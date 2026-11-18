---
name: roughdraft
description: Review local prose drafts in Roughdraft. Use for long MR descriptions, proposals, documentation, and agent instructions requiring approval, or on explicit request. Use Plannotator for implementation plans and code review.
license: MIT
---

# Roughdraft

Use Roughdraft by default for long prose drafts that require user approval,
including MR descriptions, proposals, documentation, and agent instructions.
Use Plannotator for implementation-plan approval and requested code/diff review.
Explicit tool requests override these defaults. Never send the same artifact
through both tools for duplicate approval, or move an annotated draft between
tools without resolving its review metadata first.
Also use Roughdraft whenever the user explicitly requests it. Keep short approvals,
routine progress updates, and informational answers in chat. Do not invent a
hard word-count threshold or open every Markdown file automatically.
This is a locally maintained workflow, not a vendored upstream skill.

## Prepare a review

1. Read the user's writing guidance before drafting technical prose.
1. Use the existing document when the user identifies one. For a new draft,
   honor an explicit destination. Otherwise, use a repository-ignored draft
   directory after checking its ignore status, or the environment's permitted
   temporary directory. Do not create a new root-level home-directory file.
1. Check `roughdraft --version`. On macOS, the dotfiles declare `npm:roughdraft`
   in `~/.config/mise/conf.d/tools.macos.toml`. If needed, install that declared
   tool with `MISE_NPM_PACKAGE_MANAGER=npm mise install npm:roughdraft` after
   obtaining installation approval. The scoped npm installer is necessary
   because aube cannot resolve Roughdraft's bundled local dependency. It skips
   aube's supply chain checks, so do not apply this override to other tools or
   global settings. Use the same scoped override with `mise upgrade npm:roughdraft`
   for updates until aube supports the package layout.
   Do not silently install a global npm package on other machines.
1. Tell the user to leave comments or suggestions and click **Done Reviewing**.
1. Open one file using an absolute path:

   ```sh
   roughdraft open "/absolute/path/to/draft.md" --json
   ```

The command starts or reuses Roughdraft's local server and waits for the next
review-completion event. Leave it running with no shell-tool timeout when
supported. Do not kill, detach, or background the review command as cleanup.
If the harness cannot keep a foreground command running, use `--no-watch`,
explain that automatic handoff is unavailable, and ask the user to return to
chat after reviewing. Do not configure MCP or a custom agent integration just
to open a document.

## Address feedback

1. After **Done Reviewing**, reread the Markdown from disk. The command's event
   JSON is a handoff signal, not a substitute for reading the user's changes.
1. Read inline CriticMarkup and document-level feedback in YAML endmatter.
   Treat fenced and inline code examples as literal text, not live feedback.
1. Apply requested revisions and answer questions. Preserve unrelated edits,
   comment IDs, authors, timestamps, and reply relationships. Clarify ambiguous
   suggestions rather than silently accepting them.
1. Reply inline when needed and reopen the file if another review round is
   useful. Do not loop when the user says the review is finished.
1. Before committing, posting, or exporting, prepare and inspect a clean final
   version without review markers or review-only endmatter. Preserve legitimate
   document metadata and keep unresolved feedback in the review draft.

Completing a review approves only the local handoff. It does not authorize
committing, pushing, publishing, or sending content to GitLab, Readeck, or any
other destination. Follow the user's separate approval and pending-comment
rules for those actions.

## Review syntax

Roughdraft saves feedback in ordinary Markdown using CriticMarkup:

| Feedback | Syntax |
| --- | --- |
| Comment | `{>>comment<<}` |
| Highlight | `{==selected text==}` |
| Insertion | `{++new text++}` |
| Deletion | `{--old text--}` |
| Substitution | `{~~old~>new~~}` |

For new comments and suggestions, use a unique document-local reference such as
`{#c1}` or `{#s1}` and final YAML endmatter. Record `by`, a current ISO timestamp
in `at`, and `re` for replies. Replies belong in endmatter with `body` and `re`:

```markdown
{==selected text==}{>>Please add evidence.<<}{#c1}

---
comments:
  c1:
    by: user
    at: "2026-11-16T12:00:00.000Z"
  c2:
    body: Added a source in the next paragraph.
    by: AI
    at: "2026-11-16T12:05:00.000Z"
    re: c1
```

Preserve legacy inline metadata when present. Check `roughdraft help agent`,
`roughdraft help criticmarkup`, or the
[format specification](https://roughdraft.md/spec/roughdraft-flavored-markdown.md)
when exact syntax matters. Use `roughdraft doctor /absolute/path/to/draft.md`
to validate a review document. Consult the
[upstream setup guide](https://roughdraft.md/setup.md) for reference, but retain
this workflow's approval-focused scope and existing instruction-file layout.
