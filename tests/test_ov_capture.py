"""Test that auto-capture and post-write index to OV when available."""
import json, os, socket, subprocess, threading, pytest
from pathlib import Path

PROJECT_ROOT = str(Path(__file__).resolve().parent.parent)
SOCKET_PATH = "/tmp/omcc-ov-test-capture.sock"

@pytest.fixture
def mock_ov_add():
    if os.path.exists(SOCKET_PATH):
        os.unlink(SOCKET_PATH)
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(SOCKET_PATH)
    srv.listen(5)
    captured = []
    def serve():
        for _ in range(5):
            try:
                conn, _ = srv.accept()
                data = json.loads(conn.recv(65536).decode())
                captured.append(data)
                conn.sendall(json.dumps({"ok": True}).encode())
                conn.close()
            except:
                break
    t = threading.Thread(target=serve, daemon=True)
    t.start()
    yield srv, captured
    srv.close()
    if os.path.exists(SOCKET_PATH):
        os.unlink(SOCKET_PATH)

def test_auto_capture_indexes_to_ov(mock_ov_add, tmp_path):
    """After writing to episodes.md, auto-capture also calls ov_add."""
    srv, captured = mock_ov_add
    episodes = tmp_path / "knowledge" / "episodes.md"
    episodes.parent.mkdir(parents=True)
    episodes.write_text("# Episodes\n")
    rules = tmp_path / "knowledge" / "rules.md"
    rules.write_text("")
    overlay = tmp_path / ".omcc-overlay.json"
    overlay.write_text(json.dumps({"knowledge_backend": "openviking"}))

    env = os.environ.copy()
    env["OV_SOCKET"] = SOCKET_PATH
    r = subprocess.run(
        ["bash", os.path.join(PROJECT_ROOT, "hooks/feedback/auto-capture.sh"),
         "must use StorageConfig never use direct VikingDB connection"],
        capture_output=True, text=True, env=env, cwd=str(tmp_path), timeout=10
    )
    # Episode should be written
    ep_content = episodes.read_text()
    assert "StorageConfig" in ep_content or "auto-captured" in r.stdout.lower()
    # OV should have received add_resource
    import time; time.sleep(0.3)
    ov_adds = [c for c in captured if c.get("cmd") == "add_resource"]
    assert len(ov_adds) >= 1

def test_post_write_indexes_findings(mock_ov_add, tmp_path):
    """When agent writes to a findings file, post-write indexes to OV."""
    srv, captured = mock_ov_add
    overlay = tmp_path / ".omcc-overlay.json"
    overlay.write_text(json.dumps({"knowledge_backend": "openviking"}))
    findings = tmp_path / "plan.findings.md"
    findings.write_text("## Findings\n- discovered pattern X")

    inp = json.dumps({
        "tool_name": "fs_write",
        "tool_input": {"file_path": str(findings)},
    })
    env = os.environ.copy()
    env["OV_SOCKET"] = SOCKET_PATH
    r = subprocess.run(
        ["bash", os.path.join(PROJECT_ROOT, "hooks/feedback/post-write.sh")],
        input=inp, capture_output=True, text=True, env=env, cwd=str(tmp_path), timeout=10
    )
    import time; time.sleep(0.3)
    ov_adds = [c for c in captured if c.get("cmd") == "add_resource"]
    assert len(ov_adds) >= 1
