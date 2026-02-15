# Debugging Rules
# Layer: Agent Rule (top-level principles + operational rules)
# Maintained by: humans only (hook enforced)
# Boundary: universal rules, not project-specific learnings

1. 修 bug 前必须先复现、定位根因，禁止猜测性修复。NO FIX WITHOUT ROOT CAUSE。
2. 遇到测试失败：先读完整错误信息和堆栈，再行动。
3. 连续修 3 次不成功 → 停下来，重新从复现开始。
