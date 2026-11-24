import { afterEach, describe, expect, test } from "bun:test";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  executeVent,
  formatVentResult,
  parseVentInput,
  resolveOptions,
  selectDestination,
} from "./index.ts";
import { parseMarkdownSections, ventToFile } from "./src/destinations/file.ts";
import { ventToGitHub } from "./src/destinations/github.ts";
import { parseGitLabEpicRef, ventToGitLab } from "./src/destinations/gitlab.ts";
import type { VentInput, VentMetadata } from "./src/destinations/types.ts";
import type { Exec, ExecOptions, ExecResult } from "./src/exec.ts";
import { formatCommentBody, formatIssueBody } from "./src/format.ts";
import {
  buildMatchQuery,
  extractIdentifiers,
  findBestMatch,
  similarityScore,
} from "./src/match.ts";

const tempDirs: string[] = [];

afterEach(async () => {
  while (tempDirs.length > 0) {
    const dir = tempDirs.pop()!;
    await rm(dir, { recursive: true, force: true });
  }
});

async function makeTempDir(): Promise<string> {
  const dir = await mkdtemp(join(tmpdir(), "opencode-vent-test-"));
  tempDirs.push(dir);
  return dir;
}

const sampleInput: VentInput = {
  title: "Missing read-only permission for `glab api` pagination flag",
  friction:
    "Running `glab api --paginate` prompts for approval even for read-only GET queries.",
  context: "Listing open issues across a group during triage.",
  evidence:
    "Command `glab api --paginate groups/example/issues` triggered a permission prompt.",
  suggestion:
    "Allow `glab api *` with `--paginate` when no mutation flags are present.",
  category: "permissions",
  labels: ["agent-friction"],
};

const sampleMetadata: VentMetadata = {
  date: "2026-11-20",
  timestamp: "2026-11-20T12:00:00.000Z",
  directory: "/Users/dev/project",
  remote: "git@gitlab.com:example/project.git",
  branch: "feature/test",
  sessionID: "ses_12345",
  category: "permissions",
};

