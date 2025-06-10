from fastapi import FastAPI, Depends, status
from sqlalchemy import text
from .database import get_session
from .models import Trade
from decimal import Decimal
from typing import List
import os

app = FastAPI(title="Trades API")

@app.get("/healthz")
def healthz():
    return {"status": "ok"}

@app.get("/api/trades", response_model=List[Trade])
def list_trades(limit: int = 100, session=Depends(get_session)):
    rows = session.execute(
        text("SELECT symbol, price, quantity, price_per_unit, trade_timestamp "
             "FROM trades "
             "ORDER BY trade_timestamp DESC "
             "LIMIT :lim"),
        {"lim": limit},
    )
    return [Trade(
        symbol=row.symbol,
        price=row.price,
        quantity=row.quantity,
        price_per_unit=row.price_per_unit,
        trade_timestamp=row.trade_timestamp
    ) for row in rows]
