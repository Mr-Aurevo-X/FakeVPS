#!/usr/bin/env python3
"""Localhost cockpit for FakeVPS (127.0.0.1 only).

Copyright (c) 2026 Mr-Aurevo-X
"""

from __future__ import annotations

import hmac
import json
import os
import re
import secrets
import shutil
import subprocess
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

LOOPBACK_IPS = frozenset({"127.0.0.1", "::1"})
LOOPBACK_HOSTS = frozenset({"127.0.0.1", "localhost", "::1"})
MAX_BODY = 65536


def parse_host_header(host_header: str) -> str:
    raw = (host_header or "").strip().lower()
    if raw.startswith("["):
        end = raw.find("]")
        if end > 0:
            return raw[1:end]
        return ""
    return raw.split(":", 1)[0]


def normalize_client_ip(client_ip: str) -> str:
    ip = (client_ip or "").strip().lower()
    if ip.startswith("::ffff:"):
        return ip[7:]
    return ip


def loopback_request_ok(host_header: str, client_ip: str) -> bool:
    if normalize_client_ip(client_ip) not in LOOPBACK_IPS:
        return False
    return parse_host_header(host_header) in LOOPBACK_HOSTS


def cockpit_origins(port: int) -> frozenset[str]:
    return frozenset({
        f"http://127.0.0.1:{port}",
        f"http://localhost:{port}",
        f"http://[::1]:{port}",
    })


def origin_header_ok(value: str, port: int) -> bool:
    raw = (value or "").strip().rstrip("/")
    return raw in cockpit_origins(port)


def referer_ok(value: str, port: int) -> bool:
    raw = (value or "").strip()
    if not raw:
        return False
    parsed = urlparse(raw)
    origin = f"{parsed.scheme}://{parsed.netloc}"
    return origin in cockpit_origins(port)


def csrf_ok(origin: str, referer: str, port: int) -> bool:
    if origin:
        return origin_header_ok(origin, port)
    return referer_ok(referer, port)


def redact_home_paths(text: str, home: str | None = None) -> str:
    out = text or ""
    home_path = home if home is not None else os.path.expanduser("~")
    if home_path and home_path not in {"", "/", "~"}:
        out = out.replace(home_path, "~")
    out = re.sub(r"(?<=[\s\"'=])/home/[^/\s\"']+", "~", out)
    out = re.sub(r"(?<=[\s\"'=])/Users/[^/\s\"']+", "~", out)
    out = re.sub(r"^/home/[^/\s\"']+", "~", out, flags=re.M)
    out = re.sub(r"^/Users/[^/\s\"']+", "~", out, flags=re.M)
    return out


HOME = Path.home()

BOT_MARKERS = (
    "package.json",
    "docker-compose.yml",
    "docker-compose.prod.yml",
    "compose.yaml",
    "docker-compose.yaml",
    "Dockerfile",
    "bot.py",
    "main.py",
)


def safe_browse_path(raw: str) -> Path | None:
    """Resolve a folder-picker path; only directories inside $HOME are allowed."""
    target = Path(os.path.expanduser((raw or "").strip() or "~"))
    try:
        real = target.resolve()
    except OSError:
        return None
    home = HOME.resolve()
    if real != home and home not in real.parents:
        return None
    try:
        if not real.is_dir():
            return None
    except OSError:
        return None
    return real


def tilde_display(real: Path) -> str:
    home = HOME.resolve()
    if real == home:
        return "~"
    return "~/" + real.relative_to(home).as_posix()


def browse_payload(raw: str) -> dict:
    real = safe_browse_path(raw) or HOME.resolve()
    home = HOME.resolve()
    dirs = []
    try:
        entries = sorted(real.iterdir(), key=lambda p: p.name.lower())
    except OSError:
        entries = []
    for entry in entries:
        if entry.name.startswith("."):
            continue
        try:
            if not entry.is_dir():
                continue
        except OSError:
            continue
        try:
            has_env = (entry / ".env").is_file()
            has_bot = any((entry / marker).exists() for marker in BOT_MARKERS)
        except OSError:
            has_env = False
            has_bot = False
        dirs.append({"name": entry.name, "has_env": has_env, "has_bot": has_bot})
        if len(dirs) >= 500:
            break
    parent = "" if real == home else tilde_display(real.parent)
    return {"path": tilde_display(real), "parent": parent, "dirs": dirs}


