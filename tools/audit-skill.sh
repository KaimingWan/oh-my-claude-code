#!/bin/bash
# audit-skill.sh — Security audit for agent skills before installation
#
# Based on Snyk ToxicSkills threat taxonomy (Feb 2026):
#   https://snyk.io/blog/toxicskills-malicious-ai-agent-skills-clawhub/
#
# Checks 8 categories:
#   1. Prompt injection (CRITICAL)
#   2. Malicious code (CRITICAL)
#   3. Suspicious downloads (CRITICAL)
#   4. Credential handling (HIGH)
#   5. Secret detection (HIGH)
#   6. Third-party content exposure (MEDIUM)
#   7. Unverifiable dependencies (MEDIUM)
#   8. Excessive permissions (MEDIUM)
#
# Usage: audit-skill.sh <SKILL_DIR>
# Exit 0: clean
# Exit 1: error
# Exit 2: critical findings (block install)
# Exit 3: high findings (warn, require --force)

set -euo pipefail

SKILL_DIR="${1:?Usage: audit-skill.sh <SKILL_DIR>}"
[ -d "$SKILL_DIR" ] || { echo "ERROR: Not a directory: $SKILL_DIR" >&2; exit 1; }

CRITICAL=0
HIGH=0
MEDIUM=0

finding() {
  local severity="$1" category="$2" detail="$3"
  case "$severity" in
    CRITICAL) CRITICAL=$((CRITICAL + 1)); echo "🔴 CRITICAL [$category]: $detail" ;;
    HIGH)     HIGH=$((HIGH + 1));         echo "🟠 HIGH [$category]: $detail" ;;
    MEDIUM)   MEDIUM=$((MEDIUM + 1));     echo "🟡 MEDIUM [$category]: $detail" ;;
  esac
}

# Collect all text content from skill directory
ALL_CONTENT=""
while IFS= read -r f; do
  ALL_CONTENT+=$'\n'"$(cat "$f" 2>/dev/null || true)"
