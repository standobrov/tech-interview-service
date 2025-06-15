#!/bin/bash
set -e

# ─── ПАРАМЕТРЫ ─────────────────────────────────────────────────────────────
GITEA_VERSION="1.21.11"
GITEA_USER="demo"
GITEA_PASS="demo123"
REPO_NAME="interview-service"
REPO_DIR="interview-service"
GITEA_ROOT="/var/lib/gitea"
GITEA_URL="http://localhost:3000"
SYSTEMD_UNIT="/etc/systemd/system/gitea.service"
BIN_PATH="/usr/local/bin/gitea"

# ─── 0. СНОСИМ ПРЕЖНЮЮ GITEA ПОД НОЛЬ ─────────────────────────────────────
systemctl stop    gitea 2>/dev/null || true
systemctl disable gitea 2>/dev/null || true
rm -f   "$SYSTEMD_UNIT"
systemctl daemon-reload
pkill -f "$BIN_PATH" 2>/dev/null || true
rm -f  "$BIN_PATH"
rm -rf "$GITEA_ROOT" /etc/gitea

# ─── 1. ПАКЕТЫ ────────────────────────────────────────────────────────────
apt-get update -y
apt-get install -y jq curl git

# ─── 2. УСТАНАВЛИВАЕМ GITEA ───────────────────────────────────────────────
wget -q https://dl.gitea.io/gitea/${GITEA_VERSION}/gitea-${GITEA_VERSION}-linux-amd64 -O "$BIN_PATH"
chmod +x "$BIN_PATH"

useradd --system --shell /bin/bash --comment 'Git' \
        --create-home --home-dir /home/gitea gitea 2>/dev/null || true

mkdir -p "$GITEA_ROOT"/{custom,data,log,tmp} /etc/gitea
chown -R gitea:gitea "$GITEA_ROOT" /etc/gitea
chmod -R 750 "$GITEA_ROOT"

cat > /etc/gitea/app.ini <<EOF
[server]
HTTP_PORT = 3000
ROOT_URL  = $GITEA_URL/
START_SSH_SERVER = false

[database]
DB_TYPE = sqlite3
PATH    = $GITEA_ROOT/data/gitea.db

[security]
INSTALL_LOCK = true
SECRET_KEY   = somesecret

[repository]
DEFAULT_BRANCH        = main
ALLOW_PUSH_TO_CREATE  = true
EOF
chown -R gitea:gitea /etc/gitea

cat > "$SYSTEMD_UNIT" <<EOF
[Unit]
Description=Gitea
After=network.target

[Service]
User=gitea
Group=gitea
WorkingDirectory=$GITEA_ROOT
Environment=GITEA_WORK_DIR=$GITEA_ROOT
ExecStart=$BIN_PATH web --work-path $GITEA_ROOT --config /etc/gitea/app.ini
Restart=always
RestartSec=2s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gitea
systemctl start  gitea

echo "⏳ Ждём, пока Gitea поднимется…"
for i in {1..60}; do
  if curl -fs "$GITEA_URL/api/v1/version" >/dev/null; then
    echo "✅ Gitea запустилась"
    break
  fi
  sleep 1
done

# ─── 3. СОЗДАЁМ ПОЛЬЗОВАТЕЛЯ demo ─────────────────────────────────────────
sudo -u gitea "$BIN_PATH" --work-path "$GITEA_ROOT" --config /etc/gitea/app.ini \
  admin user create --username "$GITEA_USER" \
  --password "$GITEA_PASS" --email "$GITEA_USER@example.com" --admin \
  2>/dev/null || true

# ─── 4. СОЗДАЁМ / ЧИСТИМ РЕПОЗИТОРИЙ ЧЕРЕЗ BASIC-AUTH ────────────────────
echo "📁 Пересоздаём репозиторий $REPO_NAME"
curl -s -X DELETE "$GITEA_URL/api/v1/repos/$GITEA_USER/$REPO_NAME" \
     -u "$GITEA_USER:$GITEA_PASS" >/dev/null || true

HTTP=$(curl -s -o /tmp/resp.json -w '%{http_code}' \
        -X POST "$GITEA_URL/api/v1/user/repos" \
        -u "$GITEA_USER:$GITEA_PASS" \
        -H "Content-Type: application/json" \
        -d '{"name":"'"$REPO_NAME"'","auto_init":true,"default_branch":"main"}')

if [ "$HTTP" != "201" ]; then
  echo "❌ Не удалось создать репозиторий (HTTP $HTTP)"
  cat /tmp/resp.json
  exit 1
fi
echo "✅ Репозиторий создан"

# ─── 5. ДВА КОММИТА И PUSH ───────────────────────────────────────────────
cd "$REPO_DIR"
rm -rf .git
git init --initial-branch=main
git config user.name  "$GITEA_USER"
git config user.email "$GITEA_USER@example.com"
git remote add origin "http://$GITEA_USER:$GITEA_PASS@localhost:3000/$GITEA_USER/$REPO_NAME.git"

# подтягиваем README, чтобы push был fast-forward
git pull --quiet origin main

echo "🚀 Пушим рабочий коммит"
git add .
git commit -m "✅ Initial working commit"
git push -u origin main

echo "💥 Вносим баги и пушим"
sed -i 's/SYMBOL = "BTCUSDT"/SYMBOL = "BTCUSD"/' binance_service/main.py
sed -i 's/return trades/return str(trades)/'      backend/main.py
sed -i 's/random.choice(\[True, False\])/random.choice(["True", "False"])/' binance_service/main.py
git add .
git commit -m "💥 break: str instead of Decimal + fake bool"
git push -u origin main

echo "✅ Gitea готова, два коммита отпушены"