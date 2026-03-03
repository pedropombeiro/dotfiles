# Personal Lessons Learned

Actionable corrections accumulated from user feedback.

## General

- Always read and internalize `AGENTS.local.md` and all `.ai/` instruction files at the start of every session, before doing any work.

## Code Style

- Always favor `s_('Namespace|...')` over `_('...')` for new translatable strings in GitLab.
- Prefer `if` over `unless` when possible. Only use `unless` when the equivalent `if` would require a negation (e.g. `if !condition`).
- RSpec `subject` is memoized — calling it multiple times in the same example returns the same result. Do not wrap in `result = nil; expect { result = subject }` unnecessarily.