describe("options and routing", () => {
  test("parses valid destinations, defaults, and routes", () => {
    const options = resolveOptions({
      defaultDestination: "local",
      similarityThreshold: 0.5,
      destinations: {
        local: { type: "file", path: "~/notes/vents.md" },
        gitlab: {
          type: "gitlab",
          project: "org/repo",
          epic: "https://gitlab.com/groups/org/-/epics/42",
          labels: ["friction"],
        },
        github: {
          type: "github",
          repo: "owner/repo",
          labels: ["tooling"],
        },
        invalid: { type: "gitlab" },
      },
      routes: [
        { directoryPrefix: "~/work", destination: "gitlab" },
        { remoteContains: "github.com/owner/", destination: "github" },
      ],
    });

    expect(options.defaultDestination).toBe("local");
    expect(options.similarityThreshold).toBe(0.5);
    expect(Object.keys(options.destinations)).toEqual([
      "local",
      "gitlab",
      "github",
    ]);
    expect(options.destinations.gitlab).toEqual({
      type: "gitlab",
      project: "org/repo",
      epic: "https://gitlab.com/groups/org/-/epics/42",
      host: "gitlab.com",
      confidential: true,
      labels: ["friction"],
    });

    expect(
      selectDestination(options, {
        requested: "github",
        directory: "/Users/dev/work/app",
        home: "/Users/dev",
      }).name,
    ).toBe("github");

    expect(
      selectDestination(options, {
        directory: "/Users/dev/work/app",
        home: "/Users/dev",
      }).name,
    ).toBe("gitlab");

    expect(
      selectDestination(options, {
        directory: "/Users/dev/other",
        remote: "git@github.com:owner/repo.git",
        home: "/Users/dev",
      }).name,
    ).toBe("github");

    expect(
      selectDestination(options, {
        directory: "/Users/dev/other",
        home: "/Users/dev",
      }).name,
    ).toBe("local");
  });

  test("selects the sole destination when no defaultDestination is configured", () => {
    const options = resolveOptions({
      destinations: {
        only: { type: "file", path: "~/vents.md" },
      },
    });
    expect(selectDestination(options, {}).name).toBe("only");
  });

  test("enforces project routes with a deliberate exception for unrelated file entries", () => {
    const options = resolveOptions({
      defaultDestination: "local",
      destinations: {
        local: { type: "file", path: "~/vents.md" },
        gitlab: { type: "gitlab", project: "dev/friction" },
        github: { type: "github", repo: "dev/friction" },
      },
      routes: [
        { directoryPrefix: "~/gdk", destination: "gitlab", enforced: true },
        {
          remoteRepository: "gitlab.com/gitlab-org/gitlab",
          destination: "gitlab",
          enforced: true,
        },
      ],
    });
    const locations = [
      { directory: "/home/dev/gdk/gitlab/app", home: "/home/dev" },
      {
        directory: "/worktrees/feature",
        remote: "git@gitlab.com:gitlab-org/gitlab.git",
      },
      {
        directory: "/recovery/clone",
        fetchRemotes: [
          "https://gitlab.com/dev/fork.git",
          "ssh://git@gitlab.com:22/gitlab-org/gitlab.git",
        ],
      },
    ];
    for (const location of locations) {
      expect(selectDestination(options, location).name).toBe("gitlab");
      expect(
        selectDestination(options, { ...location, requested: "gitlab" }).name,
      ).toBe("gitlab");
      expect(() =>
        selectDestination(options, { ...location, requested: "local" }),
      ).toThrow("localReason");
      expect(() =>
        selectDestination(options, {
          ...location,
          requested: "local",
          localReason: " ",
        }),
      ).toThrow("localReason");
      expect(() =>
        selectDestination(options, { ...location, requested: "github" }),
      ).toThrow("This checkout routes");
      expect(
        selectDestination(options, {
          ...location,
          requested: "local",
          localReason: "SSH signing fails in personal repositories too.",
        }).name,
      ).toBe("local");
    }
    expect(
      selectDestination(options, {
        directory: "/home/dev/gdk-backup",
        home: "/home/dev",
        remote: "https://gitlab.com/gitlab-org/gitlab-other.git",
      }).name,
    ).toBe("local");
  });

  test("throws on missing or unknown destination", () => {
    expect(() => selectDestination(resolveOptions({}), {})).toThrow(
      "No vent destinations",
    );
    const options = resolveOptions({
      destinations: {
        local: { type: "file", path: "~/vents.md" },
      },
    });
    expect(() => selectDestination(options, { requested: "missing" })).toThrow(
      "Unknown vent destination",
    );
  });
});

describe("similarity matching", () => {
  test("matches recurring friction with paraphrased title and shared identifier", () => {
    const candidates = [
      {
        id: "1",
        title: "Permission prompt on `glab api` with pagination flag",
        body: "Calling `glab api --paginate` asks for approval on GET requests.",
      },
      {
        id: "2",
        title: "Slow test suite startup on macOS",
        body: "Running integration specs takes two minutes to boot Docker.",
      },
    ];

    const match = findBestMatch(
      { title: sampleInput.title, body: sampleInput.friction },
      candidates,
      0.45,
    );
    expect(match?.item.id).toBe("1");
    expect(match!.score).toBeGreaterThanOrEqual(0.45);
  });

  test("does not match unrelated frictions", () => {
    const score = similarityScore(
      {
        title: "Broken symlink after running dotfiles bootstrap",
        body: "Bootstrap script leaves a dangling link in ~/.local/bin.",
      },
      {
        title: "ClickHouse query timeout on CI pipeline metrics",
        body: "Querying build duration over 90 days times out after 30 seconds.",
      },
    );
    expect(score).toBeLessThan(0.2);
  });

  test("ignores backticked session metadata inside <details> blocks", () => {
    const metadataBlock = formatIssueBody(
      {
        title: "ClickHouse query timeout",
        friction: "Querying build duration times out.",
        context: "Checking dashboard latency.",
      },
      sampleMetadata,
    );
    expect(extractIdentifiers(metadataBlock).size).toBe(0);

    const score = similarityScore(
      {
        title: "Broken symlink after bootstrap",
        body: formatIssueBody(
          {
            title: "Broken symlink after bootstrap",
            friction: "Bootstrap script leaves a dangling link.",
            context: "Running dotfiles setup.",
          },
          sampleMetadata,
        ),
      },
      {
        title: "ClickHouse query timeout",
        body: metadataBlock,
      },
    );
    expect(score).toBeLessThan(0.1);
  });

  test("includes evidence identifiers when building a match query", () => {
    const query = buildMatchQuery({
      title: "Linter fails to start from shell",
      friction: "Running the markdown linter fails with a shim version error.",
      evidence:
        "Invoking `markdownlint-cli2` prints `No version is set for shim`.",
    });
    const ids = extractIdentifiers(`${query.title}\n${query.body}`);
    expect(ids.has("markdownlint-cli2")).toBe(true);
    expect(ids.has("no version is set for shim")).toBe(true);
  });
});

