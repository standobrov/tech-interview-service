#!/bin/bash
set -e

GITEA_VERSION="1.21.11"
GITEA_USER="demo"
GITEA_PASS="demo123"
REPO_NAME="interview-service"
REPO_DIR="interview-service"

# Проверка, есть ли папка
if [ ! -d "$REPO_DIR" ]; then
  echo "❌ Папка $REPO_DIR не найдена"
  exit 1
fi

# Установка Gitea (если не установлен)
if ! command -v gitea &> /dev/null; then
  echo "📦 Устанавливаю Gitea..."
  wget -q https://dl.gitea.io/gitea/${GITEA_VERSION}/gitea-${GITEA_VERSION}-linux-amd64 -O /usr/local/bin/gitea
  chmod +x /usr/local/bin/gitea

  useradd --system --shell /bin/bash --comment 'Git Version Control' --create-home --home-dir /home/gitea gitea || true

  mkdir -p /var/lib/gitea/{custom,data,log}
  mkdir -p /etc/gitea
  chown -R gitea:gitea /var/lib/gitea/
  chown -R gitea:gitea /etc/gitea/
  chmod -R 750 /var/lib/gitea/
fi

# systemd unit
if [ ! -f /etc/systemd/system/gitea.service ]; then
  echo "⚙️ Создаю systemd unit..."
  cat > /etc/systemd/system/gitea.service <<EOF
[Unit]
Description=Gitea (Git with a cup of tea)
After=network.target

[Service]
RestartSec=2s
Type=simple
User=gitea
Group=gitea
WorkingDirectory=/var/lib/gitea/
ExecStart=/usr/local/bin/gitea web --config /etc/gitea/app.ini
Restart=always
Environment=USER=gitea HOME=/home/gitea GITEA_WORK_DIR=/var/lib/gitea

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reexec
  systemctl daemon-reload
fi

# Запуск Gitea
echo "🚀 Запускаю Gitea..."
systemctl enable gitea
systemctl start gitea

echo "⏳ Жду старта Gitea..."
sleep 5

# Создание пользователя demo
echo "👤 Создаю пользователя $GITEA_USER..."
curl -s -X POST http://localhost:3000/api/v1/admin/users \
  -H "Content-Type: application/json" \
  -u "admin:admin" \
  -d '{
    "email": "demo@example.com",
    "username": "'"$GITEA_USER"'",
    "password": "'"$GITEA_PASS"'"
  }' || echo "ℹ️ Возможно, пользователь уже существует"

# Получение токена
echo "🔑 Получаю токен..."
TOKEN=$(curl -s -X POST http://localhost:3000/api/v1/users/$GITEA_USER/tokens \
  -u "$GITEA_USER:$GITEA_PASS" \
  -H "Content-Type: application/json" \
  -d '{"name":"init-token"}' | jq -r .sha1)

# Создание репозитория
echo "📁 Создаю репозиторий $REPO_NAME..."
curl -s -X POST http://localhost:3000/api/v1/user/repos \
  -H "Authorization: token $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"'"$REPO_NAME"'"}' > /dev/null

# Инициализация git и пуш
cd "$REPO_DIR"
git init
git config user.name "$GITEA_USER"
git config user.email "demo@example.com"
git remote add origin "http://$GITEA_USER:$GITEA_PASS@localhost:3000/$GITEA_USER/$REPO_NAME.git"
git add .
git commit -m "Initial commit"
git push -u origin master

echo "✅ Репозиторий $REPO_NAME успешно пушнут в Gitea!"

TARGET="interview-service/binance_service/main.py"
BACKEND_TARGET="interview-service/backend/main.py"

if [ ! -f "$TARGET" ]; then
  echo "Файл $TARGET не найден!"
  exit 1
fi

if [ ! -f "$BACKEND_TARGET" ]; then
  echo "Файл $BACKEND_TARGET не найден!"
  exit 1
fi

# Ломаем SYMBOL
sed -i 's/SYMBOL = "BTCUSDT"/SYMBOL = "BTCUSD"/' "$TARGET"

# Модифицируем backend чтобы возвращал str(trades)
sed -i 's/return trades/return str(trades)/' "$BACKEND_TARGET"

# Replace boolean values with strings in transform_trade function
sed -i 's/random.choice(\[True, False\])/random.choice(["True", "False"])/' "$TARGET"

echo "binance_service сломан: SYMBOL теперь BTCUSD, quantity теперь строка."
echo "backend модифицирован: return trades заменен на return str(trades)."
echo "Setup completed successfully!"

git add .
git commit -m "vibecoded something, not sure what exactly"
git push -u origin master