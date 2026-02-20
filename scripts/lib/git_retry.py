"""Git command runner with exponential backoff for transient lock errors."""
import subprocess
import time


def git_run(cmd: list[str], max_retries: int = 3, base_delay: float = 0.5, **kwargs) -> subprocess.CompletedProcess:
    """Run a git command, retrying on index.lock errors with exponential backoff.

    Args:
        cmd: Command list (e.g. ["git", "merge", "--squash", "branch"]).
        max_retries: Maximum retry attempts for transient errors.
        base_delay: Initial delay in seconds (doubles each retry).
        **kwargs: Passed to subprocess.run (e.g. cwd, capture_output).

    Returns:
        CompletedProcess on success.

    Raises:
        subprocess.CalledProcessError: After max_retries exhausted or on non-transient error.
    """
    kwargs.setdefault("check", True)
    kwargs.setdefault("capture_output", True)
    kwargs.setdefault("text", True)

    for attempt in range(max_retries + 1):
        try:
            return subprocess.run(cmd, **kwargs)
        except subprocess.CalledProcessError as e:
            stderr = (e.stderr or "") + (e.stdout or "")
            is_lock_error = "index.lock" in stderr or "Unable to create" in stderr
            if is_lock_error and attempt < max_retries:
                time.sleep(base_delay * (2 ** attempt))
                continue
            raise
