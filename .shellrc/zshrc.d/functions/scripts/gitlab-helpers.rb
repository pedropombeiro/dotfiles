#!/usr/bin/env ruby
# frozen_string_literal: true

require 'English'
require 'tty-link'

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

  def with_hyperlink(url)
    ' ' * (length - lstrip.length) + TTY::Link.link_to(strip, url) + ' ' * (length - rstrip.length)
  end

  def truncate(length, options = {})
    text = dup
    options[:omission] ||= '…'

    length_with_room_for_omission = length - options[:omission].length

    (chars.length > length ? trim(text, length_with_room_for_omission, options) : text).to_s
  end

  private

  def trim(text, length_with_room_for_omission, options)
    stop = if options[:separator]
             text.rindex(options[:separator], length_with_room_for_omission) || length_with_room_for_omission
           else
             length_with_room_for_omission
           end

    text[0...stop] + options[:omission]
  end
end

BASELINE_MR_RATE = 13

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

    res = `op plugin run -- glab api graphql -f query='
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
    return if $CHILD_STATUS != 0

    json_res = JSON.parse(res)
    merge_requests = json_res.dig('data', 'group', 'mergeRequests')
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

    msg = "#{ym.strftime('%Y-%m')}: #{monthly_mrs.count.to_s.rjust(3)}\t#{'▁' * monthly_mrs.count}"

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

def retrieve_group_owners(group_path)
  require('json')

  res = `op plugin run -- glab api graphql -f query='
    query groupMembers($fullPath: ID!) {
      group(fullPath: $fullPath) {
        groupMembers(accessLevels: [OWNER]) {
          nodes {
            user {
              name
              username
              webUrl
              bot
              state
              status {
                availability
                message
              }
              reviewRequestedMergeRequests(state: opened) {
                count
              }
              assignedMergeRequests(state: opened) {
                count
              }
            }
          }
        }
      }
    }
  ' --field fullPath="#{group_path}"`
  return if $CHILD_STATUS != 0

  JSON.parse(res).dig(*%w[data group groupMembers nodes]).map { |v| v['user'] }
end

def filter_sort_reviewers(candidates)
  candidates
    .reject { |c| c['bot'] || c['username'].include?('-bot') }
    .filter { |c| c['state'] == 'active' }
    .sort_by do |c|
      [
        c.dig('status', 'availability') == 'BUSY' ? 1 : 0,
        c.dig('status', 'message') ? 1 : 0,
        c.dig('assignedMergeRequests', 'count'),
        c.dig('reviewRequestedMergeRequests', 'count')
      ]
    end
end

def pick_reviewer(candidates)
  require 'tty-table'

  candidates = filter_sort_reviewers(candidates)

  candidate = candidates.first
  puts "Chosen reviewer: @#{candidate['username'].with_hyperlink(candidate['webUrl'])}"
  puts

  table = TTY::Table.new(
    header: ['Username', 'Availability', 'Message', 'Assigned MRs', 'Requested MR reviews'].map(&:green),
    rows: candidates.map do |c|
      availability = c.dig('status', 'availability')
      message = c.dig('status', 'message')
      assigned_count = c.dig('assignedMergeRequests', 'count')
      requested_count = c.dig('reviewRequestedMergeRequests', 'count')
      [
        "@#{c['username']}",
        availability,
        message,
        { value: assigned_count, alignment: :right },
        { value: requested_count, alignment: :right }
      ]
    end
  )
  render =
    table.render(:unicode, padding: [0, 1]) do |renderer|
      renderer.filter = lambda { |val, row_index, col_index|
        next val if row_index.zero?

        candidate = candidates[row_index - 1]
        case col_index
        when 0
          val.with_hyperlink(candidate['webUrl'])
        else
          val
        end
      }
    end
  puts render

  nil
end

def pick_reviewer_for_group(group_path)
  pick_reviewer(retrieve_group_owners(group_path))
end

def format_reviewer_name(name, count)
  max_length = 22

  name = name.truncate(max_length / count) if count > 1

  name.cyan
end

