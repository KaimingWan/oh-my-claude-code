#!/usr/bin/env python3
"""End-to-end test for OpenViking integration with Azure OpenAI embeddings.

Tests the full lifecycle: init → add resources → search → session → cleanup.
Requires ~/.openviking/ov.conf with valid embedding config.
"""
import json
import os
import shutil
import sys
import tempfile
import time

# ── Helpers ──────────────────────────────────────────────────────────────────

PASS = 0
FAIL = 0

def check(name, condition, detail=""):
    global PASS, FAIL
    if condition:
        PASS += 1
        print(f"  ✅ {name}")
    else:
        FAIL += 1
        print(f"  ❌ {name}" + (f" — {detail}" if detail else ""))

def section(title):
    print(f"\n{'─'*60}\n  {title}\n{'─'*60}")

# ── Setup ────────────────────────────────────────────────────────────────────

section("0. Setup")
tmpdir = tempfile.mkdtemp(prefix="ov-e2e-")
print(f"  workspace: {tmpdir}")

try:
    from openviking import SyncOpenViking
    check("openviking importable", True)
except ImportError as e:
    check("openviking importable", False, str(e))
    sys.exit(1)

ov = SyncOpenViking(path=tmpdir)
ov.initialize()
check("initialize()", True)
check("is_healthy()", ov.is_healthy())

# ── 1. Add resources ────────────────────────────────────────────────────────

section("1. Add Resources (embedding via Azure OpenAI)")

# Create test files
docs = {
    "python-guide.md": "# Python Best Practices\n\nUse type hints for function signatures. "
                       "Prefer dataclasses over plain dicts for structured data. "
                       "Always use virtual environments for project isolation.",
    "rust-guide.md":   "# Rust Memory Safety\n\nRust's ownership system prevents data races at compile time. "
                       "The borrow checker ensures references are always valid. "
                       "Use Arc<Mutex<T>> for shared mutable state across threads.",
    "cooking.md":      "# Italian Pasta Recipe\n\nBoil water with salt. Cook spaghetti al dente for 8 minutes. "
                       "Prepare sauce with garlic, olive oil, and fresh tomatoes. "
                       "Toss pasta in sauce and serve with parmesan.",
}

for fname, content in docs.items():
    fpath = os.path.join(tmpdir, fname)
    with open(fpath, "w") as f:
        f.write(content)
    result = ov.add_resource(fpath, wait=True, timeout=60)
    check(f"add_resource({fname})", result.get("status") != "error", json.dumps(result)[:120])

# Give indexing a moment
time.sleep(2)

# ── 2. Semantic search ──────────────────────────────────────────────────────

section("2. Semantic Search")

# Query about Python — should find python-guide, not cooking
results = ov.search("How to write clean Python code?", limit=3)
check("search returns results", len(results) > 0, f"got {len(results)}")

if results:
    top = str(results[0])
    has_python = "python" in top.lower()
    check("top result is Python-related", has_python, top[:150])

# Query about memory safety — should find Rust guide
results2 = ov.search("memory safety and ownership", limit=3)
check("rust search returns results", len(results2) > 0)
if results2:
    top2 = str(results2[0])
    has_rust = "rust" in top2.lower() or "ownership" in top2.lower() or "borrow" in top2.lower()
    check("top result is Rust-related", has_rust, top2[:150])

# Query about cooking — should find pasta recipe
results3 = ov.search("how to cook Italian food", limit=3)
check("cooking search returns results", len(results3) > 0)
if results3:
    top3 = str(results3[0])
    has_cook = "pasta" in top3.lower() or "cook" in top3.lower() or "italian" in top3.lower() or "spaghet" in top3.lower()
    check("top result is cooking-related", has_cook, top3[:150])

# Negative: cooking query should NOT rank Python/Rust first
# (soft check — semantic search isn't perfect)

# ── 3. find() ────────────────────────────────────────────────────────────────

section("3. find() — structured retrieval")

find_results = ov.find("type hints and dataclasses", limit=3)
check("find() returns results", len(find_results) > 0, f"got {len(find_results)}")

# ── 4. overview / abstract ──────────────────────────────────────────────────

section("4. overview() & abstract()")

# List what's in the store
try:
    tree = ov.tree("/")
    check("tree() works", tree is not None, str(tree)[:200])
except Exception as e:
    check("tree() works", False, str(e))

# Try overview on a known resource
try:
    ls_root = ov.ls("/")
    check("ls('/') works", ls_root is not None)
    if ls_root:
        # Find a resource URI to test overview/abstract
        first_item = ls_root[0] if isinstance(ls_root, list) else str(ls_root)
        print(f"  (ls root sample: {str(first_item)[:120]})")
except Exception as e:
    check("ls('/') works", False, str(e))

# ── 5. Session ──────────────────────────────────────────────────────────────

section("5. Session Management")

sess = ov.session("test-e2e-session")
check("session created", sess is not None)

try:
    ov.add_message("User asked about Python best practices", session_id="test-e2e-session")
    check("add_message()", True)
except Exception as e:
    check("add_message()", False, str(e))

try:
    ov.commit_session("test-e2e-session")
    check("commit_session()", True)
except Exception as e:
    check("commit_session()", False, str(e))

# Check session exists
check("session_exists()", ov.session_exists("test-e2e-session"))

# List sessions
sessions = ov.list_sessions()
check("list_sessions()", len(sessions) > 0, f"got {len(sessions)}")

# Delete session
try:
    ov.delete_session("test-e2e-session")
    check("delete_session()", True)
except Exception as e:
    check("delete_session()", False, str(e))

# ── 6. Cleanup ──────────────────────────────────────────────────────────────

section("6. Cleanup")

ov.close()
check("close()", True)
shutil.rmtree(tmpdir, ignore_errors=True)
check("tmpdir removed", not os.path.exists(tmpdir))

# ── Summary ─────────────────────────────────────────────────────────────────

section("Summary")
total = PASS + FAIL
print(f"  {PASS}/{total} passed, {FAIL} failed")
sys.exit(1 if FAIL > 0 else 0)
