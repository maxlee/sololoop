---
description: "记录决策到 decisions-log.md"
argument-hint: "DECISION_TEXT"
allowed-tools: Bash(*)
---

# SoloLoop Log 命令

记录重要决策和目标调整到 `.sololoop/decisions-log.md`。

## 参数说明

- `DECISION_TEXT`: 决策描述文本（必需）

## 使用示例

记录一个决策：
```
/sololoop:log "决定使用方案 A 而非方案 B，因为性能更好"
```

记录目标调整：
```
/sololoop:log "调整了性能约束，从 100ms 放宽到 200ms，因为实际场景允许"
```

记录技术选型：
```
/sololoop:log "选择使用 PostgreSQL 而非 MySQL，因为需要 JSON 支持"
```

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/log-decision.sh" $ARGUMENTS
```

## 日志格式

每条记录包含：
- **时间戳**: ISO 8601 格式
- **决策内容**: 你提供的描述文本

## 查看日志

使用 `/sololoop:show-log` 命令查看最近的决策记录。

## 注意事项

- 需要先初始化目标记忆（运行 `/sololoop:init` 或 `/sololoop`）
- 决策记录会在 SessionStart 时自动注入到上下文中（最近 5 条）
- 建议在做出重要决策时及时记录，便于后续回顾
