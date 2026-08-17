/* FakeVPS — Mr-Aurevo-X. Copyright (c) 2026 Mr-Aurevo-X */

const $ = (id) => document.getElementById(id);

/* --- session token — ./fakevps ui appends it to the URL, we keep it locally --- */
(() => {
  const params = new URLSearchParams(window.location.search);
  const tok = params.get("token");
  if (tok) {
    try { localStorage.setItem("fakevps-token", tok); } catch { /* ignore */ }
    window.history.replaceState(null, "", window.location.pathname);
  }
})();

function authHeaders() {
  try {
    const tok = localStorage.getItem("fakevps-token");
    return tok ? { "X-FakeVPS-Token": tok } : {};
  } catch {
    return {};
  }
}

/* --- i18n --- */
const I18N = {
  fr: {
    "eyebrow": "Répétition locale",
    "tag": "Nœud Ubuntu · 6 Go · 4 vCPU",
    "tile.power": "Alimentation",
    "uptime.label": "Temps de marche",
    "btn.up": "Démarrer",
    "btn.down": "Arrêter",
    "btn.down.wipe": "Arrêter (efface tout)",
    "down.title.wipe": "EPHEMERAL=true — l’extinction efface disque du nœud, images et journaux",
    "confirm.wipe": "Mode éphémère : l’extinction efface tout ce que le nœud a stocké (disque, images Docker, journaux). Continuer ?",
    "tile.node": "Nœud",
    "label.disk": "Disque",
    "label.disk2": "Disque",
    "label.disk3": "Disque",
    "label.engine": "Moteur",
    "tile.telem": "Télémétrie",
    "telem.note": "Nœud ubuntu@fakevps seulement — pas le PC hôte",
    "t.ram": "RAM utilisée",
    "t.cpu": "Charge CPU",
    "t.app": "App",
    "t.docker": "Images Docker",
    "t.ct": "Conteneurs",
    "t.pids": "Processus",
    "t.rx": "Réseau in",
    "t.tx": "Réseau out",
    "t.n": "Échantillons",
    "btn.copy": "Copier",
    "copied": "Copié",
    "btn.term": "Ouvrir un terminal",
    "opened": "Ouvert",
    "bot.hint": "Mets le jeton dans secrets/discord.env puis attache un dossier, par ex. ~/Discord Bot/MyBot",
    "bot.attached": "Attaché",
    "bot.token": "Jeton",
    "btn.browse": "Parcourir",
    "btn.attach": "Attacher",
    "btn.sync": "Synchroniser",
    "btn.restart": "Relancer",
    "btn.botlogs": "Logs du bot",
    "panel.msg": "Pas d’UI — aucun port configuré",
    "panel.open": "Ouvrir le panneau",
    "tile.health": "Santé",
    "tile.log": "Journal",
    "browse.title": "Choisir le dossier du bot",
    "browse.choose": "Attacher ce dossier",
    "browse.empty": "aucun sous-dossier",
    "btn.close": "Fermer",
    "botlogs.title": "Logs du bot",
    "botlogs.refresh": "Actualiser",
    "botlogs.empty": "(aucune sortie — le bot n’a rien écrit)",
    "foot.line": "localhost only · aucune collecte",
    "state.ready": "prêt",
    "state.boot": "démarrage",
    "pill.online": "en ligne",
    "pill.boot": "démarrage",
    "pill.off": "hors ligne",
    "act.start": "démarrage…",
    "act.stop": "arrêt…",
    "act.attach": "attache du bot…",
    "act.attached": "attaché",
    "act.already": "déjà en ligne",
    "act.sync": "synchronisation",
    "act.restart": "relance",
    "token.present": "présent",
    "token.absent": "absent",
    "measuring": "mesure…",
    "unit.gb": "Go",
    "rate.b": "o/s",
    "rate.kb": "Ko/s",
    "rate.mb": "Mo/s",
    "diag.allgood": "Tout est bon",
    "diag.lead.ok": "Aucun blocage détecté sur le nœud ou le bot.",
    "diag.lead.bad": "Voici ce qui cloche, et la commande pour le débloquer.",
    "diag.api.t": "Le cockpit n’arrive pas à lire le nœud",
    "diag.offline.t": "Le VPS est éteint",
    "diag.offline.d": "Rien n’écoute en SSH. Démarrer ici, ou en terminal.",
    "diag.booting.t": "Le nœud démarre",
    "diag.booting.d": "Le conteneur/VM est là, SSH pas encore prêt. Attends 30–60 s.",
    "diag.docker.t": "Docker n’est pas prêt dans le guest",
    "diag.docker.d": "SSH répond, mais le moteur Docker du VPS n’est pas là. Le premier provision a peut‑être planté (swap, réseau).",
    "diag.path-space.t": "Le chemin du bot a un espace",
    "diag.path-space.d": "Bash coupe BOT_DIR au premier espace (ex. Discord Bot). N’attache pas ce chemin tel quel.",
    "diag.token.t": "DISCORD_TOKEN manquant",
    "diag.token.d": "Le code est copié, le bot ne démarre pas sans jeton.",
    "diag.compose-env.t": "Il manque une variable Compose",
    "diag.compose-env.d": "docker compose a arrêté le déploiement (souvent LAVALINK_PASSWORD, POSTGRES_PASSWORD, NEXTAUTH_SECRET).",
    "diag.database-url.t": "DATABASE_URL manquant",
    "diag.database-url.d": "Prisma ne peut pas migrer sans DATABASE_URL. Le .env injecté ne contient pas cette clé.",
    "diag.ts-build.t": "Build TypeScript incomplet",
    "diag.ts-build.d": "Les packages du monorepo ne sont pas compilés (Cannot find module @scope/…). Le service n’a pas été installé.",
    "diag.dind.t": "Docker imbriqué refuse d’extraire une image",
    "diag.dind.d": "Overlay-sur-overlay (ou btrfs). Le nœud fast doit avoir son graph Docker sur l’hôte.",
    "diag.migrate.t": "La migrate Compose a échoué",
    "diag.migrate.d": "L’image prod n’a parfois pas Prisma. FakeVPS bascule alors sur l’infra + systemd. Si le bot est encore rouge, regarde les logs.",
    "diag.no-bot.t": "Aucun bot n’est attaché",
    "diag.no-bot.d": "Le VPS est vide. Attache un dossier. S’il y a un espace dans le chemin, passe par un lien.",
    "diag.bot-down.t": "Le bot est attaché mais pas lancé",
    "diag.bot-down.d": "Le dossier est connu, aucun process bot/worker. Jeton, Compose ou systemd.",
    "diag.inside-guest.t": "Tu es dans le VPS, pas sur l’hôte",
    "diag.inside-guest.d": "Le prompt ubuntu@fakevps veut dire guest. ./fakevps attach se lance depuis le dossier FakeVPS sur l’hôte.",
    "diag.ok.t": "Rien à signaler",
    "diag.ok.d": "Nœud en ligne. Les feux Santé sont verts, ou le nœud attend juste un bot.",
  },
  en: {
    "eyebrow": "Local rehearsal",
    "tag": "Ubuntu node · 6 GB · 4 vCPU",
    "tile.power": "Power",
    "uptime.label": "Uptime",
    "btn.up": "Start",
    "btn.down": "Stop",
    "btn.down.wipe": "Stop (erase everything)",
    "down.title.wipe": "EPHEMERAL=true — shutdown erases the node disk, images and logs",
    "confirm.wipe": "Ephemeral mode: shutting down erases everything the node stored (disk, Docker images, logs). Continue?",
    "tile.node": "Node",
    "label.disk": "Disk",
    "label.disk2": "Disk",
    "label.disk3": "Disk",
    "label.engine": "Engine",
    "tile.telem": "Telemetry",
    "telem.note": "ubuntu@fakevps node only — not the host PC",
    "t.ram": "RAM used",
    "t.cpu": "CPU load",
    "t.app": "App",
    "t.docker": "Docker images",
    "t.ct": "Containers",
    "t.pids": "Processes",
    "t.rx": "Network in",
    "t.tx": "Network out",
    "t.n": "Samples",
    "btn.copy": "Copy",
    "copied": "Copied",
    "btn.term": "Open a terminal",
    "opened": "Opened",
    "bot.hint": "Put the token in secrets/discord.env then attach a folder, e.g. ~/Discord Bot/MyBot",
    "bot.attached": "Attached",
    "bot.token": "Token",
    "btn.browse": "Browse",
    "btn.attach": "Attach",
    "btn.sync": "Sync",
    "btn.restart": "Restart",
    "btn.botlogs": "Bot logs",
    "panel.msg": "No web UI — no port configured",
    "panel.open": "Open the panel",
    "tile.health": "Health",
    "tile.log": "Journal",
    "browse.title": "Pick the bot folder",
    "browse.choose": "Attach this folder",
    "browse.empty": "no subfolders",
    "btn.close": "Close",
    "botlogs.title": "Bot logs",
    "botlogs.refresh": "Refresh",
    "botlogs.empty": "(no output — the bot wrote nothing)",
    "foot.line": "localhost only · nothing collected",
    "state.ready": "ready",
    "state.boot": "starting",
    "pill.online": "online",
    "pill.boot": "starting",
    "pill.off": "offline",
    "act.start": "starting…",
    "act.stop": "stopping…",
    "act.attach": "attaching the bot…",
    "act.attached": "attached",
    "act.already": "already online",
    "act.sync": "sync",
    "act.restart": "restart",
    "token.present": "present",
    "token.absent": "missing",
    "measuring": "measuring…",
    "unit.gb": "GB",
    "rate.b": "B/s",
    "rate.kb": "KB/s",
    "rate.mb": "MB/s",
    "diag.allgood": "All good",
    "diag.lead.ok": "No blocker detected on the node or the bot.",
    "diag.lead.bad": "Here is what is wrong, and the command to unblock it.",
    "diag.api.t": "The cockpit can’t read the node",
    "diag.offline.t": "The VPS is off",
    "diag.offline.d": "Nothing is listening on SSH. Start it here, or from a terminal.",
    "diag.booting.t": "The node is booting",
    "diag.booting.d": "The container/VM exists, SSH isn’t ready yet. Wait 30–60 s.",
    "diag.docker.t": "Docker isn’t ready in the guest",
    "diag.docker.d": "SSH answers, but the node’s Docker engine isn’t there. The first provision may have crashed (swap, network).",
    "diag.path-space.t": "The bot path has a space",
    "diag.path-space.d": "Bash cuts BOT_DIR at the first space (e.g. Discord Bot). Don’t attach that path as-is.",
    "diag.token.t": "DISCORD_TOKEN missing",
    "diag.token.d": "The code is copied, but the bot won’t start without a token.",
    "diag.compose-env.t": "A Compose variable is missing",
    "diag.compose-env.d": "docker compose stopped the deploy (often LAVALINK_PASSWORD, POSTGRES_PASSWORD, NEXTAUTH_SECRET).",
    "diag.database-url.t": "DATABASE_URL missing",
    "diag.database-url.d": "Prisma can’t migrate without DATABASE_URL. The injected .env doesn’t have that key.",
    "diag.ts-build.t": "Incomplete TypeScript build",
    "diag.ts-build.d": "The monorepo packages aren’t compiled (Cannot find module @scope/…). The service was not installed.",
    "diag.dind.t": "Nested Docker refuses to extract an image",
    "diag.dind.d": "Overlay-on-overlay (or btrfs). The fast node must keep its Docker graph on the host.",
    "diag.migrate.t": "The Compose migrate failed",
    "diag.migrate.d": "The prod image sometimes lacks Prisma. FakeVPS then falls back to infra + systemd. If the bot is still red, check the logs.",
    "diag.no-bot.t": "No bot is attached",
    "diag.no-bot.d": "The VPS is empty. Attach a folder. If the path has a space, use a symlink.",
    "diag.bot-down.t": "The bot is attached but not running",
    "diag.bot-down.d": "The folder is known, but no bot/worker process. Token, Compose or systemd.",
    "diag.inside-guest.t": "You are inside the VPS, not on the host",
    "diag.inside-guest.d": "The ubuntu@fakevps prompt means guest. ./fakevps attach runs from the FakeVPS folder on the host.",
    "diag.ok.t": "Nothing to report",
    "diag.ok.d": "Node online. The health lights are green, or the node is just waiting for a bot.",
  },
};

