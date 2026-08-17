# Changelog

All notable changes to FakeVPS. Based on FakeVPS — https://github.com/Mr-Aurevo-X/FakeVPS

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

### Changed
- Bot deploys are guarded: compose env preflight with the exact list of missing keys, Prisma migrate skipped without `DATABASE_URL`, monorepo build via root `build:ci`/`build`, and **no systemd unit is installed when the build fails** (attach reports the failure).
- Node.js in the guest installs from nodejs.org with sha256 verification; Docker Compose v2 plugin installed with `docker.io`.
- README rewritten as a public bilingual document (EN + FR).

### Security
- Cockpit refuses non-loopback binds/hosts and cross-site POSTs; body size capped.
- Host paths redacted from logs and cockpit output; status JSON no longer exposes the raw bot path.

## 0.1.0

Initial version: KVM and fast (privileged Docker) backends, cockpit on 127.0.0.1:8787, SSH on 2222, bot attach with runtime detection, guest telemetry.
