Execute an approved plan with Ralph Loop hard constraint. Agent stops don't matter — bash loop keeps going until all checklist items are done.

## Step 1: Load Plan

Resolve which plan to execute:
1. Read `docs/plans/.active` — if it exists, use that path
2. If not found, check if there's only one plan in `docs/plans/` — use it
3. If multiple plans exist, list them and ask the user to pick

Verify the plan has reviewer APPROVE verdict. If not approved, tell the user to run @plan first.

## Step 2: Verify Checklist

The plan MUST contain a `## Checklist` section with at least one `- [ ]` item. If missing, STOP and tell the user the plan needs a checklist.

## Step 3: Launch Ralph Loop

Run:
```bash
./scripts/ralph-loop.sh
```

This bash script will:
- Loop until all `- [ ]` items become `- [x]`
- Each iteration spawns a fresh Kiro CLI instance with clean context
- Circuit breaker: exits if 3 consecutive rounds make no progress
- Agent stopping is fine — the loop restarts a new instance

## Step 4: Report Results

After ralph-loop.sh exits, report:
- How many checklist items completed vs total
- Any `- [SKIP]` items with reasons
- Read skills/finishing/SKILL.md for merge/PR/cleanup options
