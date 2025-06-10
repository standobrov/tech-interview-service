
CREATE TABLE IF NOT EXISTS trades (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    price NUMERIC(18,8) NOT NULL,
    quantity NUMERIC(18,8) CHECK (quantity > 0),
    price_per_unit NUMERIC(18,8) GENERATED ALWAYS AS (price / quantity) STORED,
    trade_timestamp TIMESTAMPTZ NOT NULL,
    CONSTRAINT uq_trade UNIQUE(symbol, trade_timestamp)
);
CREATE INDEX IF NOT EXISTS idx_trades_ts ON trades (trade_timestamp DESC);
