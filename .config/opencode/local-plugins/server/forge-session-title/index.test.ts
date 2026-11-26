import { describe, expect, test } from "bun:test";
import {
  createPlugin,
  ForgeRegistry,
  GitHubForge,
  GitLabForge,
  isIssueRequest,
  withForgePrefix,
} from "./index.ts";

const glIssue = "https://gitlab.com/group/nested/project/-/issues/123";
const glMR = "https://gitlab.com/group/project/-/merge_requests/71";
const ghIssue = "https://github.com/owner/repo/issues/15";
const ghPR = "https://github.com/owner/repo/pull/42";

const gitlabRemotes = [
  "remote.security.url git@gitlab.com:gitlab-org/security/gitlab.git",
  "remote.origin.url git@gitlab.com:gitlab-org/gitlab.git",
].join("\n");

const githubRemotes = [
  "remote.upstream.url https://github.com/upstream-org/repo.git",
  "remote.origin.url git@github.com:owner/repo.git",
].join("\n");

describe("GitLabForge", () => {
  const gitlab = new GitLabForge();

  test("parses SSH and HTTPS gitlab.com remotes and ignores github.com", () => {
    expect(gitlab.parseRemote("git@gitlab.com:gitlab-org/gitlab.git")).toBe(
      "gitlab-org/gitlab",
    );
    expect(
      gitlab.parseRemote("https://gitlab.com/gitlab-org/security/gitlab.git"),
    ).toBe("gitlab-org/security/gitlab");
    expect(
      gitlab.parseRemote("ssh://git@gitlab.com/group/nested/project/"),
    ).toBe("group/nested/project");
    expect(
      gitlab.parseRemote("git@github.com:pedropombeiro/dotfiles.git"),
    ).toBeUndefined();
    expect(
      gitlab.parseRemote("https://gitlab.example.com/group/project.git"),
    ).toBeUndefined();
  });

  test("parses MR URLs and shorthands", () => {
    expect(gitlab.parseReviewURL(`Review ${glMR}#note_1`)).toMatchObject({
      ref: glMR,
      url: glMR,
      path: "group/project",
      iid: "71",
    });
    expect(
      gitlab.parseReviewShorthand("Review gitlab-org/gitlab!274266"),
    ).toMatchObject({
      ref: "gitlab-org/gitlab!274266",
      path: "gitlab-org/gitlab",
      iid: "274266",
    });
    expect(gitlab.parseReviewShorthand("Review !274266")).toMatchObject({
      ref: "!274266",
      iid: "274266",
    });
    expect(gitlab.parseReviewShorthand("Review !0")).toBeUndefined();
    expect(gitlab.parseReviewShorthand("Review foo!71")).toBeUndefined();
  });

  test("parses project issues, work items, and group epics", () => {
    expect(gitlab.parseIssueURL(`Address ${glIssue}#note_1`)).toMatchObject({
      url: glIssue,
      path: "group/nested/project",
      iid: "123",
    });
    for (const kind of ["work_items", "epics"]) {
      expect(
        gitlab.parseIssueURL(
          `https://gitlab.com/groups/gitlab-org/-/${kind}/5`,
        ),
      ).toMatchObject({ path: "gitlab-org", iid: "5" });
    }
    expect(
      gitlab.parseIssueURL(glIssue.replace("gitlab.com", "gitlab.example.com")),
    ).toBeUndefined();
  });
});

