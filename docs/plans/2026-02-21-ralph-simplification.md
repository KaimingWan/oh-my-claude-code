# Ralph Loop Simplification — Remove Worktree Parallel Execution

**Goal:** Remove worktree-based parallel execution from ralph loop to eliminate instability (13 bugs in 2 days), reduce code complexity (~300 lines + ~40 tests), and restore pre-worktree sequential performance (~4 min/item vs 6+ min/item when parallel degrades).
**Non-Goals:** Add new parallel execution mechanism (future work when platform supports in-process subagent with LSP). Change ralph loop's core restart-on-stop design. Remove executor agent config (used by other subagent scenarios).
**Architecture:** Strip worktree.py, git_retry.py, scheduler.py, and all parallel code paths from ralph_loop.py. Keep sequential loop with heartbeat/stall detection. Add @execute detection in context-enrichment.sh. Raise stall_timeout default from 300s to 600s.
**Tech Stack:** Python 3, Bash, pytest

## Tasks

### Task 1: Delete Parallel Modules

Remove the three library modules that only serve parallel execution.

**Files:**
- Delete: `scripts/lib/worktree.py`
- Delete: `scripts/lib/git_retry.py`
- Delete: `scripts/lib/scheduler.py`
- Delete: `tests/ralph-loop/test_worktree.py`
- Delete: `tests/ralph-loop/test_git_retry.py`
- Delete: `tests/ralph-loop/test_scheduler.py`

**Verify:** `test ! -f scripts/lib/worktree.py && test ! -f scripts/lib/git_retry.py && test ! -f scripts/lib/scheduler.py && test ! -f tests/ralph-loop/test_worktree.py`

**What to implement:**
Delete the 6 files listed above. These modules are only used by parallel execution.

### Task 2: Strip Parallel Code from ralph_loop.py

Remove all parallel/worktree code paths from the main loop script. Keep sequential execution, heartbeat, stall detection, circuit breaker.

**Files:**
- Modify: `scripts/ralph_loop.py`
- Modify: `tests/ralph-loop/test_ralph_loop.py`

**Verify:** `python3 -c "import ast; t=ast.parse(open('scripts/ralph_loop.py').read()); ms=[n.module for n in ast.walk(t) if isinstance(n,ast.ImportFrom) and n.module]; assert 'scripts.lib.scheduler' not in ms and 'scripts.lib.worktree' not in ms; print('OK')"`

**What to implement:**

From ralph_loop.py, remove:
- Imports: `from scripts.lib.scheduler import build_batches, Batch` and `from scripts.lib.worktree import WorktreeManager`
- Functions: `_extract_verify_cmd()`, `build_worker_prompt()`, `build_batch_prompt()`, `run_parallel_batch()`
- Config fields: `max_parallel_workers`
- `make_cleanup_handler`: remove `worker_pgids`, `wt_manager` params and all worker/pgid cleanup code. Simplify to only kill `child_proc_ref[0]` and release lock.
- `main()`: remove `worker_pgids`, `wt_manager`, `child_procs` list, `worker_log_dir`, parallel batch routing in main loop, startup banner batch display, worktree cleanup calls
- Prompt functions: remove "PARALLEL EXECUTION" paragraph (rule 9) from `build_prompt()` and `build_init_prompt()`

From test_ralph_loop.py, remove these tests: `test_parallel_prompt_contains_dispatch`, `test_batch_mode_startup_banner`, `test_parallel_prompt_structure`, `test_partial_parse_still_batches`, `test_worker_prompt_no_plan_update`, `test_parallel_batch_creates_worktrees`, `test_parallel_workers_killed_on_exit`, `test_worker_prompt_includes_checklist_state`, `test_max_parallel_workers_env`, `test_parallel_checklist_persists_after_merge`, `test_build_batch_prompt_uses_real_plan`, `test_batch_prompt_includes_skip_and_security_guidance`

### Task 3: Raise stall_timeout and Clean Up Config

Raise default stall_timeout from 300s to 600s so agent has more time per iteration to complete multiple tasks without being killed.

**Files:**
- Modify: `scripts/ralph_loop.py`

**Verify:** `python3 -c "from scripts.ralph_loop import Config; assert Config().stall_timeout == 600; print('OK')"`

**What to implement:**
In `Config` dataclass, change: `stall_timeout: int = 600`

