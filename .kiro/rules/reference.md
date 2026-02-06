# On-Demand Reference Layer

> Detailed rules and materials, loaded only when needed.

## Templates

### Deep Interview Template

Before making a plan, ask:
```
1. [Goal] What's the desired outcome? Success criteria?
2. [Context] What triggered this need?
3. [Constraints] Time, budget, technical limits?
4. [Reference] Any good examples to follow?
5. [Priority] What's essential vs. nice-to-have?
```

### Compound Interest Checklist

| Check | Trigger | Update Target |
|-------|---------|---------------|
| New knowledge? | User provides context | `knowledge/` |
| Structured data extracted? | From files/research | `-structured.md` |
| Final plan/proposal? | Task completion | `plans/` |
| New directory? | Created during task | Create `INDEX.md` |

### Repeated Behavior Detection

When detecting repeated operations ≥3 times:
```
💡 Compound Interest Reminder: I've noticed you've [done X] [N] times.
Suggest creating:
- [ ] Template → `templates/[name].md`
- [ ] Tool → `tools/[name].sh`
Create now?
```

## Long Script Handling

```python
# ❌ Wrong: Long inline scripts
executeBash("python -c 'import xxx; ... very long code ...'")

# ✅ Right: Write to file first
fsWrite("script.py", "import xxx\n...")
executeBash("python script.py")
```

## Long Command Execution

```bash
command &
PID=$!
for i in {1..6}; do
    sleep 10
    if ! ps -p $PID > /dev/null 2>&1; then
        echo "Command completed"; break
    fi
    echo "[$((i*10))s] Still running..."
done
wait $PID 2>/dev/null
```
