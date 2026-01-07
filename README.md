# SoloLoop Plugin

Claude Code 迭代循环插件，让 Claude 在同一任务上持续迭代直到完成。

[![GitHub](https://img.shields.io/badge/GitHub-maxlee%2Fsololoop-blue)](https://github.com/maxlee/sololoop)
[![Version](https://img.shields.io/badge/version-4.0.0-green)](https://github.com/maxlee/sololoop)

## 什么是 SoloLoop？

SoloLoop 通过 Stop Hook 机制拦截 Claude 的退出尝试，将相同的 prompt 反复输入，实现自引用的迭代改进。

**v4 新特性**：借鉴 OpenSpec 的 spec-driven development (SDD) 设计，将 `--plan` 模式从"动态文件笔记"演进为"规格驱动规划"，通过结构化的 spec 模板和可选的严格模式，在动态迭代与确定性实现间达到最佳平衡。

```
用户运行 /sololoop:sololoop "任务描述" --plan --spec --max 10
    ↓
Claude 处理任务（严格遵循 spec 约束）
    ↓
Claude 尝试退出
    ↓
Stop Hook 拦截，检查进度、验收标准和复选框
    ↓
重复直到完成或达到最大迭代次数
```

### v4 核心升级

| 特性 | v3 | v4 |
|------|----|----|
| Spec 模板 | 基础 Phases | 增强结构：Requirements、AC、Test Cases、Phases |
| 规格模式 | 无 | `--spec` 严格遵循 spec 约束 |
| 退出条件 | 隐式优先级 | 显式优先级：计划完成 > Promise > 最大迭代 |
| Spec 更新 | 无 | `/sololoop:update-spec` 中途调整需求 |
| 验收标准 | 无 | 解析 AC 复选框，列出未完成项 |

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
/sololoop:sololoop "你的任务描述" --max 10
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

### 基本用法

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

### 🆕 v2 规划模式（推荐）

使用 `--plan` 参数启用文件驱动的规划模式：

```bash
# 启用规划模式
/sololoop:sololoop "实现用户认证功能" --plan

# 规划模式 + 自定义迭代次数
/sololoop:sololoop "优化前端性能" --plan --max 20

# 规划模式 + 完成标记
/sololoop:sololoop "完成 API 集成" --plan --promise "INTEGRATED" --max 15
```

启用 `--plan` 后，SoloLoop 会自动创建 `.sololoop/` 目录和规划文件：

| 文件 | 用途 |
|------|------|
| `.sololoop/task_plan.md` | 🆕 v4 增强 Spec 模板，包含 Requirements、AC、Test Cases、Phases |
| `.sololoop/notes.md` | 迭代笔记，追加式记录见解和错误 |
| `.sololoop/deliverable.md` | 交付物，隔离最终输出 |

**规划模式工作流**：
1. Claude 读取 `.sololoop/task_plan.md` 了解当前阶段和验收标准
2. 执行任务并更新复选框进度
3. 在 `.sololoop/notes.md` 记录关键见解
4. Stop Hook 检查复选框完成度
5. 所有复选框勾选后自动退出

**示例 .sololoop/task_plan.md (v4 增强模板)**：
```markdown
# Task Specification

Started: 2026-01-06T10:30:00Z

## Task

用户的任务描述

## Requirements

- REQ-1: 初始需求描述

## Acceptance Criteria

- [ ] AC-1: 可验证的验收条件

## Test Cases

| ID | Input | Expected Output | Status |
|----|-------|-----------------|--------|
| TC-1 | ... | ... | ⬜ |

## Phases

- [ ] Phase 1: 分析需求
- [ ] Phase 2: 设计架构
- [ ] Phase 3: 实现核心功能
- [ ] Phase 4: 编写测试
- [ ] Phase 5: 文档和清理

## Change Log

| Timestamp | Change |
|-----------|--------|
| 2026-01-06T10:30:00Z | Initial spec created |
```

### 🆕 v4 严格规格模式

使用 `--spec` 参数启用严格规格模式，让 Claude 严格遵循 spec 约束：

```bash
# 启用严格规格模式（需配合 --plan）
/sololoop:sololoop "实现用户认证功能" --plan --spec

# 严格模式 + 自定义迭代次数
/sololoop:sololoop "开发支付模块" --plan --spec --max 20
```

**严格模式特性**：
- 强制遵循 Requirements 和 Acceptance Criteria
- 自动验证 Test Cases 中定义的测试用例
- 在 block reason 中列出未完成的验收标准
- 适用于需要高确定性和可验证性的任务

### 🆕 v4 Spec 更新命令

在迭代过程中使用 `/sololoop:update-spec` 命令更新 spec 内容：

```bash
# 追加新需求
/sololoop:update-spec "新增需求：支持用户头像上传"
```

该命令会：
- 将新需求追加到 task_plan.md 的 Requirements 部分
- 在 Change Log 中添加更新时间戳和变更记录
- 输出确认信息显示更新内容

### 🆕 v3 中断恢复机制

当 Bash 命令执行被中断时，SoloLoop v3 会自动处理：

- **自动检测**：从 transcript 检测 "Interrupted" 模式
- **恢复指令**：在 prompt 前添加 "[中断恢复]" 前缀和恢复指导
- **升级处理**：连续中断 3 次以上时，建议替代方案
- **状态跟踪**：记录中断次数，成功迭代后自动重置

这确保了工作流不会因为长时间运行的命令被中断而停止。

## 命令参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| PROMPT | 任务描述（必需） | - |
| --max N | 最大迭代次数 | 10 |
| --promise TEXT | 完成标记 | 无 |
| --plan | 启用规划文件模式 | 禁用 |
| --spec | 🆕 v4 启用严格规格模式（需配合 --plan） | 禁用 |

### 退出条件优先级

v4 优化了退出条件的检查顺序，确保任务完成优先于最大迭代限制：

1. **计划完成**：task_plan.md 中所有复选框都勾选
2. **承诺匹配**：检测到 `<promise>TEXT</promise>` 精确匹配
3. **最大迭代**：达到 --max 指定的次数（安全网）

## 工作原理

1. **setup-sololoop.sh**：解析参数，创建状态文件 `.claude/sololoop.local.md`，如果 `--plan` 则创建 `.sololoop/` 目录和规划文件
2. **stop-hook.sh**：在 Claude 尝试停止时被调用，检查状态文件和规划文件，决定是否继续循环；v3 增加中断检测和恢复
3. **状态文件**：使用 YAML frontmatter 存储迭代计数、最大次数、完成标记、规划模式标志、中断计数（v3）

### Stop Hook 决策逻辑

```
状态文件不存在？ → 允许退出
达到最大迭代？ → 允许退出，删除状态文件
检测到完成标记？ → 允许退出，删除状态文件
规划模式且复选框全勾选？ → 允许退出，删除状态文件
🆕 检测到 Bash 中断？ → 阻止退出，添加恢复指令继续迭代
否则 → 阻止退出，返回 prompt + .sololoop/task_plan.md 引用继续迭代
```

### 状态文件格式 (v4)

```markdown
---
iteration: 1
max_iterations: 10
completion_promise: "DONE"
plan_mode: true
spec_strict: true
started_at: "2026-01-06T10:30:00Z"
interruption_count: 0
last_interruption_type: null
---

实现一个计算器功能，包括加减乘除运算。
```

## 文件结构

```
sololoop/
├── .claude-plugin/
│   ├── plugin.json          # 插件元数据（v4.0.0）
│   └── marketplace.json     # Marketplace 配置
├── commands/
│   ├── sololoop.md          # 启动命令（支持 --plan --spec）
│   ├── cancel-sololoop.md   # 取消命令
│   └── update-spec.md       # 🆕 v4 Spec 更新命令
├── hooks/
│   ├── hooks.json           # Hook 配置
│   └── stop-hook.sh         # Stop Hook 脚本（v4 增强：退出优先级、AC 解析）
├── scripts/
│   ├── setup-sololoop.sh    # 初始化脚本（v4 增强：增强 Spec 模板）
│   ├── cancel-sololoop.sh   # 取消脚本
│   └── update-spec.sh       # 🆕 v4 Spec 更新脚本
├── tests/                   # 测试文件
│   ├── setup-sololoop.bats
│   ├── stop-hook.bats
│   ├── update-spec.bats     # 🆕 v4 新增
│   ├── cancel-sololoop.bats
│   └── helpers/
└── README.md

# v4 规划模式生成的文件
project/
├── .claude/
│   └── sololoop.local.md    # 状态文件（v4 增加 spec_strict 字段）
└── .sololoop/               # 规划文件目录
    ├── task_plan.md         # 🆕 v4 增强 Spec 模板
    ├── notes.md             # 迭代笔记
    └── deliverable.md       # 交付物
```

## 故障排除

| 问题 | 解决方案 |
|------|----------|
| Unknown slash command | 检查插件是否正确加载，使用 `claude --debug` 查看日志 |
| 权限错误 | 使用 `--dangerously-skip-permissions` 或手动添加权限 |
| 循环没有启动 | 检查 prompt 是否为空，--max 是否为正整数 |
| 循环没有停止 | 运行 `/sololoop:cancel-sololoop` 或删除 `.claude/sololoop.local.md` |
| 规划文件未创建 | 确认使用了 `--plan` 参数，检查 `.sololoop/` 目录 |
| 复选框进度不更新 | 确保 Claude 正确编辑 `.sololoop/task_plan.md` 中的复选框 |
| 中断后循环停止 | 升级到 v3+，自动处理 Bash 中断 |
| 迭代次数不准确 | 升级到 v3+，严格按照 `--max` 执行 |
| 🆕 --spec 无效 | 确认同时使用了 `--plan` 参数 |
| 🆕 验收标准未检查 | 确认 task_plan.md 包含 Acceptance Criteria 部分 |
| 🆕 update-spec 失败 | 确认 `.sololoop/task_plan.md` 文件存在 |

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

```json
{
  "decision": "block",
  "reason": "继续迭代的 prompt 内容"
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
| v4.0.0 | 规格驱动规划：增强 Spec 模板、`--spec` 严格模式、退出条件优先级优化、`/sololoop:update-spec` 命令 |
| v3.0.0 | 中断恢复机制、`.sololoop/` 目录结构、严格退出条件、中断计数跟踪 |
| v2.0.0 | 规划文件模式 (`--plan`)、复选框进度跟踪、task_plan.md/notes.md/deliverable.md |
| v1.0.0 | 基础迭代循环、Stop Hook 机制、`--max` 和 `--promise` 参数 |

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
