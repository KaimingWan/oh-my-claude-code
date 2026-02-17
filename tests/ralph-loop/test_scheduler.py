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