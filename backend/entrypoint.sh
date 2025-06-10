#!/usr/bin/env bash
set -e

: "${SSH_USER:?Need SSH_USER}"
: "${SSH_PASS:?Need SSH_PASS}"

useradd -ms /bin/bash "$SSH_USER"
echo "$SSH_USER:$SSH_PASS" | chpasswd

sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
echo 'ChallengeResponseAuthentication no' >> /etc/ssh/sshd_config

/usr/sbin/sshd

# start API
exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --log-level info
