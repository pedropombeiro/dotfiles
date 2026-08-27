# Code Style - Personal Lessons

## Ruby

- Always favor `s_('Namespace|...')` over `_('...')` for new translatable strings in GitLab.
- Prefer `if` over `unless` when possible. Only use `unless` when the equivalent `if` would require a negation (e.g. `if !condition`).
- Do not add new entries to `.rubocop_todo/` files. Use inline `rubocop:disable` comments instead.

## Comments

- Keep code comments terse; remove implementation detail that the code already makes clear.
- Wrap comments greedily to the full line-length limit (120 chars in this repo), not to ~80. Do not leave a comment
  line short unless a sentence ends there.
- Start each new sentence on its own line. Two sentences never share a line, even when both would fit — so a line may
  end well before 120 chars if the next sentence begins there.
  The result reads as one sentence per paragraph-line, each greedily wrapped. Example:

  ```ruby
  # Concurrency is capped at MAX_CONCURRENT_DISTILLATIONS by assigning each principle a `resource_group` slot.
  # A resource group is a semaphore of exactly one, so N named groups give a cap of N.
  # Slots are assigned round-robin:
  # an unlucky slot with two slow principles serializes them, but each is still bounded by its own job timeout,
  # which is the property that matters.
  ```

- Applies to comments in all languages, including RSpec `#` comments and YAML.
