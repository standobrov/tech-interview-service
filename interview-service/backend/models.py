from pydantic import BaseModel
from decimal import Decimal
from datetime import datetime

class Trade(BaseModel):
    symbol: str
    price: Decimal
    quantity: Decimal
    price_per_unit: Decimal
    trade_timestamp: datetime
    suspicious: bool
