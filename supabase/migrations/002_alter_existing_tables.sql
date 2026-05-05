-- ============================================================
-- Tajir — CORRECTED Migration (works with existing 48 tables)
-- Run in: Supabase Dashboard → SQL Editor
-- ============================================================

-- Step 1: Archive paper_trades data before eventual removal
CREATE TABLE IF NOT EXISTS public.paper_trades_archive AS 
SELECT * FROM public.paper_trades;

-- Step 2: Add missing columns to existing trades table
ALTER TABLE public.trades
    ADD COLUMN IF NOT EXISTS pair         TEXT,
    ADD COLUMN IF NOT EXISTS direction    TEXT,
    ADD COLUMN IF NOT EXISTS lot_size     NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS entry_price  NUMERIC(15,5),
    ADD COLUMN IF NOT EXISTS exit_price   NUMERIC(15,5),
    ADD COLUMN IF NOT EXISTS opened_at    TIMESTAMPTZ DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS closed_at    TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS realized_pnl NUMERIC(15,2),
    ADD COLUMN IF NOT EXISTS pnl_pips     NUMERIC(10,1),
    ADD COLUMN IF NOT EXISTS signal_id    TEXT,
    ADD COLUMN IF NOT EXISTS is_guided    BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS updated_at   TIMESTAMPTZ DEFAULT NOW();

-- Step 3: Add missing columns to existing risk_profiles table
ALTER TABLE public.risk_profiles
    ADD COLUMN IF NOT EXISTS max_position_size           NUMERIC(10,4) DEFAULT 0.1,
    ADD COLUMN IF NOT EXISTS macro_shield_enabled        BOOLEAN DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS macro_shield_minutes_before INTEGER DEFAULT 30,
    ADD COLUMN IF NOT EXISTS auto_close_on_drawdown      BOOLEAN DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS max_correlation_exposure    NUMERIC(5,2) DEFAULT 0.7,
    ADD COLUMN IF NOT EXISTS updated_at                  TIMESTAMPTZ DEFAULT NOW();

-- Step 4: Create guided_trades table (NEW — does not exist)
CREATE TABLE IF NOT EXISTS public.guided_trades (
    id                UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id           TEXT          NOT NULL,
    signal_id         UUID,
    trade_id          UUID,
    pair              TEXT          NOT NULL,
    direction         TEXT          NOT NULL,
    recommended_lot   NUMERIC(10,4) NOT NULL,
    entry_price       NUMERIC(15,5),
    stop_loss         NUMERIC(15,5) NOT NULL,
    take_profit       NUMERIC(15,5) NOT NULL,
    confidence        NUMERIC(5,2),
    ai_reasoning      TEXT,
    risk_score        NUMERIC(5,2),
    status            TEXT          DEFAULT 'pending',
    user_approved_at  TIMESTAMPTZ,
    executed_at       TIMESTAMPTZ,
    outcome           TEXT,
    outcome_pnl       NUMERIC(15,2),
    outcome_explained TEXT,
    created_at        TIMESTAMPTZ   DEFAULT NOW(),
    updated_at        TIMESTAMPTZ   DEFAULT NOW(),
    CONSTRAINT unique_user_guided UNIQUE(user_id)
);

-- Step 5: Create orders table (for order state machine — NEW)
CREATE TABLE IF NOT EXISTS public.orders (
    id                UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id           TEXT          NOT NULL,
    idempotency_key   TEXT          UNIQUE,
    pair              TEXT          NOT NULL,
    direction         TEXT          NOT NULL,
    lot_size          NUMERIC(10,4) NOT NULL,
    order_type        TEXT          DEFAULT 'market',
    limit_price       NUMERIC(15,5),
    state             TEXT          NOT NULL DEFAULT 'pending',
    state_history     JSONB         DEFAULT '[]'::jsonb,
    risk_approved     BOOLEAN,
    risk_rejection_reason TEXT,
    broker_order_id   TEXT,
    fill_price        NUMERIC(15,5),
    filled_quantity   NUMERIC(10,4) DEFAULT 0,
    slippage          NUMERIC(10,5),
    commission        NUMERIC(10,2) DEFAULT 0,
    submitted_at      TIMESTAMPTZ,
    filled_at         TIMESTAMPTZ,
    cancelled_at      TIMESTAMPTZ,
    created_at        TIMESTAMPTZ   DEFAULT NOW(),
    updated_at        TIMESTAMPTZ   DEFAULT NOW()
);

-- Step 6: Create equity_snapshots table (for portfolio charting — NEW)
CREATE TABLE IF NOT EXISTS public.equity_snapshots (
    id          UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     TEXT          NOT NULL,
    equity      NUMERIC(15,2) NOT NULL,
    balance     NUMERIC(15,2) NOT NULL,
    timestamp   TIMESTAMPTZ   DEFAULT NOW()
);

-- Step 7: Create ai_request_log table (for cost tracking — NEW)
CREATE TABLE IF NOT EXISTS public.ai_request_log (
    id            UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id       TEXT,
    task_type     TEXT          NOT NULL,
    model_used    TEXT          NOT NULL,
    fallback_used BOOLEAN       DEFAULT FALSE,
    input_tokens  INTEGER,
    output_tokens INTEGER,
    latency_ms    INTEGER,
    cost_usd      NUMERIC(10,6),
    success       BOOLEAN       DEFAULT TRUE,
    error         TEXT,
    created_at    TIMESTAMPTZ   DEFAULT NOW()
);

-- Step 8: Create audit_log table (NEW)
CREATE TABLE IF NOT EXISTS public.audit_log (
    id          UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     TEXT,
    action      TEXT          NOT NULL,
    details     JSONB,
    ip_address  INET,
    user_agent  TEXT,
    timestamp   TIMESTAMPTZ   DEFAULT NOW()
);

-- Step 9: Indexes (safe — IF NOT EXISTS)
CREATE INDEX IF NOT EXISTS idx_trades_user_id ON public.trades(user_id);
CREATE INDEX IF NOT EXISTS idx_trades_closed ON public.trades(closed_at DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_orders_user ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_idempotency ON public.orders(idempotency_key);
CREATE INDEX IF NOT EXISTS idx_equity_snapshots_user ON public.equity_snapshots(user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_guided_trades_user ON public.guided_trades(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_user ON public.audit_log(user_id, timestamp DESC);

-- Step 10: Auto-update trigger for updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger (safe — OR REPLACE + IF NOT EXISTS check)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'set_updated_at_trades') THEN
        CREATE TRIGGER set_updated_at_trades BEFORE UPDATE ON public.trades
            FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'set_updated_at_orders') THEN
        CREATE TRIGGER set_updated_at_orders BEFORE UPDATE ON public.orders
            FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'set_updated_at_guided') THEN
        CREATE TRIGGER set_updated_at_guided BEFORE UPDATE ON public.guided_trades
            FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
    END IF;
END$$;
