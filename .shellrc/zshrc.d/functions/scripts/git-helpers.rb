#!/usr/bin/env ruby
# frozen_string_literal: true

# Assuming that you have branches named "${GITLAB_USERNAME}/${MR_ID}/${SEQ_ID}-branch_description"
# this script will ensure that branches from the same MR will be rebased correctly, keeping the chain order

def compute_default_branch
  system(*%w[git show-ref -q --verify refs/heads/main]) ? 'main' : 'master'
end

# compute_parent_branch will determine the closest parent branch,
# ignoring remotes that we're not tracking against, and with a preference
# for the local branch. In scenarios where the parent branch does not
# have a local tracking branch, then the remote is returned.
def compute_parent_branch(branch_name = nil)
  branch_name ||= `git rev-parse --abbrev-ref HEAD`
  remote_names = `git remote`.lines.map(&:chomp)
  active_remote_name = `git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null`.split('/').first
  other_remote_names = remote_names - [active_remote_name]

  parent_branch_line = `git log --decorate --simplify-by-decoration --oneline #{branch_name}`.lines[1].rstrip
  parent_branch_line = parent_branch_line
                       .sub('HEAD -> ', '')
                       .gsub(/tag: [^,)]+(, )?/, '')
  return compute_default_branch if parent_branch_line.match?(%r{.* \((origin|security)/(.*)\) .*})
  return compute_default_branch unless parent_branch_line.match?(/.* \((.*)\) .*/)

  parent_branch_line
    .sub(/.* \((.*)\) .*/, '\1')
    .split(', ')
    .reject { |b| other_remote_names.any? { |remote_name| b.start_with?("#{remote_name}/") } }
    .min_by(&:length) || compute_default_branch
end

class String
  def black
    "\033[30m#{self}\033[0m"
  end

  def red
    "\033[31m#{self}\033[0m"
  end

  def green
    "\033[1;32m#{self}\033[0m"
  end

  def brown
    "\033[33m#{self}\033[0m"
  end

  def blue
    "\033[34m#{self}\033[0m"
  end

  def magenta
    "\033[35m#{self}\033[0m"
  end

  def cyan
    "\033[36m#{self}\033[0m"
  end

  def gray
    "\033[37m#{self}\033[0m"
  end
end

