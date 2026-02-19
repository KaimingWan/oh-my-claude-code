#!/usr/bin/env python3
"""ralph_loop.py — Kiro CLI wrapper with Ralph Loop discipline.

Keeps restarting Kiro until all checklist items in the active plan are checked off.
Usage: python3 scripts/ralph_loop.py [max_iterations]
"""
import atexit
import os
import signal
import subprocess
import sys
import threading
import time
from datetime import datetime
from pathlib import Path

# --- Resolve project root & imports ---
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))
os.chdir(PROJECT_ROOT)

from scripts.lib.plan import PlanFile
from scripts.lib.lock import LockFile
from scripts.lib.scheduler import build_batches, Batch
from scripts.lib.cli_detect import detect_cli
from scripts.lib.precheck import run_precheck

# --- Configuration from env ---
MAX_ITERATIONS = int(sys.argv[1]) if len(sys.argv) > 1 else 10
PLAN_POINTER = Path(os.environ.get("PLAN_POINTER_OVERRIDE", "docs/plans/.active"))
TASK_TIMEOUT = int(os.environ.get("RALPH_TASK_TIMEOUT", "1800"))
HEARTBEAT_INTERVAL = int(os.environ.get("RALPH_HEARTBEAT_INTERVAL", "60"))
KIRO_CMD = os.environ.get("RALPH_KIRO_CMD", "")
SKIP_DIRTY_CHECK = os.environ.get("RALPH_SKIP_DIRTY_CHECK", "")
SKIP_PRECHECK = os.environ.get("RALPH_SKIP_PRECHECK", "")
MAX_STALE = 3

LOG_FILE = Path(".ralph-loop.log")
LOCK = LockFile(Path(".ralph-loop.lock"))
SUMMARY_FILE = Path("docs/plans/.ralph-result")

_child_proc: subprocess.Popen | None = None


def die(msg: str) -> None:
    print(f"❌ {msg}")
    sys.exit(1)


# --- Recursion guard ---
if os.environ.get("_RALPH_LOOP_RUNNING"):
    die("Nested ralph loop detected — aborting to prevent recursion")
os.environ["_RALPH_LOOP_RUNNING"] = "1"


# --- Resolve active plan ---
if not PLAN_POINTER.exists():
    die("No active plan. Run @plan first to set docs/plans/.active")

plan_path = Path(PLAN_POINTER.read_text().strip())
if not plan_path.exists():
    die(f"Plan file not found: {plan_path}")

# --- Reject dirty working tree ---
if not SKIP_DIRTY_CHECK:
    r = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True)
    if r.stdout.strip():
        die("Dirty working tree. Commit or stash changes before running ralph-loop.")

# --- Verify checklist exists ---
plan = PlanFile(plan_path)
if plan.total == 0:
    die("Plan has no checklist items. Add a ## Checklist section first.")


# --- Signal handling + cleanup ---
def _cleanup_handler(signum=None, frame=None):
    if _child_proc is not None:
        try:
            os.killpg(os.getpgid(_child_proc.pid), signal.SIGTERM)
        except (ProcessLookupError, OSError):
            pass
    LOCK.release()
    sys.exit(1)

signal.signal(signal.SIGTERM, _cleanup_handler)
signal.signal(signal.SIGINT, _cleanup_handler)
atexit.register(LOCK.release)

LOCK.acquire()


# --- Heartbeat thread ---
def _heartbeat(proc: subprocess.Popen, iteration: int, stop_event: threading.Event):
    elapsed = 0
    while not stop_event.wait(HEARTBEAT_INTERVAL):
        if proc.poll() is not None:
            break
        elapsed += HEARTBEAT_INTERVAL
        plan.reload()
        ts = datetime.now().strftime("%H:%M:%S")
        print(f"💓 [{ts}] Iteration {iteration} — {plan.checked}/{plan.total} done (elapsed {elapsed}s)",
              flush=True)


