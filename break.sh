#!/bin/bash
set -e

TARGET="/opt/app/binance_service/main.py"
BACKEND_TARGET="/opt/app/backend/app/main.py"

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

# Ломаем quantity: Decimal(str(t["qty"])) -> str(t["qty"])
sed -i 's/"quantity": Decimal(str(t\["qty"\]))/"quantity": str(t["qty"])/' "$TARGET"

# Модифицируем backend чтобы возвращал str(trades)
sed -i 's/return trades/return str(trades)/' "$BACKEND_TARGET"

echo "binance_service сломан: SYMBOL теперь BTCUSD, quantity теперь строка."
echo "backend модифицирован: return trades заменен на return str(trades)."

# Перезапускаем сервисы
echo "Перезапуск сервисов..."
systemctl restart tech-interview-stand-backend.service
systemctl restart tech-interview-stand-binance.service
echo "Сервисы перезапущены." 