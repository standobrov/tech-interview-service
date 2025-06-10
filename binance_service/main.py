import asyncio, aiohttp, os, logging
from sqlalchemy import create_engine, text
from decimal import Decimal
from datetime import datetime, timezone

DATABASE_URL = os.getenv("DATABASE_URL")
engine = create_engine(DATABASE_URL, pool_pre_ping=True)

SYMBOL = os.getenv("BINANCE_SYMBOL", "BTCUSDT")
INTERVAL = int(os.getenv("FETCH_INTERVAL", 5))
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()

logging.basicConfig(level=LOG_LEVEL)
logger = logging.getLogger("binance_worker")

BINANCE_ENDPOINT = "https://api.binance.com/api/v3/trades"

# Track the last saved trade
last_saved_trade = None

async def fetch_trade(session):
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

def save_trade(trade):
    global last_saved_trade
    
    # Skip if this is the same trade as last time
    if (last_saved_trade and 
        last_saved_trade["trade_timestamp"] == trade["trade_timestamp"] and
        last_saved_trade["price"] == trade["price"] and
        last_saved_trade["quantity"] == trade["quantity"]):
        logger.debug("Skipping duplicate trade %s", trade["trade_timestamp"])
        return False
    
    with engine.begin() as conn:
        conn.execute(
            text("INSERT INTO trades (symbol, price, quantity, trade_timestamp) "
                 "VALUES (:symbol, :price, :quantity, :trade_timestamp) ON CONFLICT DO NOTHING"),
            trade
        )
    last_saved_trade = trade
    return True

async def main():
    async with aiohttp.ClientSession() as session:
        while True:
            try:
                trade = await fetch_trade(session)
                if trade and trade["quantity"] > 0:
                    if save_trade(trade):
                        logger.info("Saved new trade %s", trade["trade_timestamp"])
                    else:
                        logger.debug("No new trades to save")
            except Exception as e:
                logger.warning("Error fetching trade: %s", e)
            await asyncio.sleep(INTERVAL)

if __name__ == "__main__":
    asyncio.run(main())