let LANG = (() => {
  try {
    const saved = localStorage.getItem("fakevps-lang");
    if (saved === "fr" || saved === "en") return saved;
  } catch { /* ignore */ }
  return (navigator.language || "en").toLowerCase().startsWith("fr") ? "fr" : "en";
})();

function tr(key) {
  return (I18N[LANG] && I18N[LANG][key]) ?? I18N.fr[key] ?? key;
}

function diagCountLabel(n) {
  if (LANG === "fr") return `${n} point${n > 1 ? "s" : ""} à régler`;
  return `${n} issue${n > 1 ? "s" : ""} to fix`;
}

function applyI18n() {
  document.documentElement.lang = LANG;
  document.querySelectorAll("[data-i18n]").forEach((el) => {
    const v = tr(el.dataset.i18n);
    if (v && v !== el.dataset.i18n) el.textContent = v;
  });
  const toggle = $("lang-toggle");
  if (toggle) toggle.textContent = LANG === "fr" ? "EN" : "FR";
}

function setHealth(id, state) {
  const el = $(id);
  if (!el) return;
  el.classList.remove("ok", "warn");
  if (state === "ok") el.classList.add("ok");
  if (state === "warn") el.classList.add("warn");
  const label = $(`${id}-state`);
  if (label) {
    label.textContent = state === "ok" ? tr("state.ready") : state === "warn" ? tr("state.boot") : "off";
  }
}