describe("GitHubForge", () => {
  const github = new GitHubForge();

  test("parses SSH and HTTPS github.com remotes and rejects nested paths", () => {
    expect(github.parseRemote("git@github.com:owner/repo.git")).toBe(
      "owner/repo",
    );
    expect(github.parseRemote("https://github.com/owner/repo/")).toBe(
      "owner/repo",
    );
    expect(
      github.parseRemote("git@gitlab.com:gitlab-org/gitlab.git"),
    ).toBeUndefined();
    expect(github.canResolvePath("owner/repo")).toBe(true);
    expect(github.canResolvePath("group/nested/project")).toBe(false);
  });

  test("parses PR and issue URLs and shorthands", () => {
    expect(github.parseReviewURL(`Review ${ghPR}/files`)).toMatchObject({
      ref: ghPR,
      url: ghPR,
      path: "owner/repo",
      iid: "42",
    });
    expect(
      github.parseIssueURL(`Address ${ghIssue}#issuecomment-1`),
    ).toMatchObject({
      ref: ghIssue,
      url: ghIssue,
      path: "owner/repo",
      iid: "15",
    });
    expect(github.parseReviewShorthand("Review owner/repo#42")).toMatchObject({
      ref: "owner/repo#42",
      path: "owner/repo",
      iid: "42",
    });
    expect(github.parseReviewShorthand("Review #42")).toMatchObject({
      ref: "#42",
      iid: "42",
    });
    expect(
      github.parseReviewShorthand("Review group/nested/project#42"),
    ).toBeUndefined();
    expect(
      github.parseIssueShorthand("Address https://example.com/page#123"),
    ).toBeUndefined();
    expect(
      github.parseIssueShorthand("Address https://example.com/#123"),
    ).toBeUndefined();
  });
});

describe("ForgeRegistry parsing", () => {
  const registry = new ForgeRegistry([new GitLabForge(), new GitHubForge()]);

  test("prefers explicit URL over markdown link text for the same IID", () => {
    expect(
      registry.parseReview(
        "Review [!71](https://gitlab.com/other/repo/-/merge_requests/71)",
      ),
    ).toMatchObject({
      url: "https://gitlab.com/other/repo/-/merge_requests/71",
      path: "other/repo",
      iid: "71",
    });
    expect(
      registry.parseReview(
        "Review [#42](https://github.com/other/repo/pull/42)",
      ),
    ).toMatchObject({
      url: "https://github.com/other/repo/pull/42",
      path: "other/repo",
      iid: "42",
    });
    expect(
      registry.parseIssue(
        "Address [#15](https://github.com/other/repo/issues/15)",
      ),
    ).toMatchObject({
      url: "https://github.com/other/repo/issues/15",
      path: "other/repo",
      iid: "15",
    });
  });

  test("matches both forges for 2-segment issue shorthands and only GitLab for nested ones", () => {
    const twoSeg = registry.parseIssue("Address owner/repo#15");
    expect(twoSeg?.forges.map((f) => f.kind)).toEqual(["gitlab", "github"]);

    const nested = registry.parseIssue("Address group/nested/project#123");
    expect(nested?.forges.map((f) => f.kind)).toEqual(["gitlab"]);
  });
});

describe("isIssueRequest", () => {
  test.each([
    `Address ${glIssue}`,
    `Address ${ghIssue}`,
    "Address #123",
    "Let's address #28",
    `Please fix ${glIssue}`,
    `Can you implement ${ghIssue}`,
    `Work on ${glIssue}`,
    `Let’s fix ${glIssue}`,
    `Go ahead and implement ${glIssue}`,
    `I'd like you to resolve ${glIssue}`,
    `Create a draft MR for ${glIssue}`,
    `Open a draft PR for ${ghIssue}`,
    `Open an MR to resolve ${glIssue}`,
    `Create a pull request to fix ${ghIssue}`,
  ])("accepts %p", (text) => expect(isIssueRequest(text)).toBe(true));

  test.each([
    `Summarize ${glIssue}`,
    `Summarize ${ghIssue}`,
    "Summarize #123",
    `What does ${glIssue} ask for?`,
    `Review ${glMR}`,
    `Review ${ghPR}`,
    "Review !274266",
    "Review #42",
    `This fixes ${glIssue}`,
    `Let's summarize ${ghIssue}`,
  ])("rejects %p", (text) => expect(isIssueRequest(text)).toBe(false));
});

