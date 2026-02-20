"""PID lock file — uses fcntl.flock for true OS-level mutual exclusion."""
import fcntl
import os
from pathlib import Path


class LockFile:
    def __init__(self, path: Path):
        self.path = path
        self._fd = None

    def acquire(self):
        """Blocking exclusive lock. Writes PID after acquiring."""
        self._fd = open(self.path, "w")
        fcntl.flock(self._fd, fcntl.LOCK_EX)
        self._fd.write(str(os.getpid()))
        self._fd.flush()

    def try_acquire(self) -> bool:
        """Non-blocking exclusive lock attempt.

        Returns True if acquired, False if another process holds the lock.
        Must call release() after a successful try_acquire().
        """
        fd = open(self.path, "w")
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            fd.write(str(os.getpid()))
            fd.flush()
            self._fd = fd
            return True
        except BlockingIOError:
            fd.close()
            return False

    def release(self):
        """Release the lock. Idempotent — safe to call multiple times."""
        if self._fd is None:
            return
        try:
            fcntl.flock(self._fd, fcntl.LOCK_UN)
        except Exception:
            pass
        try:
            self._fd.close()
        except Exception:
            pass
        self._fd = None
        try:
            self.path.unlink()
        except FileNotFoundError:
            pass

    def is_held_by_alive_process(self) -> bool:
        """Check if the lock file contains a PID of a live process."""
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
