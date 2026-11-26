import { execFile } from "node:child_process";
import { promisify } from "node:util";
import type { Plugin } from "@opencode/plugin";

const mrURL =
  /\bhttps:\/\/gitlab\.com\/((?:[\w.-]+\/)+[\w.-]+)\/-\/merge_requests\/([1-9]\d*)(?![\w-])/i;
const mrProjectRef =
  /(?<![\w/.:=?&-])((?:[\w.-]+\/)+[\w.-]+)!([1-9]\d*)(?![\w-])/i;
const mrShortRef = /(?<![\w/.:=?&-])!([1-9]\d*)(?![\w-])/;

const workItemURL =
  /\bhttps:\/\/gitlab\.com\/((?:[\w.-]+\/)+[\w.-]+)\/-\/(?:issues|work_items|epics)\/([1-9]\d*)(?![\w-])/i;
const workItemProjectRef =
  /(?<![\w/.:=?&-])((?:[\w.-]+\/)+[\w.-]+)#([1-9]\d*)(?![\w-])/i;
const workItemShortRef = /(?<![\w/.:=?&-])#([1-9]\d*)(?![\w-])/;

const issueRequest =
  /^\s*(?:(?:let['’]?s|let us|go ahead and|i(?:['’]d| would) like (?:you )?to|i want (?:you )?to|(?:can|could|would) you)\s+)?(?:please\s+)?(?:(?:address|fix|implement|resolve|work on)\b|(?:create|open)\s+(?:(?:a|an)\s+)?(?:draft\s+)?(?:mr|merge request)\s+(?:to\s+(?:address|fix|implement|resolve)|for)\b)/i;
