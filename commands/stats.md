---
description: "查看 SoloLoop 使用统计"
allowed-tools: Bash(*)
---

# 使用统计

查看 SoloLoop 的使用统计数据，包括总会话数、总迭代数、平均迭代数和退出原因分布。

## 统计内容

- **总会话数**: 使用 SoloLoop 的总次数
- **总迭代数**: 所有会话的迭代总数
- **平均迭代数**: 每次会话的平均迭代次数
- **退出原因分布**: 各种退出原因的统计
  - `promise_matched`: 完成标记匹配退出
  - `max_iterations`: 达到最大迭代次数退出
  - `user_cancelled`: 用户取消退出

## 使用示例

```
/sololoop:stats
```

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/show-stats.sh"
```

## 数据存储

统计数据存储在 `~/.claude/sololoop/stats.json` 文件中。

> 💡 提示：统计数据会在每次循环结束时自动更新。
