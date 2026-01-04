# SoloLoop Plugin

简化版的 Claude Code 迭代循环插件。

## 什么是 SoloLoop？

SoloLoop 让 Claude 在同一任务上持续迭代直到完成。通过 Stop Hook 机制拦截退出尝试，将相同的 prompt 反复输入，实现自引用的迭代改进。

```
用户运行 /sololoop:sololoop "任务描述" --max 10
    ↓
Claude 处理任务
    ↓
Claude 尝试退出
    ↓
Stop Hook 拦截，反馈相同 prompt
    ↓
重复直到完成或达到最大迭代次数
```

## 快速开始

```bash
# 基本用法（默认最多 10 次迭代）
/sololoop:sololoop "实现一个计算器函数"

# 指定最大迭代次数
/sololoop:sololoop "编写单元测试" --max 15

# 使用完成标记
/sololoop:sololoop "重构代码" --promise "DONE" --max 20

# 查看帮助
/sololoop:sololoop --help

# 取消循环
/sololoop:cancel-sololoop
```

## 命令参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| PROMPT | 任务描述（必需） | - |
| --max N | 最大迭代次数 | 10 |
| --promise TEXT | 完成标记 | 无 |

## 文件结构

```
sololoop/
├── .claude-plugin/
│   └── plugin.json          # 插件元数据（必需）
├── commands/
│   ├── sololoop.md          # 启动命令
│   └── cancel-sololoop.md   # 取消命令
├── hooks/
│   ├── hooks.json           # Hook 配置
│   └── stop-hook.sh         # Stop Hook 脚本
├── scripts/
│   ├── setup-sololoop.sh    # 初始化脚本
│   └── cancel-sololoop.sh   # 取消脚本
└── README.md
```

## 安装方式

### 方式 1：使用 --plugin-dir 加载（开发测试）

```bash
claude --plugin-dir /path/to/sololoop
```

### 方式 2：从 GitHub 安装（推荐）

```bash
# 在 Claude Code 中运行
/plugin install https://github.com/maxlee/sololoop
```

### 方式 3：手动安装

编辑 `~/.claude/settings.json`：

```json
{
  "plugins": {
    "sololoop": {
      "path": "/path/to/sololoop",
      "enabled": true
    }
  }
}
```

## 工作原理

1. **setup-sololoop.sh**：解析参数，创建状态文件 `.claude/sololoop.local.md`
2. **stop-hook.sh**：在 Claude 尝试停止时被调用，检查状态文件，决定是否继续循环
3. **状态文件**：使用 YAML frontmatter 存储迭代计数、最大次数、完成标记

### 状态文件格式

```markdown
---
iteration: 3
max_iterations: 10
completion_promise: "DONE"
started_at: "2026-01-04T10:00:00Z"
---

你的 prompt 内容...
```

### Stop Hook 决策逻辑

```
状态文件不存在？ → 允许退出
达到最大迭代？ → 允许退出，删除状态文件
检测到完成标记？ → 允许退出，删除状态文件
否则 → 阻止退出，返回 prompt 继续迭代
```

## 故障排除

| 问题 | 解决方案 |
|------|----------|
| 循环没有启动 | 检查 prompt 是否为空，--max 是否为正整数 |
| 循环没有停止 | 运行 `/sololoop:cancel-sololoop` 或删除 `.claude/sololoop.local.md` |
| 权限错误 | 在 `.claude/settings.json` 中添加 Bash 权限 |

## 参考

- [Claude Code Hooks 文档](https://code.claude.com/docs/en/hooks)
- [Claude Code Plugins 文档](https://code.claude.com/docs/en/plugins)
- [Ralph Wiggum 原始技术](https://ghuntley.com/ralph/)
- [GitHub 仓库](https://github.com/maxlee/sololoop)
