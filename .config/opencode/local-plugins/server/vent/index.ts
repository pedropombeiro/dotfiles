import type { Plugin } from '@opencode/plugin';
import { exec } from './src/exec.ts';
import { resolveOptions } from './src/options.ts';
import {
  executeVent,
  formatVentResult,
  VENT_DESCRIPTION,
  VENT_GUIDANCE,
  VENT_TOOL_NAME,
  ventInputSchema,
} from './src/tool.ts';

export { resolveOptions, selectDestination } from './src/options.ts';
export { executeVent, formatVentResult, parseVentInput } from './src/tool.ts';

export default {
  id: 'opencode-vent',
  async setup(ctx) {
    const options = resolveOptions(ctx.options);
    if (Object.keys(options.destinations).length === 0) {
      return;
    }

    async function ownsSession(sessionID: string): Promise<boolean> {
      const session = await ctx.session.get({ sessionID });
      return session.location.directory === ctx.location.directory;
    }

    const tools = await ctx.tool.transform((editor) => {
      editor.add({
        name: VENT_TOOL_NAME,
        options: { codemode: false },
        description: VENT_DESCRIPTION,
        input: ventInputSchema,
        execute: async (input, { sessionID, signal }) => {
          const session = await ctx.session.get({ sessionID });
          const directory = session.location.directory;

          let branch: string | undefined;
          try {
            const vcs = await ctx.vcs.get({ location: session.location });
            branch = vcs.data?.branch?.current || undefined;
          } catch {
            branch = undefined;
          }

          const result = await executeVent(input, options, {
            sessionID,
            directory,
            branch,
            exec,
            signal,
          });
          return { content: formatVentResult(result) };
        },
      });
    });

    await ctx.session.hook('context', async (event) => {
      try {
        if (!(await ownsSession(event.sessionID))) return;
        event.system.push({ type: 'text', text: VENT_GUIDANCE });
      } catch {
        return;
      }
    });

    return async () => {
      await tools.dispose();
    };
  },
} satisfies Plugin.Plugin;
