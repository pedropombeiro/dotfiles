#!/usr/bin/env ruby
# frozen_string_literal: true

# Assuming that you have branches named "${GITLAB_USERNAME}/${MR_ID}/${SEQ_ID}-branch_description"
# this script will ensure that branches from the same MR will be rebased correctly, keeping the chain order

def compute_default_branch
  system('git show-ref refs/remotes/origin/master >/dev/null') ? 'master' : 'main'
end

# compute_parent_branch will determine the closest parent branch,
# ignoring remotes that we're not tracking against, and with a preference
# for the local branch. In scenarios where the parent branch does not
# have a local tracking branch, then the remote is returned.
def compute_parent_branch(branch_name)
  remote_names = `git remote`.lines.map(&:chomp)
  active_remote_name = `git rev-parse --abbrev-ref --symbolic-full-name @{u}`.split('/').first
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
  def black;   "\033[30m#{self}\033[0m" end
  def red;     "\033[31m#{self}\033[0m" end
  def green;   "\033[1;32m#{self}\033[0m" end
  def brown;   "\033[33m#{self}\033[0m" end
  def blue;    "\033[34m#{self}\033[0m" end
  def magenta; "\033[35m#{self}\033[0m" end
  def cyan;    "\033[36m#{self}\033[0m" end
  def gray;    "\033[37m#{self}\033[0m" end
end

def rebase_all_per_capture_info(local_branch_info_hash)
  current_branch = `git branch --show-current`

  local_branch_info_hash.each do |branch, parent_branch|
    puts 'Rebasing '.brown + branch.cyan + ' onto '.brown + parent_branch.green + '...'.brown
    break unless system(%(git rebase --autostash "#{parent_branch}" "#{branch}"))
  end

  system("git switch #{current_branch}")
end

def rebase_all
  unless system('git diff-index --quiet HEAD --')
    abort 'Please stash the changes in the current branch before calling rebase-all!'.red
  end

  user_name = ENV['USER']
  mr_pattern = /^#{user_name}\/(?<mr_id>\d+)\/[a-z0-9\-_]+$/.freeze
  seq_mr_pattern = /^#{user_name}\/(?<mr_id>\d+)\/(?<mr_seq_nr>\d+)-[a-z0-9\-_]+$/.freeze
  backport_pattern = /^#{user_name}\/(?<mr_id>\d+)\/(?<milestone>\d+\.\d+)-[a-z0-9\-_]+$/.freeze
  default_branch = compute_default_branch

  local_branches =
    `git branch --list`
    .lines
    .map { |line| line[2..].rstrip }
    .select { |branch| branch.start_with?("#{user_name}/") }
    .sort_by do |branch|
      seq_mr_match_data = seq_mr_pattern.match(branch)
      backport_match_data = backport_pattern.match(branch)
      mr_match_data = mr_pattern.match(branch)

      next [seq_mr_match_data[:mr_id].to_i, 1, seq_mr_match_data[:mr_seq_nr].to_i] if seq_mr_match_data
      next [backport_match_data[:mr_id].to_i, 2, backport_match_data[:milestone].to_f] if backport_match_data
      [mr_match_data[:mr_id].to_i, 0] if mr_match_data
    end

  chain_previous_branch = default_branch
  chain_mr_id = nil
  mappings = local_branches.map do |branch|
    seq_mr_match_data = seq_mr_pattern.match(branch)
    backport_match_data = backport_pattern.match(branch)

    chain_previous_branch = default_branch if seq_mr_match_data && seq_mr_match_data[:mr_id] != chain_mr_id
    chain_mr_id = seq_mr_match_data ? seq_mr_match_data[:mr_id] : nil

    if seq_mr_match_data
      parent_branch = chain_previous_branch
      chain_previous_branch = branch
    elsif backport_match_data
      remote = `git rev-parse --abbrev-ref --symbolic-full-name #{branch}@{u} --`.split('/').first
      next if $?.exitstatus == 128 # Ignore branch if was deleted upstream
      parent_branch = "#{remote}/#{backport_match_data[:milestone].gsub('.', '-')}-stable-ee"
    else
      parent_branch = default_branch
    end

    [branch, parent_branch]
  end
    .compact
    .to_h

  rebase_all_per_capture_info mappings if mappings.any?
end
