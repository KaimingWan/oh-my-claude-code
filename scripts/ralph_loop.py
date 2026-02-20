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
from scripts.lib.scheduler import build_batches, Batch
from scripts.lib.cli_detect import detect_cli
from scripts.lib.precheck import run_precheck
from scripts.lib.worktree import WorktreeManager


def die(msg: str) -> None:
    print(f"❌ {msg}")
    sys.exit(1)


# --- Signal handling + cleanup ---
def make_cleanup_handler(child_proc_ref: list, child_procs: list, worker_pgids: dict,
                         wt_manager: WorktreeManager, lock: LockFile):
    """Factory returning a cleanup handler that closes over mutable state.

    worker_pgids: dict mapping pid -> pgid for all spawned parallel workers.
    This set is NOT cleared when child_procs is cleaned up, so the handler
    can kill process groups even after workers have been removed from child_procs.
    """
    def _cleanup_handler(signum=None, frame=None):
        # Kill singular child proc (sequential mode)
        cp = child_proc_ref[0]
        if cp is not None:
            try:
                os.killpg(os.getpgid(cp.pid), signal.SIGTERM)
            except (ProcessLookupError, OSError):
                pass
        # Kill all parallel worker procs still in child_procs
        for p in list(child_procs):
            try:
                os.killpg(os.getpgid(p.pid), signal.SIGTERM)
            except (ProcessLookupError, OSError):
                pass
        # Kill any remaining worker process groups tracked by pid->pgid.
        # This handles the case where child_procs was already cleared (workers
        # completed normally) but ralph is SIGTERMed before worktree cleanup.
        for pid, pgid in list(worker_pgids.items()):
            try:
                # Validate the PID still refers to the same process group
                if os.getpgid(pid) == pgid:
                    os.killpg(pgid, signal.SIGTERM)
            except (ProcessLookupError, OSError):
                pass
        # Cleanup any orphaned worktrees
        try:
            wt_manager.cleanup_stale()
        except Exception:
            pass
        lock.release()
        sys.exit(1)
    return _cleanup_handler


# --- Heartbeat thread ---
def _heartbeat(proc: subprocess.Popen, iteration: int, stop_event: threading.Event,
               plan: PlanFile, heartbeat_interval: int, stall_timeout: int):
    elapsed = 0
    stall_elapsed = 0
    last_checked = -1
    while not stop_event.wait(heartbeat_interval):
        if proc.poll() is not None:
            break
        elapsed += heartbeat_interval
        plan.reload()
        ts = datetime.now().strftime("%H:%M:%S")
        print(f"💓 [{ts}] Iteration {iteration} — {plan.checked}/{plan.total} done (elapsed {elapsed}s)",
              flush=True)
        if plan.checked == last_checked:
            stall_elapsed += heartbeat_interval
            if stall_elapsed >= stall_timeout:
                print(f"🛑 [{ts}] Stall detected: no progress for {stall_elapsed}s — killing process",
                      flush=True)
                try:
                    os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
                except (ProcessLookupError, OSError):
                    pass
                break
        else:
            stall_elapsed = 0
            last_checked = plan.checked


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


# --- Build worker prompt ---
def _extract_verify_cmd(section_text: str) -> str:
    """Extract verify command from task section. Supports inline backtick and fenced code block."""
    # Try inline: **Verify:** `cmd`
    m = re.search(r'\*\*Verify:\*\*\s*`([^`]+)`', section_text)
    if m:
        return m.group(1)
    # Try fenced: **Verify:**\n```bash\ncmd\n```
    m = re.search(r'\*\*Verify:\*\*\s*\n```(?:bash)?\n(.+?)\n```', section_text, re.DOTALL)
    if m:
        return m.group(1).strip()
    return "false"


