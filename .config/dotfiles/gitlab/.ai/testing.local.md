# Testing - Personal Lessons

## RSpec Conventions

- Always use named subjects (e.g. `subject(:result)` or `subject(:perform_request)`). This improves readability and makes specs self-documenting.
- `subject` is memoized — calling it multiple times in the same example returns the same result. Do not wrap in `result = nil; expect { result = subject }` unnecessarily.
- Prefer `let_it_be` with `freeze: true` (e.g. `let_it_be(:user, freeze: true)`) to avoid flaky tests caused by accidental global object modification.
- When multiple RSpec contexts share the same `before` hook differing only in a value, hoist the `before` to the shared parent context and use a `let` variable defined in each inner context.
