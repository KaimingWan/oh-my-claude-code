"""CLI auto-detection for ralph loop."""
import os
import shutil
import sys


def detect_cli() -> list[str]:
    """Detect available CLI: env override > kiro-cli."""
    env_cmd = os.environ.get('RALPH_KIRO_CMD', '').strip()
    if env_cmd:
        return env_cmd.split()

    if shutil.which('kiro-cli'):
        return ['kiro-cli', 'chat', '--no-interactive', '--trust-all-tools', '--agent', 'pilot']

    print('❌ kiro-cli not found in PATH.', file=sys.stderr)
    sys.exit(1)