def build_worker_prompt(task_name: str, task_files: list, verify_cmd: str, plan_path: str,
                        checklist_context: str = "") -> str:
    ctx = f"\n\nChecklist state:\n{checklist_context}" if checklist_context else ""
    return f"""Task: {task_name}
Files: {', '.join(task_files)}
Verify: {verify_cmd}
Plan: {plan_path}{ctx}

Do NOT modify docs/plans/
Commit your changes with: git commit -am 'feat: {task_name}'"""


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
9. PARALLEL EXECUTION: If 2+ unchecked items have non-overlapping file sets (check the plan's Task Files: fields),
   dispatch executor subagents in parallel (max 4, agent_name: "executor").
   Subagents only implement + run verify. YOU handle: plan file updates, git commit, progress.md.
   If any subagent fails, fall back to sequential for that item. See Strategy D in planning SKILL.md."""


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
9. PARALLEL EXECUTION: If 2+ unchecked items have non-overlapping file sets (check the plan's Task Files: fields),
   dispatch executor subagents in parallel (max 4, agent_name: "executor").
   Subagents only implement + run verify. YOU handle: plan file updates, git commit, progress.md.
   If any subagent fails, fall back to sequential for that item. See Strategy D in planning SKILL.md."""


def build_batch_prompt(batch: Batch, plan_path_: Path, iteration: int, plan: PlanFile = None) -> str:
    """Generate prompt for a batch of tasks."""
    if plan is not None:
        progress_file = plan.progress_path
        findings_file = plan.findings_path
    else:
        progress_file = plan_path_.parent / f"{plan_path_.stem}.progress.md"
        findings_file = plan_path_.parent / f"{plan_path_.stem}.findings.md"

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


# --- Parallel batch executor ---
def run_parallel_batch(batch: Batch, iteration: int, plan: PlanFile, plan_path: Path,
                       project_root: Path, wt_manager: WorktreeManager,
                       child_procs: list, worker_pgids: dict, worker_log_dir: Path,
                       task_timeout: int, max_parallel_workers: int = 4) -> list[str]:
    """Spawn N worker CLI processes in isolated worktrees, wait, merge successful ones.

    Returns list of worker names that succeeded (exit 0).
    """
    worker_log_dir.mkdir(exist_ok=True)
    workers = []  # list of (name, worktree_path, proc, log_path)

    base_cmd = detect_cli()

    checklist_ctx = f"Completed: {plan.checked}/{plan.total}.\nRemaining items:\n" + "\n".join(
        plan.next_unchecked(20)
    )

    for task in batch.tasks[:max_parallel_workers]:
        name = f"w{task.number}-i{iteration}"
        try:
            wt_path = wt_manager.create(name)
        except subprocess.CalledProcessError as e:
            print(f"⚠️  Failed to create worktree for task {task.number}: {e}", flush=True)
            continue

        # Extract verify command from section_text (inline backtick or fenced code block)
        verify_cmd = _extract_verify_cmd(task.section_text)
        prompt = build_worker_prompt(task.name, sorted(task.files), verify_cmd, str(plan_path),
                                     checklist_context=checklist_ctx)
        if base_cmd[0] == "claude":
            cmd = [base_cmd[0], "-p", prompt] + base_cmd[2:]
        else:
            cmd = base_cmd + [prompt]

        log_path = worker_log_dir / f"worker-{name}.log"
        log_fd = open(log_path, "w")
        try:
            proc = subprocess.Popen(
            cmd,
            stdout=log_fd,
            stderr=subprocess.STDOUT,
            start_new_session=True,
            cwd=str(wt_path),
            env={**os.environ, "_RALPH_LOOP_RUNNING": "1"},
        )
        except Exception:
            log_fd.close()
            print(f"⚠️  Failed to start worker for task {task.number}", flush=True)
            continue
        child_procs.append(proc)
        # Record pid->pgid immediately after spawn; workers use start_new_session=True
        # so each has its own process group. This allows cleanup even after child_procs
        # is cleared (e.g. if ralph receives SIGTERM during the merge phase).
        try:
            pgid = os.getpgid(proc.pid)
            worker_pgids[proc.pid] = pgid
        except (ProcessLookupError, OSError):
            pass
        workers.append((name, wt_path, proc, log_fd))
        print(f"  🚀 Worker {name}: task '{task.name}' → {wt_path.name}", flush=True)

    succeeded = []
    for name, wt_path, proc, log_fd in workers:
        try:
            proc.wait(timeout=task_timeout)
        except subprocess.TimeoutExpired:
            ts = datetime.now().strftime("%H:%M:%S")
            print(f"  ⏰ [{ts}] Worker {name} timed out — killing", flush=True)
            try:
                os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
                proc.wait(timeout=5)
            except (subprocess.TimeoutExpired, ProcessLookupError, OSError):
                try:
                    os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
                    proc.wait()
                except (ProcessLookupError, OSError):
                    pass
        finally:
            log_fd.close()
        if proc.returncode == 0:
            succeeded.append(name)
            print(f"  ✅ Worker {name} succeeded", flush=True)
        else:
            print(f"  ❌ Worker {name} failed (exit {proc.returncode})", flush=True)

    # Remove from child_procs tracking
    finished_procs = {p for _, _, p, _ in workers}
    child_procs[:] = [p for p in child_procs if p not in finished_procs or p.poll() is None]

    # Merge successful workers into main branch
    for name in list(succeeded):
        ok = wt_manager.merge(name)
        if ok:
            print(f"  🔀 Merged worker {name}", flush=True)
        else:
            print(f"  ⚠️  Merge conflict for worker {name} — skipping", flush=True)
            succeeded.remove(name)

    # After all merges, verify and check off all passing checklist items
    if succeeded:
        plan.reload()
        results = plan.verify_and_check_all(cwd=str(project_root))
        for idx, vcmd, passed in results:
            if passed:
                print(f"  ✅ Checklist item {idx} verified & checked off", flush=True)
            else:
                print(f"  ⚠️  Checklist item {idx} verify failed: {vcmd}", flush=True)
        # Commit the checked-off plan so subsequent merges don't overwrite it
        checked_count = sum(1 for _, _, p in results if p)
        if checked_count > 0:
            subprocess.run(["git", "add", str(plan.path)], cwd=str(project_root), capture_output=True)
            subprocess.run(["git", "commit", "-m", f"chore: update checklist (iteration {iteration})"],
                           cwd=str(project_root), capture_output=True)

    # Cleanup all worktrees and clear their pgid tracking entries
    for name, _, proc, _ in workers:
        try:
            wt_manager.remove(name)
        except Exception:
            pass
        worker_pgids.pop(proc.pid, None)

    return succeeded


from dataclasses import dataclass

@dataclass
class Config:
    max_iterations: int = 10
    task_timeout: int = 1800
    heartbeat_interval: int = 60
    stall_timeout: int = 300
    skip_dirty_check: str = ""
    skip_precheck: str = ""
    max_parallel_workers: int = 4
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
        stall_timeout=int(os.environ.get("RALPH_STALL_TIMEOUT", "300")),
        skip_dirty_check=os.environ.get("RALPH_SKIP_DIRTY_CHECK", ""),
        skip_precheck=os.environ.get("RALPH_SKIP_PRECHECK", ""),
        max_parallel_workers=int(os.environ.get("RALPH_MAX_PARALLEL_WORKERS", "4")),
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
    max_iterations = int(sys.argv[1]) if len(sys.argv) > 1 else 10
    plan_pointer = Path(os.environ.get("PLAN_POINTER_OVERRIDE", "docs/plans/.active"))
    task_timeout = int(os.environ.get("RALPH_TASK_TIMEOUT", "1800"))
    heartbeat_interval = int(os.environ.get("RALPH_HEARTBEAT_INTERVAL", "60"))
    stall_timeout = int(os.environ.get("RALPH_STALL_TIMEOUT", "300"))
    skip_dirty_check = os.environ.get("RALPH_SKIP_DIRTY_CHECK", "")
    skip_precheck = os.environ.get("RALPH_SKIP_PRECHECK", "")
    max_parallel_workers = int(os.environ.get("RALPH_MAX_PARALLEL_WORKERS", "4"))

    log_file = Path(".ralph-loop.log")
    lock = LockFile(Path(".ralph-loop.lock"))
    summary_file = Path("docs/plans/.ralph-result")
    worker_log_dir = Path(".ralph-logs")

    child_proc_ref = [None]   # mutable single-element list for signal handler closure
    child_procs: list[subprocess.Popen] = []
    worker_pgids: dict[int, int] = {}  # pid -> pgid for all spawned parallel workers
    wt_manager = WorktreeManager()

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
    _cleanup_handler = make_cleanup_handler(child_proc_ref, child_procs, worker_pgids, wt_manager, lock)
    signal.signal(signal.SIGTERM, _cleanup_handler)
    signal.signal(signal.SIGINT, _cleanup_handler)
    atexit.register(lock.release)

    if not lock.try_acquire():
        die("Another ralph-loop is already running (lock held)")

    # --- Startup: remove stale worktrees from previous runs ---
    try:
        wt_manager.cleanup_stale()
    except Exception:
        pass

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
            print(f" Iteration {i}/{max_iterations} — {plan.unchecked} remaining | Batch: {mode} [{names}]", flush=True)
        else:
            print(f" Iteration {i}/{max_iterations} — {plan.unchecked} remaining, {plan.checked} done", flush=True)
        print(f"{'=' * 63}", flush=True)

        # Route: parallel batch → worktree workers; sequential/fallback → single CLI
        if batches and batches[0].parallel:
            current_batch = batches[0]
            names = ", ".join(f"T{t.number}" for t in current_batch.tasks)
            print(f"  ⚡ Launching parallel worktree workers: [{names}]", flush=True)
            succeeded = run_parallel_batch(
                current_batch, i, plan, plan_path, PROJECT_ROOT,
                wt_manager, child_procs, worker_pgids, worker_log_dir, task_timeout,
                max_parallel_workers=max_parallel_workers,
            )
            prev_exit = 0 if succeeded else 1
        else:
            # Build prompt for sequential/fallback mode
            if batches:
                prompt = build_batch_prompt(batches[0], plan_path, i)
            elif i == 1 and plan.checked == 0:
                prompt = build_init_prompt(plan, plan_path, PROJECT_ROOT, skip_precheck)
            else:
                prompt = build_prompt(i, plan, plan_path, PROJECT_ROOT, skip_precheck, prev_exit=prev_exit)

            # Launch kiro-cli with process group isolation
            with log_file.open("a") as log_fd:
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
                child_proc_ref[0] = proc

                stop_event = threading.Event()
                hb = threading.Thread(
                    target=_heartbeat,
                    args=(proc, i, stop_event, plan, heartbeat_interval, stall_timeout),
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
