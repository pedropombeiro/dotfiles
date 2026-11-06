---
name: esquery
description: Query GitLab's Elasticsearch log clusters (the data behind Kibana at log.gprd.gitlab.net and nonprod-log.gitlab.net) from the command line with the `esquery` CLI, authenticated with the Kibana Okta SSO session. Use when the user wants to search, count, aggregate, or export `pubsub-*` indices (Rails, Sidekiq, Gitaly, Workhorse, runner, GCP audit logs, ...), or asks to "reproduce what I'd do in Kibana" programmatically.
---

# esquery

`esquery` runs counts, aggregations, and bulk exports (sliced scroll) against GitLab's pubsub log indices.
Source: `~/code/esquery` (<https://gitlab.com/gitlab-com/gl-infra/esquery>). Install or update from the checkout with `cd ~/code/esquery && git pull && go install .`, or without a checkout with `go install gitlab.com/gitlab-com/gl-infra/esquery@latest`.

## Version

This skill describes esquery **1.11.0 or later**. Older versions have no `--async` / `--async-timeout` flags and no MCP `async` argument (see Long-running queries). Run `esquery version` before the first query:

- Below 1.11.0, or `unknown command "version"`: update with one of the commands above, run `esquery version` again, and tell the user you updated it. If the update fails (no Go toolchain, no network), say so and don't use `--async`.
- `dev`: a build without version information. `esquery count --help | grep -- --async` shows whether it supports async.
- A running `esquery mcp` server keeps using the binary it started with. After an update, ask the user to restart it (in pi, reload the MCP server) before relying on `async`.

## RED data

Production logs are RED data. Do not disclose them.

## Auth

Point esquery at Kibana and it uses your Kibana SSO session:

```bash
export KIBANA_URL=https://log.gprd.gitlab.net      # staging/nonprod: https://nonprod-log.gitlab.net
```

Requests go through Kibana's Dev Tools console proxy as the logged-in user. The session cookie is stored in `~/.config/esquery/sessions.json`. When none is stored, or Kibana rejects the stored one, esquery takes the current `sid` cookie from Chrome, Chromium, Arc (macOS) or Firefox (any profile) and retries, so normally there is nothing to do. `--browser chrome` or `--browser firefox` (or `ESQUERY_BROWSER`) limits that to one browser, `--chrome-profile <name>` (or `ESQUERY_CHROME_PROFILE`) to one Chrome profile.

If no browser has a valid Kibana session either, queries fail with `log in to ... in your browser or run esquery login`. Ask the user to run `esquery login`, which opens Kibana in the default browser (or the `--chrome-profile` profile) and waits for the Okta sign-in. Don't run it yourself unless asked: it opens a browser window and may show a Keychain prompt. For other browsers or headless machines: copy the `sid` cookie from the browser's developer tools into a file, then `esquery login --sid-stdin < file`.

Kibana sessions expire after 3 days without use.

With Elasticsearch credentials you can skip Kibana: `export ELASTICSEARCH_URL='https://<user>:<pw>@<host>:9243'`. `KIBANA_URL` / `--kibana-url` takes precedence when both are set.

For a GitLab Dedicated tenant, `--dedicated-tenant <name>` (or `ESQUERY_DEDICATED_TENANT`) queries its OpenSearch with the read-only credentials from 1Password (vault "GitLab Dedicated  - Support"). The name selects the one "read only opensearch" item whose title contains it, for example `eligible_pink_eel`. The 1Password CLI must be signed in (`eval $(op signin)`), otherwise queries fail with `1Password CLI is not signed in`. On tenants, `esql` is unavailable, indices are daily (`gitlab-YYYY-MM-DD`, about a week of retention), log fields are `manager.*` for runner managers, `fleeting.*` for autoscaled VMs, and `fluentd_tag.keyword` tells the streams apart. Tenant logs are RED data too.

Smoke test:

```bash
esquery count --index 'pubsub-rails-inf-gprd*' \
  --query '{"range":{"@timestamp":{"gte":"now-5m"}}}'   # prints a number
```

## Subcommands

| Command | Use for |
| --- | --- |
| `esquery count` | How many docs match this query? |
| `esquery search` | Aggregations (terms, stats, histograms). Default output is `agg`. |
| `esquery scroll` | Export every matching doc as line-delimited JSON, via sliced scroll. |
| `esquery esql` | ES\|QL queries. The query names its index. Formats: `tsv` (default), `csv`, `json`, `rows` (objects keyed by column). `--param name=value` fills `?name` (value) and `??name` (field name) in the query. |
| `esquery determine-shard-count` | Most common shard count of an index pattern, to pick `--slices`. |
| `esquery fields` | Field names and types of an index pattern, merged across its indices. |
| `esquery login` | Store a Kibana session (see Auth). |
| `esquery mcp` | The same as an MCP server over stdio, see below. |

Common flags:

- `--index '<pattern>'`, e.g. `pubsub-rails-inf-gprd*`.
- `--query '<JSON>'`: an ES query clause (the part inside `"query":`). Can also be piped on stdin.
- `--aggs '<JSON>'`: `search` only.
- `--output source|hit|full|agg`: `source` is the default for `scroll`, `agg` for `search`. `hit` adds `_id` and `_index`, and `full` includes `_shards`.
- `--source-include` / `--source-exclude`: comma-separated fields, to keep exports small.
- `--slices N`: `scroll` parallelism (default 4). Match it to the shard count for maximum throughput.
- `--only-slice K`: run just slice `K`, for external parallelisation.
- `--async`: `count` and `search` only. Run as an async search for queries that outlive the Kibana proxy (see Long-running queries).
- `--async-timeout D`: with `--async`, how long to wait before deleting the search and failing (default `10m`, `0` for no limit).
- `--verbose` / `--debug`: log requests / full HTTP traffic.

## Indices

| Pattern | Contents |
| --- | --- |
| `pubsub-rails-inf-gprd*` | GitLab Rails application logs |
| `pubsub-sidekiq-inf-gprd*` | Sidekiq workers |
| `pubsub-gitaly-inf-gprd*` | Gitaly |
| `pubsub-workhorse-inf-gprd*` | Workhorse |
| `pubsub-kas-inf-gprd*` | KAS |
| `pubsub-runner-inf-gprd*` | `gitlab-runner` and `docker-machine` on runner managers |
| `pubsub-gcp-events-inf-gprd*` | GCP audit / activity logs (authoritative for "did GCP accept this call?") |
| `pubsub-nginx-inf-gprd*` | NGINX / HAProxy access logs |

Staging indices use `gstg` instead of `gprd` and live on `nonprod-log.gitlab.net`. The full list is in Kibana under Stack Management, Data Views.

The indices are data streams: put the `*` right after the name. `pubsub-rails-inf-gprd-*` matches nothing.

Fields live under `json.*`. Filter time windows on `@timestamp`. `json.time` or `json.timestamp` is the application's own time. Use the `.keyword` subfield for exact matches and aggregations (`json.shard.keyword`), and `match_phrase` or `query_string` for text.

Cluster facts from the ci-runners [gitlab-elasticsearch skill](https://gitlab.com/gitlab-com/gl-infra/ci-runners/agents/-/blob/main/skills/gitlab-elasticsearch/SKILL.md), which has more:

- `pubsub-runner-inf-gprd*` holds runner manager logs from four environments (gprd-ci, dev-ci, ops-ci, gstg-ci), and their pods share deployment names. Split by `json.environment`, `kubernetes.host`, or `json.runner` before comparing pods or fleets.
- `pubsub-puma-inf-gprd*` matches no documents. Puma output is in the Rails index under `json.subcomponent.keyword: "puma.stderr"`.
- In the Rails index, `json.subcomponent.keyword` separates log types (`production_json`, `api_json`, `sidekiq_client`, ...), and the route or controller is `json.meta.caller_id.keyword`.
- Runner `Job succeeded` / `Job failed` events have `json.duration_s`, `json.job` (build ID) and `json.name` (VM).

## Query pitfalls

- A zero count is ambiguous until you rerun it without the narrowing filters. Several mistakes below return 0 on data that exists.
- `term` filters and `terms` aggregations on `text` fields (e.g. `json.shard`) match nothing. Use `.keyword`.
- Two wildcards in one `query_string` term (`json.msg:*selections*failed*`) match nothing. Use `match_phrase` or AND two single-wildcard clauses.
- The analyzer splits on underscores, so `match_phrase` on `ZONE_RESOURCE_POOL_EXHAUSTED` undercounts badly. Use a wildcard `query_string` for such tokens.
- Over long ranges, check `_shards.failed` (`esquery search --output full | jq ._shards`) before trusting a count.
- Heavy responses can fail with a 502 from the load balancer. Lower `--size` and trim fields with `--source-include`. A 502 that arrives after about 60 seconds is different: the request outlived the Kibana proxy, and the search may still be running on the cluster. Don't retry it in a loop or split the window into many small queries. Run it once with `--async` (see Long-running queries).

## Long-running queries

The Kibana proxy drops a request after about 60 seconds. Multi-day windows and data more than a few days old often take longer, even with narrow `.keyword` filters. `count --async` and `search --async` (esquery 1.11.0 or later, see Version) run as an Elasticsearch async search instead, the way Kibana Discover does. The output is the same as without the flag.

```bash
esquery search --async --index 'pubsub-sidekiq-inf-gprd*' \
  --query '{"bool":{"filter":[{"range":{"@timestamp":{"gte":"now-7d"}}},{"term":{"json.class_name.keyword":"Some::Class"}}]}}' \
  --aggs '{"per_day":{"date_histogram":{"field":"@timestamp","calendar_interval":"day"}}}'
```

- A search that finishes within a second returns as usual and isn't stored. Otherwise esquery polls (each request waits up to 20 seconds) and prints progress to stderr: `esquery: async search running for 40s, 938 of 1260 shards reported`. All shards can report while the search is still reducing, so don't read that as nearly done.
- `--async-timeout` defaults to `10m`. When it runs out, esquery deletes the search and exits with an error that says to narrow the query or raise the limit. It returns no partial results. Narrowing the query is usually the better fix. Use `--async-timeout 0` (no limit) only when the user agrees that a long-running query is worth it.
- The search is deleted on exit, including after an error, a timeout or Ctrl-C. A process killed outright leaves it running for up to 5 more minutes.
- One async search with aggregations (`date_histogram` per day, `terms`, `cardinality`, `min`/`max` on `@timestamp`) is cheaper than a loop of day-sized counts, and gives the breakdown at the same time. Use `"size": 0` unless you need sample documents.
- Async search only avoids the proxy timeout. The query costs the cluster just as much.
- Not available with `--dedicated-tenant` (OpenSearch).

## Patterns

Count in a window:

```bash
esquery count --index 'pubsub-rails-inf-gprd*' \
  --query '{"range":{"@timestamp":{"gte":"2026-04-20T14:30:00Z","lte":"2026-04-20T17:30:00Z"}}}'
```

Filter and aggregate:

```bash
esquery search --index 'pubsub-runner-inf-gprd*' \
  --query '{"bool":{"must":[
    {"range":{"@timestamp":{"gte":"now-1h"}}},
    {"query_string":{"query":"json.level:error AND *ZONE_RESOURCE_POOL_EXHAUSTED*"}}
  ]}}' \
  --aggs '{"by_host":{"terms":{"field":"json.hostname.keyword","size":20}}}'
```

Nested terms (group by several fields):

```bash
--aggs '{"by_shard":{"terms":{"field":"json.shard.keyword","size":30},
  "aggs":{"by_host":{"terms":{"field":"json.hostname.keyword","size":15}}}}}'
```

Stats and percentiles:

```bash
--aggs '{"dur":{"stats":{"field":"json.duration_s"}},
         "pct":{"percentiles":{"field":"json.duration_s","percents":[50,95,99]}}}'
```

Export matching docs:

```bash
esquery scroll --index 'pubsub-rails-inf-gprd*' --slices "$(esquery determine-shard-count --index 'pubsub-rails-inf-gprd*')" \
  --source-include '@timestamp,json.correlation_id,json.message' \
  --query '{"bool":{"must":[
    {"range":{"@timestamp":{"gte":"now-15m"}}},
    {"match_phrase":{"json.message":"ActiveRecord::StatementInvalid"}}
  ]}}' \
  | jq -r '[."@timestamp", .json.correlation_id, .json.message] | @tsv'
```

Reproduce a Kibana search: in Discover open Inspect, Request, copy the JSON body, then:

```bash
jq .query kibana-inspect.json | esquery scroll --index '<pattern>'
```

Parallelise across processes:

```bash
seq 0 8 | parallel "esquery scroll --index 'pubsub-rails-inf-gprd*' --slices 9 --only-slice {} --query '$QUERY' | wc -l"
```

ES|QL, for quick grouped counts without JSON quoting. Put values the user gave you in `--param`, not in the query text, so a quote in a value cannot change the query:

```bash
esquery esql --query 'FROM pubsub-rails-inf-gprd* | WHERE @timestamp > NOW() - 15 minutes AND json.status >= ?status | STATS n = COUNT(*) BY ??group | SORT n DESC | LIMIT 20' \
  --param status=500 --param group=json.meta.caller_id.keyword
```

ES|QL returns at most 10000 rows, and a higher `LIMIT` is reduced to that without any warning (upstream: elastic/elasticsearch#161965). Treat a result of exactly 10000 rows as cut off. Without a `LIMIT` the default is 1000, which Elasticsearch does warn about, and esquery prints that warning on stderr. For every document, use `esquery scroll`.

`?name` stands for a value, `??name` for a field or function name. A value that is valid JSON (`500`, `true`, `"x"`) is sent as that type, anything else as a string.

Unsure of field names? Ask the cluster, not a reference table, because mappings change with the index templates:

```bash
esquery fields --index 'pubsub-gitaly-inf-gprd*' --field 'json.grpc.*'
```

One line per field and type: name, type, aggregatable. `text` fields are for `match_phrase`. Aggregate and filter on the `keyword` ones. A field that appears twice with different types is mapped inconsistently across the indices, and the fourth column says in how many. A `range` or `terms` on it fails on the indices with the other type. By default only indices with data in the last day are read (`--since`).

## MCP

When the `esquery` MCP server is registered in pi (`pi mcp add esquery --env KIBANA_URL=https://log.gprd.gitlab.net -- ~/go/bin/esquery mcp`), the same operations are available from codemode as `mcp__esquery__count`, `search`, `esql`, `export`, `list_indices`, `list_fields` and `kibana_link`. The RED data rule applies to the MCP tools too.

- Every tool returns structured output: read `result.structuredContent`, for example `total` and `aggregations` from `search`, or `rows[0].n` from `esql` (rows are objects keyed by column name).
- `esql` takes `params: {name: value}` for `?name` and `??name` placeholders.
- `count` and `search` take `async: true` for long-running queries (see Long-running queries), and `async_timeout_s` (default 600, `0` for no limit). Progress goes out as MCP progress notifications, so pi's 60s per-request timeout does not apply; a timed-out call returns an error.
- `export` writes to a file and returns only the path and count. Read the file with `jq`.
- `kibana_link` returns a Discover `url` for the user. Pass the same `index` and either the conditions as `filters` (`{field, value}`, `{field, values}`, `{field, range}`, `{field, exists}`, one Discover filter pill each), the same `query` DSL for anything else, or `esql` with parameter values written into the query. Set the time range with `from`/`to` (the Discover time picker), not with a `@timestamp` filter.

## Workflow

1. Pick the index pattern.
2. `esquery count` on a tight window to confirm the query matches something.
3. `esquery search --aggs ...` to break it down by host, shard, error, zone, ...
4. `esquery scroll` only when you need the raw documents.

If `count` or `search` fails with a 502 after about 60 seconds, rerun it once with `--async`.

Report the total for the window, the top-N breakdown on the most useful dimension, and one representative document (truncated) if the user needs to see what the logs look like.
