const $ = (id) => document.getElementById(id);

function setHealth(id, ok) {
  $(id).classList.toggle("ok", Boolean(ok));
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
  const online = Boolean(s.running && s.ssh);
  $("pill").classList.toggle("online", online);
  $("pill").classList.toggle("booting", Boolean(s.running && !s.ssh));
  $("pill-label").textContent = online ? "online" : s.running ? "booting" : "offline";
  $("uptime").textContent = fmtUptime(s.uptime_sec);
  $("m-ram").textContent = `${Math.round((s.ram_mb || 0) / 1024)} GB`;
  $("m-cpu").textContent = String(s.cpus || 4);
  $("m-disk").textContent = `${s.disk_gb || 40} GB`;
  $("m-be").textContent = s.backend || "—";
  $("ssh-cmd").textContent = `ssh -p ${s.ssh_port || 2222} ubuntu@127.0.0.1`;
  setHealth("h-ssh", s.ssh);
  setHealth("h-docker", s.docker);
  setHealth("h-bot", s.bot);
  setHealth("h-ui", s.ui);
  if (s.panel_port) {
    $("panel-msg").classList.add("hidden");
    $("panel-link").classList.remove("hidden");
    $("panel-link").href = `http://127.0.0.1:${s.panel_port}`;
  } else {
    $("panel-msg").classList.remove("hidden");
    $("panel-link").classList.add("hidden");
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
  try {
    const out = await api(path, { method: "POST" });
    $("log").textContent = out.log || "ok";
  } catch (err) {
    $("log").textContent = String(err.message || err);
  } finally {
    $("btn-up").disabled = false;
    $("btn-down").disabled = false;
    refresh();
  }
}

$("btn-up").addEventListener("click", () => power("/api/up"));
$("btn-down").addEventListener("click", () => power("/api/down"));
$("btn-copy").addEventListener("click", async () => {
  await navigator.clipboard.writeText($("ssh-cmd").textContent);
  $("btn-copy").textContent = "Copied";
  setTimeout(() => { $("btn-copy").textContent = "Copy"; }, 1200);
});

refresh();
setInterval(refresh, 4000);