function slug(name) {
  return String(name || "svc").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "svc";
}

function serviceLedState(state) {
  const s = String(state || "").toLowerCase();
  if (/\b(up|active|running|healthy)\b/.test(s)) return "ok";
  if (/\b(restart|start|created|paused)\b/.test(s)) return "warn";
  return "off";
}

function renderServices(services) {
  const list = $("health-list");
  if (!list) return;
  list.querySelectorAll("[data-dynamic]").forEach((el) => el.remove());
  for (const svc of services || []) {
    const name = String(svc.name || "").trim();
    if (!name) continue;
    const li = document.createElement("li");
    li.dataset.dynamic = "1";
    const ledState = serviceLedState(svc.state);
    if (ledState === "ok") li.classList.add("ok");
    if (ledState === "warn") li.classList.add("warn");
    const led = document.createElement("span");
    led.className = "led";
    const label = document.createElement("span");
    label.className = "health-name";
    label.textContent = name;
    const st = document.createElement("span");
    st.className = "health-state";
    st.id = `h-svc-${slug(name)}-state`;
    st.textContent = svc.state || (ledState === "ok" ? tr("state.ready") : "off");
    li.id = `h-svc-${slug(name)}`;
    li.append(led, label, st);
    list.append(li);
  }
}

const HIST_MAX = 36;
const HIST_KEY = "fakevps-telem-v3";
const GAUGE_C = 2 * Math.PI * 46;

