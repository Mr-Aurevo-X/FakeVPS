# FakeVPS

Start/stop a local Ubuntu node that behaves like a mid-range paid VPS (6 GB / 4 vCPU, SSH, systemd, Docker **inside** the guest). Rehearse a real deploy before you buy the box.

Multipass gives you a VM. FakeVPS rehearses the VPS you would pay for — plus a localhost cockpit.

No Discord bot is bundled. Attach **any** bot (Node, Python, Compose) when you want.

## Quick start (Linux)

```bash
cp config.env.example config.env
./fakevps up          # KVM (needs /dev/kvm)
# or
./fakevps up --fast   # Docker systemd guest
```

Cockpit: [http://127.0.0.1:8787](http://127.0.0.1:8787)

```text
./fakevps down
./fakevps status
./fakevps ssh
./fakevps attach /path/to/your-bot
```

Optional systemd user unit (survives closing the terminal):

```bash
./fakevps install-service
systemctl --user enable --now fakevps
```

## Attach a Discord bot

```bash
cp secrets/discord.env.example secrets/discord.env
# set DISCORD_TOKEN=...

./fakevps attach ~/my-bot
```

Auto-detect order: `fakevps.bot.yml` → Compose → Dockerfile → Node → Python.  
If nothing matches, the tree is copied to `/home/ubuntu/app` and you finish over SSH.

Optional web UI inside the bot:

```bash
# in config.env
BOT_PANEL_PORT=3000
```

Then `./fakevps panel` opens `http://127.0.0.1:3000`. Copy [examples/fakevps.bot.yml](examples/fakevps.bot.yml) into the bot repo to override detection.

## Windows

Use **WSL2 + Ubuntu**, not a VirtualBox/Hyper-V Linux VM.

```bash
# inside WSL
./fakevps up --fast
```

The Windows browser can open `http://127.0.0.1:8787`. Optional launcher: `contrib/fakevps.bat`.

Give WSL enough RAM in `%UserProfile%\.wslconfig` (this node wants 6 GB).

## Ports (localhost only)

| Port | What |
|------|------|
| 8787 | FakeVPS cockpit |
| 2222 | SSH (`ubuntu@127.0.0.1`) |
| `BOT_PANEL_PORT` | Optional bot web UI |

Nothing binds `0.0.0.0`.

## Français

Programme local pour répéter un VPS payant avant l’achat. `./fakevps up` démarre le nœud et le cockpit. Branche n’importe quel bot Discord avec `./fakevps attach`. Sous Windows : WSL2, pas une VM Linux.

## License

MIT
