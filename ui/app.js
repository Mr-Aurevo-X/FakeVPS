/* FakeVPS — Mr-Aurevo-X. Copyright (c) 2026 Mr-Aurevo-X */

const $ = (id) => document.getElementById(id);

function setHealth(id, state) {
  const el = $(id);
  el.classList.remove("ok", "warn");
  if (state === "ok") el.classList.add("ok");
  if (state === "warn") el.classList.add("warn");
  const label = $(`${id}-state`);
  if (label) {
    label.textContent = state === "ok" ? "ready" : state === "warn" ? "booting" : "off";
  }
}

function fmtUptime(sec) {
  const n = Number(sec) || 0;
  if (!n) return "—";
  const h = Math.floor(n / 3600);
  const m = Math.floor((n % 3600) / 60);
  return `${h}h ${m}m`;
}

async function api(path, opts) {
  const res = await fetch(path, opts);
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || res.statusText);
  return data;
}

function activityText(s) {
  return String(s.activity || s.error || $("log").textContent || "");
}

function diagnose(s) {
  const issues = [];
  const log = activityText(s).toLowerCase();
  const botDir = String(s.bot_dir || "");
  const starting = Boolean(s.starting);
  const online = Boolean(s.running && s.ssh);
  const booting = Boolean(starting || (s.running && !s.ssh));

  if (s.diag_error) {
    issues.push({
      id: "api",
      level: "off",
      title: "Le cockpit n’arrive pas à lire le nœud",
      detail: s.diag_error,
      fix: "Vérifie que FakeVPS tourne encore :\ncd ~/Documents/FakeVPS\n./fakevps ui",
    });
  }
  if (!s.running && !starting) {
    issues.push({
      id: "offline",
      level: "off",
      title: "Le VPS est éteint",
      detail: "Rien n’écoute en SSH. Start ici, ou en terminal.",
      fix: "./fakevps up --fast",
    });
  }
  if (booting) {
    issues.push({
      id: "booting",
      level: "warn",
      title: "Le nœud démarre",
      detail: "Le conteneur/VM est là, SSH pas encore prêt. Attends 30–60 s.",
      fix: "./fakevps status\n./fakevps logs",
    });
  }
  if (s.ssh && !s.docker) {
    issues.push({
      id: "docker",
      level: "warn",
      title: "Docker n’est pas prêt dans le guest",
      detail: "SSH répond, mais le moteur Docker du VPS n’est pas là. Le premier provision a peut‑être planté (swap, réseau).",
      fix: "./fakevps ssh -- 'command -v docker || echo missing'\nPuis relance ./fakevps up --fast",
    });
  }
  const botStuck = Boolean(botDir && !s.bot);
  const lookAtLog = !s.bot || Boolean(s.diag_error);

  if (lookAtLog && (log.includes("aucun fichier ou dossier") || (botDir.includes(" ") && log.includes("config.env")))) {
    issues.push({
      id: "path-space",
      level: "off",
      title: "Le chemin du bot a un espace",
      detail: "Bash coupe BOT_DIR au premier espace (ex. Discord Bot). N’attache pas ce chemin tel quel.",
      fix: "ln -sfn \"/chemin/avec espace/Bot\" ~/mon-bot\n./fakevps attach ~/mon-bot",
    });
  }
  if (lookAtLog && (log.includes("discord_token missing") || log.includes("no secrets/discord.env"))) {
    issues.push({
      id: "token",
      level: "off",
      title: "DISCORD_TOKEN manquant",
      detail: "Le code est copié, le bot ne démarre pas sans token.",
      fix: "Édite secrets/discord.env et mets DISCORD_TOKEN=…\n./fakevps ssh -- rm -f /home/ubuntu/app/.env\n./fakevps attach ~/ton-bot",
    });
  }
  if (lookAtLog && log.includes("already present") && log.includes(".env")) {
    issues.push({
      id: "stale-env",
      level: "warn",
      title: "Un vieux .env bloque l’inject",
      detail: "Le guest a déjà /home/ubuntu/app/.env. FakeVPS fusionne maintenant à chaque attach ; si le log est ancien, rattache.",
      fix: "./fakevps ssh -- rm -f /home/ubuntu/app/.env\n./fakevps attach ~/ton-bot",
    });
  }
  if (lookAtLog && (log.includes("required variable") || log.includes("is missing a value"))) {
    issues.push({
      id: "compose-env",
      level: "off",
      title: "Il manque une variable Compose",
      detail: "docker compose a arrêté le déploiement (souvent LAVALINK_PASSWORD, POSTGRES_PASSWORD, NEXTAUTH_SECRET).",
      fix: "Recopie le .env complet du bot dans secrets/discord.env\n./fakevps ssh -- rm -f /home/ubuntu/app/.env\n./fakevps attach ~/ton-bot",
    });
  }
  if (lookAtLog && (log.includes("whiteout") || log.includes("operation not permitted"))) {
    issues.push({
      id: "dind",
      level: "off",
      title: "Docker imbriqué refuse d’extraire une image",
      detail: "Overlay-sur-overlay (ou btrfs). Le nœud fast doit avoir son graph Docker sur l’hôte.",
      fix: "./fakevps down\n./fakevps up --fast\n./fakevps attach ~/ton-bot",
    });
  }
  if (botStuck && (log.includes("didn't complete successfully") || log.includes("migrate"))) {
    issues.push({
      id: "migrate",
      level: "warn",
      title: "La migrate Compose a échoué",
      detail: "L’image prod n’a parfois pas Prisma. FakeVPS bascule alors sur l’infra + systemd. Si le bot est encore rouge, regarde les logs.",
      fix: "./fakevps ssh -- 'journalctl -u discord-bot -n 40 --no-pager'",
    });
  }
  if (online && !botDir) {
    issues.push({
      id: "no-bot",
      level: "warn",
      title: "Aucun bot n’est attaché",
      detail: "Le VPS est vide. Attache un dossier. S’il y a un espace dans le chemin, passe par un lien.",
      fix: "ln -sfn \"/chemin/Discord Bot/MonBot\" ~/mon-bot\n./fakevps attach ~/mon-bot",
    });
  }
  if (online && botDir && !s.bot) {
    issues.push({
      id: "bot-down",
      level: "off",
      title: "Le bot est attaché mais pas lancé",
      detail: "Le dossier est connu, aucun process bot/worker. Token, Compose ou systemd.",
      fix: "./fakevps attach " + botDir + "\n./fakevps ssh -- 'systemctl status discord-bot --no-pager; docker ps'",
    });
  }
  if (log.includes("ubuntu@fakevps") && log.includes("./fakevps")) {
    issues.push({
      id: "inside-guest",
      level: "warn",
      title: "Tu es dans le VPS, pas sur l’hôte",
      detail: "Le prompt ubuntu@fakevps veut dire guest. ./fakevps attach se lance depuis ~/Documents/FakeVPS.",
      fix: "exit\ncd ~/Documents/FakeVPS\n./fakevps attach ~/ton-bot",
    });
  }
  if (!issues.length) {
    issues.push({
      id: "ok",
      level: "ok",
      title: "Rien à signaler",
      detail: "Nœud en ligne. Les feux Health sont verts, ou le nœud attend juste un bot.",
      fix: "Cockpit http://127.0.0.1:8787\nSSH : ./fakevps ssh",
    });
  }
  return issues;
}

