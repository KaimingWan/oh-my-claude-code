# Hardening Sprint: verify-completion, worktree, tests, agent authority

**Goal:** Fix verify-completion 30s timeout by removing redundant execution; harden worktree.py against known bugs (duplicate create, unsafe cleanup, fragile merge); improve test quality (eliminate hacky exec-based imports, register slow mark, strengthen worktree test isolation); allow agent to write instruction files after user confirmation.
**Non-Goals:** Rewrite ralph_loop.py main loop; add new features to worktree (e.g. rebase strategy); change hook architecture; modify test framework (pytest plugins).
**Architecture:** Four independent workstreams touching different file sets. Task 1 simplifies verify-completion.sh. Tasks 2-3 harden worktree.py and its tests. Task 4 refactors ralph_loop.py to make functions importable (eliminating exec hack). Task 5 registers pytest slow mark and optimizes test timeouts. Task 6 updates authority matrix for agent-assisted instruction writes.
**Tech Stack:** Bash, Python 3, pytest, git

## Tasks

### Task 1: Slim down verify-completion.sh

**Files:**
- Modify: `hooks/feedback/verify-completion.sh`

**Step 1: Modify verify-completion.sh**
Remove the verify-command re-execution loop (lines 28-40) and the `detect_test_command` + `eval` block (lines 44-48). Keep: checklist completeness check (unchecked count), verify-log cleanup, kb-health-report call. The `_RALPH_LOOP_RUNNING` guards for the removed blocks can also be removed since the blocks themselves are gone.

**Step 2: Run test — verify it passes**
Run: `bash -n hooks/feedback/verify-completion.sh && echo '{}' | bash hooks/feedback/verify-completion.sh; echo "exit: $?"`
Expected: PASS (syntax valid, exits 0 quickly)

**Step 3: Commit**
`fix: verify-completion stop hook — remove redundant verify+test execution`

**Verify:** `bash -n hooks/feedback/verify-completion.sh && ! grep -q 'detect_test_command\|alarm(30)' hooks/feedback/verify-completion.sh`

---

### Task 2: Harden worktree.py

**Files:**
- Modify: `scripts/lib/worktree.py`
- Test: `tests/ralph-loop/test_worktree.py`

**Step 1: Write failing tests**
Add tests to `test_worktree.py`:
- `test_create_duplicate_name`: call `create("x")` twice → second should not crash (idempotent via `-B` flag, but verify path still valid)
- `test_cleanup_stale_with_registered_worktree`: create a real worktree, then manually delete its directory (simulating stale), call `cleanup_stale()` → should prune git metadata AND delete leftover branches
- `test_merge_no_docs_plans`: merge when worktree branch has no docs/plans/ changes → should succeed without error from `git checkout HEAD~1 -- docs/plans/`
- `test_remove_already_removed`: call `remove("x")` when worktree doesn't exist → should not raise

