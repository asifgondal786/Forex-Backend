-- ============================================================
-- TAJIR — New Tables for Frontend Phase 17+
-- Run in Supabase SQL Editor
-- All user_id columns use TEXT (Firebase UIDs are not UUIDs)
-- ============================================================

-- ─── auto_trade_config additions ──────────────────────────────────────────────
-- Extend existing table with new columns needed by AutomationProvider

ALTER TABLE auto_trade_config
  ADD COLUMN IF NOT EXISTS daily_loss_cap_usd   FLOAT   DEFAULT 200.0,
  ADD COLUMN IF NOT EXISTS max_open_trades       INT     DEFAULT 5,
  ADD COLUMN IF NOT EXISTS auto_follow_enabled   BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS show_ai_reasoning     BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS updated_at            TIMESTAMPTZ DEFAULT now();

-- ─── auto_trade_log additions ────────────────────────────────────────────────
-- Extend existing table with result column for LogEntry

ALTER TABLE auto_trade_log
  ADD COLUMN IF NOT EXISTS result       TEXT,
  ADD COLUMN IF NOT EXISTS triggered_by TEXT DEFAULT 'manual';

-- ─── paper_trades additions ──────────────────────────────────────────────────
-- Add columns needed by portfolio provider

ALTER TABLE paper_trades
  ADD COLUMN IF NOT EXISTS lot_size       FLOAT   DEFAULT 0.01,
  ADD COLUMN IF NOT EXISTS leverage       FLOAT   DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS exit_price     FLOAT,
  ADD COLUMN IF NOT EXISTS closed_at      TIMESTAMPTZ;

-- ─── user_settings (new) ─────────────────────────────────────────────────────
-- Stores beginner mode preferences — persists across devices

CREATE TABLE IF NOT EXISTS user_settings (
  user_id                 TEXT        PRIMARY KEY,
  beginner_mode_enabled   BOOLEAN     DEFAULT FALSE,
  daily_loss_cap          FLOAT       DEFAULT 100.0,
  max_leverage            FLOAT       DEFAULT 10.0,
  daily_loss_used         FLOAT       DEFAULT 0.0,
  last_reset_date         DATE        DEFAULT CURRENT_DATE,
  email_alerts            BOOLEAN     DEFAULT TRUE,
  push_alerts             BOOLEAN     DEFAULT TRUE,
  whatsapp_alerts         BOOLEAN     DEFAULT FALSE,
  trade_alerts            BOOLEAN     DEFAULT TRUE,
  risk_alerts             BOOLEAN     DEFAULT TRUE,
  market_alerts           BOOLEAN     DEFAULT FALSE,
  ai_alerts               BOOLEAN     DEFAULT TRUE,
  theme_mode              TEXT        DEFAULT 'dark',
  created_at              TIMESTAMPTZ DEFAULT now(),
  updated_at              TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users own settings" ON user_settings;
CREATE POLICY "users own settings"
  ON user_settings FOR ALL
  USING (user_id = auth.uid()::TEXT)
  WITH CHECK (user_id = auth.uid()::TEXT);

-- ─── market_prices (new) ──────────────────────────────────────────────────────
-- Cached live prices for mark-to-market and portfolio P&L

CREATE TABLE IF NOT EXISTS market_prices (
  pair        TEXT        PRIMARY KEY,
  bid         FLOAT       NOT NULL,
  ask         FLOAT       NOT NULL,
  mid         FLOAT       GENERATED ALWAYS AS ((bid + ask) / 2) STORED,
  spread      FLOAT       GENERATED ALWAYS AS ((ask - bid) * 10000) STORED,
  source      TEXT        DEFAULT 'twelve_data',
  updated_at  TIMESTAMPTZ DEFAULT now()
);

-- No RLS — public read, service-role write only
ALTER TABLE market_prices DISABLE ROW LEVEL SECURITY;

-- Seed common pairs (will be overwritten by live data service)
INSERT INTO market_prices (pair, bid, ask, source) VALUES
  ('EUR_USD', 1.08440, 1.08460, 'seed'),
  ('GBP_USD', 1.26280, 1.26310, 'seed'),
  ('USD_JPY', 149.480, 149.510, 'seed'),
  ('GBP_JPY', 188.320, 188.360, 'seed'),
  ('AUD_USD', 0.65090, 0.65110, 'seed'),
  ('USD_CHF', 0.89780, 0.89800, 'seed'),
  ('XAU_USD', 2339.50, 2340.50, 'seed')
ON CONFLICT (pair) DO NOTHING;

-- ─── notification_log (new) ──────────────────────────────────────────────────
-- Track which push/email/SMS notifications were actually sent

CREATE TABLE IF NOT EXISTS notification_log (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     TEXT        NOT NULL,
  channel     TEXT        NOT NULL,   -- 'push' | 'email' | 'sms' | 'whatsapp'
  title       TEXT,
  body        TEXT,
  sent_at     TIMESTAMPTZ DEFAULT now(),
  status      TEXT        DEFAULT 'sent'
);

ALTER TABLE notification_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users own notification_log" ON notification_log;
CREATE POLICY "users own notification_log"
  ON notification_log FOR SELECT
  USING (user_id = auth.uid()::TEXT);

-- ─── Indexes ─────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_paper_trades_user_status
  ON paper_trades (user_id, status);

CREATE INDEX IF NOT EXISTS idx_paper_trades_user_closed
  ON paper_trades (user_id, closed_at DESC)
  WHERE status = 'closed';

CREATE INDEX IF NOT EXISTS idx_auto_trade_log_user
  ON auto_trade_log (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON notifications (user_id, is_read, created_at DESC);

-- ─── Verify ──────────────────────────────────────────────────────────────────
SELECT table_name FROM information_schema.tables
  WHERE table_schema = 'public'
  ORDER BY table_name;