function renderDiag(issues) {
  const bad = issues.filter((i) => i.level !== "ok");
  const worst = issues.some((i) => i.level === "off")
    ? "off"
    : issues.some((i) => i.level === "warn")
      ? "warn"
      : "ok";
  $("diag-kicker").textContent = "Diagnostic";
  $("diag-title").textContent = bad.length
    ? `${bad.length} point${bad.length > 1 ? "s" : ""} à régler`
    : "Tout est bon";
  $("diag-lead").textContent = worst === "ok"
    ? "Aucun blocage détecté sur le nœud ou le bot."
    : "Voici ce qui cloche, et la commande pour le débloquer.";
  const list = $("diag-list");
  list.replaceChildren();
  for (const issue of issues) {
    const li = document.createElement("li");
    li.className = `diag-item ${issue.level}`;
    const h = document.createElement("h3");
    h.textContent = issue.title;
    const p = document.createElement("p");
    p.textContent = issue.detail;
    const pre = document.createElement("pre");
    pre.textContent = issue.fix;
    li.append(h, p, pre);
    list.append(li);
  }
  $("btn-diag").textContent = bad.length ? `Diagnostic (${bad.length})` : "Diagnostic";
}

let dismissedKey = "";
let lastOpenedKey = "";

function issueKey(issues) {
  return issues.filter((i) => i.level !== "ok").map((i) => i.id).join("|");
}

function openDiag() {
  const el = $("diag");
  if (!el.open) el.showModal();
}

function syncDialog(s, forceOpen) {
  const issues = diagnose(s);
  renderDiag(issues);
  const key = issueKey(issues);
  const bad = Boolean(key);
  if (forceOpen) {
    openDiag();
    lastOpenedKey = key;
    return;
  }
  if (bad && key !== dismissedKey && key !== lastOpenedKey) {
    openDiag();
    lastOpenedKey = key;
  }
}

