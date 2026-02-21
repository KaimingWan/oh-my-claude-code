#!/usr/bin/env python3
"""ralph_loop.py — Kiro CLI wrapper with Ralph Loop discipline.

Keeps restarting Kiro until all checklist items in the active plan are checked off.
Usage: python3 scripts/ralph_loop.py [max_iterations]
"""
import atexit
import os
import re
import signal
import subprocess
import sys
import threading
import time
from datetime import datetime
from pathlib import Path

# --- Resolve project root & imports ---
_PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(_PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(_PROJECT_ROOT))

from scripts.lib.plan import PlanFile
from scripts.lib.lock import LockFile
from scripts.lib.cli_detect import detect_cli
from scripts.lib.precheck import run_precheck


def die(msg: str) -> None:
    print(f"❌ {msg}")
    sys.exit(1)


# --- Signal handling + cleanup ---
def make_cleanup_handler(child_proc_ref: list, lock: LockFile,
                         shutdown_flag: list = None):
    """Factory returning a cleanup handler that closes over mutable state.

    If shutdown_flag (single-element list) is provided, handler sets flag[0]=True
    instead of calling sys.exit, making it async-signal-safe.
    """
    def _cleanup_handler(signum=None, frame=None):
        cp = child_proc_ref[0]
        if cp is not None:
            try:
                os.killpg(os.getpgid(cp.pid), signal.SIGTERM)
            except (ProcessLookupError, OSError):
                pass
        if shutdown_flag is not None:
            shutdown_flag[0] = True
        else:
            lock.release()
            sys.exit(1)
    return _cleanup_handler


# --- Heartbeat thread ---
def _heartbeat(proc: subprocess.Popen, iteration: int, stop_event: threading.Event,
               plan: PlanFile, heartbeat_interval: int):
    elapsed = 0
    while not stop_event.wait(heartbeat_interval):
        if proc.poll() is not None:
            break
        elapsed += heartbeat_interval
        plan.reload()
        ts = datetime.now().strftime("%H:%M:%S")
        print(f"💓 [{ts}] Iteration {iteration} — {plan.checked}/{plan.total} done (elapsed {elapsed}s)",
              flush=True)


# --- Summary writer ---
def write_summary(exit_code: int, plan: PlanFile, plan_path: Path, summary_file: Path):
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
    summary_file.parent.mkdir(parents=True, exist_ok=True)
    summary_file.write_text(summary)
    print(f"\n{'=' * 63}\n{summary}\n{'=' * 63}", flush=True)


# --- Build prompt ---
def build_prompt(iteration: int, plan: PlanFile, plan_path: Path, project_root: Path,
                 skip_precheck: str = "", prev_exit: int = -1) -> str:
    plan.reload()
    progress_file = plan.progress_path
    findings_file = plan.findings_path
    next_items = "\n".join(plan.next_unchecked(5))

    if skip_precheck:
        env_status = "⏭️ Precheck skipped"
    elif prev_exit == 0:
        env_status = "✅ Environment OK (cached — last iteration succeeded)"
    else:
        precheck_ok, precheck_out = run_precheck(project_root)
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
"""


def build_init_prompt(plan: PlanFile, plan_path: Path, project_root: Path,
                      skip_precheck: str = "") -> str:
    """Generate the FIRST iteration prompt — verifies environment before implementing."""
    plan.reload()
    progress_file = plan.progress_path
    findings_file = plan.findings_path
    next_items = "\n".join(plan.next_unchecked(5))

    if skip_precheck:
        env_status = "⏭️ Precheck skipped"
    else:
        precheck_ok, precheck_out = run_precheck(project_root)
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
"""




from dataclasses import dataclass

@dataclass
class Config:
    max_iterations: int = 10
    task_timeout: int = 1800
    heartbeat_interval: int = 60
    skip_dirty_check: str = ""
    skip_precheck: str = ""
    plan_pointer: Path = None

    def __post_init__(self):
        if self.plan_pointer is None:
            self.plan_pointer = Path("docs/plans/.active")


def parse_config(argv: list[str] = None) -> Config:
    """Parse configuration from argv and environment variables."""
    argv = argv or []
    max_iter = int(argv[0]) if argv else 10
    return Config(
        max_iterations=max_iter,
        task_timeout=int(os.environ.get("RALPH_TASK_TIMEOUT", "1800")),
        heartbeat_interval=int(os.environ.get("RALPH_HEARTBEAT_INTERVAL", "60")),
        skip_dirty_check=os.environ.get("RALPH_SKIP_DIRTY_CHECK", ""),
        skip_precheck=os.environ.get("RALPH_SKIP_PRECHECK", ""),
        plan_pointer=Path(os.environ.get("PLAN_POINTER_OVERRIDE", "docs/plans/.active")),
    )


def validate_plan(plan_path: Path) -> PlanFile:
    """Validate plan file exists and has checklist items. Raises SystemExit on failure."""
    if not plan_path.exists():
        die(f"Plan file not found: {plan_path}")
    plan = PlanFile(plan_path)
    if plan.total == 0:
        die("Plan has no checklist items. Add a ## Checklist section first.")
    return plan


