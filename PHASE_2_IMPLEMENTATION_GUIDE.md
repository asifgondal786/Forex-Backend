# Phase 2 Implementation Guide - Explainability & Autonomy Control

**Status:** 🟢 IN DEVELOPMENT  
**Date:** January 24, 2026  
**Focus:** Intelligence + Explainability + User Control  

---

## 📋 Phase 2 Overview

Phase 2 transforms Tajir from a **trusted tool** (Phase 1) into an **intelligent companion** (Phase 2) by adding:

1. **Autonomy Control** - User decides AI independence level
2. **Explainability** - AI explains every decision
3. **Confidence Metrics** - Signals weighted by confidence
4. **Market Intelligence** - Timeline of impactful events
5. **Decision Reasoning** - Why AI took each trade

---

## ✨ New Components Created

### 1. AutonomyLevelsSlider ✅
**File:** `autonomy_levels_slider.dart`

**Purpose:** Let users control AI autonomy on a spectrum

**Spectrum:**
```
Manual ─── Assisted ─── Semi-Auto ─── Full Auto
   ↑           ↑            ↑            ↑
You trade   Approve      Monitor    Fully AI
  only      each one     actively   autonomous
```

**Features:**
- 4-level slider (Manual → Assisted → Semi-Auto → Full Auto)
- Visual indicators for each level
- Descriptions of what each level enables
- Color-coded (Blue → Green → Amber → Red)
- Capability list for current level
- Warning for Full Auto mode

**Props:**
```dart
AutonomyLevelsSlider(
  currentLevel: 'Semi-Auto',           // Current level
  onLevelChanged: (newLevel) => {},    // Callback when changed
  onInfoTapped: () => {},              // Info button tap
)
```

**Use Case:**
```dart
// User changes autonomy level
AutonomyLevelsSlider(
  currentLevel: _autonomyLevel,
  onLevelChanged: (level) {
    setState(() => _autonomyLevel = level);
    apiService.setAIAutonomy(level);   // Save to backend
  },
)
```

---

### 2. ConfidenceWeightedSignals ✅
**File:** `confidence_weighted_signals.dart`

**Purpose:** Show trading signals with confidence scores

**Features:**
- Shows BUY/SELL/HOLD signals
- Confidence percentage (0-100)
- Color-coded confidence (Green 75%+, Amber 50-74%, Red <50%)
- Reason for each signal
- Supporting factors listed
- Risk/Reward ratio
- Expandable for more details

**Components:**
- `TradeSignal` - Data model for each signal
  - pair: 'EUR/USD'
  - type: 'BUY' | 'SELL' | 'HOLD'
  - confidence: 0-100
  - reason: Main reason
  - factors: Supporting factors
  - riskReward: '1:2.5'

**Props:**
```dart
ConfidenceWeightedSignals(
  signals: [
    TradeSignal(
      pair: 'EUR/USD',
      type: 'BUY',
      confidence: 82.0,
      reason: 'RSI divergence detected',
      factors: [
        'RSI below 30',
        'Price above MA200',
        'Positive news sentiment',
      ],
      riskReward: '1:2.5',
    ),
  ],
  onSignalTapped: () => {},
)
```

**Visual:**
```
┌────────────────────────────────┐
│ 📊 Market Signals              │
├────────────────────────────────┤
│ EUR/USD            [BUY]   82% │
│ ████████████░░  Confidence    │
│ RSI divergence detected        │
│ • RSI below 30               │
│ • Price above MA200          │
│ Risk: 1 | Reward: 2.5        │
└────────────────────────────────┘
```

---

### 3. ExplainableAIPanel ✅
**File:** `explainable_ai_panel.dart`

**Purpose:** Answer "Why did AI take this trade?"

**Features:**
- Collapsible panel showing trade reasoning
- Main decision and reason
- Analysis factors (Bullish/Bearish/Neutral)
- Data sources used (RSI, MACD, News, etc.)
- Confidence breakdown by factor
- Expandable for deep dive

**Components:**
- `TradeExplanation` - Full explanation data
  - pair: Currency pair
  - decision: 'BUY' or 'SELL'
  - mainReason: Primary reason
  - factors: List of `TradeExplanationFactor`
  - dataSources: ['RSI', 'MACD', 'News', etc.]
  - confidenceBreakdown: {'RSI': 40%, 'News': 30%, ...}

**Props:**
```dart
ExplainableAIPanel(
  explanation: TradeExplanation(
    pair: 'EUR/USD',
    decision: 'BUY',
    mainReason: 'RSI divergence + Bullish news sentiment',
    factors: [
      TradeExplanationFactor(
        name: 'RSI Divergence',
        description: 'RSI indicator shows divergence...',
        impact: 'Bullish',
      ),
      // More factors...
    ],
    dataSources: ['RSI', 'News Sentiment', 'Volume'],
    confidenceBreakdown: {
      'Technical': 60.0,
      'Sentiment': 30.0,
      'Volume': 10.0,
    },
  ),
  onExpandTapped: () => {},
  isExpanded: false,
)
```

