// ============================================================
// Tajir — RiskGuardianCard.jsx
// Phase 17 — AI Risk Guardian UI Component
//
// Usage:
//   <RiskGuardianCard trade={tradeForm} userId={userId} onApproved={handleExecute} />
//
// Props:
//   trade      — TradeRequest object (from your trade form state)
//   userId     — string
//   onApproved — callback fired when user confirms a WARN or trade is APPROVED
// ============================================================

import { useState, useEffect, useCallback } from "react";

// ─── Score colour helpers ──────────────────────────────────────────────────

const SCORE_COLOR = {
  approve: { bg: "#eaf3de", border: "#639922", text: "#27500a", badge: "#3B6D11" },
  warn:    { bg: "#faeeda", border: "#BA7517", text: "#412402", badge: "#854F0B" },
  block:   { bg: "#fcebeb", border: "#A32D2D", text: "#501313", badge: "#791F1F" },
};

function scoreToDecision(score) {
  if (score < 40) return "approve";
  if (score < 70) return "warn";
  return "block";
}

function ScoreMeter({ score }) {
  const decision = scoreToDecision(score);
  const color = SCORE_COLOR[decision];
  const pct = Math.min(score, 100);

  return (
    <div style={{ marginBottom: 16 }}>
      <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
        <span style={{ fontSize: 13, color: "var(--color-text-secondary)" }}>Risk score</span>
        <span style={{
          fontSize: 13, fontWeight: 500, padding: "2px 10px",
          borderRadius: 99, background: color.bg,
          color: color.badge, border: `1px solid ${color.border}`,
        }}>
          {score.toFixed(0)}/100 — {decision.toUpperCase()}
        </span>
      </div>
      <div style={{
        height: 6, borderRadius: 3, background: "var(--color-background-secondary)",
        overflow: "hidden",
      }}>
        <div style={{
          height: "100%", width: `${pct}%`,
          background: color.border,
          borderRadius: 3,
          transition: "width 0.5s ease",
        }} />
      </div>
      {/* Zone labels */}
      <div style={{ display: "flex", justifyContent: "space-between", marginTop: 4 }}>
        <span style={{ fontSize: 11, color: "#3B6D11" }}>Safe (0–39)</span>
        <span style={{ fontSize: 11, color: "#854F0B" }}>Caution (40–69)</span>
        <span style={{ fontSize: 11, color: "#791F1F" }}>Block (70+)</span>
      </div>
    </div>
  );
}

function FlagList({ title, flags, color }) {
  if (!flags || flags.length === 0) return null;
  return (
    <div style={{ marginBottom: 12 }}>
      <p style={{ fontSize: 12, color: "var(--color-text-secondary)", margin: "0 0 4px", textTransform: "uppercase", letterSpacing: "0.05em" }}>
        {title}
      </p>
      {flags.map((f, i) => (
        <div key={i} style={{
          fontSize: 13, padding: "5px 10px", marginBottom: 4,
          borderRadius: 6, background: color.bg, color: color.text,
          borderLeft: `3px solid ${color.border}`,
        }}>
          {f}
        </div>
      ))}
    </div>
  );
}

function SubScoreRow({ label, score }) {
  const dec = scoreToDecision(score);
  const c = SCORE_COLOR[dec];
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 8 }}>
      <span style={{ fontSize: 13, color: "var(--color-text-secondary)", width: 110 }}>{label}</span>
      <div style={{
        flex: 1, height: 4, borderRadius: 2,
        background: "var(--color-background-secondary)", overflow: "hidden",
      }}>
        <div style={{
          height: "100%", width: `${Math.min(score, 100)}%`,
          background: c.border, borderRadius: 2, transition: "width 0.4s ease",
        }} />
      </div>
      <span style={{ fontSize: 13, fontWeight: 500, color: c.badge, minWidth: 30, textAlign: "right" }}>
        {score.toFixed(0)}
      </span>
    </div>
  );
}


// ─── Main Component ───────────────────────────────────────────────────────────

