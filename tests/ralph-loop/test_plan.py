import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

import pytest
import threading
import time
from scripts.lib.plan import PlanFile, TaskInfo
from scripts.lib.scheduler import build_batches

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


UNCHECKED_PLAN = """\
# Test Plan
**Goal:** Test unchecked filtering

## Tasks

""" + "### " + "Task 1: Alpha\n\n**Files:**\n- Create: `a.py`\n\n**Verify:** `echo ok`\n\n---\n\n" + "### " + "Task 2: Beta\n\n**Files:**\n- Create: `b.py`\n\n**Verify:** `echo ok`\n\n---\n\n" + "### " + "Task 3: Gamma\n\n**Files:**\n- Create: `c.py`\n\n**Verify:** `echo ok`\n\n"


def test_unchecked_tasks(tmp_path):
    text = UNCHECKED_PLAN + "## Checklist\n\n- [x] alpha | `echo ok`\n- [ ] beta | `echo ok`\n- [ ] gamma | `echo ok`\n"
    p = tmp_path / "plan.md"
    p.write_text(text)
    pf = PlanFile(p)
    result = pf.unchecked_tasks()
    assert len(result) == 2
    assert result[0].number == 2
    assert result[1].number == 3


def test_unchecked_tasks_all_done(tmp_path):
    text = UNCHECKED_PLAN + "## Checklist\n\n- [x] alpha | `echo ok`\n- [x] beta | `echo ok`\n- [x] gamma | `echo ok`\n"
    p = tmp_path / "plan.md"
    p.write_text(text)
    pf = PlanFile(p)
    assert pf.unchecked_tasks() == []


NON_CONTIGUOUS_PLAN = """\
# Test Plan
**Goal:** Test non-contiguous

## Tasks

""" + "### " + "Task 1: A\n\n**Files:**\n- Create: `a.py`\n\n**Verify:** `echo ok`\n\n---\n\n" + "### " + "Task 2: B\n\n**Files:**\n- Create: `b.py`\n\n**Verify:** `echo ok`\n\n---\n\n" + "### " + "Task 3: C\n\n**Files:**\n- Create: `c.py`\n\n**Verify:** `echo ok`\n\n---\n\n" + "### " + "Task 4: D\n\n**Files:**\n- Create: `d.py`\n\n**Verify:** `echo ok`\n\n---\n\n" + "### " + "Task 5: E\n\n**Files:**\n- Create: `e.py`\n\n**Verify:** `echo ok`\n\n"


def test_unchecked_tasks_non_contiguous(tmp_path):
    text = NON_CONTIGUOUS_PLAN + "## Checklist\n\n- [x] a | `echo ok`\n- [ ] b | `echo ok`\n- [x] c | `echo ok`\n- [ ] d | `echo ok`\n- [x] e | `echo ok`\n"
    p = tmp_path / "plan.md"
    p.write_text(text)
    pf = PlanFile(p)
    result = pf.unchecked_tasks()
    assert len(result) == 2
    assert result[0].number == 2
    assert result[1].number == 4


def test_counts_with_extra_whitespace(tmp_path):
    plan = "# Test\n## Checklist\n- [x] normal\n- [ ] normal\n  - [ ] indented\n  - [x] indented\n"
    p = tmp_path / "plan.md"
    p.write_text(plan)
    pf = PlanFile(p)
    assert pf.unchecked == 1


def test_counts_mixed_skip_states(tmp_path):
    plan = "# Test\n## Checklist\n- [x] done\n- [x] done\n- [ ] todo\n- [ ] todo\n- [ ] todo\n- [SKIP] skip\n"
    p = tmp_path / "plan.md"
    p.write_text(plan)
    pf = PlanFile(p)
    assert pf.checked == 2
    assert pf.unchecked == 3
    assert pf.skipped == 1
    assert pf.total == 5


def test_reload_after_external_modify(tmp_path):
    plan = "# Test\n## Checklist\n- [ ] one\n- [ ] two\n"
    p = tmp_path / "plan.md"
    p.write_text(plan)
    pf = PlanFile(p)
    assert pf.unchecked == 2
    p.write_text(plan.replace("- [ ] one", "- [x] one"))
    pf.reload()
    assert pf.unchecked == 1


def test_task_count_mismatch_more_checklist(tmp_path):
    plan = "# Test\n### Task 1: A\n**Files:**\n- Create: `a.py`\n### Task 2: B\n**Files:**\n- Create: `b.py`\n## Checklist\n- [ ] one\n- [ ] two\n- [ ] three\n- [ ] four\n"
    p = tmp_path / "plan.md"
    p.write_text(plan)
    pf = PlanFile(p)
    result = pf.unchecked_tasks()
    assert len(result) == 2


def test_task_count_mismatch_fewer_checklist(tmp_path):
    # All checklist items checked → no unchecked tasks, even if tasks > items
    plan = "# Test\n### Task 1: A\n**Files:**\n- Create: `a.py`\n### Task 2: B\n**Files:**\n- Create: `b.py`\n### Task 3: C\n**Files:**\n- Create: `c.py`\n### Task 4: D\n**Files:**\n- Create: `d.py`\n## Checklist\n- [x] one\n- [x] two\n"
    p = tmp_path / "plan.md"
    p.write_text(plan)
    pf = PlanFile(p)
    result = pf.unchecked_tasks()
    assert len(result) == 0