function loadHist() {
  try {
    const raw = sessionStorage.getItem(HIST_KEY);
    const data = raw ? JSON.parse(raw) : null;
    if (data && Array.isArray(data.ram)) return data;
  } catch {
    /* ignore */
  }
  return { ram: [], cpu: [], disk: [] };
}

function saveHist(hist) {
  try {
    sessionStorage.setItem(HIST_KEY, JSON.stringify(hist));
  } catch {
    /* ignore */
  }
}

function pushHist(hist, key, value) {
  hist[key].push(Number(value) || 0);
  if (hist[key].length > HIST_MAX) hist[key].shift();
}

function usageClass(pct) {
  if (pct >= 90) return "off";
  if (pct >= 75) return "warn";
  return "ok";
}

function setBar(id, pct) {
  const el = $(id);
  const n = Math.max(0, Math.min(100, Number(pct) || 0));
  el.style.width = `${n}%`;
  el.classList.remove("ok", "warn", "off");
  el.classList.add(usageClass(n));
}

function svgEl(name, attrs) {
  const el = document.createElementNS("http://www.w3.org/2000/svg", name);
  for (const [key, value] of Object.entries(attrs)) el.setAttribute(key, value);
  return el;
}

function drawSpark(svg, values, color) {
  const w = 280;
  const h = 72;
  while (svg.firstChild) svg.removeChild(svg.firstChild);
  for (const y of [18, 36, 54]) {
    svg.append(svgEl("line", {
      x1: "0", y1: String(y), x2: String(w), y2: String(y),
      stroke: "rgba(255,255,255,0.06)", "stroke-width": "1",
    }));
  }
  if (!values.length) return;
  const step = values.length > 1 ? w / (values.length - 1) : w;
  const pts = values.map((raw, i) => {
    const v = Math.max(0, Math.min(100, Number(raw) || 0));
    const x = i * step;
    const y = h - (v / 100) * (h - 10) - 5;
    return `${x.toFixed(1)},${y.toFixed(1)}`;
  });
  const last = pts[pts.length - 1].split(",");
  svg.append(
    svgEl("polygon", {
      fill: color,
      opacity: "0.16",
      points: `0,${h} ${pts.join(" ")} ${((values.length - 1) * step).toFixed(1)},${h}`,
    }),
    svgEl("polyline", {
      fill: "none",
      stroke: color,
      "stroke-width": "2.2",
      "stroke-linejoin": "round",
      "stroke-linecap": "round",
      points: pts.join(" "),
    }),
    svgEl("circle", { cx: last[0], cy: last[1], r: "3.2", fill: color }),
  );
}

function setGauge(id, pct) {
  const el = $(id);
  const n = Math.max(0, Math.min(100, Number(pct) || 0));
  el.style.strokeDasharray = String(GAUGE_C);
  el.style.strokeDashoffset = String(GAUGE_C * (1 - n / 100));
  el.classList.remove("ok", "warn", "off");
  el.classList.add(usageClass(n));
  $(`${id}-n`).textContent = `${n.toFixed(0)}%`;
}