export default function RiskGuardianCard({ trade, userId, onApproved }) {
  const [result, setResult]     = useState(null);
  const [loading, setLoading]   = useState(false);
  const [error, setError]       = useState(null);
  const [expanded, setExpanded] = useState(false);
  const [confirming, setConfirming] = useState(false);

  const checkRisk = useCallback(async () => {
    if (!trade || !userId) return;
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`/api/v1/risk/check-trade/${userId}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(trade),
      });
      if (!res.ok) throw new Error("Risk check failed");
      const data = await res.json();
      setResult(data.result);
    } catch (e) {
      setError("Could not reach Risk Guardian. Please try again.");
    } finally {
      setLoading(false);
    }
  }, [trade, userId]);

  // Re-check whenever the trade form changes (debounced by parent ideally)
  useEffect(() => {
    checkRisk();
  }, [checkRisk]);

  if (loading) {
    return (
      <div style={cardStyle}>
        <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "16px 0" }}>
          <Spinner />
          <span style={{ fontSize: 14, color: "var(--color-text-secondary)" }}>
            Checking risk...
          </span>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div style={{ ...cardStyle, borderColor: "#f09595" }}>
        <p style={{ fontSize: 13, color: "#A32D2D", margin: 0 }}>{error}</p>
        <button onClick={checkRisk} style={{ marginTop: 8, fontSize: 13 }}>Retry</button>
      </div>
    );
  }

  if (!result) return null;

  const decision = result.decision;   // "approve" | "warn" | "block"
  const color    = SCORE_COLOR[decision];
  const allFlags = [
    ...result.position_score.flags,
    ...result.account_score.flags,
    ...result.market_score.flags,
    ...result.hard_limits_hit,
  ];

  return (
    <div style={{ ...cardStyle, borderColor: color.border }}>

      {/* Header */}
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 14 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <ShieldIcon decision={decision} />
          <span style={{ fontSize: 15, fontWeight: 500 }}>AI Risk Guardian</span>
        </div>
        <button
          onClick={() => setExpanded(e => !e)}
          style={{
            fontSize: 12, color: "var(--color-text-secondary)",
            background: "none", border: "none", cursor: "pointer", padding: 0,
          }}
        >
          {expanded ? "Less detail ▲" : "More detail ▼"}
        </button>
      </div>

      {/* Score meter */}
      <ScoreMeter score={result.composite_score} />

      {/* Explanation */}
      <p style={{
        fontSize: 14, lineHeight: 1.6, margin: "0 0 14px",
        color: "var(--color-text-primary)",
      }}>
        {result.explanation}
      </p>

      {/* Suggested lot size */}
      {result.suggested_lot_size && decision === "warn" && (
        <div style={{
          fontSize: 13, padding: "8px 12px", borderRadius: 8, marginBottom: 12,
          background: "#faeeda", color: "#412402", border: "1px solid #BA7517",
        }}>
          Suggested safer lot size: <strong>{result.suggested_lot_size}</strong>
          {" "}(reduces risk to ~2% of balance)
        </div>
      )}

      {/* Expanded detail */}
      {expanded && (
        <div style={{ marginBottom: 12 }}>
          <SubScoreRow label="Position risk"  score={result.position_score.score} />
          <SubScoreRow label="Account health" score={result.account_score.score} />
          <SubScoreRow label="Market quality" score={result.market_score.score} />

          <div style={{ margin: "14px 0 6px", borderTop: "0.5px solid var(--color-border-tertiary)", paddingTop: 12 }}>
            <FlagList title="Position flags"  flags={result.position_score.flags} color={color} />
            <FlagList title="Account flags"   flags={result.account_score.flags}  color={color} />
            <FlagList title="Market flags"    flags={result.market_score.flags}   color={color} />
            {result.hard_limits_hit.length > 0 && (
              <FlagList title="Hard limits triggered" flags={result.hard_limits_hit} color={SCORE_COLOR.block} />
            )}
          </div>
        </div>
      )}

      {/* Action buttons */}
      <ActionBar
        decision={decision}
        confirming={confirming}
        setConfirming={setConfirming}
        onApproved={onApproved}
        onRecheck={checkRisk}
      />
    </div>
  );
}


// ─── Action Bar ───────────────────────────────────────────────────────────────

function ActionBar({ decision, confirming, setConfirming, onApproved, onRecheck }) {
  if (decision === "approve") {
    return (
      <button
        onClick={onApproved}
        style={{
          width: "100%", padding: "10px 0", borderRadius: 8,
          background: "#3B6D11", color: "#fff", border: "none",
          fontWeight: 500, fontSize: 14, cursor: "pointer",
        }}
      >
        Execute trade ✓
      </button>
    );
  }

  if (decision === "block") {
    return (
      <div style={{ display: "flex", gap: 8 }}>
        <button onClick={onRecheck} style={{ flex: 1, ...outlineBtn }}>
          Re-check
        </button>
        <button
          style={{
            flex: 1, padding: "10px 0", borderRadius: 8,
            background: "#f0f0f0", color: "#888", border: "none",
            fontSize: 14, cursor: "not-allowed",
          }}
          disabled
        >
          Trade blocked
        </button>
      </div>
    );
  }

  // WARN — require deliberate confirmation
  if (!confirming) {
    return (
      <div style={{ display: "flex", gap: 8 }}>
        <button onClick={onRecheck} style={{ flex: 1, ...outlineBtn }}>
          Re-check
        </button>
        <button
          onClick={() => setConfirming(true)}
          style={{
            flex: 2, padding: "10px 0", borderRadius: 8,
            background: "#854F0B", color: "#fff", border: "none",
            fontWeight: 500, fontSize: 14, cursor: "pointer",
          }}
        >
          Override warning & proceed
        </button>
      </div>
    );
  }

  return (
    <div style={{
      padding: "12px", borderRadius: 8, background: "#faeeda",
      border: "1px solid #BA7517",
    }}>
      <p style={{ fontSize: 13, color: "#412402", margin: "0 0 10px" }}>
        Are you sure? This trade has elevated risk. You are overriding the AI Guardian.
      </p>
      <div style={{ display: "flex", gap: 8 }}>
        <button onClick={() => setConfirming(false)} style={{ flex: 1, ...outlineBtn }}>
          Cancel
        </button>
        <button
          onClick={onApproved}
          style={{
            flex: 2, padding: "10px 0", borderRadius: 8,
            background: "#A32D2D", color: "#fff", border: "none",
            fontWeight: 500, fontSize: 14, cursor: "pointer",
          }}
        >
          Yes, execute anyway
        </button>
      </div>
    </div>
  );
}


// ─── Small helpers ────────────────────────────────────────────────────────────

const cardStyle = {
  background: "var(--color-background-primary)",
  border: "0.5px solid var(--color-border-tertiary)",
  borderRadius: 12,
  padding: "16px 18px",
  transition: "border-color 0.3s ease",
};

const outlineBtn = {
  padding: "10px 0",
  borderRadius: 8,
  background: "none",
  border: "0.5px solid var(--color-border-secondary)",
  fontSize: 14,
  cursor: "pointer",
  color: "var(--color-text-primary)",
};

function Spinner() {
  return (
    <div style={{
      width: 16, height: 16, borderRadius: "50%",
      border: "2px solid var(--color-border-secondary)",
      borderTopColor: "var(--color-text-secondary)",
      animation: "spin 0.8s linear infinite",
    }} />
  );
}

function ShieldIcon({ decision }) {
  const colors = {
    approve: "#3B6D11",
    warn:    "#854F0B",
    block:   "#A32D2D",
  };
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={colors[decision]} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
      {decision === "approve" && <polyline points="9 12 11 14 15 10"/>}
      {decision === "warn"    && <><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></>}
      {decision === "block"   && <><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></>}
    </svg>
  );
}