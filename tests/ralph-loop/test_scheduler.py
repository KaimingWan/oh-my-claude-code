import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

from scripts.lib.scheduler import build_batches
from scripts.lib.plan import TaskInfo


def make_task(num, files):
    return TaskInfo(number=num, name=f"Task {num}", files=set(files), section_text="")


def test_all_independent():
    tasks = [
        make_task(1, ["file1.py"]),
        make_task(2, ["file2.py"]),
        make_task(3, ["file3.py"])
    ]
    batches = build_batches(tasks)
    assert len(batches) == 1
    assert batches[0].parallel == True
    assert len(batches[0].tasks) == 3


def test_all_dependent():
    tasks = [
        make_task(1, ["shared.py"]),
        make_task(2, ["shared.py"]),
        make_task(3, ["shared.py"])
    ]
    batches = build_batches(tasks)
    assert len(batches) == 3
    for batch in batches:
        assert batch.parallel == False
        assert len(batch.tasks) == 1


def test_mixed_deps():
    tasks = [
        make_task(1, ["shared.py", "a.py"]),
        make_task(2, ["shared.py", "b.py"]),
        make_task(3, ["c.py"]),
        make_task(4, ["d.py"]),
    ]
    batches = build_batches(tasks)
    # Task 1 + Task 3 + Task 4 can be parallel (no overlap); Task 2 shares with Task 1
    assert any(b.parallel for b in batches)
    assert any(not b.parallel for b in batches)
    # All tasks accounted for
    all_tasks = [t for b in batches for t in b.tasks]
    assert len(all_tasks) == 4


def test_max_parallel_cap():
    tasks = [make_task(i, [f"file{i}.py"]) for i in range(6)]
    batches = build_batches(tasks, max_parallel=4)
    for b in batches:
        assert len(b.tasks) <= 4


def test_empty_tasks():
    assert build_batches([]) == []


def test_single_task():
    batches = build_batches([make_task(1, ["a.py"])])
    assert len(batches) == 1
    assert batches[0].parallel is False
    assert len(batches[0].tasks) == 1
