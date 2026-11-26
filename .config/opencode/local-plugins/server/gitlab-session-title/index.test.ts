import { describe, expect, test } from "bun:test";
import {
  createPlugin,
  isIssueRequest,
  parseGitLabRemote,
  parseMRRef,
  parseWorkItemRef,
  parseWorkItemURL,
  withForgePrefix,
} from "./index.ts";

const issue = "https://gitlab.com/group/nested/project/-/issues/123";
const mr = "https://gitlab.com/group/project/-/merge_requests/71";

describe("parseGitLabRemote", () => {
  test("parses SSH and HTTPS gitlab.com remotes", () => {
    expect(parseGitLabRemote("git@gitlab.com:gitlab-org/gitlab.git")).toBe(
      "gitlab-org/gitlab",
    );
    expect(
      parseGitLabRemote("https://gitlab.com/gitlab-org/security/gitlab.git"),
    ).toBe("gitlab-org/security/gitlab");
    expect(
      parseGitLabRemote("ssh://git@gitlab.com/group/nested/project/"),
    ).toBe("group/nested/project");
  });

  test("ignores non-gitlab.com remotes", () => {
    expect(
      parseGitLabRemote("git@github.com:pedropombeiro/dotfiles.git"),
    ).toBeUndefined();
    expect(
      parseGitLabRemote("https://gitlab.example.com/group/project.git"),
    ).toBeUndefined();
  });
});

describe("parseMRRef", () => {
  test("parses full URLs, cross-project shorthands, and bare shorthands", () => {
    expect(parseMRRef(`Review ${mr}#note_1`)).toEqual({
      ref: mr,
      url: mr,
      project: "group/project",
      iid: "71",
    });
    expect(parseMRRef("Review gitlab-org/gitlab!274266")).toEqual({
      ref: "gitlab-org/gitlab!274266",
      project: "gitlab-org/gitlab",
      iid: "274266",
    });
    expect(parseMRRef("Review !274266")).toEqual({
      ref: "!274266",
      iid: "274266",
    });
  });

  test("prefers explicit URL over markdown link text for the same IID", () => {
    expect(
      parseMRRef(
        "Review [!71](https://gitlab.com/other/repo/-/merge_requests/71)",
      ),
    ).toEqual({
      ref: "https://gitlab.com/other/repo/-/merge_requests/71",
      url: "https://gitlab.com/other/repo/-/merge_requests/71",
      project: "other/repo",
      iid: "71",
    });
  });

  test("ignores invalid references and other hosts", () => {
    expect(parseMRRef("Review !0")).toBeUndefined();
    expect(parseMRRef("Review foo!71")).toBeUndefined();
    expect(
      parseMRRef(mr.replace("gitlab.com", "gitlab.example.com")),
    ).toBeUndefined();
  });
});

describe("parseWorkItemURL", () => {
  test("parses project issues and work items in nested groups", () => {
    expect(parseWorkItemURL(`Address ${issue}#note_1`)).toEqual({
      url: issue,
      fullPath: "group/nested/project",
      iid: "123",
    });
    expect(
      parseWorkItemURL("https://gitlab.com/group/project/-/work_items/9"),
    ).toMatchObject({ fullPath: "group/project", iid: "9" });
  });

  test("uses the group path for group work items and epics", () => {
    for (const kind of ["work_items", "epics"]) {
      expect(
        parseWorkItemURL(`https://gitlab.com/groups/gitlab-org/-/${kind}/5`),
      ).toMatchObject({ fullPath: "gitlab-org", iid: "5" });
    }
  });

  test("ignores MRs, short references, and other hosts", () => {
    expect(parseWorkItemURL(mr)).toBeUndefined();
    expect(parseWorkItemURL("Address #123")).toBeUndefined();
    expect(
      parseWorkItemURL(issue.replace("gitlab.com", "gitlab.example.com")),
    ).toBeUndefined();
  });
});

describe("parseWorkItemRef", () => {
  test("parses full URLs, cross-project shorthands, and bare shorthands", () => {
    expect(parseWorkItemRef(`Address ${issue}#note_1`)).toEqual({
      ref: issue,
      url: issue,
      fullPath: "group/nested/project",
      iid: "123",
    });
    expect(parseWorkItemRef("Address gitlab-org/gitlab#642511")).toEqual({
      ref: "gitlab-org/gitlab#642511",
      fullPath: "gitlab-org/gitlab",
      iid: "642511",
    });
    expect(parseWorkItemRef("Let's address #28")).toEqual({
      ref: "#28",
      iid: "28",
    });
  });

  test("prefers explicit URL over markdown link text for the same IID", () => {
    expect(
      parseWorkItemRef(
        "Address [#123](https://gitlab.com/other/repo/-/issues/123)",
      ),
    ).toEqual({
      ref: "https://gitlab.com/other/repo/-/issues/123",
      url: "https://gitlab.com/other/repo/-/issues/123",
      fullPath: "other/repo",
      iid: "123",
    });
  });

  test("rejects URL fragments and other hosts", () => {
    expect(
      parseWorkItemRef("Address https://example.com/page#note_1"),
    ).toBeUndefined();
    expect(
      parseWorkItemRef("Address https://example.com/page#123"),
    ).toBeUndefined();
    expect(
      parseWorkItemRef("Address https://example.com/#123"),
    ).toBeUndefined();
    expect(
      parseWorkItemRef(issue.replace("gitlab.com", "gitlab.example.com")),
    ).toBeUndefined();
    expect(parseWorkItemRef(mr)).toBeUndefined();
  });
});

