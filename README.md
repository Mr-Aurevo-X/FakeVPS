# FakeVPS

**Based on FakeVPS — https://github.com/Mr-Aurevo-X/FakeVPS**

A **Mr-Aurevo-X** tool: start and stop a **local** Ubuntu node that behaves like a mid-range paid VPS (6 GB RAM / 4 vCPU / 40 GB disk, SSH, systemd, Docker **inside** the guest). Rehearse a real deploy on your machine before you rent a box.

The cockpit is [http://127.0.0.1:8787](http://127.0.0.1:8787). Traffic-light status: **green = online** (never brand-red for “online”).

No Discord bot is bundled. Attach **any** bot (Node, Python, Compose, Dockerfile) when you want.

The GitHub repo is **private for now**. This README is for people who already have the tree — not a public “clone and go” campaign.

---

## English

### What it is

FakeVPS is a **localhost rehearsal**, not a cloud product and not a hosted panel.

- **KVM** (`./fakevps up`): QEMU/KVM guest when `/dev/kvm` is available. Closest to a cheap VPS.
- **`--fast`** (`./fakevps up --fast`): privileged Docker guest with systemd. Same SSH port and cockpit, quicker iteration. Default path on **WSL2**.

Both backends expose SSH on `127.0.0.1:2222` and the cockpit on `127.0.0.1:8787`.

### Requirements

- **Linux** (native) or **Windows via WSL2 + Ubuntu**. Do not run this inside a VirtualBox/Hyper-V Linux VM and expect KVM/`--fast` to feel native.
- On WSL2, give the distro enough RAM (this node wants 6 GB) in `%UserProfile%\.wslconfig`.
- Optional Windows helper: `contrib/fakevps.bat` (still runs the Linux CLI inside WSL).

### Quick start

```bash
cp config.env.example config.env
./fakevps up          # KVM (needs /dev/kvm)
# or
./fakevps up --fast   # Docker systemd guest
```

Then:

```text
./fakevps down
./fakevps status
./fakevps status --json
./fakevps ssh
./fakevps ui
./fakevps attach "~/Discord Bot/MyBot"
./fakevps sync
./fakevps restart-bot
```

Optional systemd **user** unit (survives closing the terminal):

```bash
./fakevps install-service
systemctl --user enable --now fakevps
```

### Ports (127.0.0.1 only)

| Port | What |
|------|------|
| 8787 | FakeVPS cockpit |
| 2222 | SSH (`ssh -p 2222 ubuntu@127.0.0.1`) |
| `BOT_PANEL_PORT` | Optional bot web UI, if you set it in `config.env` |

Nothing is supposed to bind `0.0.0.0`. See [SECURITY.md](SECURITY.md).

### Attach any Discord bot

```bash
cp secrets/discord.env.example secrets/discord.env
# set DISCORD_TOKEN=…  (never commit this file)

./fakevps attach "~/Discord Bot/MyBot"
```

Paths with spaces are fine if you quote them.

**Inject `.env`:** attach copies `BOT_DIR/.env` if present, then overlays **non-empty** keys from `secrets/discord.env`. The guest file is `/home/ubuntu/app/.env` (mode `600`). The cockpit only shows whether a token is **present** or **absent** — never the value.

**Runtime detection** (first match wins): `fakevps.bot.yml` → Compose → Dockerfile → Node → Python. If nothing matches, the tree is copied to `/home/ubuntu/app` and you finish over SSH.

Copy [examples/fakevps.bot.yml](examples/fakevps.bot.yml) into the bot repo to override detection (`runtime`, `compose_file`, `start`, `panel_port`).

Optional web UI inside the bot:

```bash
# in config.env
BOT_PANEL_PORT=3000
```

Then `./fakevps panel` opens `http://127.0.0.1:3000`.

Cockpit **Bot** tile: attach a folder, **Synchroniser** (`./fakevps sync`), **Relancer** (`./fakevps restart-bot` — systemd `discord-bot` or `docker compose restart` in the guest, no extra rsync).

### Cockpit

Open [http://127.0.0.1:8787](http://127.0.0.1:8787) or run `./fakevps ui`.

- Power, node envelope (6 GB / 4 vCPU / 40 GB), live telemetry (guest only, not the host PC)
- SSH command, copy, open a local terminal
- Health LEDs (SSH, Docker, Bot, Cockpit, plus guest containers)
- Activity journal and a diagnostic dialog with copy-able commands

### License (not MIT)

See [LICENSE](LICENSE). Custom terms.

**Allowed:** use, copy, modify, run — including private or commercial projects — if you keep the credit and the origin link.

**Forbidden:** strip or hide the Mr-Aurevo-X credit; present FakeVPS as your own product; replace the origin URL with only a fork URL.

**Forks must** keep the credit **and** the origin link in the **same three places**: cockpit footer, CLI help (`./fakevps --help`), and README:

`Based on FakeVPS — https://github.com/Mr-Aurevo-X/FakeVPS`

A fork may add its own line **below**. It may not remove the origin link.

Copyright (c) 2026 **Mr-Aurevo-X**.

### Privacy

The author collects **nothing**. No backdoor, no phone-home, no analytics, no Google Fonts. Tokens stay on your machine. Details: [SECURITY.md](SECURITY.md).

### Secrets and git

Never commit `secrets/discord.env`, `config.env`, or `state/`. Examples (`*.example`) are safe to keep.

---

## Français

**Based on FakeVPS — https://github.com/Mr-Aurevo-X/FakeVPS**

Outil **Mr-Aurevo-X** : démarrer et arrêter un nœud Ubuntu **local** qui se comporte comme un VPS payant milieu de gamme (6 Go / 4 vCPU / 40 Go, SSH, systemd, Docker **dans** le guest). Tu répètes un vrai déploiement chez toi avant de louer la machine.

Cockpit : [http://127.0.0.1:8787](http://127.0.0.1:8787). Feux tricolores : **vert = en ligne** (jamais le rouge de la marque pour « en ligne »).

Aucun bot Discord n’est fourni. Tu attaches **n’importe quel** bot (Node, Python, Compose, Dockerfile).

Le dépôt GitHub est **privé pour le moment**. Ce README s’adresse à qui a déjà l’arbre — ce n’est pas une invitation à cloner en public.

### À quoi ça sert

FakeVPS est une **répétition localhost**, pas un produit cloud ni un panneau hébergé.

- **KVM** (`./fakevps up`) : guest QEMU/KVM si `/dev/kvm` est là. Le plus proche d’un VPS cheap.
- **`--fast`** (`./fakevps up --fast`) : guest Docker privilégié avec systemd. Mêmes ports SSH/cockpit, itération plus rapide. Chemin par défaut sous **WSL2**.

### Prérequis

- **Linux** natif, ou **Windows via WSL2 + Ubuntu**. Pas une VM Linux VirtualBox/Hyper-V.
- Sous WSL2, prévois assez de RAM (6 Go pour ce nœud) dans `%UserProfile%\.wslconfig`.
- Aide Windows optionnelle : `contrib/fakevps.bat`.

### Démarrage rapide

```bash
cp config.env.example config.env
./fakevps up          # KVM
# ou
./fakevps up --fast   # guest Docker + systemd
```

Puis `./fakevps down`, `status`, `ssh`, `ui`, `attach "~/Discord Bot/MyBot"`, `sync`, `restart-bot`.

Service systemd **utilisateur** :

```bash
./fakevps install-service
systemctl --user enable --now fakevps
```

### Ports (127.0.0.1 uniquement)

| Port | Rôle |
|------|------|
| 8787 | Cockpit FakeVPS |
| 2222 | SSH (`ssh -p 2222 ubuntu@127.0.0.1`) |
| `BOT_PANEL_PORT` | UI web du bot, si tu la configures |

Rien n’est censé écouter sur `0.0.0.0`. Voir [SECURITY.md](SECURITY.md).

### Attacher un bot Discord

```bash
cp secrets/discord.env.example secrets/discord.env
# DISCORD_TOKEN=…  (ne jamais commiter ce fichier)

./fakevps attach "~/Discord Bot/MyBot"
```

Les chemins avec espaces passent s’ils sont quotés.

**Injection `.env` :** copie de `BOT_DIR/.env` s’il existe, puis surcharge des clés **non vides** de `secrets/discord.env`. Côté guest : `/home/ubuntu/app/.env` (mode `600`). Le cockpit affiche seulement jeton **présent** / **absent**.

**Détection** : `fakevps.bot.yml` → Compose → Dockerfile → Node → Python. Sinon l’arbre est copié dans `/home/ubuntu/app` et tu finis en SSH.

Manifeste optionnel : [examples/fakevps.bot.yml](examples/fakevps.bot.yml).

Tuile **Bot** du cockpit : attacher, **Synchroniser**, **Relancer** (systemd ou `docker compose restart`, sans rsync).

### Cockpit

[http://127.0.0.1:8787](http://127.0.0.1:8787) ou `./fakevps ui`. Alimentation, enveloppe du nœud, télémétrie du **guest** (pas le PC hôte), SSH, santé, journal, diagnostic.

### Licence (pas MIT)

Voir [LICENSE](LICENSE).

**Autorisé :** utiliser, copier, modifier, exécuter — y compris un projet privé ou commercial — en gardant le crédit et le lien d’origine.

**Interdit :** retirer ou cacher le crédit Mr-Aurevo-X ; présenter FakeVPS comme ton produit ; remplacer l’URL d’origine par seulement l’URL du fork.

**Tout fork doit** garder le crédit **et** le lien d’origine aux **trois mêmes endroits** : pied du cockpit, aide CLI, README :

`Based on FakeVPS — https://github.com/Mr-Aurevo-X/FakeVPS`

Un fork peut ajouter sa ligne **en dessous**. Il ne peut pas retirer le lien d’origine.

Copyright (c) 2026 **Mr-Aurevo-X**.

### Vie privée

L’auteur **ne collecte rien**. Pas de backdoor, pas d’appel réseau caché, pas de Google Fonts. Les jetons restent sur ta machine. Détails : [SECURITY.md](SECURITY.md).

### Secrets et git

Ne commite jamais `secrets/discord.env`, `config.env`, ni `state/`.
