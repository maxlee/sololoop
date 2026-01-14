---
description: "初始化 SoloLoop 目标记忆目录结构"
argument-hint: "[PROMPT]"
allowed-tools: Bash(*)
---

# SoloLoop Init 命令

手动初始化目标记忆目录结构。通常情况下，首次运行 `/sololoop` 时会自动初始化，此命令用于提前设置。

## 参数说明

- `PROMPT`: 任务描述（可选），如果提供，将自动提取目标到 goal.md

## 使用示例

手动初始化（空模板）：
```
/sololoop:init
```

从 prompt 提取目标：
```
/sololoop:init "实现用户认证功能，要求支持 OAuth2"
```

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/init-sololoop.sh" $ARGUMENTS
```

## 创建的目录结构

```
.sololoop/
├── goal.md           # 当前目标描述
├── invariants.md     # 核心约束清单
├── decisions-log.md  # 决策历史记录
└── archived-goals/   # 历史目标存档
```

## 注意事项

- 如果 `.sololoop/` 目录已存在，命令会跳过初始化
- 初始化后，目标记忆将在后续 sololoop 执行中自动激活
- 可以手动编辑 goal.md 和 invariants.md 细化目标和约束