ROOT = Path(os.environ["FAKEVPS_ROOT"])
UI = ROOT / "ui"
BIN = ROOT / "fakevps"
STATE = Path(os.environ.get("FAKEVPS_STATE_DIR") or (ROOT / "state"))
LOG_PATH = STATE / "logs" / "fakevps.log"
UP_PID = STATE / "up.pid"
BACKEND_PATH = STATE / "backend"
TOKEN_PATH = STATE / "ui.token"


def load_or_create_token() -> str:
    """Session token for state-changing requests (Jupyter-style).

    Stored 600 in state/ so only this user can read it; the CLI appends it
    to the cockpit URL when opening the browser.
    """
    try:
        tok = TOKEN_PATH.read_text(encoding="utf-8").strip()
        if tok:
            return tok
    except OSError:
        pass
    tok = secrets.token_hex(16)
    TOKEN_PATH.parent.mkdir(parents=True, exist_ok=True)
    TOKEN_PATH.write_text(tok + "\n", encoding="utf-8")
    os.chmod(TOKEN_PATH, 0o600)
    return tok


SESSION_TOKEN = ""


def token_ok(header_value: str) -> bool:
    if not SESSION_TOKEN:
        return True
    return hmac.compare_digest((header_value or "").strip(), SESSION_TOKEN)


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


def tail_log(n: int = 80) -> str:
    if not LOG_PATH.exists():
        return ""
    try:
        lines = LOG_PATH.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return ""
    return redact_home_paths("\n".join(lines[-n:]))


def pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def up_in_progress() -> bool:
    if not UP_PID.exists():
        return False
    try:
        pid = int(UP_PID.read_text(encoding="utf-8").strip())
    except (ValueError, OSError):
        return False
    if pid_alive(pid):
        return True
    try:
        UP_PID.unlink()
    except OSError:
        pass
    return False


def active_up_args() -> list[str]:
    args = ["up"]
    if BACKEND_PATH.exists():
        be = BACKEND_PATH.read_text(encoding="utf-8").strip()
        if be == "fast":
            args.append("--fast")
        elif be == "kvm":
            args.append("--kvm")
    return args


