---
description: Clear all pending learnings from queue
allowed-tools: Bash
---

## Task

```bash
python3 -c "
from pathlib import Path
import json

queue_path = Path.home() / '.kiro' / 'learnings-queue.json'
if queue_path.exists():
    items = json.loads(queue_path.read_text())
    count = len(items)
    queue_path.write_text('[]')
    print(f'🗑️ Cleared {count} learnings from queue.')
else:
    print('📭 Queue was already empty.')
"
```
