#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"

# Assuming that you have branches named "${GITLAB_USERNAME}/${MR_ID}/${SEQ_ID}-branch_description"
# this script will ensure that branches from the same MR will be rebased correctly, keeping the chain order

def compute_default_branch
  @compute_default_branch ||= system(*%w[git show-ref -q --verify refs/heads/main]) ? "main" : "master"
end

# compute_parent_branch will determine the closest parent branch,
# ignoring remotes that we're not tracking against, and with a preference
# for the local branch. In scenarios where the parent branch does not
# have a local tracking branch, then the remote is returned.
def preload_parent_branches!(branches)
  @compute_parent_branch_cache ||= {}
  @remote_names ||= `git remote`.lines.map(&:chomp)

  missing = branches.reject { |b| @compute_parent_branch_cache.key?(b) }
  return if missing.empty?

  threads = missing.map do |branch_name|
    Thread.new do
      output = `git log --decorate --simplify-by-decoration --oneline #{branch_name}`.lines
      [branch_name, output]
    end
  end

  threads.each do |t|
    branch_name, output = t.value
    resolve_parent_branch_from_log(branch_name, output)
  end
end

def compute_parent_branch(branch_name = nil)
  @compute_parent_branch_cache ||= {}
  branch_name ||= `git rev-parse --abbrev-ref HEAD`

  return @compute_parent_branch_cache[branch_name] if @compute_parent_branch_cache.key?(branch_name)

  output = `git log --decorate --simplify-by-decoration --oneline #{branch_name}`.lines
  resolve_parent_branch_from_log(branch_name, output)
end