describe("formatting", () => {
  test("formats structured issue body and comment body with session metadata", () => {
    const issueBody = formatIssueBody(sampleInput, sampleMetadata);
    expect(issueBody).toContain("## Friction");
    expect(issueBody).toContain("## Context");
    expect(issueBody).toContain("## Evidence / Reproduction");
    expect(issueBody).toContain("## Suggested Improvement");
    expect(issueBody).toContain("<details>");
    expect(issueBody).toContain("- **Branch**: `feature/test`");
    expect(issueBody).toContain("- **Session**: `ses_12345`");

    const commentBody = formatCommentBody(sampleInput, sampleMetadata);
    expect(commentBody).toContain(
      "Additional occurrence reported on 2026-11-20.",
    );
    expect(commentBody).toContain("### Context");
  });
});

describe("GitLab destination", () => {
  test("parses epic URLs, work item URLs, and shorthand refs", () => {
    expect(
      parseGitLabEpicRef(
        "https://gitlab.com/groups/gitlab-org/-/epics/123",
        "gitlab.com",
      ),
    ).toEqual({
      host: "gitlab.com",
      groupPath: "gitlab-org",
      iid: "123",
      url: "https://gitlab.com/groups/gitlab-org/-/epics/123",
    });

    expect(
      parseGitLabEpicRef(
        "https://gitlab.example.com/groups/org/sub/-/work_items/99",
        "gitlab.com",
      ),
    ).toEqual({
      host: "gitlab.example.com",
      groupPath: "org/sub",
      iid: "99",
      url: "https://gitlab.example.com/groups/org/sub/-/epics/99",
    });

    expect(parseGitLabEpicRef("gitlab-org/quality&77", "gitlab.com")).toEqual({
      host: "gitlab.com",
      groupPath: "gitlab-org/quality",
      iid: "77",
      url: "https://gitlab.com/groups/gitlab-org/quality/-/epics/77",
    });
  });

  test("comments on matching open epic issue instead of creating a duplicate", async () => {
    const calls: Array<{ file: string; args: string[]; stdin?: string }> = [];
    const mockExec: Exec = async (
      file,
      args,
      options?: ExecOptions,
    ): Promise<ExecResult> => {
      calls.push({ file, args, stdin: options?.stdin });
      if (args.includes("--method")) {
        return { stdout: JSON.stringify({ id: 555 }), stderr: "", code: 0 };
      }
      return {
        stdout: JSON.stringify([
          {
            id: 9001,
            iid: 42,
            project_id: 278964,
            title: "Permission prompt on `glab api` pagination flag",
            description:
              "Running `glab api --paginate` triggers an approval prompt.",
            state: "opened",
            web_url: "https://gitlab.com/gitlab-org/gitlab/-/issues/42",
          },
        ]),
        stderr: "",
        code: 0,
      };
    };

    const result = await ventToGitLab(
      "gitlab",
      {
        type: "gitlab",
        project: "gitlab-org/gitlab",
        epic: "https://gitlab.com/groups/gitlab-org/-/epics/100",
        host: "gitlab.com",
        confidential: true,
        labels: ["workflow"],
      },
      sampleInput,
      sampleMetadata,
      { exec: mockExec, threshold: 0.45 },
    );

    expect(result).toEqual({
      action: "commented",
      destination: "gitlab",
      destinationType: "gitlab",
      url: "https://gitlab.com/gitlab-org/gitlab/-/issues/42#note_555",
      title: sampleInput.title,
      matchedTitle: "Permission prompt on `glab api` pagination flag",
      matchScore: expect.any(Number),
    });

    expect(calls).toHaveLength(2);
    expect(calls[0]!.args).toEqual([
      "api",
      "--hostname",
      "gitlab.com",
      "groups/gitlab-org/epics/100/issues?state=opened&per_page=100",
    ]);
    expect(calls[1]!.args).toEqual([
      "api",
      "--hostname",
      "gitlab.com",
      "--method",
      "POST",
      "--input",
      "-",
      "projects/278964/issues/42/notes",
    ]);
    expect(JSON.parse(calls[1]!.stdin!).body).toContain(
      "Additional occurrence reported on 2026-11-20.",
    );
  });

  test("creates a confidential issue under the epic when no existing issue matches", async () => {
    const calls: Array<{ args: string[]; stdin?: string }> = [];
    const mockExec: Exec = async (
      _file,
      args,
      options?: ExecOptions,
    ): Promise<ExecResult> => {
      calls.push({ args, stdin: options?.stdin });
      if (!args.includes("--method")) {
        return { stdout: "[]", stderr: "", code: 0 };
      }
      if (args.at(-1)?.includes("/issues") && options?.stdin) {
        return {
          stdout: JSON.stringify({
            id: 7777,
            iid: 101,
            project_id: 278964,
            title: sampleInput.title,
            web_url: "https://gitlab.com/gitlab-org/gitlab/-/issues/101",
            epic: { id: 500, iid: 100 },
          }),
          stderr: "",
          code: 0,
        };
      }
      return { stdout: "{}", stderr: "", code: 0 };
    };

    const result = await ventToGitLab(
      "gitlab",
      {
        type: "gitlab",
        project: "gitlab-org/gitlab",
        epic: "https://gitlab.com/groups/gitlab-org/-/epics/100",
        host: "gitlab.com",
        confidential: true,
        labels: ["workflow"],
      },
      sampleInput,
      sampleMetadata,
      { exec: mockExec, threshold: 0.45 },
    );

    expect(result).toEqual({
      action: "created",
      destination: "gitlab",
      destinationType: "gitlab",
      url: "https://gitlab.com/gitlab-org/gitlab/-/issues/101",
      title: sampleInput.title,
    });

    expect(calls).toHaveLength(3);
    const payload = JSON.parse(calls[2]!.stdin!) as Record<string, unknown>;
    expect(payload.confidential).toBe(true);
    expect(payload.labels).toBe("workflow,agent-friction");
    expect(payload.description).toContain(
      "/epic https://gitlab.com/groups/gitlab-org/-/epics/100",
    );
  });

  test("falls back to REST epic link endpoint if response omits epic field", async () => {
    const endpoints: string[] = [];
    const mockExec: Exec = async (
      _file,
      args,
      options?: ExecOptions,
    ): Promise<ExecResult> => {
      const endpoint = args.at(-1)!;
      endpoints.push(endpoint);
      if (!args.includes("--method"))
        return { stdout: "[]", stderr: "", code: 0 };
      if (options?.stdin) {
        return {
          stdout: JSON.stringify({
            id: 8888,
            iid: 102,
            project_id: 278964,
            title: sampleInput.title,
            web_url: "https://gitlab.com/gitlab-org/gitlab/-/issues/102",
          }),
          stderr: "",
          code: 0,
        };
      }
      return { stdout: "{}", stderr: "", code: 0 };
    };

    const result = await ventToGitLab(
      "gitlab",
      {
        type: "gitlab",
        project: "gitlab-org/gitlab",
        epic: "https://gitlab.com/groups/gitlab-org/-/epics/100",
        host: "gitlab.com",
        confidential: true,
        labels: [],
      },
      sampleInput,
      sampleMetadata,
      { exec: mockExec, threshold: 0.45 },
    );

    expect(result.action).toBe("created");
    expect(result.note).toBeUndefined();
    expect(endpoints).toEqual([
      "groups/gitlab-org/epics/100/issues?state=opened&per_page=100",
      "groups/gitlab-org/epics/100/issues?state=closed&per_page=100",
      "projects/gitlab-org%2Fgitlab/issues",
      "groups/gitlab-org/epics/100/issues/8888",
    ]);
  });

  test("returns the exact closed match in the destination project without writing", async () => {
    const title = "glab draft update help reverses positional arguments";
    const url = "https://gitlab.com/dev/friction/-/work_items/8";
    const mockExec: Exec = async (_file, args, options) => {
      expect(args).not.toContain("--method");
      expect(options?.stdin).toBeUndefined();
      if (args.at(-1)?.includes("state=opened")) {
        return { stdout: "[]", stderr: "", code: 0 };
      }
      expect(args).toContain("--paginate");
      expect(args.at(-1)).toBe(
        "groups/org/epics/42/issues?state=closed&per_page=100",
      );
      return {
        stdout: JSON.stringify([
          {
            title,
            state: "closed",
            web_url: "https://gitlab.com/org/other/-/issues/1",
          },
          {
            title: `${title} in old versions`,
            state: "closed",
            web_url: "https://gitlab.com/dev/friction/-/issues/7",
          },
          { title, state: "closed", web_url: url },
        ]),
        stderr: "",
        code: 0,
      };
    };
    const result = await ventToGitLab(
      "gitlab",
      {
        type: "gitlab",
        project: "dev/friction",
        epic: "org&42",
        host: "gitlab.com",
        confidential: true,
        labels: [],
      },
      { ...sampleInput, title: ` ${title.toUpperCase()} ` },
      sampleMetadata,
      { exec: mockExec, threshold: 0.45 },
    );
    expect(result).toMatchObject({
      action: "skipped",
      url,
      matchedTitle: title,
    });
    expect(formatVentResult(result)).toContain(
      "No issue or comment was created.",
    );
  });

  test("filters project issues by destination labels when no epic is configured", async () => {
    const endpoints: string[] = [];
    const mockExec: Exec = async (_file, args): Promise<ExecResult> => {
      endpoints.push(args.at(-1)!);
      if (!args.includes("--method"))
        return { stdout: "[]", stderr: "", code: 0 };
      return {
        stdout: JSON.stringify({
          id: 9999,
          iid: 103,
          project_id: 278964,
          title: sampleInput.title,
          web_url: "https://gitlab.com/gitlab-org/gitlab/-/issues/103",
        }),
        stderr: "",
        code: 0,
      };
    };

    const result = await ventToGitLab(
      "gitlab",
      {
        type: "gitlab",
        project: "gitlab-org/gitlab",
        host: "gitlab.com",
        confidential: true,
        labels: ["agent-friction", "tooling"],
      },
      sampleInput,
      sampleMetadata,
      { exec: mockExec, threshold: 0.45 },
    );

    expect(result.action).toBe("created");
    expect(endpoints[0]).toBe(
      "projects/gitlab-org%2Fgitlab/issues?state=opened&per_page=100&labels=agent-friction%2Ctooling",
    );
  });
});