function fmtRate(bps) {
  const n = Number(bps) || 0;
  if (n < 1024) return `${n.toFixed(0)} ${tr("rate.b")}`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} ${tr("rate.kb")}`;
  return `${(n / (1024 * 1024)).toFixed(1)} ${tr("rate.mb")}`;
}

function updateTelemetry(s, online) {
  const ramUsed = Number(s.ram_used_mb) || 0;
  const ramTotal = Number(s.ram_total_mb) || Number(s.ram_mb) || 0;
  const cpuPct = online ? Number(s.cpu_pct) || 0 : 0;
  const diskApp = Number(s.disk_app_gb) || 0;
  const diskDocker = Number(s.disk_docker_gb) || 0;
  const diskUsed = Number(s.disk_used_gb) || (diskApp + diskDocker) || 0;
  const diskTotal = Number(s.disk_total_gb) || Number(s.disk_gb) || 0;
  const ramPct = ramTotal ? (100 * ramUsed) / ramTotal : 0;
  const diskPct = diskTotal ? (100 * diskUsed) / diskTotal : 0;
  $("t-ram").textContent = online && ramTotal
    ? `${(ramUsed / 1024).toFixed(1)} / ${(ramTotal / 1024).toFixed(1)} ${tr("unit.gb")}`
    : "—";
  $("t-cpu").textContent = online ? `${cpuPct.toFixed(0)}% · load ${s.load1 ?? "—"}` : "—";
  $("t-disk-app").textContent = !online
    ? "—"
    : s.disk_pending
      ? tr("measuring")
      : `${diskApp.toFixed(1)} ${tr("unit.gb")}`;
  $("t-disk-docker").textContent = !online
    ? "—"
    : s.disk_pending
      ? tr("measuring")
      : `${diskDocker.toFixed(1)} / ${diskTotal || 40} ${tr("unit.gb")}`;
  $("t-ct").textContent = online ? String(s.containers ?? "—") : "—";
  $("t-pids").textContent = online && s.pids ? String(s.pids) : "—";
  $("t-rx").textContent = online ? fmtRate(s.net_rx_bps) : "—";
  $("t-tx").textContent = online ? fmtRate(s.net_tx_bps) : "—";
  if (online && ramTotal) {
    $("m-ram").textContent = `${(ramUsed / 1024).toFixed(1)} / ${Math.round(ramTotal / 1024)} ${tr("unit.gb")}`;
  }
  if (online && diskTotal && !s.disk_pending) {
    $("m-disk").textContent = `${diskUsed.toFixed(1)} / ${Math.round(diskTotal)} ${tr("unit.gb")}`;
  }
  if (online) {
    $("m-cpu").textContent = `${cpuPct.toFixed(0)}% · ${s.cpus || 4}`;
  }
  setBar("bar-ram", online ? ramPct : 0);
  setBar("bar-cpu", online ? cpuPct : 0);
  setBar("bar-disk", online ? diskPct : 0);
  setGauge("g-ram", online ? ramPct : 0);
  setGauge("g-cpu", online ? cpuPct : 0);
  setGauge("g-disk", online ? diskPct : 0);
  const hist = loadHist();
  if (online) {
    pushHist(hist, "ram", ramPct);
    pushHist(hist, "cpu", cpuPct);
    pushHist(hist, "disk", diskPct);
    saveHist(hist);
  }
  const last = (arr) => arr[arr.length - 1] || 0;
  const sparkColor = (pct) => {
    const lvl = usageClass(pct);
    if (lvl === "off") return "#ef4444";
    if (lvl === "warn") return "#eab308";
    return "#22c55e";
  };
  drawSpark($("chart-ram"), hist.ram, sparkColor(last(hist.ram)));
  drawSpark($("chart-cpu"), hist.cpu, sparkColor(last(hist.cpu)));
  drawSpark($("chart-disk"), hist.disk, sparkColor(last(hist.disk)));
  $("cap-ram").textContent = online ? `${ramPct.toFixed(0)}%` : "%";
  $("cap-cpu").textContent = online ? `${cpuPct.toFixed(0)}%` : "%";
  $("cap-disk").textContent = online ? `${diskPct.toFixed(0)}%` : "%";
  $("t-n").textContent = hist.ram.length ? String(hist.ram.length) : "—";
}

function fmtUptime(sec) {
  const n = Number(sec) || 0;
  if (!n) return "—";
  const h = Math.floor(n / 3600);
  const m = Math.floor((n % 3600) / 60);
  return `${h}h ${m}m`;
}

async function api(path, opts) {
  const o = opts || {};
  const res = await fetch(path, { ...o, headers: { ...authHeaders(), ...(o.headers || {}) } });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || data.log || res.statusText);
  return data;
}

function redactSecrets(text) {
  return String(text || "").replace(/DISCORD_TOKEN=.*/gi, "DISCORD_TOKEN=(redacted)");
}

function keepActivityLine(line) {
  const l = line.toLowerCase();
  if ((l.includes("warning") || l.includes("warn")) && l.includes("privileged")) {
    return false;
  }
  return true;
}

function filterActivity(text) {
  return redactSecrets(text)
    .split("\n")
    .filter(keepActivityLine)
    .join("\n");
}

function lineKind(line) {
  const l = line.toLowerCase();
  if (/error|failed|missing|aucun fichier|required variable/.test(l)) return "log-err";
  if (l.includes("inject")) return "log-inject";
  if (l.includes("attach")) return "log-attach";
  return "";
}

function renderActivity(text) {
  const filtered = filterActivity(text);
  const pre = $("log");
  pre.replaceChildren();
  const lines = filtered.split("\n");
  for (const line of lines) {
    const span = document.createElement("span");
    span.className = `log-line ${lineKind(line)}`.trim();
    span.textContent = line;
    pre.append(span);
  }
}

function activityText(s) {
  return String(s.activity || s.error || "");
}

function recentActivity(raw) {
  const log = String(raw || "").toLowerCase();
  let cut = -1;
  for (const marker of ["injected bot_dir", "injected secrets", "auto-deploy bot"]) {
    const i = log.lastIndexOf(marker);
    if (i > cut) cut = i;
  }
  return cut >= 0 ? log.slice(cut) : log;
}

function diagnose(s) {
  const issues = [];
  const log = recentActivity(activityText(s));
  const botDir = String(s.bot_dir_display || "");
  const starting = Boolean(s.starting);
  const online = Boolean(s.running && s.ssh);
  const booting = Boolean(starting || (s.running && !s.ssh));

  if (s.diag_error) {
    issues.push({
      id: "api",
      level: "off",
      title: tr("diag.api.t"),
      detail: s.diag_error,
      fix: "./fakevps ui",
    });
  }
  if (!s.running && !starting) {
    issues.push({
      id: "offline",
      level: "off",
      title: tr("diag.offline.t"),
      detail: tr("diag.offline.d"),
      fix: "./fakevps up --fast",
    });
  }
  if (booting) {
    issues.push({
      id: "booting",
      level: "warn",
      title: tr("diag.booting.t"),
      detail: tr("diag.booting.d"),
      fix: "./fakevps status\n./fakevps logs",
    });
  }
  if (s.ssh && !s.docker) {
    issues.push({
      id: "docker",
      level: "warn",
      title: tr("diag.docker.t"),
      detail: tr("diag.docker.d"),
      fix: "./fakevps ssh -- 'command -v docker || echo missing'\nPuis relance ./fakevps up --fast",
    });
  }
  const botStuck = Boolean(botDir && !s.bot);
  const lookAtLog = !s.bot || Boolean(s.diag_error);

  if (lookAtLog && (log.includes("aucun fichier ou dossier") || (botDir.includes(" ") && log.includes("config.env")))) {
    issues.push({
      id: "path-space",
      level: "off",
      title: tr("diag.path-space.t"),
      detail: tr("diag.path-space.d"),
      fix: "ln -sfn \"~/Discord Bot/MyBot\" ~/mon-bot\n./fakevps attach ~/mon-bot",
    });
  }
  if (lookAtLog && (log.includes("discord_token missing") || log.includes("no secrets/discord.env"))) {
    issues.push({
      id: "token",
      level: "off",
      title: tr("diag.token.t"),
      detail: tr("diag.token.d"),
      fix: "Édite secrets/discord.env et mets DISCORD_TOKEN=…\n./fakevps ssh -- rm -f /home/ubuntu/app/.env\n./fakevps attach \"~/Discord Bot/MyBot\"",
    });
  }
  if (lookAtLog && (log.includes("required variable") || log.includes("is missing a value"))) {
    issues.push({
      id: "compose-env",
      level: "off",
      title: tr("diag.compose-env.t"),
      detail: tr("diag.compose-env.d"),
      fix: "Recopie le .env complet du bot dans secrets/discord.env\n./fakevps ssh -- rm -f /home/ubuntu/app/.env\n./fakevps attach \"~/Discord Bot/MyBot\"",
    });
  }
  if (lookAtLog && (log.includes("environment variable not found: database_url") || log.includes("database_url missing"))) {
    issues.push({
      id: "database-url",
      level: "off",
      title: tr("diag.database-url.t"),
      detail: tr("diag.database-url.d"),
      fix: "Ajoute DATABASE_URL=… dans secrets/discord.env (ou dans le .env du bot)\n./fakevps attach \"~/Discord Bot/MyBot\"",
    });
  }
  if (lookAtLog && (log.includes("error ts2307") || log.includes("service not installed"))) {
    issues.push({
      id: "ts-build",
      level: "off",
      title: tr("diag.ts-build.t"),
      detail: tr("diag.ts-build.d"),
      fix: "Vérifie que le package.json racine a un script build/build:ci\n./fakevps attach \"~/Discord Bot/MyBot\"",
    });
  }
  if (lookAtLog && (log.includes("whiteout") || log.includes("operation not permitted"))) {
    issues.push({
      id: "dind",
      level: "off",
      title: tr("diag.dind.t"),
      detail: tr("diag.dind.d"),
      fix: "./fakevps down\n./fakevps up --fast\n./fakevps attach \"~/Discord Bot/MyBot\"",
    });
  }
  if (botStuck && (log.includes("didn't complete successfully") || log.includes("migrate"))) {
    issues.push({
      id: "migrate",
      level: "warn",
      title: tr("diag.migrate.t"),
      detail: tr("diag.migrate.d"),
      fix: "./fakevps ssh -- 'journalctl -u discord-bot -n 40 --no-pager'",
    });
  }
  if (online && !botDir) {
    issues.push({
      id: "no-bot",
      level: "warn",
      title: tr("diag.no-bot.t"),
      detail: tr("diag.no-bot.d"),
      fix: "ln -sfn \"~/Discord Bot/MyBot\" ~/mon-bot\n./fakevps attach ~/mon-bot",
    });
  }
  if (online && botDir && !s.bot) {
    issues.push({
      id: "bot-down",
      level: "off",
      title: tr("diag.bot-down.t"),
      detail: tr("diag.bot-down.d"),
      fix: "./fakevps attach \"" + botDir + "\"\n./fakevps ssh -- 'systemctl status discord-bot --no-pager; docker ps'",
    });
  }
  if (log.includes("ubuntu@fakevps") && log.includes("./fakevps")) {
    issues.push({
      id: "inside-guest",
      level: "warn",
      title: tr("diag.inside-guest.t"),
      detail: tr("diag.inside-guest.d"),
      fix: "exit\n./fakevps attach \"~/Discord Bot/MyBot\"",
    });
  }
  if (!issues.length) {
    issues.push({
      id: "ok",
      level: "ok",
      title: tr("diag.ok.t"),
      detail: tr("diag.ok.d"),
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
  $("diag-title").textContent = bad.length ? diagCountLabel(bad.length) : tr("diag.allgood");
  $("diag-lead").textContent = worst === "ok" ? tr("diag.lead.ok") : tr("diag.lead.bad");
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
    const copyBtn = document.createElement("button");
    copyBtn.type = "button";
    copyBtn.className = "btn ghost diag-copy";
    copyBtn.textContent = tr("btn.copy");
    copyBtn.addEventListener("click", async () => {
      await navigator.clipboard.writeText(issue.fix);
      copyBtn.textContent = tr("copied");
      setTimeout(() => { copyBtn.textContent = tr("btn.copy"); }, 1200);
    });
    li.append(h, p, pre, copyBtn);
    list.append(li);
  }
  $("btn-diag").textContent = bad.length ? `Diagnostic (${bad.length})` : "Diagnostic";
}

let dismissedKey = "";
let lastOpenedKey = "";
let lastStatus = {};

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
    ? tr("pill.boot")
    : online
      ? tr("pill.online")
      : s.running
        ? tr("pill.boot")
        : tr("pill.off");
  $("uptime").textContent = fmtUptime(s.uptime_sec);
  $("m-ram").textContent = `${Math.round((s.ram_mb || 0) / 1024)} ${tr("unit.gb")}`;
  $("m-cpu").textContent = String(s.cpus || 4);
  $("m-disk").textContent = `${s.disk_gb || 40} ${tr("unit.gb")}`;
  $("m-be").textContent = s.backend || "—";
  updateTelemetry(s, online && !starting);
  $("ssh-cmd").textContent = `ssh -p ${s.ssh_port || 2222} ubuntu@127.0.0.1`;
  setHealth("h-ssh", s.ssh ? "ok" : s.running ? "warn" : "off");
  setHealth("h-docker", s.docker ? "ok" : s.ssh ? "warn" : "off");
  setHealth("h-bot", s.bot ? "ok" : s.bot_attached || s.bot_dir_display ? "warn" : "off");
  setHealth("h-ui", s.ui ? "ok" : "off");
  renderServices(s.services);
  if (s.panel_port) {
    $("panel-msg").classList.add("hidden");
    $("panel-link").classList.remove("hidden");
    $("panel-link").href = `http://127.0.0.1:${s.panel_port}`;
  } else {
    $("panel-msg").classList.remove("hidden");
    $("panel-link").classList.add("hidden");
  }
  const shown = s.bot_dir_display || "";
  if (shown || s.bot_attached) {
    $("bot-hint").classList.add("hidden");
    $("bot-attached").classList.remove("hidden");
    $("bot-dir").textContent = shown || "…";
  } else {
    $("bot-hint").classList.remove("hidden");
    $("bot-attached").classList.add("hidden");
  }
  $("bot-runtime").textContent = s.runtime && s.runtime !== "none" ? s.runtime : "—";
  if (s.token_present === true) {
    $("bot-token").textContent = tr("token.present");
  } else if (s.ssh) {
    $("bot-token").textContent = tr("token.absent");
  } else {
    $("bot-token").textContent = "—";
  }
  $("btn-sync").disabled = !online || !(s.bot_attached || s.bot_dir_display);
  $("btn-restart").disabled = !online;
  $("btn-down").textContent = s.ephemeral ? tr("btn.down.wipe") : tr("btn.down");
  $("btn-down").title = s.ephemeral ? tr("down.title.wipe") : "";
  $("btn-botlogs").disabled = !online;
  if (s.activity) {
    renderActivity(s.activity);
  } else if (starting) {
    renderActivity(tr("act.start"));
  }
  syncDialog(s, Boolean(s.force_diag));
}

