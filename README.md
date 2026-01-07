# SoloLoop Plugin

Claude Code 迭代循环插件，让 Claude 在同一任务上持续迭代直到完成。

[![GitHub](https://img.shields.io/badge/GitHub-maxlee%2Fsololoop-blue)](https://github.com/maxlee/sololoop)
[![Version](https://img.shields.io/badge/version-5.0.0-green)](https://github.com/maxlee/sololoop)

## 什么是 SoloLoop？

SoloLoop 通过 Stop Hook 机制拦截 Claude 的退出尝试，将相同的 prompt 反复输入，实现自引用的迭代改进。

**v5 新特性**：架构重构，回归纯粹的顽强循环引擎。移除内置规格管理功能（`--plan`、`--spec`），将这些职责交给专业工具 OpenSpec 处理。新增 `/sololoop:openspec` 桥接命令实现无缝集成。

```
用户运行 /sololoop:sololoop "任务描述" --max 10
    ↓
Claude 处理任务
    ↓
Claude 尝试退出
    ↓
Stop Hook 拦截，检查进度
    ↓
重复直到完成或达到最大迭代次数
```

### v5 核心变更

| 特性 | v4 | v5 |
|------|----|----|
| 架构理念 | All-in-one | 职责分离（轻量循环引擎） |
| 规格管理 | 内置 `--plan`/`--spec` | 外部 OpenSpec 集成 |
| 桥接命令 | 无 | `/sololoop:openspec` |
| 迭代信息 | 混入 reason | systemMessage 分离 |
| `.sololoop/` 目录 | 自动创建 | 已移除 |
| Prompt 纯净度 | 包含迭代前缀 | 原始 prompt 保持纯净 |

## 安装方式

### 🚀 方式 A：从 GitHub Marketplace 安装（推荐）

```bash
# 1. 添加 SoloLoop 作为 marketplace
/plugin marketplace add maxlee/sololoop

# 2. 安装插件
/plugin install sololoop@sololoop-marketplace
```

安装后直接使用：
```bash
# 纯循环模式
/sololoop:sololoop "你的任务描述" --max 10

# OpenSpec 集成模式
/sololoop:openspec feature-name --max 10
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

#### 方式 C：调试模式

查看插件加载详情：

```bash
claude --debug --plugin-dir /path/to/sololoop
```

## 快速开始

### 纯循环模式（基本用法）

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

### 🆕 v5 OpenSpec 集成模式（推荐）

使用 `/sololoop:openspec` 命令与 OpenSpec 无缝集成：

```bash
# 基本用法
/sololoop:openspec feature-name

# 指定最大迭代次数
/sololoop:openspec feature-name --max 20

# 使用完成标记
/sololoop:openspec feature-name --promise "DONE" --max 15
```

**前置条件**：
1. 项目中已安装 OpenSpec（存在 `openspec/` 目录）
2. 已创建变更目录 `openspec/changes/<feature-name>/`
3. 变更目录中存在 `tasks.md` 文件

**OpenSpec 模式工作流**：
1. 桥接脚本检查 OpenSpec 目录和 tasks.md 文件
2. 自动构建引用 tasks.md 的 prompt
3. Claude 按照 tasks.md 执行任务并勾选复选框
4. Stop Hook 检测 tasks.md 复选框进度
5. 所有复选框勾选后自动退出

**自动构建的 Prompt**：
```
按照 openspec/changes/<feature-name>/tasks.md 实现所有任务。

参考规格：openspec/changes/<feature-name>/specs/
项目约定：openspec/project.md（如存在）

完成每个任务后在 tasks.md 中勾选对应复选框。
```

### ⚠️ 废弃参数警告

v5 已废弃以下参数，使用时会显示警告：

| 废弃参数 | 替代方案 |
|---------|---------|
| `--plan` | 使用 `/sololoop:openspec` |
| `--spec` | 使用 `/sololoop:openspec` |

```bash
# ❌ 废弃用法（会显示警告）
/sololoop:sololoop "任务" --plan
/sololoop:sololoop "任务" --spec

# ✅ 推荐用法
/sololoop:openspec feature-name
```

### 中断恢复机制

当 Bash 命令执行被中断时，SoloLoop 会自动处理：

- **自动检测**：从 transcript 检测 "Interrupted" 模式
- **恢复指令**：在 systemMessage 中添加恢复指导
- **升级处理**：连续中断 3 次以上时，建议替代方案
- **状态跟踪**：记录中断次数，成功迭代后自动重置

这确保了工作流不会因为长时间运行的命令被中断而停止。

## 命令参数

### /sololoop:sololoop（纯循环模式）

| 参数 | 说明 | 默认值 |
|------|------|--------|
| PROMPT | 任务描述（必需） | - |
| --max N | 最大迭代次数 | 10 |
| --promise TEXT | 完成标记 | 无 |
| --plan | ⚠️ 已废弃，显示警告 | - |
| --spec | ⚠️ 已废弃，显示警告 | - |

### /sololoop:openspec（OpenSpec 集成模式）

| 参数 | 说明 | 默认值 |
|------|------|--------|
| change-name | OpenSpec 变更名称（必需） | - |
| --max N | 最大迭代次数 | 10 |
| --promise TEXT | 完成标记 | 无 |

### 退出条件优先级

v5 优化了退出条件的检查顺序：

1. **OpenSpec 任务完成**：tasks.md 中所有复选框都勾选（优先级 1）
2. **承诺匹配**：检测到 `<promise>TEXT</promise>` 精确匹配（优先级 2）
3. **最大迭代**：达到 --max 指定的次数（优先级 3，安全网）

## 工作原理

### 架构概览

```
SoloLoop v5 (轻量循环引擎)     OpenSpec (外部工具)
├── 循环引擎                   ├── 规格定义 (specs/)
├── 中断恢复                   ├── 变更管理 (changes/)
├── OpenSpec 桥接              ├── 任务分解 (tasks.md)
└── 退出条件判断               └── 归档演进
```

### 核心脚本

1. **setup-sololoop.sh**：解析参数，创建状态文件 `.claude/sololoop.local.md`
2. **openspec-bridge.sh**：检查 OpenSpec 目录，构建引用 tasks.md 的 prompt
3. **stop-hook.sh**：在 Claude 尝试停止时被调用，检查状态文件和进度，决定是否继续循环

### Stop Hook 决策逻辑

```
状态文件不存在？ → 允许退出
OpenSpec 模式且复选框全勾选？ → 允许退出，删除状态文件
检测到完成标记？ → 允许退出，删除状态文件
达到最大迭代？ → 允许退出，删除状态文件
检测到 Bash 中断？ → 阻止退出，systemMessage 添加恢复指令
否则 → 阻止退出，返回原始 prompt 继续迭代
```

### 状态文件格式 (v5)

```markdown
---
iteration: 1
max_iterations: 10
completion_promise: "DONE"
openspec_mode: true
openspec_tasks_file: "openspec/changes/feature-x/tasks.md"
started_at: "2026-01-07T10:30:00Z"
interruption_count: 0
last_interruption_type: null
---

原始 prompt 内容...
```

### Hook 输出格式 (v5)

v5 采用 `systemMessage` 分离迭代信息，保持 prompt 纯净：

**继续迭代**：
```json
{
  "decision": "block",
  "reason": "原始 prompt 内容（纯净）",
  "systemMessage": "🔄 SoloLoop 迭代 2/10 | 进度: 3/5 (60%)"
}
```

**允许退出**：
```json
{
  "decision": "allow"
}
```

## 文件结构

```
sololoop/
├── .claude-plugin/
│   ├── plugin.json          # 插件元数据（v5.0.0）
│   └── marketplace.json     # Marketplace 配置
├── commands/
│   ├── sololoop.md          # 纯循环命令
│   ├── openspec.md          # 🆕 v5 OpenSpec 桥接命令
│   └── cancel-sololoop.md   # 取消命令
├── hooks/
│   ├── hooks.json           # Hook 配置
│   └── stop-hook.sh         # Stop Hook 脚本（v5：systemMessage 分离）
├── scripts/
│   ├── setup-sololoop.sh    # 初始化脚本
│   ├── openspec-bridge.sh   # 🆕 v5 OpenSpec 桥接脚本
│   └── cancel-sololoop.sh   # 取消脚本
├── tests/                   # 测试文件
│   ├── setup-sololoop.bats
│   ├── openspec-bridge.bats # 🆕 v5 新增
│   ├── stop-hook.bats
│   ├── cancel-sololoop.bats
│   ├── command-format.bats
│   ├── integration.bats
│   └── helpers/
└── README.md

# 运行时生成的文件
project/
└── .claude/
    └── sololoop.local.md    # 状态文件
```

## 故障排除

| 问题 | 解决方案 |
|------|----------|
| Unknown slash command | 检查插件是否正确加载，使用 `claude --debug` 查看日志 |
| 权限错误 | 使用 `--dangerously-skip-permissions` 或手动添加权限 |
| 循环没有启动 | 检查 prompt 是否为空，--max 是否为正整数 |
| 循环没有停止 | 运行 `/sololoop:cancel-sololoop` 或删除 `.claude/sololoop.local.md` |
| 中断后循环停止 | 升级到 v3+，自动处理 Bash 中断 |
| 迭代次数不准确 | 升级到 v3+，严格按照 `--max` 执行 |
| 🆕 openspec 命令失败 | 确认 `openspec/` 目录存在且包含 tasks.md |
| 🆕 --plan/--spec 警告 | 这些参数已废弃，请使用 `/sololoop:openspec` |
| 🆕 进度不显示 | 确认 tasks.md 中使用标准复选框格式 `- [ ]` / `- [x]` |

---

## 插件开发参考文档

以下是从 [Claude Code 官方文档](https://code.claude.com/docs/en/plugins) 整理的插件开发关键信息。

### 插件目录结构

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json          # 必需：插件元数据
├── commands/                 # 斜杠命令 Markdown 文件
├── agents/                   # 自定义 agent 定义
├── skills/                   # Agent Skills（含 SKILL.md）
├── hooks/
│   └── hooks.json           # Hook 配置
├── .mcp.json                # MCP 服务器配置
└── .lsp.json                # LSP 服务器配置
```

### plugin.json 完整 Schema

```json
{
  "name": "plugin-name",           // 必需：唯一标识符（kebab-case）
  "version": "1.2.0",              // 语义化版本
  "description": "插件描述",
  "author": {
    "name": "作者名",
    "email": "email@example.com",
    "url": "https://github.com/author"
  },
  "homepage": "https://docs.example.com/plugin",
  "repository": "https://github.com/author/plugin",
  "license": "MIT",
  "keywords": ["keyword1", "keyword2"],
  "commands": ["./custom/commands/special.md"],
  "agents": "./custom/agents/",
  "skills": "./custom/skills/",
  "hooks": "./config/hooks.json",
  "mcpServers": "./mcp-config.json",
  "lspServers": "./.lsp.json"
}
```

### 命令文件 Frontmatter

命令文件支持以下 frontmatter 字段：

| 字段 | 用途 | 默认值 |
|------|------|--------|
| `description` | 命令简述 | 使用 prompt 第一行 |
| `allowed-tools` | 命令可用的工具列表 | 继承会话设置 |
| `argument-hint` | 参数提示 | 无 |
| `model` | 指定模型 | 继承会话设置 |
| `disable-model-invocation` | 禁止 SlashCommand 工具调用 | false |

### allowed-tools 格式

```yaml
# 单个工具
allowed-tools: Read

# 多个工具（逗号分隔字符串）
allowed-tools: Read, Write, Edit

# 多个工具（数组格式）
allowed-tools:
  - Read
  - Write
  - Bash(git:*)

# Bash 命令过滤器
allowed-tools: Bash(git:*)              # 只允许 git 命令
allowed-tools: Bash(*)                  # 允许所有 bash 命令
allowed-tools: Bash(git status:*)       # 只允许 git status

# 通配符
allowed-tools: "*"                      # 允许所有工具

# ❌ 错误格式
allowed-tools: Bash                     # 缺少命令过滤器
```

### 命令中执行 Bash

使用 `!` 前缀执行 bash 命令，输出会包含在命令上下文中：

```markdown
---
description: 分析代码质量
allowed-tools: Bash(node:*)
---

分析结果: !`node ${CLAUDE_PLUGIN_ROOT}/scripts/analyze.js $1`
```

### 环境变量

- `${CLAUDE_PLUGIN_ROOT}`: 插件目录的绝对路径
- `${CLAUDE_PROJECT_DIR}`: 项目目录路径（仅在 hook 中可用）

### Hook 配置

hooks.json 结构：

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/stop-hook.sh"
          }
        ]
      }
    ]
  }
}
```

支持的 Hook 事件：
- `PreToolUse`: 工具调用前
- `PostToolUse`: 工具调用后
- `UserPromptSubmit`: 用户提交 prompt 时
- `Stop`: 主 agent 完成响应时
- `SubagentStop`: 子 agent 完成时
- `SessionStart`: 会话开始时
- `SessionEnd`: 会话结束时

### Stop Hook 输出格式

v5 采用 `systemMessage` 分离迭代信息：

```json
{
  "decision": "block",
  "reason": "原始 prompt（纯净）",
  "systemMessage": "🔄 SoloLoop 迭代 2/10 | 进度: 3/5 (60%)"
}
```

### Marketplace 配置

.claude-plugin/marketplace.json：

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "marketplace-name",
  "description": "Marketplace 描述",
  "owner": {
    "name": "Owner Name",
    "email": "email@example.com"
  },
  "plugins": [
    {
      "name": "plugin-name",
      "description": "插件描述",
      "category": "productivity",
      "source": "./",
      "homepage": "https://github.com/user/plugin",
      "tags": ["tag1", "tag2"]
    }
  ]
}
```

