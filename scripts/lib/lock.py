"""PID lock file — signals to hooks that ralph-loop is active."""
import os
from pathlib import Path


class LockFile:
    def __init__(self, path: Path):
        self.path = path

    def acquire(self):
        self.path.write_text(str(os.getpid()))

    def release(self):
        try:
            self.path.unlink()
        except FileNotFoundError:
            pass

    def is_held_by_alive_process(self) -> bool:
        if not self.path.exists():
            return False
        try:
            pid = int(self.path.read_text().strip())
            os.kill(pid, 0)
            return True
        except (ValueError, ProcessLookupError, PermissionError):
            return False

    def __enter__(self):
        self.acquire()
        return self

    def __exit__(self, *_):
        self.release()