# --- Summary writer ---
def write_summary(exit_code: int):
    plan.reload()
    status = "✅ SUCCESS" if exit_code == 0 else "❌ FAILED"
    lines = [
        "# Ralph Loop Result", "",
        f"- **Status:** {status} (exit {exit_code})",
        f"- **Plan:** {plan_path}",
        f"- **Completed:** {plan.checked}",
        f"- **Remaining:** {plan.unchecked}",
        f"- **Skipped:** {plan.skipped}",
        f"- **Finished at:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
    ]
    if plan.unchecked > 0:
        lines += ["", "## Remaining Items"] + plan.next_unchecked(50)
    summary = "\n".join(lines)
    SUMMARY_FILE.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY_FILE.write_text(summary)
    print(f"\n{'=' * 63}\n{summary}\n{'=' * 63}", flush=True)


# --- Build worker prompt ---
def build_worker_prompt(task_name: str, task_files: list, verify_cmd: str, plan_path: str) -> str:
    return f"""Task: {task_name}
Files: {', '.join(task_files)}
Verify: {verify_cmd}
Plan: {plan_path}

Do NOT modify docs/plans/
Do NOT run git commit"""


# --- Build prompt ---
def build_prompt(iteration: int, prev_exit: int = -1) -> str:
    plan.reload()
    progress_file = plan.progress_path
    findings_file = plan.findings_path
    next_items = "\n".join(plan.next_unchecked(5))

    if SKIP_PRECHECK:
        env_status = "⏭️ Precheck skipped"
    elif prev_exit == 0:
        env_status = "✅ Environment OK (cached — last iteration succeeded)"
    else:
        precheck_ok, precheck_out = run_precheck(PROJECT_ROOT)
        env_status = f"✅ Environment OK" if precheck_ok else f"❌ Environment FAILING:\n{precheck_out}"

    return f"""You are executing a plan. Read these files first:
1. Plan: {plan_path}
2. Progress log: {progress_file} (if exists — contains learnings from previous iterations)
3. Findings: {findings_file} (if exists — contains research discoveries and decisions)

Environment: {env_status}

Next unchecked items:
{next_items}

Rules:
1. Implement the FIRST unchecked item. Verify it works (run tests/typecheck).
2. Update the plan: change that item from '- [ ]' to '- [x]'.
3. Append to {progress_file} with format:
   ## Iteration {iteration} — $(date)
   - **Task:** <what you did>
   - **Files changed:** <list>
   - **Learnings:** <gotchas, patterns discovered>
   - **Status:** done / skipped
4. If you discover reusable patterns or make technical decisions, write to {findings_file}.
5. Commit: feat: <item description>.
6. Continue with next unchecked item. Do NOT stop while unchecked items remain.
7. If stuck after 3 attempts, change item to '- [SKIP] <reason>' and move to next.
8. If a command is blocked by a security hook, read the suggested alternative and retry with the safe command. If blocked 3+ times on the same item, mark it as '- [SKIP] blocked by security hook' and continue.
9. PARALLEL EXECUTION: If 2+ unchecked items have non-overlapping file sets (check the plan's Task Files: fields),
   dispatch executor subagents in parallel (max 4, agent_name: "executor").
   Subagents only implement + run verify. YOU handle: plan file updates, git commit, progress.md.
   If any subagent fails, fall back to sequential for that item. See Strategy D in planning SKILL.md."""