### 插件安装作用域

| 作用域 | 配置文件 | 用途 |
|--------|----------|------|
| user | ~/.claude/settings.json | 个人插件，跨项目可用（默认） |
| project | .claude/settings.json | 团队插件，通过版本控制共享 |
| local | .claude/settings.local.json | 项目特定，gitignore |

### CLI 命令

```bash
# 安装插件
claude plugin install <plugin>@<marketplace> [--scope user|project|local]

# 卸载插件
claude plugin uninstall <plugin> [--scope user|project|local]

# 启用/禁用插件
claude plugin enable <plugin>
claude plugin disable <plugin>

# 更新插件
claude plugin update <plugin>
```

### 调试

```bash
# 查看插件加载详情
claude --debug

# 直接加载本地插件目录
claude --plugin-dir /path/to/plugin
```

### 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 插件未加载 | plugin.json 无效 | 验证 JSON 语法 |
| 命令不显示 | 目录结构错误 | 确保 commands/ 在插件根目录 |
| Hook 不触发 | 脚本不可执行 | 运行 `chmod +x script.sh` |
| MCP 服务器失败 | 路径错误 | 使用 `${CLAUDE_PLUGIN_ROOT}` |
| 路径错误 | 使用绝对路径 | 所有路径必须相对且以 `./` 开头 |