function render(s) {
  const starting = Boolean(s.starting);
  const online = Boolean(s.running && s.ssh);
  const booting = Boolean(starting || (s.running && !s.ssh));
  document.body.classList.toggle("is-online", online && !starting);
  document.body.classList.toggle("is-booting", booting);
  document.body.classList.toggle("is-offline", !online && !booting);
  $("btn-up").classList.toggle("idle-glow", !online && !booting);
  $("pill").classList.toggle("online", online && !starting);
  $("pill").classList.toggle("booting", booting);
  $("pill").classList.toggle("offline", !online && !booting);
  $("pill-label").textContent = starting
    ? "starting"
    : online
      ? "online"
      : s.running
        ? "booting"
        : "offline";
  $("uptime").textContent = fmtUptime(s.uptime_sec);
  $("m-ram").textContent = `${Math.round((s.ram_mb || 0) / 1024)} GB`;
  $("m-cpu").textContent = String(s.cpus || 4);
  $("m-disk").textContent = `${s.disk_gb || 40} GB`;
  $("m-be").textContent = s.backend || "—";
  $("ssh-cmd").textContent = `ssh -p ${s.ssh_port || 2222} ubuntu@127.0.0.1`;
  setHealth("h-ssh", s.ssh ? "ok" : s.running ? "warn" : "off");
  setHealth("h-docker", s.docker ? "ok" : s.ssh ? "warn" : "off");
  setHealth("h-bot", s.bot ? "ok" : s.bot_dir ? "warn" : "off");
  setHealth("h-ui", s.ui ? "ok" : "off");
  if (s.panel_port) {
    $("panel-msg").classList.add("hidden");
    $("panel-link").classList.remove("hidden");
    $("panel-link").href = `http://127.0.0.1:${s.panel_port}`;
  } else {
    $("panel-msg").classList.remove("hidden");
    $("panel-link").classList.add("hidden");
  }
  const botDir = s.bot_dir || "";
  if (botDir) {
    $("bot-hint").classList.add("hidden");
    $("bot-attached").classList.remove("hidden");
    $("bot-dir").textContent = botDir;
  } else {
    $("bot-hint").classList.remove("hidden");
    $("bot-attached").classList.add("hidden");
  }
  if (s.activity) {
    $("log").textContent = s.activity;
  } else if (starting) {
    $("log").textContent = "starting…";
  }
  syncDialog(s, Boolean(s.force_diag));
}

async function refresh() {
  try {
    const s = await api("/api/status");
    render(s);
  } catch (err) {
    const msg = String(err.message || err);
    $("log").textContent = msg;
    syncDialog({ diag_error: msg, activity: msg }, true);
  }
}

async function power(path) {
  $("btn-up").disabled = true;
  $("btn-down").disabled = true;
  $("log").textContent = path === "/api/up" ? "starting…" : "stopping…";
  try {
    const out = await api(path, { method: "POST" });
    $("log").textContent = out.log || (out.already_online ? "already online" : "ok");
  } catch (err) {
    $("log").textContent = String(err.message || err);
    syncDialog({ activity: String(err.message || err), force_diag: true }, true);
  } finally {
    $("btn-up").disabled = false;
    $("btn-down").disabled = false;
    refresh();
  }
}

async function attachBot() {
  const dir = $("bot-path").value.trim();
  $("log").textContent = "attaching bot…";
  $("btn-attach").disabled = true;
  try {
    const out = await api("/api/attach", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ dir }),
    });
    $("log").textContent = out.log || "attached";
    const failed = /missing|error|failed|aucun fichier|required variable|whiteout/i.test(out.log || "");
    if (failed) {
      const s = await api("/api/status").catch(() => ({ activity: out.log }));
      s.activity = out.log || s.activity;
      s.force_diag = true;
      render(s);
    }
  } catch (err) {
    $("log").textContent = String(err.message || err);
    syncDialog({ activity: String(err.message || err), force_diag: true }, true);
  } finally {
    $("btn-attach").disabled = false;
    refresh();
  }
}

$("btn-diag").addEventListener("click", () => {
  openDiag();
});
$("diag-close").addEventListener("click", () => {
  dismissedKey = lastOpenedKey || issueKey(diagnose({ activity: $("log").textContent }));
  $("diag").close();
});
$("diag").addEventListener("close", () => {
  dismissedKey = lastOpenedKey || dismissedKey;
});

$("btn-up").addEventListener("click", () => power("/api/up"));
$("btn-down").addEventListener("click", () => power("/api/down"));
$("btn-attach").addEventListener("click", attachBot);
$("bot-path").addEventListener("keydown", (ev) => {
  if (ev.key === "Enter") attachBot();
});
$("btn-copy").addEventListener("click", async () => {
  await navigator.clipboard.writeText($("ssh-cmd").textContent);
  $("btn-copy").textContent = "Copied";
  setTimeout(() => { $("btn-copy").textContent = "Copy"; }, 1200);
});

refresh();
setInterval(refresh, 4000);
