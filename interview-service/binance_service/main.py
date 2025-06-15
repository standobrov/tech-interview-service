import asyncio, aiohttp, os, logging
from sqlalchemy import create_engine, text
from decimal import Decimal
from datetime import datetime, timezone
import random

DATABASE_URL = os.getenv("DATABASE_URL")
engine = create_engine(DATABASE_URL, pool_pre_ping=True)

SYMBOL = "BTCUSDT"
INTERVAL = 5
LOG_LEVEL = "INFO"

logging.basicConfig(level=LOG_LEVEL)
logger = logging.getLogger("binance_worker")

BINANCE_ENDPOINT = "https://api.binance.com/api/v3/trades"

async def extract_trade(session):
    params = {"symbol": SYMBOL, "limit": 1}
    async with session.get(BINANCE_ENDPOINT, params=params, timeout=10) as r:
        r.raise_for_status()
        data = await r.json()
        if data:
            t = data[0]
            return {
                "symbol": SYMBOL,
                "price": Decimal(str(t["price"])),
                "quantity": Decimal(str(t["qty"])),
                "trade_timestamp": datetime.fromtimestamp(t["time"]/1000, timezone.utc),
            }
    return None

def transform_trade(trade):
    return {**trade, "suspicious": random.choice([True, False])}

def load_trade(trade):
    with engine.begin() as conn:
        conn.execute(
            text("INSERT INTO trades (symbol, price, quantity, trade_timestamp, suspicious) "
                 "VALUES (:symbol, :price, :quantity, :trade_timestamp, :suspicious) ON CONFLICT DO NOTHING"),
            trade
        )
    return True

async def main():
    async with aiohttp.ClientSession() as session:
        while True:
            try:
                trade = await extract_trade(session)
                if trade:
                    transformed_trade = transform_trade(trade)
                    if load_trade(transformed_trade):
                        logger.info("Saved new trade %s", trade["trade_timestamp"])
                    else:
                        logger.debug("No new trades to save")
            except Exception as e:
                logger.warning("Error fetching trade: %s", e)
            await asyncio.sleep(INTERVAL)

if __name__ == "__main__":
    asyncio.run(main())
