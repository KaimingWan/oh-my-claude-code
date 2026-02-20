# Debugging Rules
# Layer: Agent Rule (top-level principles + operational rules)
# Maintained by: humans only (hook enforced)
# Boundary: universal rules, not project-specific learnings

1. 修 bug 前必须先复现、定位根因，禁止猜测性修复。NO FIX WITHOUT ROOT CAUSE。
2. 遇到测试失败：先读完整错误信息和堆栈，再行动。
3. 连续修 3 次不成功 → 停下来，重新从复现开始。
4. 调试代码问题必须先用 LSP 工具（get_diagnostics, search_symbols, find_references, goto_definition, get_hover）做语义分析。grep 仅用于注释/字符串/配置。
5. 修 bug 前必须产出诊断证据：用了哪些 LSP 工具、发现了什么、根因判断。无证据不修复。
6. 修复后必须 get_diagnostics 验证，新增 diagnostics 为 0 才算完成。
7. 不熟悉的代码：先 goto_definition 理解实现 → find_references 理解使用 → 再动手改。