def test_checklist_with_skip_positional(tmp_path):
    plan = "# Test\n### Task 1: A\n**Files:**\n- Create: `a.py`\n### Task 2: B\n**Files:**\n- Create: `b.py`\n### Task 3: C\n**Files:**\n- Create: `c.py`\n### Task 4: D\n**Files:**\n- Create: `d.py`\n## Checklist\n- [x] one\n- [SKIP] two\n- [ ] three\n- [ ] four\n"
    p = tmp_path / "plan.md"
    p.write_text(plan)
    pf = PlanFile(p)
    result = pf.unchecked_tasks()
    assert len(result) == 2
    assert result[0].number == 3
    assert result[1].number == 4


def test_parse_tasks_malformed_header(tmp_path):
    plan = "# Test\n### Task 1: Good\n**Files:**\n- Create: `a.py`\n### BadTask no number\n**Files:**\n- Create: `bad.py`\n### Task 2: Good\n**Files:**\n- Create: `b.py`\n"
    p = tmp_path / "plan.md"
    p.write_text(plan)
    pf = PlanFile(p)
    tasks = pf.parse_tasks()
    assert len(tasks) == 2


def test_partial_task_parse(tmp_path):
    """Plan with 5 task headers but 2 malformed → parse_tasks() returns 3 valid tasks."""
    plan = (
        "# Test\n\n## Tasks\n\n"
        "### Task 1: Good One\n**Files:**\n- Create: `a.py`\n\n"
        "### Malformed no number\n**Files:**\n- Create: `bad1.py`\n\n"
        "### Task 2: Good Two\n**Files:**\n- Create: `b.py`\n\n"
        "### Also bad header\n**Files:**\n- Create: `bad2.py`\n\n"
        "### Task 3: Good Three\n**Files:**\n- Create: `c.py`\n\n"
        "## Checklist\n\n- [ ] one\n- [ ] two\n- [ ] three\n- [ ] four\n- [ ] five\n"
    )
    p = tmp_path / "plan.md"
    p.write_text(plan)
    pf = PlanFile(p)
    tasks = pf.parse_tasks()
    assert len(tasks) == 3
    assert tasks[0].name == "Good One"
    assert tasks[1].name == "Good Two"
    assert tasks[2].name == "Good Three"


def test_recompute_after_partial_completion(tmp_path):
    plan = """\
# Test Plan
**Goal:** Test batch recomputation after partial completion

## Tasks

### Task 1: Alpha
**Files:**
- Create: `a.py`
- Modify: `shared.py`

**Verify:** `echo ok`

---

### Task 2: Beta
**Files:**
- Create: `b.py`

**Verify:** `echo ok`

---

### Task 3: Gamma
**Files:**
- Modify: `shared.py`
- Create: `c.py`

**Verify:** `echo ok`

---

### Task 4: Delta
**Files:**
- Create: `d.py`

**Verify:** `echo ok`

## Checklist

- [x] alpha | `echo ok`
- [ ] beta | `echo ok`
- [ ] gamma | `echo ok`
- [ ] delta | `echo ok`
"""
    p = tmp_path / "plan.md"
    p.write_text(plan)
    pf = PlanFile(p)
    
    unchecked = pf.unchecked_tasks()
    assert len(unchecked) == 3
    assert unchecked[0].number == 2
    assert unchecked[1].number == 3
    assert unchecked[2].number == 4
    
    batches = build_batches(unchecked)
    assert len(batches) == 1
    assert batches[0].parallel == True
    assert len(batches[0].tasks) == 3


def test_truncated_plan(tmp_path):
    plan = "# Test\n## Checklist\n- [x] done one\n- [ ] todo two\n- ["
    p = tmp_path / "plan.md"
    p.write_text(plan)
    pf = PlanFile(p)
    assert pf.checked == 1
    assert pf.unchecked == 1  # third item truncated mid-prefix, regex won't match


def test_binary_content_in_plan(tmp_path):
    p = tmp_path / "plan.md"
    p.write_bytes(b"\x80\x81\x82\xff\xfe# Not valid UTF-8")
    with pytest.raises(UnicodeDecodeError):
        PlanFile(p)


def test_state_files_scoped_to_plan(tmp_path):
    plan = tmp_path / "2026-01-01-my-feature.md"
    plan.write_text("# Test\n## Checklist\n- [ ] item | `true`\n")
    pf = PlanFile(plan)
    assert pf.progress_path == tmp_path / "2026-01-01-my-feature.progress.md"
    assert pf.findings_path == tmp_path / "2026-01-01-my-feature.findings.md"


def test_concurrent_reload(tmp_path):
    p = tmp_path / "plan.md"
    p.write_text(SAMPLE_PLAN)
    pf = PlanFile(p)
    
    results = []
    
    def reader_thread():
        for _ in range(50):
            pf.reload()
            checked = pf.checked
            unchecked = pf.unchecked
            results.append((checked, unchecked))
            time.sleep(0.001)
    
    def writer_thread():
        for i in range(25):
            if i % 2 == 0:
                p.write_text(SAMPLE_PLAN.replace("- [ ] item two", "- [x] item two"))
            else:
                p.write_text(SAMPLE_PLAN)
            time.sleep(0.002)
    
    threads = []
    for _ in range(10):
        t = threading.Thread(target=reader_thread)
        threads.append(t)
    
    writer = threading.Thread(target=writer_thread)
    threads.append(writer)
    
    for t in threads:
        t.start()
    
    for t in threads:
        t.join()
    
    # Verify no crashes, exceptions, or negative values
    for checked, unchecked in results:
        assert checked >= 0
        assert unchecked >= 0