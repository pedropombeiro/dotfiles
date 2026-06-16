# Reviewer scoring model & API reference

This document explains how `reviewer-finder` ranks candidates and which GitLab
API fields back each signal. The scripts under `scripts/` implement it; this is
the reference for understanding and tuning the behavior.

## Two-stage review convention

GitLab MRs in `gitlab-org/gitlab` follow a two-stage review:

1. **SME (first) review** — someone with domain competence for the changed area.
   Sourced from the MR's **named CODE_OWNER approval rules** (excluding the
   generic Maintainers fallback), preferring members who recently authored the
   changed files.
2. **Maintainer (second) review** — a generic maintainer who gives the final
   approval. Sourced from the MR's **Maintainers** CODE_OWNER rule.

A single MR can touch several areas, so **each CODE_OWNER rule is an independent
approval requirement**. The skill produces one ranked SME block per such rule,
plus a maintainer block — not a single global pick. The rules themselves come
from the MR (see "Candidate source" below), so the split always matches what
GitLab will actually require.

## Candidate source: the MR's approval rules (SSOT)

Candidates come from the MR's own GraphQL `approvalState.rules` — the exact set
GitLab computes and shows in the MR Review widget (e.g. "153 code owners for
`/spec/`"). This is **authoritative**: GitLab has already resolved which
CODE_OWNER rules apply to this MR's changes and who is eligible to approve each.

```graphql
project(fullPath:) { mergeRequest(iid:) { approvalState { rules {
  name section type approvalsRequired approved
  eligibleApprovers {
    username bot state jobTitle location lastActivityOn
    status { availability message emoji }
    activeReviews: reviewRequestedMergeRequests(state: opened, updatedAfter:) {
      nodes { approvedBy { nodes { username } } }
    }
    assignedMergeRequests(state: opened) { count }
  }
} } } }
```

Why this replaced CODEOWNERS parsing + group expansion:

- **No glob matching** of changed paths against `.gitlab/CODEOWNERS`.
- **No group membership expansion**, so none of the inherited-member problems.
  Previously, expanding groups via REST `members/all` pulled *inherited* members
  from ancestor groups — a UX designer (`pedroms`) with an inherited `gitlab-org`
  role wrongly appeared in the rails-backend/database/frontend maintainer pools.
  `eligibleApprovers` only ever contains people GitLab considers valid approvers
  for the rule.
- **Per-rule** → multi-area MRs naturally yield one candidate set per
  requirement.
- **Signals inline**: jobTitle, status, location, lastActivityOn, active reviews,
  and assigned MRs come back in the same query and are reused downstream.

### Rules → sections

- Each `type == "CODE_OWNER"` rule becomes a section. By default only rules with
  `approvalsRequired > 0` (still needing approval) are kept; `--include-satisfied`
  keeps all.
- A rule whose `section` is the generic **"Maintainers"** fallback feeds the
  second-stage maintainer pool; every other CODE_OWNER rule is a first-stage SME
  requirement.
- `ANY_APPROVER`/`REGULAR` rules (e.g. "All Members") are ignored — they are not
  code-owner requirements.
- Bots and service accounts (`bot == true`, non-active, or `*bot*`/`securitybot`
  names) are dropped.

Note: `eligibleApprovers` is returned in full (not a 100-capped connection), so
one request yields the entire candidate set. Contribution-recency
(`days_idle`/`no_footprint`) is **not** fetched here — the sorted-MR subqueries
time out across a large `eligibleApprovers` set — so `reviewer-signals.sh` adds
those via its small chunked queries and merges. Group `fullPath`/`mergeRequest`
fields resolve correctly (unlike the top-level `user()` batchloader bug, which is
why per-user signal batching uses the plural `users(usernames:)` field).

## Signals

All signals are gathered from **one batched GraphQL query per chunk** of users
via the plural `users(usernames: [...])` field:

```graphql
{ users(usernames: ["a","b",...]) { nodes {
    username bot location lastActivityOn
    status { availability message emoji }
    reviewRequestedMergeRequests(state: opened,
      reviewStates: [UNREVIEWED, REVIEWED, REQUESTED_CHANGES]) { count }
    lastAuthored: authoredMergeRequests(first: 1, sort: UPDATED_DESC) { nodes { updatedAt } }
    lastReviewed: reviewRequestedMergeRequests(first: 1, sort: UPDATED_DESC) { nodes { updatedAt } }
} } }
```

| Signal | GraphQL field | Notes |
|--------|---------------|-------|
| Current OOO/PTO | `status { availability message emoji }` | Hard-exclude when `availability == "busy"`, the message matches PTO keywords, or the emoji is a vacation emoji. |
| Outstanding load (group members) | `reviewRequestedMergeRequests(state: opened, updatedAfter: <1w>) { nodes { approvedBy { nodes { username } } } }` | The gitlab-dashboard definition: count open, recently-updated review requests where the reviewer is **not** among `approvedBy` (i.e. still owes a review). The `updatedAfter` window (default 1 week) ignores stale/abandoned requests. This is the preferred load metric. |
| Outstanding load (handle/recent-author fallback) | `reviewRequestedMergeRequests(state: opened, reviewStates: [UNREVIEWED, REVIEWED, REQUESTED_CHANGES]).count` | Used only for `@user` SME owners and recent-author hints not sourced from a group; `reviewStates` excludes `APPROVED`. |
| Role fit | `jobTitle` | Surfaced for every candidate. In a section with a clear domain (backend/frontend/database), a candidate whose `jobTitle` clearly belongs to another discipline (designer/PM/UX/tech-writer) gets a mild penalty + advisory note. Never a hard exclude. |
| Assigned MRs (context) | `assignedMergeRequests(state: opened).count` | Reported as `assigned_open`; extra context on how busy the person is, not scored directly. |
| Profile / timezone | `location` | The API exposes no numeric timezone, so `reviewer-signals.sh` derives a coarse `tz_offset` (UTC hours) from the free-text `location` via a keyword map (countries/cities/regions). Unrecognized/empty location → `tz_offset: null` and timezone scoring is skipped for that person. |
| Inferred inactivity | `lastAuthored` + `lastReviewed` (most recent `updatedAt`) | `days_idle` = days since the most recent **contribution** (authored or reviewer-requested MR update). `>= --stale-days` (default 3) marks the candidate **stale** — advisory, never excluded. |
| No footprint | both subqueries empty | `no_footprint: true` when **no** authored or reviewed MR is found at all. This is treated as **stale** (penalized), not neutral: a candidate with no visible engineering activity is a responsiveness risk we should not silently rank highly. `days_idle` stays `null` (genuinely unknown count) but the staleness penalty still applies. |
| Liveness hint only | `lastActivityOn` | Reported as `last_activity_on` but **not** used for `days_idle`: it ticks on bare sign-ins/token use and over-reports liveness (e.g. "active today" for someone with no contribution in weeks). |
| Bot filter | `bot` + username heuristic | `bot == true` users and service accounts matching `*bot*`/`securitybot` are dropped entirely; never valid reviewers. |

### Why GraphQL (not REST)

The REST approach needed several multi-second calls per candidate (a ~4-5s MR
search plus a per-MR `reviewers` lookup to exclude approvals, plus status,
profile, and events calls). GraphQL collapses it into batched requests, and the
`reviewStates` argument does the exclude-approved filtering server-side.

The `lastAuthored`/`lastReviewed` sorted-MR subqueries are expensive, so each
GraphQL request covers a **small chunk** (`--chunk-size`, default 10) — larger
chunks make the resolver time out (`"Timeout on ..."` errors). Chunks are fetched
**concurrently** (`--concurrency`, default 12) so total wall time is ~= the
slowest chunk (~15-20s for a 100+ pool), not the sum. Partial responses (some
nodes + timeout errors) are tolerated: returned nodes are kept, missing users
get no signal entry and are treated as unknown.

Note: top-level aliased `user(username:)` calls mis-resolve under GitLab's
batchloader (aliases collide and return the wrong user). Always use the plural
`users(usernames: [...])` field for batching.

### Load semantics

The preferred metric (group members) counts open review requests, updated within
~1 week, where the reviewer is **not** among `approvedBy` — i.e. reviews they
still owe. The fallback metric (handles/recent authors) counts `reviewStates`
`UNREVIEWED`/`REVIEWED`/`REQUESTED_CHANGES` (everything except `APPROVED`). Both
exclude approvals: a clean approval means the ball is no longer with them.

## Scoring (lower score = better)

Implemented in `rank-reviewers.sh`:

```
score = load * LOAD_WEIGHT             # default LOAD_WEIGHT = 10
      - SME_BONUS (if recent author)   # default SME_BONUS  = 20
      + STALE_PENALTY (if stale)       # default STALE_PENALTY = 15
      + ROLE_MISMATCH_PENALTY (if role # default = 10
        clearly mismatches section)
      + tz_score * TZ_WEIGHT           # default TZ_WEIGHT = 3; only when
                                       # tz_offset and --author-tz are known
```

Hard-excluded (dropped from `ranked`, listed under `excluded`): `ooo_now == true`.

### Role-fit (advisory)

A second guard against non-experts surfacing as reviewers (beyond DIRECT-member
expansion). When a section maps to a clear domain — `domain_of()` recognizes
backend/frontend/database from the section name — a candidate whose `jobTitle`
clearly belongs to another discipline (designer, UX, product manager, technical
writer, documentation) gets `ROLE_MISMATCH_PENALTY` and a visible
`role mismatch: <title> (advisory)` note. It is never a hard exclude (job titles
are imperfect), and it does not apply to the generic `Maintainers` pool (no
single domain). All candidates show `role: <jobTitle>` in their rationale.

### Timezone term (`tz_score * TZ_WEIGHT`, default TZ_WEIGHT=3)

Applied only when both the candidate's `tz_offset` and `--author-tz` are known
(otherwise 0). It uses the **current UTC hour** (`--now-utc-hour`, defaults to
now) to compute each candidate's **local hour at request time**, then scores by
`--tz-mode`:

- **`day-ahead` (DEFAULT):** prefer a reviewer who has most of their **workday
  still ahead** right now, so they can pick the review up today. Using their
  local hour `h` and a 9:00–18:00 workday:
  - `h` before 09:00 → small penalty `(9 - h) * 0.5` (they'll start soon),
  - `h` within hours → `((h - 9) / 9) * 8` (rises from 0 at start to ~8 as the
    day elapses),
  - `h` at/after 18:00 → `12` (their day is over — strongly deprioritized).

  So at 07:00 UTC a Madrid reviewer (local 08:00) wins; at 17:00 UTC a US-Pacific
  reviewer (local 09:00) wins. This matches "send it to someone whose full day is
  ahead of them."
- **`overlap` (`--tz-mode overlap`, or the deprecated `--coordination-heavy`):**
  `|delta| * 2` — closest timezone wins; best when heavy back-and-forth is
  expected.
- **`handoff` (`--tz-mode handoff`):** `| |delta| - 8 |` — favors a reviewer ~8h
  ahead, the classic end-of-day handoff.

## Upcoming PTO (Glean — agent step, not a script)

The scripts cannot see calendars or Slack, so the **agent** performs the
upcoming-PTO check after ranking, over the top candidates only (see SKILL.md).
Anyone confirmed to be going OOO within the lookahead window (default 5 business
days) is demoted with the evidence cited, and the next-best candidate is
surfaced.

## Tunable constants

| Where | Constant | Default | Meaning |
|-------|----------|---------|---------|
| `candidate-reviewers.sh` | `--recent-authors` | 5 | Recent git authors per MR added as SME hints. |
| `candidate-reviewers.sh` | `--active-reviews-days` | 7 | Recency window for the active-review load count on eligible approvers. |
| `candidate-reviewers.sh` | `--include-satisfied` | off | Also include CODE_OWNER rules already satisfied (e.g. for merged/approved MRs). |
| `reviewer-signals.sh` | `--stale-days` | 3 | Days since last contribution before a candidate is flagged stale (advisory). |
| `reviewer-signals.sh` | `--chunk-size` | 10 | Usernames per batched GraphQL request. Keep small: the sorted-MR subqueries time out on larger chunks. |
| `reviewer-signals.sh` | `--concurrency` | 12 | Chunks fetched in parallel. |
| `reviewer-signals.sh` | `--max-candidates` | 400 | Generous safety cap on total candidates evaluated. Rarely hit. |
| `rank-reviewers.sh` | `LOAD_WEIGHT` | 10 | Weight per outstanding review. |
| `rank-reviewers.sh` | `SME_BONUS` | 20 | Bonus for recent authors of the changed files. |
| `rank-reviewers.sh` | `STALE_PENALTY` | 15 | Penalty for stale candidates. |
| `rank-reviewers.sh` | `ROLE_MISMATCH_PENALTY` | 10 | Penalty when `jobTitle` clearly mismatches a domain section (advisory). |
| `rank-reviewers.sh` | `TZ_WEIGHT` | 3 | Multiplier on the timezone score. |
| `rank-reviewers.sh` | `--tz-mode` | day-ahead | `day-ahead` (full day ahead, default), `overlap` (closest tz), or `handoff` (~8h ahead). |
| `rank-reviewers.sh` | `--now-utc-hour` | now | UTC hour driving the day-ahead model; override for "what if I send later". |
| `rank-reviewers.sh` | `WORKDAY_START` / `WORKDAY_END` | 9 / 18 | Local workday window for the day-ahead model. |

## Performance

Signals are fetched in small batched GraphQL chunks (`--chunk-size`, default 10)
run **concurrently** (`--concurrency`, default 12). A 128-member pool resolves in
~15-25s total and **every** candidate is evaluated. `rank-reviewers.sh` ranks
only candidates that have a gathered signal entry (bots and unresolved/partial
users are dropped), so the list is never padded with score-0 noise.

## Known limitations

- **Maintainer-only MRs.** When the changed paths map only to the `Maintainers`
  section (e.g. a top-of-file `*.rb` rule with no more-specific named section),
  there is no separate SME shortlist — the SME and maintainer reviewer are the
  same pool. Present a single maintainer ranking and note that no area-specific
  SME section claimed the files.
- Recent-author hints derive from commit email local-parts, which are not always
  GitLab usernames. They are soft signals; treat a missing signal entry as
  "unknown", not "unavailable".
- The users API exposes no numeric timezone; `tz_offset` is **derived from the
  free-text `location`** via a keyword map. It is coarse (city/country/region
  level, standard-time offsets, no DST) and only good enough to prefer a
  near/day-ahead reviewer over a far one. Candidates with an empty or
  unrecognized location get `tz_offset: null` and are not timezone-scored — so a
  reviewer with no location set (like `johnmason`) will never be preferred on
  timezone grounds; pick someone with a known, suitable location instead.
