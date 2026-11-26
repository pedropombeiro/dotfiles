import { execFile } from "node:child_process";
import { promisify } from "node:util";
import {
  oneLine,
  parseRemoteForHost,
  type CliRunner,
  type Forge,
  type ReviewDetails,
  type ShorthandMatch,
  type URLMatch,
} from "./forges.ts";

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

const workItemQuery =
  "query($fullPath: ID!, $iid: String!) { namespace(fullPath: $fullPath) { workItem(iid: $iid) { title } } }";

export const execGlab: CliRunner = async (args, signal) => {
  const { stdout } = await promisify(execFile)(
    "glab",
    ["api", "--hostname", "gitlab.com", ...args],
    { timeout: 5000, signal },
  );
  return stdout;
};

function firstShorthand(
  projectMatch: RegExpExecArray | null,
  shortMatch: RegExpExecArray | null,
): ShorthandMatch | undefined {
  if (projectMatch && (!shortMatch || projectMatch.index <= shortMatch.index)) {
    return {
      index: projectMatch.index,
      ref: projectMatch[0],
      path: projectMatch[1],
      iid: projectMatch[2],
    };
  }
  if (shortMatch) {
    return {
      index: shortMatch.index,
      ref: shortMatch[0],
      iid: shortMatch[1],
    };
  }
  return undefined;
}

export class GitLabForge implements Forge {
  readonly kind = "gitlab" as const;
  readonly host = "gitlab.com";
  readonly label = "GitLab";
  readonly noun = "merge request" as const;

  constructor(private readonly glab: CliRunner = execGlab) {}

  parseRemote(url: string): string | undefined {
    return parseRemoteForHost(url, this.host);
  }

  canResolvePath(path: string): boolean {
    return /^(?:[\w.-]+\/)+[\w.-]+$/.test(path);
  }

  parseReviewURL(text: string): URLMatch | undefined {
    const match = mrURL.exec(text);
    if (!match) return undefined;
    return {
      index: match.index,
      ref: match[0],
      url: match[0],
      path: match[1],
      iid: match[2],
    };
  }

  parseIssueURL(text: string): URLMatch | undefined {
    const match = workItemURL.exec(text);
    if (!match) return undefined;
    return {
      index: match.index,
      ref: match[0],
      url: match[0],
      // Group work items and epics live under `/groups/<group>/-/`.
      path: match[1].replace(/^groups\//, ""),
      iid: match[2],
    };
  }

  parseReviewShorthand(text: string): ShorthandMatch | undefined {
    return firstShorthand(mrProjectRef.exec(text), mrShortRef.exec(text));
  }

  parseIssueShorthand(text: string): ShorthandMatch | undefined {
    return firstShorthand(
      workItemProjectRef.exec(text),
      workItemShortRef.exec(text),
    );
  }

  async lookupReview(
    path: string,
    iid: string,
    signal?: AbortSignal,
  ): Promise<ReviewDetails | undefined> {
    try {
      const endpoint = `projects/${encodeURIComponent(path)}/merge_requests/${iid}`;
      const data = JSON.parse(await this.glab([endpoint], signal));
      const username: unknown = data?.author?.username;
      if (typeof username !== "string" || !/^[\w.-]+$/.test(username)) {
        return undefined;
      }
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

  async lookupIssueTitle(
    path: string,
    iid: string,
    signal?: AbortSignal,
  ): Promise<string | undefined> {
    try {
      const stdout = await this.glab(
        [
          "graphql",
          "-f",
          `query=${workItemQuery}`,
          "-f",
          `fullPath=${path}`,
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
}
