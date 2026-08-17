/* FakeVPS — Mr-Aurevo-X. Copyright (c) 2026 Mr-Aurevo-X */

const $ = (id) => document.getElementById(id);

function setHealth(id, state) {
  const el = $(id);
  if (!el) return;
  el.classList.remove("ok", "warn");
  if (state === "ok") el.classList.add("ok");
  if (state === "warn") el.classList.add("warn");
  const label = $(`${id}-state`);
  if (label) {
    label.textContent = state === "ok" ? "prêt" : state === "warn" ? "démarrage" : "off";
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
    st.textContent = svc.state || (ledState === "ok" ? "prêt" : "off");
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
  if (n < 1024) return `${n.toFixed(0)} o/s`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} Ko/s`;
  return `${(n / (1024 * 1024)).toFixed(1)} Mo/s`;
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
    ? `${(ramUsed / 1024).toFixed(1)} / ${(ramTotal / 1024).toFixed(1)} Go`
    : "—";
  $("t-cpu").textContent = online ? `${cpuPct.toFixed(0)}% · load ${s.load1 ?? "—"}` : "—";
  $("t-disk-app").textContent = !online
    ? "—"
    : s.disk_pending
      ? "mesure…"
      : `${diskApp.toFixed(1)} Go`;
  $("t-disk-docker").textContent = !online
    ? "—"
    : s.disk_pending
      ? "mesure…"
      : `${diskDocker.toFixed(1)} / ${diskTotal || 40} Go`;
  $("t-ct").textContent = online ? String(s.containers ?? "—") : "—";
  $("t-pids").textContent = online && s.pids ? String(s.pids) : "—";
  $("t-rx").textContent = online ? fmtRate(s.net_rx_bps) : "—";
  $("t-tx").textContent = online ? fmtRate(s.net_tx_bps) : "—";
  if (online && ramTotal) {
    $("m-ram").textContent = `${(ramUsed / 1024).toFixed(1)} / ${Math.round(ramTotal / 1024)} Go`;
  }
  if (online && diskTotal && !s.disk_pending) {
    $("m-disk").textContent = `${diskUsed.toFixed(1)} / ${Math.round(diskTotal)} Go`;
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
  const res = await fetch(path, opts);
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
      title: "Le cockpit n’arrive pas à lire le nœud",
      detail: s.diag_error,
      fix: "./fakevps ui",
    });
  }
  if (!s.running && !starting) {
    issues.push({
      id: "offline",
      level: "off",
      title: "Le VPS est éteint",
      detail: "Rien n’écoute en SSH. Démarrer ici, ou en terminal.",
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
      fix: "ln -sfn \"~/Discord Bot/MyBot\" ~/mon-bot\n./fakevps attach ~/mon-bot",
    });
  }
  if (lookAtLog && (log.includes("discord_token missing") || log.includes("no secrets/discord.env"))) {
    issues.push({
      id: "token",
      level: "off",
      title: "DISCORD_TOKEN manquant",
      detail: "Le code est copié, le bot ne démarre pas sans jeton.",
      fix: "Édite secrets/discord.env et mets DISCORD_TOKEN=…\n./fakevps ssh -- rm -f /home/ubuntu/app/.env\n./fakevps attach \"~/Discord Bot/MyBot\"",
    });
  }
  if (lookAtLog && (log.includes("required variable") || log.includes("is missing a value"))) {
    issues.push({
      id: "compose-env",
      level: "off",
      title: "Il manque une variable Compose",
      detail: "docker compose a arrêté le déploiement (souvent LAVALINK_PASSWORD, POSTGRES_PASSWORD, NEXTAUTH_SECRET).",
      fix: "Recopie le .env complet du bot dans secrets/discord.env\n./fakevps ssh -- rm -f /home/ubuntu/app/.env\n./fakevps attach \"~/Discord Bot/MyBot\"",
    });
  }
  if (lookAtLog && (log.includes("whiteout") || log.includes("operation not permitted"))) {
    issues.push({
      id: "dind",
      level: "off",
      title: "Docker imbriqué refuse d’extraire une image",
      detail: "Overlay-sur-overlay (ou btrfs). Le nœud fast doit avoir son graph Docker sur l’hôte.",
      fix: "./fakevps down\n./fakevps up --fast\n./fakevps attach \"~/Discord Bot/MyBot\"",
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
      fix: "ln -sfn \"~/Discord Bot/MyBot\" ~/mon-bot\n./fakevps attach ~/mon-bot",
    });
  }
  if (online && botDir && !s.bot) {
    issues.push({
      id: "bot-down",
      level: "off",
      title: "Le bot est attaché mais pas lancé",
      detail: "Le dossier est connu, aucun process bot/worker. Jeton, Compose ou systemd.",
      fix: "./fakevps attach \"" + botDir + "\"\n./fakevps ssh -- 'systemctl status discord-bot --no-pager; docker ps'",
    });
  }
  if (log.includes("ubuntu@fakevps") && log.includes("./fakevps")) {
    issues.push({
      id: "inside-guest",
      level: "warn",
      title: "Tu es dans le VPS, pas sur l’hôte",
      detail: "Le prompt ubuntu@fakevps veut dire guest. ./fakevps attach se lance depuis le dossier FakeVPS sur l’hôte.",
      fix: "exit\n./fakevps attach \"~/Discord Bot/MyBot\"",
    });
  }
  if (!issues.length) {
    issues.push({
      id: "ok",
      level: "ok",
      title: "Rien à signaler",
      detail: "Nœud en ligne. Les feux Santé sont verts, ou le nœud attend juste un bot.",
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
    const copyBtn = document.createElement("button");
    copyBtn.type = "button";
    copyBtn.className = "btn ghost diag-copy";
    copyBtn.textContent = "Copier";
    copyBtn.addEventListener("click", async () => {
      await navigator.clipboard.writeText(issue.fix);
      copyBtn.textContent = "Copié";
      setTimeout(() => { copyBtn.textContent = "Copier"; }, 1200);
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
    ? "démarrage"
    : online
      ? "en ligne"
      : s.running
        ? "démarrage"
        : "hors ligne";
  $("uptime").textContent = fmtUptime(s.uptime_sec);
  $("m-ram").textContent = `${Math.round((s.ram_mb || 0) / 1024)} Go`;
  $("m-cpu").textContent = String(s.cpus || 4);
  $("m-disk").textContent = `${s.disk_gb || 40} Go`;
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
    $("bot-token").textContent = "présent";
  } else if (s.ssh) {
    $("bot-token").textContent = "absent";
  } else {
    $("bot-token").textContent = "—";
  }
  $("btn-sync").disabled = !online || !(s.bot_attached || s.bot_dir_display);
  $("btn-restart").disabled = !online;
  if (s.activity) {
    renderActivity(s.activity);
  } else if (starting) {
    renderActivity("démarrage…");
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
  renderActivity(path === "/api/up" ? "démarrage…" : "arrêt…");
  try {
    const out = await api(path, { method: "POST" });
    renderActivity(out.log || (out.already_online ? "déjà en ligne" : "ok"));
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
  renderActivity("attache du bot…");
  $("btn-attach").disabled = true;
  try {
    const out = await api("/api/attach", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ dir }),
    });
    renderActivity(out.log || "attaché");
    const failed = /missing|error|failed|aucun fichier|required variable|whiteout/i.test(out.log || "");
    if (failed) {
      const s = await api("/api/status").catch(() => ({ activity: out.log }));
      s.activity = out.log || s.activity;
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
$("btn-sync").addEventListener("click", () => botAction("/api/sync", "synchronisation"));
$("btn-restart").addEventListener("click", () => botAction("/api/restart-bot", "relance"));
$("btn-copy").addEventListener("click", async () => {
  await navigator.clipboard.writeText($("ssh-cmd").textContent);
  $("btn-copy").textContent = "Copié";
  setTimeout(() => { $("btn-copy").textContent = "Copier"; }, 1200);
});
$("btn-term").addEventListener("click", async () => {
  try {
    await api("/api/open-terminal", { method: "POST" });
    $("btn-term").textContent = "Ouvert";
  } catch (err) {
    renderActivity(String(err.message || err));
  }
  setTimeout(() => { $("btn-term").textContent = "Ouvrir un terminal"; }, 1200);
});

refreshStatus();
setInterval(refreshMetrics, 4000);
setInterval(refreshStatus, 12000);