describe("isIssueRequest", () => {
  test.each([
    `Address ${issue}`,
    "Address #123",
    "Let's address #28",
    `Please fix ${issue}`,
    `Can you implement ${issue}`,
    `Work on ${issue}`,
    `Let's address ${issue}`,
    `Let’s fix ${issue}`,
    `Go ahead and implement ${issue}`,
    `I'd like you to resolve ${issue}`,
    `Create a draft MR for ${issue}`,
    `Open an MR to resolve ${issue}`,
  ])("accepts %p", (text) => expect(isIssueRequest(text)).toBe(true));

  test.each([
    `Summarize ${issue}`,
    "Summarize #123",
    `What does ${issue} ask for?`,
    `Review ${mr}`,
    "Review !274266",
    `This fixes ${issue}`,
    `Let's summarize ${issue}`,
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
  responses: Record<string, unknown>,
  options: {
    sessionTitle?: string;
    directory?: string;
    remotes?: string;
  } = {},
) {
  const {
    sessionTitle = "Old title",
    directory = "/repo",
    remotes = [
      "remote.security.url git@gitlab.com:gitlab-org/security/gitlab.git",
      "remote.origin.url git@gitlab.com:gitlab-org/gitlab.git",
    ].join("\n"),
  } = options;
  const calls: string[][] = [];
  const gitCalls: Array<{ args: string[]; cwd: string }> = [];
  const updates: { sessionID: string; title: string }[] = [];
  const tools: Record<string, any> = {};
  let hook: (event: any) => Promise<void> = async () => {};
  const glab = async (args: string[]) => {
    calls.push(args);
    const key =
      args[0] === "graphql"
        ? `${args.find((arg) => arg.startsWith("fullPath="))}#${args.find((arg) => arg.startsWith("iid="))}`
        : args[0];
    if (!(key in responses)) throw new Error(`no response for ${key}`);
    return JSON.stringify(responses[key]);
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
    calls,
    gitCalls,
    updates,
    tools,
    ready: createPlugin(glab, git).setup(ctx as any),
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

describe("title hook", () => {
  test("names implementation sessions after the issue title", async () => {
    const plugin = setup({
      "fullPath=group/nested/project#iid=123": workItem(
        "Fix  factory\ndefaults",
      ),
    });
    await plugin.ready;
    const event = await plugin.title([
      { type: "text", text: `Address ${issue}` },
    ]);
    expect(event.result).toBe("Fix factory defaults");
    expect(plugin.gitCalls).toHaveLength(0);
  });

  test("resolves bare and cross-project issue shorthands", async () => {
    const plugin = setup({
      "fullPath=gitlab-org/gitlab#iid=28": workItem(
        "Detect squash-merged branches",
      ),
      "fullPath=group/project#iid=123": workItem("Cross-project issue"),
    });
    await plugin.ready;

    const bare = await plugin.title("Let's address #28");
    expect(bare.result).toBe("Detect squash-merged branches");
    expect(plugin.gitCalls).toHaveLength(1);

    const cross = await plugin.title("Address group/project#123");
    expect(cross.result).toBe("Cross-project issue");
    expect(plugin.gitCalls).toHaveLength(1);
  });

  test("supports group work items", async () => {
    const plugin = setup({
      "fullPath=gitlab-org#iid=5": workItem("Group epic"),
    });
    await plugin.ready;
    const event = await plugin.title(
      "Work on https://gitlab.com/groups/gitlab-org/-/work_items/5",
    );
    expect(event.result).toBe("Group epic");
  });

  test("leaves read-only requests, earlier results, and failed lookups alone", async () => {
    const plugin = setup({});
    await plugin.ready;
    expect((await plugin.title(`Summarize ${issue}`)).result).toBeUndefined();
    expect((await plugin.title(`Address ${issue}`, "Earlier")).result).toBe(
      "Earlier",
    );
    expect(plugin.calls).toHaveLength(0);
    expect((await plugin.title(`Address ${issue}`)).result).toBeUndefined();
  });

  test("adds the MR author and MR title for full URL review requests", async () => {
    const plugin = setup({
      "projects/group%2Fproject/merge_requests/71": {
        author: { username: "jdoe" },
        title: "Update factory defaults",
      },
    });
    await plugin.ready;
    const event = await plugin.title(`Review ${mr}`);
    expect(event.result).toBeUndefined();
    expect(event.system[0].text).toContain(
      `The GitLab merge request ${mr} ("Update factory defaults") is by @jdoe.`,
    );
    expect(plugin.gitCalls).toHaveLength(0);
  });

  test("resolves bare !iid and cross-project!iid MR shorthands preferring origin", async () => {
    const plugin = setup({
      "projects/gitlab-org%2Fgitlab/merge_requests/274266": {
        author: { username: "dlrussel" },
        title: "Rename destroy_pipeline to delete_pipeline",
      },
      "projects/gitlab-org%2Fsecurity%2Fgitlab/merge_requests/99": {
        author: { username: "secdev" },
        title: "Security patch",
      },
    });
    await plugin.ready;

    const bare = await plugin.title("Review !274266");
    expect(bare.result).toBeUndefined();
    expect(bare.system[0].text).toContain(
      'The GitLab merge request !274266 ("Rename destroy_pipeline to delete_pipeline") is by @dlrussel.',
    );
    expect(plugin.calls[0]).toEqual([
      "projects/gitlab-org%2Fgitlab/merge_requests/274266",
    ]);

    const fallbackRemote = await plugin.title("Review !99");
    expect(fallbackRemote.system[0].text).toContain(
      'The GitLab merge request !99 ("Security patch") is by @secdev.',
    );

    const cross = await plugin.title("Review gitlab-org/gitlab!274266");
    expect(cross.system[0].text).toContain(
      'The GitLab merge request gitlab-org/gitlab!274266 ("Rename destroy_pipeline to delete_pipeline") is by @dlrussel.',
    );
  });

  test("ignores bare shorthands in non-GitLab repositories", async () => {
    const plugin = setup(
      {},
      { remotes: "remote.origin.url git@github.com:owner/repo.git" },
    );
    await plugin.ready;
    const event = await plugin.title("Review !274266");
    expect(event.system).toHaveLength(0);
    expect(plugin.calls).toHaveLength(0);
  });
});

describe("rename tools", () => {
  test("renames a session after an issue URL or shorthand and keeps the Forgekeeper prefix", async () => {
    const plugin = setup(
      {
        "fullPath=group/nested/project#iid=123": workItem(
          "Fix factory defaults",
        ),
        "fullPath=gitlab-org/gitlab#iid=642511": workItem(
          "Rename pipeline mutation",
        ),
      },
      { sessionTitle: "[#123, !456] Old title" },
    );
    await plugin.ready;
    const output = await plugin.tools.rename_issue_session.execute(
      { url: issue },
      context,
    );
    expect(output.content).toBe(
      "Session title: [#123, !456] Fix factory defaults",
    );
    expect(plugin.updates[0]).toEqual({
      sessionID: "ses_test",
      title: "[#123, !456] Fix factory defaults",
    });

    const shortOutput = await plugin.tools.rename_issue_session.execute(
      { url: "#642511" },
      context,
    );
    expect(shortOutput.content).toBe(
      "Session title: [#123, !456] Rename pipeline mutation",
    );
  });

  test("rejects issue references embedded in other text", async () => {
    const plugin = setup({});
    await plugin.ready;
    for (const bad of [`see ${issue}`, "see #123"]) {
      const output = await plugin.tools.rename_issue_session.execute(
        { url: bad },
        context,
      );
      expect(output.content).toStartWith("No title changed.");
    }
    expect(plugin.updates).toHaveLength(0);
  });

  test("renames a review session using explicit topic or MR title fallback", async () => {
    const plugin = setup(
      {
        "projects/group%2Fproject/merge_requests/71": {
          author: { username: "jdoe" },
          title: "Fallback MR title",
        },
        "projects/gitlab-org%2Fgitlab/merge_requests/274266": {
          author: { username: "dlrussel" },
          title: "Rename destroy_pipeline to delete_pipeline",
        },
      },
      { sessionTitle: "[!71] Old title" },
    );
    await plugin.ready;

    await plugin.tools.rename_mr_review_session.execute(
      { url: mr, topic: "factory defaults !71" },
      context,
    );
    expect(plugin.updates[0]).toEqual({
      sessionID: "ses_test",
      title: "[!71] @jdoe - Review factory defaults",
    });

    await plugin.tools.rename_mr_review_session.execute(
      { url: "!274266" },
      context,
    );
    expect(plugin.updates[1]).toEqual({
      sessionID: "ses_test",
      title:
        "[!71] @dlrussel - Review Rename destroy_pipeline to delete_pipeline",
    });

    await plugin.tools.rename_mr_review_session.execute(
      { url: mr, topic: "merge request" },
      context,
    );
    expect(plugin.updates[2]).toEqual({
      sessionID: "ses_test",
      title: "[!71] @jdoe - Review Fallback MR title",
    });
  });

  test("rejects MR references embedded in other text", async () => {
    const plugin = setup({});
    await plugin.ready;
    for (const bad of [`see ${mr}`, "see !274266"]) {
      const output = await plugin.tools.rename_mr_review_session.execute(
        { url: bad },
        context,
      );
      expect(output.content).toStartWith("No title changed.");
    }
    expect(plugin.updates).toHaveLength(0);
  });
});
