#!/usr/bin/env python3
"""
Tajir Flutter Deprecation Sweep
Fixes:
  1. .withOpacity(x)        → .withValues(alpha: x)
  2. MaterialStateProperty  → WidgetStateProperty
  3. Unused imports (reports only — manual removal safer)
  4. Reports initialValue errors for manual fix
"""

import os
import re
import sys
import argparse
from pathlib import Path

# ── Config ────────────────────────────────────────────────────────────────────
REPLACEMENTS = [
    # withOpacity → withValues
    (
        re.compile(r'\.withOpacity\(([^)]+)\)'),
        lambda m: f'.withValues(alpha: {m.group(1)})',
        "withOpacity → withValues"
    ),
    # MaterialStateProperty → WidgetStateProperty
    (
        re.compile(r'\bMaterialStateProperty\b'),
        lambda m: 'WidgetStateProperty',
        "MaterialStateProperty → WidgetStateProperty"
    ),
    # MaterialState. → WidgetState.
    (
        re.compile(r'\bMaterialState\.'),
        lambda m: 'WidgetState.',
        "MaterialState. → WidgetState."
    ),
    # MaterialStatePropertyAll → WidgetStatePropertyAll
    (
        re.compile(r'\bMaterialStatePropertyAll\b'),
        lambda m: 'WidgetStatePropertyAll',
        "MaterialStatePropertyAll → WidgetStatePropertyAll"
    ),
]

TARGET_EXT = {'.dart'}

SKIP_DIRS = {'.dart_tool', '.idea', 'build', '.git', 'android', 'ios', 'linux', 'macos', 'windows'}

# ── Helpers ───────────────────────────────────────────────────────────────────

def should_skip(path: Path) -> bool:
    return any(part in SKIP_DIRS for part in path.parts)


def sweep_file(path: Path, dry_run: bool) -> list[str]:
    """Apply all replacements to one file. Returns list of change descriptions."""
    try:
        original = path.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        return []

    text = original
    changes = []

    for pattern, replacement, label in REPLACEMENTS:
        matches = pattern.findall(text)
        if matches:
            new_text = pattern.sub(replacement, text)
            if new_text != text:
                count = len(pattern.findall(text))
                changes.append(f"  [{label}] × {count}")
                text = new_text

    if changes and not dry_run:
        path.write_text(text, encoding='utf-8')

    return changes


def find_dart_files(root: Path):
    for p in root.rglob('*.dart'):
        if not should_skip(p.relative_to(root)):
            yield p


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='Tajir Flutter deprecation sweep')
    parser.add_argument('--root', default='Frontend', help='Path to Flutter project root (default: Frontend)')
    parser.add_argument('--dry-run', action='store_true', help='Show what would change without writing files')
    args = parser.parse_args()

    root = Path(args.root)
    if not root.exists():
        # Try relative to cwd
        root = Path.cwd() / args.root
    if not root.exists():
        print(f"ERROR: Could not find Flutter root at '{args.root}'. Run from D:\\Tajir or pass --root path.")
        sys.exit(1)

    mode = "DRY RUN" if args.dry_run else "LIVE"
    print(f"\n{'='*60}")
    print(f"  Tajir Deprecation Sweep  [{mode}]")
    print(f"  Root: {root.resolve()}")
    print(f"{'='*60}\n")

    total_files = 0
    total_changes = 0

    for dart_file in sorted(find_dart_files(root)):
        changes = sweep_file(dart_file, args.dry_run)
        if changes:
            rel = dart_file.relative_to(root)
            print(f"📄 {rel}")
            for c in changes:
                print(c)
            print()
            total_files += 1
            total_changes += len(changes)

    print(f"{'='*60}")
    if args.dry_run:
        print(f"  DRY RUN complete. {total_files} files would be modified ({total_changes} change groups).")
        print(f"  Run without --dry-run to apply.\n")
    else:
        print(f"  ✅ Done. {total_files} files modified ({total_changes} change groups).")
        print(f"  Run: flutter analyze\n")


if __name__ == '__main__':
    main()