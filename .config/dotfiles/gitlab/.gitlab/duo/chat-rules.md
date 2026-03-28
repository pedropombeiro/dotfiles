# Rules

- Prefer using the Knowledge Graph MCP server when searching the codebase instead of the Glob tool.
- Avoid passing double quotes in commands, since there is currently a problem parsing commands that use them.
- When deleting temporary test files, use the `-f` switch for the `rm` command.
- Feature flags are enabled by default in specs, so no setup is needed for that scenario. When testing the case where
  the feature flag is disabled, we should create it in a self-contained context, and set up the feature flag state in a
  `before` hook.

## Guidelines for branch creation

- Branch names follow the format `pedropombeiro/<ISSUE-NUMBER>/<BRANCH-NAME>`

## Guidelines for dealing with specs

- Follow the guidelines in https://docs.gitlab.com/development/testing_guide/

## Guidelines for command execution

- Run Ruby tests with `bundle exec rspec <filename> --format documentation`. Do not use `-v` as that returns the RSpec version.
- When editing RSpec files, run the `bundle exec rubocop -A <filename>` code formatter afterwards to fix indentation.
- When executing the `cat` command to read a file, no not specify the `-A` command line switch.
- Be aware that the shell may have special interpretations for characters such as ~ and !, so make sure to quote any
  command line arguments that include them.

## Guidelines for writing weekly issue status reports

- When outputting GitLab user names, wrap them in backticks, so that they are not mentioned.
- When writing feature flag names or about epics, try to link to the respecting issue/epic.
- Do not remove items from the list in the Confidence section.
- Use the following template:

  ```
  ## Status Update

  **Progress this week:**
  <!-- What got done? Any wins or learnings? --->
  -

  **What's next:**
  <!-- Planned work for next week -->
  - ...

  **Blockers:**
  <!-- Any blockers or questions? Tag specific people if needed -->
  - None <!-- (if no blockers) -->

  **Confidence for current milestone:**
  - [ ] 🔴 At risk - may not make it
  - [ ] 🟡 Some concerns - watching closely
  - [ ] 🟢 On track - confident we'll deliver

  /health_status <on_track|needs_attention|at_risk>
  /cc @golnazs
  ```
