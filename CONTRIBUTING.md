# Contributing

**Based on FakeVPS — https://github.com/Mr-Aurevo-X/FakeVPS**

This origin repository is **1.0.0 final**. It is not a community upstream.

- Take the [v1.0.0 release](https://github.com/Mr-Aurevo-X/FakeVPS/releases/tag/v1.0.0) or fork it to **your** GitHub account.
- Reuse and modify **your** copy as you like.
- Anything that differs from this 1.0.0 is not Mr-Aurevo-X's responsibility.
- Do not expect pull requests or issues here to be reviewed or merged.
- A reference to the original project is asked, not required. If you keep one, leave `Based on FakeVPS — https://github.com/Mr-Aurevo-X/FakeVPS` unchanged.

See [LICENSE](LICENSE). Thank you for keeping a trace.

## 1.0 final

This is the last origin tree. The earlier **0.3 freeze** (no new CLI or cockpit surface once attach CI stayed green) is how the surface was locked before 1.0.0. Ideas belong on your fork.

## If you publish a fork

Turn on GitHub **secret scanning** and **push protection**. Protect `main` (required checks, no force-push). The workflow in `.github/workflows/checks.yml` is a working baseline.

## Do not commit

`config.env`, `secrets/discord.env`, SSH keys, `state/`, live tokens. The public artifact is git (or `git archive`), not a zip of the working folder.

---

## Contribuer

Ce dépôt d'origine est la **1.0.0 finale**. Ce n'est pas un upstream communautaire.

- Prenez la [release v1.0.0](https://github.com/Mr-Aurevo-X/FakeVPS/releases/tag/v1.0.0) ou forkez sur **votre** compte GitHub.
- Réutilisez et modifiez **votre** copie à votre guise.
- Tout ce qui diffère de cette 1.0.0 ne m'incombe plus.
- N'attendez pas que les PR ou issues ici soient lues ou fusionnées.
- Une référence au projet d'origine est demandée, pas obligatoire. Si vous en gardez une, laissez `Based on FakeVPS — https://github.com/Mr-Aurevo-X/FakeVPS` telle quelle. Merci d'en garder une trace.
