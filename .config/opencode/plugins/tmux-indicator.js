// @bun
// packages/tmux-indicator/src/index.ts
import { writeFileSync } from "fs";
import { randomUUID } from "crypto";

// packages/_shared/src/events.ts
function readRequestId(properties) {
  const requestID = properties["requestID"];
  if (typeof requestID === "string")
    return requestID;
  const permissionID = properties["permissionID"];
  return typeof permissionID === "string" ? permissionID : undefined;
}
function questionDetail(args) {
  const questions = Array.isArray(args?.questions) ? args.questions.filter((question) => typeof question === "object" && question !== null).filter((question) => typeof question["header"] === "string" || typeof question["question"] === "string").map((question) => ({
    header: typeof question["header"] === "string" ? question["header"] : "",
    question: typeof question["question"] === "string" ? question["question"] : "",
    options: Array.isArray(question["options"]) ? question["options"].filter((option) => typeof option === "object" && option !== null).filter((option) => typeof option["label"] === "string").map((option) => ({
      label: option["label"],
      description: typeof option["description"] === "string" ? option["description"] : undefined
    })) : [],
    multiple: typeof question["multiple"] === "boolean" ? question["multiple"] : undefined
  })) : undefined;
  return { reason: "question", title: questions?.[0]?.header, questions };
}

// packages/_shared/src/agent-state.ts
function createAgentStateTracker(options) {
  const states = new Map;
  const waits = new Map;
  async function setState(sessionID, state) {
    if (state === "busy" && hasWait(sessionID))
      return;
    if (states.get(sessionID) === state)
      return;
    states.set(sessionID, state);
    if (state === "waiting")
      return;
    if (state === "busy")
      await options.onBusy?.(sessionID);
    if (state === "idle")
      await options.onIdle?.(sessionID);
    if (state === "error")
      await options.onError?.(sessionID);
  }
  function isActive(sessionID) {
    return states.has(sessionID);
  }
  function hasWait(sessionID) {
    return [...waits.values()].some((waitingSessionID) => waitingSessionID === sessionID);
  }
  async function wait(sessionID, id, detail) {
    if (!isActive(sessionID) || waits.has(id))
      return;
    waits.set(id, sessionID);
    const wasWaiting = states.get(sessionID) === "waiting";
    states.set(sessionID, "waiting");
    if (!wasWaiting)
      await options.onWaiting?.(sessionID, detail);
  }
  async function resume(sessionID, id) {
    if (waits.get(id) !== sessionID)
      return;
    waits.delete(id);
    if (!hasWait(sessionID) && isActive(sessionID))
      await setState(sessionID, "busy");
  }
  function replaceWait(sessionID, oldId, newId) {
    if (waits.get(oldId) !== sessionID || waits.has(newId))
      return false;
    waits.delete(oldId);
    waits.set(newId, sessionID);
    return true;
  }
  async function event(input) {
    const { event: event2 } = input;
    if (event2.type === "session.status") {
      const { sessionID, status } = event2.properties;
      if (status.type === "busy")
        await setState(sessionID, "busy");
      if (status.type === "idle") {
        waits.forEach((waitingSessionID, id) => {
          if (waitingSessionID === sessionID)
            waits.delete(id);
        });
        if (isActive(sessionID))
          await setState(sessionID, "idle");
        states.delete(sessionID);
      }
      return;
    }
    if (event2.type === "session.idle" || event2.type === "session.error") {
      const sessionID = event2.properties?.["sessionID"];
      if (typeof sessionID !== "string" || !isActive(sessionID))
        return;
      waits.forEach((waitingSessionID, id) => {
        if (waitingSessionID === sessionID)
          waits.delete(id);
      });
      await setState(sessionID, event2.type === "session.idle" ? "idle" : "error");
      states.delete(sessionID);
      return;
    }
    if (event2.type === "permission.asked") {
      const props = event2.properties;
      await wait(props.sessionID, props.id, {
        reason: "permission",
        id: props.id,
        type: props.permission,
        title: props.patterns?.[0] ? `${props.permission}: ${props.patterns[0]}` : props.permission,
        pattern: props.patterns
      });
      return;
    }
    if (event2.type === "question.asked") {
      const props = event2.properties;
      if (props.tool && replaceWait(props.sessionID, `tool:${props.tool.callID}`, props.id))
        return;
      await wait(props.sessionID, props.id, {
        reason: "question",
        id: props.id,
        title: props.questions?.[0]?.header,
        questions: props.questions
      });
      return;
    }
    if (event2.type === "permission.replied") {
      const props = event2.properties;
      const id = readRequestId(props);
      if (id)
        await resume(props.sessionID, id);
      return;
    }
    if (event2.type === "question.replied" || event2.type === "question.rejected") {
      const props = event2.properties;
      await resume(props.sessionID, props.requestID);
    }
  }
  async function toolExecuteBefore(input, output) {
    if (options.handleToolQuestions !== false && input.tool === "question") {
      await wait(input.sessionID, `tool:${input.callID}`, questionDetail(output.args));
    }
  }
  async function toolExecuteAfter(input) {
    if (options.handleToolQuestions !== false && input.tool === "question") {
      await resume(input.sessionID, `tool:${input.callID}`);
    }
  }
  return { event, toolExecuteBefore, toolExecuteAfter };
}
// packages/tmux-indicator/src/navigation.ts
import { once } from "events";
import { mkdtempSync, rmSync } from "fs";
import { createServer } from "http";
import { tmpdir } from "os";
import { join } from "path";
async function createNavigation(client, directory, waiting) {
  const folder = mkdtempSync(join(tmpdir(), "oc-tmux-"));
  const socket = join(folder, "s");
  const tui = client.tui;
  const server = createServer(async (request, response) => {
    response.setHeader("Content-Type", "application/json");
    if (request.method === "GET" && request.url === "/waiting") {
      response.end(JSON.stringify([...waiting].sort()));
      return;
    }
    const sessionID = request.url?.match(/^\/select\/(ses[a-zA-Z0-9_-]+)$/)?.[1];
    if (request.method !== "POST" || !sessionID || !waiting.has(sessionID)) {
      response.writeHead(404).end("false");
      return;
    }
    try {
      const result = await tui.publish({
        body: { type: "tui.session.select", properties: { sessionID } },
        query: { directory },
        throwOnError: true,
        signal: AbortSignal.timeout(3000)
      });
      response.writeHead(result.data === true ? 200 : 502).end(JSON.stringify(result.data === true));
    } catch {
      response.writeHead(502).end("false");
    }
  });
  const cleanup = () => rmSync(folder, { recursive: true, force: true });
  try {
    server.listen(socket);
    await once(server, "listening");
  } catch (error) {
    cleanup();
    throw error;
  }
  server.unref();
  process.once("exit", cleanup);
  return {
    socket,
    close: async () => {
      const closed = once(server, "close");
      server.close();
      server.closeAllConnections();
      await closed;
      process.off("exit", cleanup);
      cleanup();
    }
  };
}

