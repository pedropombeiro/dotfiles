import { describe, expect, test } from "bun:test";
import {
  createPlugin,
  isIssueRequest,
  parseWorkItemURL,
  withForgePrefix,
} from "./index.ts";

const issue = "https://gitlab.com/group/nested/project/-/issues/123";
const mr = "https://gitlab.com/group/project/-/merge_requests/71";

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

describe("isIssueRequest", () => {
  test.each([
    `Address ${issue}`,
    `Please fix ${issue}`,
    `Can you implement ${issue}`,
    `Work on ${issue}`,
    `Create a draft MR for ${issue}`,
    `Open an MR to resolve ${issue}`,
  ])("accepts %p", (text) => expect(isIssueRequest(text)).toBe(true));

  test.each([
    `Summarize ${issue}`,
    `What does ${issue} ask for?`,
    `Review ${mr}`,
    `This fixes ${issue}`,
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

function setup(responses: Record<string, unknown>, sessionTitle = "Old title") {
  const calls: string[][] = [];
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
  const ctx = {
    tool: {
      transform: (fn: any) =>
        fn({ add: (tool: any) => (tools[tool.name] = tool) }),
    },
    session: {
      hook: (_kind: string, fn: typeof hook) => (hook = fn),
      get: async () => ({ title: sessionTitle }),
      update: async (input: any) => void updates.push(input),
    },
  };
  return {
    calls,
    updates,
    tools,
    ready: createPlugin(glab).setup(ctx as any),
    title: async (content: unknown, result?: string) => {
      const event = {
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

  test("adds the MR author for review requests", async () => {
    const plugin = setup({
      "projects/group%2Fproject/merge_requests/71": {
        author: { username: "jdoe" },
      },
    });
    await plugin.ready;
    const event = await plugin.title(`Review ${mr}`);
    expect(event.result).toBeUndefined();
    expect(event.system[0].text).toContain(
      `The GitLab author of ${mr} is @jdoe.`,
    );
  });
});

describe("rename tools", () => {
  test("renames a session after an issue and keeps the Forgekeeper prefix", async () => {
    const plugin = setup(
      {
        "fullPath=group/nested/project#iid=123": workItem(
          "Fix factory defaults",
        ),
      },
      "[#123, !456] Old title",
    );
    await plugin.ready;
    const output = await plugin.tools.rename_issue_session.execute(
      { url: issue },
      context,
    );
    expect(output.content).toBe(
      "Session title: [#123, !456] Fix factory defaults",
    );
    expect(plugin.updates).toEqual([
      { sessionID: "ses_test", title: "[#123, !456] Fix factory defaults" },
    ]);
  });

  test("rejects issue URLs embedded in other text", async () => {
    const plugin = setup({});
    await plugin.ready;
    const output = await plugin.tools.rename_issue_session.execute(
      { url: `see ${issue}` },
      context,
    );
    expect(output.content).toStartWith("No title changed.");
    expect(plugin.updates).toHaveLength(0);
  });

  test("renames a review session with the MR author", async () => {
    const plugin = setup(
      {
        "projects/group%2Fproject/merge_requests/71": {
          author: { username: "jdoe" },
        },
      },
      "[!71] Old title",
    );
    await plugin.ready;
    await plugin.tools.rename_mr_review_session.execute(
      { url: mr, topic: "factory defaults !71" },
      context,
    );
    expect(plugin.updates).toEqual([
      { sessionID: "ses_test", title: "[!71] @jdoe - Review factory defaults" },
    ]);
  });
});
