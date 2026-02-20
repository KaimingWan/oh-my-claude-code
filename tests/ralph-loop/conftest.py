import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from scripts.lib.plan import PlanFile


@pytest.fixture
def plan_factory(tmp_path):
    def factory(task_count=2, checked_pattern=None, skip_pattern=None, file_sets=None):
        if checked_pattern is None:
            checked_pattern = [False] * task_count
        if skip_pattern is None:
            skip_pattern = []
        if file_sets is None:
            file_sets = [{f"file{i}.txt"} for i in range(task_count)]

        plan_path = tmp_path / "plan.md"
        active_path = tmp_path / ".active"

        content = "# Plan\n\n## Tasks\n\n"
        for i in range(task_count):
            content += f"### Task {i+1}: Task_{i+1}\n\n"
            content += f"**Files:** {', '.join(file_sets[i])}\n\n"
            content += "**Verify:** `echo ok`\n\n"

        content += "## Checklist\n\n"
        for i in range(task_count):
            if i in skip_pattern:
                content += f"- [SKIP] Task {i+1}\n"
            elif checked_pattern[i]:
                content += f"- [x] Task {i+1}\n"
            else:
                content += f"- [ ] Task {i+1}\n"

        content += "\n## Errors\n\n| Task | Error |\n|------|-------|\n"

        plan_path.write_text(content)
        active_path.write_text(str(plan_path))

        return plan_path, active_path

    return factory


@pytest.fixture
def ralph_env(tmp_path):
    return {
        "PATH": os.environ.get("PATH", ""),
        "HOME": str(tmp_path),
        "PLAN_POINTER_OVERRIDE": str(tmp_path / ".active"),
        "RALPH_TASK_TIMEOUT": "5",
        "RALPH_HEARTBEAT_INTERVAL": "999",
        "RALPH_SKIP_DIRTY_CHECK": "1",
        "RALPH_SKIP_PRECHECK": "1",
    }