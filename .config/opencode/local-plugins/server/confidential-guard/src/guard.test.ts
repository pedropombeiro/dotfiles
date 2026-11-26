import { describe, expect, test } from "bun:test";
import {
  analyzeGitConfig,
  checkToolCallBefore,
  confidentialReasonForDirectory,
  createPlugin,
  detectConfidentialOutput,
  DUO_MODELS,
  duoModelForAgent,
  extractBranchIssueIid,
  extractGitLabRefs,
  extractTargetsFromInstructions,
  extractToolInputRefs,
  forkSource,
  GitLabConfidentialityChecker,
  isConfidentialProjectPath,
  isGitLabOutputTool,
  linkedOwner,
  parseModelRef,
  redactToolResult,
  resolveDuoModels,
} from "../index.ts";

const VERTEX_PLAN = { providerID: "google-vertex", id: "gemini-4-argon" };
const VERTEX_BUILD = { providerID: "google-vertex", id: "gemini-4-neon" };
const VERTEX_FAST = { providerID: "google-vertex", id: "gemini-4-hydrogen" };

describe("duoModelForAgent", () => {
  test("maps agents to their expected Duo models", () => {
    expect(duoModelForAgent("plan")).toEqual(DUO_MODELS.plan);
    expect(duoModelForAgent(undefined)).toEqual(DUO_MODELS.plan);
    expect(duoModelForAgent("build")).toEqual(DUO_MODELS.build);
    expect(duoModelForAgent("explore")).toEqual(DUO_MODELS.explore);
    expect(duoModelForAgent("title")).toEqual(DUO_MODELS.title);
    expect(duoModelForAgent("general", DUO_MODELS.build)).toEqual(
      DUO_MODELS.build,
    );
    expect(duoModelForAgent("general", VERTEX_BUILD)).toEqual(DUO_MODELS.plan);
  });

  test("parseModelRef and resolveDuoModels read options and env while rejecting non-gitlab providers", () => {
    expect(parseModelRef("gitlab/duo-chat-gpt-7-plan#high")).toEqual({
      providerID: "gitlab",
      id: "duo-chat-gpt-7-plan",
      variant: "high",
    });

    const resolved = resolveDuoModels(
      {
        models: {
          plan: "gitlab/duo-chat-custom-plan",
          // Non-gitlab provider must be ignored so confidential work stays on Duo.
          build: "google-vertex/gemini-4-neon",
        },
      },
      {
        OPENCODE_DUO_BUILD_MODEL: "gitlab/duo-chat-env-build",
        OPENCODE_DUO_FAST_MODEL: "gitlab/duo-chat-env-fast",
      },
    );

    expect(resolved).toEqual({
      plan: { providerID: "gitlab", id: "duo-chat-custom-plan" },
      build: { providerID: "gitlab", id: "duo-chat-env-build" },
      explore: { providerID: "gitlab", id: "duo-chat-env-fast" },
      title: { providerID: "gitlab", id: "duo-chat-env-fast" },
    });
  });
});

describe("confidential project & repo detection", () => {
  test("recognizes confidential project paths and ignores public repos", () => {
    expect(isConfidentialProjectPath("gitlab-org/security/gitlab")).toBe(true);
    expect(isConfidentialProjectPath("gitlab-org%2Fsecurity%2Fgitlab")).toBe(
      true,
    );
    expect(
      isConfidentialProjectPath(
        "https://gitlab.com/gitlab-com/gl-security/appsec/issue-tracker",
      ),
    ).toBe(true);
    expect(isConfidentialProjectPath("pedropombeiro/work-friction")).toBe(true);
    expect(isConfidentialProjectPath("gitlab-org/gitlab")).toBe(false);
    expect(isConfidentialProjectPath("gitlab-org/gitlab-runner")).toBe(false);
  });

  test("recognizes confidential directories", () => {
    expect(
      confidentialReasonForDirectory(
        "/Users/p/Developer/gitlab.com/gitlab-org/security/gitlab",
      ),
    ).toBeDefined();
    expect(
      confidentialReasonForDirectory(
        "/Users/p/Developer/gitlab.com/pedropombeiro/work-friction",
      ),
    ).toBeDefined();
    expect(
      confidentialReasonForDirectory("/Users/p/gitlab-development-kit/gitlab"),
    ).toBeUndefined();
  });

  test("analyzeGitConfig keeps shared GDK checkout public on public branch and locks on security branch", () => {
    const sharedConfig = [
      "remote.origin.url git@gitlab.com:gitlab-org/gitlab.git",
      "remote.security.url git@gitlab.com:gitlab-org/security/gitlab.git",
      "branch.pedropombeiro/12345/public-fix.remote origin",
      "branch.security-fix-cve.remote security",
    ].join("\n");

    const publicBranch = analyzeGitConfig(
      sharedConfig,
      "pedropombeiro/12345/public-fix",
    );
    expect(publicBranch.confidentialReason).toBeUndefined();
    expect(publicBranch.defaultProject).toBe("gitlab-org/gitlab");

    const securityBranch = analyzeGitConfig(sharedConfig, "security-fix-cve");
    expect(securityBranch.confidentialReason).toContain("security");

    const standaloneSecurity = analyzeGitConfig(
      "remote.origin.url git@gitlab.com:gitlab-org/security/gitlab.git",
      "master",
    );
    expect(standaloneSecurity.confidentialReason).toContain(
      "gitlab-org/security/gitlab",
    );
  });

  test("extractBranchIssueIid extracts numeric issue IIDs only", () => {
    expect(extractBranchIssueIid("pedropombeiro/543210/fix-auth")).toBe(
      "543210",
    );
    expect(extractBranchIssueIid("pedropombeiro/42/short")).toBe("42");
    expect(extractBranchIssueIid("master")).toBeUndefined();
    expect(
      extractBranchIssueIid("docs-sync/principles-2026-11-26"),
    ).toBeUndefined();
  });
});