**Visual (Expanded):**
```
┌─────────────────────────────┐
│ 🧠 Why AI Took This Trade  │ [▼]
├─────────────────────────────┤
│ [BUY] AI Decision           │
│ RSI divergence detected...  │
│                             │
│ Analysis Factors            │
│ ├─ RSI Divergence  [Bullish]│
│ ├─ News Sentiment  [Bullish]│
│ └─ Volume Pattern  [Neutral]│
│                             │
│ Data Sources                │
│ [RSI] [News] [Volume]      │
│                             │
│ Confidence Breakdown        │
│ Technical:  ████░░░░░░ 60% │
│ Sentiment:  ███░░░░░░░ 30% │
│ Volume:     ██░░░░░░░░ 10% │
└─────────────────────────────┘
```

---

### 4. MarketEventsTimeline ✅
**File:** `market_events_timeline.dart`

**Purpose:** Show upcoming market events that impact prices

**Features:**
- Horizontal timeline of events
- Impact level (High/Medium/Low)
- Time until event
- Country + currency
- Forecast vs. Previous value
- Affected currency pairs
- Color-coded by impact

**Components:**
- `MarketEvent` - Event data model
  - title: 'CPI Release'
  - country: 'USA'
  - time: DateTime
  - impact: 'High' | 'Medium' | 'Low'
  - forecast: Expected value
  - previous: Previous value
  - affectedPairs: Currencies affected

**Props:**
```dart
MarketEventsTimeline(
  events: [
    MarketEvent(
      title: 'CPI Release',
      country: 'USA',
      time: DateTime.now().add(Duration(hours: 2)),
      impact: 'High',
      forecast: '2.1%',
      previous: '2.0%',
      affectedPairs: ['EUR/USD', 'GBP/USD'],
    ),
    // More events...
  ],
  onEventTapped: () => {},
)
```

**Visual:**
```
┌─────────────────────────────┐
│ 📅 Market Events            │
├─────────────────────────────┤
│ ● CPI Release      [HIGH]   │
│ │  🌍 USA            2h     │
│ │  Forecast: 2.1%           │
│ │  [EUR/USD] [GBP/USD]      │
│ │                           │
│ ● Fed Decision     [MEDIUM] │
│ │  🌍 USA            1d     │
│ │  [USD/JPY]                │
│ │                           │
│ ● ECB Minutes      [LOW]    │
│ │  🌍 EUR            3d     │
│   [EUR/GBP]                 │
└─────────────────────────────┘
```

---

## 🔧 Integration Steps

### Step 1: Add Autonomy Slider to Dashboard
```dart
// In dashboard_screen_enhanced.dart
AutonomyLevelsSlider(
  currentLevel: _autonomyLevel,
  onLevelChanged: (level) {
    setState(() => _autonomyLevel = level);
  },
  onInfoTapped: () {
    // Show autonomy info dialog
  },
)
```

### Step 2: Add Confidence Signals Below AI Banner
```dart
if (_aiEnabled && signals.isNotEmpty)
  ConfidenceWeightedSignals(
    signals: signals,
    onSignalTapped: () {
      // Show signal details
    },
  ),
```

### Step 3: Add Explainability Panel
```dart
if (selectedTrade != null)
  ExplainableAIPanel(
    explanation: selectedTrade.explanation,
    onExpandTapped: () {
      setState(() => _explainablePanelExpanded = !_explainablePanelExpanded);
    },
    isExpanded: _explainablePanelExpanded,
  ),
```

### Step 4: Add Market Events Timeline
```dart
if (upcomingEvents.isNotEmpty)
  MarketEventsTimeline(
    events: upcomingEvents,
    onEventTapped: () {
      // Show event details
    },
  ),
```

---

## 📊 Data Flow

```
Backend API
    ↓
┌─────────────────────────────────┐
│  AI Analysis Engine             │
│  (Generates signals +           │
│   explanations)                 │
└─────────────────────────────────┘
    ↓
┌─────────────────────────────────┐
│  Phase 2 Components             │
│  ├─ Autonomy Slider             │
│  ├─ Confidence Signals          │
│  ├─ Explainable Panel           │
│  └─ Market Timeline             │
└─────────────────────────────────┘
    ↓
User sees intelligent dashboard with full context
```

---

## 🎨 Color Coding

### Autonomy Levels
```
Manual:      🔵 Blue    (#3B82F6)
Assisted:    🟢 Green   (#10B981)
Semi-Auto:   🟡 Amber   (#F59E0B)
Full Auto:   🔴 Red     (#EF4444)
```

### Confidence Scores
```
75-100%:     🟢 Green   (High confidence)
50-74%:      🟡 Amber   (Medium confidence)
0-49%:       🔴 Red     (Low confidence)
```