def build_init_prompt() -> str:
    """Generate the FIRST iteration prompt — verifies environment before implementing."""
    plan.reload()
    progress_file = plan.progress_path
    findings_file = plan.findings_path
    next_items = "\n".join(plan.next_unchecked(5))

    if SKIP_PRECHECK:
        env_status = "⏭️ Precheck skipped"
    else:
        precheck_ok, precheck_out = run_precheck(PROJECT_ROOT)
        env_status = f"✅ Environment OK" if precheck_ok else f"❌ Environment FAILING:\n{precheck_out}"

    return f"""You are executing a plan (FIRST iteration — environment setup and verification).

Read these files first:
1. Plan: {plan_path}
2. Progress log: {progress_file} (if exists — contains learnings from previous iterations)
3. Findings: {findings_file} (if exists — contains research discoveries and decisions)

Environment: {env_status}

This is the FIRST iteration. Before implementing anything:
1. Verify the environment is set up correctly (dependencies installed, tests runnable).
2. If environment is failing, fix it first before proceeding.
3. Then implement the FIRST unchecked item below.

Next unchecked items:
{next_items}

Rules:
1. Implement the FIRST unchecked item. Verify it works (run tests/typecheck).
2. Update the plan: change that item from '- [ ]' to '- [x]'.
3. Append to {progress_file} with format:
   ## Iteration 1 — $(date)
   - **Task:** <what you did>
   - **Files changed:** <list>
   - **Learnings:** <gotchas, patterns discovered>
   - **Status:** done / skipped
4. If you discover reusable patterns or make technical decisions, write to {findings_file}.
5. Commit: feat: <item description>.
6. Continue with next unchecked item. Do NOT stop while unchecked items remain.
7. If stuck after 3 attempts, change item to '- [SKIP] <reason>' and move to next.
8. If a command is blocked by a security hook, read the suggested alternative and retry with the safe command. If blocked 3+ times on the same item, mark it as '- [SKIP] blocked by security hook' and continue.
9. PARALLEL EXECUTION: If 2+ unchecked items have non-overlapping file sets (check the plan's Task Files: fields),
   dispatch executor subagents in parallel (max 4, agent_name: "executor").
   Subagents only implement + run verify. YOU handle: plan file updates, git commit, progress.md.
   If any subagent fails, fall back to sequential for that item. See Strategy D in planning SKILL.md."""


def build_batch_prompt(batch: Batch, plan_path_: Path, iteration: int) -> str:
    """Generate prompt for a batch of tasks."""
    plan = type('_plan', (), {
        'progress_path': plan_path_.parent / f"{plan_path_.stem}.progress.md",
        'findings_path': plan_path_.parent / f"{plan_path_.stem}.findings.md",
    })()
    progress_file = plan.progress_path
    findings_file = plan.findings_path

    if batch.parallel:
        task_lines = "\n".join(
            f"  - Task {t.number}: {t.name} (files: {', '.join(sorted(t.files))})"
            for t in batch.tasks
        )
        return f"""You are executing a plan in parallel mode. Read the plan first: {plan_path_}

Dispatch these tasks to executor subagents using use_subagent (agent_name: "executor"):
{task_lines}

Each subagent implements its task and runs the verify command from the plan.
You handle: plan checklist updates, git commit, {progress_file} updates.
If any subagent fails, fall back to sequential for that task.
Max parallel: {len(batch.tasks)}. See Strategy D in planning SKILL.md."""
    else:
        task = batch.tasks[0]
        return f"""You are executing a plan. Read these files first:
1. Plan: {plan_path_}
2. Progress log: {progress_file} (if exists)
3. Findings: {findings_file} (if exists)

Implement Task {task.number}: {task.name}
Files: {', '.join(sorted(task.files))}

Rules:
1. Implement the task. Verify it works (run the verify command from the plan).
2. Update the plan: change the corresponding checklist item from '- [ ]' to '- [x]'.
3. Append to {progress_file} with iteration {iteration} progress.
4. Commit: feat: <task description>."""


# --- Startup banner ---
plan.reload()
unchecked = plan.unchecked_tasks()
batches = build_batches(unchecked) if unchecked else []

if batches:
    print(f"🔄 Ralph Loop — {plan.unchecked} tasks remaining ({plan.checked}/{plan.total} done) | batch mode", flush=True)
    for idx, b in enumerate(batches, 1):
        task_names = ", ".join(f"T{t.number}" for t in b.tasks)
        mode = "⚡ parallel" if b.parallel else "📝 sequential"
        print(f"  Batch {idx}: {mode} [{task_names}]", flush=True)