describe("extractGitLabRefs & extractTargetsFromInstructions", () => {
  test("parses URLs, qualified shorthands, and bare shorthands", () => {
    const refs = extractGitLabRefs(
      [
        "Look at https://gitlab.com/gitlab-org/gitlab/-/issues/100",
        "and https://gitlab.com/groups/gitlab-org/-/epics/24897",
        "and gitlab-org/security/gitlab!55",
        "and #200",
      ].join(" "),
      "gitlab-org/gitlab",
    );

    expect(refs).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          kind: "issue",
          path: "gitlab-org/gitlab",
          iid: "100",
        }),
        expect.objectContaining({
          kind: "group_work_item",
          path: "gitlab-org",
          iid: "24897",
        }),
        expect.objectContaining({
          kind: "merge_request",
          path: "gitlab-org/security/gitlab",
          iid: "55",
        }),
        expect.objectContaining({
          kind: "issue",
          path: "gitlab-org/gitlab",
          iid: "200",
        }),
      ]),
    );
  });

  test("extractTargetsFromInstructions ignores none and returns active targets", () => {
    expect(
      extractTargetsFromInstructions([
        {
          key: "forgekeeper-session-target",
          value: "Current session target: none.",
        },
      ]),
    ).toBeUndefined();

    expect(
      extractTargetsFromInstructions([
        {
          key: "forgekeeper-session-target",
          value:
            "Current session target: https://gitlab.com/gitlab-org/gitlab/-/issues/999.",
        },
      ]),
    ).toContain("https://gitlab.com/gitlab-org/gitlab/-/issues/999");
  });
});

describe("GitLabConfidentialityChecker", () => {
  test("flags confidential project offline without invoking glab", async () => {
    let calls = 0;
    const checker = new GitLabConfidentialityChecker(async () => {
      calls += 1;
      return "{}";
    });

    const reason = await checker.checkRefs([
      { kind: "merge_request", path: "gitlab-org/security/gitlab", iid: "12" },
    ]);
    expect(reason).toContain("gitlab-org/security/gitlab");
    expect(calls).toBe(0);
  });

  test("detects confidential issue, security label rules, group epics, and MRs closing confidential issues", async () => {
    const calls: string[] = [];
    const checker = new GitLabConfidentialityChecker(async (args) => {
      calls.push(args.join(" "));
      const endpoint = args[0];
      if (endpoint === "projects/gitlab-org%2Fgitlab/issues/1") {
        return JSON.stringify({ confidential: true, labels: [] });
      }
      if (endpoint === "projects/gitlab-org%2Fgitlab/issues/2") {
        return JSON.stringify({ confidential: false, labels: ["security"] });
      }
      if (endpoint === "projects/gitlab-org%2Fgitlab/issues/3") {
        return JSON.stringify({
          confidential: false,
          labels: ["security", "security-fix-in-public"],
        });
      }
      if (endpoint === "projects/gitlab-org%2Fgitlab/merge_requests/10") {
        return JSON.stringify({
          labels: [],
          source_branch: "pedropombeiro/1/secret-fix",
          description: "Fixes #1",
        });
      }
      if (endpoint === "projects/gitlab-org%2Fgitlab/merge_requests/11") {
        return JSON.stringify({
          labels: [],
          source_branch: "pedropombeiro/3/public-fix",
          description: "Fixes #3",
        });
      }
      if (
        endpoint ===
        "projects/gitlab-org%2Fgitlab/merge_requests/11/closes_issues"
      ) {
        return JSON.stringify([{ iid: 3, confidential: false, labels: [] }]);
      }
      if (endpoint === "graphql") {
        return JSON.stringify({
          data: { namespace: { workItem: { confidential: true } } },
        });
      }
      throw new Error(`unexpected endpoint: ${endpoint}`);
    });

    expect(
      await checker.checkRefs([
        { kind: "issue", path: "gitlab-org/gitlab", iid: "1" },
      ]),
    ).toContain("confidential issue");
    // Second call hits cache.
    const countAfterFirst = calls.length;
    expect(
      await checker.checkRefs([
        { kind: "issue", path: "gitlab-org/gitlab", iid: "1" },
      ]),
    ).toContain("confidential issue");
    expect(calls.length).toBe(countAfterFirst);

    expect(
      await checker.checkRefs([
        { kind: "issue", path: "gitlab-org/gitlab", iid: "2" },
      ]),
    ).toContain("security issue");
    expect(
      await checker.checkRefs([
        { kind: "issue", path: "gitlab-org/gitlab", iid: "3" },
      ]),
    ).toBeUndefined();
    expect(
      await checker.checkRefs([
        { kind: "merge_request", path: "gitlab-org/gitlab", iid: "10" },
      ]),
    ).toContain("confidential issue");
    expect(
      await checker.checkRefs([
        { kind: "merge_request", path: "gitlab-org/gitlab", iid: "11" },
      ]),
    ).toBeUndefined();
    expect(
      await checker.checkRefs([
        { kind: "group_work_item", path: "gitlab-org", iid: "99" },
      ]),
    ).toContain("confidential work item");
  });
});

