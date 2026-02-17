import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

import pytest
from scripts.lib.plan import PlanFile

SAMPLE_PLAN = """\
# Test Plan

**Goal:** Test

## Checklist

- [x] item one | `echo ok`
- [ ] item two | `echo pending`
- [ ] item three | `echo pending`
- [SKIP] item four skipped | `echo skip`
"""

def test_counts(tmp_path):
    p = tmp_path / "plan.md"
    p.write_text(SAMPLE_PLAN)
    pf = PlanFile(p)
    assert pf.checked == 1
    assert pf.unchecked == 2
    assert pf.skipped == 1
    assert pf.total == 3

def test_next_items(tmp_path):
    p = tmp_path / "plan.md"
    p.write_text(SAMPLE_PLAN)
    pf = PlanFile(p)
    items = pf.next_unchecked(5)
    assert len(items) == 2
    assert "item two" in items[0]

def test_all_done(tmp_path):
    p = tmp_path / "plan.md"
    p.write_text(SAMPLE_PLAN.replace("- [ ]", "- [x]"))
    pf = PlanFile(p)
    assert pf.is_complete

def test_no_checklist(tmp_path):
    p = tmp_path / "plan.md"
    p.write_text("# Empty plan\nNo checklist here.")
    pf = PlanFile(p)
    assert pf.total == 0

def test_reload(tmp_path):
    p = tmp_path / "plan.md"
    p.write_text(SAMPLE_PLAN)
    pf = PlanFile(p)
    assert pf.unchecked == 2
    p.write_text(SAMPLE_PLAN.replace("- [ ] item two", "- [x] item two"))
    pf.reload()
    assert pf.unchecked == 1


TASK_PLAN = """\
# Test Plan
**Goal:** Test parallel execution

## Tasks

""" + "### " + "Task 1: Parser implementation\n\n" + "**Files:**\n- Modify: `scripts/lib/plan.py`\n- Test: `tests/ralph-loop/test_plan.py`\n\n" + "**Verify:** `echo ok`\n\n---\n\n" + "### " + "Task 2: Scheduler creation\n\n" + "**Files:**\n- Create: `scripts/lib/scheduler.py`\n- Test: `tests/ralph-loop/test_scheduler.py`\n\n" + "**Verify:** `echo ok`\n\n---\n\n" + "### " + "Task 3: Integration\n\n" + "**Files:**\n- Modify: `scripts/ralph_loop.py`\n- Modify: `scripts/lib/plan.py`\n\n" + "**Verify:** `echo ok`\n\n---\n\n" + "### " + "Task 4: Documentation\n\n" + "**Files:**\n- Modify: `skills/planning/SKILL.md`\n\n" + "**Verify:** `echo ok`\n\n## Checklist\n\n- [ ] item 1 | `echo ok`\n- [ ] item 2 | `echo ok`\n- [ ] item 3 | `echo ok`\n- [ ] item 4 | `echo ok`\n"""


def test_parse_tasks(tmp_path):
    p = tmp_path / "plan.md"
    p.write_text(TASK_PLAN)
    pf = PlanFile(p)
    tasks = pf.parse_tasks()
    
    assert len(tasks) == 4
    assert tasks[0].number == 1
    assert tasks[0].name == "Parser implementation"
    assert tasks[0].files == {"scripts/lib/plan.py", "tests/ralph-loop/test_plan.py"}
    
    assert tasks[1].number == 2
    assert tasks[1].name == "Scheduler creation"
    assert tasks[1].files == {"scripts/lib/scheduler.py", "tests/ralph-loop/test_scheduler.py"}
    
    assert tasks[2].number == 3
    assert tasks[2].name == "Integration"
    assert tasks[2].files == {"scripts/ralph_loop.py", "scripts/lib/plan.py"}
    
    assert tasks[3].number == 4
    assert tasks[3].name == "Documentation"
    assert tasks[3].files == {"skills/planning/SKILL.md"}


def test_parse_tasks_file_sets(tmp_path):
    p = tmp_path / "plan.md"
    p.write_text(TASK_PLAN)
    pf = PlanFile(p)
    tasks = pf.parse_tasks()
    
    # Task 1 and Task 3 share scripts/lib/plan.py
    assert "scripts/lib/plan.py" in tasks[0].files
    assert "scripts/lib/plan.py" in tasks[2].files
    
    # Task 2 and Task 4 have disjoint files
    assert tasks[1].files.isdisjoint(tasks[3].files)


def test_parse_tasks_empty_plan(tmp_path):
    p = tmp_path / "plan.md"
    p.write_text("# Empty Plan\nNo tasks here.")
    pf = PlanFile(p)
    tasks = pf.parse_tasks()
    assert tasks == []
