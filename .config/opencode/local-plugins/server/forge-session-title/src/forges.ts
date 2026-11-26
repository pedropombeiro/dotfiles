import { execFile } from "node:child_process";
import { promisify } from "node:util";

export type ForgeKind = "gitlab" | "github";
export type ReviewNoun = "merge request" | "pull request";

export type CliRunner = (
  args: string[],
  signal?: AbortSignal,
) => Promise<string>;
export type GitRunner = (
  args: string[],
  cwd: string,
  signal?: AbortSignal,
) => Promise<string>;

export interface URLMatch {
  readonly index: number;
  readonly ref: string;
  readonly url: string;
  readonly path: string;
  readonly iid: string;
}

export interface ShorthandMatch {
  readonly index: number;
  readonly ref: string;
  readonly path?: string;
  readonly iid: string;
}

export interface ReviewDetails {
  readonly username: string;
  readonly title?: string;
}

export interface ResolvedReview extends ReviewDetails {
  readonly forge: ForgeKind;
  readonly label: string;
  readonly noun: ReviewNoun;
  readonly ref: string;
}

export interface ParsedForgeRef {
  readonly ref: string;
  readonly url?: string;
  readonly path?: string;
  readonly iid: string;
  readonly forges: readonly Forge[];
}

export interface RemoteProject {
  readonly forge: Forge;
  readonly path: string;
}

export interface Forge {
  readonly kind: ForgeKind;
  readonly host: string;
  readonly label: string;
  readonly noun: ReviewNoun;
  parseRemote(url: string): string | undefined;
  canResolvePath(path: string): boolean;
  parseReviewURL(text: string): URLMatch | undefined;
  parseIssueURL(text: string): URLMatch | undefined;
  parseReviewShorthand(text: string): ShorthandMatch | undefined;
  parseIssueShorthand(text: string): ShorthandMatch | undefined;
  lookupReview(
    path: string,
    iid: string,
    signal?: AbortSignal,
  ): Promise<ReviewDetails | undefined>;
  lookupIssueTitle(
    path: string,
    iid: string,
    signal?: AbortSignal,
  ): Promise<string | undefined>;
}

export const execGit: GitRunner = async (args, cwd, signal) => {
  const { stdout } = await promisify(execFile)("git", args, {
    cwd,
    timeout: 3000,
    signal,
  });
  return stdout;
};

export const oneLine = (text: string) => text.replace(/\s+/g, " ").trim();

export function parseRemoteForHost(
  url: string,
  host: string,
): string | undefined {
  const trimmed = url.trim();
  const escapedHost = host.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const scp = trimmed.match(
    new RegExp(`^(?:[^@/]+@)?${escapedHost}:(?!\\/)(.+)$`, "i"),
  );
  let path: string | undefined;
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
      parsed.hostname.toLowerCase() !== host.toLowerCase()
    ) {
      return undefined;
    }
    path = decodeURIComponent(parsed.pathname);
  }
  path = path
    .replace(/^\/+/, "")
    .replace(/\/+$/, "")
    .replace(/\.git$/i, "");
  return /^(?:[\w.-]+\/)+[\w.-]+$/.test(path) ? path : undefined;
}

