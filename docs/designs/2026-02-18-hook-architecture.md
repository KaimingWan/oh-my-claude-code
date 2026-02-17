# Hook Architecture Design

> Canonical reference for the hook system. All hook changes must conform to this document.
> **Status:** Active | **Date:** 2026-02-18

## Design Principles

### Three-Category System

| Category | Directory | Exit behavior | Purpose | Bypass |
|----------|-----------|--------------|---------|--------|
| **security** | `hooks/security/` | exit 2 = hard block | Unconditional safety invariants (dangerous commands, secrets, workspace boundary) | None — never bypassable |
| **gate** | `hooks/gate/` | exit 2 = hard block | Workflow enforcement (plan required, ralph loop, regression tests) | `.skip-plan`, `.skip-ralph` marker files |
| **feedback** | `hooks/feedback/` | exit 0 = advisory | Context injection, auto-test, progress tracking, completion verification | Always runs, agent may ignore output |

**Decision rule:** If the constraint must never be violated → security. If it enforces a workflow that has legitimate bypass scenarios → gate. If it provides information or runs side-effects → feedback.

### Boundary Clarifications

- `gate/pre-write.sh` contains an advisory function (`inject_plan_context`) alongside blocking gates. This is intentional — the advisory piggybacks on the same stdin parse to avoid a separate hook invocation. The file's category is gate (its primary purpose is blocking).
- `feedback/post-write.sh` returns exit 1 on test failure. PostToolUse exit 1 is treated as advisory by the platform — it does not block the write. The file's category is feedback.
- Shadow hooks (scripts called internally by other hooks, not registered in config) are categorized by their caller's category.

### Core Invariants

1. **Single config source:** `scripts/generate_configs.py` generates all config files. Never hand-edit `.claude/settings.json` or `.kiro/agents/*.json`.
2. **enforcement.md is design-layer SoT:** `.kiro/rules/enforcement.md` defines what hooks exist, their classification, and their purpose. `generate_configs.py` is config-layer SoT (which hook registers to which agent/event). When they disagree, fix the generator to match enforcement.md.
3. **As-code over as-text:** If a constraint can be enforced by a hook, don't rely on AGENTS.md or rules/ to enforce it.

## Hook Registry

### Direct Hooks (registered in config)

| # | Hook | Path | Event(s) | Category | Source deps |
|---|------|------|----------|----------|-------------|
| 1 | Dangerous command blocker | `hooks/security/block-dangerous.sh` | PreToolUse[bash] | security | common.sh, patterns.sh, block-recovery.sh |
| 2 | Secret leak blocker | `hooks/security/block-secrets.sh` | PreToolUse[bash] | security | common.sh, patterns.sh, block-recovery.sh |
| 3 | sed/awk on JSON blocker | `hooks/security/block-sed-json.sh` | PreToolUse[bash] | security | common.sh, block-recovery.sh |
| 4 | Workspace boundary guard | `hooks/security/block-outside-workspace.sh` | PreToolUse[bash,write] | security | common.sh, block-recovery.sh |
| 5 | Pre-write dispatcher | `hooks/gate/pre-write.sh` | PreToolUse[write] | gate | common.sh, patterns.sh |
| 6 | Ralph loop enforcer | `hooks/gate/enforce-ralph-loop.sh` | PreToolUse[bash,write] | gate | common.sh |
| 7 | Regression test gate | `hooks/gate/require-regression.sh` | PreToolUse[bash] | gate | common.sh |
| 8 | Post-write dispatcher | `hooks/feedback/post-write.sh` | PostToolUse[write] | feedback | common.sh |
| 9 | Bash execution logger | `hooks/feedback/post-bash.sh` | PostToolUse[bash] | feedback | common.sh |
| 10 | Correction detector | `hooks/feedback/correction-detect.sh` | UserPromptSubmit | feedback | — |
| 11 | Session initializer | `hooks/feedback/session-init.sh` | UserPromptSubmit | feedback | — |
| 12 | Context enrichment | `hooks/feedback/context-enrichment.sh` | UserPromptSubmit | feedback | — |
| 13 | Completion verifier | `hooks/feedback/verify-completion.sh` | Stop | feedback | common.sh |

### Shadow Hooks (called internally, not in config)

| # | Hook | Path | Called by | Purpose |
|---|------|------|----------|---------|
| 14 | Auto-capture | `hooks/feedback/auto-capture.sh` | correction-detect.sh | Write correction to episodes.md |
| 15 | KB health report | `hooks/feedback/kb-health-report.sh` | verify-completion.sh | Generate knowledge base health report |

### Shared Libraries (`_lib/`)

| File | API | Used by | Contract |
|------|-----|---------|----------|
| `common.sh` | `hook_block()`, `file_mtime()`, `detect_test_command()`, `is_source_file()`, `is_test_file()`, `find_active_plan()` | All hooks | Stable — changes must not break existing callers. New functions: add, don't modify signatures. |
| `patterns.sh` | `DANGEROUS_BASH_PATTERNS[]`, `INJECTION_PATTERNS`, `SECRET_PATTERNS` | security hooks, pre-write.sh | Append-only arrays. Never remove patterns without security review. |
| `block-recovery.sh` | `hook_block_with_recovery()` | security hooks | Wraps `hook_block()` with retry counting and skip-after-3 logic. |