### Task 4: Add @execute Detection in context-enrichment.sh

When user message contains `@execute`, inject a strong directive to run ralph loop immediately.

**Files:**
- Modify: `hooks/feedback/context-enrichment.sh`

**Verify:** `echo '{"prompt":"@execute"}' | bash hooks/feedback/context-enrichment.sh 2>/dev/null | grep -q 'ralph_loop'`

**What to implement:**
Add after the debugging skill reminder block:

```bash
# @execute command — force ralph loop
if echo "$USER_MSG" | grep -qE '^@execute|^/execute'; then
  echo "🚀 Execute detected → Run \`python3 scripts/ralph_loop.py\` immediately. Do NOT read the plan or implement tasks yourself."
fi
```

### Task 5: Simplify SKILL.md Execution Strategies

Remove Strategy B/C/D and Workspace Isolation sections. Keep only Strategy A (sequential).

**Files:**
- Modify: `skills/planning/SKILL.md`

**Verify:** `! grep -q 'Strategy B\|Strategy C\|Strategy D\|Workspace Isolation.*Worktree' skills/planning/SKILL.md`

**What to implement:**
Replace the Strategy Selection table and Strategy B/C/D/Workspace Isolation sections (lines 352-437) with:

```markdown
### Execution Strategy

Sequential execution: one task at a time, commit after each.

1. Load plan, identify next unchecked item
2. Execute task (implement + test + verify)
3. Check off item, commit
4. Continue to next. Repeat until done.

Each ralph loop iteration spawns a fresh CLI with clean context. The agent should complete as many tasks as possible per iteration before context fills up.
```

### Task 6: Clean Up .worktrees and .gitignore

Remove .worktrees directory and its .gitignore entry.

**Files:**
- Modify: `.gitignore`

**Verify:** `test ! -d .worktrees && ! grep -q '.worktrees' .gitignore`

**What to implement:**
Remove `.worktrees/` directory. Remove `.worktrees` line from `.gitignore`.

### Task 7: Full Regression Test

Run the complete test suite to verify nothing is broken.

**Files:**
- Test: `tests/`

**Verify:** `python3 -m pytest tests/ -v --tb=short 2>&1 | tail -1 | grep -q 'passed'`

**What to implement:**
Run `python3 -m pytest tests/ -v`. Expect ALL PASS, ~130 tests (down from 171). Fix any regressions.

## Review
<!-- Reviewer writes here -->

## Checklist

- [x] worktree.py, git_retry.py, scheduler.py deleted | `test ! -f scripts/lib/worktree.py && test ! -f scripts/lib/git_retry.py && test ! -f scripts/lib/scheduler.py`
- [x] parallel test files deleted | `test ! -f tests/ralph-loop/test_worktree.py && test ! -f tests/ralph-loop/test_git_retry.py && test ! -f tests/ralph-loop/test_scheduler.py`
- [x] ralph_loop.py has no parallel imports | `python3 -c "import ast; t=ast.parse(open('scripts/ralph_loop.py').read()); ms=[n.module for n in ast.walk(t) if isinstance(n,ast.ImportFrom) and n.module]; assert 'scripts.lib.scheduler' not in ms and 'scripts.lib.worktree' not in ms; print('OK')"`
- [x] ralph_loop.py has no parallel functions | `! grep -q 'def run_parallel_batch\|def build_worker_prompt\|def _extract_verify_cmd\|def build_batch_prompt' scripts/ralph_loop.py`
- [x] stall_timeout default is 600 | `python3 -c "from scripts.ralph_loop import Config; assert Config().stall_timeout == 600; print('OK')"`
- [x] @execute triggers ralph loop injection | `echo '{"prompt":"@execute"}' | bash hooks/feedback/context-enrichment.sh 2>/dev/null | grep -q 'ralph_loop'`
- [x] SKILL.md has no parallel strategies | `! grep -q 'Strategy B\|Strategy C\|Strategy D\|Workspace Isolation.*Worktree' skills/planning/SKILL.md`
- [x] .worktrees dir removed | `test ! -d .worktrees`
- [x] 回归测试通过 | `python3 -m pytest tests/ -v`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|

## Future

When Kiro/CC platform supports in-process subagent with LSP tools and zero cold-start, re-evaluate parallel execution. The implementation would be much simpler: no worktree, no merge, no process management — just `use_subagent` calls within a single CLI session.
