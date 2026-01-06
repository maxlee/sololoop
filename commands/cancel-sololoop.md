---
description: "取消 SoloLoop 迭代循环"
argument-hint: ""
allowed-tools: Bash(*)
---

# 取消 SoloLoop 循环

取消当前活动的 SoloLoop 迭代循环。

## 说明

- 删除状态文件 `.claude/sololoop.local.md`
- 显示取消时的迭代计数
- 如果启用了规划文件模式，会保留 `.sololoop/` 目录中的规划文件（task_plan.md、notes.md、deliverable.md）

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/cancel-sololoop.sh"
```