export function isWholeRef(
  input: string,
  parsed: { ref: string; url?: string },
): boolean {
  const trimmed = input.trim();
  if (parsed.url) {
    return (
      trimmed.startsWith(parsed.url) &&
      /^(?:[/?#]|$)/.test(trimmed.slice(parsed.url.length))
    );
  }
  return trimmed === parsed.ref;
}

interface ParseOptions {
  wholeInput?: boolean;
}

export class ForgeRegistry {
  constructor(
    readonly forges: readonly Forge[],
    private readonly git: GitRunner = execGit,
  ) {}

  async resolveRemotes(
    cwd: string | undefined,
    signal?: AbortSignal,
  ): Promise<RemoteProject[]> {
    if (!cwd) return [];
    let stdout: string;
    try {
      stdout = await this.git(
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

    const projects: RemoteProject[] = [];
    const seen = new Set<string>();
    for (const [, url] of remotes) {
      for (const forge of this.forges) {
        const path = forge.parseRemote(url);
        if (!path) continue;
        const key = `${forge.kind}:${path.toLowerCase()}`;
        if (seen.has(key)) break;
        seen.add(key);
        projects.push({ forge, path });
        break;
      }
    }
    return projects;
  }

  private parseRef(
    text: string,
    getURL: (forge: Forge, input: string) => URLMatch | undefined,
    getShorthand: (forge: Forge, input: string) => ShorthandMatch | undefined,
    options: ParseOptions = {},
  ): ParsedForgeRef | undefined {
    const urlMatches: Array<{ forge: Forge; match: URLMatch }> = [];
    const shorthandMatches: Array<{ forge: Forge; match: ShorthandMatch }> = [];

    for (const forge of this.forges) {
      const urlMatch = getURL(forge, text);
      if (urlMatch) urlMatches.push({ forge, match: urlMatch });
      const shortMatch = getShorthand(forge, text);
      if (shortMatch) shorthandMatches.push({ forge, match: shortMatch });
    }

    urlMatches.sort((a, b) => a.match.index - b.match.index);
    shorthandMatches.sort((a, b) => a.match.index - b.match.index);

    const earliestURL = urlMatches[0];
    const earliestShort = shorthandMatches[0];

    let parsed: ParsedForgeRef | undefined;
    if (
      earliestURL &&
      (!earliestShort || earliestURL.match.index <= earliestShort.match.index)
    ) {
      parsed = {
        ref: earliestURL.match.ref,
        url: earliestURL.match.url,
        path: earliestURL.match.path,
        iid: earliestURL.match.iid,
        forges: [earliestURL.forge],
      };
    } else if (earliestShort) {
      // Prefer an explicit URL when a markdown link like `[!123](url)` or `[#42](url)` names the same IID.
      if (
        !earliestShort.match.path &&
        earliestURL &&
        earliestURL.match.iid === earliestShort.match.iid
      ) {
        parsed = {
          ref: earliestURL.match.ref,
          url: earliestURL.match.url,
          path: earliestURL.match.path,
          iid: earliestURL.match.iid,
          forges: [earliestURL.forge],
        };
      } else {
        const matchingForges = shorthandMatches
          .filter(
            (entry) =>
              entry.match.index === earliestShort.match.index &&
              entry.match.ref === earliestShort.match.ref,
          )
          .map((entry) => entry.forge);
        parsed = {
          ref: earliestShort.match.ref,
          path: earliestShort.match.path,
          iid: earliestShort.match.iid,
          forges: matchingForges,
        };
      }
    }

    if (!parsed) return undefined;
    if (options.wholeInput && !isWholeRef(text, parsed)) return undefined;
    return parsed;
  }

  parseReview(
    text: string,
    options?: ParseOptions,
  ): ParsedForgeRef | undefined {
    return this.parseRef(
      text,
      (forge, input) => forge.parseReviewURL(input),
      (forge, input) => forge.parseReviewShorthand(input),
      options,
    );
  }

  parseIssue(text: string, options?: ParseOptions): ParsedForgeRef | undefined {
    return this.parseRef(
      text,
      (forge, input) => forge.parseIssueURL(input),
      (forge, input) => forge.parseIssueShorthand(input),
      options,
    );
  }

  private async candidateTargets(
    parsed: ParsedForgeRef,
    cwd: string | undefined,
    signal?: AbortSignal,
  ): Promise<RemoteProject[]> {
    if (parsed.url && parsed.path && parsed.forges.length === 1) {
      return [{ forge: parsed.forges[0], path: parsed.path }];
    }
    if (parsed.path) {
      const compatible = parsed.forges.filter((forge) =>
        forge.canResolvePath(parsed.path!),
      );
      if (compatible.length <= 1) {
        return compatible.map((forge) => ({ forge, path: parsed.path! }));
      }
      const remotes = await this.resolveRemotes(cwd, signal);
      const ordered: Forge[] = [];
      for (const remote of remotes) {
        if (
          compatible.includes(remote.forge) &&
          !ordered.includes(remote.forge)
        ) {
          ordered.push(remote.forge);
        }
      }
      for (const forge of compatible) {
        if (!ordered.includes(forge)) ordered.push(forge);
      }
      return ordered.map((forge) => ({ forge, path: parsed.path! }));
    }

    const remotes = await this.resolveRemotes(cwd, signal);
    return remotes.filter((remote) => parsed.forges.includes(remote.forge));
  }

  async lookupReview(
    parsed: ParsedForgeRef,
    cwd: string | undefined,
    signal?: AbortSignal,
  ): Promise<ResolvedReview | undefined> {
    const targets = await this.candidateTargets(parsed, cwd, signal);
    for (const { forge, path } of targets) {
      if (signal?.aborted) return undefined;
      const details = await forge.lookupReview(path, parsed.iid, signal);
      if (details) {
        return {
          forge: forge.kind,
          label: forge.label,
          noun: forge.noun,
          ref: parsed.ref,
          username: details.username,
          title: details.title,
        };
      }
    }
    return undefined;
  }

  async lookupIssueTitle(
    parsed: ParsedForgeRef,
    cwd: string | undefined,
    signal?: AbortSignal,
  ): Promise<string | undefined> {
    const targets = await this.candidateTargets(parsed, cwd, signal);
    for (const { forge, path } of targets) {
      if (signal?.aborted) return undefined;
      const title = await forge.lookupIssueTitle(path, parsed.iid, signal);
      if (title) return title;
    }
    return undefined;
  }
}
