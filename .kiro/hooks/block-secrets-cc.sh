#!/bin/bash
# Block secrets in git commits — PreToolUse hook (Claude Code version)
# Scans staged files for secrets before git commit/push

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# Only check git commit and git push
if ! echo "$CMD" | grep -qiE '\bgit\s+(commit|push)\b'; then
  exit 0
fi

# Scan staged diff for secrets
STAGED=$(git diff --cached --diff-filter=ACMR 2>/dev/null || git diff HEAD~1 HEAD 2>/dev/null)

if [ -z "$STAGED" ]; then
  exit 0
fi

SECRETS_FOUND=""

# AWS keys
if echo "$STAGED" | grep -qE 'AKIA[0-9A-Z]{16}'; then
  SECRETS_FOUND="${SECRETS_FOUND}\n  - AWS Access Key ID (AKIA...)"
fi

# Private keys
if echo "$STAGED" | grep -qE 'BEGIN (RSA|DSA|EC|OPENSSH|PGP) PRIVATE KEY'; then
  SECRETS_FOUND="${SECRETS_FOUND}\n  - Private key block"
fi

# Generic high-entropy secrets
if echo "$STAGED" | grep -qiE '(sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|gho_[a-zA-Z0-9]{36}|glpat-[a-zA-Z0-9\-]{20,})'; then
  SECRETS_FOUND="${SECRETS_FOUND}\n  - API token (OpenAI/GitHub/GitLab pattern)"
fi

# Hardcoded passwords
if echo "$STAGED" | grep -qiE '(password|passwd|pwd)\s*[:=]\s*["\x27][^${\s][^"\x27]{8,}'; then
  SECRETS_FOUND="${SECRETS_FOUND}\n  - Hardcoded password"
fi

# Connection strings with credentials
if echo "$STAGED" | grep -qiE '(mongodb|postgres|mysql|redis)://[^:]+:[^@]+@'; then
  SECRETS_FOUND="${SECRETS_FOUND}\n  - Database connection string with credentials"
fi

if [ -n "$SECRETS_FOUND" ]; then
  echo "🔐 BLOCKED: Potential secrets detected in staged changes! Found:${SECRETS_FOUND}" >&2
  exit 2
fi

exit 0
