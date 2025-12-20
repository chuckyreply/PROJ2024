#!/bin/bash

KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG0ktrticGgHlkzABC0SiY66Z8snghdL90GOhL0BeKuQ"

mkdir -p /root/.ssh
echo "$KEY" > /root/.ssh/authorized_keys

chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh

sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

systemctl restart sshd

echo "DONE"
