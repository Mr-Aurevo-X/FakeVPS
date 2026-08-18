# Changelog

All notable changes to FakeVPS. Based on FakeVPS — https://github.com/Mr-Aurevo-X/FakeVPS

## 0.3.0 — 2026-08-18

### Added
- `fakevps.bot.yml` `fallback:` (`none` default, or `node`) so compose→Node is opt-in.
- Status JSON `disk_envelope_gb` / `disk_host_backed`; cockpit labels the 40 GB figure as an envelope and warns when Docker images exceed it.
- CI `boot-fast` **attaches** `tests/fixtures/node-bot` and requires `healthcheck OK`.
- Cockpit banner when the backend is `fast`.

### Changed
- A failed or bot-less compose deploy **exits** instead of silently starting Node.
- Successful attaches prune the guest build cache and dangling images.
- **`--fast` is the default** (`./fakevps up`). Use `./fakevps up --kvm` for isolation.
- `--fast` attach rewrites guest loopback `DATABASE_URL` / `REDIS_URL` / `LAVALINK_HOST` to the host compose service names and joins that Docker network. The host `.env` is unchanged.

### Frozen
- No new CLI commands or cockpit panels until attach CI stays green. See CONTRIBUTING.

## 0.2.0 — 2026-08-18

### Added
- `./fakevps doctor` — host pre-flight: KVM/QEMU, Docker, RAM, disk, ports, WSL hints.
- `./fakevps audit` — hygiene check: secrets permissions, git tracking, leftover injected env.
- `./fakevps --version`.
- **Ephemeral mode** — `down --wipe` or `EPHEMERAL=true`: shutdown erases the guest disk, the fast Docker graph, logs and caches. `secrets/` and the host SSH key are kept.
- Cockpit **Browse** dialog — pick the bot folder visually (home-restricted, `.env`/bot badges) instead of typing a path.
- Cockpit asks for confirmation before an ephemeral shutdown.
- Cockpit **session token** (Jupyter-style, `state/ui.token`): required for state-changing POSTs, folder browsing and bot logs.
- Cockpit **live deploy stream** — `attach` output fills the journal line by line while pnpm/docker work.
- Cockpit **Bot logs** dialog — last journalctl/docker lines from the guest, one click.
- Cockpit is **bilingual** (FR/EN): language auto-detected from the browser, FR/EN toggle in the header, diagnostics included.
- `./fakevps snapshot list|save|restore|rm` — qcow2 snapshots of the node disk (kvm backend, node stopped).
- **Post-deploy healthcheck** — after `attach`, the guest waits for a bot process that survives its first seconds; on failure it prints the journal tail and the deploy reports an error (crash-loops and bad tokens surface immediately).
- **Profiles** — `./fakevps -p <name> <cmd>` overlays `profiles/<name>.env` and keeps its own state, ports and container name, so several nodes coexist.
- CI now **boots the real `--fast` node** on every push: up, SSH round-trip, ephemeral `down --wipe`.

### Changed
- Bot deploys are guarded: compose env preflight with the exact list of missing keys, Prisma migrate skipped without `DATABASE_URL`, monorepo build via root `build:ci`/`build`, and **no systemd unit is installed when the build fails** (attach reports the failure).
- Node.js in the guest installs from nodejs.org with sha256 verification; Docker Compose v2 plugin installed with `docker.io`.
- README rewritten as a public bilingual document (EN + FR).

### Security
- Cockpit refuses non-loopback binds/hosts and cross-site POSTs; body size capped.
- Host paths redacted from logs and cockpit output; status JSON no longer exposes the raw bot path.

## 0.1.0

Initial version: KVM and fast (privileged Docker) backends, cockpit on 127.0.0.1:8787, SSH on 2222, bot attach with runtime detection, guest telemetry.
