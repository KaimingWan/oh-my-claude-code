import sys, os, subprocess, textwrap, time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

import pytest
from scripts.lib.lock import LockFile

# ---------------------------------------------------------------------------
# Existing tests (keep passing)
# ---------------------------------------------------------------------------

def test_acquire_release(tmp_path):
    lf = LockFile(tmp_path / ".lock")
    lf.acquire()
    assert lf.path.exists()
    assert lf.path.read_text().strip() == str(os.getpid())
    lf.release()
    assert not lf.path.exists()

def test_is_alive_current_process(tmp_path):
    lf = LockFile(tmp_path / ".lock")
    lf.acquire()
    assert lf.is_held_by_alive_process()
    lf.release()

def test_stale_lock_detected(tmp_path):
    lf = LockFile(tmp_path / ".lock")
    lf.path.write_text("999999999")
    assert not lf.is_held_by_alive_process()

def test_context_manager(tmp_path):
    lock_path = tmp_path / ".lock"
    with LockFile(lock_path) as lf:
        assert lock_path.exists()
    assert not lock_path.exists()

def test_concurrent_acquire(tmp_path):
    import threading
    lock_path = tmp_path / ".lock"
    results = []

    def acquire_lock():
        lf = LockFile(lock_path)
        lf.acquire()
        results.append(lf.path.read_text().strip())

    t1 = threading.Thread(target=acquire_lock)
    t2 = threading.Thread(target=acquire_lock)
    t1.start()
    t2.start()
    t1.join()
    t2.join()

    assert len(results) == 2
    assert lock_path.exists()
    assert lock_path.read_text().strip() in results

# ---------------------------------------------------------------------------
# New fcntl.flock tests
# ---------------------------------------------------------------------------

def _run_child(script: str, lock_path: Path, timeout: int = 5) -> subprocess.CompletedProcess:
    """Run a Python snippet in a subprocess that has LockFile available."""
    repo_root = str(Path(__file__).resolve().parent.parent.parent)
    full_script = textwrap.dedent(f"""
import sys
sys.path.insert(0, {repo_root!r})
from pathlib import Path
from scripts.lib.lock import LockFile
lock_path = Path({str(lock_path)!r})
{textwrap.dedent(script)}
""")
    return subprocess.run(
        [sys.executable, "-c", full_script],
        capture_output=True, text=True, timeout=timeout
    )


def test_flock_mutual_exclusion(tmp_path):
    """Two processes cannot hold the lock simultaneously."""
    lock_path = tmp_path / ".lock"

    # Parent acquires the lock
    lf = LockFile(lock_path)
    lf.acquire()
    try:
        # Child tries non-blocking acquire while parent holds
        result = _run_child("""
lf = LockFile(lock_path)
acquired = lf.try_acquire()
print("acquired:" + str(acquired))
sys.exit(0 if not acquired else 1)
""", lock_path)
        assert result.returncode == 0, (
            f"Child should have failed to acquire but got returncode={result.returncode}\n"
            f"stdout={result.stdout}\nstderr={result.stderr}"
        )
        assert "acquired:False" in result.stdout
    finally:
        lf.release()


def test_flock_release_allows_reacquire(tmp_path):
    """After releasing the lock, another process can acquire it."""
    lock_path = tmp_path / ".lock"

    lf = LockFile(lock_path)
    lf.acquire()
    lf.release()

    result = _run_child("""
lf = LockFile(lock_path)
acquired = lf.try_acquire()
print("acquired:" + str(acquired))
if acquired:
    lf.release()
sys.exit(0 if acquired else 1)
""", lock_path)
    assert result.returncode == 0, (
        f"Child should have acquired after release but got returncode={result.returncode}\n"
        f"stdout={result.stdout}\nstderr={result.stderr}"
    )
    assert "acquired:True" in result.stdout


def test_flock_context_manager(tmp_path):
    """Context manager acquires on enter and releases on exit."""
    lock_path = tmp_path / ".lock"

    # Acquire via context manager, then verify child can acquire after exit
    with LockFile(lock_path):
        assert lock_path.exists()
        # While held, child must fail
        result = _run_child("""
lf = LockFile(lock_path)
acquired = lf.try_acquire()
print("acquired:" + str(acquired))
sys.exit(0 if not acquired else 1)
""", lock_path)
        assert result.returncode == 0, "Child acquired lock while context manager held it"
        assert "acquired:False" in result.stdout

    # After context exit, child must succeed
    assert not lock_path.exists()
    result = _run_child("""
lf = LockFile(lock_path)
acquired = lf.try_acquire()
print("acquired:" + str(acquired))
if acquired:
    lf.release()
sys.exit(0 if acquired else 1)
""", lock_path)
    assert result.returncode == 0, "Child failed to acquire after context manager released"
    assert "acquired:True" in result.stdout


def test_release_idempotent(tmp_path):
    """Calling release multiple times must not raise."""
    lf = LockFile(tmp_path / ".lock")
    lf.acquire()
    lf.release()
    lf.release()  # second call must be safe
    lf.release()  # third call must be safe