### Agent Registration Matrix

| Hook | default | pilot | executor | researcher | reviewer | CC settings.json |
|------|---------|-------|----------|------------|----------|-------------------|
| block-dangerous | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| block-secrets | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| block-sed-json | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| block-outside-workspace | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| pre-write | ✅ | ✅ | — | — | — | ✅ |
| enforce-ralph-loop | ✅ | ✅ | — | — | — | ✅ |
| require-regression | — | ✅ | — | — | — | — |
| post-write | ✅ | ✅ | — | — | — | ✅ |
| post-bash | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| correction-detect | ✅ | ✅ | — | — | — | ✅ |
| session-init | ✅ | ✅ | — | — | — | ✅ |
| context-enrichment | ✅ | ✅ | — | — | — | ✅ |
| verify-completion | ✅ | ✅ | — | — | — | ✅ |

## Lifecycle

### Adding a New Hook

1. **Classify** — Use the decision tree in Extensibility section below.
2. **Write script** — Place in `hooks/<category>/`, source `_lib/common.sh`. Naming: `verb-noun.sh`.
3. **Update enforcement.md** — Add row to Hook Registry in `.kiro/rules/enforcement.md`.
4. **Update generator** — Add hook to `scripts/generate_configs.py` in the appropriate agent builder(s).
5. **Regenerate configs** — `python3 scripts/generate_configs.py`
6. **Validate** — `python3 scripts/generate_configs.py --validate`
7. **Write tests** — Add to `tests/hooks/`.
8. **Update this doc** — Add row to Hook Registry and Agent Registration Matrix above.

### Modifying an Existing Hook

1. Make changes to the script.
2. Run existing tests: `bash tests/hooks/test-kiro-compat.sh`
3. If changing function signatures in `_lib/`: check all callers first.
4. Update enforcement.md if the hook's event, type, or purpose changed.
5. Run `python3 scripts/generate_configs.py --validate`
6. Update this doc if registry information changed.

### Deprecating a Hook

1. Mark `deprecated` in enforcement.md registry with reason and replacement.
2. Remove from `scripts/generate_configs.py`.
3. Regenerate configs: `python3 scripts/generate_configs.py`
4. Move script to `.trash/` (preserve for recovery).
5. Update this doc — move from registry to a "Deprecated" section.
6. Clean up `.trash/` on next major version.

### Shadow Hook Rules

- A shadow hook is a script called by another hook via `bash "$(dirname "$0")/script.sh"`, not registered in any config.
- Shadow hooks must be listed in the Shadow Hooks table above.
- The caller is responsible for error handling — shadow hook failures should not crash the caller.
- To promote a shadow hook to a direct hook: follow the "Adding" flow above.

## Extensibility

### Classification Decision Tree

```
New constraint needed
  ├── Can it be violated without safety risk?
  │   ├── No → security/ (exit 2, no bypass)
  │   └── Yes ↓
  ├── Does it enforce a workflow step?
  │   ├── Yes → gate/ (exit 2, bypass via marker file)
  │   └── No ↓
  └── It provides information or side-effects
      └── feedback/ (exit 0, advisory)
```

### Event Coverage and Extension Points

| Event | Current hooks | How to extend |
|-------|--------------|---------------|
| PreToolUse[bash] | 4 security + 2 gate | Add patterns to `patterns.sh` before creating new hooks |
| PreToolUse[write] | 1 gate (pre-write.sh, multi-phase) | Add new phases to pre-write.sh |
| PostToolUse[write] | 1 feedback (post-write.sh, multi-function) | Add functions to post-write.sh |
| PostToolUse[bash] | 1 feedback | Extend post-bash.sh |
| UserPromptSubmit | 3 feedback | Add detection patterns to existing hooks first |
| Stop | 1 feedback | Extend verify-completion.sh |

**Future events:** When Kiro CLI adds new events (e.g., `agentSpawn`, `SessionEnd`), create new hook scripts following the "Adding" flow. Do not retrofit existing hooks.

### Shared Library Extension

- **`common.sh`:** Append-only functions. Document with one-line comment. Do not change existing signatures.
- **`patterns.sh`:** Append-only arrays. Never remove patterns without security review.
- **New `_lib/` files:** Allowed for genuinely new capabilities. Must be sourced explicitly — no auto-loading.

### Merged Hook Strategy

`pre-write.sh` and `post-write.sh` merge multiple logical hooks into one script to reduce invocation overhead:

1. Prefer adding a phase/function to the existing merged hook over creating a new script.
2. Each phase must be a named function with a clear comment header.
3. Phase numbering must be sequential (0, 1, 2, ...) matching execution order.
4. Gate phases (exit 2) must come before advisory phases (exit 0).
