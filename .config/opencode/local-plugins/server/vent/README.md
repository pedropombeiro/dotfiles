# vent

An OpenCode server plugin that exposes a `vent` tool so agents can record tooling, documentation,
skill, permission, and workflow frictions encountered during routine work.

## Behavior

- Registers the `vent` tool (`codemode: false`) and injects concise guidance into sessions when at
  least one destination is configured, so the agent knows when to record actionable friction and
  what to leave out.
- Formats each entry with structured Markdown sections (`Friction`, `Context`,
  `Evidence / Reproduction`, `Suggested Improvement`) and a collapsible session metadata block
  (timestamp, category, working directory, repository remote, branch, and session ID).
- Checks existing open items at the target destination before creating a new entry. When an open
  item matches above `similarityThreshold`, `vent` appends a comment or occurrence subsection
  instead of filing a duplicate.
- Uses standard OpenCode tool permissions. Keep `vent` on `ask` if you want to review and approve
  the payload before an issue is created or updated.

## Tool parameters

| Parameter | Required | Description |
| --- | --- | --- |
| `title` | Yes | Concise summary of the friction (issue title or Markdown `##` heading). |
| `friction` | Yes | Description of what failed, was slow, was undocumented, or caused wasted effort. |
| `context` | Yes | Task or investigation underway when the friction occurred. |
| `evidence` | No | Error messages, commands, file paths, or reproduction details. |
| `suggestion` | No | Proposed fix or improvement. |
| `category` | No | One of `tooling`, `documentation`, `skill`, `permissions`, `environment`, `workflow`, `other`. |
| `labels` | No | Extra labels merged with the destination's configured `labels` (GitLab and GitHub). |
| `destination` | No | Named destination key. Enforced routes restrict overrides. |
| `localReason` | No | Why an explicitly selected file entry is unrelated personal friction. Required to override an enforced route with a file destination. |

## Options

Configure destinations and optional routing rules in `opencode.json`:

```jsonc
{
  "plugins": [
    {
      "package": "./local-plugins/server/vent",
      "options": {
        "defaultDestination": "local",
        "similarityThreshold": 0.45,
        "destinations": {
          "local": {
            "type": "file",
            "path": "~/.agents/docs/vents.md"
          },
          "gitlab": {
            "type": "gitlab",
            "project": "group/project",
            "epic": "https://gitlab.com/groups/group/-/epics/123",
            "host": "gitlab.com",
            "confidential": true,
            "labels": ["agent-friction"]
          },
          "github": {
            "type": "github",
            "repo": "owner/repo",
            "host": "github.com",
            "labels": ["agent-friction"]
          }
        },
        "routes": [
          { "directoryPrefix": "~/work", "destination": "gitlab" },
          { "remoteContains": "github.com/owner/", "destination": "github" }
        ]
      }
    }
  ]
}
```

### Destination resolution order

1. First matching route with `enforced: true`. A different destination is rejected unless it is a file destination and `localReason` explains the unrelated personal friction.
2. Explicit `destination` tool argument.
3. First matching non-enforced route.
4. `defaultDestination`, or the sole destination when only one is configured.

Routes match by `directoryPrefix`, `remoteContains`, or `remoteRepository`. If
you specify more than one condition on a route, all must match. Remote rules
check fetch URLs, including remotes other than `origin`. `remoteRepository`
matches a full `host/namespace/project` identity across HTTPS and SSH URLs.
An issue destination failure never falls back to a file.

### Destination types

- **`gitlab`**: uses `glab api` to list open issues under `epic` (accepting legacy epic
  URLs, work item epic URLs, or `<group>&<iid>` shorthand) or `project`. Comments on a matching
  open issue, or creates a new issue in `project` linked to `epic` via the `/epic` quick action
  with a REST link fallback. If no open issue matches, checks closed issues in the configured
  project and epic for the same title, ignoring case and surrounding whitespace. Returns the
  closed issue link without creating, commenting on, or reopening an issue. `confidential`
  defaults to `true`.
- **`github`**: uses `gh api` to list open issues in `repo` (ignoring pull requests). Comments on a
  matching open issue, or creates a new issue.
- **`file`**: reads and updates a local Markdown file (supporting leading `~/`). Appends a
  `### Occurrence (YYYY-MM-DD)` subsection to a matching `##` section, or appends a new `##`
  section.

## Tests

Run the tests from this directory:

```sh
mise exec bun -- bun test
```
