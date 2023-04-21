#!/usr/bin/env ruby
# frozen_string_literal: true

require 'English'

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
              bot
              state
              status {
                availability
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
        c.dig(*%w[assignedMergeRequests count]),
        c.dig(*%w[reviewRequestedMergeRequests count])
      ]
    end
end

def pick_reviewer(candidates)
  require 'terminal-table'

  candidates = filter_sort_reviewers(candidates)

  puts "Chosen reviewer: @#{candidates.first['username']}"
  puts

  puts Terminal::Table.new(
    title: 'Reviewers',
    headings: ['Username', 'Availability', 'Assigned MRs', 'Requested MR reviews'],
    rows: candidates.map do |c|
      availability = c.dig(*%w[status availability])
      assigned_count = c.dig(*%w[assignedMergeRequests count])
      requested_count = c.dig(*%w[reviewRequestedMergeRequests count])
      ["@#{c['username']} (#{c['name']})", availability, assigned_count, requested_count]
    end
  )

  nil
end

def pick_reviewer_for_group(group_path)
  pick_reviewer(retrieve_group_owners(group_path))
end

def retrieve_mrs
  require('json')

  res = `glab api graphql -f query='
    query authoredMergeRequests {
      currentUser {
        authoredMergeRequests(state: opened, sort: UPDATED_DESC) {
          nodes {
            reference
            webUrl
            title
            createdAt
            updatedAt
            approved
            approvalsRequired
            approvalsLeft
            detailedMergeStatus
            squashOnMerge
            reviewers {
              nodes {
                username
              }
            }
            headPipeline {
              status
            }
          }
        }
      }
    }
  '`
  return if $CHILD_STATUS != 0

  mrs = JSON.parse(res).dig(*%w[data currentUser authoredMergeRequests nodes])

  require 'terminal-table'
  require 'time'

  Terminal::Table::Style.defaults = { border: :unicode_round }
  pipeline_aliases = { 'SUCCESS' => '✅', 'FAILED' => '❌', 'RUNNING' => '🔄' }
  any_rebase = mrs.any? { |mr| mr['shouldBeRebased'] }
  headings = ['Reference', 'Updated', 'Merge status', 'Pipeline', 'Squash']
  headings << 'Should rebase' if any_rebase
  headings += ['Approvals', 'Reviewers', 'Title/URL']

  puts Terminal::Table.new(
    title: 'Merge requests'.blue,
    headings: headings.map(&:green),
    rows: mrs.map do |mr|
      updated_at = Time.parse(mr['updatedAt'])
      title = mr['title']
      merge_status = mr['detailedMergeStatus']
      squash = mr['squashOnMerge'] ? '✔️' : '❌'
      should_be_rebased = mr['shouldBeRebased'] ? 'Y' : ''
      approvals_left = mr['approvalsLeft']
      approvals_required = mr['approvalsRequired']
      pipeline_status = mr.dig(*%w[headPipeline status])
      reviewers = mr.dig(*%w[reviewers nodes]).map { |node| node['username'] }

      row = [
        mr['reference'],
        updated_at,
        merge_status,
        pipeline_aliases.fetch(pipeline_status, pipeline_status),
        { value: squash, alignment: :center }
      ]
      row << should_be_rebased if any_rebase
      row + [
        { value: "#{approvals_required - approvals_left}/#{approvals_required}", alignment: :right },
        reviewers.map(&:cyan).join("\n"),
        "#{title}\n  #{mr['webUrl'].green}\n "
      ]
    end
  )

  nil
end