describe("withForgePrefix", () => {
  test("keeps Forgekeeper references and drops the old title", () => {
    expect(withForgePrefix("[#123, !456] Old title", "New title")).toBe(
      "[#123, !456] New title",
    );
  });

  test("ignores brackets without references", () => {
    expect(withForgePrefix("[Feature flag] Old title", "New title")).toBe(
      "New title",
    );
    expect(withForgePrefix(undefined, "New title")).toBe("New title");
  });

  test("limits titles to 100 characters", () => {
    expect(withForgePrefix("[#1] Old", "x".repeat(200))).toHaveLength(100);
  });
});

function setup(
  options: {
    glab?: Record<string, unknown>;
    gh?: Record<string, unknown>;
    sessionTitle?: string;
    directory?: string;
    remotes?: string;
  } = {},
) {
  const {
    glab: glabResponses = {},
    gh: ghResponses = {},
    sessionTitle = "Old title",
    directory = "/repo",
    remotes = gitlabRemotes,
  } = options;
  const glabCalls: string[][] = [];
  const ghCalls: string[][] = [];
  const gitCalls: Array<{ args: string[]; cwd: string }> = [];
  const updates: { sessionID: string; title: string }[] = [];
  const tools: Record<string, any> = {};
  let hook: (event: any) => Promise<void> = async () => {};

  const glab = async (args: string[]) => {
    glabCalls.push(args);
    const key =
      args[0] === "graphql"
        ? `${args.find((arg) => arg.startsWith("fullPath="))}#${args.find((arg) => arg.startsWith("iid="))}`
        : args[0];
    if (!(key in glabResponses)) throw new Error(`no glab response for ${key}`);
    return JSON.stringify(glabResponses[key]);
  };
  const gh = async (args: string[]) => {
    ghCalls.push(args);
    const key = args[0];
    if (!(key in ghResponses)) throw new Error(`no gh response for ${key}`);
    return JSON.stringify(ghResponses[key]);
  };
  const git = async (args: string[], cwd: string) => {
    gitCalls.push({ args, cwd });
    if (!remotes) throw new Error("not a git repo");
    return remotes;
  };
  const ctx = {
    location: { directory },
    tool: {
      transform: (fn: any) =>
        fn({ add: (tool: any) => (tools[tool.name] = tool) }),
    },
    session: {
      hook: (_kind: string, fn: typeof hook) => (hook = fn),
      get: async () => ({ title: sessionTitle, location: { directory } }),
      update: async (input: any) => void updates.push(input),
    },
  };
  return {
    glabCalls,
    ghCalls,
    gitCalls,
    updates,
    tools,
    ready: createPlugin({ glab, gh, git }).setup(ctx as any),
    title: async (content: unknown, result?: string) => {
      const event = {
        sessionID: "ses_test",
        messages: [{ role: "user", content }],
        system: [] as any[],
        result,
      };
      await hook(event);
      return event;
    },
  };
}

const workItem = (title: string) => ({
  data: { namespace: { workItem: { title } } },
});
const context = { sessionID: "ses_test", signal: new AbortController().signal };

