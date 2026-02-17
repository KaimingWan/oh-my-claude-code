"""Plan file parser — reads markdown checklist state."""
import re
from dataclasses import dataclass
from pathlib import Path

_CHECKED = re.compile(r"^- \[x\] ", re.MULTILINE)
_UNCHECKED = re.compile(r"^- \[ \] ", re.MULTILINE)
_SKIPPED = re.compile(r"^- \[SKIP\] ", re.MULTILINE)
_UNCHECKED_LINE = re.compile(r"^- \[ \] .*$", re.MULTILINE)


@dataclass
class TaskInfo:
    number: int
    name: str
    files: set[str]
    section_text: str


class PlanFile:
    def __init__(self, path: Path):
        self.path = path
        self._text = path.read_text() if path.exists() else ""

    def reload(self):
        self._text = self.path.read_text() if self.path.exists() else ""

    @property
    def checked(self) -> int:
        return len(_CHECKED.findall(self._text))

    @property
    def unchecked(self) -> int:
        return len(_UNCHECKED.findall(self._text))

    @property
    def skipped(self) -> int:
        return len(_SKIPPED.findall(self._text))

    @property
    def total(self) -> int:
        return self.checked + self.unchecked

    @property
    def is_complete(self) -> bool:
        return self.unchecked == 0

    def next_unchecked(self, n: int = 5) -> list[str]:
        return _UNCHECKED_LINE.findall(self._text)[:n]

    def parse_tasks(self) -> list[TaskInfo]:
        task_pattern = re.compile(r'^### Task (\d+): (.+)$', re.MULTILINE)
        file_pattern = re.compile(r'^- (?:Create|Modify|Test|Delete): `(.+?)`', re.MULTILINE)
        
        tasks = []
        matches = list(task_pattern.finditer(self._text))
        
        for i, match in enumerate(matches):
            number = int(match.group(1))
            name = match.group(2)
            start = match.start()
            
            # Find end of section (next task or ## header or end of text)
            if i + 1 < len(matches):
                end = matches[i + 1].start()
            else:
                next_section = re.search(r'^## ', self._text[start:], re.MULTILINE)
                end = start + next_section.start() if next_section else len(self._text)
            
            section_text = self._text[start:end]
            files = set(file_pattern.findall(section_text))
            
            tasks.append(TaskInfo(number, name, files, section_text))
        
        return tasks
