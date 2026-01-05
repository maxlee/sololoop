---
description: "启动 SoloLoop 迭代循环"
argument-hint: "PROMPT [--max N] [--promise TEXT]"
allowed-tools: ["Bash"]
---

# SoloLoop 命令

启动迭代循环，让 Claude 在同一任务上持续工作直到完成。

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-sololoop.sh" $ARGUMENTS
```

循环启动后，请开始处理任务。当你尝试退出时，Stop Hook 会将相同的 prompt 反馈回来，让你继续迭代改进。

如果设置了完成标记，请在任务真正完成时输出 `<promise>完成标记</promise>`。
