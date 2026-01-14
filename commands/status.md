---
description: "显示目标记忆状态"
allowed-tools: Bash(*)
---

# SoloLoop Status 命令

显示 SoloLoop 目标记忆的当前状态。

## 功能说明

显示以下信息：
- 当前目标摘要（从 goal.md 提取）
- 迭代进度
- 重锚状态（距离下次重锚的迭代数）
- 漂移警告计数
- 最后活动时间

## 使用示例

查看当前状态：
```
/sololoop:status
```

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/show-status.sh"
```

## 输出示例

```
📊 SoloLoop 目标记忆状态

🎯 [Goal Memory Active]

📋 当前目标:
   完成用户认证功能，要求支持 OAuth2

🔄 迭代进度:     12 / 50
⚓ 重锚间隔:     7 / 15
📌 总重锚次数:   2
✅ 漂移警告:     0

⏱️ 时间信息:
   开始时间:     2026-01-13T10:00:00Z
   最后活动:     2026-01-13T10:30:00Z
```

## 注意事项

- 需要先初始化目标记忆（运行 `/sololoop:init` 或 `/sololoop`）
- 如果没有活动循环，部分字段会显示 "N/A"
- 漂移警告计数 > 0 表示最近输出可能偏离了原始目标

