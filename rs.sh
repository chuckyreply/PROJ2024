#!/bin/bash

USER="root"
SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG0ktrticGgHlkzABC0SiY66Z8snghdL90GOhL0BeKuQ"

HOME_DIR=$(eval echo "~$USER")
SSH_DIR="$HOME_DIR/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

# Pastikan folder .ssh ada
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# TIMPA authorized_keys
echo "$SSH_KEY" > "$AUTH_KEYS"

# Permission & ownership
chmod 600 "$AUTH_KEYS"
chown -R "$USER:$USER" "$SSH_DIR"

echo "✅ authorized_keys berhasil ditimpa untuk user $USER"