describe("pre-execution & post-execution tool checks", () => {
  test("checkToolCallBefore detects RED MCP servers, confidential GitLab params, and RED shell commands", () => {
    expect(
      checkToolCallBefore("lazy-mcp_invoke_command", {
        server: "esquery",
        command_name: "search",
      }),
    ).toBeDefined();
    expect(
      checkToolCallBefore("lazy-mcp_invoke_command", {
        server: "incident_io",
        command_name: "list_incidents",
      }),
    ).toBeDefined();
    expect(
      checkToolCallBefore("lazy-mcp_invoke_command", {
        server: "gitlab",
        command_name: "get_issue",
        parameters: { project_id: "pedropombeiro/work-friction", iid: 12 },
      }),
    ).toBeDefined();
    expect(
      checkToolCallBefore("gitlab_get_merge_request", {
        project_id: "gitlab-org/security/gitlab",
        mr_iid: 42,
      }),
    ).toBeDefined();
    expect(
      checkToolCallBefore("shell", {
        command: "FOO=1 ~/.agents/skills/dblab/scripts/pgai query 'SELECT 1'",
      }),
    ).toBeDefined();
    expect(
      checkToolCallBefore("shell", {
        command: "mise exec -- esquery search --index pubsub-rails",
      }),
    ).toBeDefined();
    expect(
      checkToolCallBefore("shell", {
        command:
          "glab api projects/gitlab-org%2Fsecurity%2Fgitlab/merge_requests/1",
      }),
    ).toBeDefined();
    expect(
      checkToolCallBefore("gitlab_list_vulnerabilities", {
        project_id: "gitlab-org/gitlab",
      }),
    ).toBeDefined();
    expect(
      checkToolCallBefore("gitlab_list_project_audit_events", {
        project_id: "gitlab-org/gitlab",
      }),
    ).toBeDefined();
    expect(
      extractToolInputRefs("gitlab_get_work_item_notes", {
        project_id: "gitlab-org/gitlab",
        work_item_id: 555,
      }),
    ).toEqual([{ kind: "issue", path: "gitlab-org/gitlab", iid: "555" }]);
    expect(
      extractToolInputRefs("gitlab_list_discussions", {
        resource_type: "merge_request",
        project_id: "gitlab-org/gitlab",
        iid: 777,
      }),
    ).toEqual([
      { kind: "merge_request", path: "gitlab-org/gitlab", iid: "777" },
    ]);
    expect(
      checkToolCallBefore("read", {
        path: "/Users/p/Developer/gitlab.com/gitlab-org/security/gitlab/app/models/user.rb",
      }),
    ).toBeDefined();
    expect(
      checkToolCallBefore("shell", {
        command: 'bash -c "esquery search --index pubsub-rails"',
      }),
    ).toBeDefined();
    expect(
      checkToolCallBefore("shell", {
        command: '"$HOME/.agents/skills/dblab/scripts/pgai" query "SELECT 1"',
      }),
    ).toBeDefined();
    expect(
      checkToolCallBefore("shell", {
        command: "run-in-tmux-pane 'pgai query SELECT 1'",
      }),
    ).toBeDefined();

    // Non-confidential / benign calls must pass.
    expect(
      checkToolCallBefore("gitlab_get_merge_request", {
        project_id: "gitlab-org/gitlab",
        mr_iid: 42,
      }),
    ).toBeUndefined();
    expect(
      checkToolCallBefore("shell", {
        command: "git grep esquery docs/",
      }),
    ).toBeUndefined();
    expect(
      checkToolCallBefore("shell", {
        command: "glab mr view 274266",
      }),
    ).toBeUndefined();
  });

  test("detectConfidentialOutput and redactToolResult catch confidential responses", () => {
    expect(
      detectConfidentialOutput('{"iid": 1, "confidential": true}'),
    ).toBeDefined();
    expect(
      detectConfidentialOutput("Title: Secret\nConfidential: true\n"),
    ).toBeDefined();
    expect(
      detectConfidentialOutput(
        "web_url: https://gitlab.com/gitlab-org/security/gitlab/-/merge_requests/5",
      ),
    ).toBeDefined();
    expect(
      detectConfidentialOutput(
        JSON.stringify([{ iid: 42, labels: ["security", "type::bug"] }]),
      ),
    ).toBeDefined();
    expect(
      detectConfidentialOutput(
        JSON.stringify([
          {
            iid: 43,
            labels: ["security", "security-fix-in-public", "type::bug"],
          },
        ]),
      ),
    ).toBeUndefined();
    expect(
      detectConfidentialOutput('{"iid": 1, "confidential": false}'),
    ).toBeUndefined();

    const redacted = redactToolResult(
      {
        content: [{ type: "text", text: "secret body" }],
        output: "secret body",
        metadata: { raw: "secret" },
      },
      "[withheld]",
    );
    expect(redacted.content).toEqual([{ type: "text", text: "[withheld]" }]);
    expect(redacted.output).toBe("[withheld]");
    expect(redacted.metadata).toEqual({ confidentialRedacted: true });
  });

  test("linkedOwner ignores forks and returns valid Forgekeeper linked owner", () => {
    expect(
      linkedOwner({
        id: "ses_linked",
        metadata: {
          forgekeeper: {
            linked: { owner: "ses_owner", session: "ses_linked" },
          },
        },
      }),
    ).toBe("ses_owner");
    expect(
      linkedOwner({
        id: "ses_fork",
        fork: { sessionID: "ses_linked" },
        metadata: {
          forgekeeper: {
            linked: { owner: "ses_owner", session: "ses_linked" },
          },
        },
      }),
    ).toBeUndefined();
  });
});

interface MockSession {
  id: string;
  parentID?: string;
  fork?: { sessionID?: string };
  agent?: string;
  model?: { providerID: string; id: string };
  metadata?: Record<string, unknown>;
  location?: { directory: string };
}