describe("GitHub destination", () => {
  test("ignores pull requests and comments on a matching open issue", async () => {
    const calls: Array<{ args: string[]; stdin?: string }> = [];
    const mockExec: Exec = async (
      _file,
      args,
      options?: ExecOptions,
    ): Promise<ExecResult> => {
      calls.push({ args, stdin: options?.stdin });
      if (!args.includes("--method")) {
        return {
          stdout: JSON.stringify([
            {
              number: 10,
              title: sampleInput.title,
              body: sampleInput.friction,
              html_url: "https://github.com/owner/repo/pull/10",
              pull_request: {},
            },
            {
              number: 11,
              title: "Permission prompt on `glab api` pagination flag",
              body: "Running `glab api --paginate` asks for approval.",
              html_url: "https://github.com/owner/repo/issues/11",
            },
          ]),
          stderr: "",
          code: 0,
        };
      }
      return {
        stdout: JSON.stringify({
          html_url: "https://github.com/owner/repo/issues/11#issuecomment-9",
        }),
        stderr: "",
        code: 0,
      };
    };

    const result = await ventToGitHub(
      "github",
      {
        type: "github",
        repo: "owner/repo",
        host: "github.com",
        labels: ["friction"],
      },
      sampleInput,
      sampleMetadata,
      { exec: mockExec, threshold: 0.45 },
    );

    expect(result.action).toBe("commented");
    expect(result.url).toBe(
      "https://github.com/owner/repo/issues/11#issuecomment-9",
    );
    expect(calls[1]!.args).toContain("repos/owner/repo/issues/11/comments");
  });

  test("creates a new issue when no open issue matches", async () => {
    const calls: Array<{ args: string[]; stdin?: string }> = [];
    const mockExec: Exec = async (
      _file,
      args,
      options?: ExecOptions,
    ): Promise<ExecResult> => {
      calls.push({ args, stdin: options?.stdin });
      if (!args.includes("--method"))
        return { stdout: "[]", stderr: "", code: 0 };
      return {
        stdout: JSON.stringify({
          html_url: "https://github.com/owner/repo/issues/12",
        }),
        stderr: "",
        code: 0,
      };
    };

    const result = await ventToGitHub(
      "github",
      {
        type: "github",
        repo: "owner/repo",
        host: "github.com",
        labels: ["friction"],
      },
      sampleInput,
      sampleMetadata,
      { exec: mockExec, threshold: 0.45 },
    );

    expect(result.action).toBe("created");
    expect(result.url).toBe("https://github.com/owner/repo/issues/12");
    expect(calls[0]!.args).toContain(
      "repos/owner/repo/issues?state=open&per_page=100&labels=friction",
    );
    const payload = JSON.parse(calls[1]!.stdin!) as { labels: string[] };
    expect(payload.labels).toEqual(["friction", "agent-friction"]);
  });
});

