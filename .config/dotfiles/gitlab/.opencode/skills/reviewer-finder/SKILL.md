---
name: reviewer-finder
description: Recommend (or, on explicit request, assign) the best GitLab reviewers for a merge request, optimizing for outstanding review load, availability, OOO/PTO (current and upcoming), timezone fit, and the SME-then-maintainer review convention. Use when the user asks who should review an MR, to find/suggest reviewers, or to assign reviewers while creating MRs.
license: MIT
compatibility: opencode
metadata:
  audience: developers
  author: pedropombeiro
  keywords: reviewer, review, merge request, codeowners, sme, maintainer, assign, pto, ooo
  workflow: gitlab
---

# Reviewer finder

Recommend the best reviewers for a GitLab merge request. The MR is inferred from
the current branch or given explicitly (URL or IID). Optimizes for review load,
availability, OOO/PTO, timezone, and the SME → maintainer two-stage convention.

## When to use

The user asks any of:

- "who should review this?", "find reviewers for !N", "best reviewer for this MR"
- "suggest a reviewer for `<branch>`"
- "assign reviewers" / "create the MR and assign a reviewer" (the **assign**
  path — see "Assigning" below)

## When NOT to use

- The MR is a draft the user isn't ready to route — confirm intent first.
- There is no MR yet and the user only wants general team-ownership info — that's
  a CODEOWNERS lookup, not reviewer selection.

## How it works

Four scripts under `scripts/` form a pipeline (all `glab` + `jq`, read-only):

1. **`resolve-mr.sh`** — current branch | URL | IID → `{project, iid, author, files}`.
2. **`candidate-reviewers.sh`** — queries the MR's **`approvalState.rules`** (the
   SSOT: the exact eligible approvers GitLab shows in the MR Review widget, e.g.
   "153 code owners for `/spec/`"). Each CODE_OWNER rule becomes a section (the
   Maintainers fallback → maintainer pool; others → per-area SME). This avoids
   CODEOWNERS parsing and group-membership expansion entirely — so non-approvers
   (e.g. a UX designer with an inherited `gitlab-org` role) never appear. SME
   sections are augmented with recent authors of the files; per-approver signals
   are gathered in the same query.
3. **`reviewer-signals.sh`** — per candidate: outstanding review load, current
   OOO/PTO status, role (`jobTitle`), location, and days-idle. Reuses signals
   pre-gathered during group expansion; fills gaps for handle/recent-author
   candidates.
4. **`rank-reviewers.sh`** — ranks candidates per section + the maintainer pool,
   including an advisory role-fit penalty when a candidate's `jobTitle` clearly
   mismatches a domain section.

Run them as a pipe:

```bash
SK=~/.config/dotfiles/gitlab/.opencode/skills/reviewer-finder/scripts

# Infer MR from the current branch (or pass an IID / URL to resolve-mr.sh):
"$SK/resolve-mr.sh" \
  | "$SK/candidate-reviewers.sh" \
  | "$SK/reviewer-signals.sh" \
  | "$SK/rank-reviewers.sh" --author-tz <author_utc_offset> > /tmp/reviewers.json
```

`reviewer-signals.sh` gathers all signals (load, status, location, contribution
recency) via **batched GraphQL** in small chunks fetched **concurrently**, so it
evaluates the entire candidate pool (even 100+ maintainers) in ~15-25s. No
sampling or per-candidate REST fan-out.

`days_idle` is computed from the most recent **contribution** (latest authored or
reviewer-requested MR update), not `lastActivityOn` — the latter ticks on bare
sign-ins and falsely reports "active today" for someone idle for weeks.

Pass `--author-tz <hours>` (e.g. `1`, `-5`) when you know the author's UTC offset
so timezone scoring applies. Add `--coordination-heavy` to `rank-reviewers.sh`
when the MR will need a lot of back-and-forth (prefers timezone overlap instead
of a handoff).

See [`references/scoring.md`](references/scoring.md) for the full scoring model,
API field reference, and tunable constants.

## Scoring summary

Lower score = better. Per candidate:

- **Current OOO/PTO** → hard-excluded (status `busy`, PTO keywords, or vacation
  emoji). Listed under `excluded`, never ranked.
- **Outstanding load** → counts open MRs where the reviewer's state is **not**
  `approved` (i.e. `unreviewed`/`reviewed`/`requested_changes`). Lower is better.
- **SME bonus** → recent authors of the changed files rank higher in their section.
- **Inferred inactivity** → idle ≥ 3 days (default) is flagged **advisory**, not
  excluded.
- **Timezone fit** → handoff-optimized by default; `--coordination-heavy` prefers
  overlap. Applied only when the timezone is known.

## Upcoming-PTO check (Glean)

The scripts cannot see calendars or Slack. After ranking, **you (the agent)** must
check whether the top candidates are about to go on PTO, because we want to avoid
routing a review to someone leaving imminently.

1. Take the **top 3 per required section + top 3 maintainers** from the ranked
   output.
