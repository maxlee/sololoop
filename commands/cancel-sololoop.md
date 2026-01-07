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

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/cancel-sololoop.sh"
```
