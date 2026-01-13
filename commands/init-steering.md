---
description: "初始化 Manus 最佳实践 Steering 模板到项目"
allowed-tools: Bash(*)
---

# 初始化 Steering 模板

将 SoloLoop 提供的 Manus 最佳实践模板复制到项目的 `.claude/steering/` 目录。

复制后，你可以在对话中使用 `#manus-rules` 来启用这些最佳实践。

执行脚本:
```!
"${CLAUDE_PLUGIN_ROOT}/scripts/init-steering.sh"
```