describe("title hook (GitLab)", () => {
  test("names implementation sessions after GitLab issues and work items", async () => {
    const plugin = setup({
      glab: {
        "fullPath=group/nested/project#iid=123": workItem(
          "Fix  factory\ndefaults",
        ),
        "fullPath=gitlab-org/gitlab#iid=28": workItem(
          "Detect squash-merged branches",
        ),
        "fullPath=gitlab-org#iid=5": workItem("Group epic"),
      },
    });
    await plugin.ready;

    expect(
      (await plugin.title([{ type: "text", text: `Address ${glIssue}` }]))
        .result,
    ).toBe("Fix factory defaults");
    expect(plugin.gitCalls).toHaveLength(0);

    expect((await plugin.title("Let's address #28")).result).toBe(
      "Detect squash-merged branches",
    );
    expect(plugin.gitCalls).toHaveLength(1);

    expect(
      (
        await plugin.title(
          "Work on https://gitlab.com/groups/gitlab-org/-/work_items/5",
        )
      ).result,
    ).toBe("Group epic");
  });

  test("resolves GitLab MR URLs and shorthands preferring origin", async () => {
    const plugin = setup({
      glab: {
        "projects/group%2Fproject/merge_requests/71": {
          author: { username: "jdoe" },
          title: "Update factory defaults",
        },
        "projects/gitlab-org%2Fgitlab/merge_requests/274266": {
          author: { username: "dlrussel" },
          title: "Rename destroy_pipeline to delete_pipeline",
        },
        "projects/gitlab-org%2Fsecurity%2Fgitlab/merge_requests/99": {
          author: { username: "secdev" },
          title: "Security patch",
        },
      },
    });
    await plugin.ready;

    const full = await plugin.title(`Review ${glMR}`);
    expect(full.system[0].text).toContain(
      `The GitLab merge request ${glMR} ("Update factory defaults") is by @jdoe.`,
    );

    const bare = await plugin.title("Review !274266");
    expect(bare.system[0].text).toContain(
      'The GitLab merge request !274266 ("Rename destroy_pipeline to delete_pipeline") is by @dlrussel.',
    );

    const fallbackRemote = await plugin.title("Review !99");
    expect(fallbackRemote.system[0].text).toContain(
      'The GitLab merge request !99 ("Security patch") is by @secdev.',
    );

    const cross = await plugin.title("Review gitlab-org/gitlab!274266");
    expect(cross.system[0].text).toContain(
      'The GitLab merge request gitlab-org/gitlab!274266 ("Rename destroy_pipeline to delete_pipeline") is by @dlrussel.',
    );
  });

  test("does not query GitHub when reviewing #123 in a GitLab-only checkout", async () => {
    const plugin = setup({ remotes: gitlabRemotes });
    await plugin.ready;
    const event = await plugin.title("What does #642511 ask for?");
    expect(event.system).toHaveLength(0);
    expect(plugin.ghCalls).toHaveLength(0);
    expect(plugin.glabCalls).toHaveLength(0);
  });
});

describe("title hook (GitHub)", () => {
  test("names implementation sessions after GitHub issues and skips PRs returned by issues API", async () => {
    const plugin = setup({
      remotes: githubRemotes,
      gh: {
        "repos/owner/repo/issues/15": { title: "Support dark mode" },
        "repos/owner/repo/issues/42": {
          title: "Not an issue",
          pull_request: { url: ghPR },
        },
      },
    });
    await plugin.ready;

    expect((await plugin.title(`Address ${ghIssue}`)).result).toBe(
      "Support dark mode",
    );
    expect(plugin.gitCalls).toHaveLength(0);

    expect((await plugin.title("Let's fix #15")).result).toBe(
      "Support dark mode",
    );
    expect((await plugin.title("Address #42")).result).toBeUndefined();
  });

  test("adds the PR author and title for GitHub PR URLs and shorthands", async () => {
    const plugin = setup({
      remotes: githubRemotes,
      gh: {
        "repos/owner/repo/pulls/42": {
          user: { login: "octocat" },
          title: "Add session title support",
        },
        "repos/upstream-org/repo/pulls/7": {
          user: { login: "renovate[bot]" },
          title: "Update dependency",
        },
      },
    });
    await plugin.ready;

    const full = await plugin.title(`Review ${ghPR}`);
    expect(full.result).toBeUndefined();
    expect(full.system[0].text).toContain(
      `The GitHub pull request ${ghPR} ("Add session title support") is by @octocat.`,
    );
    expect(plugin.gitCalls).toHaveLength(0);

    const bare = await plugin.title("Review #42");
    expect(bare.system[0].text).toContain(
      'The GitHub pull request #42 ("Add session title support") is by @octocat.',
    );

    const upstreamFallback = await plugin.title("Review #7");
    expect(upstreamFallback.system[0].text).toContain(
      'The GitHub pull request #7 ("Update dependency") is by @renovate[bot].',
    );

    const cross = await plugin.title("Review owner/repo#42");
    expect(cross.system[0].text).toContain(
      'The GitHub pull request owner/repo#42 ("Add session title support") is by @octocat.',
    );
  });

  test("resolves cross-repo owner/repo#123 by trying checkout forge first, then falling back", async () => {
    const plugin = setup({
      remotes: githubRemotes,
      glab: {
        "fullPath=gitlab-org/gitlab#iid=642511": workItem(
          "Rename pipeline mutation",
        ),
      },
    });
    await plugin.ready;

    const event = await plugin.title("Address gitlab-org/gitlab#642511");
    expect(event.result).toBe("Rename pipeline mutation");
    expect(plugin.ghCalls).toEqual([["repos/gitlab-org/gitlab/issues/642511"]]);
    expect(plugin.glabCalls).toHaveLength(1);
  });

  test("leaves read-only requests, earlier results, and failed lookups alone", async () => {
    const plugin = setup({ remotes: githubRemotes });
    await plugin.ready;
    expect((await plugin.title(`Summarize ${ghIssue}`)).result).toBeUndefined();
    expect((await plugin.title(`Address ${ghIssue}`, "Earlier")).result).toBe(
      "Earlier",
    );
    expect(plugin.ghCalls).toHaveLength(0);
    expect((await plugin.title("Review !274266")).system).toHaveLength(0);
    expect(plugin.glabCalls).toHaveLength(0);
  });
});

