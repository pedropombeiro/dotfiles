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

const prURL =
  /\bhttps:\/\/github\.com\/([\w.-]+\/[\w.-]+)\/pull\/([1-9]\d*)(?![\w-])/i;
const issueURL =
  /\bhttps:\/\/github\.com\/([\w.-]+\/[\w.-]+)\/issues\/([1-9]\d*)(?![\w-])/i;
const repoHashRef = /(?<![\w/.:=?&-])([\w.-]+\/[\w.-]+)#([1-9]\d*)(?![\w-])/i;
const shortHashRef = /(?<![\w/.:=?&-])#([1-9]\d*)(?![\w-])/;

export const execGh: CliRunner = async (args, signal) => {
  const { stdout } = await promisify(execFile)(
    "gh",
    ["api", "--hostname", "github.com", ...args],
    { timeout: 5000, signal },
  );
  return stdout;
};

function firstHashShorthand(text: string): ShorthandMatch | undefined {
  const repoMatch = repoHashRef.exec(text);
  const shortMatch = shortHashRef.exec(text);
  if (repoMatch && (!shortMatch || repoMatch.index <= shortMatch.index)) {
    return {
      index: repoMatch.index,
      ref: repoMatch[0],
      path: repoMatch[1],
      iid: repoMatch[2],
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

export class GitHubForge implements Forge {
  readonly kind = "github" as const;
  readonly host = "github.com";
  readonly label = "GitHub";
  readonly noun = "pull request" as const;

  constructor(private readonly gh: CliRunner = execGh) {}

  parseRemote(url: string): string | undefined {
    const path = parseRemoteForHost(url, this.host);
    return path && this.canResolvePath(path) ? path : undefined;
  }

  canResolvePath(path: string): boolean {
    return /^[\w.-]+\/[\w.-]+$/.test(path);
  }

  parseReviewURL(text: string): URLMatch | undefined {
    const match = prURL.exec(text);
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
    const match = issueURL.exec(text);
    if (!match) return undefined;
    return {
      index: match.index,
      ref: match[0],
      url: match[0],
      path: match[1],
      iid: match[2],
    };
  }

  parseReviewShorthand(text: string): ShorthandMatch | undefined {
    return firstHashShorthand(text);
  }

  parseIssueShorthand(text: string): ShorthandMatch | undefined {
    return firstHashShorthand(text);
  }

  async lookupReview(
    path: string,
    iid: string,
    signal?: AbortSignal,
  ): Promise<ReviewDetails | undefined> {
    try {
      const endpoint = `repos/${path}/pulls/${iid}`;
      const data = JSON.parse(await this.gh([endpoint], signal));
      const username: unknown = data?.user?.login;
      if (
        typeof username !== "string" ||
        !/^[\w.-]+(?:\[bot\])?$/.test(username)
      ) {
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
      const endpoint = `repos/${path}/issues/${iid}`;
      const data = JSON.parse(await this.gh([endpoint], signal));
      // GitHub's issues endpoint also returns PRs; skip them here.
      if (data?.pull_request) return undefined;
      const title: unknown = data?.title;
      if (typeof title === "string" && oneLine(title)) return oneLine(title);
    } catch {
      return undefined;
    }
  }
}