def spawn_ssh_terminal() -> tuple[bool, str]:
    """Open a local terminal to the guest. Fixed argv — no user shell string."""
    port = os.environ.get("SSH_PORT") or "2222"
    user = os.environ.get("SSH_USER") or "ubuntu"
    key = ROOT / "secrets" / "vps_ed25519"
    known = STATE / "known_hosts"
    ssh_cmd = ["ssh", "-p", port, f"{user}@127.0.0.1"]
    if key.is_file():
        ssh_cmd = [
            "ssh",
            "-i",
            str(key),
            "-p",
            port,
            "-o",
            "StrictHostKeyChecking=accept-new",
            "-o",
            f"UserKnownHostsFile={known}",
            f"{user}@127.0.0.1",
        ]
    prefixes: list[list[str]] = [
        ["xdg-terminal-exec"],
        ["gnome-terminal", "--"],
        ["kitty"],
        ["alacritty", "-e"],
        ["konsole", "-e"],
        ["xfce4-terminal", "-e"],
        ["xterm", "-e"],
    ]
    for prefix in prefixes:
        if not shutil.which(prefix[0]):
            continue
        try:
            subprocess.Popen(
                [*prefix, *ssh_cmd],
                start_new_session=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            return True, "terminal opened"
        except OSError:
            continue
    return False, "no terminal emulator found (xdg-terminal-exec, gnome-terminal, kitty, alacritty)"


def spawn_fakevps(*args: str) -> int:
    env = os.environ.copy()
    env["FAKEVPS_SKIP_UI"] = "1"
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    logf = open(LOG_PATH, "a", encoding="utf-8")
    proc = subprocess.Popen(
        [str(BIN), *args],
        cwd=str(ROOT),
        env=env,
        stdout=logf,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    return proc.pid


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

    def _ui_port(self) -> int:
        return int(os.environ.get("UI_PORT", "8787"))

    def _reject_if_remote(self) -> bool:
        host = self.headers.get("Host") or ""
        client = self.client_address[0] if self.client_address else ""
        if loopback_request_ok(host, client):
            return False
        self._json(403, {"error": "localhost only"})
        return True

    def _reject_if_csrf(self) -> bool:
        origin = self.headers.get("Origin") or ""
        referer = self.headers.get("Referer") or ""
        if csrf_ok(origin, referer, self._ui_port()):
            return False
        self._json(403, {"error": "localhost cockpit only"})
        return True

    def _reject_if_no_token(self) -> bool:
        if token_ok(self.headers.get("X-FakeVPS-Token") or ""):
            return False
        self._json(403, {"error": "missing session token — open the cockpit with ./fakevps ui"})
        return True

    def _stream_fakevps(self, *args: str) -> None:
        """Stream a fakevps command's output line by line (HTTP/1.0, close-delimited)."""
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        env = os.environ.copy()
        env["FAKEVPS_SKIP_UI"] = "1"
        proc = subprocess.Popen(
            [str(BIN), *args],
            cwd=str(ROOT),
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
        rc = -1
        try:
            assert proc.stdout is not None
            for line in proc.stdout:
                self.wfile.write(redact_home_paths(line).encode("utf-8"))
                self.wfile.flush()
            rc = proc.wait()
            self.wfile.write(f"[exit {rc}]\n".encode("utf-8"))
        except (BrokenPipeError, ConnectionResetError):
            proc.terminate()

    def _reject_if_huge(self) -> bool:
        try:
            n = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            n = 0
        if n <= MAX_BODY:
            return False
        self._json(413, {"error": "body too large"})
        return True

    def _read_json(self) -> dict:
        n = int(self.headers.get("Content-Length") or 0)
        if n <= 0:
            return {}
        if n > MAX_BODY:
            return {}
        raw = self.rfile.read(n)
        try:
            data = json.loads(raw.decode() or "{}")
        except json.JSONDecodeError:
            return {}
        return data if isinstance(data, dict) else {}

    def do_GET(self) -> None:  # noqa: N802
        if self._reject_if_remote():
            return
        path = urlparse(self.path).path
        if path == "/api/status":
            proc = run_fakevps("status", "--json")
            if proc.returncode != 0:
                self._json(500, {
                    "error": redact_home_paths(proc.stderr.strip() or "status failed"),
                    "activity": tail_log(),
                    "starting": up_in_progress(),
                })
                return
            try:
                data = json.loads(proc.stdout)
            except json.JSONDecodeError:
                self._json(500, {"error": "invalid status json"})
                return
            data["activity"] = tail_log()
            data["starting"] = up_in_progress()
            self._json(200, data)
            return
        if path == "/api/metrics":
            proc = run_fakevps("metrics")
            if proc.returncode != 0:
                self._json(500, {
                    "error": proc.stderr.strip() or "metrics failed",
                })
                return
            try:
                data = json.loads(proc.stdout or "{}")
            except json.JSONDecodeError:
                self._json(500, {"error": "invalid metrics json"})
                return
            if not isinstance(data, dict):
                data = {}
            self._json(200, data)
            return
        if path == "/api/logs":
            self._json(200, {"log": tail_log(), "starting": up_in_progress()})
            return
        if path == "/api/browse":
            if self._reject_if_no_token():
                return
            query = parse_qs(urlparse(self.path).query)
            raw = (query.get("path") or [""])[0]
            self._json(200, browse_payload(raw))
            return
        if path == "/api/bot-logs":
            if self._reject_if_no_token():
                return
            proc = run_fakevps("ssh", "--", BOT_LOGS_SCRIPT)
            if proc.returncode != 0 and not proc.stdout.strip():
                self._json(500, {"error": redact_home_paths(proc.stderr.strip() or "node is down")})
                return
            self._json(200, {"log": redact_home_paths(proc.stdout[-8000:])})
            return
        if path == "/":
            self.path = "/index.html"
        super().do_GET()

    def do_POST(self) -> None:  # noqa: N802
        if self._reject_if_remote():
            return
        if self._reject_if_csrf():
            return
        if self._reject_if_no_token():
            return
        if self._reject_if_huge():
            return
        parsed = urlparse(self.path)
        path = parsed.path
        stream = "stream=1" in (parsed.query or "")
        if path == "/api/up":
            st = run_fakevps("status", "--json")
            already = False
            try:
                already = bool(json.loads(st.stdout or "{}").get("ssh"))
            except json.JSONDecodeError:
                already = False
            if already:
                self._json(200, {
                    "ok": True,
                    "already_online": True,
                    "log": tail_log() or "already online",
                })
                return
            if up_in_progress():
                self._json(200, {
                    "ok": True,
                    "started": True,
                    "log": tail_log() or "start already in progress",
                })
                return
            pid = spawn_fakevps(*active_up_args())
            UP_PID.parent.mkdir(parents=True, exist_ok=True)
            UP_PID.write_text(f"{pid}\n", encoding="utf-8")
            self._json(200, {
                "ok": True,
                "started": True,
                "log": tail_log() or "starting…",
            })
            return
        if path == "/api/down":
            proc = run_fakevps("down")
            self._json(200 if proc.returncode == 0 else 500, {
                "ok": proc.returncode == 0,
                "log": redact_home_paths((proc.stdout + proc.stderr)[-4000:]) or tail_log(),
            })
            return
        if path == "/api/attach":
            body = self._read_json()
            raw = str(body.get("dir") or "").strip()
            if not raw:
                self._json(400, {"ok": False, "error": "dir required"})
                return
            expanded = os.path.expanduser(raw)
            if not os.path.isdir(expanded):
                self._json(400, {"ok": False, "error": "not a directory"})
                return
            if stream:
                self._stream_fakevps("attach", expanded)
                return
            proc = run_fakevps("attach", expanded)
            self._json(200 if proc.returncode == 0 else 500, {
                "ok": proc.returncode == 0,
                "log": redact_home_paths((proc.stdout + proc.stderr)[-4000:]) or tail_log(),
            })
            return
        if path == "/api/sync":
            proc = run_fakevps("sync")
            self._json(200 if proc.returncode == 0 else 500, {
                "ok": proc.returncode == 0,
                "log": redact_home_paths((proc.stdout + proc.stderr)[-4000:]) or tail_log(),
            })
            return
        if path == "/api/restart-bot":
            proc = run_fakevps("restart-bot")
            self._json(200 if proc.returncode == 0 else 500, {
                "ok": proc.returncode == 0,
                "log": redact_home_paths((proc.stdout + proc.stderr)[-4000:]) or tail_log(),
            })
            return
        if path == "/api/open-terminal":
            ok, msg = spawn_ssh_terminal()
            self._json(200 if ok else 500, {"ok": ok, "log": msg})
            return
        self._json(404, {"error": "not found"})

    def do_HEAD(self) -> None:  # noqa: N802
        if self._reject_if_remote():
            return
        super().do_HEAD()


BOT_LOGS_SCRIPT = r"""
if systemctl is-active discord-bot >/dev/null 2>&1 || systemctl is-enabled discord-bot >/dev/null 2>&1; then
  echo '--- systemd discord-bot ---'
  sudo -n journalctl -u discord-bot -n 120 --no-pager 2>/dev/null \
    || journalctl -u discord-bot -n 120 --no-pager 2>/dev/null || true
fi
names="$(docker ps --format '{{.Names}}' 2>/dev/null | grep -iE 'bot|worker|discord' || true)"
for n in $names; do
  echo "--- docker $n ---"
  docker logs --tail 60 "$n" 2>&1 | tail -60
done
"""


def main() -> None:
    global SESSION_TOKEN
    wanted = (os.environ.get("UI_HOST") or "127.0.0.1").strip()
    if wanted not in {"127.0.0.1", "localhost", ""}:
        print("[ui] refusing non-loopback bind", file=sys.stderr)
        sys.exit(2)
    SESSION_TOKEN = load_or_create_token()
    host = "127.0.0.1"
    port = int(os.environ.get("UI_PORT", "8787"))
    httpd = ThreadingHTTPServer((host, port), Handler)
    print(f"[ui] http://{host}:{port}", flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
