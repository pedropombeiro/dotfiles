// Blocks access to credential files and redacts secrets from tool output and replayed
// history. The logic lives in ../lib/env-protection/guards.mjs, outside the plugin
// discovery path, so it can be tested on its own (see guards.test.mjs there).
import { createGuards, redactStructuredSecretsDeep, textParts, warningFor } from "../lib/env-protection/guards.mjs";

const SHELL_ENV_OVERRIDES = {
  MANPAGER: undefined,
  VIMPAGER_VIM: undefined,
  EDITOR: "cat",
  VISUAL: "cat",
  GIT_EDITOR: "cat",
};

const applyProcessEnvOverrides = () => {
  for (const [key, value] of Object.entries(SHELL_ENV_OVERRIDES)) {
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
};

export default {
  id: "env-protection",
  async setup(ctx) {
    applyProcessEnvOverrides();
    const guards = createGuards({
      directory: ctx.location.directory,
      worktree: ctx.location.project.directory,
    });

    await ctx.shell.hook("create.before", (event) => {
      Object.assign(event.env, SHELL_ENV_OVERRIDES);
    });

    await ctx.tool.hook("execute.before", (event) => {
      const args = event.input || {};
      guards.checkToolCall({
        tool: event.tool,
        filePath: args.path ?? args.filePath,
        args,
      });
    });

    await ctx.tool.hook("execute.after", (event) => {
      if (event.status !== "completed" || !event.result) return;
      try {
        const extra =
          event.tool === "shell" ? guards.commandIndex(event.input?.command, event.input?.workdir) : undefined;
        const result = event.result;
        let count = 0;

        for (const part of textParts(result)) {
          const redacted = guards.redactText(part.text, extra);
          part.text = redacted.text;
          count += redacted.count;
        }

        for (const key of ["output", "metadata"]) {
          if (result[key] !== undefined) result[key] = guards.redactValue(result[key], extra).value;
        }

        if (count > 0) {
          const [first] = textParts(result);
          if (first) first.text = warningFor(count) + first.text;
          else result.content = [{ type: "text", text: warningFor(count) }, ...(result.content ?? [])];
        }
        event.result = result;
      } catch {
        // A redaction failure must never prevent the command from completing.
      }
    });

    // Scrubs replayed history too, so a value that leaked before a file was protected
    // isn't sent again.
    const redactRequest = (event) => {
      if (!Array.isArray(event.messages)) return;
      try {
        guards.redactValue(event.messages);
      } catch {
        redactStructuredSecretsDeep(event.messages);
      }
    };
    for (const name of ["context", "compaction", "generate", "title"]) {
      await ctx.session.hook(name, redactRequest);
    }
  },
};
