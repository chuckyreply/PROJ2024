#!/bin/bash

VERSION=2.11
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
MO_DIR="$BASE_DIR/moneroocean"

echo "MoneroOcean mining setup script v$VERSION (lokal)."
echo "File akan disimpan di: $MO_DIR"
echo

if [ "$(id -u)" == "0" ]; then
  echo "WARNING: Tidak disarankan menjalankan script ini sebagai root."
fi

WALLET=$1
EMAIL=$2

if [ -z "$WALLET" ]; then
  echo "Usage: setup_moneroocean_miner.sh <wallet address> [<email>]"
  exit 1
fi

WALLET_BASE=$(echo "$WALLET" | cut -f1 -d".")
if [ ${#WALLET_BASE} != 106 -a ${#WALLET_BASE} != 95 ]; then
  echo "ERROR: Wallet address salah (harus 95 atau 106 karakter)"
  exit 1
fi

if ! command -v curl >/dev/null; then
  echo "ERROR: butuh curl untuk melanjutkan"
  exit 1
fi

CPU_THREADS=$(nproc)
EXP_MONERO_HASHRATE=$(( CPU_THREADS * 700 / 1000 ))

power2() {
  if ! command -v bc >/dev/null; then
    echo "64"
  else
    echo "x=l($1)/l(2); scale=0; 2^((x+0.5)/1)" | bc -l
  fi
}

PORT=$(( $EXP_MONERO_HASHRATE * 30 ))
PORT=$(( $PORT == 0 ? 1 : $PORT ))
PORT=$(power2 $PORT)
PORT=$(( 10000 + $PORT ))

echo "Host memiliki $CPU_THREADS thread CPU (~$EXP_MONERO_HASHRATE KH/s)"
echo "Pool port dipilih: $PORT"
sleep 2

echo "[*] Menghapus instalasi lama (jika ada)"
sudo systemctl stop moneroocean_miner.service 2>/dev/null || true
sudo systemctl disable moneroocean_miner.service 2>/dev/null || true
killall -9 xmrig 2>/dev/null || true
rm -rf "$MO_DIR"

echo "[*] Mengunduh XMRig (MoneroOcean build)"
mkdir -p "$MO_DIR"
curl -L --progress-bar "https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/xmrig.tar.gz" -o /tmp/xmrig.tar.gz
tar xf /tmp/xmrig.tar.gz -C "$MO_DIR"
rm -f /tmp/xmrig.tar.gz

sed -i 's/"donate-level": *[^,]*,/"donate-level": 1,/' "$MO_DIR/config.json"

"$MO_DIR/xmrig" --help >/dev/null || {
  echo "ERROR: xmrig gagal dijalankan"
  exit 1
}

PASS=$(hostname | cut -f1 -d"." | sed -r 's/[^a-zA-Z0-9\-]+/_/g')
[ "$PASS" == "localhost" ] && PASS=$(ip route get 1 | awk '{print $NF;exit}')
[ -z "$PASS" ] && PASS=na
[ ! -z "$EMAIL" ] && PASS="$PASS:$EMAIL"

sed -i 's/"url": *"[^"]*",/"url": "gulf.moneroocean.stream:'$PORT'",/' "$MO_DIR/config.json"
sed -i 's/"user": *"[^"]*",/"user": "'$WALLET'",/' "$MO_DIR/config.json"
sed -i 's/"pass": *"[^"]*",/"pass": "'$PASS'",/' "$MO_DIR/config.json"
sed -i 's/"max-cpu-usage": *[^,]*,/"max-cpu-usage": 100,/' "$MO_DIR/config.json"
sed -i 's#"log-file": *null,#"log-file": "'$MO_DIR/xmrig.log'",#' "$MO_DIR/config.json"
sed -i 's/"syslog": *[^,]*,/"syslog": true,/' "$MO_DIR/config.json"

cp "$MO_DIR/config.json" "$MO_DIR/config_background.json"
sed -i 's/"background": *false,/"background": true,/' "$MO_DIR/config_background.json"

echo "[*] Membuat script miner.sh"
cat >"$MO_DIR/miner.sh" <<EOL
#!/bin/bash
if ! pidof xmrig >/dev/null; then
  nice "$MO_DIR/xmrig" \$*
else
  echo "Miner sudah berjalan di background. Gunakan 'killall xmrig' jika ingin menghentikannya."
fi
EOL
chmod +x "$MO_DIR/miner.sh"

if ! sudo -n true 2>/dev/null; then
  if ! grep -q "moneroocean/miner.sh" ~/.profile; then
    echo "[*] Menambahkan autostart ke ~/.profile"
    echo "$MO_DIR/miner.sh --config=$MO_DIR/config_background.json >/dev/null 2>&1" >> ~/.profile
  fi
  echo "[*] Menjalankan miner di background..."
  bash "$MO_DIR/miner.sh" --config="$MO_DIR/config_background.json" >/dev/null 2>&1 &
else
  echo "[*] Membuat service systemd..."
  SERVICE_FILE="/etc/systemd/system/moneroocean_miner.service"
  sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=MoneroOcean Miner
After=network.target

[Service]
ExecStart=$MO_DIR/xmrig --config=$MO_DIR/config.json
WorkingDirectory=$MO_DIR
Restart=always
Nice=10
CPUWeight=75

[Install]
WantedBy=multi-user.target
EOL
  sudo systemctl daemon-reload
  sudo systemctl enable moneroocean_miner.service
  sudo systemctl start moneroocean_miner.service
  echo "Gunakan: sudo journalctl -u moneroocean_miner -f untuk melihat log"
fi

echo
echo "✅ Setup complete!"
echo "📁 Semua file disimpan di: $MO_DIR"
echo "💡 Jalankan manual: $MO_DIR/miner.sh"
