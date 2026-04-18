#!/usr/bin/env python3
"""
Tajir — Fix all initialValue / missing-value errors + unused imports/elements
Run from D:\Tajir:
    python scripts/fix_initialvalue.py --dry-run
    python scripts/fix_initialvalue.py
"""

import re
import sys
import argparse
from pathlib import Path

ROOT = Path("Frontend/lib")

# ── Fix definitions ───────────────────────────────────────────────────────────
# Each entry: (relative_path, list_of_(old_string, new_string, description))

FIXES = {

    # ── embodied_agent_screen.dart ────────────────────────────────────────────
    "features/embodied_agent/embodied_agent_screen.dart": [

        # DropdownButtonFormField<String> for riskProfile — initialValue → value
        (
            "DropdownButtonFormField<String>(\n                  key: ValueKey<String>(agent.riskProfile),\n                  initialValue: agent.riskProfile,",
            "DropdownButtonFormField<String>(\n                  key: ValueKey<String>(agent.riskProfile),\n                  value: agent.riskProfile,",
            "DropdownButtonFormField riskProfile: initialValue → value"
        ),

        # DropdownMenuItem 'beginner'
        (
            "DropdownMenuItem<String>(\n                      initialValue: 'beginner',",
            "DropdownMenuItem<String>(\n                      value: 'beginner',",
            "DropdownMenuItem beginner: initialValue → value"
        ),
        # DropdownMenuItem 'intermediate'
        (
            "DropdownMenuItem<String>(\n                      initialValue: 'intermediate',",
            "DropdownMenuItem<String>(\n                      value: 'intermediate',",
            "DropdownMenuItem intermediate: initialValue → value"
        ),
        # DropdownMenuItem 'pro'
        (
            "DropdownMenuItem<String>(\n                      initialValue: 'pro',",
            "DropdownMenuItem<String>(\n                      value: 'pro',",
            "DropdownMenuItem pro: initialValue → value"
        ),
        # DropdownMenuItem 'custom'
        (
            "DropdownMenuItem<String>(\n                      initialValue: 'custom',",
            "DropdownMenuItem<String>(\n                      value: 'custom',",
            "DropdownMenuItem custom: initialValue → value"
        ),

        # DropdownButtonFormField<AgentAutonomyMode> — initialValue → value
        (
            "DropdownButtonFormField<AgentAutonomyMode>(\n            key: ValueKey<AgentAutonomyMode>(agent.autonomyMode),\n            initialValue: agent.autonomyMode,",
            "DropdownButtonFormField<AgentAutonomyMode>(\n            key: ValueKey<AgentAutonomyMode>(agent.autonomyMode),\n            value: agent.autonomyMode,",
            "DropdownButtonFormField autonomyMode: initialValue → value"
        ),

        # DropdownMenuItem(initialValue: mode, — inside .map()
        (
            "=> DropdownMenuItem<AgentAutonomyMode>(\n                  initialValue: mode,",
            "=> DropdownMenuItem<AgentAutonomyMode>(\n                  value: mode,",
            "DropdownMenuItem mode: initialValue → value"
        ),

        # _buildSliderRow risk per trade
        (
            "_buildSliderRow(\n            label: 'Risk per trade',\n            initialValue: agent.draftRiskPerTradePercent,",
            "_buildSliderRow(\n            label: 'Risk per trade',\n            value: agent.draftRiskPerTradePercent,",
            "_buildSliderRow riskPerTrade: initialValue → value"
        ),
        # _buildSliderRow daily loss cap
        (
            "_buildSliderRow(\n            label: 'Daily loss cap',\n            initialValue: agent.draftDailyLossPercent,",
            "_buildSliderRow(\n            label: 'Daily loss cap',\n            value: agent.draftDailyLossPercent,",
            "_buildSliderRow dailyLoss: initialValue → value"
        ),

        # DropdownButtonFormField<String> for languageCode
        (
            "final dropdown = DropdownButtonFormField<String>(\n                key: ValueKey<String>(agent.languageCode),\n                initialValue: agent.languageCode,",
            "final dropdown = DropdownButtonFormField<String>(\n                key: ValueKey<String>(agent.languageCode),\n                value: agent.languageCode,",
            "DropdownButtonFormField languageCode: initialValue → value"
        ),

        # DropdownMenuItem(initialValue: entry.key,
        (
            "(entry) => DropdownMenuItem<String>(\n                      initialValue: entry.key,",
            "(entry) => DropdownMenuItem<String>(\n                      value: entry.key,",
            "DropdownMenuItem entry.key: initialValue → value"
        ),

        # _SafetyRow calls — initialValue → value (6 occurrences)
        # max risk per trade
        (
            "_SafetyRow(\n            label: 'Max risk per trade',\n            initialValue: '${g.maxRiskPerTradePercent.toStringAsFixed(2)}%',",
            "_SafetyRow(\n            label: 'Max risk per trade',\n            value: '${g.maxRiskPerTradePercent.toStringAsFixed(2)}%',",
            "_SafetyRow maxRiskPerTrade: initialValue → value"
        ),
        # daily loss limit
        (
            "_SafetyRow(\n            label: 'Daily loss limit',\n            initialValue: '${g.dailyLossLimitPercent.toStringAsFixed(2)}%',",
            "_SafetyRow(\n            label: 'Daily loss limit',\n            value: '${g.dailyLossLimitPercent.toStringAsFixed(2)}%',",
            "_SafetyRow dailyLossLimit: initialValue → value"
        ),
        # weekly loss limit
        (
            "_SafetyRow(\n            label: 'Weekly loss limit',\n            initialValue: '${g.weeklyLossLimitPercent.toStringAsFixed(2)}%',",
            "_SafetyRow(\n            label: 'Weekly loss limit',\n            value: '${g.weeklyLossLimitPercent.toStringAsFixed(2)}%',",
            "_SafetyRow weeklyLossLimit: initialValue → value"
        ),
        # hard max drawdown
        (
            "_SafetyRow(\n            label: 'Hard max drawdown',\n            initialValue: '${g.hardMaxDrawdownPercent.toStringAsFixed(2)}%',",
            "_SafetyRow(\n            label: 'Hard max drawdown',\n            value: '${g.hardMaxDrawdownPercent.toStringAsFixed(2)}%',",
            "_SafetyRow hardMaxDrawdown: initialValue → value"
        ),
        # profile
        (
            "_SafetyRow(\n            label: 'Profile',\n            initialValue: g.profile.isEmpty ? 'custom' : g.profile,",
            "_SafetyRow(\n            label: 'Profile',\n            value: g.profile.isEmpty ? 'custom' : g.profile,",
            "_SafetyRow profile: initialValue → value"
        ),
        # risk guardian status
        (
            "_SafetyRow(\n            label: 'Risk Guardian',\n            initialValue: g.riskGuardianStatus,",
            "_SafetyRow(\n            label: 'Risk Guardian',\n            value: g.riskGuardianStatus,",
            "_SafetyRow riskGuardianStatus: initialValue → value"
        ),

        # Slider — initialValue → value
        (
            "Slider(\n            initialValue: value.clamp(min, max).toDouble(),",
            "Slider(\n            value: value.clamp(min, max).toDouble(),",
            "Slider: initialValue → value"
        ),
    ],

    # ── settings_screen.dart ──────────────────────────────────────────────────
    "features/settings/settings_screen.dart": [

        # Switch — initialValue → value
        (
            "Switch(\n                      initialValue: _autonomousModeEnabled,",
            "Switch(\n                      value: _autonomousModeEnabled,",
            "Switch autonomousModeEnabled: initialValue → value"
        ),

        # DropdownButtonFormField<String> autonomousProfile
        (
            "DropdownButtonFormField<String>(\n                  initialValue: _autonomousProfile,",
            "DropdownButtonFormField<String>(\n                  value: _autonomousProfile,",
            "DropdownButtonFormField autonomousProfile: initialValue → value"
        ),

        # DropdownMenuItem 'conservative'
        (
            "DropdownMenuItem(\n                      initialValue: 'conservative',",
            "DropdownMenuItem(\n                      value: 'conservative',",
            "DropdownMenuItem conservative: initialValue → value"
        ),
        # DropdownMenuItem 'balanced'
        (
            "DropdownMenuItem(\n                      initialValue: 'balanced',",
            "DropdownMenuItem(\n                      value: 'balanced',",
            "DropdownMenuItem balanced: initialValue → value"
        ),
        # DropdownMenuItem 'aggressive'
        (
            "DropdownMenuItem(\n                      initialValue: 'aggressive',",
            "DropdownMenuItem(\n                      value: 'aggressive',",
            "DropdownMenuItem aggressive: initialValue → value"
        ),

        # Slider — initialValue → value
        (
            "Slider(\n                  initialValue: _autonomousMinConfidence,",
            "Slider(\n                  value: _autonomousMinConfidence,",
            "Slider autonomousMinConfidence: initialValue → value"
        ),

        # Switch selected (line 1076-1077)
        (
            "Switch(\n            initialValue: selected,",
            "Switch(\n            value: selected,",
            "Switch selected: initialValue → value"
        ),

        # Remove unused import: mode_provider.dart
        (
            "import '../../providers/mode_provider.dart';\n",
            "",
            "Remove unused import: mode_provider.dart"
        ),
    ],

    # ── task_history_screen.dart ──────────────────────────────────────────────
    "features/task_history/task_history_screen.dart": [

        # LinearProgressIndicator — initialValue → value
        (
            "LinearProgressIndicator(\n                initialValue: task.progress,",
            "LinearProgressIndicator(\n                value: task.progress,",
            "LinearProgressIndicator: initialValue → value"
        ),
    ],

    # ── mode_switcher_widget.dart ─────────────────────────────────────────────
    "shared/widgets/mode_switcher_widget.dart": [

        # DropdownButton<AppMode> — initialValue → value
        (
            "DropdownButton<AppMode>(\n              initialValue: current,",
            "DropdownButton<AppMode>(\n              value: current,",
            "DropdownButton AppMode: initialValue → value"
        ),

        # DropdownMenuItem<AppMode> — initialValue → value
        (
            "DropdownMenuItem<AppMode>(\n                  initialValue: mode,",
            "DropdownMenuItem<AppMode>(\n                  value: mode,",
            "DropdownMenuItem mode: initialValue → value"
        ),
    ],

    # ── mode_router.dart ──────────────────────────────────────────────────────
    "features/dashboard/mode_router.dart": [
        # Remove 'hide TradeSignalsScreen' from news import
        (
            " hide TradeSignalsScreen",
            "",
            "mode_router: remove invalid hide clause for TradeSignalsScreen"
        ),
    ],

    # ── Unused imports ────────────────────────────────────────────────────────
    "features/ai_chat/ai_chat_screen.dart": [
        (
            "import '../../providers/mode_provider.dart';\n",
            "",
            "Remove unused import: mode_provider.dart"
        ),
    ],
    "features/market_watch/market_watch_screen.dart": [
        (
            "import '../../providers/quick_actions_provider.dart';\n",
            "",
            "Remove unused import: quick_actions_provider.dart"
        ),
    ],
    "features/news/news_events_screen.dart": [
        (
            "import '../../providers/quick_actions_provider.dart';\n",
            "",
            "Remove unused import: quick_actions_provider.dart"
        ),
    ],
    "features/settings/custom_setup_screen.dart": [
        (
            "import '../../core/widgets/quick_actions_overlay.dart';\n",
            "",
            "Remove unused import: quick_actions_overlay.dart"
        ),
        (
            "import '../../providers/quick_actions_provider.dart';\n",
            "",
            "Remove unused import: quick_actions_provider.dart"
        ),
    ],
    "features/trade_signals/trade_signals_screen.dart": [
        (
            "import '../../providers/quick_actions_provider.dart';\n",
            "",
            "Remove unused import: quick_actions_provider.dart"
        ),
    ],
}


