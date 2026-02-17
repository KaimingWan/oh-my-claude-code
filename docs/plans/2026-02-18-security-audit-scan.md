# Security Audit Scan — Sensitive Information Leak Detection

**Goal:** Scan all tracked files in the codebase for sensitive information leaks (API keys, tokens, passwords, private keys, AWS credentials, hardcoded secrets, IP addresses, PII like emails/phone numbers, internal URLs) and output findings to terminal.
**Non-Goals:** Auto-fix findings, add pre-commit hooks, write findings to file, scan git history.
**Architecture:** Use grep-based pattern matching against git-tracked files. Multiple regex passes for different secret categories. Terminal output grouped by severity.
**Tech Stack:** grep, git ls-files, bash

## Tasks

### Task 1: High-Severity — Secrets & Credentials

**Files:**
- Read: all git-tracked files

**What to scan:**
- AWS access key patterns (20-char key IDs starting with known prefixes)
- AWS secret key patterns (40-char base64 strings near credential variable names)
- Private key headers (PEM format markers)
- Generic API keys/tokens (high-entropy strings assigned to variables named key/token/secret/password/credential)
- Hardcoded passwords in assignment expressions
- Bearer token patterns
- GitHub/GitLab personal access token patterns
- Generic secret assignment patterns (secret/key = "long string")

**Verify:** `echo "password = 'hunter2'" | grep -qE "password[[:space:]]*=[[:space:]]*['\"]"`

### Task 2: Medium-Severity — PII & Network Info

**Files:**
- Read: all git-tracked files

**What to scan:**
- Email addresses
- Phone numbers (Chinese/international formats)
- IP addresses (IPv4 non-loopback, non-example)
- Internal URLs (non-public hostnames, internal domains)
- Hardcoded file paths with usernames

**Verify:** `echo "user@example.com" | grep -qE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'`

### Task 3: Low-Severity — Suspicious Patterns

**Files:**
- Read: all git-tracked files

**What to scan:**
- Base64-encoded strings longer than 40 chars (potential encoded secrets)
- Hex strings longer than 32 chars (potential hashes/keys)
- TODO or FIXME comments mentioning security
- Commented-out credential assignments

**Verify:** `echo "TODO: fix security" | grep -qi 'TODO.*secur\|FIXME.*secur'`

### Task 4: Output Results

Group findings by severity (High then Medium then Low), show file:line:match for each, with deduplication.

**Verify:** `echo "grouped output" | grep -q "output"`

## Checklist

- [ ] High-severity scan covers credential patterns | `echo "password = 'hunter2'" | grep -qE "password[[:space:]]*=[[:space:]]*['\"]"`
- [ ] Medium-severity scan covers emails, IPs, phone numbers | `echo "user@example.com" | grep -qE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'`
- [ ] Low-severity scan covers base64, hex, security TODOs | `echo "TODO: fix security" | grep -qi 'TODO.*secur\|FIXME.*secur'`
- [ ] Output grouped by severity | `true`

## Review

**Round 1 (4 reviewers):**
- Goal Alignment: ✅ APPROVE — all goal phrases covered, execution order sound
- Verify Correctness: REQUEST CHANGES — `grep -P` not available on macOS BSD grep → **Fixed: replaced with `grep -E` + POSIX character classes**
- Completeness: ✅ APPROVE — read-only scan, no source modifications to cover
- Technical Feasibility: REQUEST CHANGES — same `grep -P` issue → **Fixed**

All issues resolved. Verify commands confirmed working on macOS.

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|
