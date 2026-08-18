# Contributing

**Based on FakeVPS — https://github.com/Mr-Aurevo-X/FakeVPS**

This origin repository is a **public snapshot**. It is not a community upstream.

- Fork it to **your** GitHub account.
- Reuse and modify **your** fork (or a private copy).
- Do not expect pull requests or issues here to be reviewed or merged.
- A reference to the original project is asked, not required. If you keep one, leave `Based on FakeVPS — https://github.com/Mr-Aurevo-X/FakeVPS` unchanged.

See [LICENSE](LICENSE). Thank you for keeping a trace.

## 0.3 freeze

The 0.3 line froze the CLI and cockpit surface (no new commands or panels) once attach CI stayed green. That freeze is now the public snapshot. Ideas belong on your fork.

## If you publish a fork

Turn on GitHub **secret scanning** and **push protection**. Protect `main` (required checks, no force-push). The workflow in `.github/workflows/checks.yml` is a working baseline.

## Do not commit

`config.env`, `secrets/discord.env`, SSH keys, `state/`, live tokens. The public artifact is git (or `git archive`), not a zip of the working folder.

---

## Contribuer

Ce dépôt d'origine est un **instantané public**. Ce n'est pas un upstream communautaire.

- Forkez-le sur **votre** compte GitHub.
- Réutilisez et modifiez **votre** fork (ou une copie privée).
- N'attendez pas que les PR ou issues ici soient lues ou fusionnées.
- Une référence au projet d'origine est demandée, pas obligatoire. Si vous en gardez une, laissez `Based on FakeVPS — https://github.com/Mr-Aurevo-X/FakeVPS` telle quelle. Merci d'en garder une trace.
