# otel-status

A server plugin that checks whether the OpenTelemetry collector accepts OTLP requests and
shows the result in the CLI footer.

## Behavior

The background service sends an empty OTLP metrics export at a fixed interval. The
footer shows the result as `● 🔭`:

| Dot | Meaning |
|---|---|
| Green | The collector accepted the request. |
| Red | The request failed or was rejected. |
| Yellow | The service has no `host.name` in `OPENCODE_RESOURCE_ATTRIBUTES`. A warning toast also appears once per terminal session. |

`/otel` runs a check and shows the host name or the warning, plus the last error. It's
also in the command palette.

An accepted empty request doesn't prove that real exports succeed.

The probe sends the headers from `OPENCODE_OTLP_HEADERS`, parsed the same way as the
exporter, and keeps them out of the status, RPC responses, and `/otel`.

## Options

The `endpoint` and `protocol` options must match the exporter's in both `opencode.json`
alternates.

| Option | Default | Description |
|---|---|---|
| `endpoint` | `OPENCODE_OTLP_ENDPOINT`, then `OTEL_EXPORTER_OTLP_ENDPOINT` | Collector URL. |
| `protocol` | `OPENCODE_OTLP_PROTOCOL`, then `grpc` | `grpc`, `http/protobuf`, or `http/json`, as for the exporter. |
| `intervalSeconds` | `60` | Time between checks. |
| `timeoutSeconds` | `5` | Request timeout, capped at the interval. |

For the host name, NAS access from tmux, and credentials, see
[Telemetry](../../../../../.agents/docs/opencode.md#telemetry).

## Tests

Run the tests from this directory:

```sh
mise exec bun@1.3.10 -- bun test
```

For how local plugins load and the rules for editing them, see
[Explicitly loaded plugin directories](../../../../../.agents/docs/opencode.md#explicitly-loaded-plugin-directories).
