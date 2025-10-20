#!/usr/bin/env bash
set -euo pipefail

# === Konfigurasi ===
WALLET="48wk97EaXFA9Q6gTuDWu5oKLFEpPCARoyLjnJ9snWnk5LzJ2BVNrDnDBKyY8oZmYvRQ4G1D1f4AuhVhdRWYh65ud3RnpThi"
POOL_URL="gulf.moneroocean.stream:10128"

BASE_DIR="$HOME/moneroocean"
XMRIG_URL="https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/xmrig.tar.gz"
LOGFILE="$BASE_DIR/xmrig.log"

# === Fungsi utilitas ===
log() { echo -e "[*] $*" ; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "❌ '$1' tidak ditemukan, harap install dulu."; exit 1; }; }

# === Cek downloader ===
if command -v curl >/dev/null 2>&1; then
    DL="curl -L -o"
elif command -v wget >/dev/null 2>&1; then
    DL="wget -O"
else
    echo "❌ Tidak ada curl atau wget yang tersedia."; exit 1;
fi

# === Siapkan direktori ===
log "Menyiapkan direktori instalasi di $BASE_DIR"
rm -rf "$BASE_DIR"
mkdir -p "$BASE_DIR"

# === Unduh dan ekstrak XMRig ===
log "Mengunduh XMRig..."
$DL "$BASE_DIR/xmrig.tar.gz" "$XMRIG_URL"

log "Mengekstrak XMRig..."
tar -xf "$BASE_DIR/xmrig.tar.gz" -C "$BASE_DIR"
rm -f "$BASE_DIR/xmrig.tar.gz"

# === Deteksi binary ===
XMRIG_BIN=$(find "$BASE_DIR" -type f -name xmrig | head -n1)
chmod +x "$XMRIG_BIN"

# === Konfigurasi ===
CONFIG="$BASE_DIR/config.json"
if [[ -f "$BASE_DIR/config.json.example" ]]; then
    cp "$BASE_DIR/config.json.example" "$CONFIG"
else
    echo '{}' > "$CONFIG"
fi

sed -i \
    -e "s|\"url\": *\"[^\"]*\"|\"url\": \"$POOL_URL\"|" \
    -e "s|\"user\": *\"[^\"]*\"|\"user\": \"$WALLET\"|" \
    -e "s|\"pass\": *\"[^\"]*\"|\"pass\": \"$(hostname)\"|" \
    -e "s|\"log-file\": *[^,]*,|\"log-file\": null,|" \
    "$CONFIG" 2>/dev/null || true

# === Jalankan miner ===
cd "$BASE_DIR"

if systemctl --user >/dev/null 2>&1; then
    log "Menjalankan XMRig menggunakan systemd --user"
    SERVICE_NAME="xmrig-miner.service"
    SYSTEMD_DIR="$HOME/.config/systemd/user"
    mkdir -p "$SYSTEMD_DIR"

    cat > "$SYSTEMD_DIR/$SERVICE_NAME" <<EOF
[Unit]
Description=XMRig Miner
After=network.target

[Service]
ExecStart=$XMRIG_BIN --config=$CONFIG
WorkingDirectory=$BASE_DIR
Restart=always

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now "$SERVICE_NAME"
    log "XMRig dijalankan sebagai systemd user service."
elif command -v tmux >/dev/null 2>&1; then
    log "Menjalankan XMRig di tmux session 'xmrig'"
    tmux new-session -d -s xmrig "$XMRIG_BIN --config=$CONFIG >> $LOGFILE 2>&1"
else
    log "Menjalankan XMRig di background dengan nohup"
    nohup "$XMRIG_BIN" --config="$CONFIG" >> "$LOGFILE" 2>&1 &
fi

# === Info sistem dasar ===
if command -v lscpu >/dev/null 2>&1; then
    CPU_INFO=$(lscpu | grep 'Model name' | head -1 | cut -d: -f2 | xargs)
else
    CPU_INFO=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs 2>/dev/null || echo "Unknown CPU")
fi
RAM_INFO=$(free -h 2>/dev/null | awk '/Mem:/ {print $2 " total, " $3 " used"}' || echo "Unknown RAM")

log "== Informasi Sistem =="
log "User: $(whoami)"
log "Hostname: $(hostname)"
log "CPU: $CPU_INFO"
log "RAM: $RAM_INFO"
log "Log file: $LOGFILE"
log "== Instalasi selesai ✅ =="
