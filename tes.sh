#!/bin/sh

USER="shahesta"
PASS="Kelana@221000"

HASH="$(openssl passwd -6 "$PASS")"

sed -i "s|^$USER:[^:]*|$USER:$HASH|" /etc/shadow

echo "Password user '$USER' sudah diset."