else:
    print(f"🔄 Ralph Loop — {plan.unchecked} tasks remaining ({plan.checked}/{plan.total} done) | log: {LOG_FILE}",
          flush=True)
print(flush=True)

# --- Main loop ---
prev_checked = 0
stale_rounds = 0
final_exit = 1
prev_exit = -1  # -1 = no previous iteration; 0 = last CLI exited OK (precheck cacheable)

for i in range(1, MAX_ITERATIONS + 1):
    plan.reload()

    if plan.is_complete:
        print(f"\n✅ All {plan.checked} checklist items complete!", flush=True)
        final_exit = 0
        break

    # Circuit breaker
    if plan.checked <= prev_checked and i > 1:
        stale_rounds += 1
        print(f"⚠️  No progress this round ({stale_rounds}/{MAX_STALE} stale)", flush=True)
        if stale_rounds >= MAX_STALE:
            print(f"❌ Circuit breaker: {MAX_STALE} rounds with no progress. Stopping.", flush=True)
            for item in plan.next_unchecked(50):
                print(f"   {item}")
            break
    else:
        stale_rounds = 0
    prev_checked = plan.checked

    # Recompute batches from remaining unchecked tasks
    unchecked = plan.unchecked_tasks()
    batches = build_batches(unchecked) if unchecked else []

    print(f"{'=' * 63}", flush=True)
    if batches:
        current_batch = batches[0]
        mode = "⚡ parallel" if current_batch.parallel else "📝 sequential"
        names = ", ".join(f"T{t.number}" for t in current_batch.tasks)
        print(f" Iteration {i}/{MAX_ITERATIONS} — {plan.unchecked} remaining | Batch: {mode} [{names}]", flush=True)
    else:
        print(f" Iteration {i}/{MAX_ITERATIONS} — {plan.unchecked} remaining, {plan.checked} done", flush=True)
    print(f"{'=' * 63}", flush=True)

    # Use batch-aware prompt if batches available, otherwise fallback
    if batches:
        prompt = build_batch_prompt(batches[0], plan_path, i)
    elif i == 1 and plan.checked == 0:
        prompt = build_init_prompt()
    else:
        prompt = build_prompt(i, prev_exit=prev_exit)

    # Launch kiro-cli with process group isolation
    with LOG_FILE.open("a") as log_fd:
        base_cmd = detect_cli()
        if base_cmd[0] == 'claude':
            # claude -p <prompt> [flags...] — prompt is positional after -p
            cmd = [base_cmd[0], '-p', prompt] + base_cmd[2:]
        else:
            # kiro-cli chat ... <prompt> — prompt is last arg
            cmd = base_cmd + [prompt]

        proc = subprocess.Popen(
            cmd, stdout=log_fd, stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        _child_proc = proc

        stop_event = threading.Event()
        hb = threading.Thread(target=_heartbeat, args=(proc, i, stop_event), daemon=True)
        hb.start()

        try:
            proc.wait(timeout=TASK_TIMEOUT)
        except subprocess.TimeoutExpired:
            ts = datetime.now().strftime("%H:%M:%S")
            print(f"⏰ [{ts}] Iteration {i} timed out after {TASK_TIMEOUT}s — killing", flush=True)
            os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
                proc.wait()

        stop_event.set()
        hb.join(timeout=2)

    prev_exit = proc.returncode if proc.returncode is not None else 1

    # Early completion check — avoid wasting a full iteration
    plan.reload()
    if plan.is_complete:
        print(f"\n✅ All {plan.checked} checklist items complete!", flush=True)
        final_exit = 0
        break

else:
    plan.reload()
    if not plan.is_complete:
        print(f"\n⚠️ Reached max iterations ({MAX_ITERATIONS}). {plan.unchecked} items still unchecked.",
              flush=True)

write_summary(final_exit)
LOCK.release()
sys.exit(final_exit)
