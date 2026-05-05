-- ============================================================
-- Tajir — Supabase Database Schema
-- Run in: Supabase Dashboard → SQL Editor
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── Orders (trade order lifecycle with state machine) ──────
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    idempotency_key TEXT UNIQUE,
    pair TEXT NOT NULL,
    direction TEXT NOT NULL CHECK (direction IN ('buy', 'sell')),
    lot_size DECIMAL(10, 4) NOT NULL,
    order_type TEXT DEFAULT 'market' CHECK (order_type IN ('market', 'limit', 'stop')),
    limit_price DECIMAL(15, 5),
    state TEXT NOT NULL DEFAULT 'pending',
    state_history JSONB DEFAULT '[]'::jsonb,
    risk_approved BOOLEAN,
    risk_rejection_reason TEXT,
    broker_order_id TEXT,
    fill_price DECIMAL(15, 5),
    filled_quantity DECIMAL(10, 4) DEFAULT 0,
    slippage DECIMAL(10, 5),
    commission DECIMAL(10, 2) DEFAULT 0,
    submitted_at TIMESTAMPTZ,
    filled_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─── Trades (open and closed positions) ─────────────────────
CREATE TABLE IF NOT EXISTS public.trades (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    order_id UUID REFERENCES public.orders(id),
    pair TEXT NOT NULL,
    direction TEXT NOT NULL CHECK (direction IN ('buy', 'sell')),
    lot_size DECIMAL(10, 4) NOT NULL,
    entry_price DECIMAL(15, 5) NOT NULL,
    stop_loss DECIMAL(15, 5),
    take_profit DECIMAL(15, 5),
    exit_price DECIMAL(15, 5),
    status TEXT DEFAULT 'open' CHECK (status IN ('open', 'closed', 'cancelled')),
    realized_pnl DECIMAL(15, 2),
    pnl_pips DECIMAL(10, 1),
    signal_id UUID,
    is_copy_trade BOOLEAN DEFAULT FALSE,
    source_user_id UUID,
    opened_at TIMESTAMPTZ DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─── Signals (AI-generated) ─────────────────────────────────
CREATE TABLE IF NOT EXISTS public.signals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pair TEXT NOT NULL,
    direction TEXT NOT NULL CHECK (direction IN ('buy', 'sell')),
    entry_price DECIMAL(15, 5) NOT NULL,
    stop_loss DECIMAL(15, 5) NOT NULL,
    take_profit DECIMAL(15, 5) NOT NULL,
    confidence DECIMAL(5, 2) NOT NULL CHECK (confidence BETWEEN 0 AND 100),
    risk_reward_ratio DECIMAL(5, 2),
    ai_model_used TEXT,
    reasoning TEXT,
    technical_indicators JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    outcome TEXT CHECK (outcome IN ('win', 'loss', 'breakeven', 'expired')),
    expires_at TIMESTAMPTZ NOT NULL,
    triggered_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─── Portfolio (real-time account state) ────────────────────
CREATE TABLE IF NOT EXISTS public.portfolio (
    user_id UUID PRIMARY KEY,
    balance DECIMAL(15, 2) DEFAULT 0,
    equity DECIMAL(15, 2) DEFAULT 0,
    margin_used DECIMAL(15, 2) DEFAULT 0,
    free_margin DECIMAL(15, 2) DEFAULT 0,
    unrealized_pnl DECIMAL(15, 2) DEFAULT 0,
    realized_pnl_today DECIMAL(15, 2) DEFAULT 0,
    total_realized_pnl DECIMAL(15, 2) DEFAULT 0,
    win_rate DECIMAL(5, 2) DEFAULT 0,
    total_trades INTEGER DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─── Equity Snapshots (for charting) ────────────────────────
CREATE TABLE IF NOT EXISTS public.equity_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    equity DECIMAL(15, 2) NOT NULL,
    balance DECIMAL(15, 2) NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- ─── Risk Settings ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.risk_settings (
    user_id UUID PRIMARY KEY,
    max_daily_loss_pct DECIMAL(5, 2) DEFAULT 3.0,
    max_drawdown_pct DECIMAL(5, 2) DEFAULT 10.0,
    max_position_size DECIMAL(10, 4) DEFAULT 0.1,
    max_open_positions INTEGER DEFAULT 5,
    max_correlation_exposure DECIMAL(5, 2) DEFAULT 0.7,
    macro_shield_enabled BOOLEAN DEFAULT TRUE,
    macro_shield_minutes_before INTEGER DEFAULT 30,
    auto_close_on_drawdown BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─── AI Request Log (cost tracking) ────────────────────────
CREATE TABLE IF NOT EXISTS public.ai_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID,
    task_type TEXT NOT NULL,
    model_used TEXT NOT NULL,
    fallback_used BOOLEAN DEFAULT FALSE,
    input_tokens INTEGER,
    output_tokens INTEGER,
    latency_ms INTEGER,
    cost_usd DECIMAL(10, 6),
    success BOOLEAN DEFAULT TRUE,
    error TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─── Audit Log ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID,
    action TEXT NOT NULL,
    details JSONB,
    ip_address INET,
    user_agent TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- ─── Macro Events ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.macro_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    country TEXT,
    currency TEXT,
    impact TEXT CHECK (impact IN ('high', 'medium', 'low')),
    forecast TEXT,
    previous TEXT,
    actual TEXT,
    event_time TIMESTAMPTZ NOT NULL,
    source TEXT DEFAULT 'forex_factory',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════
-- INDEXES
-- ═══════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_orders_user ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_idempotency ON public.orders(idempotency_key);
CREATE INDEX IF NOT EXISTS idx_orders_active ON public.orders(state) WHERE state NOT IN ('filled', 'cancelled_by_user', 'broker_rejected');
CREATE INDEX IF NOT EXISTS idx_trades_user ON public.trades(user_id);
CREATE INDEX IF NOT EXISTS idx_trades_open ON public.trades(user_id, status) WHERE status = 'open';
CREATE INDEX IF NOT EXISTS idx_trades_closed ON public.trades(user_id, closed_at DESC);
CREATE INDEX IF NOT EXISTS idx_signals_active ON public.signals(is_active, expires_at) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_equity_user ON public.equity_snapshots(user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_user ON public.audit_log(user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_ai_requests ON public.ai_requests(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_macro_time ON public.macro_events(event_time);

-- ═══════════════════════════════════════════════════════════════
-- RLS (Row Level Security)
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.portfolio ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.risk_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equity_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users own orders" ON public.orders FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users own trades" ON public.trades FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users own portfolio" ON public.portfolio FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users own risk" ON public.risk_settings FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users own equity" ON public.equity_snapshots FOR ALL USING (auth.uid() = user_id);

-- Signals are readable by all authenticated users
ALTER TABLE public.signals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Signals public read" ON public.signals FOR SELECT USING (auth.role() = 'authenticated');

-- Macro events are fully public
ALTER TABLE public.macro_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Macro events public" ON public.macro_events FOR SELECT USING (TRUE);

-- ═══════════════════════════════════════════════════════════════
-- TRIGGERS
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.orders
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.risk_settings
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
