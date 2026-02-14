# userPromptSubmit Hook 调研

> Date: 2026-02-14 | Source: Kiro 官方文档 + CLI introspect

## 机制

### Kiro CLI（我们在用的）

触发时机：用户提交消息时，100% 触发。

Hook Event（stdin JSON）：
```json
{
  "hook_event_name": "userPromptSubmit",
  "cwd": "/current/working/directory",
  "prompt": "用户输入的完整消息"
}
```

Shell Command action 的行为：
- exit 0 → stdout 加入 agent context（软注入，agent 可忽略）
- exit 非 0 → stderr 显示为 warning

关键限制：**CLI 上 exit 非 0 不能阻断用户消息提交**（和 preToolUse exit 2 阻断不同）。

### Kiro IDE（参考）

IDE 版本有两个重要差异：
1. **Agent Prompt action**（"Add to prompt"）：hook 的 prompt 被 *追加* 到用户消息，合并后发给 agent。这比 CLI 的 stdout 注入更强——它直接修改了用户消息本身。
2. **Shell Command action**：exit 非 0 时 **可以阻断用户消息提交**（Prompt Submit hook, the user prompt submission is blocked）。
3. **USER_PROMPT 环境变量**：shell command 可以通过 `$USER_PROMPT` 环境变量访问用户输入。

CLI 版本的 `prompt` 字段在 stdin JSON 里，功能等价于 IDE 的 `USER_PROMPT` 环境变量。

## 用途

| 用途 | 实现方式 | 可靠性 |
|------|---------|--------|
| 注入额外 context | stdout 输出文本 | 🟡 软注入，agent 可忽略 |
| 检测用户意图（纠正/debug/恢复） | 解析 prompt 字段，条件输出 | 🟡 同上 |
| 阻断特定消息 | exit 非 0（仅 IDE 有效） | 🔴 CLI 不支持 |
| 记录日志 | 写文件/发请求 | 🟢 100% 可靠（副作用） |
| 设置 flag 文件 | touch /tmp/xxx.flag | 🟢 100% 可靠（供其他 hook 读取） |

## 最佳实践

1. **不要依赖 stdout 注入做强约束** — agent 可以忽略。真正的强约束用 preToolUse exit 2。
2. **用 flag 文件做跨 hook 通信** — userPromptSubmit 设置 flag，stop hook 检查 flag，形成闭环。
3. **保持轻量** — 每次用户发消息都会触发，避免耗时操作（网络请求、LLM 调用）。
4. **解析 prompt 做条件注入** — 只在需要时注入，减少 token 消耗。高频教训除外（成本低，收益高）。
5. **利用 USER_PROMPT / prompt 字段** — 可以做关键词检测、意图分类、前缀匹配等。

## 当前框架使用情况

context-enrichment.sh 作为 userPromptSubmit hook，做了 4 件事：
1. 纠正检测 → 注入 self-reflect 提醒 + 写 flag 文件
2. 恢复检测 → 注入未完成任务提醒
3. Debug 检测 → 注入 systematic-debugging 提醒
4. 高频教训 → 无条件注入 JSON=jq 等规则

## 来源

- [Kiro Hook Types](https://kiro.dev/docs/hooks/types/) — IDE 版 hook 触发类型
- [Kiro Hook Actions](https://kiro.dev/docs/hooks/actions/) — Agent Prompt vs Shell Command
- Kiro CLI introspect 文档 — CLI 版 hook 机制
