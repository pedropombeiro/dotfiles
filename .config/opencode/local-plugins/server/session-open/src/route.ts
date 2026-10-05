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
