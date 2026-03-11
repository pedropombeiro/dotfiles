# Personal Lessons Learned

Actionable corrections accumulated from user feedback.

## General

- Always read and internalize `AGENTS.local.md` and all `.ai/` instruction files at the start of every session, before doing any work.

## Code Style

- Always favor `s_('Namespace|...')` over `_('...')` for new translatable strings in GitLab.
- Prefer `if` over `unless` when possible. Only use `unless` when the equivalent `if` would require a negation (e.g. `if !condition`).
- RSpec `subject` is memoized — calling it multiple times in the same example returns the same result. Do not wrap in `result = nil; expect { result = subject }` unnecessarily.
- Always use named subjects in RSpec (e.g. `subject(:result)` instead of `subject`). This improves readability and makes specs self-documenting.
- Prefer `let_it_be` with `freeze: true` (e.g. `let_it_be(:user, freeze: true)`) to avoid flaky tests caused by accidental global object modification.

## Work Items (MRs, Issues, Epics)

- Do not post comments directly on MRs, issues, or epics. Only update descriptions, labels, and metadata.
- Do not assign reviewers unless the user explicitly asks — leave reviewer selection to the user.
