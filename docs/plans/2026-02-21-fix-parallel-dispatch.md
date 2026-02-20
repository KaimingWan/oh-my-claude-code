# Fix Ralph Loop Parallel Dispatch Bugs

**Goal:** 修复 ralph loop 并行执行的 2 个核心 bug：(1) 已完成 task 被反复调度（unchecked_tasks fallback 返回所有 task），(2) 无改动 worker 的空 merge 被当作冲突浪费 iteration。
**Non-Goals:** 不改变 scheduler 算法；不改变 worktree 隔离策略；不添加新功能。
**Architecture:** 修改 plan.py 的 unchecked_tasks() 和 worktree.py 的 merge()。所有改动向后兼容。
**Tech Stack:** Python 3, pytest

## Tasks

### Task 1: Fix unchecked_tasks() unmatched fallback

当 checklist 项（如"回归测试通过"）无法匹配到任何 task 时，当前 fallback 返回所有 task。这导致已完成的 task 被反复调度。

**Files:**
- Modify: `scripts/lib/plan.py`
- Test: `tests/ralph-loop/test_plan.py`

**Step 1: Write failing test**

```python
# tests/ralph-loop/test_plan.py — append
def test_unchecked_tasks_skips_completed_with_unmatched_items(tmp_path):
    """When unmatched checklist items exist but all tasks are done, return empty."""
    plan_file = tmp_path / "plan.md"
    plan_file.write_text("""# Plan
## Tasks
### Task 1: Fix parser
Files: a.py
### Task 2: Fix lexer
Files: b.py
## Checklist
- [x] parser fixed | `echo ok`
- [x] lexer fixed | `echo ok`
- [ ] 回归测试通过 | `python3 -m pytest tests/ -v`
- [ ] 全量测试通过 | `python3 -m pytest tests/ -v`
""")
    from scripts.lib.plan import PlanFile
    p = PlanFile(plan_file)
    result = p.unchecked_tasks()
    # Should NOT return Task 1 and Task 2 — they're done
    assert len(result) == 0, f"Expected 0 tasks, got {[t.name for t in result]}"
```

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_plan.py::test_unchecked_tasks_skips_completed_with_unmatched_items -v`
Expected: FAIL (returns all 2 tasks due to unmatched fallback)

**Step 3: Write minimal implementation**

修改 `unchecked_tasks()` 的 unmatched fallback 逻辑（约 L90）：当有 unmatched unchecked 项时，不再返回所有 task，而是只返回自身有 unchecked matched 项的 task。如果没有任何 task 有 unchecked matched 项，返回空列表。

```python
# Replace:
if unmatched_unchecked:
    return tasks
# With:
# Unmatched items don't cause all tasks to be returned.
# Only return tasks that have their own unchecked matched items.
```

**Step 4: Run test — verify it passes**
Run: `python3 -m pytest tests/ralph-loop/test_plan.py -v`
Expected: PASS

**Step 5: Commit**

**Verify:** `python3 -m pytest tests/ralph-loop/test_plan.py::test_unchecked_tasks_skips_completed_with_unmatched_items -v`

### Task 2: Handle empty squash merge gracefully

当 worker 在 worktree 中没有产生新 commit（task 已完成或 worker 没做改动），`git merge --squash` 报 "nothing to squash"，`git commit` 因无 staged changes 失败，整个 merge 被当作冲突处理。

**Files:**
- Modify: `scripts/lib/worktree.py`
- Test: `tests/ralph-loop/test_worktree.py`

**Step 1: Write failing test**

```python
# tests/ralph-loop/test_worktree.py — append
def test_merge_no_changes_returns_true(git_repo):
    """merge() should return True (not False) when worker made no changes."""
    wm = WorktreeManager(base_dir=str(git_repo / ".worktrees"), project_root=str(git_repo))
    wm.create("empty")
    # Don't make any changes in the worktree
    result = wm.merge("empty")
    assert result is True, "Empty merge should succeed, not be treated as conflict"
```

**Step 2: Run test — verify it fails**
Run: `python3 -m pytest tests/ralph-loop/test_worktree.py::test_merge_no_changes_returns_true -v`
Expected: FAIL (CalledProcessError from git commit with nothing to commit)

**Step 3: Write minimal implementation**

修改 `worktree.py` 的 `merge()` 方法（L26-48）：在 `git merge --squash` 之后、`git commit` 之前，检查是否有 staged changes。如果没有，跳过 commit 直接返回 True。

```python
# After git merge --squash and git restore docs/plans/:
# Check if there are staged changes to commit
diff = subprocess.run(["git", "diff", "--cached", "--quiet"],
                      cwd=self.project_root, capture_output=True)
if diff.returncode == 0:
    # Nothing staged — worker made no changes, skip commit
    return True
git_run(["git", "commit", "-m", f"squash: merge {branch_name}"], ...)
```

**Step 4: Run test — verify it passes**
Run: `python3 -m pytest tests/ralph-loop/test_worktree.py -v`
Expected: PASS

**Step 5: Commit**

**Verify:** `python3 -m pytest tests/ralph-loop/test_worktree.py::test_merge_no_changes_returns_true -v`

## Checklist

- [ ] unchecked_tasks 不返回已完成 task | `python3 -m pytest tests/ralph-loop/test_plan.py::test_unchecked_tasks_skips_completed_with_unmatched_items -v`
- [ ] 空 merge 返回 True 而非冲突 | `python3 -m pytest tests/ralph-loop/test_worktree.py::test_merge_no_changes_returns_true -v`
- [ ] 回归测试通过 | `python3 -m pytest tests/ralph-loop/ -v`
- [ ] 全量测试通过 | `python3 -m pytest tests/ -v`

## Review
<!-- Reviewer writes here -->

## Errors

| Error | Task | Attempt | Resolution |
|-------|------|---------|------------|