function applyStatus(s) {
  lastStatus = { ...lastStatus, ...s };
  render(lastStatus);
}

async function refreshStatus() {
  try {
    const s = await api("/api/status");
    applyStatus(s);
  } catch (err) {
    const msg = String(err.message || err);
    renderActivity(msg);
    syncDialog({ diag_error: msg, activity: msg }, true);
  }
}

async function refreshMetrics() {
  try {
    const m = await api("/api/metrics");
    applyStatus({ ...lastStatus, ...m });
  } catch {
    /* keep last status */
  }
}

async function power(path) {
  $("btn-up").disabled = true;
  $("btn-down").disabled = true;
  renderActivity(path === "/api/up" ? tr("act.start") : tr("act.stop"));
  try {
    const out = await api(path, { method: "POST" });
    renderActivity(out.log || (out.already_online ? tr("act.already") : "ok"));
  } catch (err) {
    renderActivity(String(err.message || err));
    syncDialog({ activity: String(err.message || err), force_diag: true }, true);
  } finally {
    $("btn-up").disabled = false;
    $("btn-down").disabled = false;
    refreshStatus();
  }
}

async function attachBot() {
  const dir = $("bot-path").value.trim();
  renderActivity(tr("act.attach"));
  $("btn-attach").disabled = true;
  try {
    // Streamed deploy: the journal fills line by line while pnpm/docker work.
    const res = await fetch("/api/attach?stream=1", {
      method: "POST",
      headers: { ...authHeaders(), "Content-Type": "application/json" },
      body: JSON.stringify({ dir }),
    });
    if (!res.ok || !res.body) {
      const data = await res.json().catch(() => ({}));
      throw new Error(data.error || data.log || res.statusText);
    }
    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let acc = "";
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      acc += decoder.decode(value, { stream: true });
      renderActivity(acc.split("\n").slice(-120).join("\n"));
    }
    renderActivity(acc || tr("act.attached"));
    const failed = /missing|error|failed|aucun fichier|required variable|whiteout|\[exit [1-9]/i.test(acc);
    if (failed) {
      const s = await api("/api/status").catch(() => ({ activity: acc }));
      s.activity = acc || s.activity;
      s.force_diag = true;
      applyStatus(s);
    }
  } catch (err) {
    renderActivity(String(err.message || err));
    syncDialog({ activity: String(err.message || err), force_diag: true }, true);
  } finally {
    $("btn-attach").disabled = false;
    refreshStatus();
  }
}

