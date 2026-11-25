import { execFile } from "node:child_process";
import { promisify } from "node:util";
import type { Plugin } from "@opencode/plugin";

const exec = promisify(execFile);
const mrURL = /\bhttps:\/\/gitlab\.com\/((?:[\w.-]+\/)+[\w.-]+)\/-\/merge_requests\/([1-9]\d*)(?![\w-])/i;

async function lookupAuthor(project: string, iid: string, signal?: AbortSignal) {
  try {
    const endpoint = `projects/${encodeURIComponent(project)}/merge_requests/${iid}`;
    const { stdout } = await exec("glab", ["api", "--hostname", "gitlab.com", endpoint], { timeout: 5000, signal });
    const username: unknown = JSON.parse(stdout)?.author?.username;
    if (typeof username === "string" && /^[\w.-]+$/.test(username)) return username;
  } catch {
    return undefined;
  }
}

export default {
  id: "title-mr-author",
  async setup(ctx) {
    await ctx.tool.transform((editor) => {
      editor.add({
        name: "rename_mr_review_session",
        description: "Rename the current session using the GitLab MR review title rules. Use only when the user explicitly asks to rename a review session. Use the first full GitLab.com MR URL from the user's review request. If it isn't in the conversation, ask for it.",
        input: {
          type: "object",
          properties: {
            url: { type: "string", description: "Full GitLab.com MR URL from the user's review request." },
            topic: { type: "string", description: "Short review topic. Use 'merge request' if unknown." },
          },
          required: ["url", "topic"],
          additionalProperties: false,
        },
        options: { codemode: false },
        async execute(input, { sessionID, signal }) {
          const { url, topic } = input as { url: string; topic: string };
          const match = mrURL.exec(url);
          if (!match || match.index !== 0 || !/^(?:[/?#]|$)/.test(url.slice(match[0].length))) {
            return { content: "No title changed. Provide a full GitLab.com merge request URL." };
          }
          const [, project, iid] = match;
          const username = await lookupAuthor(project, iid, signal);
          if (!username) return { content: "No title changed. Could not look up the MR author." };

          const session = await ctx.session.get({ sessionID });
          const prefix = session.title?.match(/^\[[^\]\r\n]*!\d+[^\]\r\n]*\](?=\s|$)/)?.[0];
          const start = `${prefix ? `${prefix} ` : ""}@${username} - Review `;
          const summary = topic.replace(/[!#]\d+\b/g, "").replace(/\s+/g, " ").trim() || "merge request";
          const title = `${start}${summary}`.slice(0, 100).trimEnd();
          if (signal?.aborted) return { content: "Rename cancelled." };
          if (title !== session.title) await ctx.session.update({ sessionID, title });
          return { content: `Session title: ${title}` };
        },
      });
    });

    await ctx.session.hook("title", async (event) => {
      for (const { role, content } of event.messages) {
        if (role !== "user") continue;
        const text = typeof content === "string" ? content : Array.isArray(content)
          ? content.flatMap((part) => part?.type === "text" ? [part.text] : []).join("\n")
          : "";
        const match = mrURL.exec(text);
        if (!match) continue;
        const [url, project, iid] = match;
        const username = await lookupAuthor(project, iid);
        if (username) {
          event.system.push({ type: "text", text: [
            `The GitLab author of ${url} is @${username}.`,
            `Only if the user asks to review that MR, use "@${username} - Review <short topic>".`,
            'If the topic is unknown, use "merge request". Omit the MR number and any bracketed prefix; Forgekeeper adds the reference.',
            "For all other requests, follow the usual title rules without adding an author.",
          ].join("\n") });
        }
        return;
      }
    });
  },
} satisfies Plugin;
