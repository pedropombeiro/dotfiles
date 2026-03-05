const DEFAULT_TITLE_RE = /^(New session - |Child session - )\d{4}-\d{2}-\d{2}T/;
const SKIP_BRANCHES = new Set(["master", "main", "HEAD", "develop"]);
const ISSUE_NUMBER_RE = /\/(\d+)\//;

export const SessionTitle = async ({ client, $, worktree }) => {
  async function getBranch() {
    try {
      const result = await $`git -C ${worktree} rev-parse --abbrev-ref HEAD 2>/dev/null`.text();
      const branch = result.trim();
      if (!branch || branch === "HEAD") return undefined;
      return branch;
    } catch {
      return undefined;
    }
  }

  return {
    event: async ({ event }) => {
      if (event.type !== "session.idle") return;

      const sessionID = event.properties.sessionID;
      const { data: session } = await client.session.get({ path: { id: sessionID } });
      if (!session) return;

      if (session.parentID) return;
      if (DEFAULT_TITLE_RE.test(session.title)) return;
      if (session.title.startsWith("[")) return;

      const branch = await getBranch();
      if (!branch || SKIP_BRANCHES.has(branch)) return;

      const issueMatch = branch.match(ISSUE_NUMBER_RE);
      const prefix = issueMatch ? `#${issueMatch[1]}` : branch;
      const newTitle = `[${prefix}] ${session.title}`;

      await client.session.update({
        path: { id: sessionID },
        body: { title: newTitle.slice(0, 100) },
      });
    },
  };
};