def rebase_all_per_capture_info(local_branch_info_hash)
  return if local_branch_info_hash.empty?

  current_branch = `git branch --show-current`.strip

  local_branch_info_hash.each do |branch, parent_branch|
    puts 'Rebasing '.brown + branch.cyan + ' onto '.brown + parent_branch.green + '...'.brown

    system(*%W[git rev-parse --abbrev-ref --symbolic-full-name #{parent_branch}], out: File::NULL, err: File::NULL)
    unless Process.last_status.success?
      puts '  Skipping since '.red + parent_branch.green + ' does not exist.'.red
      return
    end

    system({ 'LEFTHOOK' => '0' }, *%W[git rebase --update-refs --autostash #{parent_branch} #{branch}])
    next if Process.last_status.success?

    auto_generated_files_hash = {
      'app/workers/all_queues.yml' => %w[bundle exec rake gitlab:sidekiq:all_queues_yml:generate],
      'config/sidekiq_queues.yml' => %w[bundle exec rake gitlab:sidekiq:sidekiq_queues_yml:generate],
      'db/structure.sql' => %w[bundle exec scripts/regenerate-schema],
      'doc/api/graphql/reference/index.md' => %w[bundle exec rake gitlab:graphql:compile_docs],
      'doc/user/compliance/audit_event_types.md' => %w[bundle exec rake gitlab:audit_event_types:compile_docs],
      'doc/update/breaking_windows.md' => %w[bundle exec rake gitlab:docs:compile_windows],
      'doc/update/deprecations.md' => %w[bundle exec rake gitlab:docs:compile_deprecations],
      'doc/update/removals.md' => %w[bundle exec rake gitlab:docs:compile_removals]
    }

    loop do
      status = `git status --short`
      break unless auto_generated_files_hash.select { |file, _| status.include?("UU #{file}") }.any?

      err = false
      auto_generated_files_hash
        .select { |file, _| status.include?("UU #{file}") }
        .each do |file, cmd|
          puts "  Merge conflict in #{file.red}, regenerating...".brown
          system(*cmd)
          err = true

          system(*%W[git add #{file}])
          break unless Process.last_status.success?

          err = false
        end

      break unless err || system({ 'GIT_EDITOR' => 'true', 'LEFTHOOK' => '0' }, *%w[git rebase --continue])
    end

    # There is a merge conflict that needs to be resolved by the user, exit now
    system(%(terminal-notifier -title 'rebase_all failed with merge conflict' -message 'Please resolve merge conflicts!' -sound boop -ignoreDnD))
    return
  end

  system(*%W[git switch #{current_branch}])
end

def rebase_mappings
  system(*%w[git diff-index --quiet HEAD -- . ':!bin/'])
  unless Process.last_status.success?
    system(%(terminal-notifier -title 'rebase_all failed' -message 'Please stash the changes in the current branch before calling rebase_all!' -sound boop -ignoreDnD))
    abort 'Please stash the changes in the current branch before calling rebase_all!'.red
  end

  user_name = ENV.fetch('USER', nil)
  default_branch = compute_default_branch

  mr_pattern       = %r{^(security[-/])?#{user_name}/(?<mr_id>\d+)/[a-z0-9\-+_]+$}i
  seq_mr_pattern   = %r{^(security[-/])?#{user_name}/(?<mr_id>\d+)/(?<mr_seq_nr>\d+)-[a-z0-9\-+_]+$}i
  backport_pattern = %r{^(security[-/])?#{user_name}/(?<mr_id>\d+)/[a-z0-9\-+_]+-(?<milestone>\d+[-.]\d+)$}i

  local_branches =
    `git branch --list`
    .lines
    .map { |line| line[2..].rstrip }
    .select { |branch| branch.start_with?("#{user_name}/", "security-#{user_name}/", "security/#{user_name}/") }
    .sort_by do |branch|
      seq_mr_match_data = seq_mr_pattern.match(branch)
      backport_match_data = backport_pattern.match(branch)
      mr_match_data = mr_pattern.match(branch)

      if seq_mr_match_data
        # Sort by: [branch_distance, mr_id, seq_nr, branch_name]
        # This ensures branches are grouped by MR and ordered by sequence within each MR
        [
          branch_distance(branch, default_branch),
          seq_mr_match_data[:mr_id].to_i,
          seq_mr_match_data[:mr_seq_nr].to_i,
          branch
        ]
      elsif backport_match_data
        [
          branch_distance(branch, default_branch),
          backport_match_data[:mr_id].to_i,
          999, # Put backport branches after sequenced branches
          backport_match_data[:milestone].tr('.', '-').to_f
        ]
      elsif mr_match_data
        [
          branch_distance(branch, default_branch),
          mr_match_data[:mr_id].to_i,
          999, # Put non-sequenced branches after sequenced branches
          branch
        ]
      else
        [
          branch_distance(branch, default_branch),
          999_999, # Put non-MR branches last
          999,
          branch
        ]
      end
    end

  # Track branches per MR ID
  mr_chains = {}

  local_branches.map do |branch|
    seq_mr_match_data = seq_mr_pattern.match(branch)
    mr_match_data = mr_pattern.match(branch)
    backport_match_data = backport_pattern.match(branch)

    # Determine current MR info
    current_mr_id = nil
    current_mr_seq_nr = nil

    if seq_mr_match_data
      current_mr_id     = seq_mr_match_data[:mr_id]
      current_mr_seq_nr = seq_mr_match_data[:mr_seq_nr].to_i
    elsif mr_match_data
      current_mr_id = mr_match_data[:mr_id]
    end

    # Get or initialize the chain for this MR
    if current_mr_id
      mr_chains[current_mr_id] ||= [default_branch]
      current_chain = mr_chains[current_mr_id]
    else
      current_chain = [default_branch]
    end

    rebase_onto = nil
    if current_mr_seq_nr
      if current_mr_seq_nr == 1
        parent_branch = current_chain.last
        rebase_onto = parent_branch # Always set for sequence 1 (which is default_branch)
        current_chain << branch
      else
        seq_1_branch = current_chain.find { |b| b != default_branch }
        parent_branch = seq_1_branch || current_chain.last
        rebase_onto = parent_branch
      end
    elsif backport_match_data
      remote = 'security'

      parent_branch = "#{remote}/#{backport_match_data[:milestone].tr('.', '-')}-stable-ee"
      rebase_onto = parent_branch
    else
      parent_branch = compute_parent_branch(branch)
    end

    {
      chain_mr_id: current_mr_id,
      chain_mr_seq_nr: current_mr_seq_nr,
      branch: branch,
      parent_branch: parent_branch,
      rebase_onto: rebase_onto || parent_branch
    }
  end
end

def branch_sort_key(branch_info)
  [branch_info[:chain_mr_id] || '', branch_info[:chain_mr_seq_nr].nil? ? 0 : -branch_info[:chain_mr_seq_nr]]
end

def branch_distance(branch, parent_branch)
  `git rev-list --count #{parent_branch}..#{branch}`.strip.to_i
end

def rebase_all
  require 'json'
  default_branch = compute_default_branch
  mappings = rebase_mappings
             .sort { |b1, b2| branch_sort_key(b1) <=> branch_sort_key(b2) }
             .sort do |b1, b2|
    branch_distance(b1[:branch],
                    default_branch) <=> branch_distance(b2[:branch], default_branch)
  end
    .to_h { |b| [b[:branch], b[:rebase_onto]] }
  rebase_all_per_capture_info(mappings)
end

def git_push_issue(*args)
  args = ARGV if args.empty?

  current_branch = `git branch --show-current`.strip

  user_name = ENV.fetch('USER', nil)
  mr_pattern = %r{^(?<prefix>(security[-/])?#{user_name})/(?<mr_id>\d+)/[a-z0-9\-+_]+$}
  mr_match_data = mr_pattern.match(current_branch)

  return unless mr_match_data

  local_branch_info_hash =
    rebase_mappings.select do |b|
      b[:branch].start_with?("#{mr_match_data[:prefix]}/#{mr_match_data[:mr_id]}")
    end

  branches = []
  local_branch_info_hash.each do |b|
    branch = b[:branch]
    parent_branch = b[:parent_branch]

    system(*%W[git rev-parse --abbrev-ref --symbolic-full-name #{parent_branch}], out: File::NULL, err: File::NULL)
    unless Process.last_status.success?
      puts '  Skipping since '.red + parent_branch.green + ' does not exist.'.red
      next
    end

    branches << branch
  end

  return unless branches.any?

  active_remote_name = `git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null`.split('/').first

  puts 'Pushing '.brown + branches.map(&:cyan).join(', ') + ' to '.brown + active_remote_name.green + '...'.brown

  system(*%W[git push --force-with-lease #{active_remote_name}], *branches, *args)
end

def changed_branch_files(format: nil)
  current_branch = `git branch --show-current`.strip
  parent_branch = compute_parent_branch(current_branch)

  change_log = `git diff --diff-filter=AM -U0 #{parent_branch}..#{current_branch} | grep -E '^(---|\\+\\+\\+|@@)'`.lines
  changed_files =
    change_log.reject { |line| line.start_with?('@@') } # discard diff header
              .map { |line| line.slice(4..-1).chomp }
              .reject { |file| file == '/dev/null' } # discard deletions
              .map { |file| file.slice(2..-1) } # discard b/
              .uniq

  changed_files.map do |file|
    index = change_log.index { |line| line.include?("b/#{file}") }
    line = change_log[index + 1].split[2].slice(1..-1).to_i

    case format
    when :vim
      "+#{line} #{file}"
    when :jetbrains
      "--line #{line} #{file}"
    else
      "#{file}:#{line}"
    end
  end
end
