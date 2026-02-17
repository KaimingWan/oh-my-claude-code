import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

import pytest
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


@pytest.mark.parametrize("task_count,file_sets,max_parallel,expected_batch_count,expected_max_batch_size", [
    (1, [["a.py"]], 4, 1, 1),
    (4, [["a.py"], ["b.py"], ["c.py"], ["d.py"]], 4, 1, 4),
    (5, [["a.py"], ["b.py"], ["c.py"], ["d.py"], ["e.py"]], 4, 2, 4),
    (4, [["shared.py"], ["shared.py"], ["shared.py"], ["shared.py"]], 4, 4, 1),
    (4, [["x.py"], ["x.py"], ["y.py"], ["y.py"]], 4, 2, 2),
    (8, [["a.py"], ["b.py"], ["c.py"], ["d.py"], ["e.py"], ["f.py"], ["g.py"], ["h.py"]], 2, 4, 2),
    (4, [["a.py", "b.py"], ["b.py", "c.py"], ["c.py", "d.py"], ["d.py", "e.py"]], 4, 2, 2)
])
def test_batch_grouping_parametric(task_count, file_sets, max_parallel, expected_batch_count, expected_max_batch_size):
    tasks = [make_task(i, file_sets[i]) for i in range(task_count)]
    batches = build_batches(tasks, max_parallel)
    assert len(batches) == expected_batch_count
    assert max(len(b.tasks) for b in batches) <= expected_max_batch_size
    assert sum(len(b.tasks) for b in batches) == task_count


def test_batch_stability():
    tasks = [make_task(i, [f"file{i}.py"]) for i in range(4)]
    results = [build_batches(tasks) for _ in range(10)]
    first = results[0]
    for result in results[1:]:
        assert len(result) == len(first)
        for i, batch in enumerate(result):
            assert {t.number for t in batch.tasks} == {t.number for t in first[i].tasks}


def test_large_task_set():
    tasks = [make_task(i, [f"file{i}.py"]) for i in range(50)]
    batches = build_batches(tasks, max_parallel=4)
    assert all(len(b.tasks) <= 4 for b in batches)
    assert sum(len(b.tasks) for b in batches) == 50


def test_empty_file_sets():
    tasks = [make_task(i, []) for i in range(3)]
    batches = build_batches(tasks)
    assert len(batches) == 1
    assert len(batches[0].tasks) == 3

def test_rebatch_after_removal():
    tasks = [
        make_task(1, ["shared.py", "a.py"]),
        make_task(2, ["shared.py", "b.py"]),
        make_task(3, ["c.py"]),
        make_task(4, ["d.py"])
    ]
    
    initial_batches = build_batches(tasks)
    assert len(initial_batches) >= 2
    
    remaining_tasks = [tasks[1], tasks[2], tasks[3]]
    new_batches = build_batches(remaining_tasks)
    
    assert len(new_batches) == 1
    assert new_batches[0].parallel == True
    assert len(new_batches[0].tasks) == 3