def retrieve_mrs(*args)
  username = ARGV[0] if args.empty?

  require 'date'
  require 'json'

  res = `op plugin run -- glab api graphql -f query='
    query authoredMergeRequests {
      user(username: "#{username}") {
    authoredMergeRequests(state: opened, assigneeUsername: "#{username}", sort: UPDATED_DESC) {
          nodes {
            reference
            webUrl
            title
            sourceBranch
            createdAt
            updatedAt
            approved
            approvalsRequired
            approvalsLeft
            autoMergeEnabled
            detailedMergeStatus
            squashOnMerge
            conflicts
            reviewers {
              nodes {
                username
                webUrl
              }
            }
            headPipeline {
              path
              status
              startedAt
              finishedAt
              failedJobs: jobs(statuses: FAILED, retried: false) {
                count
              }
            }
          }
        }
      }
    }
  '`
  return if $CHILD_STATUS != 0

  if res.start_with?('glab:')
    puts res
    exit 1
  end

  mrs = JSON.parse(res).dig(*%w[data user authoredMergeRequests nodes])
  unless mrs
    puts res
    exit 1
  end

  require 'tty-table'
  require 'time'

  pipeline_aliases = { 'SUCCESS' => '✔︎'.green, 'FAILED' => '‼'.red, 'RUNNING' => '▶︎'.brown }
  merge_status_aliases = { 'CI_STILL_RUNNING' => 'CI_STILL_RUNNING'.green }
  any_rebase = mrs.any? { |mr| mr['shouldBeRebased'] }
  any_conflicts = mrs.any? { |mr| mr['conflicts'] }
  headings = ['Reference'.truncate(7), 'Merge status']
  pipeline_col_index = headings.count
  headings += %w[Pipeline Squash]
  headings << 'Should rebase' if any_rebase
  headings << 'Conflicts' if any_conflicts
  headings += ['Approvals'.truncate(5), 'Reviewers', 'Title', 'Source branch']
  reviewers_col_index = headings.count - 3
  title_col_index = headings.count - 2

  table = TTY::Table.new(
    header: headings.map(&:green),
    rows: mrs.map do |mr|
      title = mr['title'].truncate(69)
      merge_status = merge_status_aliases.fetch(mr['detailedMergeStatus'], mr['detailedMergeStatus'])
      merge_status += ' 🚀' if mr['autoMergeEnabled']
      merge_status.truncate(21)
      squash = mr['squashOnMerge'] ? '✔︎'.green : '⨯'.red
      conflicts = mr['conflicts'] ? '⨯'.red : '✔︎'.green
      should_be_rebased = mr['shouldBeRebased'] ? 'Y' : ''
      approved = mr['approved']
      approvals_left = mr['approvalsLeft']
      approvals_required = mr['approvalsRequired']
      pipeline_status = mr.dig('headPipeline', 'status')
      pipeline_started_at = mr.dig('headPipeline', 'startedAt')
      pipeline_finished_at = mr.dig('headPipeline', 'finishedAt')
      pipeline_started_at = DateTime.parse(pipeline_started_at) if pipeline_started_at
      pipeline_finished_at = DateTime.parse(pipeline_finished_at) if pipeline_finished_at
      pipeline_duration = pipeline_finished_at || pipeline_started_at.nil? ? nil : (DateTime.now - pipeline_started_at).to_f * 24 * 60 * 60
      pipeline_age = pipeline_finished_at ? (DateTime.now - pipeline_finished_at).to_f * 24 * 60 * 60 : nil
      pipeline_failed_jobs = mr.dig('headPipeline', 'failedJobs', 'count').to_i
      reviewers = mr.dig('reviewers', 'nodes').map { |reviewer| reviewer['username'] }

      row = [
        mr['reference'],
        merge_status,
        [
          pipeline_aliases.fetch(pipeline_status, pipeline_status) || '??',
          pipeline_failed_jobs.positive? ? '⨯'.red : nil,
          pipeline_duration ? "(#{(pipeline_duration / 60).round} mins)" : nil,
          pipeline_age && pipeline_age > 8 * 60 * 60 ? '🥶' : nil
        ].compact.join(' '),
        { value: squash, alignment: :center }
      ]
      row << should_be_rebased if any_rebase
      row << conflicts if any_conflicts
      row + [
        { value: approved ? '✔︎'.green : "#{approvals_required - approvals_left}/#{approvals_required}",
          alignment: :right },
        reviewers.map { |name| format_reviewer_name(name, reviewers.count) }.join(', '),
        title,
        mr['sourceBranch'].truncate(50).green
      ]
    end
  )

  render =
    table.render(:unicode, width: 1000, padding: [0, 1]) do |renderer|
      renderer.filter = lambda { |val, row_index, col_index|
        next val if row_index.zero?

        mr = mrs[row_index - 1]
        case col_index
        when 0
          val.with_hyperlink(mr['webUrl'])
        when pipeline_col_index
          if mr.dig('headPipeline', 'path')
            val.with_hyperlink("https://gitlab.com#{mr.dig('headPipeline', 'path')}")
          else
            val
          end
        when reviewers_col_index
          reviewers = mr.dig('reviewers', 'nodes')
          new_val = reviewers.map do |reviewer|
            format_reviewer_name(reviewer['username'], reviewers.count).with_hyperlink(reviewer['webUrl'])
          end.join(', ')

          " #{new_val}#{' ' * (val.length - val.strip.length - 1)}"
        when title_col_index
          val.with_hyperlink(mr['webUrl'])
        else
          val
        end
      }
    end
  puts render
  puts "#{mrs.count} merge request(s)"

  nil
end
