"""CLI auto-detection for ralph loop."""
import os
import signal
import shutil
import subprocess
import sys


def detect_cli() -> list[str]:
    """Detect available CLI: env override > claude > kiro-cli."""
    env_cmd = os.environ.get('RALPH_KIRO_CMD', '').strip()
    if env_cmd:
        return env_cmd.split()

    if shutil.which('claude'):
        # Verify claude is authenticated (quick probe, must not hang)
        try:
            proc = subprocess.Popen(
                ['claude', '-p', 'ping', '--output-format', 'text', '--no-session-persistence'],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                start_new_session=True,
            )
            try:
                stdout, _ = proc.communicate(timeout=5)
                if proc.returncode == 0:
                    return [
                        'claude', '-p',
                        '--allowedTools', 'Bash,Read,Write,Edit,Task,WebSearch,WebFetch',
                        '--output-format', 'stream-json', '--verbose',
                        '--no-session-persistence',
                    ]
            except subprocess.TimeoutExpired:
                os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
                proc.wait()
        except (OSError, FileNotFoundError):
            pass

    if shutil.which('kiro-cli'):
        return ['kiro-cli', 'chat', '--no-interactive', '--trust-all-tools', '--agent', 'pilot']

    print('❌ Neither claude nor kiro-cli found in PATH.', file=sys.stderr)
    sys.exit(1)