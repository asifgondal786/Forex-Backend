# Security Lessons Learned

Use this file to capture recurring patterns and prevention outcomes.

## Template

### Incident or Finding

- Date:
- Summary:
- Impact:
- Root cause:
- Detection method:
- Resolution:
- Preventive control added:
- Owner:
- Follow-up date:

---

## Initial Entry

- Date: 2026-03-03
- Summary: Historical key exposure required history rewrite.
- Impact: Temporary push protection failures and branch resync required.
- Root cause: Hardcoded API key in test utility + tracked env history.
- Detection method: GitHub push protection and git-history scan.
- Resolution: History rewritten, key removed, scanning and hooks added.
- Preventive control added: CI secret scan + pre-commit hook + audit process.
- Owner: Team lead
- Follow-up date: Next monthly audit
