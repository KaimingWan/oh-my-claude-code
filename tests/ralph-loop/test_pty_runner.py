"""Tests for scripts/lib/pty_runner.py — PTY-based unbuffered output capture."""
import time, os, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from scripts.lib.pty_runner import pty_run


def test_output_is_unbuffered(tmp_path):
    """PTY runner captures output line-by-line without waiting for process exit."""
    log = tmp_path / "out.log"
    # Python script that prints two lines with a sleep between them
    script = 'import time; print("line1"); time.sleep(1); print("line2")'
    proc, stop = pty_run(["python3", "-c", script], log)
    time.sleep(0.5)
    # line1 should already be in the log (unbuffered)
    assert "line1" in log.read_text()
    proc.wait()
    stop()
    assert "line2" in log.read_text()


def test_returncode_preserved(tmp_path):
    """Exit code from child process is preserved."""
    log = tmp_path / "out.log"
    proc, stop = pty_run(["python3", "-c", "import sys; sys.exit(42)"], log)
    proc.wait()
    stop()
    assert proc.returncode == 42


def test_process_group_isolation(tmp_path):
    """Child runs in its own process group (start_new_session=True)."""
    log = tmp_path / "out.log"
    proc, stop = pty_run(["python3", "-c", "import os; print(os.getpgid(0))"], log)
    proc.wait()
    stop()
    child_pgid = int(log.read_text().strip().split('\n')[0].strip())
    assert child_pgid != os.getpgid(0)