// Forgekeeper's reference prefix, such as `[#123, !456]`.
const forgePrefix = /^\[[^\]\r\n]*[#!&]\d+[^\]\r\n]*\](?=\s|$)/;
const workItemQuery =
  "query($fullPath: ID!, $iid: String!) { namespace(fullPath: $fullPath) { workItem(iid: $iid) { title } } }";
const MAX_TITLE_LENGTH = 100;

export type Glab = (args: string[], signal?: AbortSignal) => Promise<string>;
export type Git = (
  args: string[],
  cwd: string,
  signal?: AbortSignal,
) => Promise<string>;

const execGlab: Glab = async (args, signal) => {
  const { stdout } = await promisify(execFile)(
    "glab",
    ["api", "--hostname", "gitlab.com", ...args],
    { timeout: 5000, signal },
  );
  return stdout;
};

const execGit: Git = async (args, cwd, signal) => {
  const { stdout } = await promisify(execFile)("git", args, {
    cwd,
    timeout: 3000,
    signal,
  });
  return stdout;
};

export function parseGitLabRemote(url: string): string | undefined {
  const trimmed = url.trim();
  let path: string | undefined;
  const scp = trimmed.match(/^(?:[^@/]+@)?gitlab\.com:(?!\/)(.+)$/i);
  if (scp && !/^[a-z][a-z0-9+.-]*:\/\//i.test(trimmed)) {
    path = scp[1];
  } else {
    let parsed: URL;
    try {
      parsed = new URL(trimmed);
    } catch {
      return undefined;
    }
    if (
      !["ssh:", "https:", "http:", "git+ssh:", "ssh+git:"].includes(
        parsed.protocol,
      ) ||
      parsed.hostname.toLowerCase() !== "gitlab.com"
    ) {
      return undefined;
    }
    path = decodeURIComponent(parsed.pathname);
  }
  path = path
    .replace(/^\/+/, "")
    .replace(/\/+$/, "")
    .replace(/\.git$/i, "");
  if (!/^(?:[\w.-]+\/)+[\w.-]+$/.test(path)) return undefined;
  return path;
}

export interface ParsedMRRef {
  ref: string;
  url?: string;
  project?: string;
  iid: string;
}

export interface ParsedWorkItemRef {
  ref: string;
  url?: string;
  fullPath?: string;
  iid: string;
}

function firstMatch<T extends { index: number }>(
  matches: Array<T | undefined>,
): T | undefined {
  let best: T | undefined;
  for (const candidate of matches) {
    if (!candidate) continue;
    if (!best || candidate.index < best.index) best = candidate;
  }
  return best;
}

export function parseMRRef(text: string): ParsedMRRef | undefined {
  const urlMatch = mrURL.exec(text);
  const projectMatch = mrProjectRef.exec(text);
  const shortMatch = mrShortRef.exec(text);

  const explicit = firstMatch([
    urlMatch
      ? {
          index: urlMatch.index,
          ref: urlMatch[0],
          url: urlMatch[0],
          project: urlMatch[1],
          iid: urlMatch[2],
        }
      : undefined,
    projectMatch
      ? {
          index: projectMatch.index,
          ref: projectMatch[0],
          project: projectMatch[1],
          iid: projectMatch[2],
        }
      : undefined,
  ]);
  const bare = shortMatch
    ? { index: shortMatch.index, ref: shortMatch[0], iid: shortMatch[1] }
    : undefined;

  const chosen = firstMatch([explicit, bare]);
  if (!chosen) return undefined;
  // Prefer an explicit project reference when a markdown link like `[!123](url)` names the same IID.
  if (!("project" in chosen) && explicit && explicit.iid === chosen.iid) {
    const { index: _, ...rest } = explicit;
    return rest;
  }
  const { index: _, ...rest } = chosen;
  return rest;
}

export function parseWorkItemURL(text: string) {
  const match = workItemURL.exec(text);
  if (!match) return;
  const [url, path, iid] = match;
  // Group work items and epics live under `/groups/<group>/-/`.
  return { url, fullPath: path.replace(/^groups\//, ""), iid };
}

export function parseWorkItemRef(text: string): ParsedWorkItemRef | undefined {
  const urlMatch = workItemURL.exec(text);
  const projectMatch = workItemProjectRef.exec(text);
  const shortMatch = workItemShortRef.exec(text);

  const explicit = firstMatch([
    urlMatch
      ? {
          index: urlMatch.index,
          ref: urlMatch[0],
          url: urlMatch[0],
          fullPath: urlMatch[1].replace(/^groups\//, ""),
          iid: urlMatch[2],
        }
      : undefined,
    projectMatch
      ? {
          index: projectMatch.index,
          ref: projectMatch[0],
          fullPath: projectMatch[1],
          iid: projectMatch[2],
        }
      : undefined,
  ]);
  const bare = shortMatch
    ? { index: shortMatch.index, ref: shortMatch[0], iid: shortMatch[1] }
    : undefined;

  const chosen = firstMatch([explicit, bare]);
  if (!chosen) return undefined;
  if (!("fullPath" in chosen) && explicit && explicit.iid === chosen.iid) {
    const { index: _, ...rest } = explicit;
    return rest;
  }
  const { index: _, ...rest } = chosen;
  return rest;
}

export const isIssueRequest = (text: string) => issueRequest.test(text);

const isWholeRef = (input: string, parsed: { ref: string; url?: string }) => {
  const trimmed = input.trim();
  if (parsed.url) {
    return (
      trimmed.startsWith(parsed.url) &&
      /^(?:[/?#]|$)/.test(trimmed.slice(parsed.url.length))
    );
  }
  return trimmed === parsed.ref;
};

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

export function createPlugin(glab: Glab = execGlab, git: Git = execGit) {
  async function resolveGitLabProjects(
    cwd: string | undefined,
    signal?: AbortSignal,
  ): Promise<string[]> {
    if (!cwd) return [];
    let stdout: string;
    try {
      stdout = await git(
        ["config", "--get-regexp", "^remote\\..*\\.url$"],
        cwd,
        signal,
      );
    } catch {
      return [];
    }
    const remotes: Array<[string, string]> = [];
    for (const line of stdout.split("\n")) {
      const match = line.match(/^remote\.(.+)\.url\s+(.+)$/);
      if (match) remotes.push([match[1], match[2]]);
    }
    const rank = (name: string) =>
      name === "origin" ? 0 : name === "upstream" ? 1 : 2;
    remotes.sort(([a], [b]) => rank(a) - rank(b));

    const projects: string[] = [];
    const seen = new Set<string>();
    for (const [, url] of remotes) {
      const project = parseGitLabRemote(url);
      if (!project) continue;
      const lower = project.toLowerCase();
      if (seen.has(lower)) continue;
      seen.add(lower);
      projects.push(project);
    }
    return projects;
  }

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

  async function lookupWorkItemTitleAcrossProjects(
    fullPath: string | undefined,
    iid: string,
    cwd: string | undefined,
    signal?: AbortSignal,
  ) {
    const candidates = fullPath
      ? [fullPath]
      : await resolveGitLabProjects(cwd, signal);
    for (const candidate of candidates) {
      if (signal?.aborted) return undefined;
      const title = await lookupWorkItemTitle(candidate, iid, signal);
      if (title) return title;
    }
    return undefined;
  }

  async function lookupMergeRequest(
    project: string,
    iid: string,
    signal?: AbortSignal,
  ): Promise<{ username: string; title?: string } | undefined> {
    try {
      const endpoint = `projects/${encodeURIComponent(project)}/merge_requests/${iid}`;
      const data = JSON.parse(await glab([endpoint], signal));
      const username: unknown = data?.author?.username;
      if (typeof username !== "string" || !/^[\w.-]+$/.test(username))
        return undefined;
      const rawTitle: unknown = data?.title;
      const title =
        typeof rawTitle === "string" && oneLine(rawTitle)
          ? oneLine(rawTitle)
          : undefined;
      return { username, title };
    } catch {
      return undefined;
    }
  }

  async function lookupMergeRequestAcrossProjects(
    project: string | undefined,
    iid: string,
    cwd: string | undefined,
    signal?: AbortSignal,
  ) {
    const candidates = project
      ? [project]
      : await resolveGitLabProjects(cwd, signal);
    for (const candidate of candidates) {
      if (signal?.aborted) return undefined;
      const mr = await lookupMergeRequest(candidate, iid, signal);
      if (mr) return mr;
    }
    return undefined;
  }

  return {
    id: "gitlab-session-title",
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
            "Rename the current session using the GitLab MR review title rules. Use only when the user explicitly asks to rename a review session. Pass the first GitLab.com MR URL or shorthand reference (such as !123 or group/project!123) from the user's review request. If it isn't in the conversation, ask for it.",
          input: {
            type: "object",
            properties: {
              url: {
                type: "string",
                description:
                  "GitLab.com MR URL or shorthand reference (such as !123 or group/project!123) from the user's review request.",
              },
              topic: {
                type: "string",
                description:
                  "Optional short review topic. Omit to derive it from the GitLab MR title.",
              },
            },
            required: ["url"],
            additionalProperties: false,
          },
          options: { codemode: false },
          async execute(input, { sessionID, signal }) {
            const { url, topic } = input as { url: string; topic?: string };
            const parsed = parseMRRef(url);
            if (!parsed || !isWholeRef(url, parsed)) {
              return {
                content:
                  "No title changed. Provide a GitLab.com merge request URL or shorthand reference (such as !123).",
              };
            }
            const session = await ctx.session.get({ sessionID });
            const cwd = await sessionDirectory(sessionID, session);
            const mr = await lookupMergeRequestAcrossProjects(
              parsed.project,
              parsed.iid,
              cwd,
              signal,
            );
            if (!mr)
              return {
                content: "No title changed. Could not look up the MR author.",
              };

            const cleanedTopic = topic
              ? oneLine(topic.replace(/[!#]\d+\b/g, ""))
              : "";
            const explicitTopic =
              cleanedTopic && cleanedTopic.toLowerCase() !== "merge request"
                ? cleanedTopic
                : "";
            const summary = explicitTopic || mr.title || "merge request";
            const title = withForgePrefix(
              session.title,
              `@${mr.username} - Review ${summary}`,
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
            "Rename the current session after the GitLab issue or work item it addresses. Use only when the user explicitly asks to rename the session after an issue. Pass the GitLab.com issue, work item, or epic URL or shorthand reference (such as #123 or group/project#123) from the user's request. If it isn't in the conversation, ask for it.",
          input: {
            type: "object",
            properties: {
              url: {
                type: "string",
                description:
                  "GitLab.com issue, work item, or epic URL or shorthand reference (such as #123 or group/project#123) that the session addresses.",
              },
            },
            required: ["url"],
            additionalProperties: false,
          },
          options: { codemode: false },
          async execute(input, { sessionID, signal }) {
            const { url } = input as { url: string };
            const item = parseWorkItemRef(url);
            if (!item || !isWholeRef(url, item)) {
              return {
                content:
                  "No title changed. Provide a GitLab.com issue or work item URL or shorthand reference (such as #123).",
              };
            }
            const session = await ctx.session.get({ sessionID });
            const cwd = await sessionDirectory(sessionID, session);
            const issueTitle = await lookupWorkItemTitleAcrossProjects(
              item.fullPath,
              item.iid,
              cwd,
              signal,
            );
            if (!issueTitle)
              return {
                content: "No title changed. Could not look up the issue title.",
              };

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
            ? parseWorkItemRef(text)
            : undefined;
          if (item) {
            const cwd = item.fullPath
              ? undefined
              : await sessionDirectory(event.sessionID);
            const title = await lookupWorkItemTitleAcrossProjects(
              item.fullPath,
              item.iid,
              cwd,
            );
            if (title)
              event.result = title.slice(0, MAX_TITLE_LENGTH).trimEnd();
            return;
          }
          const parsedMR = parseMRRef(text);
          if (!parsedMR) continue;
          const cwd = parsedMR.project
            ? undefined
            : await sessionDirectory(event.sessionID);
          const mr = await lookupMergeRequestAcrossProjects(
            parsedMR.project,
            parsedMR.iid,
            cwd,
          );
          if (mr) {
            const titleSuffix = mr.title ? ` ("${mr.title}")` : "";
            event.system.push({
              type: "text",
              text: [
                `The GitLab merge request ${parsedMR.ref}${titleSuffix} is by @${mr.username}.`,
                `Only if the user asks to review that MR, use "@${mr.username} - Review <short topic>", summarizing the topic from the user's request or the MR title.`,
                'If the topic is still unknown, use "merge request". Omit the MR number (such as !123) and any bracketed prefix; Forgekeeper adds the reference.',
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
