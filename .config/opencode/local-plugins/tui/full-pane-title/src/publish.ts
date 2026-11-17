import type { Attention } from "./attention"

export function publisher(run: (args: string[]) => Promise<unknown>, pane: string, refresh: () => Promise<unknown>) {
  let pending = Promise.resolve()
  let previous: string | undefined
  let previousAttention: Attention
  let initialized = false
  let disposed = false
  const enqueue = (title?: string, attention?: Attention) => {
    pending = pending.catch(() => {}).then(async () => {
      await run(title === undefined
        ? ["set-option", "-p", "-u", "-t", pane, "@opencode-full-title"]
        : ["set-option", "-p", "-t", pane, "@opencode-full-title", title])
      await run(attention === undefined
        ? ["set-option", "-p", "-u", "-t", pane, "@opencode-attention"]
        : ["set-option", "-p", "-t", pane, "@opencode-attention", attention])
      await refresh()
    })
    return pending
  }
  return {
    update(title?: string, attention?: Attention) {
      if (disposed || (initialized && title === previous && attention === previousAttention)) return
      initialized = true
      previous = title
      previousAttention = attention
      void enqueue(title, attention).catch(() => { initialized = false })
    },
    close() {
      disposed = true
      return enqueue().catch(() => {})
    },
  }
}