describe("rename tools", () => {
  test("renames sessions after GitLab and GitHub issues while keeping Forgekeeper prefix", async () => {
    const plugin = setup({
      remotes: githubRemotes,
      sessionTitle: "[#15] Old title",
      glab: {
        "fullPath=group/nested/project#iid=123": workItem(
          "Fix factory defaults",
        ),
      },
      gh: {
        "repos/owner/repo/issues/15": { title: "Support dark mode" },
      },
    });
    await plugin.ready;

    const glOut = await plugin.tools.rename_issue_session.execute(
      { url: glIssue },
      context,
    );
    expect(glOut.content).toBe("Session title: [#15] Fix factory defaults");

    const ghOut = await plugin.tools.rename_issue_session.execute(
      { url: "#15" },
      context,
    );
    expect(ghOut.content).toBe("Session title: [#15] Support dark mode");
  });

  test("renames review sessions for GitLab MRs and GitHub PRs", async () => {
    const plugin = setup({
      remotes: githubRemotes,
      sessionTitle: "[#42] Old title",
      glab: {
        "projects/group%2Fproject/merge_requests/71": {
          author: { username: "jdoe" },
          title: "Fallback MR title",
        },
      },
      gh: {
        "repos/owner/repo/pulls/42": {
          user: { login: "octocat" },
          title: "Add session title support",
        },
      },
    });
    await plugin.ready;

    await plugin.tools.rename_mr_review_session.execute(
      { url: glMR, topic: "factory defaults !71" },
      context,
    );
    expect(plugin.updates[0]).toEqual({
      sessionID: "ses_test",
      title: "[#42] @jdoe - Review factory defaults",
    });

    await plugin.tools.rename_mr_review_session.execute(
      { url: "#42" },
      context,
    );
    expect(plugin.updates[1]).toEqual({
      sessionID: "ses_test",
      title: "[#42] @octocat - Review Add session title support",
    });

    await plugin.tools.rename_mr_review_session.execute(
      { url: ghPR, topic: "pull request" },
      context,
    );
    expect(plugin.updates[2]).toEqual({
      sessionID: "ses_test",
      title: "[#42] @octocat - Review Add session title support",
    });
  });

  test("rejects references embedded in other text", async () => {
    const plugin = setup({});
    await plugin.ready;
    for (const bad of [`see ${glIssue}`, `see ${ghIssue}`, "see #123"]) {
      const output = await plugin.tools.rename_issue_session.execute(
        { url: bad },
        context,
      );
      expect(output.content).toStartWith("No title changed.");
    }
    for (const bad of [
      `see ${glMR}`,
      `see ${ghPR}`,
      "see !274266",
      "see #42",
    ]) {
      const output = await plugin.tools.rename_mr_review_session.execute(
        { url: bad },
        context,
      );
      expect(output.content).toStartWith("No title changed.");
    }
    expect(plugin.updates).toHaveLength(0);
  });
});
