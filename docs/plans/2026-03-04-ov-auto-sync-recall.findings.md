# OV Auto-Sync & Recall — Findings

## Codebase Patterns

- **Hook lib sourcing:** `source "$(dirname "$0")/../_lib/<lib>.sh" 2>/dev/null || true` — always with fallback
- **OV availability check:** `_ov_check_overlay` checks `.omcc-overlay.json` for `knowledge_backend == openviking`; `ov_init` additionally checks socket + health
- **macOS compat:** No `timeout` command available — use `sleep` in loop instead
- **Error handling in hooks:** Hooks must not block on OV failure — always `|| true` on ov calls
- **session-init guard:** Uses `$LESSONS_FLAG` file to run once per session; new code goes before `touch "$LESSONS_FLAG"`
