/* FakeVPS — Mr-Aurevo-X. Copyright (c) 2026 Mr-Aurevo-X */

const $ = (id) => document.getElementById(id);

function setHealth(id, state) {
  const el = $(id);
  el.classList.remove("ok", "warn");
  if (state === "ok") el.classList.add("ok");
  if (state === "warn") el.classList.add("warn");
}

function fmtUptime(sec) {
  const n = Number(sec) || 0;
  if (!n) return "Uptime —";
  const h = Math.floor(n / 3600);
  const m = Math.floor((n % 3600) / 60);
  return `Uptime ${h}h ${m}m`;
}

async function api(path, opts) {
  const res = await fetch(path, opts);
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || res.statusText);
  return data;
}

function render(s) {
  const starting = Boolean(s.starting);
  const online = Boolean(s.running && s.ssh);
  const booting = Boolean(starting || (s.running && !s.ssh));
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
}

async function refresh() {
  try {
    const s = await api("/api/status");
    render(s);
  } catch (err) {
    $("log").textContent = String(err.message || err);
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
  } catch (err) {
    $("log").textContent = String(err.message || err);
  } finally {
    $("btn-attach").disabled = false;
    refresh();
  }
}

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