**Step 2: Fix worktree.py**
1. `create()`: add existence check — if worktree path already exists, `remove()` it first then recreate
2. `merge()`: guard `git checkout HEAD~1 -- docs/plans/` with a check that docs/plans/ actually differs between merge commit and parent. Use `git diff --name-only HEAD~1 HEAD -- docs/plans/` — if empty, skip the checkout+amend. Wrap the diff check in try/except (CalledProcessError → skip restore, don't abort merge)
3. `remove()`: wrap both subprocess calls in try/except to handle already-removed case
4. `cleanup_stale()`: call `git worktree remove --force` before `shutil.rmtree` for directories that are still registered

**Step 3: Run tests**
Run: `python3 -m pytest tests/ralph-loop/test_worktree.py -v`
Expected: PASS

**Step 4: Commit**
`fix: worktree.py — idempotent create, safe merge, robust remove/cleanup`

**Verify:** `python3 -m pytest tests/ralph-loop/test_worktree.py -v`

---

### Task 3: Strengthen worktree test isolation

**Files:**
- Modify: `tests/ralph-loop/test_worktree.py`

**Step 1: Add teardown safety**
Refactor `git_repo` fixture to include a `WorktreeManager` cleanup in its teardown (after yield). This ensures no leftover worktrees or branches even if assertions fail mid-test. Add explicit `wm.cleanup_all()` in a try/finally for every test that creates worktrees.

**Step 2: Run tests**
Run: `python3 -m pytest tests/ralph-loop/test_worktree.py -v`
Expected: PASS

**Step 3: Commit**
`test: worktree tests — add teardown safety for branch cleanup`

**Verify:** `python3 -m pytest tests/ralph-loop/test_worktree.py -v`

---

### Task 4: Make ralph_loop.py functions importable (eliminate exec hack)

**Files:**
- Modify: `scripts/ralph_loop.py`
- Modify: `tests/ralph-loop/test_ralph_loop.py`
- Modify: `tests/ralph-loop/conftest.py`

**Step 1: Refactor ralph_loop.py**
Wrap all module-level side effects (plan loading, lock acquisition, signal handlers, main loop) in `if __name__ == "__main__":` block. Functions (`build_batch_prompt`, `build_worker_prompt`, `build_prompt`, `build_init_prompt`, `_extract_verify_cmd`, `write_summary`, `_heartbeat`, `_cleanup_handler`, `run_parallel_batch`, `die`) stay at module level and become safely importable. Module-level constants that depend on argv/env (`MAX_ITERATIONS`, `PLAN_POINTER`, `TASK_TIMEOUT`, `HEARTBEAT_INTERVAL`, `STALL_TIMEOUT`, `MAX_STALE`, etc.) move inside main block. Functions that reference these receive them as parameters — specifically:
- `build_prompt(iteration, prev_exit, plan, plan_path, project_root, skip_precheck)` 
- `build_init_prompt(plan, plan_path, project_root, skip_precheck)`
- `build_batch_prompt(batch, plan_path, iteration)` — already parameterized, no change
- `build_worker_prompt(...)` — already parameterized, no change
- `_heartbeat(proc, iteration, stop_event, plan, stall_timeout)` — add plan + stall_timeout params
- `write_summary(exit_code, plan, plan_path, summary_file)` — add explicit params
- `run_parallel_batch(batch, iteration, ...)` — receives config as params

**Step 2: Update tests**
Replace all `_import_build_batch_prompt()`, `_import_build_prompt()`, `_import_build_init_prompt()` exec-based hacks and `import_ralph_fn()` in conftest.py with direct imports:
```python
from scripts.ralph_loop import build_batch_prompt, build_worker_prompt
```

**Step 3: Run tests**
Run: `python3 -m pytest tests/ralph-loop/test_ralph_loop.py -v`
Expected: PASS

**Step 4: Commit**
`refactor: ralph_loop.py — wrap side effects in __main__, enable direct import`

**Verify:** `python3 -m pytest tests/ralph-loop/test_ralph_loop.py -v`

---

### Task 5: Test quality — register slow mark, optimize timeouts

**Files:**
- Modify: `pyproject.toml`
- Modify: `tests/ralph-loop/test_ralph_loop.py`

**Step 1: Register slow mark**
Add pytest marker registration (create pyproject.toml or add section if exists):
```toml
[tool.pytest.ini_options]
markers = ["slow: marks tests as slow (deselect with '-m \"not slow\"')"]
```

**Step 2: Reduce sleep-based waits**
In tests that use `time.sleep(1)` for process startup detection, replace with poll loops (some already do this — `test_no_orphan_after_ralph_killed` has a good pattern with deadline). Target: `test_lock_cleanup_on_signal`, `test_sigint_cleanup`, `test_double_ralph_no_lock_guard`.

**Step 3: Run tests**
Run: `python3 -m pytest tests/ralph-loop/ -v`
Expected: PASS, 0 warnings about unknown marks

**Step 4: Commit**
`test: register slow mark, replace sleep with poll loops`

**Verify:** `python3 -m pytest tests/ralph-loop/ --co -q 2>&1 | grep -cv 'PytestUnknownMarkWarning' > /dev/null && ! python3 -m pytest tests/ralph-loop/ --co -q 2>&1 | grep -q 'PytestUnknownMarkWarning'`

---

### Task 6: Agent authority for instruction file writes

**Files:**
- Modify: `AGENTS.md`
- Modify: `skills/self-reflect/SKILL.md`

**Step 1: Update Authority Matrix in AGENTS.md**
Change "仅人操作：修改 CLAUDE.md / .claude/rules/（hook enforced）" to include exception: agent can execute `.skip-instruction-guard` three-step flow after user explicitly confirms content in conversation.

**Step 2: Strengthen self-reflect SKILL.md**
In the "Writing to Protected Files" section, clarify that agent SHOULD execute this flow autonomously after user confirmation — not wait for human to do it manually.

**Step 3: Commit**
`docs: authorize agent to execute instruction-guard bypass after user confirmation`

**Verify:** `grep -q '代执行' AGENTS.md`

---

## Review

### Round 1 (4 reviewers)
- **Goal Alignment:** APPROVE — all 6 tasks map to goal phrases, no gaps, no unnecessary tasks
- **Verify Correctness:** REQUEST CHANGES — flagged that AGENTS.md/SKILL.md don't contain expected text pre-implementation. **Rejected finding:** verify commands check post-implementation state; Task 6 creates the content. False positive.
- **Completeness:** REQUEST CHANGES — two valid findings:
  1. Task 2 merge() git diff check needs try/except → **Fixed:** added error handling spec
  2. Task 4 variable scoping not specified → **Fixed:** added explicit parameter lists for each function
- **Technical Feasibility:** APPROVE — no blockers, pyproject.toml doesn't exist (no conflict), __main__ refactor preserves script entry point

### Round 2 (2 reviewers — fixed angles only)
- **Goal Alignment:** APPROVE — confirmed fixes address Round 1 feedback, all tasks still aligned
- **Verify Correctness:** APPROVE — all 13 verify commands traced, exit codes sound for both correct/broken cases

**Final verdict: APPROVE (Round 2 unanimous)**

## Checklist
- [ ] verify-completion 不再执行 verify commands 和 test suite | `! grep -q 'detect_test_command\|alarm(30)' hooks/feedback/verify-completion.sh`
- [ ] verify-completion 语法正确 | `bash -n hooks/feedback/verify-completion.sh`
- [ ] worktree create 幂等（重复创建不崩溃） | `python3 -m pytest tests/ralph-loop/test_worktree.py::test_create_duplicate_name -v`
- [ ] worktree merge 无 docs/plans 变更时不报错 | `python3 -m pytest tests/ralph-loop/test_worktree.py::test_merge_no_docs_plans -v`
- [ ] worktree remove 已删除时不报错 | `python3 -m pytest tests/ralph-loop/test_worktree.py::test_remove_already_removed -v`
- [ ] worktree cleanup_stale 处理注册但已删除的 worktree | `python3 -m pytest tests/ralph-loop/test_worktree.py::test_cleanup_stale_with_registered_worktree -v`
- [ ] worktree 测试有 teardown 安全保障 | `python3 -m pytest tests/ralph-loop/test_worktree.py -v`
- [ ] ralph_loop.py 函数可直接 import | `python3 -c "from scripts.ralph_loop import build_batch_prompt, build_worker_prompt; print('ok')"`
- [ ] 测试不再用 exec hack 导入函数 | `! grep -q '_import_build_batch_prompt\|import_ralph_fn' tests/ralph-loop/test_ralph_loop.py`
- [ ] pytest slow mark 已注册（无 warning） | `! python3 -m pytest tests/ralph-loop/ --co -q 2>&1 | grep -q 'PytestUnknownMarkWarning'`
- [ ] 回归测试通过 | `python3 -m pytest tests/ralph-loop/ -v`
- [ ] AGENTS.md 包含 agent 代执行授权 | `grep -q '代执行' AGENTS.md`
- [ ] self-reflect SKILL.md 明确 agent 可自动执行 | `grep -qiE 'autonomously|自动执行' skills/self-reflect/SKILL.md`

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|
