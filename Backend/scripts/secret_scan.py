#!/usr/bin/env python3
"""Lightweight secret scanner for staged changes or commit ranges."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass


@dataclass(frozen=True)
class Rule:
    name: str
    pattern: re.Pattern[str]


RULES: list[Rule] = [
    Rule("Supabase Secret Key", re.compile(r"sb_" r"secret_[A-Za-z0-9_-]{8,}")),
    Rule("GitHub Personal Access Token", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}\b")),
    Rule("OpenAI API Key", re.compile(r"\bsk-[A-Za-z0-9]{20,}\b")),
    Rule("AWS Access Key ID", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    Rule("Firebase API Key", re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b")),
    Rule(
        "Private Key Block",
        re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    ),
    Rule(
        "Hardcoded Secret Assignment",
        re.compile(
            r"(?i)\b(?:api[_-]?key|secret|token|password|passphrase)\b\s*[:=]\s*['\"][^'\"]{16,}['\"]"
        ),
    ),
]


@dataclass(frozen=True)
class Finding:
    rule_name: str
    path: str
    line_no: int
    commit: str | None = None


def run_git(args: list[str]) -> str:
    result = subprocess.run(["git", *args], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"git {' '.join(args)} failed")
    return result.stdout


def scan_text(path: str, text: str, commit: str | None = None) -> list[Finding]:
    findings: list[Finding] = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        for rule in RULES:
            if rule.pattern.search(line):
                findings.append(Finding(rule.name, path, line_no, commit))
    return findings


def staged_files() -> list[str]:
    out = run_git(["diff", "--cached", "--name-only", "--diff-filter=ACMR"])
    return [line.strip() for line in out.splitlines() if line.strip()]


def staged_blob(path: str) -> str | None:
    result = subprocess.run(["git", "show", f":{path}"], capture_output=True)
    if result.returncode != 0:
        return None
    return result.stdout.decode("utf-8", errors="replace")


def scan_staged() -> list[Finding]:
    findings: list[Finding] = []
    for path in staged_files():
        blob = staged_blob(path)
        if blob is None:
            continue
        findings.extend(scan_text(path, blob))
    return findings


def commit_list(commit_range: str) -> list[str]:
    out = run_git(["rev-list", "--reverse", commit_range])
    return [line.strip() for line in out.splitlines() if line.strip()]


def commit_files(commit: str) -> list[str]:
    out = run_git(["diff-tree", "--no-commit-id", "--name-only", "-r", "--diff-filter=AM", commit])
    return [line.strip() for line in out.splitlines() if line.strip()]


def commit_blob(commit: str, path: str) -> str | None:
    result = subprocess.run(["git", "show", f"{commit}:{path}"], capture_output=True)
    if result.returncode != 0:
        return None
    return result.stdout.decode("utf-8", errors="replace")


def scan_range(commit_range: str) -> list[Finding]:
    findings: list[Finding] = []
    for commit in commit_list(commit_range):
        for path in commit_files(commit):
            blob = commit_blob(commit, path)
            if blob is None:
                continue
            findings.extend(scan_text(path, blob, commit=commit))
    return findings


def dedupe(findings: list[Finding]) -> list[Finding]:
    seen: set[tuple[str, str, int, str | None]] = set()
    unique: list[Finding] = []
    for f in findings:
        key = (f.rule_name, f.path, f.line_no, f.commit)
        if key in seen:
            continue
        seen.add(key)
        unique.append(f)
    return unique


def print_findings(findings: list[Finding]) -> None:
    print("[secret-scan] Potential secrets detected. Commit/push blocked.")
    for f in findings:
        if f.commit:
            print(f"  - {f.rule_name}: {f.path}:{f.line_no} (commit {f.commit[:12]})")
        else:
            print(f"  - {f.rule_name}: {f.path}:{f.line_no}")
    print(
        "[secret-scan] Move secrets to environment variables or secret manager, "
        "then amend/rewrite the offending commit."
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Scan git content for common secret patterns.")
    parser.add_argument(
        "--range",
        dest="commit_range",
        help="Commit range to scan (example: origin/main..HEAD). If omitted, scans staged content.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        findings = scan_range(args.commit_range) if args.commit_range else scan_staged()
    except RuntimeError as err:
        print(f"[secret-scan] {err}", file=sys.stderr)
        return 2

    findings = dedupe(findings)
    if findings:
        print_findings(findings)
        return 1

    print("[secret-scan] OK: no known secret patterns found.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