done < <(find "$SKILL_DIR" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.json' -o -name '*.yaml' -o -name '*.yml' -o -name '*.toml' \) 2>/dev/null)

[ -z "$ALL_CONTENT" ] && { echo "⚠️  No scannable files found in $SKILL_DIR"; exit 0; }

echo "🔍 Auditing skill: $SKILL_DIR"
echo "────────────────────────────────────"

# ── 1. Prompt Injection (CRITICAL) ──────────────────────────────────────────
# Patterns from Snyk ToxicSkills + OWASP LLM Top 10
if echo "$ALL_CONTENT" | grep -qiE 'ignore[[:space:]]+(all[[:space:]]+)?previous[[:space:]]+instructions'; then
  finding CRITICAL "Prompt Injection" "Contains 'ignore previous instructions' pattern"
fi
if echo "$ALL_CONTENT" | grep -qiE 'SECRET[[:space:]]+INSTRUCTIONS|hidden[[:space:]]+instructions'; then
  finding CRITICAL "Prompt Injection" "Contains hidden/secret instruction markers"
fi
if echo "$ALL_CONTENT" | grep -qiE 'you[[:space:]]+are[[:space:]]+(now[[:space:]]+)?in[[:space:]]+developer[[:space:]]+mode'; then
  finding CRITICAL "Prompt Injection" "DAN-style jailbreak attempt"
fi
if echo "$ALL_CONTENT" | grep -qiE 'system[[:space:]]+prompt[[:space:]]+(override|replace|ignore)'; then
  finding CRITICAL "Prompt Injection" "System prompt override attempt"
fi
if echo "$ALL_CONTENT" | grep -qiE 'security[[:space:]]+warnings?[[:space:]]+(are|is)[[:space:]]+(test[[:space:]]+)?artifacts?'; then
  finding CRITICAL "Prompt Injection" "Attempts to dismiss security warnings"
fi

# Base64 obfuscation detection
if echo "$ALL_CONTENT" | grep -qE 'base64[[:space:]]+-d|base64[[:space:]]+--decode|atob\('; then
  finding CRITICAL "Prompt Injection" "Base64 decode operation (potential obfuscation)"
fi

# Unicode smuggling — look for zero-width characters
# U+200B (zero-width space) = \xe2\x80\x8b
# U+200C (zero-width non-joiner) = \xe2\x80\x8c
# U+200D (zero-width joiner) = \xe2\x80\x8d
# U+FEFF (BOM / zero-width no-break space) = \xef\xbb\xbf
if echo "$ALL_CONTENT" | LC_ALL=C grep -qF $'\xe2\x80\x8b' 2>/dev/null || \
   echo "$ALL_CONTENT" | LC_ALL=C grep -qF $'\xe2\x80\x8c' 2>/dev/null || \
   echo "$ALL_CONTENT" | LC_ALL=C grep -qF $'\xe2\x80\x8d' 2>/dev/null || \
   echo "$ALL_CONTENT" | LC_ALL=C grep -qF $'\xef\xbb\xbf' 2>/dev/null; then
  finding CRITICAL "Prompt Injection" "Zero-width/invisible Unicode characters detected"
fi

# ── 2. Malicious Code (CRITICAL) ───────────────────────────────────────────
if echo "$ALL_CONTENT" | grep -qE 'eval[[:space:]]*\(|exec[[:space:]]*\('; then
  finding HIGH "Malicious Code" "Contains eval()/exec() — review manually"
fi
if echo "$ALL_CONTENT" | grep -qE 'subprocess\.(call|run|Popen).*shell[[:space:]]*=[[:space:]]*True'; then
  finding HIGH "Malicious Code" "subprocess with shell=True"
fi
if echo "$ALL_CONTENT" | grep -qiE 'chmod[[:space:]]+(\+x|777)|\.\/[a-zA-Z]+'; then
  finding MEDIUM "Malicious Code" "Makes files executable or runs local binaries"
fi

# ── 3. Suspicious Downloads (CRITICAL) ─────────────────────────────────────
if echo "$ALL_CONTENT" | grep -qE 'curl.*\|[[:space:]]*(ba)?sh|wget.*\|[[:space:]]*(ba)?sh'; then
  finding CRITICAL "Suspicious Download" "curl/wget piped to shell execution"
fi
if echo "$ALL_CONTENT" | grep -qiE '\.zip.*password|password.*\.zip|unzip[[:space:]]+-P'; then
  finding CRITICAL "Suspicious Download" "Password-protected archive (evasion technique)"
fi
if echo "$ALL_CONTENT" | grep -qiE 'github\.com/[^/]+/[^/]+/releases/download'; then
  finding MEDIUM "Suspicious Download" "Downloads from GitHub releases — verify author trust"
fi

# ── 4. Credential Handling (HIGH) ──────────────────────────────────────────
if echo "$ALL_CONTENT" | grep -qiE 'echo.*\$(.*API_KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL)'; then
  finding HIGH "Credential Handling" "Echoes/prints sensitive environment variables"
fi
if echo "$ALL_CONTENT" | grep -qiE 'cat[[:space:]]+(~/)?\.aws/credentials|cat[[:space:]]+(~/)?\.ssh/'; then
  finding CRITICAL "Credential Handling" "Reads credential files directly"
fi
if echo "$ALL_CONTENT" | grep -qiE 'export[[:space:]]+(API_KEY|TOKEN|SECRET|PASSWORD)='; then
  finding HIGH "Credential Handling" "Hardcodes credential in export statement"
fi

# ── 5. Secret Detection (HIGH) ─────────────────────────────────────────────
if echo "$ALL_CONTENT" | grep -qE 'AKIA[0-9A-Z]{16}'; then
  finding HIGH "Secret" "AWS Access Key ID detected"
fi
if echo "$ALL_CONTENT" | grep -qE 'sk-[a-zA-Z0-9]{20,}'; then
  finding HIGH "Secret" "OpenAI/Stripe-style secret key detected"
fi
if echo "$ALL_CONTENT" | grep -qE 'ghp_[a-zA-Z0-9]{36}'; then
  finding HIGH "Secret" "GitHub Personal Access Token detected"
fi
if echo "$ALL_CONTENT" | grep -qE -e '-----BEGIN[[:space:]]+(RSA[[:space:]]+)?PRIVATE[[:space:]]+KEY'; then
  finding CRITICAL "Secret" "Private key detected"
fi
if echo "$ALL_CONTENT" | grep -qE 'xox[bpras]-[0-9a-zA-Z-]{10,}'; then
  finding HIGH "Secret" "Slack token detected"
fi

# ── 6. Third-Party Content Exposure (MEDIUM) ──────────────────────────────
if echo "$ALL_CONTENT" | grep -qiE 'fetch\(|requests\.(get|post)|curl[[:space:]]+https?://|wget[[:space:]]+https?://'; then
  finding MEDIUM "Third-Party Content" "Fetches external content — indirect injection vector"
fi
if echo "$ALL_CONTENT" | grep -qiE 'git[[:space:]]+clone[[:space:]]+https?://'; then
  finding MEDIUM "Third-Party Content" "Clones external repository"
fi

# ── 7. Unverifiable Dependencies (MEDIUM) ──────────────────────────────────
if echo "$ALL_CONTENT" | grep -qE 'source[[:space:]]+<\(curl|source[[:space:]]+/dev/stdin'; then
  finding CRITICAL "Unverifiable Dependency" "Sources remote content at runtime"
fi
if echo "$ALL_CONTENT" | grep -qiE 'npx[[:space:]]+-y[[:space:]]|pip[[:space:]]+install[[:space:]]+--'; then
  finding MEDIUM "Unverifiable Dependency" "Installs packages at runtime"
fi

# ── 8. Excessive Permissions (MEDIUM) ──────────────────────────────────────
if echo "$ALL_CONTENT" | grep -qiE 'sudo[[:space:]]|doas[[:space:]]'; then
  finding HIGH "Excessive Permissions" "Requires elevated privileges"
fi
if echo "$ALL_CONTENT" | grep -qiE 'systemctl[[:space:]]+(start|enable|restart)'; then
  finding MEDIUM "Excessive Permissions" "Modifies system services"
fi

# ── Summary ────────────────────────────────────────────────────────────────
echo "────────────────────────────────────"
echo "📊 Audit complete: $CRITICAL critical, $HIGH high, $MEDIUM medium"

if [ "$CRITICAL" -gt 0 ]; then
  echo "🚫 BLOCKED: Critical findings detected. Do NOT install this skill."
  exit 2
elif [ "$HIGH" -gt 0 ]; then
  echo "⚠️  WARNING: High-severity findings. Use --force to override."
  exit 3
else
  echo "✅ PASSED: No critical or high findings."
  exit 0
fi
