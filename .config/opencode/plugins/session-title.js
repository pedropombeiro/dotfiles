const DEFAULT_TITLE_RE = /^(New session - |Child session - )\d{4}-\d{2}-\d{2}T/;
const SKIP_BRANCHES = new Set(["master", "main", "HEAD", "develop"]);
const ISSUE_NUMBER_RE = /\/(\d+)\//;
const TITLE_PREFIX_RE = /^\[([^\]]*)\] /;

export const SessionTitle = async ({ client, $, worktree }) => {
  const mrCache = new Map();

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

  async function getMrIid(branch) {
    if (mrCache.has(branch)) return mrCache.get(branch);

    try {
      const output = await $`glab mr list --source-branch ${branch} 2>/dev/null`.cwd(worktree).text();
      const match = output.match(/^!(\d+)\t/m);
      const iid = match ? match[1] : undefined;
      if (iid) mrCache.set(branch, iid);
      return iid;
    } catch {
      return undefined;
    }
  }

  return {
    event: async ({ event }) => {
      if (event.type !== "session.idle") return;

      const sessionID = event.properties.sessionID;
      const { data: session } = await client.session.get({
        path: { id: sessionID },
      });
      if (!session) return;
      if (session.parentID) return;
      if (DEFAULT_TITLE_RE.test(session.title)) return;

      const branch = await getBranch();
      if (!branch || SKIP_BRANCHES.has(branch)) return;

      const existingPrefix = session.title.match(TITLE_PREFIX_RE);

      if (existingPrefix) {
        const prefixContent = existingPrefix[1];
        const hasRealMr = /!\d+/.test(prefixContent);
        if (hasRealMr) return;

        const hasPlaceholderMr = prefixContent.includes("!N/A");
        if (!hasPlaceholderMr) {
          const mrIid = await getMrIid(branch);
          const mrTag = mrIid ? `!${mrIid}` : "!N/A";
          const newPrefix = `${prefixContent}, ${mrTag}`;
          const rest = session.title.slice(existingPrefix[0].length);
          const newTitle = `[${newPrefix}] ${rest}`;
          await client.session.update({
            path: { id: sessionID },
            body: { title: newTitle.slice(0, 100) },
          });
          return;
        }

        const mrIid = await getMrIid(branch);
        if (!mrIid) return;
        const newPrefix = prefixContent.replace("!N/A", `!${mrIid}`);
        const rest = session.title.slice(existingPrefix[0].length);
        const newTitle = `[${newPrefix}] ${rest}`;
        await client.session.update({
          path: { id: sessionID },
          body: { title: newTitle.slice(0, 100) },
        });
        return;
      }

      const issueMatch = branch.match(ISSUE_NUMBER_RE);
      const mrIid = await getMrIid(branch);

      const parts = [];
      if (issueMatch) parts.push(`#${issueMatch[1]}`);
      else parts.push(branch);
      parts.push(mrIid ? `!${mrIid}` : "!N/A");

      const newTitle = `[${parts.join(", ")}] ${session.title}`;

      await client.session.update({
        path: { id: sessionID },
        body: { title: newTitle.slice(0, 100) },
      });
    },
  };
};
