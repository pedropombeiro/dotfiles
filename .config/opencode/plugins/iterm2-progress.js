const isIterm2 =
  process.env.TERM_PROGRAM === "iTerm.app" ||
  process.env.LC_TERMINAL === "iTerm2" ||
  !!process.env.ITERM_SESSION_ID;

function osc(payload) {
  if (!isIterm2) return;
  const esc = process.env.TMUX
    ? `\x1bPtmux;\x1b\x1b]${payload}\x07\x1b\\`
    : `\x1b]${payload}\x07`;
  process.stdout.write(esc);
}

function progress(code) {
  osc(`9;4;${code}`);
}

export const Iterm2Progress = async () => {
  return {
    event: async ({ event }) => {
      if (event.type === "session.status") {
        const { status } = event.properties;
        if (status.type === "busy") {
          progress("3");
        } else if (status.type === "idle") {
          progress("0");
        }
      } else if (event.type === "session.error") {
        progress("2");
      } else if (event.type === "permission.asked") {
        progress("4;50");
      }
    },
    "tool.execute.before": async (input) => {
      if (input.tool === "question") {
        progress("4;50");
      }
    },
  };
};