async function showBotLogs() {
  const dlg = $("botlogs");
  if (!dlg.open) dlg.showModal();
  $("botlogs-pre").textContent = "…";
  try {
    const out = await api("/api/bot-logs");
    $("botlogs-pre").textContent = redactSecrets(out.log || "").trim() || tr("botlogs.empty");
  } catch (err) {
    $("botlogs-pre").textContent = String(err.message || err);
  }
}

async function botAction(path, label) {
  renderActivity(`${label}…`);
  $("btn-sync").disabled = true;
  $("btn-restart").disabled = true;
  try {
    const out = await api(path, { method: "POST" });
    renderActivity(out.log || "ok");
  } catch (err) {
    renderActivity(String(err.message || err));
    syncDialog({ activity: String(err.message || err), force_diag: true }, true);
  } finally {
    $("btn-sync").disabled = false;
    $("btn-restart").disabled = false;
    refreshStatus();
  }
}

let browsePath = "~";

function browseJoin(base, name) {
  return base === "~" ? `~/${name}` : `${base}/${name}`;
}

function browseBadge(kind, label) {
  const span = document.createElement("span");
  span.className = `browse-badge browse-badge-${kind}`;
  span.textContent = label;
  return span;
}

function renderBrowse(data) {
  browsePath = data.path || "~";
  $("browse-path").textContent = browsePath;
  $("browse-up").disabled = !data.parent;
  $("browse-up").dataset.parent = data.parent || "";
  const list = $("browse-list");
  list.textContent = "";
  for (const d of data.dirs || []) {
    const li = document.createElement("li");
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "browse-item";
    btn.textContent = d.name;
    btn.addEventListener("click", () => loadBrowse(browseJoin(browsePath, d.name)));
    li.append(btn);
    if (d.has_env) li.append(browseBadge("env", ".env"));
    if (d.has_bot) li.append(browseBadge("bot", "bot"));
    list.append(li);
  }
  if (!(data.dirs || []).length) {
    const li = document.createElement("li");
    li.className = "browse-empty muted";
    li.textContent = tr("browse.empty");
    list.append(li);
  }
}

