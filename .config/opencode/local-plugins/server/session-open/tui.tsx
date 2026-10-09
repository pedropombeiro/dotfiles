// OpenCode loads this CLI entry point automatically because the server entry
// point in index.ts is configured in opencode.json. It opens the session that
// the `open_session` tool requests, but only in the terminal that shows the
// requesting session, and acknowledges so the tool can report the result.
import { Plugin } from "@opencode/plugin/tui"
import { openRequested } from "./src/route"
import { SessionOpenRpc, type OpenRequest } from "./src/rpc"

export default Plugin.define({
  id: "pedropombeiro.session-open-cli",
  setup(context) {
    const rpc = context.client.rpc(SessionOpenRpc)

    return rpc.events.on("requested", (event) => {
      const request = event.data as unknown as OpenRequest
      const action = openRequested(context.ui, request)
      if (!action) return

      const location = event.location ?? context.location ?? context.data.location.default()
      void rpc.handled({ requestID: request.requestID, action }, { location }).catch(() => {})
    })
  },
})
