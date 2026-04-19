# Git History Rewrite Notice

Date: March 3, 2026  
Reason: Removal of exposed credentials from repository history.

## What Changed

- Git history for `main` was rewritten to remove leaked key material.
- Legacy `.env` history was removed.
- Remote `origin/main` was force-updated with lease protection.
- No intended runtime feature regressions were introduced by the rewrite itself.

## Required Team Action

1. Save local work:
```bash
git stash
```
2. Sync to rewritten history:
```bash
git fetch origin main
git reset --hard origin/main
```
3. Reapply local changes if needed:
```bash
git stash pop
```
4. Clean old references:
```bash
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

## Verification Command

```bash
git log --all -p -S "AIzaSy"
git log --all -p -S "xkeysib"
```

Both commands should return no hits for leaked historical credentials on updated clones.
