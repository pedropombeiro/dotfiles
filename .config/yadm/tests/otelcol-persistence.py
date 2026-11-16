"""Exercise the real collector with an isolated, initially unavailable backend.

Usage: mise exec -- python3 ~/.config/yadm/tests/otelcol-persistence.py
No requests leave localhost. Requires the mise-managed otelcol-contrib binary.
"""

import http.server
import json
import os
import shutil
import socket
import subprocess
import tempfile
import threading
import time
import urllib.request
from pathlib import Path
from typing import ClassVar


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def wait_for(check, label):
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        try:
            if check():
                return
        except (OSError, urllib.error.URLError):
            pass
        time.sleep(0.1)
    raise AssertionError(label)


class Backend(http.server.BaseHTTPRequestHandler):
    received: ClassVar[list] = []

    def do_POST(self):
        body = self.rfile.read(int(self.headers["Content-Length"]))
        self.received.append((self.path, self.headers.get("Authorization"), body))
        self.send_response(200)
        self.send_header("Content-Type", "application/x-protobuf")
        self.end_headers()

    def log_message(self, *_):
        pass


def main():
    binary = shutil.which("otelcol-contrib")
    assert binary, "Run through mise exec with otelcol-contrib installed"
    config_path = Path(__file__).resolve().parents[2] / "otelcol/config.yaml"
    receiver, health, metrics, remote = (free_port() for _ in range(4))
    with tempfile.TemporaryDirectory(prefix="otelcol-persistence-") as temp:
        root = Path(temp)
        config = config_path.read_text()
        for before, after in (
            ("127.0.0.1:4318", f"127.0.0.1:{receiver}"),
            ("127.0.0.1:13133", f"127.0.0.1:{health}"),
            ("port: 8888", f"port: {metrics}"),
            ("https://otel.pombei.ro", f"http://127.0.0.1:{remote}"),
            ("initial_interval: 5s", "initial_interval: 100ms"),
            ("max_interval: 60s", "max_interval: 200ms"),
        ):
            config = config.replace(before, after)
        (root / "config.yaml").write_text(config)
        env = dict(
            os.environ,
            OTELCOL_STORAGE_DIR=str(root / "queue"),
            OTELCOL_AUTHORIZATION="Basic dGVzdDpwYXNz",
        )
        process = None
        backend = None
        with (root / "collector.log").open("w+") as log:

            def start():
                return subprocess.Popen(
                    [binary, "--config", str(root / "config.yaml")],
                    env=env,
                    stdout=log,
                    stderr=log,
                )

            def ready():
                return (
                    urllib.request.urlopen(
                        f"http://127.0.0.1:{health}", timeout=1
                    ).status
                    == 200
                )

            try:
                process = start()
                wait_for(ready, "collector failed to start")
                now = str(time.time_ns())
                payloads = {
                    "metrics": {
                        "resourceMetrics": [
                            {
                                "scopeMetrics": [
                                    {
                                        "metrics": [
                                            {
                                                "name": "relay.persistence.test",
                                                "gauge": {
                                                    "dataPoints": [
                                                        {
                                                            "timeUnixNano": now,
                                                            "asInt": "1",
                                                        }
                                                    ]
                                                },
                                            }
                                        ]
                                    }
                                ]
                            }
                        ]
                    },
                    "logs": {
                        "resourceLogs": [
                            {
                                "scopeLogs": [
                                    {
                                        "logRecords": [
                                            {
                                                "timeUnixNano": now,
                                                "body": {
                                                    "stringValue": "relay-persistence-test"
                                                },
                                            }
                                        ]
                                    }
                                ]
                            }
                        ]
                    },
                    "traces": {
                        "resourceSpans": [
                            {
                                "scopeSpans": [
                                    {
                                        "spans": [
                                            {
                                                "traceId": "01010101010101010101010101010101",
                                                "spanId": "0202020202020202",
                                                "name": "relay-persistence-test",
                                                "startTimeUnixNano": now,
                                                "endTimeUnixNano": str(int(now) + 1000),
                                            }
                                        ]
                                    }
                                ]
                            }
                        ]
                    },
                }
                for signal, payload in payloads.items():
                    request = urllib.request.Request(
                        f"http://127.0.0.1:{receiver}/v1/{signal}",
                        data=json.dumps(payload).encode(),
                        headers={"Content-Type": "application/json"},
                    )
                    assert urllib.request.urlopen(request, timeout=5).status == 200
                assert len(list((root / "queue").glob("exporter*"))) == 3
                process.kill()  # Abrupt crash, not a graceful flush.
                process.wait(timeout=10)
                process = start()
                wait_for(ready, "collector failed to restart with its stored queues")
                backend = http.server.ThreadingHTTPServer(
                    ("127.0.0.1", remote), Backend
                )
                threading.Thread(target=backend.serve_forever, daemon=True).start()
                wait_for(
                    lambda: len({p for p, _, _ in Backend.received}) == 3,
                    "persisted telemetry did not reach the recovered backend",
                )
                for path, auth, body in Backend.received:
                    assert auth == "Basic dGVzdDpwYXNz", path
                    assert body, path
                print(
                    "PASS: metrics, logs, and traces persisted through SIGKILL and forwarded after recovery"
                )
            except BaseException:
                log.flush()
                print((root / "collector.log").read_text())
                raise
            finally:
                if process and process.poll() is None:
                    process.terminate()
                    process.wait(timeout=15)
                if backend:
                    backend.shutdown()


if __name__ == "__main__":
    main()
