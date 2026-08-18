# FakeVPS

**Based on FakeVPS — https://github.com/Mr-Aurevo-X/FakeVPS**

Run a **local** Ubuntu node that behaves like a mid-range paid VPS — 6 GB RAM, 4 vCPU, 40 GB disk, SSH, systemd, Docker inside the guest — and rehearse a real deploy before renting a box. No bot is bundled: attach **any** Discord bot (Node, Python, Compose, Dockerfile).

> **Public snapshot (0.3.2).** This origin repository is finished. Fork it, reuse it, change it on **your** GitHub — not here. Pull requests and issues on this repo will not be maintained. Please keep a trace of the original project.
>
> **Instantané public (0.3.2).** Ce dépôt d'origine est terminé. Forkez, réutilisez, modifiez **votre** copie — pas celle-ci. Les PR et issues ici ne seront pas traitées. Merci d'en garder une trace.

[English](#english) · [Français](#français)

---

## English

### A note from Mr-Aurevo-X

I built FakeVPS in August 2026 on CachyOS, inside [Cursor](https://cursor.com), because I wanted a local Ubuntu node that felt like a cheap VPS — SSH, systemd, Docker — so I could rehearse a Discord bot deploy before paying for a box. That is how I work: Cursor builds, I do the QA. This tree is the snapshot I am putting on the public internet. I will not keep changing **this** repository. Fork it onto your own GitHub, break it, rebuild it. If you mention the origin, leave this line as-is: `Based on FakeVPS — https://github.com/Mr-Aurevo-X/FakeVPS`. Thank you for keeping a trace.

— [Mr-Aurevo-X](https://github.com/Mr-Aurevo-X)

### How it works

One CLI (`./fakevps`), two backends, same ports:

- `./fakevps up` — **privileged Docker** guest (`--fast`, the default). Faster iteration. Disk is the host Docker graph (an envelope, not a 40 GB partition). Near host-root — machine you control only.
- `./fakevps up --kvm` — **KVM/QEMU** guest. Strongest isolation, needs `/dev/kvm`.

```mermaid
flowchart LR
    You[You] --> CLI["./fakevps CLI"]
    CLI --> Fast["Docker guest (up)"]
    CLI --> KVM["KVM guest (up --kvm)"]
    KVM --> Guest["Ubuntu 24.04 · SSH · systemd · Docker"]
    Fast --> Guest
    Guest --> Cockpit["Cockpit 127.0.0.1:8787"]
    Guest --> SSH["SSH 127.0.0.1:2222"]
```

Everything binds **127.0.0.1 only**: cockpit on `8787`, SSH on `2222`, optional bot panel on `BOT_PANEL_PORT`. Nothing listens on `0.0.0.0`.

### Linux

Requirements: Docker for the default backend, or QEMU/KVM (`/dev/kvm`) for `--kvm`. Run `./fakevps doctor` before the first `up`.

```bash
cp config.env.example config.env
./fakevps doctor
./fakevps up          # fast (privileged Docker, default)
# or
./fakevps up --kvm    # KVM guest
```

### Windows

FakeVPS runs inside **WSL2 + Ubuntu** (not in a VirtualBox/Hyper-V Linux VM). The default `./fakevps up` needs **Docker inside that WSL distro**.

1. Give WSL2 enough RAM (the node wants 6 GB, so plan ~8 GB for WSL) in `%UserProfile%\.wslconfig`:

   ```ini
   [wsl2]
   memory=8GB
   ```

2. Clone the repo inside the WSL filesystem and follow the Linux steps.
3. Default backend is already `./fakevps up` (`--fast`). Use `--kvm` only if `/dev/kvm` is available.
4. Optional helper from Windows: `contrib/fakevps.bat` (it still runs the Linux CLI inside WSL).

### Commands

| Command | What it does |
|---------|--------------|
| `./fakevps up [--fast|--kvm]` | Start the node and the cockpit (default: fast) |
| `./fakevps down [--wipe]` | Stop everything; `--wipe` erases all stored state |
| `./fakevps status [--json]` | Backend, SSH, cockpit, bot state |
| `./fakevps logs` | Tail host / serial / fast-container logs |
| `./fakevps ssh [-- cmd]` | Shell into the guest |
| `./fakevps ui` | Open the cockpit (session token in the URL) |
| `./fakevps attach <dir>` | Point at a bot folder and deploy it |
| `./fakevps sync` | Re-rsync the bot tree |
| `./fakevps restart-bot` | Restart the bot in the guest (systemd or Compose) |
| `./fakevps panel` | Open the bot web UI if `BOT_PANEL_PORT` is set |
| `./fakevps metrics` | Guest telemetry JSON |
| `./fakevps reset` | Wipe disk/container; next `up` is a fresh node |
| `./fakevps snapshot list\|save\|restore\|rm <name>` | qcow2 snapshots of the node disk (kvm, node stopped) |
| `./fakevps doctor` | Check the host (KVM, Docker, RAM, disk, ports) before the first `up` |
| `./fakevps audit` | Check secrets permissions and git hygiene |
| `./fakevps --version` | Print version, copyright, origin URL |
| `./fakevps -p <name> <cmd>` | Run with profile `profiles/<name>.env` (own state and ports) |
| `./fakevps install-service [--fast\|--kvm]` | systemd user unit for auto-start |

Profiles: copy [profiles/example.env.example](profiles/example.env.example) to `profiles/<name>.env`, give that file **its own ports**, then `./fakevps -p <name> up`.

### Attach a bot

```bash
cp secrets/discord.env.example secrets/discord.env
# set DISCORD_TOKEN=… (never commit this file)

./fakevps attach ~/MyBot
```

Or click **Browse** / **Parcourir** in the cockpit's Bot tile and pick the folder — no path typing, no quoting issues.

If `BOT_DIR` is already set in `config.env` and `AUTO_DEPLOY=true` (the default), the next `up` also deploys that bot. Set `AUTO_DEPLOY=false` if `up` should boot a bare node and leave start to `attach`.

- **`.env` injection** — attach copies `BOT_DIR/.env` if present, then overlays non-empty keys from `secrets/discord.env`. The guest file is `/home/ubuntu/app/.env` (mode `600`). The cockpit only ever shows token **present/absent**, never the value. If a required key is missing (`DATABASE_URL`, Compose variables…), the deploy stops early with the exact list. On `--fast`, loopback URLs (`localhost` / `127.0.0.1`) are rewritten to the host compose service that publishes that port, and the node joins that Docker network. The host `.env` is not modified.
- **Runtime detection** (first match wins): `fakevps.bot.yml` → Compose → Dockerfile → Node → Python. Copy [examples/fakevps.bot.yml](examples/fakevps.bot.yml) into the bot repo and uncomment what you need. A typical override:

```yaml
runtime: compose          # or node | docker | python | auto
compose_file: docker-compose.yml
fallback: none            # node = allow compose then Node (opt-in)
start: npm start
panel:
  start: npm run panel   # optional; needs BOT_PANEL_PORT
```

  A compose file that fails (or has no `bot`/`worker`/`discord` container) does **not** start Node unless `fallback: node` (or `runtime: node`) is set.
- **Monorepos** — the root `build:ci` / `build` script is used so workspace packages compile in order. If the build fails, no service is installed and `attach` reports the failure.
- Set `BOT_PANEL_PORT=3000` in `config.env` to forward the bot's own web UI on `http://127.0.0.1:3000`. The guest process starts only if `fakevps.bot.yml` also has `panel.start` (otherwise the forward stays idle). After attach, the guest waits for a process that survives its first seconds; a crash-loop prints the journal tail and fails the deploy.

### Cockpit

`./fakevps ui` or [http://127.0.0.1:8787](http://127.0.0.1:8787) — `ui` appends a session token; do not share that URL.

- Power controls, node envelope, live telemetry (guest only — never the host PC)
- SSH command with copy / open-terminal buttons
- Health LEDs (SSH, Docker, Bot, Cockpit, guest containers)
- Bot tile: Browse, attach, sync, restart, bot logs
- Journal (live deploy stream) plus a diagnostic dialog with copy-able fixes
- FR/EN (browser language, header toggle)
- Fast-backend banner when `--fast` is active

### Configuration (`config.env`)

| Key | Default | Meaning |
|-----|---------|---------|
| `BACKEND` | `fast` | `fast` (default, privileged Docker) or `kvm` |
| `RAM_MB` / `CPUS` / `DISK_GB` | `6144` / `4` / `40` | Node envelope |
| `SSH_PORT` / `UI_PORT` | `2222` / `8787` | Host ports (loopback) |
| `BOT_DIR` | empty | Attached bot folder (set by `attach`) |
| `BOT_RUNTIME` | `auto` | Force `compose`/`docker`/`node`/`python` |
| `BOT_PANEL_PORT` | empty | Forward the bot's web UI (`panel.start` starts the process) |
| `AUTO_DEPLOY` | `true` | If `BOT_DIR` is set, `up` deploys the bot. `false` = bare node until `attach` |
| `EPHEMERAL` | `false` | `true` = every `down` erases all stored state |

**Ephemeral mode** — with `EPHEMERAL=true` (or `./fakevps down --wipe`), shutdown deletes the guest disk (bot code and injected `.env` included), the fast Docker graph, logs and caches. Only `secrets/` and the host SSH key remain. The next `up` re-provisions from scratch.

### Security & privacy

- Everything binds `127.0.0.1`. The cockpit refuses non-loopback hosts and cross-site POSTs.
- The author collects **nothing**: no analytics, no phone-home, no external fonts. Tokens stay on your machine.
- `--fast` is the **default** and runs a **privileged** container — near host-root. Prefer `./fakevps up --kvm` when isolation matters.
- Never commit `secrets/discord.env`, `config.env`, or `state/`. The public artifact is the git repository, not a zip of the working folder.

Details: [SECURITY.md](SECURITY.md).

### License and forks

Custom terms — see [LICENSE](LICENSE).

- **Allowed:** use, copy, modify, run, including commercial projects — on **your** fork or private copy.
- **This repository:** public snapshot. It will not be modified. Open your own repo; do not treat this one as an upstream.
- **Asked, not required:** keep a trace of the original project. If you mention it, use `Based on FakeVPS — https://github.com/Mr-Aurevo-X/FakeVPS` as-is — no extra wording on that line. You may add your own notice below.

Copyright (c) 2026 **Mr-Aurevo-X**.

---

## Français

### Mot de Mr-Aurevo-X

J'ai écrit FakeVPS en août 2026 sur CachyOS, dans [Cursor](https://cursor.com), parce que je voulais un nœud Ubuntu local qui ait l'air d'un VPS pas cher — SSH, systemd, Docker — pour répéter le déploiement d'un bot Discord avant de payer une machine. C'est ma façon de travailler : Cursor construit, je fais la QA. Cet arbre est l'instantané que je mets sur internet. Je ne modifierai plus **ce** dépôt. Forkez-le sur votre GitHub, cassez-le, reconstruisez-le. Si vous citez l'origine, laissez cette ligne telle quelle : `Based on FakeVPS — https://github.com/Mr-Aurevo-X/FakeVPS`. Merci d'en garder une trace.

— [Mr-Aurevo-X](https://github.com/Mr-Aurevo-X)

### Fonctionnement

Une CLI (`./fakevps`), deux moteurs, mêmes ports :

- `./fakevps up` — guest **Docker privilégié** (`--fast`, le défaut). Plus rapide. Le disque est le graph Docker sur l'hôte (enveloppe, pas une partition 40 Go). Quasi root hôte — machine à toi uniquement.
- `./fakevps up --kvm` — guest **KVM/QEMU**. Isolation maximale, nécessite `/dev/kvm`.

```mermaid
flowchart LR
    Toi[Toi] --> CLI["CLI ./fakevps"]
    CLI --> Fast["Guest Docker (up)"]
    CLI --> KVM["Guest KVM (up --kvm)"]
    KVM --> Guest["Ubuntu 24.04 · SSH · systemd · Docker"]
    Fast --> Guest
    Guest --> Cockpit["Cockpit 127.0.0.1:8787"]
    Guest --> SSH["SSH 127.0.0.1:2222"]
```

Tout écoute en **127.0.0.1 uniquement** : cockpit sur `8787`, SSH sur `2222`, panneau du bot optionnel sur `BOT_PANEL_PORT`. Rien sur `0.0.0.0`.

### Linux

Prérequis : Docker pour le moteur par défaut, ou QEMU/KVM (`/dev/kvm`) pour `--kvm`. Lance `./fakevps doctor` avant le premier `up`.

```bash
cp config.env.example config.env
./fakevps doctor
./fakevps up          # fast (Docker privilégié, défaut)
# ou
./fakevps up --kvm    # guest KVM
```

### Windows

FakeVPS tourne dans **WSL2 + Ubuntu** (pas dans une VM Linux VirtualBox/Hyper-V). Le `./fakevps up` par défaut a besoin de **Docker dans cette distro WSL**.

1. Donne assez de RAM à WSL2 (le nœud veut 6 Go, prévoit ~8 Go pour WSL) dans `%UserProfile%\.wslconfig` :

   ```ini
   [wsl2]
   memory=8GB
   ```

2. Clone le dépôt dans le système de fichiers WSL et suis les étapes Linux.
3. Le défaut est déjà `./fakevps up` (`--fast`). `--kvm` seulement si `/dev/kvm` est disponible.
4. Aide optionnelle côté Windows : `contrib/fakevps.bat` (lance la CLI Linux dans WSL).

### Commandes

| Commande | Rôle |
|----------|------|
| `./fakevps up [--fast|--kvm]` | Démarrer le nœud et le cockpit (défaut : fast) |
| `./fakevps down [--wipe]` | Tout arrêter ; `--wipe` efface tout l'état stocké |
| `./fakevps status [--json]` | Moteur, SSH, cockpit, état du bot |
| `./fakevps logs` | Dernières lignes des journaux hôte / série / conteneur fast |
| `./fakevps ssh [-- cmd]` | Shell dans le guest |
| `./fakevps ui` | Ouvrir le cockpit (jeton de session dans l'URL) |
| `./fakevps attach <dossier>` | Attacher un dossier de bot et le déployer |
| `./fakevps sync` | Re-rsync de l'arbre du bot |
| `./fakevps restart-bot` | Relancer le bot dans le guest (systemd ou Compose) |
| `./fakevps panel` | Ouvrir l'UI web du bot si `BOT_PANEL_PORT` est défini |
| `./fakevps metrics` | Télémétrie du guest en JSON |
| `./fakevps reset` | Effacer disque/conteneur ; le prochain `up` repart de zéro |
| `./fakevps snapshot list\|save\|restore\|rm <nom>` | Snapshots qcow2 du disque du nœud (kvm, nœud arrêté) |
| `./fakevps doctor` | Vérifier l'hôte (KVM, Docker, RAM, disque, ports) avant le premier `up` |
| `./fakevps audit` | Vérifier permissions des secrets et hygiène git |
| `./fakevps --version` | Afficher version, copyright, URL d'origine |
| `./fakevps -p <nom> <cmd>` | Lancer avec le profil `profiles/<nom>.env` (état et ports séparés) |
| `./fakevps install-service [--fast\|--kvm]` | Unité systemd utilisateur (auto-démarrage) |

Profils : copie [profiles/example.env.example](profiles/example.env.example) vers `profiles/<nom>.env`, mets **des ports à toi**, puis `./fakevps -p <nom> up`.

### Attacher un bot

```bash
cp secrets/discord.env.example secrets/discord.env
# DISCORD_TOKEN=… (ne jamais commiter ce fichier)

./fakevps attach ~/MonBot
```

Ou clique **Parcourir** / **Browse** dans la tuile Bot du cockpit et choisis le dossier — pas de chemin à taper, pas de souci d'espaces.

Si `BOT_DIR` est déjà dans `config.env` et `AUTO_DEPLOY=true` (le défaut), le prochain `up` déploie aussi ce bot. Mets `AUTO_DEPLOY=false` si `up` doit juste allumer un nœud nu et laisser `attach` démarrer le bot.

- **Injection `.env`** — `attach` copie `BOT_DIR/.env` s'il existe, puis surcharge avec les clés non vides de `secrets/discord.env`. Côté guest : `/home/ubuntu/app/.env` (mode `600`). Le cockpit affiche seulement jeton **présent/absent**, jamais la valeur. S'il manque une clé requise (`DATABASE_URL`, variables Compose…), le déploiement s'arrête tôt avec la liste exacte. En `--fast`, les URL en loopback (`localhost` / `127.0.0.1`) sont réécrites vers le service compose hôte qui publie ce port, et le nœud rejoint ce réseau Docker. Le `.env` hôte n'est pas modifié.
- **Détection du runtime** (premier match gagnant) : `fakevps.bot.yml` → Compose → Dockerfile → Node → Python. Copie [examples/fakevps.bot.yml](examples/fakevps.bot.yml) dans le repo du bot et décommente ce qu'il faut. Surcharge typique :

```yaml
runtime: compose          # ou node | docker | python | auto
compose_file: docker-compose.yml
fallback: none            # node = autoriser compose puis Node (opt-in)
start: npm start
panel:
  start: npm run panel   # optionnel ; nécessite BOT_PANEL_PORT
```

  Un Compose qui échoue (ou sans conteneur `bot`/`worker`/`discord`) **ne lance pas** Node, sauf `fallback: node` (ou `runtime: node`).
- **Monorepos** — le script racine `build:ci` / `build` compile les packages workspace dans l'ordre. Si le build échoue, aucun service n'est installé et `attach` remonte l'échec.
- Mets `BOT_PANEL_PORT=3000` dans `config.env` pour forwarder l'UI web du bot sur `http://127.0.0.1:3000`. Le process guest ne part que si `fakevps.bot.yml` a aussi `panel.start` (sinon le forward reste vide). Après `attach`, le guest attend un process qui survit aux premières secondes ; une boucle de crash affiche la fin du journal et échoue le déploiement.

### Cockpit

`./fakevps ui` ou [http://127.0.0.1:8787](http://127.0.0.1:8787) — `ui` ajoute un jeton de session ; ne partage pas cette URL.

- Alimentation, enveloppe du nœud, télémétrie en direct (guest uniquement — jamais le PC hôte)
- Commande SSH avec boutons copier / ouvrir un terminal
- LEDs de santé (SSH, Docker, Bot, Cockpit, conteneurs du guest)
- Tuile Bot : parcourir, attacher, synchroniser, relancer, logs du bot
- Journal (flux de déploiement en direct) et fenêtre de diagnostic avec correctifs copiables
- FR/EN (langue du navigateur, bascule dans l'en-tête)
- Bandeau du moteur fast quand `--fast` est actif

### Configuration (`config.env`)

| Clé | Défaut | Rôle |
|-----|--------|------|
| `BACKEND` | `fast` | `fast` (défaut, Docker privilégié) ou `kvm` |
| `RAM_MB` / `CPUS` / `DISK_GB` | `6144` / `4` / `40` | Enveloppe du nœud |
| `SSH_PORT` / `UI_PORT` | `2222` / `8787` | Ports hôte (loopback) |
| `BOT_DIR` | vide | Dossier du bot attaché (rempli par `attach`) |
| `BOT_RUNTIME` | `auto` | Forcer `compose`/`docker`/`node`/`python` |
| `BOT_PANEL_PORT` | vide | Exposer l'UI web du bot (`panel.start` lance le process) |
| `AUTO_DEPLOY` | `true` | Si `BOT_DIR` est défini, `up` déploie le bot. `false` = nœud nu jusqu'à `attach` |
| `EPHEMERAL` | `false` | `true` = chaque `down` efface tout l'état stocké |

**Mode éphémère** — avec `EPHEMERAL=true` (ou `./fakevps down --wipe`), l'extinction supprime le disque du guest (code du bot et `.env` injecté compris), le graph Docker du mode fast, les journaux et les caches. Seuls `secrets/` et la clé SSH de l'hôte restent. Le prochain `up` re-provisionne tout.

### Sécurité et vie privée

- Tout écoute sur `127.0.0.1`. Le cockpit refuse les hôtes non-loopback et les POST cross-site.
- L'auteur **ne collecte rien** : pas d'analytics, pas d'appel réseau caché, pas de polices externes. Les jetons restent sur ta machine.
- `--fast` est le **défaut** et lance un conteneur **privilégié** — quasi root sur l'hôte. Préfère `./fakevps up --kvm` quand l'isolation compte.
- Ne commite jamais `secrets/discord.env`, `config.env` ni `state/`. L'artefact public est le dépôt git, pas un zip du dossier de travail.

Détails : [SECURITY.md](SECURITY.md).

### Licence et forks

Termes personnalisés — voir [LICENSE](LICENSE).

- **Autorisé :** utiliser, copier, modifier, exécuter, y compris en commercial — sur **votre** fork ou copie privée.
- **Ce dépôt :** instantané public. Il ne sera plus modifié. Ouvrez le vôtre ; ne traitez pas celui-ci comme un upstream.
- **Demandé, pas obligatoire :** garder une trace du projet d'origine. Si vous le citez, utilisez `Based on FakeVPS — https://github.com/Mr-Aurevo-X/FakeVPS` telle quelle — sans rien ajouter sur cette ligne. Vous pouvez mettre votre mention en dessous. Merci d'en garder une trace.

Copyright (c) 2026 **Mr-Aurevo-X**.