2. Run a **single batched Glean `chat`** over that union. Prefer `chat` (cheap,
   summarized) per `CLAUDE.local.md`; fall back to `search` with
   `app=googlecalendar` or `app=slack` only if `chat` is inconclusive.
   Example message:
   > Are any of these GitLab team members going on PTO, vacation, or out of
   > office in the next 5 business days: `userA`, `userB`, `userC`, ...? Check
   > calendars and recent Slack.
3. For anyone confirmed leaving within **5 business days**: **demote** them below
   available candidates, cite the evidence and their return date, and surface the
   next-best candidate in that section.
4. If Glean is unavailable, note that upcoming PTO could **not** be verified —
   do not fail or silently skip; say so.

## Presenting results

Show a per-section matrix:

- One ranked block per **required** SME section, then the **maintainer** block.
  Surface optional (`^[...]`) sections as lower priority.
- For each candidate, give the rationale: outstanding load, local time/location,
  availability/status, SME evidence (recent author), and any PTO note.
- **Cross-section overlap:** if one available candidate covers multiple required
  sections (in the `overlap` map), highlight them to minimize the number of
  distinct reviewers — while still listing each section's full options.
- Wrap every username in backticks (`` `username` ``) so nobody is pinged.

### Maintainer-only MRs

If the changed files map only to the `Maintainers` section (no area-specific
named SME section claims them — common for top-of-file rules like `*.rb`), there
is no separate SME shortlist. Present a single maintainer ranking and state that
no specific SME section owns the files, so the same reviewer covers both stages.

### Score ties

Because the users API exposes no numeric timezone, many load-0 active candidates
tie at score 0. Break ties with `location`/timezone judgement (favor a handoff or
overlap per the MR's needs) and the Glean upcoming-PTO check, and present a few
options rather than a single arbitrary pick.

## Assigning (opt-in)

Default behavior is **recommend-only**. Only assign reviewers when the user has
given an **explicit** instruction — either in the current request ("assign a
reviewer") or a standing instruction while working through a stream of MRs
("assign reviewers as you create each MR").

When assigning:

- Pick the **top available candidate per required section** + the top maintainer,
  applying cross-section minimization (one person can satisfy multiple sections).
- Never assign anyone hard-excluded (current OOO/PTO) or flagged by the Glean
  check as about to be out; use the next-best instead.
- **Spread load across a batch.** When assigning reviewers to several MRs in one
  go, prefer distinct reviewers rather than piling the same top pick onto every
  MR. After each assignment that person's outstanding load effectively goes up by
  one — account for it so the batch is balanced.
- **Assign directly, then report** who was set per section and why. Do not ask
  for a second confirmation when an explicit/standing assign instruction already
  exists.

### How to request the review

The conventional, human-facing way to request a review is a short friendly
comment using the `/request_review` quick action — **not** a bare API reassign.
The quick action both assigns the reviewer and notifies them, and the comment
tells them **what kind of review** is expected. Post one comment per reviewer:

```
Hey @<reviewer> :wave:, mind doing the <review-type> review? <one-line context>

/request_review @<reviewer>
```

- **`<review-type>`** names the stage so the reviewer knows their role:
  - For a **named SME section** (e.g. `[Backend]`, `[Database]`), use the team's
    scoped label phrasing — e.g. "the ~backend initial review".
  - For the **maintainer** stage (the `Maintainers` rule / second review), say
    "the maintainer review".
  - **Maintainer-only MRs** (the only applicable rule is the `Maintainers`
    `/spec/`-style rule, with no separate SME section) → phrase it as "the
    maintainer review", since there is no separate SME/initial stage.
- **`<one-line context>`** is a brief reason that helps the reviewer triage
  (e.g. "It's a test-only cleanup removing `let_it_be freeze: false` opt-outs.").
- Because `/request_review @user` performs the assignment, the comment alone is
  sufficient — you don't also need `glab mr update --reviewer`. If you already
  set the reviewer via the API, the quick action is idempotent for the same user.
- Posting these review-request comments **is** covered by the explicit/standing
  assign instruction (assigning a reviewer is the user's intent). Still respect
  the no-other-comments rule: only the `/request_review` request, nothing else.
- Escape backticks/`$` in the comment body via a file + `$(cat ...)` (see the
  `glab` skill's message-escaping guidance).

A plan-mode approval or answering a clarifying question does **not** count as an
assign instruction. Absent an explicit ask, stop at the recommendation.

## Agent guidelines

1. **Recommend by default; assign only on an explicit/standing instruction**,
   then report. This is the one narrow case where assigning reviewers is allowed.
   Request the review via a friendly `/request_review @user` comment that names
   the expected **review type** (SME `~label` initial vs maintainer) — see
   "How to request the review".
2. **Backtick usernames** in all chat output.
3. **OOO inference and Glean PTO findings are advisory** — cite the evidence so
   the user can override; never present them as certainty.
4. **Whole-pool evaluation** — signals come from batched GraphQL, so even large
   maintainer pools are fully evaluated in seconds; no sampling caveat needed.
5. **Author timezone** — derive it from the MR author's `location` (via the
   resolved data) and pass `--author-tz`; if unknown, skip timezone scoring and
   reason about it qualitatively from `location`.
6. **Degrade gracefully** — if a signal source (status, last activity, Glean) is
   unavailable for a candidate, treat it as unknown and say so, rather than
   excluding the candidate.