function createMockContext(opts: {
  directory?: string;
  sessions: Record<string, MockSession>;
  instructions?: Record<string, Array<{ key: string; value: string }>>;
  branch?: string;
  generatedTitle?: string;
}) {
  const storage = new Map<string, unknown>();
  const sessionHooks = new Map<
    string,
    Array<(event: any) => Promise<void> | void>
  >();
  const toolHooks = new Map<
    string,
    Array<(event: any) => Promise<void> | void>
  >();
  const switched: Array<{
    sessionID: string;
    model: { providerID: string; id: string };
  }> = [];

  const ctx: any = {
    location: { directory: opts.directory ?? "/gdk/gitlab" },
    storage: {
      async get(key: string) {
        return storage.get(key);
      },
      async set(key: string, value: unknown) {
        storage.set(key, value);
      },
    },
    vcs: {
      async get() {
        return { data: { branch: { current: opts.branch ?? "master" } } };
      },
    },
    experimental: {
      generate: {
        async text({ model }: { model: { providerID: string; id: string } }) {
          if (!opts.generatedTitle) throw new Error("unavailable");
          return { data: { text: `${opts.generatedTitle} (${model.id})` } };
        },
      },
    },
    session: {
      async get({ sessionID }: { sessionID: string }) {
        const s = opts.sessions[sessionID];
        if (!s) throw new Error(`missing session ${sessionID}`);
        return s;
      },
      async switchModel({
        sessionID,
        model,
      }: {
        sessionID: string;
        model: { providerID: string; id: string };
      }) {
        switched.push({ sessionID, model });
        if (opts.sessions[sessionID]) {
          opts.sessions[sessionID].model = model;
        }
      },
      instructions: {
        entry: {
          async list({ sessionID }: { sessionID: string }) {
            return opts.instructions?.[sessionID] ?? [];
          },
        },
      },
      async hook(name: string, fn: (event: any) => Promise<void> | void) {
        const list = sessionHooks.get(name) ?? [];
        list.push(fn);
        sessionHooks.set(name, list);
      },
    },
    tool: {
      async hook(name: string, fn: (event: any) => Promise<void> | void) {
        const list = toolHooks.get(name) ?? [];
        list.push(fn);
        toolHooks.set(name, list);
      },
    },
  };

  return {
    ctx,
    storage,
    switched,
    async emitSession(name: string, event: any) {
      for (const fn of sessionHooks.get(name) ?? []) await fn(event);
    },
    async emitTool(name: string, event: any) {
      for (const fn of toolHooks.get(name) ?? []) await fn(event);
    },
  };
}

