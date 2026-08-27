const COMMIT_OR_TAG_PATTERN = /(^|[;&|]\s*)\s*(?:git|yadm)\s+(?:enter\s+git\s+)?(?:commit|tag)\b/
const CROSS_PROJECT_REFERENCE_PATTERN = /\b[\w.-]+(?:\/[\w.-]+)*[#!&]\d+\b/
const BARE_ISSUE_REFERENCE_PATTERN = /(?<![\w/#])#\d+\b/
const BARE_MR_REFERENCE_PATTERN = /(?<![\w/!])!\d+\b/
// The `>` exclusion keeps shell redirects such as `2>&1` and `1>&2` from being
// read as epic references, since the whole command is scanned, not just the
// commit message. Cross-project epics like `gitlab-org&42` are still caught by
// CROSS_PROJECT_REFERENCE_PATTERN.
const BARE_EPIC_REFERENCE_PATTERN = /(?<![\w/&>])&\d+\b/

const findShortReference = (message) => {
  for (const pattern of [
    CROSS_PROJECT_REFERENCE_PATTERN,
    BARE_ISSUE_REFERENCE_PATTERN,
    BARE_MR_REFERENCE_PATTERN,
    BARE_EPIC_REFERENCE_PATTERN,
  ]) {
    const match = message.match(pattern)

    if (match) {
      return match[0]
    }
  }
}

export const NoShortGitlabRefs = async () => {
  return {
    "tool.execute.before": async (input, output) => {
      if (
        input.tool !== "bash" ||
        process.env.OPENCODE_ALLOW_SHORT_GITLAB_REFS === "1"
      ) {
        return
      }

      const command = output?.args?.command ?? ""
      const commitOrTag = command.match(COMMIT_OR_TAG_PATTERN)

      if (!commitOrTag || commitOrTag.index === undefined) {
        return
      }

      // Scan from the commit/tag invocation to include quoted messages and heredocs.
      const reference = findShortReference(
        command.slice(commitOrTag.index + commitOrTag[0].length),
      )

      if (!reference) {
        return
      }

      throw new Error(
        `Commit messages must not contain shortened GitLab references. Found: \`${reference}\`. ` +
          "Use the full canonical URL instead: `https://gitlab.com/<group>/<project>/-/issues/<iid>`, " +
          "`https://gitlab.com/<group>/<project>/-/merge_requests/<iid>`, or " +
          "`https://gitlab.com/groups/<group>/-/epics/<iid>`. Rewrite the message; DO NOT bypass " +
          "this check with `--no-verify` or by writing the message to a file. A human may set " +
          "`OPENCODE_ALLOW_SHORT_GITLAB_REFS=1` in OpenCode's environment for an explicit exception.",
      )
    },
  }
}
