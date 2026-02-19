"""Batch scheduler — groups independent tasks for parallel execution."""
from dataclasses import dataclass, field
from scripts.lib.plan import TaskInfo


@dataclass
class Batch:
    tasks: list[TaskInfo] = field(default_factory=list)
    parallel: bool = False


def build_batches(tasks: list[TaskInfo], max_parallel: int = 4) -> list[Batch]:
    """Greedy algorithm: pick first remaining task, add all independent tasks (no file overlap) up to max_parallel.
    Single-task batches are marked parallel=False."""
    remaining = list(tasks)
    batches = []
    
    # Handle empty file sets first - put each in its own sequential batch
    empty_tasks = [t for t in remaining if not t.files]
    for t in empty_tasks:
        remaining.remove(t)
        batches.append(Batch(tasks=[t], parallel=False))
    
    while remaining:
        batch_tasks = [remaining.pop(0)]
        batch_files = set(batch_tasks[0].files)
        i = 0
        while i < len(remaining) and len(batch_tasks) < max_parallel:
            if not remaining[i].files & batch_files:
                t = remaining.pop(i)
                batch_tasks.append(t)
                batch_files |= t.files
            else:
                i += 1
        batches.append(Batch(tasks=batch_tasks, parallel=len(batch_tasks) > 1))
    return batches