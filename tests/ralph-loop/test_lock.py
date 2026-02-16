import sys, os
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

import pytest
from scripts.lib.lock import LockFile

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