describe("confidential-guard plugin integration", () => {
  const defaultGit = async (args: string[]) => {
    if (args[0] === "config") {
      return [
        "remote.origin.url git@gitlab.com:gitlab-org/gitlab.git",
        "remote.security.url git@gitlab.com:gitlab-org/security/gitlab.git",
      ].join("\n");
    }
    return "master";
  };

  const defaultGlab = async (args: string[]) => {
    const endpoint = args[0];
    if (endpoint === "projects/gitlab-org%2Fgitlab/issues/555") {
      return JSON.stringify({ confidential: true, labels: [] });
    }
    if (endpoint === "projects/gitlab-org%2Fgitlab/issues/111") {
      return JSON.stringify({ confidential: false, labels: [] });
    }
    if (endpoint === "projects/gitlab-org%2Fgitlab/merge_requests/777") {
      return JSON.stringify({
        labels: [],
        source_branch: "pedropombeiro/555/secret-fix",
        description: "Fixes #555",
      });
    }
    return JSON.stringify({ confidential: false, labels: [] });
  };

  test("switches session on prompt hook for confidential issue and leaves public issues on Vertex", async () => {
    const harness = createMockContext({
      sessions: {
        ses_pub: {
          id: "ses_pub",
          agent: "plan",
          model: VERTEX_PLAN,
          location: { directory: "/gdk/gitlab" },
        },
        ses_sec: {
          id: "ses_sec",
          agent: "build",
          model: VERTEX_BUILD,
          location: { directory: "/gdk/gitlab" },
        },
      },
    });
    const plugin = createPlugin({ git: defaultGit, glab: defaultGlab });
    await plugin.setup(harness.ctx);

    await harness.emitSession("prompt", {
      sessionID: "ses_pub",
      prompt: {
        text: "Please check https://gitlab.com/gitlab-org/gitlab/-/issues/111",
      },
    });
    expect(harness.switched).toEqual([]);

    await harness.emitSession("prompt", {
      sessionID: "ses_sec",
      prompt: {
        text: "Please fix https://gitlab.com/gitlab-org/gitlab/-/issues/555",
      },
    });
    expect(harness.switched).toEqual([
      { sessionID: "ses_sec", model: DUO_MODELS.build },
    ]);
  });

  test("Forgekeeper linked worktree session switches both linked and owner sessions to Duo before turn", async () => {
    const harness = createMockContext({
      directory: "/worktrees/wt-1",
      sessions: {
        ses_owner: {
          id: "ses_owner",
          agent: "plan",
          model: VERTEX_PLAN,
          location: { directory: "/gdk/gitlab" },
        },
        ses_linked: {
          id: "ses_linked",
          agent: "plan",
          model: VERTEX_PLAN,
          location: { directory: "/worktrees/wt-1" },
          metadata: {
            forgekeeper: {
              linked: { owner: "ses_owner", session: "ses_linked" },
            },
          },
        },
      },
    });
    const plugin = createPlugin({ git: defaultGit, glab: defaultGlab });
    await plugin.setup(harness.ctx);

    await harness.emitSession("prompt", {
      sessionID: "ses_linked",
      prompt: {
        text: "Forgekeeper failed-job investigation task for https://gitlab.com/gitlab-org/gitlab/-/merge_requests/777.",
      },
    });

    expect(harness.switched).toEqual([
      { sessionID: "ses_linked", model: DUO_MODELS.plan },
      { sessionID: "ses_owner", model: DUO_MODELS.plan },
    ]);
  });

  test("explore subagent inherits confidential lock from parent and switches to Duo Luna", async () => {
    const harness = createMockContext({
      sessions: {
        ses_parent: {
          id: "ses_parent",
          agent: "plan",
          model: DUO_MODELS.plan,
          location: { directory: "/gdk/gitlab" },
        },
        ses_child: {
          id: "ses_child",
          parentID: "ses_parent",
          agent: "explore",
          model: VERTEX_FAST,
          location: { directory: "/gdk/gitlab" },
        },
      },
    });
    const plugin = createPlugin({ git: defaultGit, glab: defaultGlab });
    await plugin.setup(harness.ctx);

    // Parent starts directly on Duo, prompt still records the lock.
    await harness.emitSession("prompt", {
      sessionID: "ses_parent",
      prompt: {
        text: "Investigate https://gitlab.com/gitlab-org/gitlab/-/issues/555",
      },
    });
    expect(harness.switched).toEqual([]);

    // Spawned explore subagent (defaulting to Vertex Hydrogen) gets switched to Duo Luna.
    await harness.emitSession("prompt", {
      sessionID: "ses_child",
      prompt: { text: "Find callers of AuthService" },
    });
    expect(harness.switched).toEqual([
      { sessionID: "ses_child", model: DUO_MODELS.explore },
    ]);
  });

  test("execute.before blocks RED tool on upstream model and allows once switched to Duo", async () => {
    const harness = createMockContext({
      sessions: {
        ses_1: {
          id: "ses_1",
          agent: "plan",
          model: VERTEX_PLAN,
          location: { directory: "/gdk/gitlab" },
        },
      },
    });
    const plugin = createPlugin({ git: defaultGit, glab: defaultGlab });
    await plugin.setup(harness.ctx);

    await expect(
      harness.emitTool("execute.before", {
        sessionID: "ses_1",
        agent: "plan",
        tool: "lazy-mcp_invoke_command",
        input: { server: "esquery", command_name: "search", parameters: {} },
      }),
    ).rejects.toThrow(/blocked on upstream model/i);

    expect(harness.switched).toEqual([
      { sessionID: "ses_1", model: DUO_MODELS.plan },
    ]);

    // Now that session model is Duo, the same call succeeds.
    await expect(
      harness.emitTool("execute.before", {
        sessionID: "ses_1",
        agent: "plan",
        tool: "lazy-mcp_invoke_command",
        input: { server: "esquery", command_name: "search", parameters: {} },
      }),
    ).resolves.toBeUndefined();
  });

  test("execute.after redacts confidential GitLab output on upstream model and preserves on Duo", async () => {
    const harness = createMockContext({
      sessions: {
        ses_up: {
          id: "ses_up",
          agent: "build",
          model: VERTEX_BUILD,
          location: { directory: "/gdk/gitlab" },
        },
        ses_duo: {
          id: "ses_duo",
          agent: "build",
          model: DUO_MODELS.build,
          location: { directory: "/gdk/gitlab" },
        },
      },
    });
    const plugin = createPlugin({ git: defaultGit, glab: defaultGlab });
    await plugin.setup(harness.ctx);

    const upstreamEvent: any = {
      sessionID: "ses_up",
      agent: "build",
      tool: "gitlab_get_issue",
      input: { project_id: "gitlab-org/gitlab", issue_iid: 555 },
      status: "completed",
      result: {
        content: [
          {
            type: "text",
            text: '{"iid": 555, "confidential": true, "description": "TOP SECRET"}',
          },
        ],
      },
    };
    await harness.emitTool("execute.after", upstreamEvent);
    expect(harness.switched).toEqual([
      { sessionID: "ses_up", model: DUO_MODELS.build },
    ]);
    expect(upstreamEvent.result.content[0].text).toContain(
      "withheld from upstream model",
    );
    expect(upstreamEvent.result.content[0].text).not.toContain("TOP SECRET");

    const duoEvent: any = {
      sessionID: "ses_duo",
      agent: "build",
      tool: "gitlab_get_issue",
      input: { project_id: "gitlab-org/gitlab", issue_iid: 555 },
      status: "completed",
      result: {
        content: [
          {
            type: "text",
            text: '{"iid": 555, "confidential": true, "description": "TOP SECRET"}',
          },
        ],
      },
    };
    await harness.emitTool("execute.after", duoEvent);
    expect(duoEvent.result.content[0].text).toContain("TOP SECRET");
  });

  test("context backstop blocks upstream request and title hook routes confidential titles to Duo Luna", async () => {
    const harness = createMockContext({
      sessions: {
        ses_1: {
          id: "ses_1",
          agent: "plan",
          model: VERTEX_PLAN,
          location: { directory: "/gdk/gitlab" },
        },
      },
      branch: "pedropombeiro/555/secret-fix",
      generatedTitle: "Secret fix",
    });
    const plugin = createPlugin({ git: defaultGit, glab: defaultGlab });
    await plugin.setup(harness.ctx);

    await expect(
      harness.emitSession("context", {
        sessionID: "ses_1",
        agent: "plan",
        model: VERTEX_PLAN,
        messages: [],
        system: [],
      }),
    ).rejects.toThrow(/Blocked upstream model/);

    const titleEvent: any = {
      sessionID: "ses_1",
      model: VERTEX_FAST,
      messages: [{ role: "user", content: "Fix confidential auth bypass" }],
      system: [],
    };
    await harness.emitSession("title", titleEvent);
    expect(titleEvent.result).toBe("Secret fix (duo-chat-gpt-6-luna)");
  });

  test("set_session_target switches to Duo and prompt hook checks forgekeeper-session-target instructions", async () => {
    const harness = createMockContext({
      sessions: {
        ses_target: {
          id: "ses_target",
          agent: "plan",
          model: VERTEX_PLAN,
          location: { directory: "/gdk/gitlab" },
        },
        ses_inst: {
          id: "ses_inst",
          agent: "build",
          model: VERTEX_BUILD,
          location: { directory: "/gdk/gitlab" },
        },
      },
      instructions: {
        ses_inst: [
          {
            key: "forgekeeper-session-target",
            value:
              "Current session target: https://gitlab.com/gitlab-org/gitlab/-/issues/555.",
          },
        ],
      },
    });
    const plugin = createPlugin({ git: defaultGit, glab: defaultGlab });
    await plugin.setup(harness.ctx);

    const targetEvent: any = {
      sessionID: "ses_target",
      agent: "plan",
      tool: "set_session_target",
      input: { target: "https://gitlab.com/gitlab-org/gitlab/-/issues/555" },
      status: "completed",
      result: { content: "Target updated." },
    };
    await harness.emitTool("execute.after", targetEvent);
    expect(harness.switched).toContainEqual({
      sessionID: "ses_target",
      model: DUO_MODELS.plan,
    });
    expect(targetEvent.result.content).toContain(
      "Session model switched to gitlab/duo-chat-gpt-6-2-astra",
    );

    await harness.emitSession("prompt", {
      sessionID: "ses_inst",
      prompt: { text: "Please continue with the fix." },
    });
    expect(harness.switched).toContainEqual({
      sessionID: "ses_inst",
      model: DUO_MODELS.build,
    });

    // Without generate.text, title hook blocks upstream title generation instead of leaking.
    await expect(
      harness.emitSession("title", {
        sessionID: "ses_inst",
        model: VERTEX_FAST,
        messages: [{ role: "user", content: "Continue" }],
        system: [],
      }),
    ).rejects.toThrow(/Blocked upstream title model/);
  });

  test("execute.before checks confidential issue/MR IIDs on gitlab_* and glab calls before execution", async () => {
    const harness = createMockContext({
      sessions: {
        ses_disc: {
          id: "ses_disc",
          agent: "plan",
          model: VERTEX_PLAN,
          location: { directory: "/gdk/gitlab" },
        },
      },
    });
    const plugin = createPlugin({ git: defaultGit, glab: defaultGlab });
    await plugin.setup(harness.ctx);

    await expect(
      harness.emitTool("execute.before", {
        sessionID: "ses_disc",
        agent: "plan",
        tool: "gitlab_list_discussions",
        input: {
          project_id: "gitlab-org/gitlab",
          resource_type: "issue",
          resource_iid: 555,
        },
      }),
    ).rejects.toThrow(/blocked on upstream model/i);

    expect(harness.switched).toContainEqual({
      sessionID: "ses_disc",
      model: DUO_MODELS.plan,
    });
  });

  test("parallel tool calls in a single upstream turn remain guarded until a Duo turn starts", async () => {
    const harness = createMockContext({
      sessions: {
        ses_par: {
          id: "ses_par",
          agent: "build",
          model: VERTEX_BUILD,
          location: { directory: "/gdk/gitlab" },
        },
      },
    });
    const plugin = createPlugin({ git: defaultGit, glab: defaultGlab });
    await plugin.setup(harness.ctx);

    // Turn 1 starts on Vertex.
    await harness.emitSession("context", {
      sessionID: "ses_par",
      agent: "build",
      model: VERTEX_BUILD,
      messages: [],
      system: [],
    });

    const call1: any = {
      sessionID: "ses_par",
      agent: "build",
      tool: "gitlab_get_issue",
      input: { project_id: "gitlab-org/gitlab", issue_iid: 555 },
      status: "completed",
      result: {
        content: [
          {
            type: "text",
            text: '{"iid": 555, "confidential": true, "body": "SECRET 1"}',
          },
        ],
      },
    };
    const call2: any = {
      sessionID: "ses_par",
      agent: "build",
      tool: "gitlab_get_issue",
      input: { project_id: "gitlab-org/gitlab", issue_iid: 556 },
      status: "completed",
      result: {
        content: [
          {
            type: "text",
            text: '{"iid": 556, "confidential": true, "body": "SECRET 2"}',
          },
        ],
      },
    };

    await harness.emitTool("execute.after", call1);

    // Interleaved auxiliary Duo requests (transient generate and compaction)
    // must not overwrite the primary Vertex turn's model provenance.
    await harness.emitSession("generate", {
      sessionID: "ses_par",
      agent: "title",
      model: DUO_MODELS.title,
      transient: true,
    });
    await harness.emitSession("compaction", {
      sessionID: "ses_par",
      agent: "build",
      model: DUO_MODELS.build,
    });
    // A queued confidential prompt arriving before call2 finishes switches the
    // session model for the next turn, but must not unmask call2 in the current
    // Vertex turn.
    await harness.emitSession("prompt", {
      sessionID: "ses_par",
      prompt: {
        text: "Queued follow-up on https://gitlab.com/gitlab-org/gitlab/-/issues/555",
      },
    });

    await harness.emitTool("execute.after", call2);

    expect(call1.result.content[0].text).not.toContain("SECRET 1");
    expect(call2.result.content[0].text).not.toContain("SECRET 2");
  });

  test("failed glab lookups fail closed without caching as public, and incomplete MR lookups are not cached as public", async () => {
    let mode: "fail" | "confidential" | "public" = "fail";
    let closesShouldFail = true;
    let mrCalls = 0;

    const flakyChecker = new GitLabConfidentialityChecker(async (args) => {
      const endpoint = args[0];
      if (endpoint === "projects/gitlab-org%2Fgitlab/issues/888") {
        if (mode === "fail") throw new Error("timeout");
        if (mode === "confidential") {
          return JSON.stringify({ iid: 888, confidential: true, labels: [] });
        }
        return JSON.stringify({ iid: 888, confidential: false, labels: [] });
      }
      if (endpoint === "projects/gitlab-org%2Fgitlab/merge_requests/900") {
        mrCalls += 1;
        return JSON.stringify({
          iid: 900,
          labels: [],
          source_branch: "feature-branch",
          description: "",
        });
      }
      if (
        endpoint ===
        "projects/gitlab-org%2Fgitlab/merge_requests/900/closes_issues"
      ) {
        if (closesShouldFail) throw new Error("502 Bad Gateway");
        return JSON.stringify([]);
      }
      throw new Error(`unexpected: ${endpoint}`);
    });

    // 1. Lookup failure returns unknown (fail-closed truthy reason) and is not cached.
    const failedAssessment = await flakyChecker.checkRefsAssessment([
      { kind: "issue", path: "gitlab-org/gitlab", iid: "888" },
    ]);
    expect(failedAssessment.status).toBe("unknown");
    expect(
      await flakyChecker.checkRefs([
        { kind: "issue", path: "gitlab-org/gitlab", iid: "888" },
      ]),
    ).toContain("unverified");

    // 2. Subsequent retry reaches glab and detects confidentiality.
    mode = "confidential";
    expect(
      await flakyChecker.checkRefs([
        { kind: "issue", path: "gitlab-org/gitlab", iid: "888" },
      ]),
    ).toContain("confidential issue");

    // 3. MR with failing closes_issues returns unknown and is not cached as public.
    const mrUnknown = await flakyChecker.checkRefsAssessment([
      { kind: "merge_request", path: "gitlab-org/gitlab", iid: "900" },
    ]);
    expect(mrUnknown.status).toBe("unknown");
    expect(mrCalls).toBe(1);

    closesShouldFail = false;
    const mrPublic = await flakyChecker.checkRefsAssessment([
      { kind: "merge_request", path: "gitlab-org/gitlab", iid: "900" },
    ]);
    expect(mrPublic.status).toBe("public");
    expect(mrCalls).toBe(2);

    // 4. Issue payload missing boolean confidential or array labels is unknown, not public.
    const partialChecker = new GitLabConfidentialityChecker(async (args) => {
      if (args[0] === "projects/gitlab-org%2Fgitlab/issues/700") {
        return JSON.stringify({ iid: 700 });
      }
      if (args[0] === "graphql") {
        return JSON.stringify({ data: { namespace: { workItem: null } } });
      }
      return JSON.stringify({ iid: 1, confidential: false, labels: [] });
    });
    const partialOutcome = await partialChecker.checkRefsAssessment([
      { kind: "issue", path: "gitlab-org/gitlab", iid: "700" },
    ]);
    expect(partialOutcome.status).toBe("unknown");

    // 5. Reference budget overflow (> 16 public refs) fails closed as unknown.
    const twentyPublicRefs = extractGitLabRefs(
      Array.from(
        { length: 20 },
        (_, idx) => `https://gitlab.com/gitlab-org/gitlab/-/issues/${idx + 1}`,
      ).join(" "),
    );
    const overflowOutcome =
      await partialChecker.checkRefsAssessment(twentyPublicRefs);
    expect(overflowOutcome.status).toBe("unknown");
    expect(overflowOutcome.reason).toContain("beyond lookup limit");

    // Verify extractGitLabRefs priority for confidential project URLs.
    const refsWithManyPublic = extractGitLabRefs(
      Array.from(
        { length: 20 },
        (_, idx) => `https://gitlab.com/gitlab-org/gitlab/-/issues/${idx + 1}`,
      )
        .concat(
          "https://gitlab.com/gitlab-org/security/gitlab/-/merge_requests/9",
        )
        .join(" "),
    );
    expect(refsWithManyPublic[0]).toMatchObject({
      kind: "project",
      path: "gitlab-org/security/gitlab",
    });
    expect(isGitLabOutputTool("vent", {})).toBe(true);
    expect(
      extractToolInputRefs("glab", undefined, "gitlab-org/gitlab"),
    ).toEqual([]);
    expect(
      forkSource({ id: "ses_fork", fork: { sessionID: "ses_source" } }),
    ).toBe("ses_source");
  });

  test("reading work item notes on Duo locks the session, and forked/subagent sessions inherit the lock", async () => {
    const harness = createMockContext({
      sessions: {
        ses_duo_root: {
          id: "ses_duo_root",
          agent: "plan",
          model: DUO_MODELS.plan,
          location: { directory: "/gdk/gitlab" },
        },
        ses_explore_child: {
          id: "ses_explore_child",
          parentID: "ses_duo_root",
          agent: "explore",
          model: VERTEX_FAST,
          location: { directory: "/gdk/gitlab" },
        },
        ses_forked: {
          id: "ses_forked",
          fork: { sessionID: "ses_duo_root" },
          agent: "build",
          model: VERTEX_BUILD,
          location: { directory: "/gdk/gitlab" },
        },
      },
    });
    const plugin = createPlugin({ git: defaultGit, glab: defaultGlab });
    await plugin.setup(harness.ctx);

    // Duo session reads work_item_notes (with work_item_id: 555); notes response
    // has noconfidential flag, so execute.before must lock the session on Duo.
    await expect(
      harness.emitTool("execute.before", {
        sessionID: "ses_duo_root",
        agent: "plan",
        tool: "gitlab_get_work_item_notes",
        input: { project_id: "gitlab-org/gitlab", work_item_id: 555 },
      }),
    ).resolves.toBeUndefined();

    // Child explore subagent and forked session both inherit the lock and switch to Duo.
    await harness.emitSession("prompt", {
      sessionID: "ses_explore_child",
      prompt: { text: "Search for callers" },
    });
    expect(harness.switched).toContainEqual({
      sessionID: "ses_explore_child",
      model: DUO_MODELS.explore,
    });

    await harness.emitSession("prompt", {
      sessionID: "ses_forked",
      prompt: { text: "Continue implementation in fork" },
    });
    expect(harness.switched).toContainEqual({
      sessionID: "ses_forked",
      model: DUO_MODELS.build,
    });
  });

  test("branch switch within repo cache TTL and storage/switchModel failures fail closed", async () => {
    let activeBranch = "pedropombeiro/111/public-fix";
    const harness = createMockContext({
      sessions: {
        ses_branch: {
          id: "ses_branch",
          agent: "plan",
          model: VERTEX_PLAN,
          location: { directory: "/gdk/gitlab" },
        },
      },
    });
    harness.ctx.vcs.get = async () => ({
      data: { branch: { current: activeBranch } },
    });

    const gitWithSecurityBranch = async (args: string[]) => {
      if (args[0] === "config") {
        return [
          "remote.origin.url git@gitlab.com:gitlab-org/gitlab.git",
          "remote.security.url git@gitlab.com:gitlab-org/security/gitlab.git",
          "branch.pedropombeiro/111/public-fix.remote origin",
          "branch.security-fix-cve.remote security",
        ].join("\n");
      }
      return activeBranch;
    };

    const plugin = createPlugin({
      git: gitWithSecurityBranch,
      glab: defaultGlab,
    });
    await plugin.setup(harness.ctx);

    // 1. Public branch stays on Vertex.
    await harness.emitSession("prompt", {
      sessionID: "ses_branch",
      prompt: { text: "Check status" },
    });
    expect(harness.switched).toEqual([]);

    // 2. Immediate branch switch to security-tracking branch does not reuse public cache.
    activeBranch = "security-fix-cve";
    await harness.emitSession("prompt", {
      sessionID: "ses_branch",
      prompt: { text: "Check status on new branch" },
    });
    expect(harness.switched).toEqual([
      { sessionID: "ses_branch", model: DUO_MODELS.plan },
    ]);

    // 3. Storage read failure refuses upstream dispatch rather than failing open.
    const brokenStorageHarness = createMockContext({
      sessions: {
        ses_broken: {
          id: "ses_broken",
          agent: "plan",
          model: VERTEX_PLAN,
          location: { directory: "/gdk/gitlab" },
        },
      },
    });
    brokenStorageHarness.ctx.storage.get = async () => {
      throw new Error("disk I/O error");
    };
    const brokenPlugin = createPlugin({ git: defaultGit, glab: defaultGlab });
    await brokenPlugin.setup(brokenStorageHarness.ctx);

    await expect(
      brokenStorageHarness.emitSession("context", {
        sessionID: "ses_broken",
        agent: "plan",
        model: VERTEX_PLAN,
        messages: [],
        system: [],
      }),
    ).rejects.toThrow(/session lock storage could not be read/);

    // 4. Storage write failure rejects confidential tool calls (even on Duo) and
    // still redacts upstream confidential tool output before surfacing the error.
    const writeFailHarness = createMockContext({
      sessions: {
        ses_duo_write_fail: {
          id: "ses_duo_write_fail",
          agent: "plan",
          model: DUO_MODELS.plan,
          location: { directory: "/gdk/gitlab" },
        },
        ses_vertex_write_fail: {
          id: "ses_vertex_write_fail",
          agent: "build",
          model: VERTEX_BUILD,
          location: { directory: "/gdk/gitlab" },
        },
      },
    });
    writeFailHarness.ctx.storage.set = async () => {
      throw new Error("readonly database");
    };
    const writeFailPlugin = createPlugin({
      git: defaultGit,
      glab: defaultGlab,
    });
    await writeFailPlugin.setup(writeFailHarness.ctx);

    await expect(
      writeFailHarness.emitTool("execute.before", {
        sessionID: "ses_duo_write_fail",
        agent: "plan",
        tool: "gitlab_get_work_item_notes",
        input: { project_id: "gitlab-org/gitlab", work_item_id: 555 },
      }),
    ).rejects.toThrow(/readonly database/);

    const leakAttempt: any = {
      sessionID: "ses_vertex_write_fail",
      agent: "build",
      tool: "gitlab_get_issue",
      input: { project_id: "gitlab-org/gitlab", issue_iid: 555 },
      status: "completed",
      result: {
        content: [
          {
            type: "text",
            text: '{"iid": 555, "confidential": true, "body": "MUST REDACT"}',
          },
        ],
      },
    };
    await expect(
      writeFailHarness.emitTool("execute.after", leakAttempt),
    ).rejects.toThrow(/readonly database/);
    expect(leakAttempt.result.content[0].text).not.toContain("MUST REDACT");
  });
});
