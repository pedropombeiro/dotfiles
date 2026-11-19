export function publisher(run: (args: string[]) => Promise<unknown>, pane: string, refresh: () => Promise<unknown>) {
  let pending = Promise.resolve()
  let previous: string | undefined
  let initialized = false
  let disposed = false
  const enqueue = (title?: string) => {
    pending = pending.catch(() => {}).then(async () => {
      await run(title === undefined
        ? ["set-option", "-p", "-u", "-t", pane, "@opencode-full-title"]
        : ["set-option", "-p", "-t", pane, "@opencode-full-title", title])
      await refresh()
    })
    return pending
  }
  return {
    update(title?: string) {
      if (disposed || (initialized && title === previous)) return
      initialized = true
      previous = title
      void enqueue(title).catch(() => { initialized = false })
    },
    close() {
      disposed = true
      return enqueue().catch(() => {})
    },
  }
}
