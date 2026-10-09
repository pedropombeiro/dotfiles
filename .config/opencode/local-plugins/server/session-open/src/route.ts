import type { OpenAction, OpenRequest } from "./rpc"

export type Route = { readonly type: string; readonly sessionID?: string }

// Only the terminal that shows the requesting session acts, so other open
// terminals keep their view.
export function showsSource(route: Route, request: Pick<OpenRequest, "sourceSessionIDs">): boolean {
  return route.type === "session" && route.sessionID !== undefined && request.sourceSessionIDs.includes(route.sessionID)
}

// Tabs hold root sessions only, so a child session opens through the router.
export function openAction(tabsEnabled: boolean, request: Pick<OpenRequest, "root">): OpenAction {
  return tabsEnabled && request.root ? "tab" : "route"
}

export interface SessionUI {
  router: {
    current(): Route
    navigate(route: { type: "session"; sessionID: string }): void
  }
  tabs: {
    enabled(): boolean
    focus(sessionID: string): void
    close(sessionID: string): void
  }
}

// Capture the source before navigation. Never close a tab that also owns the
// destination, and keep the source open if navigation did not reach the target.
export function openRequested(ui: SessionUI, request: OpenRequest): OpenAction | undefined {
  if (!showsSource(ui.router.current(), request)) return
  const tabsEnabled = ui.tabs.enabled()
  const action = openAction(tabsEnabled, request)
  if (action === "tab") ui.tabs.focus(request.sessionID)
  else ui.router.navigate({ type: "session", sessionID: request.sessionID })

  const current = ui.router.current()
  if (current.type !== "session" || current.sessionID !== request.sessionID) return

  const sourceRootID = request.sourceSessionIDs[request.sourceSessionIDs.length - 1]
  if (request.closeSource && tabsEnabled && sourceRootID && sourceRootID !== request.rootSessionID)
    ui.tabs.close(sourceRootID)
  return action
}
