// ============================================================
// Tajir — EventShieldPanel.jsx
// Phase 18 — Macro Event Shield UI
//
// Usage:
//   <EventShieldPanel symbol="EURUSD" />
//
// Shows:
//   - Active block banner when inside a news window
//   - Countdown to next high-impact event
//   - List of upcoming events for the symbol's currencies
// ============================================================

import { useState, useEffect, useRef } from "react";

const IMPACT_COLOR = {
  high:   { bg: "#fcebeb", border: "#A32D2D", text: "#501313", dot: "#E24B4A" },
  medium: { bg: "#faeeda", border: "#BA7517", text: "#412402", dot: "#EF9F27" },
  low:    { bg: "#eaf3de", border: "#639922", text: "#27500a", dot: "#97C459" },
};

const CURRENCY_FLAG = { USD: "🇺🇸", EUR: "🇪🇺", GBP: "🇬🇧", JPY: "🇯🇵" };

function formatMinutes(minutes) {
  if (minutes < 0)  return "now";
  if (minutes < 60) return `${Math.round(minutes)}m`;
  const h = Math.floor(minutes / 60);
  const m = Math.round(minutes % 60);
  return m > 0 ? `${h}h ${m}m` : `${h}h`;
}

function formatTime(isoString) {
  const d = new Date(isoString);
  return d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", timeZoneName: "short" });
}

function minutesUntil(isoString) {
  return (new Date(isoString) - Date.now()) / 60000;
}


// ─── Active Block Banner ──────────────────────────────────────────────────────

function BlockBanner({ windowResult }) {
  const [tick, setTick] = useState(0);
  useEffect(() => {
    const id = setInterval(() => setTick(t => t + 1), 30000);
    return () => clearInterval(id);
  }, []);

  const endsAt   = windowResult.window_ends_at ? new Date(windowResult.window_ends_at) : null;
  const minsLeft = endsAt ? Math.max(0, (endsAt - Date.now()) / 60000) : null;

  return (
    <div style={{
      background: "#fcebeb",
      border: "1px solid #A32D2D",
      borderRadius: 10,
      padding: "12px 14px",
      marginBottom: 14,
      display: "flex",
      alignItems: "flex-start",
      gap: 10,
    }}>
      <ShieldBlockIcon />
      <div style={{ flex: 1 }}>
        <p style={{ margin: "0 0 4px", fontWeight: 500, fontSize: 14, color: "#501313" }}>
          Trading blocked — news window active
        </p>
        <p style={{ margin: 0, fontSize: 13, color: "#791F1F", lineHeight: 1.5 }}>
          {windowResult.reason}
        </p>
        {minsLeft !== null && (
          <p style={{ margin: "6px 0 0", fontSize: 12, color: "#A32D2D" }}>
            Window lifts in ~{Math.ceil(minsLeft)} min
          </p>
        )}
      </div>
    </div>
  );
}


// ─── Upcoming Event Row ───────────────────────────────────────────────────────

function EventRow({ event }) {
  const mins   = minutesUntil(event.event_time);
  const color  = IMPACT_COLOR[event.impact] || IMPACT_COLOR.low;
  const urgent = mins > 0 && mins <= 30;

  return (
    <div style={{
      display: "flex",
      alignItems: "center",
      gap: 10,
      padding: "9px 0",
      borderBottom: "0.5px solid var(--color-border-tertiary)",
    }}>
      {/* Impact dot */}
      <div style={{
        width: 8, height: 8, borderRadius: "50%",
        background: color.dot, flexShrink: 0,
      }} />

      {/* Flag + currency */}
      <span style={{ fontSize: 13, minWidth: 44, color: "var(--color-text-secondary)" }}>
        {CURRENCY_FLAG[event.currency] || ""} {event.currency}
      </span>

      {/* Title */}
      <span style={{
        fontSize: 13, flex: 1,
        color: "var(--color-text-primary)",
        fontWeight: urgent ? 500 : 400,
      }}>
        {event.title}
      </span>

      {/* Forecast pill */}
      {event.forecast && (
        <span style={{
          fontSize: 11, padding: "2px 7px",
          borderRadius: 99,
          background: "var(--color-background-secondary)",
          color: "var(--color-text-secondary)",
          whiteSpace: "nowrap",
        }}>
          F: {event.forecast}
        </span>
      )}

      {/* Countdown */}
      <span style={{
        fontSize: 12,
        fontWeight: 500,
        color: urgent ? color.dot : "var(--color-text-secondary)",
        minWidth: 42,
        textAlign: "right",
        whiteSpace: "nowrap",
      }}>
        {mins < 0 ? "past" : formatMinutes(mins)}
      </span>
    </div>
  );
}