def resolve_parent_branch_from_log(branch_name, log_lines)
  @compute_parent_branch_cache ||= {}
  @remote_names ||= `git remote`.lines.map(&:chomp)
  @active_remote_name ||= `git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null`.split("/").first
  other_remote_names = @remote_names - [@active_remote_name]

  parent_branch_line = log_lines[1]&.rstrip || ""
  parent_branch_line = parent_branch_line
    .sub("HEAD -> ", "")
    .gsub(/tag: [^,)]+(, )?/, "")
  return @compute_parent_branch_cache[branch_name] = compute_default_branch if parent_branch_line.match?(%r{.* \((origin|security)/(.*)\) .*})
  return @compute_parent_branch_cache[branch_name] = compute_default_branch unless parent_branch_line.match?(/.* \((.*)\) .*/)

  @compute_parent_branch_cache[branch_name] =
    parent_branch_line
      .sub(/.* \((.*)\) .*/, '\1')
      .split(", ")
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

  local_branch_info_hash.each do |branch, info|
    parent_branch = info.is_a?(Hash) ? info[:rebase_onto] : info
    fork_point = info.is_a?(Hash) ? info[:fork_point] : nil

    if checked_out_in_other_worktree?(branch)
      puts "  Skipping ".brown + branch.cyan + " (checked out in another worktree)".brown
      next
    end

    if info.is_a?(Hash) && info[:squash_merged]
      puts "  Skipping ".brown + branch.cyan + " (already squash-merged into #{compute_default_branch})".brown
      next
    end

    if info.is_a?(Hash) && info[:ambiguous_parents]&.any?
      puts "  Skipping ".brown + branch.cyan +
        " (ambiguous stack parent: #{info[:ambiguous_parents].join(", ")}; rebase manually)".red
      next
    end

    if fork_point
      puts "Rebasing ".brown + branch.cyan + " onto ".brown + parent_branch.green +
        " (replaying commits after #{fork_point.match?(/\A\h{40}\z/) ? fork_point[0, 12] : fork_point})...".brown
    else
      puts "Rebasing ".brown + branch.cyan + " onto ".brown + parent_branch.green + "...".brown
    end

    system(*%W[git rev-parse --abbrev-ref --symbolic-full-name #{parent_branch}], out: File::NULL, err: File::NULL)

    unless Process.last_status.success?
      puts "  Skipping since ".red + parent_branch.green + " does not exist.".red
      next
    end

    rebase_cmd = if fork_point
      %W[git rebase --update-refs --autostash --onto #{parent_branch} #{fork_point} #{branch}]
    else
      %W[git rebase --update-refs --autostash #{parent_branch} #{branch}]
    end

    system({"LEFTHOOK" => "0"}, *rebase_cmd)
    next if Process.last_status.success?

    auto_generated_files_hash = {
      "app/workers/all_queues.yml" => %w[bundle exec rake gitlab:sidekiq:all_queues_yml:generate],
      "config/sidekiq_queues.yml" => %w[bundle exec rake gitlab:sidekiq:sidekiq_queues_yml:generate],
      "db/structure.sql" => %w[bundle exec scripts/regenerate-schema],
      "doc/api/graphql/reference/index.md" => %w[bundle exec rake gitlab:graphql:compile_docs],
      "doc/user/compliance/audit_event_types.md" => %w[bundle exec rake gitlab:audit_event_types:compile_docs],
      "doc/update/breaking_windows.md" => %w[bundle exec rake gitlab:docs:compile_windows],
      "doc/update/deprecations.md" => %w[bundle exec rake gitlab:docs:compile_deprecations],
      "doc/update/removals.md" => %w[bundle exec rake gitlab:docs:compile_removals],
      "doc/api/openapi/openapi_v2.yaml" => %w[bundle exec rake gitlab:openapi:v2:generate],
      "doc/api/openapi/openapi_v3.yaml" => %w[bundle exec rake gitlab:openapi:v3:generate]
    }

    resolved = false
    loop do
      conflicting_files = unmerged_files
      auto_conflicting = conflicting_files.select { |file| auto_generated_files_hash.key?(file) }
      break if auto_conflicting.empty? || auto_conflicting.size < conflicting_files.size

      regenerated = auto_conflicting.all? do |file|
        puts "  Merge conflict in #{file.red}, regenerating...".brown
        next true if system(*(%w[mise x ruby --] + auto_generated_files_hash[file])) && system(*%W[git add #{file}])

        puts "  Failed to regenerate ".red + file.cyan
        false
      end
      break unless regenerated

      if system({"GIT_EDITOR" => "true", "LEFTHOOK" => "0"}, *%w[git rebase --continue])
        resolved = true
        break
      end
    end
    next if resolved

    # There is a merge conflict that needs to be resolved by the user, exit now
    system(%(hs -c 'hs.notify.new({title="rebase_all", informativeText="Failed with merge conflict. Please resolve merge conflicts!"}):send()'))
    return false
  end

  system(*%W[git switch #{current_branch}])
end

UNMERGED_STATUSES = %w[DD AU UD UA DU AA UU].freeze

def unmerged_files
  `git status --short`.lines
    .select { |line| UNMERGED_STATUSES.include?(line[0, 2]) }
    .map { |line| line[3..].strip }
end

def rebase_mappings
  system(*%w[git diff-index --quiet HEAD -- . ':!bin/'])

  unless Process.last_status.success?
    system(%(hs -c 'hs.notify.new({title="rebase_all", informativeText="Please stash the changes in the current branch before calling rebase_all!"}):send()'))
    abort "Please stash the changes in the current branch before calling rebase_all!".red
  end

  user_name = ENV.fetch("USER", nil)
  default_branch = compute_default_branch

  preload_local_branches!

  mr_pattern = %r{^(security[-/])?#{user_name}/(?<mr_id>\d+)/[a-z0-9\-+_]+$}i
  seq_mr_pattern = %r{^(security[-/])?#{user_name}/(?<mr_id>\d+)/(?<mr_seq_nr>\d+)-[a-z0-9\-+_]+$}i
  backport_pattern = %r{^(security[-/])?#{user_name}/(?<mr_id>\d+)/[a-z0-9\-+_]+-(?<milestone>\d+[-.]\d+)$}i

  local_branches =
    @branch_exists_cache.keys
      .select { |branch| branch.start_with?("#{user_name}/", "security-#{user_name}/", "security/#{user_name}/") }

  non_seq_branches = local_branches.reject { |b| seq_mr_pattern.match?(b) || backport_pattern.match?(b) }

  @remote_names ||= `git remote`.lines.map(&:chomp)
  @active_remote_name ||= `git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null`.split("/").first

  preload_threads = [
    Thread.new { branch_distance_map(default_branch, local_branches) },
    Thread.new do
      preload_merge_bases!(default_branch, local_branches)
      preload_squash_merged!(default_branch, local_branches)
    end,
    Thread.new { preload_fork_points!(default_branch, local_branches) },
    Thread.new { preload_parent_branches!(non_seq_branches) }
  ]
  preload_threads.each(&:join)

  local_branches = local_branches.sort_by do |branch|
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
        backport_match_data[:milestone].tr(".", "-").to_f
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

  mr_seq_branches = {}
  mr_unnumbered_branches = unnumbered_mr_branches(local_branches, mr_pattern, [seq_mr_pattern, backport_pattern])

  local_branches.each do |branch|
    seq_mr_match_data = seq_mr_pattern.match(branch)
    next unless seq_mr_match_data

    mr_id = seq_mr_match_data[:mr_id]
    seq_nr = seq_mr_match_data[:mr_seq_nr].to_i
    mr_seq_branches[mr_id] ||= {}
    (mr_seq_branches[mr_id][seq_nr] ||= []) << branch
  end

  local_branches.map do |branch|
    seq_mr_match_data = seq_mr_pattern.match(branch)
    mr_match_data = mr_pattern.match(branch)
    backport_match_data = backport_pattern.match(branch)

    current_mr_id = nil
    current_mr_seq_nr = nil

    if seq_mr_match_data
      current_mr_id = seq_mr_match_data[:mr_id]
      current_mr_seq_nr = seq_mr_match_data[:mr_seq_nr].to_i
    elsif mr_match_data
      current_mr_id = mr_match_data[:mr_id]
    end

    rebase_onto = nil
    fork_point = nil
    ambiguous_parents = nil
    if current_mr_seq_nr
      seq_map = mr_seq_branches[current_mr_id]
      prev_seq_nr = seq_map.keys.select { |seq| seq < current_mr_seq_nr }.max
      if prev_seq_nr
        prev_branch = seq_map[prev_seq_nr].first
        if branch_exists?(prev_branch)
          if branch_merged_into?(prev_branch, default_branch)
            mb = merge_base(default_branch, branch)
            fork_point = prev_branch unless branch_merged_into?(prev_branch, mb)
            rebase_onto = default_branch
          else
            # Capture the old parent boundary now: a plain rebase replays rewritten parent commits.
            fork_point = stacked_fork_point(prev_branch, branch, default_branch)
            rebase_onto = prev_branch
          end
        else
          rebase_onto = default_branch
        end
      elsif (stack_base = resolve_unnumbered_stack_base(branch, mr_unnumbered_branches[current_mr_id], default_branch))
        if stack_base[:ambiguous]
          ambiguous_parents = stack_base[:candidates]
          rebase_onto = default_branch
        else
          rebase_onto = stack_base[:branch]
          fork_point = stack_base[:fork_point]
        end
      else
        prev_seq_pattern = "#{user_name}/#{current_mr_id}/#{current_mr_seq_nr - 1}-"
        old_tip = deleted_branch_tip_from_reflog(prev_seq_pattern, branch)
        if old_tip
          mb = merge_base(default_branch, branch)
          fork_point = old_tip unless branch_merged_into?(old_tip, mb)
        end

        rebase_onto = default_branch
      end

      parent_branch = rebase_onto
    elsif backport_match_data
      remote = "security"

      parent_branch = "#{remote}/#{backport_match_data[:milestone].tr(".", "-")}-stable-ee"
      rebase_onto = parent_branch
    else
      parent_branch = compute_parent_branch(branch)
    end

    # A squash-merged parent is not an ancestor of the default branch, so replay only this branch's commits.
    rebase_target = rebase_onto || parent_branch
    if rebase_target != default_branch && branch_exists?(rebase_target) &&
        branch_squash_merged_into?(rebase_target, default_branch)
      fork_point ||= stacked_fork_point(rebase_target, branch, default_branch) || resolve_ref(rebase_target)
      rebase_onto = default_branch
    end

    if fork_point.nil? && ambiguous_parents.nil? && (rebase_onto || parent_branch) == default_branch
      fp_result = compute_fork_point(default_branch, branch)
      fp = fp_result[:value]
      mb = merge_base(default_branch, branch)
      default_branch_sha = resolve_ref(default_branch)
      if fp_result[:success] && !fp.empty? && fp != default_branch_sha && fp != mb
        fork_point = fp
        rebase_onto = default_branch
      end
    end

    {
      chain_mr_id: current_mr_id,
      chain_mr_seq_nr: current_mr_seq_nr,
      branch: branch,
      parent_branch: parent_branch,
      rebase_onto: rebase_onto || parent_branch,
      fork_point: fork_point,
      squash_merged: branch_squash_merged_into?(branch, default_branch),
      ambiguous_parents: ambiguous_parents
    }
  end
end

def unnumbered_mr_branches(branches, mr_pattern, excluded_patterns)
  branches.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |branch, groups|
    next if excluded_patterns.any? { |pattern| pattern.match?(branch) }

    mr_match_data = mr_pattern.match(branch)
    groups[mr_match_data[:mr_id]] << branch if mr_match_data
  end
end

# The first numbered branch of a stack may sit on an unnumbered branch of the same MR,
# because only stacked branches get a sequence prefix. Prefer the closest direct ancestor,
# then a reflog fork point, then a uniquely matching patch-equivalent parent prefix.
def resolve_unnumbered_stack_base(branch, candidates, default_branch)
  unmerged = candidates.reject { |candidate| branch_merged_into?(candidate, default_branch) }
  return if unmerged.empty?

  ancestors = unmerged.select { |candidate| branch_merged_into?(candidate, branch) }
  unless ancestors.empty?
    base = ancestors.max_by { |candidate| branch_distance(candidate, default_branch) }
    return {branch: base, fork_point: resolve_ref(base)}
  end

  reflog_matches = unmerged.filter_map do |candidate|
    fp = reflog_fork_point(candidate, branch, default_branch)
    {branch: candidate, fork_point: fp, distance: branch_distance(candidate, default_branch)} if fp
  end
  unless reflog_matches.empty?
    max_distance = reflog_matches.map { |match| match[:distance] }.max
    closest = reflog_matches.select { |match| match[:distance] == max_distance }
    return {ambiguous: true, candidates: closest.map { |match| match[:branch] }} if closest.size > 1

    match = closest.first
    return {branch: match[:branch], fork_point: match[:fork_point]}
  end

  patch_matches = unmerged.filter_map do |candidate|
    match = patch_prefix_match(candidate, branch, default_branch)
    {branch: candidate, fork_point: match[:fork_point], prefix_length: match[:prefix_length]} if match
  end
  return if patch_matches.empty?

  max_prefix = patch_matches.map { |match| match[:prefix_length] }.max
  closest = patch_matches.select { |match| match[:prefix_length] == max_prefix }
  return {ambiguous: true, candidates: closest.map { |match| match[:branch] }} if closest.size > 1

  match = closest.first
  {branch: match[:branch], fork_point: match[:fork_point]}
end

def branch_sort_key(branch_info)
  [branch_info[:chain_mr_id] || "", branch_info[:chain_mr_seq_nr].nil? ? 0 : -branch_info[:chain_mr_seq_nr]]
end

def preload_local_branches!
  @branch_exists_cache ||= {}
  @branch_upstream_cache ||= {}
  @resolve_ref_cache ||= {}
  return if @branch_exists_preloaded

  `git for-each-ref --format='%(objectname)%09%(refname:short)%09%(upstream:short)%09%(upstream:track)' refs/heads/`.lines.each do |line|
    sha, branch, upstream, track = line.chomp.split("\t", 4)
    next unless sha && branch && !branch.empty?

    @resolve_ref_cache[branch] = sha
    @branch_exists_cache[branch] = true
    @branch_upstream_cache[branch] = {
      upstream: (upstream && !upstream.empty?) ? upstream : nil,
      gone: track == "[gone]"
    }
  end
  @branch_exists_preloaded = true
end

def branch_upstream_info(branch)
  preload_local_branches!
  @branch_upstream_cache[branch] ||= begin
    out = `git for-each-ref --format='%(upstream:short)%09%(upstream:track)' refs/heads/#{branch}`.chomp
    upstream, track = out.split("\t", 2)
    {
      upstream: (upstream && !upstream.empty?) ? upstream : nil,
      gone: track == "[gone]"
    }
  end
end

def worktree_branches
  @worktree_branches ||= begin
    current_dir = File.realpath(Dir.pwd)
    branches = Set.new
    current_path = nil
    `git worktree list --porcelain`.each_line do |line|
      line.chomp!

      if line.start_with?("worktree ")
        current_path = line.sub("worktree ", "")
      elsif line.start_with?("branch ") && current_path
        next if File.realpath(current_path) == current_dir

        branches << line.sub("branch refs/heads/", "")
      end
    end
    branches
  end
end

def checked_out_in_other_worktree?(branch)
  worktree_branches.include?(branch)
end

def branch_exists?(branch)
  @branch_exists_cache ||= {}
  return @branch_exists_cache[branch] if @branch_exists_cache.key?(branch)

  @branch_exists_cache[branch] =
    system(*%W[git rev-parse --verify #{branch}], out: File::NULL, err: File::NULL)
end

def resolve_ref(ref)
  @resolve_ref_cache ||= {}
  @resolve_ref_cache[ref] ||= `git rev-parse #{ref}`.strip
end

def merge_base(a, b)
  @merge_base_cache ||= {}
  key = "#{a}:#{b}"
  return @merge_base_cache[key] if @merge_base_cache.key?(key)

  @merge_base_cache[key] = `git merge-base #{a} #{b} 2>/dev/null`.strip
end

def preload_merge_bases!(default_branch, branches)
  @merge_base_cache ||= {}
  missing = branches.reject { |b| @merge_base_cache.key?("#{default_branch}:#{b}") }
  return if missing.empty?

  threads = missing.map do |branch|
    Thread.new do
      result = `git merge-base #{default_branch} #{branch} 2>/dev/null`.strip
      [branch, result]
    end
  end

  threads.each do |t|
    branch, result = t.value
    @merge_base_cache["#{default_branch}:#{branch}"] = result
  end
end

def preload_fork_points!(default_branch, branches)
  @fork_point_cache ||= {}
  missing = branches.reject { |b| @fork_point_cache.key?("#{default_branch}:#{b}") }
  return if missing.empty?

  threads = missing.map do |branch|
    Thread.new do
      result = `git merge-base --fork-point #{default_branch} #{branch} 2>/dev/null`.strip
      success = Process.last_status.success?
      [branch, result, success]
    end
  end

  threads.each do |t|
    branch, result, success = t.value
    @fork_point_cache["#{default_branch}:#{branch}"] = {value: result, success: success}
  end
end

def compute_fork_point(default_branch, branch)
  @fork_point_cache ||= {}
  key = "#{default_branch}:#{branch}"
  return @fork_point_cache[key] if @fork_point_cache.key?(key)

  result = `git merge-base --fork-point #{default_branch} #{branch} 2>/dev/null`.strip
  @fork_point_cache[key] = {value: result, success: Process.last_status.success?}
end

def reflog_fork_point(parent_branch, branch, default_branch = compute_default_branch)
  result = compute_fork_point(parent_branch, branch)
  value = result[:value]
  return unless result[:success] && !value.empty?
  return unless branch_merged_into?(value, branch)
  return if branch_merged_into?(value, default_branch)

  value
end

def branch_patch_commits(branch, default_branch = compute_default_branch)
  @branch_patch_commits_cache ||= {}
  key = "#{default_branch}:#{branch}"
  return @branch_patch_commits_cache[key] if @branch_patch_commits_cache.key?(key)

  mb = merge_base(default_branch, branch)
  return @branch_patch_commits_cache[key] = [] if mb.empty?

  commits = IO.popen(%W[git rev-list --reverse #{mb}..#{branch}], err: File::NULL, &:read).lines.map(&:strip)
  return @branch_patch_commits_cache[key] = [] if commits.empty? || !Process.last_status.success?

  patch_ids = {}
  pipeline_ok = true
  Open3.pipeline_r(
    ["git", "log", "--no-merges", "--no-ext-diff", "--no-color", "--pretty=format:commit %H", "-p", "#{mb}..#{branch}"],
    %w[git patch-id --stable]
  ) do |out, wait_threads|
    out.each_line do |line|
      patch_id, sha = line.split
      patch_ids[sha] = patch_id if patch_id && sha
    end
    pipeline_ok = wait_threads.all? { |t| t.value.success? }
  end
  return @branch_patch_commits_cache[key] = [] unless pipeline_ok

  @branch_patch_commits_cache[key] = commits.map { |sha| {sha: sha, patch_id: patch_ids[sha]} }
end

def patch_prefix_match(parent_branch, branch, default_branch = compute_default_branch)
  parent_commits = branch_patch_commits(parent_branch, default_branch)
  return if parent_commits.empty?
  return unless parent_commits.all? { |commit| commit[:patch_id] }

  branch_commits = branch_patch_commits(branch, default_branch)
  return if branch_commits.size < parent_commits.size

  parent_patch_ids = parent_commits.map { |commit| commit[:patch_id] }
  branch_prefix_ids = branch_commits.first(parent_commits.size).map { |commit| commit[:patch_id] }
  return unless branch_prefix_ids == parent_patch_ids

  {
    fork_point: branch_commits[parent_commits.size - 1][:sha],
    prefix_length: parent_commits.size
  }
end

def stacked_fork_point(parent_branch, branch, default_branch = compute_default_branch)
  if branch_merged_into?(parent_branch, branch) && !branch_merged_into?(parent_branch, default_branch)
    return resolve_ref(parent_branch)
  end

  reflog_fork_point(parent_branch, branch, default_branch) ||
    patch_prefix_match(parent_branch, branch, default_branch)&.fetch(:fork_point)
end

def branch_merged_into?(branch, target)
  @branch_merged_cache ||= {}
  key = "#{branch}:#{target}"
  return @branch_merged_cache[key] if @branch_merged_cache.key?(key)

  if @merge_base_cache&.key?("#{target}:#{branch}") && @resolve_ref_cache&.key?(branch)
    return @branch_merged_cache[key] = (@merge_base_cache["#{target}:#{branch}"] == @resolve_ref_cache[branch])
  end

  @branch_merged_cache[key] = system(*%W[git merge-base --is-ancestor #{branch} #{target}])
end

def preload_squash_merged!(target, branches)
  preload_target_merge_commits!(target, branches)
  resolve_ref("#{target}^{tree}")
  branches.map { |branch| Thread.new { branch_squash_merged_into?(branch, target) } }.each(&:join)
end

def branch_squash_merged_into?(branch, target)
  @branch_squash_merged_cache ||= {}
  key = "#{branch}:#{target}"
  return @branch_squash_merged_cache[key] if @branch_squash_merged_cache.key?(key)

  @branch_squash_merged_cache[key] = compute_branch_squash_merged(branch, target)
end

def tree_merged_into?(branch_ref, target_ref)
  merged_tree = IO.popen(%W[git merge-tree --write-tree --no-messages #{target_ref} #{branch_ref}], err: File::NULL, &:read)
  return false unless Process.last_status.success?

  merged_tree.lines.first&.strip == resolve_ref("#{target_ref}^{tree}")
end

def commit_timestamp(ref)
  out = IO.popen(%W[git log -1 --format=%ct #{ref}], err: File::NULL, &:read).strip
  return unless Process.last_status.success? && !out.empty?

  out.to_i
end

def changed_files_between(base_ref, tip_ref)
  out = IO.popen(%W[git diff --name-only #{base_ref} #{tip_ref}], err: File::NULL, &:read)
  return [] unless Process.last_status.success?

  out.lines.map(&:strip).reject(&:empty?)
end

def preload_target_merge_commits!(target, branches)
  @target_merge_commits_cache ||= {}
  return if @target_merge_commits_cache.key?(target)

  preload_merge_bases!(target, branches)
  mbs = branches.map { |branch| merge_base(target, branch) }.reject(&:empty?).uniq
  if mbs.empty?
    @target_merge_commits_cache[target] = {}
    return
  end

  root_mb = if mbs.size == 1
    mbs.first
  else
    out = IO.popen(["git", "merge-base", "--octopus", *mbs], err: File::NULL, &:read).strip
    (Process.last_status.success? && !out.empty?) ? out : mbs.first
  end

  commits_by_branch = {}
  pattern = /\AMerge branch '([^']+)'(?: into '?#{Regexp.escape(target)}'?)?\z/
  IO.popen(
    ["git", "log", "--first-parent", "--merges", "--format=%H\t%ct\t%s", "#{root_mb}..#{target}"],
    err: File::NULL
  ) do |io|
    io.each_line do |line|
      sha, timestamp, subject = line.chomp.split("\t", 3)
      next unless sha && timestamp && subject

      match = pattern.match(subject)
      next unless match

      merged_branch = match[1]
      commits_by_branch[merged_branch] ||= {sha: sha, timestamp: timestamp.to_i}
    end
  end

  @target_merge_commits_cache[target] = commits_by_branch
end

def find_branch_merge_commit(branch, target)
  mb = merge_base(target, branch)
  return if mb.empty? || mb == resolve_ref(branch)

  if @target_merge_commits_cache&.key?(target)
    commit = @target_merge_commits_cache[target][branch]
    return unless commit
    return commit if branch_merged_into?(mb, commit[:sha])
  end

  subject_prefix = "Merge branch '#{branch}'"
  allowed_subjects = [
    subject_prefix,
    "#{subject_prefix} into '#{target}'",
    "#{subject_prefix} into #{target}"
  ]

  IO.popen(
    ["git", "log", "--first-parent", "--merges", "--fixed-strings", "--grep=#{subject_prefix}", "--format=%H\t%ct\t%s", "#{mb}..#{target}"],
    err: File::NULL
  ) do |io|
    io.each_line do |line|
      sha, timestamp, subject = line.chomp.split("\t", 3)
      next unless sha && timestamp && subject
      next unless allowed_subjects.include?(subject)

      return {sha: sha, timestamp: timestamp.to_i}
    end
  end

  nil
end

# Squash merges leave no ancestry link, and follow-up commits on the MR can make the local branch's merge-tree differ.
# Check the local branch, its upstream when no local commits are unpushed, and verified first-parent merge commits on
# the target.
def compute_branch_squash_merged(branch, target)
  return false if branch_merged_into?(branch, target)
  return true if tree_merged_into?(branch, target)

  upstream_info = branch_upstream_info(branch)
  upstream = upstream_info[:upstream]
  has_live_upstream = upstream && !upstream_info[:gone] && branch_exists?(upstream)

  if has_live_upstream
    return false unless branch_merged_into?(branch, upstream)
    if resolve_ref(branch) != resolve_ref(upstream) &&
        (branch_merged_into?(upstream, target) || tree_merged_into?(upstream, target))
      return true
    end
  end

  merge_commit = find_branch_merge_commit(branch, target)
  return false unless merge_commit

  merge_sha = merge_commit[:sha]
  return true if tree_merged_into?(branch, merge_sha)
  if has_live_upstream && resolve_ref(branch) != resolve_ref(upstream) && tree_merged_into?(upstream, merge_sha)
    return true
  end

  branch_ts = commit_timestamp(branch)
  return false unless branch_ts && branch_ts <= merge_commit[:timestamp]

  mb = merge_base(target, branch)
  branch_files = changed_files_between(mb, branch)
  merge_files = changed_files_between("#{merge_sha}^1", merge_sha)
  !branch_files.empty? && (branch_files - merge_files).empty?
end

def deleted_branch_tip_from_reflog(branch_name_prefix, descendant_branch = nil)
  escaped = Regexp.escape(branch_name_prefix)
  patterns = [
    /\brebase.*: checkout #{escaped}/,
    /\bcheckout: moving from .+ to #{escaped}/
  ]

  reflog_cmd = [
    "git", "reflog", "--format=%H %gs", "--grep-reflog=checkout.*#{branch_name_prefix}", "--grep-reflog=rebase.*#{branch_name_prefix}"
  ]

  IO.popen(reflog_cmd) do |io|
    io.each_line do |line|
      sha, description = line.strip.split(" ", 2)
      next unless description
      next unless patterns.any? { |p| description.match?(p) }
      next if descendant_branch && !branch_merged_into?(sha, descendant_branch)

      return sha
    end
  end

  nil
end

def branch_distance_map(parent_branch, branches)
  @branch_distance_cache ||= {}

  missing = branches.uniq.reject { |branch| @branch_distance_cache.key?("#{branch}:#{parent_branch}") }
  return if missing.empty?

  missing_set = missing.to_h { |branch| [branch, true] }
  distances = {}

  output = `git for-each-ref --format='%(refname:short) %(ahead-behind:#{parent_branch})' refs/heads/`
  if Process.last_status.success?
    output.lines.each do |line|
      branch, ahead, behind = line.split
      next unless branch && ahead && behind
      next unless missing_set[branch]

      distances[branch] = ahead.to_i
    end
  end

  missing.each do |branch|
    key = "#{branch}:#{parent_branch}"
    @branch_distance_cache[key] = distances.fetch(branch) do
      `git rev-list --count #{parent_branch}..#{branch}`.strip.to_i
    end
  end
end

def branch_distance(branch, parent_branch)
  @branch_distance_cache ||= {}
  key = "#{branch}:#{parent_branch}"
  return @branch_distance_cache[key] if @branch_distance_cache.key?(key)

  @branch_distance_cache[key] = `git rev-list --count #{parent_branch}..#{branch}`.strip.to_i
end

def sort_rebase_mappings(mappings, default_branch)
  ordered = mappings.sort_by { |b| [branch_distance(b[:branch], default_branch), branch_sort_key(b)] }
  by_branch = ordered.to_h { |b| [b[:branch], b] }
  visited = Set.new
  visiting = Set.new
  result = []

  visit = lambda do |entry|
    branch = entry[:branch]
    return if visited.include?(branch) || visiting.include?(branch)

    visiting << branch
    parent = by_branch[entry[:rebase_onto]]
    visit.call(parent) if parent && parent[:branch] != branch
    visiting.delete(branch)
    visited << branch
    result << entry
  end

  ordered.each { |entry| visit.call(entry) }
  result
end

def rebase_all
  require "json"
  default_branch = compute_default_branch
  mappings = sort_rebase_mappings(rebase_mappings, default_branch)
    .to_h { |b| [b[:branch], b.slice(:rebase_onto, :fork_point, :squash_merged, :ambiguous_parents)] }
  exit(1) if rebase_all_per_capture_info(mappings) == false
end

def git_push_issue(*args)
  args = ARGV if args.empty?

  current_branch = `git branch --show-current`.strip

  user_name = ENV.fetch("USER", nil)
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
      puts "  Skipping since ".red + parent_branch.green + " does not exist.".red
      next
    end

    branches << branch
  end

  return unless branches.any?

  active_remote_name = `git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null`.split("/").first

  puts "Pushing ".brown + branches.map(&:cyan).join(", ") + " to ".brown + active_remote_name.green + "...".brown

  exit(1) unless system(*%W[git push --force-with-lease #{active_remote_name}], *branches, *args)
end

def changed_branch_files(format: nil)
  current_branch = `git branch --show-current`.strip
  parent_branch = compute_parent_branch(current_branch)

  change_log = `git diff --diff-filter=AM -U0 #{parent_branch}..#{current_branch} | grep -E '^(---|\\+\\+\\+|@@)'`.lines
  changed_files =
    change_log.reject { |line| line.start_with?("@@") } # discard diff header
      .map { |line| line.slice(4..-1).chomp }
      .reject { |file| file == File::NULL } # discard deletions
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
