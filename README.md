# SoloLoop Plugin

简化版的 Claude Code 迭代循环插件，让 Claude 在同一任务上持续迭代直到完成。

[![GitHub](https://img.shields.io/badge/GitHub-maxlee%2Fsololoop-blue)](https://github.com/maxlee/sololoop)

## 什么是 SoloLoop？

SoloLoop 通过 Stop Hook 机制拦截 Claude 的退出尝试，将相同的 prompt 反复输入，实现自引用的迭代改进。

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

## 安装方式

### 🚀 方式 A：从 GitHub Marketplace 安装（推荐）

```bash
# 1. 添加 SoloLoop 作为 marketplace
/plugin marketplace add maxlee/sololoop

# 2. 安装插件
/plugin install sololoop
```

安装后直接使用：
```bash
/sololoop:sololoop "你的任务描述" --max 10
```

用户需要在 ~/.claude/settings.json 中添加权限:
```bash
{
  "permissions": {
    "allow": [
      "Bash(~/.claude/plugins/cache/sololoop-marketplace/sololoop/*/scripts/*:*)"
    ]
  }
}
```

### 🚀 方式 B：克隆后本地安装

```bash
# 1. 克隆仓库到本地
git clone https://github.com/maxlee/sololoop.git ~/sololoop

# 2. 在 Claude Code 中安装插件
/plugin install ~/sololoop
```

### 🔧 本地开发测试

#### 方式 A：沉浸式开发模式（推荐）

跳过所有权限确认，让迭代循环更加流畅：

```bash
claude --dangerously-skip-permissions --plugin-dir /path/to/sololoop
```

> ⚠️ **注意**：此模式会跳过所有安全确认，仅建议在受信任的项目中使用。

#### 方式 B：标准开发模式

```bash
claude --plugin-dir /path/to/sololoop
```

首次使用时需要手动授权，或在 `~/.claude/settings.json` 中添加权限：

```json
{
  "permissions": {
    "allow": [
      "Bash(/path/to/sololoop/scripts/setup-sololoop.sh:*)",
      "Bash(/path/to/sololoop/scripts/cancel-sololoop.sh:*)"
    ]
  }
}
```

#### 方式 C：调试模式

查看插件加载详情：

```bash
claude --debug --plugin-dir /path/to/sololoop
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

## 工作原理

1. **setup-sololoop.sh**：解析参数，创建状态文件 `.claude/sololoop.local.md`
2. **stop-hook.sh**：在 Claude 尝试停止时被调用，检查状态文件，决定是否继续循环
3. **状态文件**：使用 YAML frontmatter 存储迭代计数、最大次数、完成标记

### Stop Hook 决策逻辑

```
状态文件不存在？ → 允许退出
达到最大迭代？ → 允许退出，删除状态文件
检测到完成标记？ → 允许退出，删除状态文件
否则 → 阻止退出，返回 prompt 继续迭代
```

## 文件结构

```
sololoop/
├── .claude-plugin/
│   └── plugin.json          # 插件元数据
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

## 故障排除

| 问题 | 解决方案 |
|------|----------|
| Unknown slash command | 检查插件是否正确加载，使用 `claude --debug` 查看日志 |
| 权限错误 | 使用 `--dangerously-skip-permissions` 或手动添加权限 |
| 循环没有启动 | 检查 prompt 是否为空，--max 是否为正整数 |
| 循环没有停止 | 运行 `/sololoop:cancel-sololoop` 或删除 `.claude/sololoop.local.md` |

## 参考

- [Claude Code Hooks 文档](https://code.claude.com/docs/en/hooks)
- [Claude Code Plugins 文档](https://code.claude.com/docs/en/plugins)
- [Ralph Wiggum 原始技术](https://ghuntley.com/ralph/)

## License

MIT