// ─── Main Component ───────────────────────────────────────────────────────────

export default function EventShieldPanel({ symbol }) {
  const [status,  setStatus]  = useState(null);
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState(null);
  const intervalRef = useRef(null);

  const fetchStatus = async () => {
    if (!symbol) return;
    try {
      const res = await fetch(`/api/v1/macro/status/${symbol.toUpperCase()}`);
      if (!res.ok) throw new Error("Shield status unavailable");
      const data = await res.json();
      setStatus(data);
      setError(null);
    } catch (e) {
      setError("Could not load event shield data.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStatus();
    intervalRef.current = setInterval(fetchStatus, 60_000);   // refresh every 60s
    return () => clearInterval(intervalRef.current);
  }, [symbol]);

  if (loading) return (
    <div style={{ padding: "12px 0", fontSize: 13, color: "var(--color-text-secondary)" }}>
      Loading event shield...
    </div>
  );

  if (error) return (
    <div style={{ padding: "12px 0", fontSize: 13, color: "var(--color-text-secondary)" }}>
      {error}
    </div>
  );

  if (!status) return null;

  const { window_result, upcoming } = status;
  const isBlocked = window_result.is_blocked;

  return (
    <div style={{
      background: "var(--color-background-primary)",
      border: `0.5px solid ${isBlocked ? "#A32D2D" : "var(--color-border-tertiary)"}`,
      borderRadius: 12,
      padding: "14px 16px",
      transition: "border-color 0.3s ease",
    }}>

      {/* Header */}
      <div style={{
        display: "flex", alignItems: "center",
        justifyContent: "space-between",
        marginBottom: 12,
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <CalendarIcon blocked={isBlocked} />
          <span style={{ fontSize: 15, fontWeight: 500 }}>Macro Event Shield</span>
        </div>
        <span style={{
          fontSize: 11, padding: "2px 8px", borderRadius: 99,
          background: isBlocked ? "#fcebeb" : "#eaf3de",
          color: isBlocked ? "#A32D2D" : "#3B6D11",
          fontWeight: 500,
        }}>
          {isBlocked ? "BLOCKED" : "CLEAR"}
        </span>
      </div>

      {/* Active block banner */}
      {isBlocked && <BlockBanner windowResult={window_result} />}

      {/* Upcoming events */}
      {upcoming.length > 0 ? (
        <div>
          <p style={{
            fontSize: 11, color: "var(--color-text-secondary)",
            textTransform: "uppercase", letterSpacing: "0.05em",
            margin: "0 0 4px",
          }}>
            Upcoming for {symbol.toUpperCase()}
          </p>
          {upcoming.map((event, i) => (
            <EventRow key={i} event={event} />
          ))}
        </div>
      ) : (
        <p style={{ fontSize: 13, color: "var(--color-text-secondary)", margin: 0 }}>
          No high-impact events in the next 4 hours.
        </p>
      )}

      {/* Footer refresh note */}
      <p style={{
        fontSize: 11, color: "var(--color-text-secondary)",
        margin: "10px 0 0", textAlign: "right",
      }}>
        Refreshes every 60s · Source: Forex Factory
      </p>
    </div>
  );
}


// ─── Icons ────────────────────────────────────────────────────────────────────

function CalendarIcon({ blocked }) {
  const stroke = blocked ? "#A32D2D" : "var(--color-text-secondary)";
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
      stroke={stroke} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="4" width="18" height="18" rx="2"/>
      <line x1="16" y1="2" x2="16" y2="6"/>
      <line x1="8"  y1="2" x2="8"  y2="6"/>
      <line x1="3"  y1="10" x2="21" y2="10"/>
    </svg>
  );
}

function ShieldBlockIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none"
      stroke="#A32D2D" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"
      style={{ flexShrink: 0, marginTop: 1 }}>
      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
      <line x1="15" y1="9" x2="9" y2="15"/>
      <line x1="9"  y1="9" x2="15" y2="15"/>
    </svg>
  );
}