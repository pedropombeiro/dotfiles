// Reports whether the OTLP collector accepts requests over the exporter's
// protocol: an empty metrics export for HTTP, or a TCP connect for gRPC. The
// probe runs in the background service, the process that exports telemetry, so it sees
// the exporter's network access. opencode.json loads this directory through a
// path entry with the endpoint as an option; the parent directory is outside
// OpenCode's plugin discovery paths. OpenCode then loads tui.tsx in the CLI.
import type { Plugin } from "@opencode/plugin"
import { acquireMonitor, type MonitorOptions } from "./src/monitor"
import { PROTOCOLS, type Protocol } from "./src/probe"
import { OtelStatusRpc } from "./src/rpc"

export interface Options {
  endpoint?: string
  protocol?: string
  intervalSeconds?: number
  timeoutSeconds?: number
}

const DEFAULT_INTERVAL_SECONDS = 60
const DEFAULT_TIMEOUT_SECONDS = 5

function pickProtocol(value: unknown): Protocol | undefined {
  return PROTOCOLS.find((protocol) => protocol === value)
}

function positive(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isFinite(value) && value > 0 ? value : fallback
}

export function resolveOptions(
  options: Options,
  env: Record<string, string | undefined> = process.env,
): MonitorOptions {
  const endpoint =
    (typeof options.endpoint === "string" && options.endpoint.trim()) ||
    env["OPENCODE_OTLP_ENDPOINT"]?.trim() ||
    env["OTEL_EXPORTER_OTLP_ENDPOINT"]?.trim() ||
    undefined
  // Same precedence and default as the exporter.
  const protocol = pickProtocol(options.protocol) ?? pickProtocol(env["OPENCODE_OTLP_PROTOCOL"]?.trim()) ?? "grpc"
  const intervalMs = positive(options.intervalSeconds, DEFAULT_INTERVAL_SECONDS) * 1000
  const timeoutMs = Math.min(positive(options.timeoutSeconds, DEFAULT_TIMEOUT_SECONDS) * 1000, intervalMs)
  return { endpoint, protocol, intervalMs, timeoutMs }
}

export default {
  id: "pedropombeiro.otel-status",
  async setup(ctx) {
    // OpenCode runs one plugin instance per location; they share one probe.
    const lease = acquireMonitor(resolveOptions(ctx.options as Options))
    const { monitor } = lease
    const rpc = await ctx.rpc.register(OtelStatusRpc, {
      status: async () => monitor.snapshot(),
      check: async () => monitor.check(),
    })
    const unsubscribe = monitor.subscribe((status) => {
      void rpc.events.emit("changed", status).catch(() => {})
    })
    return async () => {
      unsubscribe()
      lease.release()
      await rpc.dispose()
    }
  },
} satisfies Plugin.Plugin
