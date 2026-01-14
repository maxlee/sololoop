---
description: "显示决策日志记录"
argument-hint: "[COUNT|all]"
allowed-tools: Bash(*)
---

# SoloLoop Show Log 命令

显示 `.sololoop/decisions-log.md` 中的决策记录。

## 参数说明

- `COUNT`: 显示条目数量（可选，默认 5）
- `all`: 显示全部记录

## 使用示例

显示最近 5 条记录（默认）：
```
/sololoop:show-log
```

显示最近 10 条记录：
```
/sololoop:show-log 10
```

显示全部记录：
```
/sololoop:show-log all
```

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/show-log.sh" $ARGUMENTS
```

## 输出格式

每条记录显示：
- 时间戳
- 决策内容

记录按时间倒序排列（最新的在前）。

## 相关命令

- `/sololoop:log "描述"` - 添加新的决策记录
- `/sololoop:status` - 查看当前目标状态

## 注意事项

- 需要先初始化目标记忆（运行 `/sololoop:init` 或 `/sololoop`）
- 如果日志为空，会提示使用 `/sololoop:log` 添加记录