describe("file destination", () => {
  test("creates the file, appends new sections, and appends occurrences under matching sections", async () => {
    const dir = await makeTempDir();
    const targetPath = join(dir, "docs", "vents.md");

    const first = await ventToFile(
      "local",
      { type: "file", path: targetPath },
      sampleInput,
      sampleMetadata,
      { threshold: 0.45 },
    );
    expect(first.action).toBe("created");

    const secondInput: VentInput = {
      title: "Docker daemon stalls after macOS sleep",
      friction:
        "Colima socket stops responding until restarted after wake from sleep.",
      context: "Running container builds after reopening the laptop.",
    };
    const second = await ventToFile(
      "local",
      { type: "file", path: targetPath },
      secondInput,
      sampleMetadata,
      { threshold: 0.45 },
    );
    expect(second.action).toBe("created");

    const recurring = await ventToFile(
      "local",
      { type: "file", path: targetPath },
      {
        title: "Approval prompt on `glab api` pagination flag",
        friction:
          "Another `glab api --paginate` GET call prompted for approval.",
        context: "Checking merge requests across projects.",
      },
      {
        ...sampleMetadata,
        date: "2026-11-21",
        timestamp: "2026-11-21T09:00:00.000Z",
      },
      { threshold: 0.45 },
    );
    expect(recurring.action).toBe("commented");
    expect(recurring.matchedTitle).toBe(sampleInput.title);

    const content = await readFile(targetPath, "utf8");
    const sections = parseMarkdownSections(content);
    expect(sections.map((section) => section.title)).toEqual([
      sampleInput.title,
      secondInput.title,
    ]);
    expect(sections[0]!.body).toContain("### Occurrence (2026-11-21)");
    expect(sections[1]!.body).not.toContain("### Occurrence (2026-11-21)");
  });

  test("ignores ## headings inside fenced code blocks", () => {
    const markdown = [
      "# Agent Vents",
      "",
      "## Real section",
      "",
      "```markdown",
      "## Not a section",
      "```",
      "",
      "## Second section",
      "",
      "Body text",
    ].join("\n");

    expect(parseMarkdownSections(markdown).map((s) => s.title)).toEqual([
      "Real section",
      "Second section",
    ]);
  });

  test("serializes concurrent writes to the same file without losing entries", async () => {
    const dir = await makeTempDir();
    const targetPath = join(dir, "concurrent.md");

    await Promise.all([
      ventToFile(
        "local",
        { type: "file", path: targetPath },
        {
          title: "First concurrent friction",
          friction: "The first tool failed during setup.",
          context: "Testing concurrent write safety.",
        },
        sampleMetadata,
        { threshold: 0.45 },
      ),
      ventToFile(
        "local",
        { type: "file", path: targetPath },
        {
          title: "Second unrelated timeout issue",
          friction: "Database query timed out on large table scan.",
          context: "Running analytics benchmarks.",
        },
        sampleMetadata,
        { threshold: 0.45 },
      ),
    ]);

    const content = await readFile(targetPath, "utf8");
    const sections = parseMarkdownSections(content);
    expect(sections.map((section) => section.title)).toEqual([
      "First concurrent friction",
      "Second unrelated timeout issue",
    ]);
  });
});

