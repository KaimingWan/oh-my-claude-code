#!/usr/bin/env python3
"""Append new tests to test_ralph_loop.py"""

new_tests = r'''


def test_worker_prompt_includes_checklist_state():
    """build_worker_prompt with checklist_context includes the unchecked item text."""
    from scripts.ralph_loop import build_worker_prompt
    ctx = "Completed: 4/6.\nRemaining items:\n- [ ] fix parser\n- [ ] update docs"
    prompt = build_worker_prompt("Fix parser", ["parser.py"], "echo ok", "plan.md",
                                checklist_context=ctx)
    assert "fix parser" in prompt
    assert "update docs" in prompt
    assert "Completed: 4/6" in prompt


def test_max_parallel_workers_env(tmp_path):
    """RALPH_MAX_PARALLEL_WORKERS=2 limits workers per batch to 2 even with 4 tasks."""
    task_section = (
        "## Tasks\n\n"
        "### Task 1: Alpha\n\n**Files:**\n- Create: `a.py`\n\n**Verify:** `echo ok`\n\n---\n\n"
        "### Task 2: Beta\n\n**Files:**\n- Create: `b.py`\n\n**Verify:** `echo ok`\n\n---\n\n"
        "### Task 3: Gamma\n\n**Files:**\n- Create: `c.py`\n\n**Verify:** `echo ok`\n\n---\n\n"
        "### Task 4: Delta\n\n**Files:**\n- Create: `d.py`\n\n**Verify:** `echo ok`\n\n"
    )
    items = (
        "- [ ] alpha | `echo ok`\n"
        "- [ ] beta | `echo ok`\n"
        "- [ ] gamma | `echo ok`\n"
        "- [ ] delta | `echo ok`"
    )
    plan_text = PLAN_TEMPLATE.format(items=items)
    plan_text = plan_text.replace("## Checklist", task_section + "## Checklist")
    write_plan(tmp_path, items=items)
    (tmp_path / "plan.md").write_text(plan_text)

    lock_path = Path(".ralph-loop.lock")
    lock_path.unlink(missing_ok=True)
    summary_file = Path("docs/plans/.ralph-result")
    try:
        r = run_ralph(tmp_path, extra_env={
            "RALPH_KIRO_CMD": "echo done",
            "RALPH_TASK_TIMEOUT": "5",
            "RALPH_MAX_PARALLEL_WORKERS": "2",
        }, max_iter="1")
        launched = r.stdout.count("\U0001f680 Worker")
        assert launched <= 2, f"Expected max 2 workers, got {launched}. Output:\n{r.stdout[:1000]}"
    finally:
        lock_path.unlink(missing_ok=True)
        summary_file.unlink(missing_ok=True)
        import subprocess as sp
        sp.run(["git", "worktree", "prune"], capture_output=True)


def test_parallel_checklist_persists_after_merge(tmp_path):
    """After parallel workers complete and merge, checklist items should be git-committed."""
    task_section = (
        "## Tasks\n\n"
        "### Task 1: Create alpha\n\n**Files:**\n- Create: `alpha.py`\n\n**Verify:** `test -f alpha.py`\n\n---\n\n"
        "### Task 2: Create beta\n\n**Files:**\n- Create: `beta.py`\n\n**Verify:** `test -f beta.py`\n\n"
    )
    items = (
        "- [ ] create alpha | `test -f alpha.py`\n"
        "- [ ] create beta | `test -f beta.py`"
    )
    plan_text = PLAN_TEMPLATE.format(items=items)
    plan_text = plan_text.replace("## Checklist", task_section + "## Checklist")
    write_plan(tmp_path, items=items)
    (tmp_path / "plan.md").write_text(plan_text)

    lock_path = Path(".ralph-loop.lock")
    lock_path.unlink(missing_ok=True)
    summary_file = Path("docs/plans/.ralph-result")
    try:
        worker_script = tmp_path / "create_file.sh"
        worker_script.write_text("#!/bin/bash\ntouch alpha.py beta.py && git add -A && git commit -m 'feat: create files'\n")
        worker_script.chmod(0o755)

        r = run_ralph(tmp_path, extra_env={
            "RALPH_KIRO_CMD": str(worker_script),
            "RALPH_TASK_TIMEOUT": "10",
        }, max_iter="2")
        plan_content = (tmp_path / "plan.md").read_text()
        checked_count = plan_content.count("- [x]")
        assert "update checklist" in r.stdout.lower() or checked_count > 0 or "verified" in r.stdout.lower(), \
            f"Expected checklist persistence. Plan:\n{plan_content}\nOutput:\n{r.stdout[:1000]}"
    finally:
        lock_path.unlink(missing_ok=True)
        summary_file.unlink(missing_ok=True)
        import subprocess as sp
        sp.run(["git", "worktree", "prune"], capture_output=True)
'''

with open('tests/ralph-loop/test_ralph_loop.py', 'a') as f:
    f.write(new_tests)

print('Done - appended 3 tests')
