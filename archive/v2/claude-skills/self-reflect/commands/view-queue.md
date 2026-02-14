---
description: View pending learnings queue
allowed-tools: Bash
---

## Task

```bash
python3 -c "
import json
from pathlib import Path

queue_path = Path.home() / '.kiro' / 'learnings-queue.json'
if not queue_path.exists():
    print('📭 No pending learnings.')
else:
    items = json.loads(queue_path.read_text())
    if not items:
        print('📭 No pending learnings.')
    else:
        print(f'📋 {len(items)} pending learnings:\n')
        print('| # | Confidence | Content | Type |')
        print('|---|-----------|---------|------|')
        for i, item in enumerate(items, 1):
            msg = item.get('message', '')[:40]
            conf = item.get('confidence', 0)
            typ = item.get('type', 'auto')
            print(f'| {i} | {conf:.0%} | {msg}... | {typ} |')
"
```