describe("executeVent and input parsing", () => {
  test("validates input and executes through selected destination", async () => {
    expect(() =>
      parseVentInput({ title: "x", friction: "missing context" }),
    ).toThrow("`context`");

    const dir = await makeTempDir();
    const targetPath = join(dir, "vents.md");
    const options = resolveOptions({
      defaultDestination: "local",
      destinations: { local: { type: "file", path: targetPath } },
    });

    const mockExec: Exec = async (_file, args): Promise<ExecResult> => {
      if (args.includes("remote")) {
        return {
          stdout: "origin\tgit@github.com:example/repo.git (fetch)\n",
          stderr: "",
          code: 0,
        };
      }
      return { stdout: "main\n", stderr: "", code: 0 };
    };

    const result = await executeVent(sampleInput, options, {
      sessionID: "ses_999",
      directory: dir,
      exec: mockExec,
      now: () => new Date("2026-11-20T15:30:00.000Z"),
    });

    expect(result.action).toBe("created");
    expect(formatVentResult(result)).toContain("Created new file vent");

    const saved = await readFile(targetPath, "utf8");
    expect(saved).toContain(
      "- **Repository**: `git@github.com:example/repo.git`",
    );
    expect(saved).toContain("- **Branch**: `main`");
  });

  test("routes a fork with a matching fetch remote and leaves the log untouched on GitLab failure", async () => {
    const dir = await makeTempDir();
    const targetPath = join(dir, "vents.md");
    const options = resolveOptions({
      defaultDestination: "local",
      destinations: {
        local: { type: "file", path: targetPath },
        gitlab: { type: "gitlab", project: "dev/friction", epic: "org&42" },
      },
      routes: [
        {
          remoteRepository: "gitlab.com/org/project",
          destination: "gitlab",
          enforced: true,
        },
      ],
    });
    const mockExec: Exec = async (file, args) => {
      if (file === "glab")
        return { code: 1, stdout: "", stderr: "authorization failed" };
      return {
        code: 0,
        stdout: args.includes("remote")
          ? "origin\thttps://gitlab.com/dev/fork.git (fetch)\nupstream\thttps://gitlab.com/org/project.git (fetch)\n"
          : "main\n",
        stderr: "",
      };
    };
    const runtime = { sessionID: "ses_999", directory: dir, exec: mockExec };
    await expect(
      executeVent({ ...sampleInput, destination: "local" }, options, runtime),
    ).rejects.toThrow("localReason");
    await expect(executeVent(sampleInput, options, runtime)).rejects.toThrow(
      "authorization failed",
    );
    expect(await Bun.file(targetPath).exists()).toBe(false);
    const personal = await executeVent(
      {
        ...sampleInput,
        destination: "local",
        localReason: "An unrelated user-wide tool failed.",
      },
      options,
      runtime,
    );
    expect(personal.destinationType).toBe("file");
    expect(await Bun.file(targetPath).exists()).toBe(true);
  });
});
