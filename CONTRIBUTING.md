# Contributing

**Based on FakeVPS — https://github.com/Mr-Aurevo-X/FakeVPS**

This repository is **private** and **owner-write only**. There is no write access without an invite from Mr-Aurevo-X.

The [LICENSE](LICENSE) is a contract. It does not technically stop a fork from stripping the origin link. Keep credit and `https://github.com/Mr-Aurevo-X/FakeVPS` in the cockpit footer, `./fakevps --help`, and the README.

## 0.3 freeze

No new commands, no new cockpit panels, until the `boot-fast` attach job stays green. Harden what exists (deploy, disk, CI). Ideas wait for 0.4.

## When the repo is public

Turn on GitHub **secret scanning** and **push protection**. Protect `main` (required checks, no force-push). The workflow in `.github/workflows/checks.yml` is the baseline.

## Do not commit

`config.env`, `secrets/discord.env`, SSH keys, `state/`, live tokens. The public artifact is git (or `git archive`), not a zip of the working folder.
