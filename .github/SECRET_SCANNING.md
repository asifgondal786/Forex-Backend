# Secret Scanning Configuration

## Overview
Your repository uses a lightweight secret scanner to prevent accidental commits of sensitive data (API keys, tokens, private keys, etc.).

## Components

### 1. Scanner Script (`scripts/secret_scan.py`)
- **Purpose**: Detects common secret patterns in git changes
- **Detection Rules**:
  - Supabase Secret Keys (`sb_secret_*`)
  - GitHub Personal Access Tokens (`ghp_*`, `ghs_*`, etc.)
  - OpenAI API Keys (`sk-*`)
  - AWS Access Keys (`AKIA*`)
  - Firebase API Keys (`AIza*`)
  - Private Key Blocks (RSA, EC, OpenSSH)
  - Hardcoded secret assignments (`api_key = "..."`, etc.)

### 2. Git Hooks
Automatic scanning at two points:

#### Pre-commit Hook (`.git/hooks/pre-commit`)
- Runs on `git commit`
- Scans **staged changes** before they're committed
- **Blocks commit** if secrets are detected
- ✅ Prevents local commits of secrets

#### Pre-push Hook (`.git/hooks/pre-push`)
- Runs on `git push`
- Scans **commits being pushed** (not on remote yet)
- **Blocks push** if secrets are detected
- ✅ Prevents pushing secret commits to remote

## Usage

### Normal Workflow
```bash
# Edit files
# Stage changes
git add .

# Commit (pre-commit hook runs automatically)
git commit -m "Your message"

# Push (pre-push hook runs automatically)
git push
```

### If Secrets Are Detected

**On commit:**
```
[secret-scan] Potential secrets detected. Commit/push blocked.
  - GitHub Personal Access Token: config.env:15
[secret-scan] Move secrets to environment variables or secret manager, then amend/rewrite the offending commit.
```

**Solution:**
1. Remove the secret from the file
2. Move it to environment variables or `.env.local` (add to `.gitignore`)
3. Stage the fix: `git add .`
4. Amend the commit: `git commit --amend --no-edit`
5. Try pushing again

### Manual Scanning

Scan staged changes:
```bash
python scripts/secret_scan.py
```

Scan a range of commits:
```bash
python scripts/secret_scan.py --range origin/main..HEAD
```

## Setup Instructions (One-time)

The hooks should be executable. If they're not working, ensure they have execute permissions:

**On Windows (Git Bash):**
```bash
chmod +x .git/hooks/pre-commit
chmod +x .git/hooks/pre-push
```

**On macOS/Linux:**
```bash
chmod +x .git/hooks/pre-commit
chmod +x .git/hooks/pre-push
```

## Extending the Scanner

To add new secret patterns, edit `scripts/secret_scan.py`:

```python
RULES: list[Rule] = [
    # ... existing rules ...
    Rule("Custom API Key", re.compile(r"\bcustom_[A-Za-z0-9]{32,}\b")),
]
```

## Bypassing (Not Recommended)

If you absolutely need to bypass the scanner:

```bash
# Bypass pre-commit hook
git commit --no-verify -m "Your message"

# Bypass pre-push hook
git push --no-verify
```

⚠️ **Use only for legitimate cases** (e.g., test fixtures with fake credentials). Consider safer alternatives first.

## Best Practices

✅ **Do:**
- Use environment variables for sensitive data
- Use `.env.local` or `.env` files (add to `.gitignore`)
- Use secret managers (Supabase, Firebase, AWS Secrets Manager)
- Keep `secrets` in separate configuration files outside version control
- Rotate compromised tokens immediately

❌ **Don't:**
- Commit API keys, tokens, or private keys
- Hardcode passwords or secrets
- Add secrets to `.env` files tracked by git
- Store plaintext credentials in config files

## Troubleshooting

**Hooks not running?**
- Ensure `.git/hooks/` directory exists
- Check file permissions: `ls -la .git/hooks/`
- Verify script paths are correct

**False positives?**
- Review the detected line in your file
- If it's a legitimate non-secret string, add specific exclusions to the scanner

**Need to scan past commits?**
```bash
python scripts/secret_scan.py --range main..HEAD
```

## Related Files
- `.gitignore` - Ensure sensitive files are excluded
- `requirements.txt` - Python dependencies (if any)
- Postman/environment files - Never commit auth credentials
