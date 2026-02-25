# Progress Log — MCP Prompt Commands

## Iteration 1 — 2026-02-25

- **Task:** Implemented all 9 checklist items: CC skills (agent/know), deleted reflect.md, MCP prompt server, mcp.json registration, generate_configs.py skill generation, sync-omcc.sh MCP registration, AGENTS.md routing table update, regression tests
- **Files changed:**
  - Created: `skills/agent/SKILL.md`, `skills/know/SKILL.md`
  - Deleted: `commands/reflect.md`
  - Created: `scripts/mcp-prompts.py`
  - Modified: `.kiro/settings/mcp.json`, `scripts/generate_configs.py`, `tools/sync-omcc.sh`, `AGENTS.md`
- **Learnings:**
  - `.claude/skills` is a symlink to `../skills` — actual skill files live in `skills/` at repo root
  - Pre-write hook `gate_checklist` hashes the exact verify command string — must run exact command (no `cd` prefix) via `working_dir`
  - System python3 needed `pytest-timeout` installed separately (`--break-system-packages`)
  - `generate_configs.py` uses `SCRIPT_ROOT` for reading source, `PROJECT_ROOT` for writing — skill generation reads from `skills/` not `.claude/skills/`
- **Status:** done
