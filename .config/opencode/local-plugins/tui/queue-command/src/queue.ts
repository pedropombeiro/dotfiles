export type Route = { type: string; sessionID?: string }

export type PromptRequest = {
  sessionID: string
  text: string
  delivery: "queue"
  resume: true
}

// Shape returned by `context.ui.model.current()`.
export type SelectedModel = { providerID: string; modelID: string; variant?: string }

export type SwitchModelRequest = {
  sessionID: string
  model: { providerID: string; id: string; variant?: string }
}

export type SessionApi = {
  prompt: (request: PromptRequest) => Promise<unknown>
  switchModel: (request: SwitchModelRequest) => Promise<unknown>
}

export type Toast = { title?: string; message: string; variant: "info" | "success" | "warning" | "error" }

const PREVIEW_LENGTH = 60

export function preview(text: string) {
  const line = text.replace(/\s+/g, " ").trim()
  return line.length > PREVIEW_LENGTH ? `${line.slice(0, PREVIEW_LENGTH - 1)}…` : line
}

// Queues the text in the displayed session. `resume` starts an idle session
// right away; a busy session runs the message after its current turn.
// Like the built-in composer, it first switches the session to the model
// selected in the prompt, so a model picked just before `/queue` applies.
export async function queueMessage(
  input: string | undefined,
  route: Route,
  session: SessionApi,
  model?: SelectedModel,
): Promise<Toast> {
  const text = input?.trim() ?? ""
  if (!text) return { message: "Usage: /queue <message>", variant: "warning" }
  if (route.type !== "session" || !route.sessionID) {
    return { message: "Open a session before queueing a message", variant: "warning" }
  }
  const sessionID = route.sessionID
  try {
    if (model) {
      await session.switchModel({
        sessionID,
        model: { providerID: model.providerID, id: model.modelID, variant: model.variant },
      })
    }
    await session.prompt({ sessionID, text, delivery: "queue", resume: true })
    return { title: "Message queued", message: preview(text), variant: "success" }
  } catch (error) {
    const reason = error instanceof Error ? error.message : String(error)
    return { message: `Could not queue the message: ${reason}`, variant: "error" }
  }
}