// packages/tmux-indicator/src/index.ts
var TmuxIndicatorPlugin = async ({ $, client, directory }) => {
  const tmux = process.env["TMUX"];
  if (!tmux)
    return {};
  const tmuxPane = process.env["TMUX_PANE"];
  if (!tmuxPane)
    return {};
  const waiting = new Set;
  const navigation = await createNavigation(client, directory, waiting);
  const option = `@opencode-waiting-target-${randomUUID()}`;
  let startupGrace = true;
  let disposed = false;
  let pending = Promise.resolve();
  const enqueue = (action) => {
    const next = pending.then(action);
    pending = next.catch(() => {});
    return next;
  };
  const refreshWindow = async () => {
    const panes = (await $`tmux list-panes -t ${tmuxPane} -F '#{pane_id}'`.quiet().text()).trim().split(`
`);
    const options = await Promise.all(panes.map((pane) => $`tmux show-options -p -t ${pane}`.quiet().text()));
    if (options.some((value) => /^@opencode-waiting-target-/m.test(value))) {
      await $`tmux set-option -w -t ${tmuxPane} @opencode-waiting 1`.quiet();
    } else {
      await $`tmux set-option -w -u -t ${tmuxPane} @opencode-waiting`.nothrow().quiet();
    }
  };
  const publish = async () => {
    if (startupGrace || disposed)
      return;
    if (waiting.size) {
      await $`tmux set-option -p -t ${tmuxPane} ${option} ${navigation.socket}`.quiet();
    } else {
      await $`tmux set-option -p -u -t ${tmuxPane} ${option}`.nothrow().quiet();
    }
    await refreshWindow();
  };
  const ring = async () => {
    const tty = (await $`tmux display-message -t ${tmuxPane} -p '#{pane_tty}'`.quiet().text()).trim();
    if (tty) {
      try {
        writeFileSync(tty, "\x07");
      } catch {
        return;
      }
    }
  };
  const activate = async (sessionID) => {
    waiting.add(sessionID);
    await publish();
    if (!startupGrace && !disposed)
      await ring();
  };
  const deactivate = async (sessionID) => {
    if (waiting.delete(sessionID))
      await publish();
  };
  const timer = setTimeout(() => {
    enqueue(async () => {
      startupGrace = false;
      if (!waiting.size || disposed)
        return;
      await publish();
      await ring();
    }).catch(() => {});
  }, 3000);
  timer.unref();
  const tracker = createAgentStateTracker({
    onWaiting: activate,
    onBusy: deactivate,
    onIdle: deactivate,
    onError: deactivate
  });
  return {
    event: (input) => enqueue(() => tracker.event(input)),
    "tool.execute.before": (input, output) => enqueue(() => tracker.toolExecuteBefore(input, output)),
    "tool.execute.after": (input) => enqueue(() => tracker.toolExecuteAfter(input)),
    dispose: async () => {
      disposed = true;
      clearTimeout(timer);
      await pending;
      await navigation.close();
      await $`tmux set-option -p -u -t ${tmuxPane} ${option}`.nothrow().quiet();
      await refreshWindow();
    }
  };
};
export {
  TmuxIndicatorPlugin
};
