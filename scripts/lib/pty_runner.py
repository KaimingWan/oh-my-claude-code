"""PTY-based subprocess runner for unbuffered output capture."""
import os
import pty
import subprocess
import threading
from pathlib import Path


def pty_run(cmd: list[str], log_path: Path) -> tuple[subprocess.Popen, callable]:
    """Launch cmd with stdout/stderr on a PTY, tee output to log_path.

    Returns (proc, stop_fn). Call stop_fn() after proc.wait() to join reader thread.
    """
    master, slave = pty.openpty()
    proc = subprocess.Popen(
        cmd, stdout=slave, stderr=subprocess.STDOUT,
        start_new_session=True, close_fds=True,
    )
    os.close(slave)

    stop_event = threading.Event()

    def _reader():
        with open(log_path, "ab") as f:
            while not stop_event.is_set():
                try:
                    data = os.read(master, 4096)
                    if not data:
                        break
                    f.write(data)
                    f.flush()
                except OSError:
                    break
        try:
            os.close(master)
        except OSError:
            pass

    t = threading.Thread(target=_reader, daemon=True)
    t.start()

    def stop():
        stop_event.set()
        t.join(timeout=2)

    return proc, stop