# ── Engine ────────────────────────────────────────────────────────────────────

def apply_fixes(rel_path: str, fixes: list, dry_run: bool) -> tuple[int, list[str]]:
    path = ROOT / rel_path
    if not path.exists():
        return 0, [f"  ⚠️  FILE NOT FOUND: {path}"]

    original = path.read_text(encoding="utf-8")
    text = original
    applied = []
    skipped = []

    for old, new, desc in fixes:
        if old in text:
            text = text.replace(old, new, 1)
            applied.append(f"  ✅ {desc}")
        else:
            skipped.append(f"  ⏭️  SKIP (not found): {desc}")

    changed = text != original

    if changed and not dry_run:
        path.write_text(text, encoding="utf-8")

    return (1 if changed else 0), applied + skipped


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    mode = "DRY RUN" if args.dry_run else "LIVE"
    print(f"\n{'='*60}")
    print(f"  Tajir Fix — initialValue errors + unused imports  [{mode}]")
    print(f"  Root: {ROOT.resolve()}")
    print(f"{'='*60}\n")

    if not ROOT.exists():
        print(f"ERROR: {ROOT} not found. Run from D:\\Tajir.")
        sys.exit(1)

    total_changed = 0
    for rel_path, fixes in FIXES.items():
        changed, msgs = apply_fixes(rel_path, fixes, args.dry_run)
        total_changed += changed
        print(f"📄 {rel_path}")
        for m in msgs:
            print(m)
        print()

    print(f"{'='*60}")
    if args.dry_run:
        print(f"  DRY RUN: {total_changed} files would be modified.")
        print(f"  Run without --dry-run to apply.\n")
    else:
        print(f"  ✅ Done. {total_changed} files modified.")
        print(f"  Next: flutter analyze\n")


if __name__ == "__main__":
    main()