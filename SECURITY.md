# Security / Sécurité

Owner / propriétaire : **Mr-Aurevo-X**

Based on FakeVPS — https://github.com/Mr-Aurevo-X/FakeVPS

FakeVPS is a **localhost rehearsal** tool. It is not a hosted service.

---

## English

### What the author does not do

- The author **collects nothing**. There is no telemetry back to Mr-Aurevo-X, no analytics, no crash reporter, no update phone-home, and no Google Fonts (or other CDN) from the cockpit.
- There is **no backdoor**: no hidden listener, no reverse shell, no undocumented remote endpoint.
- Tokens, `.env` files, and SSH keys **stay on the machine** that runs FakeVPS. Status APIs expose booleans such as `token_present`, never the token value.

### Bind address

Cockpit, SSH, and optional bot panel binds are **127.0.0.1 only**. Nothing is intended to listen on `0.0.0.0`. Treat a bind on all interfaces as a bug.

### Secrets

- Put Discord credentials in `secrets/discord.env` (gitignored) or in the attached bot’s `.env`.
- Never commit `secrets/discord.env`, `config.env`, `state/`, or live tokens.
- `./fakevps attach` / inject may copy keys **into the guest** at `/home/ubuntu/app/.env` (mode `600`). That file lives on your disk, not on a server owned by the author.

### Reporting a vulnerability

This GitHub repository is **private** for now.

- Open a **GitHub issue** on the private `Mr-Aurevo-X/FakeVPS` repo (preferred).
- When the project is public, use a **private GitHub security advisory** instead of a public issue.
- No email is required. Do not paste live tokens, `config.env`, or `.env` contents in the report.

---

## Français

### Ce que l’auteur ne fait pas

- L’auteur **ne collecte rien**. Pas de télémétrie vers Mr-Aurevo-X, pas d’analytics, pas de rapport de crash, pas d’appel réseau pour les polices ou les mises à jour.
- **Pas de backdoor** : pas d’écouteur caché, pas de shell inverse, pas d’endpoint distant non documenté.
- Les jetons, fichiers `.env` et clés SSH **restent sur la machine** qui exécute FakeVPS. Les API de statut exposent des booléens (`token_present`), jamais la valeur du jeton.

### Adresse d’écoute

Cockpit, SSH et panneau bot optionnel écoutent **uniquement 127.0.0.1**. Rien n’est censé écouter sur `0.0.0.0`. Un bind toutes interfaces est un bug.

### Secrets

- Mets les identifiants Discord dans `secrets/discord.env` (ignoré par git) ou dans le `.env` du bot attaché.
- Ne commite jamais `secrets/discord.env`, `config.env`, `state/`, ni un jeton réel.
- `./fakevps attach` / l’injection peut copier des clés **dans le guest** (`/home/ubuntu/app/.env`, mode `600`). Ce fichier reste sur ton disque.

### Signaler une faille

Le dépôt GitHub est **privé** pour le moment.

- Ouvre une **issue GitHub** sur le dépôt privé `Mr-Aurevo-X/FakeVPS`.
- Quand le projet sera public, utilise un **avis de sécurité GitHub privé** plutôt qu’une issue publique.
- Aucun e-mail n’est exigé. N’inclus pas de jeton, de `config.env` ni de `.env` dans le signalement.
