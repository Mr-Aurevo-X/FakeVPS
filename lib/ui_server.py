#!/usr/bin/env python3
"""Localhost cockpit for FakeVPS (127.0.0.1 only)."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(os.environ["FAKEVPS_ROOT"])
UI = ROOT / "ui"
BIN = ROOT / "fakevps"


def run_fakevps(*args: str) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["FAKEVPS_SKIP_UI"] = "1"
    return subprocess.run(
        [str(BIN), *args],
        cwd=str(ROOT),
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(UI), **kwargs)

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("[ui] " + (fmt % args) + "\n")

    def _json(self, code: int, payload: object) -> None:
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if path == "/api/status":
            proc = run_fakevps("status", "--json")
            if proc.returncode != 0:
                self._json(500, {"error": proc.stderr.strip() or "status failed"})
                return
            try:
                self._json(200, json.loads(proc.stdout))
            except json.JSONDecodeError:
                self._json(500, {"error": "invalid status json", "raw": proc.stdout})
            return
        if path == "/":
            self.path = "/index.html"
        super().do_GET()

    def do_POST(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if path == "/api/up":
            proc = run_fakevps("up")
            self._json(200 if proc.returncode == 0 else 500, {
                "ok": proc.returncode == 0,
                "log": (proc.stdout + proc.stderr)[-4000:],
            })
            return
        if path == "/api/down":
            proc = run_fakevps("down")
            self._json(200 if proc.returncode == 0 else 500, {
                "ok": proc.returncode == 0,
                "log": (proc.stdout + proc.stderr)[-4000:],
            })
            return
        self._json(404, {"error": "not found"})


def main() -> None:
    host = "127.0.0.1"
    port = int(os.environ.get("UI_PORT", "8787"))
    httpd = ThreadingHTTPServer((host, port), Handler)
    print(f"[ui] http://{host}:{port}", flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
