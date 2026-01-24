#!/usr/bin/env ruby
# frozen_string_literal: true

require "English"

REJECTED_LABELS = /^(workflow:|missed:|estimate:|Effort:|\[Deprecated|auto updated).*/

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

  def truncate(length, options = {})
    text = dup
    options[:omission] ||= "…"

    length_with_room_for_omission = length - options[:omission].length

    ((chars.length > length) ? trim(text, length_with_room_for_omission, options) : text).to_s
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

def graphql_execute(query, **kwargs)
  `op plugin run -- glab api graphql -f query='#{query}' #{kwargs.map { |k, v| "--field #{k}='#{v}'" }.join(" ")}`
end

BASELINE_MR_RATE = 13

def gitlab_mr_rate(*author)
  author = ARGV[0] if author.empty?

  require "date"
  require "json"

  mrs = []
  start_cursor = nil
  best_month = nil
  best_month_mr_rate = 0
  total_time_to_merge = 0
  $stderr.print "Fetching "

  loop do
    $stderr.putc "."

    res = graphql_execute(<<~GQL, groupPath: "gitlab-org", author: author, after: start_cursor, createdAfter: "2020-01-27")
      query($groupPath: ID!, $author: String!, $after: String, $createdAfter: Time) {
        group(fullPath: $groupPath) {
          mergeRequests(
            authorUsername: $author,
            state: merged,
            includeSubgroups: true,
            createdAfter: $createdAfter,
            after: $after
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
      }
    GQL
    return if $CHILD_STATUS != 0

    json_res = JSON.parse(res)
    merge_requests = json_res.dig("data", "group", "mergeRequests")
    mrs +=
      merge_requests["nodes"]
        .select { |mr| mr["mergedAt"] }
        .map do |mr|
        {merged_at: DateTime.iso8601(mr["mergedAt"])}
      rescue
        $stderr.print "\n#{mr}\n"
        raise
      end

    total_time_to_merge = merge_requests["totalTimeToMerge"]
    page_info = merge_requests["pageInfo"]
    break unless page_info["hasNextPage"]

    start_cursor = page_info["endCursor"]
  end

  puts
  now = DateTime.now
  mrs_merged_by_month = mrs
    .sort_by { |mr| now - mr[:merged_at] }
    .group_by { |mr| [now, DateTime.civil(mr[:merged_at].year, mr[:merged_at].month, -1)].min }
  mrs_merged_by_month.reverse_each do |ym, monthly_mrs|
    prorated_mr_count = monthly_mrs.count
    if ym.year == now.year && ym.month == now.month
      prorated_mr_count = monthly_mrs.count.to_f / ym.day * DateTime.civil(ym.year, ym.month, -1).day
      indicator = " (in progress - #{prorated_mr_count.to_i} prorated)"
    end

    if monthly_mrs.count > best_month_mr_rate
      best_month = ym
      best_month_mr_rate = monthly_mrs.count
    end

    msg = "#{ym.strftime("%Y-%m")}: #{monthly_mrs.count.to_s.rjust(3)}\t#{"▁" * monthly_mrs.count}"

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

  puts "-" * 12
  msg = "Average MRs merged per month: #{monthly_average.round}"
  if monthly_average > BASELINE_MR_RATE
    puts msg.green
  else
    puts msg.red
  end
  puts "Average per MR: #{(total_time_to_merge / (60 * 60 * 24) / mrs.count).round(1)} days"
  puts "Total MRs merged: #{mrs.count}"
  puts "Best month: #{best_month.strftime("%Y-%m")} (#{best_month_mr_rate} MRs)"
end

def gpsup(remote, issue_iid)
  require "date"

  res = graphql_execute(<<~GQL)
    query issueLabels {
      project(fullPath: "gitlab-org/gitlab") {
        group {
          milestones(sort: DUE_DATE_DESC, containingDate: "#{Date.today}") {
            nodes {
              title
            }
          }
        }
        issue(iid: "#{issue_iid}") {
          labels {
            nodes {
              title
            }
          }
        }
      }
    }
  GQL

  require "json"
  milestone = nil
  labels = []
  if $CHILD_STATUS == 0
    json_res = JSON.parse(res)
    milestone = json_res.dig(*%w[data project group milestones nodes])
      .map { |h| h["title"] }
      .find { |title| title.match?(/^[0-9]+\.[0-9]+/) }
    labels = json_res.dig(*%w[data project issue labels nodes])
      &.map { |h| h["title"] }
      &.reject { |label| label.match?(REJECTED_LABELS) }
  end

  require_relative "git-helpers"
  branch = `git rev-parse --abbrev-ref HEAD`.strip
  parent_branch = compute_parent_branch(branch)
  options = [
    "create",
    "squash",
    "target='#{parent_branch}'",
    "assign='#{ENV.fetch("USER", nil)}'",
    "label='Category:Fleet Visibility'",
    "label='section::ci'",
    "label='devops::verify'",
    "label='group::ci platform'"
  ] + (labels&.map { |label| "label='#{label}'" } || [])
  options << "milestone='#{milestone}'" if milestone
  cmd = <<~SHELL.lines(chomp: true).join(" ")
    git push --set-upstream "#{remote}" "#{branch}" #{options.uniq.map { |option| "-o merge_request.#{option}" }.join(" ")} #{ARGV.join(" ")}
  SHELL

  puts cmd
  system(cmd)
end