---

## 版本历史

| 版本 | 主要特性 |
|------|----------|
| v5.0.0 | 架构重构：职责分离、移除 `--plan`/`--spec`、新增 `/sololoop:openspec` 桥接、systemMessage 分离迭代信息 |
| v4.0.0 | 规格驱动规划：增强 Spec 模板、`--spec` 严格模式、退出条件优先级优化、`/sololoop:update-spec` 命令 |
| v3.0.0 | 中断恢复机制、`.sololoop/` 目录结构、严格退出条件、中断计数跟踪 |
| v2.0.0 | 规划文件模式 (`--plan`)、复选框进度跟踪、task_plan.md/notes.md/deliverable.md |
| v1.0.0 | 基础迭代循环、Stop Hook 机制、`--max` 和 `--promise` 参数 |

### v5 迁移指南

从 v4 迁移到 v5：

1. **移除 `.sololoop/` 目录**：v5 不再使用此目录
2. **安装 OpenSpec**：如需规格驱动开发，请安装 OpenSpec
3. **更新命令**：
   - `--plan` → `/sololoop:openspec <change-name>`
   - `--spec` → `/sololoop:openspec <change-name>`
4. **纯循环模式**：继续使用 `/sololoop:sololoop "prompt" --max N`

---

## 参考链接

- [Claude Code Plugins 文档](https://code.claude.com/docs/en/plugins)
- [Plugins Reference](https://code.claude.com/docs/en/plugins-reference)
- [Slash Commands](https://code.claude.com/docs/en/slash-commands)
- [Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Plugin Marketplaces](https://code.claude.com/docs/en/plugin-marketplaces)
- [Ralph Wiggum 原始技术](https://ghuntley.com/ralph/)

## License

MIT