def main():
    PROJECT_ROOT = Path(__file__).resolve().parent.parent
    MAX_STALE = 3
    os.chdir(PROJECT_ROOT)

    # --- Configuration from env ---
    cfg = parse_config(sys.argv[1:])
    max_iterations = cfg.max_iterations
    plan_pointer = cfg.plan_pointer
    task_timeout = cfg.task_timeout
    heartbeat_interval = cfg.heartbeat_interval
    skip_dirty_check = cfg.skip_dirty_check
    skip_precheck = cfg.skip_precheck

    log_file = Path(".ralph-loop.log")
    lock = LockFile(Path(".ralph-loop.lock"))
    summary_file = Path("docs/plans/.ralph-result")

    child_proc_ref = [None]   # mutable single-element list for signal handler closure

    # --- Recursion guard ---
    if os.environ.get("_RALPH_LOOP_RUNNING"):
        die("Nested ralph loop detected — aborting to prevent recursion")
    os.environ["_RALPH_LOOP_RUNNING"] = "1"

    # --- Resolve active plan ---
    if not plan_pointer.exists():
        die("No active plan. Run @plan first to set docs/plans/.active")

    plan_path = Path(plan_pointer.read_text().strip())
    if not plan_path.exists():
        die(f"Plan file not found: {plan_path}")

    # --- Reject dirty working tree ---
    if not skip_dirty_check:
        r = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True)
        if r.stdout.strip():
            die("Dirty working tree. Commit or stash changes before running ralph-loop.")

    # --- Verify checklist exists ---
    plan = PlanFile(plan_path)
    if plan.total == 0:
        die("Plan has no checklist items. Add a ## Checklist section first.")

    # --- Signal handling + cleanup ---
    shutdown_flag = [False]
    _cleanup_handler = make_cleanup_handler(child_proc_ref, lock, shutdown_flag=shutdown_flag)
    signal.signal(signal.SIGTERM, _cleanup_handler)
    signal.signal(signal.SIGINT, _cleanup_handler)
    atexit.register(lock.release)

    if not lock.try_acquire():
        die("Another ralph-loop is already running (lock held)")

    # --- Startup banner ---
    plan.reload()
    print(f"🔄 Ralph Loop — {plan.unchecked} tasks remaining ({plan.checked}/{plan.total} done) | log: {log_file}",
          flush=True)
    print(flush=True)

    # --- Main loop ---
    prev_checked = 0
    stale_rounds = 0
    final_exit = 1
    prev_exit = -1  # -1 = no previous iteration; 0 = last CLI exited OK (precheck cacheable)

    for i in range(1, max_iterations + 1):
        plan.reload()

        if shutdown_flag[0]:
            break

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

        print(f"{'=' * 63}", flush=True)
        print(f" Iteration {i}/{max_iterations} — {plan.unchecked} remaining, {plan.checked} done", flush=True)
        print(f"{'=' * 63}", flush=True)

        # Build prompt
        if i == 1 and plan.checked == 0:
            prompt = build_init_prompt(plan, plan_path, PROJECT_ROOT, skip_precheck)
        else:
            prompt = build_prompt(i, plan, plan_path, PROJECT_ROOT, skip_precheck, prev_exit=prev_exit)

        if shutdown_flag[0]:
            break

        # Launch kiro-cli with process group isolation
        with log_file.open("a") as log_fd:
            base_cmd = detect_cli()
            if base_cmd[0] == 'claude':
                cmd = [base_cmd[0], '-p', prompt] + base_cmd[2:]
            else:
                cmd = base_cmd + [prompt]

            proc = subprocess.Popen(
                cmd, stdout=log_fd, stderr=subprocess.STDOUT,
                start_new_session=True,
            )
            child_proc_ref[0] = proc

            stop_event = threading.Event()
            hb = threading.Thread(
                target=_heartbeat,
                args=(proc, i, stop_event, plan, heartbeat_interval),
                daemon=True,
            )
            hb.start()

            try:
                proc.wait(timeout=task_timeout)
            except subprocess.TimeoutExpired:
                ts = datetime.now().strftime("%H:%M:%S")
                print(f"⏰ [{ts}] Iteration {i} timed out after {task_timeout}s — killing", flush=True)
                os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
                    proc.wait()

            stop_event.set()
            hb.join(timeout=2)

        prev_exit = proc.returncode if proc.returncode is not None else 1

        if shutdown_flag[0]:
            break

        # Early completion check — avoid wasting a full iteration
        plan.reload()
        if plan.is_complete:
            print(f"\n✅ All {plan.checked} checklist items complete!", flush=True)
            final_exit = 0
            break

    else:
        plan.reload()
        if not plan.is_complete:
            print(f"\n⚠️ Reached max iterations ({max_iterations}). {plan.unchecked} items still unchecked.",
                  flush=True)

    write_summary(final_exit, plan, plan_path, summary_file)
    lock.release()
    sys.exit(final_exit)


if __name__ == "__main__":
    main()
