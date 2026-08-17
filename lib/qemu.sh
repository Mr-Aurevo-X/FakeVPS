# QEMU/KVM backend — 6 GB / 4 vCPU, localhost hostfwd.

CLOUD_IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
CLOUD_IMG_NAME="noble-server-cloudimg-amd64.img"

qemu_image_path() {
  printf '%s\n' "$STATE_DIR/images/$CLOUD_IMG_NAME"
}

qemu_disk_path() {
  printf '%s\n' "$STATE_DIR/kvm/disk.qcow2"
}

qemu_pidfile() {
  printf '%s\n' "$STATE_DIR/kvm/qemu.pid"
}

qemu_monitor() {
  printf '%s\n' "$STATE_DIR/kvm/monitor.sock"
}

qemu_running() {
  local pf
  pf="$(qemu_pidfile)"
  [[ -f "$pf" ]] || return 1
  local pid
  pid="$(cat "$pf")"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

download_cloud_image() {
  local dest
  dest="$(qemu_image_path)"
  if [[ -f "$dest" ]]; then
    return 0
  fi
  require_cmd curl
  log "downloading Ubuntu 24.04 cloud image"
  mkdir -p "$(dirname "$dest")"
  curl -fL --retry 3 --retry-delay 2 -o "${dest}.part" "$CLOUD_IMG_URL"
  mv "${dest}.part" "$dest"
}

build_seed_iso() {
  require_cmd xorriso
  ensure_ssh_key
  local seed="$STATE_DIR/kvm/seed"
  local iso="$STATE_DIR/kvm/seed.iso"
  mkdir -p "$seed"
  local pubkey
  pubkey="$(tr -d '\n' <"$SSH_PUB")"
  sed "s|@SSH_PUBKEY@|${pubkey}|" "$FAKEVPS_ROOT/cloud-init/user-data" >"$seed/user-data"
  cp "$FAKEVPS_ROOT/cloud-init/meta-data" "$seed/meta-data"
  xorriso -as mkisofs -V cidata -o "$iso" -r -J "$seed" >/dev/null 2>&1
}

ensure_overlay_disk() {
  require_cmd qemu-img
  local disk base
  disk="$(qemu_disk_path)"
  base="$(qemu_image_path)"
  if [[ -f "$disk" ]]; then
    return 0
  fi
  qemu-img create -f qcow2 -F qcow2 -b "$base" "$disk" "${DISK_GB}G" >/dev/null
}

qemu_hostfwd() {
  local fwd="hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22"
  if [[ -n "${BOT_PANEL_PORT}" ]]; then
    fwd="${fwd},hostfwd=tcp:127.0.0.1:${BOT_PANEL_PORT}-:${BOT_PANEL_PORT}"
  fi
  printf '%s\n' "$fwd"
}

qemu_up() {
  require_cmd qemu-system-x86_64
  [[ -e /dev/kvm ]] || die "/dev/kvm missing — use ./fakevps up --fast on WSL2 or enable KVM"
  if qemu_running; then
    log "KVM already running"
    return 0
  fi
  download_cloud_image
  build_seed_iso
  ensure_overlay_disk
  local disk iso mon serial
  disk="$(qemu_disk_path)"
  iso="$STATE_DIR/kvm/seed.iso"
  mon="$(qemu_monitor)"
  serial="$STATE_DIR/kvm/serial.log"
  rm -f "$mon"
  log "starting QEMU (${RAM_MB} MB, ${CPUS} vCPU)"
  qemu-system-x86_64 \
    -enable-kvm \
    -machine q35,accel=kvm \
    -cpu host \
    -m "$RAM_MB" \
    -smp "$CPUS" \
    -drive "file=${disk},if=virtio,format=qcow2" \
    -drive "file=${iso},if=virtio,format=raw,media=cdrom" \
    -netdev "user,id=net0,$(qemu_hostfwd)" \
    -device virtio-net-pci,netdev=net0 \
    -nographic \
    -serial "file:${serial}" \
    -monitor "unix:${mon},server,nowait" \
    -pidfile "$(qemu_pidfile)" \
    -daemonize
  set_backend kvm
}

qemu_acpi_down() {
  local mon
  mon="$(qemu_monitor)"
  if [[ -S "$mon" ]]; then
    python3 - "$mon" <<'PY'
import socket, sys
path = sys.argv[1]
s = socket.socket(socket.AF_UNIX)
s.connect(path)
s.sendall(b"system_powerdown\n")
s.close()
PY
    local i=0
    while qemu_running && (( i < 40 )); do
      sleep 1
      i=$((i + 1))
    done
  fi
  if qemu_running; then
    local pid
    pid="$(cat "$(qemu_pidfile)")"
    log "ACPI timed out — sending TERM to QEMU"
    kill -TERM "$pid" 2>/dev/null || true
    sleep 2
  fi
  rm -f "$(qemu_pidfile)" "$(qemu_monitor)"
}

qemu_reset_disk() {
  rm -f "$(qemu_disk_path)" "$STATE_DIR/kvm/seed.iso"
}
