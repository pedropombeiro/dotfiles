#!/usr/bin/env ruby
# frozen_string_literal: true

# Assuming that you have branches named "${GITLAB_USERNAME}/${MR_ID}/${SEQ_ID}-branch_description"
# this script will ensure that branches from the same MR will be rebased correctly, keeping the chain order

def compute_default_branch
  system(*%w[git show-ref refs/remotes/origin/master], out: File::NULL) ? 'master' : 'main'
end

# compute_parent_branch will determine the closest parent branch,
# ignoring remotes that we're not tracking against, and with a preference
# for the local branch. In scenarios where the parent branch does not
# have a local tracking branch, then the remote is returned.
def compute_parent_branch(branch_name)
  remote_names       = `git remote`.lines.map(&:chomp)
  active_remote_name = `git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null`.split('/').first
  other_remote_names = remote_names - [active_remote_name]

  parent_branch_line = `git log --decorate --simplify-by-decoration --oneline #{branch_name}`.lines[1].rstrip
  parent_branch_line
    .sub('HEAD -> ', '')
    .gsub(/tag: [^,)]+(, )?/, '')
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
      'app/workers/all_queues.yml' => %w[bin/rake gitlab:sidekiq:all_queues_yml:generate],
      'config/sidekiq_queues.yml' => %w[bin/rake gitlab:sidekiq:sidekiq_queues_yml:generate],
      'db/structure.sql' => %w[scripts/regenerate-schema],
      'doc/api/graphql/reference/index.md' => %w[bin/rake gitlab:graphql:compile_docs],
      'doc/update/deprecations.md' => %w[bin/rake gitlab:docs:compile_deprecations],
      'doc/update/removals.md' => %w[bin/rake gitlab:docs:compile_removals]
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
    return
  end

  system(*%W[git switch #{current_branch}])
end

def rebase_mappings
  system(*%w[git restore db/schema_migrations/], out: File::NULL)

  system(*%w[git diff-index --quiet HEAD --])
  unless Process.last_status.success?
    abort 'Please stash the changes in the current branch before calling rebase-all!'.red
  end

  user_name = ENV['USER']
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
      seq_mr_match_data   = seq_mr_pattern.match(branch)
      backport_match_data = backport_pattern.match(branch)
      mr_match_data       = mr_pattern.match(branch)

      next [seq_mr_match_data[:mr_id].to_i, 1, seq_mr_match_data[:mr_seq_nr].to_i] if seq_mr_match_data

      if backport_match_data
        next [backport_match_data[:mr_id].to_i, 2,
              backport_match_data[:milestone].tr('.', '-').to_f]
      end
      next [mr_match_data[:mr_id].to_i, 1] if mr_match_data

      []
    end

  chain_previous_branches  = [default_branch]
  chain_previous_mr_seq_nr = nil
  chain_mr_id              = nil

  local_branches.map do |branch|
    seq_mr_match_data   = seq_mr_pattern.match(branch)
    mr_match_data       = mr_pattern.match(branch)
    backport_match_data = backport_pattern.match(branch)

    chain_previous_mr_id = chain_mr_id

    if seq_mr_match_data
      chain_mr_id     = seq_mr_match_data[:mr_id]
      chain_mr_seq_nr = seq_mr_match_data[:mr_seq_nr].to_i
    elsif mr_match_data
      chain_mr_id     = mr_match_data[:mr_id]
      chain_mr_seq_nr = nil
    else
      chain_mr_id     = nil
      chain_mr_seq_nr = nil
    end

    if chain_previous_mr_id && chain_mr_id != chain_previous_mr_id
      chain_previous_branches  = [default_branch]
      chain_previous_mr_seq_nr = nil
    end

    if chain_mr_seq_nr
      if chain_previous_mr_seq_nr.nil? || chain_mr_seq_nr > chain_previous_mr_seq_nr
        parent_branch = chain_previous_branches.last
        chain_previous_branches << branch
      else
        parent_branch = chain_previous_branches[-2]
      end

      chain_previous_mr_seq_nr = chain_mr_seq_nr
    elsif backport_match_data
      remote = `git rev-parse --abbrev-ref --symbolic-full-name #{branch}@{u} --`.split('/').first
      next if Process.last_status.exitstatus == 128 # Ignore branch if was deleted upstream

      parent_branch = "#{remote}/#{backport_match_data[:milestone].tr('.', '-')}-stable-ee"
    else
      parent_branch = default_branch
    end

    {
      chain_mr_id: chain_mr_id,
      chain_mr_seq_nr: chain_mr_seq_nr,
      branch: branch,
      parent_branch: parent_branch
    }
  end
end

def branch_sort_key(branch_info)
  [branch_info[:chain_mr_id] || '', branch_info[:chain_mr_seq_nr].nil? ? 0 : -branch_info[:chain_mr_seq_nr]]
end

def rebase_all
  default_branch = compute_default_branch
  mappings = rebase_mappings
             .sort { |b1, b2| branch_sort_key(b1) <=> branch_sort_key(b2) }
             .uniq { |b| "#{b[:chain_mr_id] || b[:branch]}/#{b[:chain_mr_seq_nr].nil? ? Random.rand(1..100_000) : 0}" }
             .to_h { |b| [b[:branch], default_branch] }
  rebase_all_per_capture_info(mappings)
end

def git_push_issue(*args)
  args = ARGV if args.empty?

  current_branch = `git branch --show-current`.strip

  user_name = ENV['USER']
  mr_pattern = %r{^(?<prefix>(security[-/])?#{user_name})/(?<mr_id>\d+)/[a-z0-9\-+_]+$}
  mr_match_data = mr_pattern.match(current_branch)

  return unless mr_match_data

  local_branch_info_hash =
    rebase_mappings.select do |b|
      b[:branch].start_with?("#{mr_match_data[:prefix]}/#{mr_match_data[:mr_id]}")
    end

  local_branch_info_hash.each do |b|
    branch = b[:branch]
    parent_branch = b[:parent_branch]

    active_remote_name = `git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null`.split('/').first

    puts 'Pushing '.brown + branch.cyan + ' to '.brown + active_remote_name.green + '...'.brown

    system(*%W[git rev-parse --abbrev-ref --symbolic-full-name #{parent_branch}], out: File::NULL, err: File::NULL)
    unless Process.last_status.success?
      puts '  Skipping since '.red + parent_branch.green + ' does not exist.'.red
      next
    end

    system(*%W[git push --force-with-lease #{active_remote_name} #{branch}] + args)
    break unless Process.last_status.success?
  end

  system(*%W[git switch #{current_branch}])
end

BASELINE_MR_RATE = 6

def gitlab_mr_rate(*author)
  author = ARGV[0] if author.empty?

  require 'date'
  require 'json'

  mrs = []
  start_cursor = 'null'
  best_month = nil
  best_month_mr_rate = 0
  total_time_to_merge = 0
  $stderr.print 'Fetching '

  loop do
    $stderr.putc '.'

    res = `glab api graphql -f query='
        query {
          group(fullPath: "gitlab-org") {
            mergeRequests(
              authorUsername: "#{author}",
              state: merged,
              includeSubgroups: true,
              after: #{start_cursor}
            ) {
              totalTimeToMerge
              nodes {
                mergedAt
              }
              pageInfo {
                endCursor
                hasNextPage
              }
            }
          }
        }'`
    return if $?.exitstatus != 0

    json_res = JSON.parse(res)
    merge_requests = json_res.dig(*%w[data group mergeRequests])
    mrs +=
      merge_requests['nodes'].map do |mr|
        { merged_at: DateTime.iso8601(mr['mergedAt']) }
      rescue StandardError
        $stderr.print mr
        raise
      end

    total_time_to_merge = merge_requests['totalTimeToMerge']
    page_info = merge_requests['pageInfo']
    break unless page_info['hasNextPage']

    start_cursor = "\"#{page_info['endCursor']}\""
  end

  puts
  now = DateTime.now
  mrs_merged_by_month = mrs.group_by { |mr| [now, DateTime.civil(mr[:merged_at].year, mr[:merged_at].month, -1)].min }
  mrs_merged_by_month.each do |ym, monthly_mrs|
    prorated_mr_count = monthly_mrs.count
    if ym.year == now.year && ym.month == now.month
      prorated_mr_count = monthly_mrs.count.to_f / ym.day * DateTime.civil(ym.year, ym.month, -1).day
      indicator = " (in progress - #{prorated_mr_count.to_i} prorated)"
    end

    if monthly_mrs.count > best_month_mr_rate
      best_month = ym
      best_month_mr_rate = monthly_mrs.count
    end

    msg = "#{ym.strftime('%Y-%m')}: #{monthly_mrs.count.to_s.rjust(3)}"

    if prorated_mr_count < BASELINE_MR_RATE
      print msg.red
      $stderr.print indicator.red if indicator
    else
      print msg.green
      $stderr.print indicator.green if indicator
    end

    puts
  end

  first_mr_at = mrs.map { |mr| mr[:merged_at] }.min
  last_mr_at = mrs.map { |mr| mr[:merged_at] }.max

  monthly_average =
    if last_mr_at.year == first_mr_at.year && last_mr_at.month == first_mr_at.month
      mrs.count.to_f / ((DateTime.civil(last_mr_at.year, last_mr_at.month,
                                        -1) - DateTime.civil(first_mr_at.year, first_mr_at.month, 1)).to_f / 30)
    else
      mrs.count.to_f / ((last_mr_at - first_mr_at).to_f / 30)
    end

  puts '-' * 12
  msg = "Average MRs merged per month: #{monthly_average.round}"
  if monthly_average > BASELINE_MR_RATE
    puts msg.green
  else
    puts msg.red
  end
  puts "Average per MR: #{(total_time_to_merge / (60 * 60 * 24) / mrs.count).round(1)} days"
  puts "Total MRs merged: #{mrs.count}"
  puts "Best month: #{best_month.strftime('%Y-%m')} (#{best_month_mr_rate} MRs)"
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
