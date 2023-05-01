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
    stop = if options[:separator]
             (text.rindex(options[:separator], length_with_room_for_omission) || length_with_room_for_omission)
           else
             length_with_room_for_omission
           end

    (chars.length > length ? text[0...stop] + options[:omission] : text).to_s
  end
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
    return if $CHILD_STATUS != 0

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

def retrieve_group_owners(group_path)
  require('json')

  res = `glab api graphql -f query='
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
        c.dig(*%w[status availability]) == 'BUSY' ? 1 : 0,
        c.dig(*%w[status message]) ? 1 : 0,
        c.dig(*%w[assignedMergeRequests count]),
        c.dig(*%w[reviewRequestedMergeRequests count])
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
      availability = c.dig(*%w[status availability])
      message = c.dig(*%w[status message])
      assigned_count = c.dig(*%w[assignedMergeRequests count])
      requested_count = c.dig(*%w[reviewRequestedMergeRequests count])
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

def retrieve_mrs(*args)
  username = ARGV[0] if args.empty?

  require('json')

  res = `glab api graphql -f query='
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
            }
          }
        }
      }
    }
  '`
  return if $CHILD_STATUS != 0

  mrs = JSON.parse(res).dig(*%w[data user authoredMergeRequests nodes])
  unless mrs
    puts res
    exit 1
  end

  require 'tty-table'
  require 'time'

  pipeline_aliases = { 'SUCCESS' => '✅', 'FAILED' => '❌', 'RUNNING' => '🔄' }
  any_rebase = mrs.any? { |mr| mr['shouldBeRebased'] }
  any_conflicts = mrs.any? { |mr| mr['conflicts'] }
  headings = ['Ref.', 'Merge status']
  pipeline_col_index = headings.count
  headings += %w[Pipeline Squash]
  headings << 'Should rebase' if any_rebase
  headings << 'Conflicts' if any_conflicts
  headings += ['Appr.', 'Reviewers', 'Title', 'Source branch']
  reviewers_col_index = headings.count - 3
  title_col_index = headings.count - 2

  table = TTY::Table.new(
    header: headings.map(&:green),
    rows: mrs.map do |mr|
      title = mr['title'].truncate(72)
      merge_status = mr['detailedMergeStatus']
      squash = mr['squashOnMerge'] ? '✔️' : '❌'
      conflicts = mr['conflicts'] ? '❌' : '✔️'
      should_be_rebased = mr['shouldBeRebased'] ? 'Y' : ''
      approvals_left = mr['approvalsLeft']
      approvals_required = mr['approvalsRequired']
      pipeline_status = mr.dig(*%w[headPipeline status])
      reviewers = mr.dig(*%w[reviewers nodes]).map { |reviewer| reviewer['username'] }

      row = [
        mr['reference'],
        merge_status,
        pipeline_aliases.fetch(pipeline_status, pipeline_status),
        { value: squash, alignment: :center }
      ]
      row << should_be_rebased if any_rebase
      row << conflicts if any_conflicts
      row + [
        { value: "#{approvals_required - approvals_left}/#{approvals_required}", alignment: :right },
        reviewers.map(&:cyan).join(', '),
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
          val.with_hyperlink("https://gitlab.com#{mr.dig('headPipeline', 'path')}")
        when reviewers_col_index
          reviewers = mr.dig(*%w[reviewers nodes])
          new_val = reviewers.map do |reviewer|
            reviewer['username'].cyan.with_hyperlink(reviewer['webUrl'])
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

  nil
end
