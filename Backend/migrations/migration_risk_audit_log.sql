-- ============================================================
-- Tajir Phase 17 — Risk Guardian Audit Log
-- Run in Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS risk_audit_log (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          TEXT NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Trade details
    symbol           TEXT NOT NULL,
    direction        TEXT NOT NULL CHECK (direction IN ('buy', 'sell')),
    lot_size         NUMERIC(10,2) NOT NULL,
    leverage         INTEGER NOT NULL,
    source           TEXT NOT NULL DEFAULT 'manual',
    trust_level      TEXT NOT NULL DEFAULT 'assist',

    -- Guardian output
    composite_score  NUMERIC(5,1) NOT NULL,
    decision         TEXT NOT NULL CHECK (decision IN ('approve', 'warn', 'block')),
    explanation      TEXT NOT NULL,

    -- Detailed flags (stored as JSON arrays)
    position_flags   JSONB NOT NULL DEFAULT '[]'::jsonb,
    account_flags    JSONB NOT NULL DEFAULT '[]'::jsonb,
    market_flags     JSONB NOT NULL DEFAULT '[]'::jsonb,
    hard_limits_hit  JSONB NOT NULL DEFAULT '[]'::jsonb,

    -- Sub-scores
    position_score   NUMERIC(5,1),
    account_score    NUMERIC(5,1),
    market_score     NUMERIC(5,1),

    -- Safe suggestion
    suggested_lot    NUMERIC(10,2)
);

-- Index for per-user audit history (most common query)
CREATE INDEX IF NOT EXISTS risk_audit_log_user_created
    ON risk_audit_log (user_id, created_at DESC);

-- Index for analytics — how many blocks per decision type
CREATE INDEX IF NOT EXISTS risk_audit_log_decision
    ON risk_audit_log (decision, created_at DESC);

-- Row Level Security — users see only their own logs
ALTER TABLE risk_audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see own risk logs"
    ON risk_audit_log FOR SELECT
    USING (auth.uid()::text = user_id);

-- Admins can read all (for monitoring / support)
CREATE POLICY "Service role reads all"
    ON risk_audit_log FOR ALL
    USING (auth.role() = 'service_role');

-- ============================================================
-- Optional: Daily summary view (useful for dashboard analytics)
-- ============================================================

CREATE OR REPLACE VIEW risk_daily_summary AS
SELECT
    user_id,
    DATE(created_at) AS trade_date,
    COUNT(*)                                          AS total_checks,
    SUM(CASE WHEN decision = 'approve' THEN 1 ELSE 0 END) AS approved,
    SUM(CASE WHEN decision = 'warn'    THEN 1 ELSE 0 END) AS warned,
    SUM(CASE WHEN decision = 'block'   THEN 1 ELSE 0 END) AS blocked,
    ROUND(AVG(composite_score), 1)                    AS avg_risk_score
FROM risk_audit_log
GROUP BY user_id, DATE(created_at);