async function loadBrowse(path) {
  try {
    const data = await api(`/api/browse?path=${encodeURIComponent(path || "~")}`);
    renderBrowse(data);
  } catch (err) {
    renderActivity(String(err.message || err));
  }
}

$("btn-browse").addEventListener("click", () => {
  $("browse").showModal();
  loadBrowse($("bot-path").value.trim() || "~");
});
$("browse-close").addEventListener("click", () => $("browse").close());
$("browse-up").addEventListener("click", () => {
  const parent = $("browse-up").dataset.parent;
  if (parent) loadBrowse(parent);
});
$("browse-choose").addEventListener("click", () => {
  $("bot-path").value = browsePath;
  $("browse").close();
  attachBot();
});

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
$("btn-down").addEventListener("click", () => {
  if (lastStatus.ephemeral && !window.confirm(tr("confirm.wipe"))) return;
  power("/api/down");
});
$("btn-attach").addEventListener("click", attachBot);
$("bot-path").addEventListener("keydown", (ev) => {
  if (ev.key === "Enter") attachBot();
});
$("btn-sync").addEventListener("click", () => botAction("/api/sync", tr("act.sync")));
$("btn-restart").addEventListener("click", () => botAction("/api/restart-bot", tr("act.restart")));
$("btn-botlogs").addEventListener("click", showBotLogs);
$("botlogs-refresh").addEventListener("click", showBotLogs);
$("botlogs-close").addEventListener("click", () => $("botlogs").close());
$("btn-copy").addEventListener("click", async () => {
  await navigator.clipboard.writeText($("ssh-cmd").textContent);
  $("btn-copy").textContent = tr("copied");
  setTimeout(() => { $("btn-copy").textContent = tr("btn.copy"); }, 1200);
});
$("btn-term").addEventListener("click", async () => {
  try {
    await api("/api/open-terminal", { method: "POST" });
    $("btn-term").textContent = tr("opened");
  } catch (err) {
    renderActivity(String(err.message || err));
  }
  setTimeout(() => { $("btn-term").textContent = tr("btn.term"); }, 1200);
});
$("lang-toggle").addEventListener("click", () => {
  LANG = LANG === "fr" ? "en" : "fr";
  try { localStorage.setItem("fakevps-lang", LANG); } catch { /* ignore */ }
  applyI18n();
  if (Object.keys(lastStatus).length) render(lastStatus);
});

applyI18n();
refreshStatus();
setInterval(refreshMetrics, 4000);
setInterval(refreshStatus, 12000);