### Impact Levels (Events)
```
High:        🔴 Red     (#EF4444)
Medium:      🟡 Amber   (#F59E0B)
Low:         🟰 Gray    (#6B7280)
```

### Signals
```
BUY:         🟢 Green   (#10B981)
SELL:        🔴 Red     (#EF4444)
HOLD:        🟰 Gray    (#6B7280)
```

---

## 📋 Backend Integration Requirements

### Phase 2 Endpoints Needed

```
1. GET /api/ai/autonomy/levels
   Response: ["Manual", "Assisted", "Semi-Auto", "Full Auto"]

2. POST /api/ai/autonomy/set
   Request:  {"level": "Semi-Auto"}
   Response: {"status": "success", "level": "Semi-Auto"}

3. GET /api/signals/current
   Response: [
     {
       "pair": "EUR/USD",
       "type": "BUY",
       "confidence": 82.0,
       "reason": "RSI divergence detected",
       "factors": [...]
     }
   ]

4. GET /api/trades/{tradeId}/explanation
   Response: {
     "pair": "EUR/USD",
     "decision": "BUY",
     "mainReason": "...",
     "factors": [...],
     "dataSources": [...],
     "confidenceBreakdown": {...}
   }

5. GET /api/events/market
   Response: [
     {
       "title": "CPI Release",
       "country": "USA",
       "time": "2026-01-24T14:30:00Z",
       "impact": "High",
       "forecast": "2.1%"
     }
   ]
```

### Mock Data (for development)
```dart
// In test_data_helper.dart
final mockSignals = [
  TradeSignal(
    pair: 'EUR/USD',
    type: 'BUY',
    confidence: 82.0,
    reason: 'RSI divergence + Bullish sentiment',
    factors: [
      'RSI below 30',
      'Price above MA200',
      'Positive news sentiment',
    ],
  ),
];

final mockExplanation = TradeExplanation(
  pair: 'EUR/USD',
  decision: 'BUY',
  mainReason: 'RSI divergence detected with bullish sentiment',
  factors: [...],
  dataSources: ['RSI', 'News Sentiment', 'Volume'],
  confidenceBreakdown: {...},
);

final mockEvents = [
  MarketEvent(
    title: 'CPI Release',
    country: 'USA',
    time: DateTime.now().add(Duration(hours: 2)),
    impact: 'High',
  ),
];
```

---

## 🚀 Deployment Checklist

- [ ] All 4 Phase 2 components created
- [ ] Components render without errors
- [ ] Responsive design tested
- [ ] Integration into dashboard complete
- [ ] Mock data working
- [ ] Backend endpoints designed
- [ ] Testing scenarios defined
- [ ] Documentation complete

---

## 📈 User Experience Improvements

### Before Phase 2
```
User sees: "AI made a trade"
User thinks: "But why? I don't understand"
Result: ❌ Low trust in AI decisions
```

### After Phase 2
```
User sees:
  ✅ AI Autonomy Level (I control independence)
  ✅ Signal Confidence (82% - high confidence)
  ✅ Why AI Did It (Reason + factors)
  ✅ What Events Affect It (Market timeline)

User thinks: "This makes sense. I trust this."
Result: ✅ High trust in AI decisions
```

---

## 🎯 Success Metrics (Phase 2)

| Metric | Target | How to Measure |
|--------|--------|---|
| User Sets Autonomy Level | 100% | Track autonomy changes |
| Explores Explanations | 70%+ | Track panel expansions |
| Reviews Market Events | 60%+ | Track event taps |
| Trusts AI Decisions | 80%+ | User survey |
| Engagement Time | +40% | vs Phase 1 |

---

## 🔄 Roadmap

```
Phase 2 (THIS)           🟡 IN PROGRESS
├─ Autonomy Slider       ✅ Done
├─ Confidence Signals    ✅ Done
├─ Explainable Panel     ✅ Done
├─ Market Timeline       ✅ Done
└─ Integration           🟡 In Progress

Phase 3 (NEXT)           🟠 Planned
├─ Sentiment Radar       (will add)
├─ Sleep Mode            (will add)
├─ Market Replay         (will add)
└─ Learning Indicator    (will add)
```

---

## ✅ Phase 2 Components Status

| Component | File | Status | Lines |
|-----------|------|--------|-------|
| AutonomyLevelsSlider | autonomy_levels_slider.dart | ✅ Complete | ~320 |
| ConfidenceWeightedSignals | confidence_weighted_signals.dart | ✅ Complete | ~280 |
| ExplainableAIPanel | explainable_ai_panel.dart | ✅ Complete | ~420 |
| MarketEventsTimeline | market_events_timeline.dart | ✅ Complete | ~300 |

**Total Phase 2 Code:** ~1,320 lines of production-ready Flutter

---

**Phase 2: Explainability & Autonomy Control** 🧠✨  
**Status: COMPONENTS COMPLETE → Ready for Integration**
