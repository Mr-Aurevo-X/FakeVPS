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

Cockpit, SSH, and optional bot panel binds are **127.0.0.1 only**. Nothing is intended to listen on `0.0.0.0`. Treat a bind on all interfaces as a bug. `UI_HOST` cannot move the cockpit off loopback.

The cockpit uses a **session token** (Jupyter-style): the server writes a random token to `state/ui.token` (mode 600) and `./fakevps ui` appends it to the URL it opens. State-changing POSTs, folder browsing, and bot logs require that token, so another local user — or a page opened without it — cannot drive `/api/up` / `/api/down` or list your home folder. Requests whose `Host` header is not `127.0.0.1` / `localhost` are refused (DNS-rebinding guard), and POSTs also require `Origin` (or `Referer`) to be this cockpit URL. Do not expose the port, and do not run FakeVPS on a shared login. Use `./fakevps` in a terminal if you are not the cockpit page.

### `--fast` is nearly host-root

`./fakevps up --fast` starts a **privileged** Docker container with `cgroupns=host`. That is close to root on the host. Use it only on a machine you control. Do not expose the node. Do not run `--fast` on a shared computer.

KVM (`./fakevps up`) is the stronger isolation story.

### Guest package install (no `curl | bash`)

First-boot scripts install Docker from the **Ubuntu package** (`docker.io`). Node.js **22 LTS** is installed from `nodejs.org` with a **sha256 check** when a bot needs it (Ubuntu 24.04 only has Node 18; current pnpm wants ≥ 22.13). They do not pipe `get.docker.com` or NodeSource into a shell.

### Git repo vs folder dump

The public artifact is the **git repository**, not a zip of the working folder. `state/` and `secrets/` are gitignored but can still sit on disk — including a leftover Docker graph under `state/fast/docker` (sometimes root-owned). Do not publish a folder dump. Use `git archive` or a clone. `contrib/sanitize-working-tree.sh` removes user-owned leftovers it can delete; it will not `sudo` a root graph.

### Secrets

- Put Discord credentials in `secrets/discord.env` (gitignored) or in the attached bot’s `.env`.
- Never commit `secrets/discord.env`, `config.env`, `state/`, or live tokens.
- If a token was ever pasted into a chat or a log, **reset it** on the Discord developer portal. FakeVPS cannot rotate it for you.
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

Cockpit, SSH et panneau bot optionnel écoutent **uniquement 127.0.0.1**. Rien n’est censé écouter sur `0.0.0.0`. Un bind toutes interfaces est un bug. `UI_HOST` ne peut pas sortir le cockpit de la boucle locale.

Le cockpit utilise un **jeton de session** (façon Jupyter) : le serveur écrit un jeton aléatoire dans `state/ui.token` (mode 600) et `./fakevps ui` l’ajoute à l’URL qu’il ouvre. Les POST qui changent l’état, le parcours de dossiers et les logs du bot exigent ce jeton — un autre utilisateur local, ou une page ouverte sans lui, ne peut pas piloter `/api/up` / `/api/down` ni lister ton home. Une requête dont le `Host` n’est pas `127.0.0.1` / `localhost` est refusée, et les POST exigent aussi `Origin` (ou `Referer`) égal à l’URL du cockpit. N’expose pas le port. Ne lance pas FakeVPS sur une session partagée. Hors page cockpit, utilise `./fakevps` dans un terminal.

### `--fast` est presque root hôte

`./fakevps up --fast` lance un conteneur Docker **privilégié** avec `cgroupns=host`. C’est proche du root de l’hôte. Uniquement sur une machine à toi. N’expose pas le nœud. Ne lance pas `--fast` sur un PC partagé.

KVM (`./fakevps up`) isole mieux.

### Paquets guest (pas de `curl | bash`)

Le premier boot installe Docker via le **paquet Ubuntu** (`docker.io`). Node.js **22 LTS** vient de `nodejs.org` avec **contrôle sha256** si le bot en a besoin (Ubuntu 24.04 n’a que Node 18 ; pnpm actuel veut ≥ 22.13). Pas de `get.docker.com` ni NodeSource pipé dans un shell.

### Dépôt git vs zip du dossier

L’artefact public, c’est le **dépôt git**, pas un zip du dossier de travail. `state/` et `secrets/` sont ignorés par git mais peuvent rester sur le disque — y compris un graphe Docker sous `state/fast/docker` (parfois root). Ne publie pas un dump du dossier. Utilise `git archive` ou un clone. `contrib/sanitize-working-tree.sh` enlève ce qu’il peut sans `sudo`.

### Secrets

- Mets les identifiants Discord dans `secrets/discord.env` (ignoré par git) ou dans le `.env` du bot attaché.
- Ne commite jamais `secrets/discord.env`, `config.env`, `state/`, ni un jeton réel.
- Si un jeton a fuité dans un chat ou un log, **réinitialise-le** sur le portail développeur Discord. FakeVPS ne peut pas le tourner à ta place.
- `./fakevps attach` / l’injection peut copier des clés **dans le guest** (`/home/ubuntu/app/.env`, mode `600`). Ce fichier reste sur ton disque.

### Signaler une faille

Le dépôt GitHub est **privé** pour le moment.

- Ouvre une **issue GitHub** sur le dépôt privé `Mr-Aurevo-X/FakeVPS`.
- Quand le projet sera public, utilise un **avis de sécurité GitHub privé** plutôt qu’une issue publique.
- Aucun e-mail n’est exigé. N’inclus pas de jeton, de `config.env` ni de `.env` dans le signalement.
