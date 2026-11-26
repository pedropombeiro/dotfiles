import type { Plugin } from "@opencode/plugin";
import {
  execGit,
  ForgeRegistry,
  oneLine,
  type CliRunner,
  type Forge,
  type GitRunner,
} from "./src/forges.ts";
import { execGh, GitHubForge } from "./src/github.ts";
import { execGlab, GitLabForge } from "./src/gitlab.ts";

const issueRequest =
  /^\s*(?:(?:let['’]?s|let us|go ahead and|i(?:['’]d| would) like (?:you )?to|i want (?:you )?to|(?:can|could|would) you)\s+)?(?:please\s+)?(?:(?:address|fix|implement|resolve|work on)\b|(?:create|open)\s+(?:(?:a|an)\s+)?(?:draft\s+)?(?:mr|pr|merge request|pull request)\s+(?:to\s+(?:address|fix|implement|resolve)|for)\b)/i;
// Forgekeeper's reference prefix, such as `[#123, !456]`.
const forgePrefix = /^\[[^\]\r\n]*[#!&]\d+[^\]\r\n]*\](?=\s|$)/;
const MAX_TITLE_LENGTH = 100;

export { ForgeRegistry, GitHubForge, GitLabForge };
export type {
  CliRunner,
  Forge,
  ForgeKind,
  GitRunner,
  ParsedForgeRef,
  RemoteProject,
  ResolvedReview,
  ReviewDetails,
} from "./src/forges.ts";

export const isIssueRequest = (text: string) => issueRequest.test(text);

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

export interface CreatePluginOptions {
  glab?: CliRunner;
  gh?: CliRunner;
  git?: GitRunner;
  forges?: readonly Forge[];
}

export function createPlugin(options: CreatePluginOptions = {}) {
  const forges = options.forges ?? [
    new GitLabForge(options.glab ?? execGlab),
    new GitHubForge(options.gh ?? execGh),
  ];
  const registry = new ForgeRegistry(forges, options.git ?? execGit);

  return {
    id: "forge-session-title",
    async setup(ctx) {
      const sessionDirectory = async (
        sessionID?: string,
        session?: { location?: { directory?: string } },
      ) => {
        if (session?.location?.directory) return session.location.directory;
        if (ctx.location?.directory) return ctx.location.directory;
        if (!sessionID) return undefined;
        const loaded = await ctx.session
          .get({ sessionID })
          .catch(() => undefined);
        return loaded?.location?.directory;
      };

      await ctx.tool.transform((editor) => {
        editor.add({
          name: "rename_mr_review_session",
          description:
            "Rename the current session using the PR/MR review title rules (`@<author> - Review <short topic>`). Use only when the user explicitly asks to rename a review session. Pass the first GitHub PR or GitLab MR URL or shorthand reference (such as !123, group/project!123, #42, or owner/repo#42) from the user's review request. If it isn't in the conversation, ask for it.",
          input: {
            type: "object",
            properties: {
              url: {
                type: "string",
                description:
                  "GitHub PR or GitLab MR URL or shorthand reference (such as !123, group/project!123, #42, or owner/repo#42).",
              },
              topic: {
                type: "string",
                description:
                  "Optional short review topic. Omit to derive it from the PR/MR title.",
              },
            },
            required: ["url"],
            additionalProperties: false,
          },
          options: { codemode: false },
          async execute(input, { sessionID, signal }) {
            const { url, topic } = input as { url: string; topic?: string };
            const parsed = registry.parseReview(url, { wholeInput: true });
            if (!parsed) {
              return {
                content:
                  "No title changed. Provide a GitHub PR or GitLab MR URL or shorthand reference (such as !123 or #42).",
              };
            }
            const session = await ctx.session.get({ sessionID });
            const cwd =
              parsed.path && parsed.forges.length === 1
                ? undefined
                : await sessionDirectory(sessionID, session);
            const review = await registry.lookupReview(parsed, cwd, signal);
            if (!review) {
              return {
                content:
                  "No title changed. Could not look up the PR/MR author.",
              };
            }

            const cleanedTopic = topic
              ? oneLine(topic.replace(/[!#]\d+\b/g, ""))
              : "";
            const explicitTopic =
              cleanedTopic && !/^(?:merge|pull) request$/i.test(cleanedTopic)
                ? cleanedTopic
                : "";
            const summary = explicitTopic || review.title || review.noun;
            const title = withForgePrefix(
              session.title,
              `@${review.username} - Review ${summary}`,
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
            "Rename the current session after the GitHub or GitLab issue, work item, or epic it addresses. Use only when the user explicitly asks to rename the session after an issue. Pass the URL or shorthand reference (such as #123 or owner/repo#123) from the user's request. If it isn't in the conversation, ask for it.",
          input: {
            type: "object",
            properties: {
              url: {
                type: "string",
                description:
                  "GitHub or GitLab issue, work item, or epic URL or shorthand reference (such as #123 or owner/repo#123).",
              },
            },
            required: ["url"],
            additionalProperties: false,
          },
          options: { codemode: false },
          async execute(input, { sessionID, signal }) {
            const { url } = input as { url: string };
            const parsed = registry.parseIssue(url, { wholeInput: true });
            if (!parsed) {
              return {
                content:
                  "No title changed. Provide a GitHub or GitLab issue or work item URL or shorthand reference (such as #123).",
              };
            }
            const session = await ctx.session.get({ sessionID });
            const cwd =
              parsed.path && parsed.forges.length === 1
                ? undefined
                : await sessionDirectory(sessionID, session);
            const issueTitle = await registry.lookupIssueTitle(
              parsed,
              cwd,
              signal,
            );
            if (!issueTitle) {
              return {
                content: "No title changed. Could not look up the issue title.",
              };
            }

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
          const issueRef = isIssueRequest(text)
            ? registry.parseIssue(text)
            : undefined;
          if (issueRef) {
            const cwd =
              issueRef.path && issueRef.forges.length === 1
                ? undefined
                : await sessionDirectory(event.sessionID);
            const title = await registry.lookupIssueTitle(issueRef, cwd);
            if (title)
              event.result = title.slice(0, MAX_TITLE_LENGTH).trimEnd();
            return;
          }
          const reviewRef = registry.parseReview(text);
          if (!reviewRef) continue;
          const cwd =
            reviewRef.path && reviewRef.forges.length === 1
              ? undefined
              : await sessionDirectory(event.sessionID);
          const review = await registry.lookupReview(reviewRef, cwd);
          if (review) {
            const titleSuffix = review.title ? ` ("${review.title}")` : "";
            event.system.push({
              type: "text",
              text: [
                `The ${review.label} ${review.noun} ${review.ref}${titleSuffix} is by @${review.username}.`,
                `Only if the user asks to review that ${review.noun}, use "@${review.username} - Review <short topic>", summarizing the topic from the user's request or the ${review.noun} title.`,
                `If the topic is still unknown, use "${review.noun}". Omit the ${review.noun} number (such as !123 or #123) and any bracketed prefix; Forgekeeper adds the reference.`,
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
