import { execFile } from "node:child_process";
import { promisify } from "node:util";
import type { Plugin } from "@opencode/plugin";

const mrURL =
  /\bhttps:\/\/gitlab\.com\/((?:[\w.-]+\/)+[\w.-]+)\/-\/merge_requests\/([1-9]\d*)(?![\w-])/i;
const workItemURL =
  /\bhttps:\/\/gitlab\.com\/((?:[\w.-]+\/)+[\w.-]+)\/-\/(?:issues|work_items|epics)\/([1-9]\d*)(?![\w-])/i;
const issueRequest =
  /^\s*(?:(?:can|could|would) you\s+)?(?:please\s+)?(?:(?:address|fix|implement|resolve|work on)\b|(?:create|open)\s+(?:(?:a|an)\s+)?(?:draft\s+)?(?:mr|merge request)\s+(?:to\s+(?:address|fix|implement|resolve)|for)\b)/i;
// Forgekeeper's reference prefix, such as `[#123, !456]`.
const forgePrefix = /^\[[^\]\r\n]*[#!&]\d+[^\]\r\n]*\](?=\s|$)/;
const workItemQuery =
  "query($fullPath: ID!, $iid: String!) { namespace(fullPath: $fullPath) { workItem(iid: $iid) { title } } }";
const MAX_TITLE_LENGTH = 100;

type Glab = (args: string[], signal?: AbortSignal) => Promise<string>;

const execGlab: Glab = async (args, signal) => {
  const { stdout } = await promisify(execFile)(
    "glab",
    ["api", "--hostname", "gitlab.com", ...args],
    { timeout: 5000, signal },
  );
  return stdout;
};

export function parseWorkItemURL(text: string) {
  const match = workItemURL.exec(text);
  if (!match) return;
  const [url, path, iid] = match;
  // Group work items and epics live under `/groups/<group>/-/`.
  return { url, fullPath: path.replace(/^groups\//, ""), iid };
}

export const isIssueRequest = (text: string) => issueRequest.test(text);

const isWholeURL = (input: string, matched: string) =>
  input.startsWith(matched) && /^(?:[/?#]|$)/.test(input.slice(matched.length));

const oneLine = (text: string) => text.replace(/\s+/g, " ").trim();

export function withForgePrefix(current: string | undefined, title: string) {
  const prefix = current?.match(forgePrefix)?.[0];
  return `${prefix ? `${prefix} ` : ""}${title}`
    .slice(0, MAX_TITLE_LENGTH)
    .trimEnd();
}

const messageText = (content: unknown) =>
  typeof content === "string"
    ? content
    : Array.isArray(content)
      ? content
          .flatMap((part) => (part?.type === "text" ? [part.text] : []))
          .join("\n")
      : "";

export function createPlugin(glab: Glab = execGlab) {
  async function lookupWorkItemTitle(
    fullPath: string,
    iid: string,
    signal?: AbortSignal,
  ) {
    try {
      const stdout = await glab(
        [
          "graphql",
          "-f",
          `query=${workItemQuery}`,
          "-f",
          `fullPath=${fullPath}`,
          "-f",
          `iid=${iid}`,
        ],
        signal,
      );
      const title: unknown =
        JSON.parse(stdout)?.data?.namespace?.workItem?.title;
      if (typeof title === "string" && oneLine(title)) return oneLine(title);
    } catch {
      return undefined;
    }
  }

  async function lookupAuthor(
    project: string,
    iid: string,
    signal?: AbortSignal,
  ) {
    try {
      const endpoint = `projects/${encodeURIComponent(project)}/merge_requests/${iid}`;
      const username: unknown = JSON.parse(await glab([endpoint], signal))
        ?.author?.username;
      if (typeof username === "string" && /^[\w.-]+$/.test(username))
        return username;
    } catch {
      return undefined;
    }
  }

  return {
    id: "title-mr-author",
    async setup(ctx) {
      await ctx.tool.transform((editor) => {
        editor.add({
          name: "rename_mr_review_session",
          description:
            "Rename the current session using the GitLab MR review title rules. Use only when the user explicitly asks to rename a review session. Use the first full GitLab.com MR URL from the user's review request. If it isn't in the conversation, ask for it.",
          input: {
            type: "object",
            properties: {
              url: {
                type: "string",
                description:
                  "Full GitLab.com MR URL from the user's review request.",
              },
              topic: {
                type: "string",
                description:
                  "Short review topic. Use 'merge request' if unknown.",
              },
            },
            required: ["url", "topic"],
            additionalProperties: false,
          },
          options: { codemode: false },
          async execute(input, { sessionID, signal }) {
            const { url, topic } = input as { url: string; topic: string };
            const match = mrURL.exec(url);
            if (!match || match.index !== 0 || !isWholeURL(url, match[0])) {
              return {
                content:
                  "No title changed. Provide a full GitLab.com merge request URL.",
              };
            }
            const [, project, iid] = match;
            const username = await lookupAuthor(project, iid, signal);
            if (!username)
              return {
                content: "No title changed. Could not look up the MR author.",
              };

            const session = await ctx.session.get({ sessionID });
            const summary =
              oneLine(topic.replace(/[!#]\d+\b/g, "")) || "merge request";
            const title = withForgePrefix(
              session.title,
              `@${username} - Review ${summary}`,
            );
            if (signal?.aborted) return { content: "Rename cancelled." };
            if (title !== session.title)
              await ctx.session.update({ sessionID, title });
            return { content: `Session title: ${title}` };
          },
        });
        editor.add({
          name: "rename_issue_session",
          description:
            "Rename the current session after the GitLab issue or work item it addresses. Use only when the user explicitly asks to rename the session after an issue. Use the full GitLab.com issue or work item URL from the user's request. If it isn't in the conversation, ask for it.",
          input: {
            type: "object",
            properties: {
              url: {
                type: "string",
                description:
                  "Full GitLab.com issue, work item, or epic URL that the session addresses.",
              },
            },
            required: ["url"],
            additionalProperties: false,
          },
          options: { codemode: false },
          async execute(input, { sessionID, signal }) {
            const { url } = input as { url: string };
            const item = parseWorkItemURL(url);
            if (!item || !isWholeURL(url, item.url)) {
              return {
                content:
                  "No title changed. Provide a full GitLab.com issue or work item URL.",
              };
            }
            const issueTitle = await lookupWorkItemTitle(
              item.fullPath,
              item.iid,
              signal,
            );
            if (!issueTitle)
              return {
                content: "No title changed. Could not look up the issue title.",
              };

            const session = await ctx.session.get({ sessionID });
            const title = withForgePrefix(session.title, issueTitle);
            if (signal?.aborted) return { content: "Rename cancelled." };
            if (title !== session.title)
              await ctx.session.update({ sessionID, title });
            return { content: `Session title: ${title}` };
          },
        });
      });

      await ctx.session.hook("title", async (event) => {
        if (event.result !== undefined) return;
        for (const { role, content } of event.messages) {
          if (role !== "user") continue;
          const text = messageText(content);
          const item = isIssueRequest(text)
            ? parseWorkItemURL(text)
            : undefined;
          if (item) {
            const title = await lookupWorkItemTitle(item.fullPath, item.iid);
            if (title)
              event.result = title.slice(0, MAX_TITLE_LENGTH).trimEnd();
            return;
          }
          const match = mrURL.exec(text);
          if (!match) continue;
          const [url, project, iid] = match;
          const username = await lookupAuthor(project, iid);
          if (username) {
            event.system.push({
              type: "text",
              text: [
                `The GitLab author of ${url} is @${username}.`,
                `Only if the user asks to review that MR, use "@${username} - Review <short topic>".`,
                'If the topic is unknown, use "merge request". Omit the MR number and any bracketed prefix; Forgekeeper adds the reference.',
                "For all other requests, follow the usual title rules without adding an author.",
              ].join("\n"),
            });
          }
          return;
        }
      });
    },
  } satisfies Plugin;
}

export default createPlugin();
