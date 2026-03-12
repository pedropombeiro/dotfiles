# Code Style - Personal Lessons

## Ruby

- Always favor `s_('Namespace|...')` over `_('...')` for new translatable strings in GitLab.
- Prefer `if` over `unless` when possible. Only use `unless` when the equivalent `if` would require a negation (e.g. `if !condition`).
- Do not add new entries to `.rubocop_todo/` files. Use inline `rubocop:disable` comments instead.
