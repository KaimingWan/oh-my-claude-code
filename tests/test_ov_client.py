"""Unit tests for ov-init.sh Python socket client (no socat dependency)."""
import json, os, socket, threading, pytest
from pathlib import Path

SOCKET_PATH = "/tmp/omcc-ov-test.sock"

@pytest.fixture
def mock_ov_server():
    if os.path.exists(SOCKET_PATH):
        os.unlink(SOCKET_PATH)
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(SOCKET_PATH)
    srv.listen(1)
    responses = []
    def serve():
        conn, _ = srv.accept()
        data = json.loads(conn.recv(65536).decode())
        responses.append(data)
        if data["cmd"] == "health":
            conn.sendall(json.dumps({"ok": True}).encode())
        elif data["cmd"] == "search":
            conn.sendall(json.dumps({"ok": True, "results": ["test result"]}).encode())
        elif data["cmd"] == "add_resource":
            conn.sendall(json.dumps({"ok": True}).encode())
        conn.close()
    t = threading.Thread(target=serve, daemon=True)
    t.start()
    yield srv, responses
    srv.close()
    if os.path.exists(SOCKET_PATH):
        os.unlink(SOCKET_PATH)

def test_ov_call_no_socat(mock_ov_server):
    srv, responses = mock_ov_server
    import subprocess
    r = subprocess.run(
        ["bash", "-c", f'source hooks/_lib/ov-init.sh; OV_SOCKET={SOCKET_PATH}; ov_call \'{{"cmd":"health"}}\''],
        capture_output=True, text=True, timeout=5
    )
    assert '"ok"' in r.stdout
    assert responses[0]["cmd"] == "health"

def test_ov_init_sh_no_socat():
    content = Path("hooks/_lib/ov-init.sh").read_text()
    assert "socat" not in content

def test_validate_no_socat_warning():
    content = Path("tools/validate-project.sh").read_text()
    assert "socat" not in content

def test_daemon_has_storage_config():
    content = Path("scripts/ov-daemon.py").read_text()
    assert "StorageConfig" in content

def test_daemon_uses_large_model():
    content = Path("scripts/ov-daemon.py").read_text()
    assert "text-embedding-3-large" in content
    assert "text-embedding-3-small" not in content
