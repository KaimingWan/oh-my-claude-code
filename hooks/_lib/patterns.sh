#!/bin/bash
# patterns.sh — Shared regex patterns for security hooks

DANGEROUS_BASH_PATTERNS=(
  '\brm[[:space:]]+(-[rRf]|--recursive|--force)'
  '\brmdir\b'
  '\bmkfs\b'
  '\bshred\b'
  '\bdd[[:space:]]+.*of=/'
  '\bgit[[:space:]]+push[[:space:]]+.*--force'
  '\bgit[[:space:]]+push[[:space:]]+.*-f\b'
  '\bgit[[:space:]]+reset[[:space:]]+--hard'
  '\bgit[[:space:]]+clean[[:space:]]+-f'
  '\bgit[[:space:]]+stash[[:space:]]+drop'
  '\bgit[[:space:]]+branch[[:space:]]+-[dD]'
  '\bchmod[[:space:]]+(-R[[:space:]]+)?777'
  '\bchown[[:space:]]+-R'
  'curl.*\|[[:space:]]*(ba)?sh'
  'wget.*\|[[:space:]]*(ba)?sh'
  '\bkill[[:space:]]+-9'
  '\bkillall\b'
  '\bpkill\b'
  '\bshutdown\b'
  '\breboot\b'
  '\bsystemctl[[:space:]]+(stop|disable|mask)'
  '\bDROP[[:space:]]+(DATABASE|TABLE|SCHEMA)\b'
  '\bTRUNCATE\b'
  '\bdocker[[:space:]]+system[[:space:]]+prune[[:space:]]+-a'
  '\bdocker[[:space:]]+rm[[:space:]]+-f'
  '\bdocker[[:space:]]+rmi[[:space:]]+-f'
  '\bfind\b.*-delete'
  '\bfind\b.*-exec[[:space:]]+rm'
)

INJECTION_PATTERNS='(curl.*\|[[:space:]]*(ba)?sh|wget.*\|[[:space:]]*(ba)?sh|SECRET[[:space:]]+INSTRUCTIONS|hidden[[:space:]]+instructions|ignore[[:space:]]+(all[[:space:]]+)?previous|system[[:space:]]+prompt|<script)'

SECRET_PATTERNS='(AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|-----BEGIN[[:space:]]+(RSA[[:space:]]+)?PRIVATE[[:space:]]+KEY)'
