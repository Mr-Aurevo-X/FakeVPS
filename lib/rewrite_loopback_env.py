#!/usr/bin/env python3
"""Rewrite host-loopback service URLs so a --fast guest can reach them.

Host `.env` files often use localhost:5433 because compose publishes on
127.0.0.1. Copied verbatim into the guest, that points at the guest itself.
When a host container publishes that port, map it to the compose service
name and internal port, and report the Docker network the guest must join.

Copyright (c) 2026 Mr-Aurevo-X
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, quote, urlencode, urlparse, urlunparse

LOOPBACK_HOSTS = {"localhost", "127.0.0.1", "::1"}
SKIP_NETWORKS = {"bridge", "host", "none", "ingress"}
URL_KEYS = ("DATABASE_URL", "REDIS_URL")
HOST_PORT_KEYS = (("LAVALINK_HOST", "LAVALINK_PORT", 2333),)
DEFAULT_PORTS = {
    "postgres": 5432,
    "postgresql": 5432,
    "redis": 6379,
    "rediss": 6379,
}
CONNECT_TIMEOUT_SEC = 5


@dataclass(frozen=True)
class Publisher:
    name: str
    container_port: int
    network: str


def is_loopback_host(host: str | None) -> bool:
    if not host:
        return False
    return host.strip("[]").lower() in LOOPBACK_HOSTS


def pick_network(networks: dict[str, Any] | None) -> str | None:
    if not networks:
        return None
    named = [name for name in networks if name not in SKIP_NETWORKS]
    if named:
        return named[0]
    return None


def publishers_from_inspect(containers: list[dict[str, Any]]) -> dict[int, Publisher]:
    found: dict[int, Publisher] = {}
    for info in containers:
        name = str(info.get("Name") or "").lstrip("/")
        if not name:
            continue
        nets = (info.get("NetworkSettings") or {}).get("Networks") or {}
        network = pick_network(nets)
        if not network:
            continue
        ports = (info.get("NetworkSettings") or {}).get("Ports") or {}
        if not isinstance(ports, dict):
            continue
        for binding_key, bindings in ports.items():
            if not bindings or not isinstance(bindings, list):
                continue
            container_port_s = str(binding_key).split("/", 1)[0]
            try:
                container_port = int(container_port_s)
            except ValueError:
                continue
            for bind in bindings:
                if not isinstance(bind, dict):
                    continue
                host_port_s = bind.get("HostPort")
                if not host_port_s:
                    continue
                try:
                    host_port = int(host_port_s)
                except ValueError:
                    continue
                if host_port not in found:
                    found[host_port] = Publisher(name, container_port, network)
    return found


def _docker_bin() -> str | None:
    return shutil.which("docker")


def discover_docker() -> dict[int, Publisher]:
    docker = _docker_bin()
    if not docker:
        return {}
    try:
        raw = subprocess.check_output([docker, "ps", "-q"], text=True)
    except (OSError, subprocess.CalledProcessError):
        return {}
    ids = raw.split()
    if not ids:
        return {}
    try:
        inspect = json.loads(
            subprocess.check_output([docker, "inspect", *ids], text=True)
        )
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError):
        return {}
    if not isinstance(inspect, list):
        return {}
    return publishers_from_inspect(inspect)


def parse_env_text(text: str) -> dict[str, str]:
    data: dict[str, str] = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if key.startswith("export "):
            key = key[7:].strip()
        if key:
            data[key] = value
    return data


def dump_env(data: dict[str, str]) -> str:
    if not data:
        return ""
    return "\n".join(f"{key}={value}" for key, value in data.items()) + "\n"


def loopback_url_keys(env: dict[str, str]) -> list[str]:
    keys: list[str] = []
    for key in URL_KEYS:
        host = urlparse(env.get(key, "")).hostname
        if is_loopback_host(host):
            keys.append(key)
    for host_key, _port_key, _default in HOST_PORT_KEYS:
        if is_loopback_host(env.get(host_key, "").strip() or None):
            keys.append(host_key)
    return keys


def _quote_userinfo(parsed: Any) -> str:
    if parsed.username is None:
        return ""
    user = quote(parsed.username, safe="")
    if parsed.password is None:
        return f"{user}@"
    return f"{user}:{quote(parsed.password, safe='')}@"


def replace_url_host_port(url: str, host: str, port: int) -> str:
    parsed = urlparse(url)
    netloc = f"{_quote_userinfo(parsed)}{host}:{port}"
    return urlunparse(parsed._replace(netloc=netloc))


def ensure_postgres_connect_timeout(url: str) -> str:
    parsed = urlparse(url)
    if parsed.scheme not in {"postgres", "postgresql"}:
        return url
    query = parse_qs(parsed.query, keep_blank_values=True)
    if "connect_timeout" in query:
        return url
    query["connect_timeout"] = [str(CONNECT_TIMEOUT_SEC)]
    return urlunparse(parsed._replace(query=urlencode(query, doseq=True)))


def _url_host_port(url: str) -> tuple[str | None, int | None]:
    parsed = urlparse(url)
    host = parsed.hostname
    if parsed.port is not None:
        return host, parsed.port
    default = DEFAULT_PORTS.get(parsed.scheme)
    return host, default


def rewrite_env(
    env: dict[str, str],
    publishers: dict[int, Publisher],
) -> tuple[dict[str, str], list[str], list[str], list[str]]:
    """Return (env, rewritten keys, networks to join, unresolved loopback keys)."""
    out = dict(env)
    rewritten: list[str] = []
    networks: list[str] = []
    unresolved: list[str] = []

    def add_network(network: str) -> None:
        if network and network not in networks:
            networks.append(network)

    for key in URL_KEYS:
        url = out.get(key, "")
        host, port = _url_host_port(url)
        if not is_loopback_host(host) or port is None:
            continue
        pub = publishers.get(port)
        if pub is None:
            unresolved.append(key)
            continue
        new_url = replace_url_host_port(url, pub.name, pub.container_port)
        if key == "DATABASE_URL":
            new_url = ensure_postgres_connect_timeout(new_url)
        out[key] = new_url
        rewritten.append(key)
        add_network(pub.network)

    for host_key, port_key, default_port in HOST_PORT_KEYS:
        host = out.get(host_key, "").strip()
        if not is_loopback_host(host or None):
            continue
        try:
            port = int(str(out.get(port_key, "")).strip() or default_port)
        except ValueError:
            port = default_port
        pub = publishers.get(port)
        if pub is None:
            unresolved.append(host_key)
            continue
        out[host_key] = pub.name
        out[port_key] = str(pub.container_port)
        rewritten.append(host_key)
        add_network(pub.network)

    return out, rewritten, networks, unresolved


def apply_file(path: Path, publishers: dict[int, Publisher]) -> dict[str, Any]:
    env = parse_env_text(path.read_text(encoding="utf-8", errors="replace"))
    loopback = loopback_url_keys(env)
    rewritten_env, rewritten, networks, unresolved = rewrite_env(env, publishers)
    if rewritten:
        path.write_text(dump_env(rewritten_env), encoding="utf-8")
    return {
        "loopback": loopback,
        "rewritten": rewritten,
        "networks": networks,
        "unresolved": unresolved,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", metavar="ENV", help="rewrite this env file in place")
    parser.add_argument(
        "--inspect-json",
        metavar="FILE",
        help="docker inspect JSON (list) instead of calling docker",
    )
    parser.add_argument(
        "--discover-docker",
        action="store_true",
        help="discover published ports from running host containers",
    )
    args = parser.parse_args(argv)
    if not args.apply:
        parser.error("--apply is required")
    path = Path(args.apply)
    if not path.is_file():
        print("env file not found", file=sys.stderr)
        return 2
    publishers: dict[int, Publisher] = {}
    if args.inspect_json:
        payload = json.loads(Path(args.inspect_json).read_text(encoding="utf-8"))
        if not isinstance(payload, list):
            print("inspect JSON must be a list", file=sys.stderr)
            return 2
        publishers = publishers_from_inspect(payload)
    elif args.discover_docker:
        publishers = discover_docker()
    report = apply_file(path, publishers)
    json.dump(report, sys.stdout, separators=(",", ":"))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
