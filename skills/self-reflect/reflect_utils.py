#!/usr/bin/env python3
"""Self-reflect utilities for the 3-layer architecture.

Detects correction patterns in user messages and manages
the learning queue for syncing to appropriate target files.
"""
import json
import re
from pathlib import Path
from datetime import datetime, timezone


def get_config_dir() -> Path:
    """Get the config directory (~/.kiro/ or ~/.claude/)."""
    kiro = Path.home() / ".kiro"
    claude = Path.home() / ".claude"
    if kiro.exists():
        return kiro
    if claude.exists():
        return claude
    kiro.mkdir(parents=True, exist_ok=True)
    return kiro


def get_queue_path() -> Path:
    return get_config_dir() / "learnings-queue.json"


def iso_timestamp() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_queue() -> list:
    path = get_queue_path()
    if not path.exists():
        return []
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, IOError):
        return []


def save_queue(items: list) -> None:
    path = get_queue_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(items, indent=2, ensure_ascii=False), encoding="utf-8")


# --- Pattern Detection ---

HIGH_PATTERNS = [
    (r"\bremember\s*:", "remember"),
    (r"\balways\s*:", "always"),
    (r"\bdon'?t\b.*\bunless\b", "dont-unless"),
    (r"\bi told you\b", "i-told-you"),
]

MED_PATTERNS = [
    (r"\bno,?\s+use\b", "use-X-not-Y"),
    (r"\bnot\s+\w+,?\s+use\b", "use-X-not-Y"),
    (r"\byou missed\b", "you-missed"),
    (r"\byou forgot\b", "you-forgot"),
    (r"\bwhy didn'?t you\b", "why-didnt"),
    (r"\byou failed to\b", "failed-to"),
]

POSITIVE_PATTERNS = [
    (r"\bperfect!?\b", "positive"),
    (r"\bexactly right\b", "positive"),
    (r"\bgreat approach\b", "positive"),
    (r"\bthat'?s what i wanted\b", "positive"),
    (r"\bkeep doing this\b", "positive"),
]

EXCLUDE_PATTERNS = [
    r"\?$",
    r"^please\b",
    r"^help me\b",
    r"\berror\b",
    r"\bfailed\b",
]


def detect_patterns(message: str):
    """Detect correction/feedback patterns in a message.
    
    Returns: (type, pattern_name, confidence, sentiment, decay_days) or (None,)*5
    """
    msg = message.strip()
    lower = msg.lower()

    if len(msg) > 300:
        return None, None, 0, None, 0

    for pat in EXCLUDE_PATTERNS:
        if re.search(pat, lower):
            return None, None, 0, None, 0

    for pat, name in HIGH_PATTERNS:
        if re.search(pat, lower):
            return "auto", name, 0.90, "correction", 90

    for pat, name in MED_PATTERNS:
        if re.search(pat, lower):
            return "auto", name, 0.80, "correction", 60

    for pat, name in POSITIVE_PATTERNS:
        if re.search(pat, lower):
            return "auto", name, 0.70, "positive", 30

    return None, None, 0, None, 0


def capture_learning(message: str, project: str = None) -> dict | None:
    """Detect and capture a learning from user message."""
    item_type, patterns, confidence, sentiment, decay_days = detect_patterns(message)
    if not item_type:
        return None

    queue_item = {
        "message": message,
        "type": item_type,
        "patterns": patterns,
        "confidence": confidence,
        "sentiment": sentiment,
        "decay_days": decay_days,
        "timestamp": iso_timestamp(),
        "project": project or str(Path.cwd()),
    }

    items = load_queue()
    items.append(queue_item)
    save_queue(items)
    return queue_item


def suggest_target(learning: str) -> str:
    """Suggest which file a learning should sync to."""
    lower = learning.lower()

    if any(x in lower for x in ["gpt-", "claude-", "gemini-", "model"]):
        return "global"
    if any(x in lower for x in ["file name", "filename", "format", "lint", "style", "naming"]):
        return "enforcement"
    if any(x in lower for x in ["template", "example", "sop", "workflow"]):
        return "reference"
    return "agents"


def get_queue_summary() -> str:
    items = load_queue()
    if not items:
        return "📭 No pending learnings."

    lines = [f"📋 {len(items)} pending learnings:\n"]
    for i, item in enumerate(items[:10], 1):
        preview = item["message"][:50] + ("..." if len(item["message"]) > 50 else "")
        conf = item.get("confidence", 0)
        target = suggest_target(item["message"])
        lines.append(f"{i}. [{conf:.0%}] \"{preview}\" → {target}")

    if len(items) > 10:
        lines.append(f"   ... and {len(items) - 10} more")
    return "\n".join(lines)


if __name__ == "__main__":
    print(get_queue_summary())
