#!/usr/bin/env python3
"""
Tajir — Final fix for remaining issues in embodied_agent_screen.dart
Run from D:\Tajir:
    python scripts/fix_final.py --dry-run
    python scripts/fix_final.py
"""

import sys
import argparse
from pathlib import Path

ROOT = Path("Frontend/lib")

FIXES = {
    "features/embodied_agent/embodied_agent_screen.dart": [

        # ── 2 remaining errors: DropdownMenuItem inside .map() ────────────────
        # Line 626 — AgentAutonomyMode
        (
            "                  (mode) => DropdownMenuItem<AgentAutonomyMode>(\n                    initialValue: mode,",
            "                  (mode) => DropdownMenuItem<AgentAutonomyMode>(\n                    value: mode,",
            "DropdownMenuItem<AgentAutonomyMode> in .map(): initialValue → value"
        ),
        # Line 801 — String entry.key
        (
            "                      (entry) => DropdownMenuItem<String>(\n                        initialValue: entry.key,",
            "                      (entry) => DropdownMenuItem<String>(\n                        value: entry.key,",
            "DropdownMenuItem<String> entry.key in .map(): initialValue → value"
        ),

        # ── 3 deprecated_member_use: DropdownButtonFormField value → initialValue
        # Flutter 3.33+ deprecated value: on DropdownButtonFormField, use initialValue:
        # Line 580 — riskProfile
        (
            "                  key: ValueKey<String>(agent.riskProfile),\n                  value: agent.riskProfile,",
            "                  key: ValueKey<String>(agent.riskProfile),\n                  initialValue: agent.riskProfile,",
            "DropdownButtonFormField riskProfile: value → initialValue (Flutter 3.33+)"
        ),
        # Line 618 — autonomyMode
        (
            "            key: ValueKey<AgentAutonomyMode>(agent.autonomyMode),\n            value: agent.autonomyMode,",
            "            key: ValueKey<AgentAutonomyMode>(agent.autonomyMode),\n            initialValue: agent.autonomyMode,",
            "DropdownButtonFormField autonomyMode: value → initialValue (Flutter 3.33+)"
        ),
        # Line 789 — languageCode
        (
            "                key: ValueKey<String>(agent.languageCode),\n                value: agent.languageCode,",
            "                key: ValueKey<String>(agent.languageCode),\n                initialValue: agent.languageCode,",
            "DropdownButtonFormField languageCode: value → initialValue (Flutter 3.33+)"
        ),
    ],

    # settings_screen.dart — DropdownButtonFormField value → initialValue
    "features/settings/settings_screen.dart": [
        (
            "DropdownButtonFormField<String>(\n                  value: _autonomousProfile,",
            "DropdownButtonFormField<String>(\n                  initialValue: _autonomousProfile,",
            "DropdownButtonFormField autonomousProfile: value → initialValue (Flutter 3.33+)"
        ),
    ],

    # mode_router.dart — the hide clause fix didn't work, try exact string
    "features/dashboard/mode_router.dart": [
        # Try alternate spacing variants
        (
            "hide TradeSignalsScreen",
            "",
            "mode_router: remove hide TradeSignalsScreen (variant 2)"
        ),
    ],

    # quick_actions_overlay.dart — remove unused private constants
    "core/widgets/quick_actions_overlay.dart": [
        # These are warnings but easy to clear
        # We'll comment them out safely rather than delete (safer for constants)
        (
            "\nconst _kBg",
            "\n// const _kBg",
            "Comment out unused _kBg"
        ),
        (
            "\nconst _kBorder",
            "\n// const _kBorder",
            "Comment out unused _kBorder"
        ),
        (
            "\nconst _kText",
            "\n// const _kText",
            "Comment out unused _kText"
        ),
    ],

    # market_watch_screen.dart — remove unused _kSurface
    "features/market_watch/market_watch_screen.dart": [
        (
            "\nconst _kSurface",
            "\n// const _kSurface",
            "Comment out unused _kSurface"
        ),
    ],
}


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
    print(f"  Tajir Final Fix  [{mode}]")
    print(f"  Root: {ROOT.resolve()}")
    print(f"{'='*60}\n")

    if not ROOT.exists():
        print(f"ERROR: {ROOT} not found. Run from D:\\Tajir.")
        sys.exit(1)

    total_changed = 0
    for rel_path, fixes in FIXES.items():
        changed, msgs = apply_fixes(rel_path, fixes, dry_run=args.dry_run)
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
        print(f"  Done. {total_changed} files modified.")
        print(f"  Next: flutter analyze\n")


if __name__ == "__main__":
    main()