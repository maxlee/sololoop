# SoloLoop Plugin

Claude Code 迭代循环插件，让 Claude 在同一任务上持续迭代直到完成。

[![GitHub](https://img.shields.io/badge/GitHub-maxlee%2Fsololoop-blue)](https://github.com/maxlee/sololoop)
[![Version](https://img.shields.io/badge/version-8.0.0-green)](https://github.com/maxlee/sololoop)

## 什么是 SoloLoop？

SoloLoop 通过 Stop Hook 机制拦截 Claude 的退出尝试，将相同的 prompt 反复输入，实现自引用的迭代改进。

**v8 增强版本**：新增插件包装器模式、会话恢复检测、重复失败检测、使用统计追踪。

```
用户运行 /sololoop:sololoop "任务描述" --max 10
    ↓
Claude 处理任务
    ↓
Claude 尝试退出
    ↓
Stop Hook 拦截，检查 Promise 标记
    ↓
重复直到 Promise 匹配或达到最大迭代次数
```

### v8 核心增强

| 特性 | v7 | v8 |
|------|----|----|
| 插件包装器 | 无 | `/sololoop:wrap` 包装任意插件命令 |
| 会话恢复 | 无 | SessionStart Hook 检测未完成循环 |
| 重复失败检测 | 无 | 连续 3 次相同错误时建议换策略 |
| 使用统计 | 无 | `/sololoop:stats` 查看统计数据 |
| 优雅退出 | 基础 | 增强的退出状态和原因说明 |

### v7 核心修复

| 问题 | v6 | v7 |
|------|----|----|
| hooks.json 格式 | 扁平数组（错误） | 嵌套对象（官方规范） |
| OpenSpec 默认 Promise | `DONE` | 无默认值 |
| Stop Hook 触发 | 从未触发 | 正常工作 |

### v6 核心变更

| 特性 | v5 | v6 |
|------|----|----|
| 退出条件 | 复选框 100% 或 Promise | 仅 Promise 驱动 |
| 变更列表 | 手动输入名称 | `+` 触发符快速列出 |
| 默认 Promise | 无 | `DONE` |
| 自我审查 | 无 | Prompt 包含审查指引 |

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

### 🆕 v6 OpenSpec 集成模式（推荐）

使用 `/sololoop:openspec` 命令与 OpenSpec 无缝集成：

```bash
# 🆕 v6: 列出所有可用变更
/sololoop:openspec +

# 基本用法
/sololoop:openspec feature-name

# 指定最大迭代次数
/sololoop:openspec feature-name --max 20

# 使用完成标记（v6 默认为 DONE）
/sololoop:openspec feature-name --promise "DONE" --max 15
```

**前置条件**：
1. 项目中已安装 OpenSpec（存在 `openspec/` 目录）
2. 已创建变更目录 `openspec/changes/<feature-name>/`
3. 变更目录中存在 `tasks.md` 文件

**🆕 v6 `+` 触发符**：

快速查看所有可用的 OpenSpec 变更：

```bash
/sololoop:openspec +
```

输出示例：
```
📂 可用的 OpenSpec 变更：

  ✅ user-auth
  ✅ payment-integration
  ⚠️ new-feature (缺少 tasks.md)

请使用完整命令：
  /sololoop:openspec <feature-name>
```

**🆕 v6 Promise 驱动退出**：

v6 移除了「复选框 100% = 自动退出」的逻辑，改为 Promise 驱动：

1. 复选框完成不会自动退出循环
2. Claude 需要输出 `<promise>DONE</promise>` 才能退出
3. 这让 Claude 有机会在退出前进行自我审查

**OpenSpec 模式工作流**：
1. 桥接脚本检查 OpenSpec 目录和 tasks.md 文件
2. 自动构建引用 tasks.md 的 prompt（包含 Promise 退出说明）
3. Claude 按照 tasks.md 执行任务并勾选复选框
4. 完成所有任务后，Claude 进行自我审查
5. 确认完成后，Claude 输出 `<promise>DONE</promise>` 退出循环

**自动构建的 Prompt**：
```
按照 openspec/changes/<feature-name>/tasks.md 实现所有任务。

参考规格：openspec/changes/<feature-name>/specs/
项目约定：openspec/project.md（如存在）

## 任务执行规则

1. 完成每个任务后在 tasks.md 中勾选对应复选框
2. 复选框完成不会自动退出循环
3. 完成所有任务后，进行自我审查：
   - 检查是否有遗漏的任务
   - 检查是否有需要改进的地方
   - 确认代码质量符合预期
4. 确认一切完成后，输出 <promise>DONE</promise> 退出循环
```

### 🆕 Manus 最佳实践（Steering 模板）

SoloLoop 提供 Manus 工作流最佳实践的 Steering 模板，包含：
- **2-Action Rule**：双动作规则，防止信息丢失
- **3-Strike Protocol**：三振出局协议，智能错误处理
- **5-Question Test**：五问重启测试，上下文恢复

```bash
# 初始化 Steering 模板到项目
/sololoop:init-steering

# 使用时通过 # 手动触发
#manus-rules 执行复杂的重构任务...
```

> 💡 这些规则通过 Claude Code 原生 Steering 机制实现，与 SoloLoop 循环引擎完全解耦。

### 🆕 v8 插件包装器模式

使用 `/sololoop:wrap` 命令将循环能力应用到任意插件命令：

```bash
# 基本用法：包装其他插件命令
/sololoop:wrap "@code-review:review src/"

# 指定最大迭代次数
/sololoop:wrap "@linter:fix ." --max 5

# 使用完成标记
/sololoop:wrap "@test:run" --promise "ALL_TESTS_PASSED" --max 15
```

**工作原理**：
1. wrap 命令创建状态文件，标记 `wrap_mode: true`
2. Stop Hook 检测到包装模式，构建 Skill Tool 调用指令
3. Claude 使用 Skill Tool 执行被包装的命令
4. 循环继续直到 Promise 匹配或达到最大迭代次数

**参数说明**：
| 参数 | 必需 | 默认值 | 说明 |
|------|------|--------|------|
| `<plugin-command>` | 是 | - | 要包装的插件命令，需用引号包裹 |
| `--max <N>` | 否 | 10 | 最大迭代次数 |
| `--promise <TEXT>` | 否 | - | 完成标记文本 |

### 🆕 v8 使用统计

查看 SoloLoop 使用统计：

```bash
/sololoop:stats
```

输出示例：
```
📊 SoloLoop 使用统计

总会话数: 42
总迭代数: 156
平均迭代: 3.7

退出原因分布:
  promise_matched: 28
  max_iterations: 12
  user_cancelled: 2
```

统计数据存储在 `~/.claude/sololoop/stats.json`，跨项目共享。

### 🆕 v8 会话恢复检测

当会话启动时，如果检测到未完成的循环，会自动提示：

```
⚠️ 检测到未完成的 SoloLoop 循环 (3/10)。
继续: 直接运行命令；重新开始: 先运行 /sololoop:cancel-sololoop
```

这通过 SessionStart Hook 实现，确保不会丢失进度。

### 🆕 v8 重复失败检测

当连续 3 次遇到相同错误时，Stop Hook 会在 systemMessage 中添加建议：

```
🔄 SoloLoop 迭代 5/10 | ⚠️ 检测到连续 3 次相同错误，建议换一种方法
```

这帮助避免在同一问题上浪费迭代次数。

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

### /sololoop:wrap（🆕 v8 插件包装器模式）

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `<plugin-command>` | 要包装的插件命令（必需，需引号包裹） | - |
| --max N | 最大迭代次数 | 10 |
| --promise TEXT | 完成标记 | 无 |

### /sololoop:openspec（OpenSpec 集成模式）

| 参数 | 说明 | 默认值 |
|------|------|--------|
| change-name | OpenSpec 变更名称（必需） | - |
| + | 列出所有可用变更 | - |
| --max N | 最大迭代次数 | 10 |
| --promise TEXT | 完成标记（可选，不设置则仅依赖最大迭代次数退出） | 无 |

### /sololoop:stats（🆕 v8 使用统计）

无参数，显示 SoloLoop 使用统计信息。

### /sololoop:init-steering（Steering 模板初始化）

无参数，将 Manus 最佳实践模板复制到项目的 `.claude/steering/` 目录。

### /sololoop:cancel-sololoop（取消循环）

无参数，删除状态文件并终止当前循环。

### 退出条件优先级

v6 简化了退出条件，采用 Promise 驱动：

1. **Promise 匹配**：检测到 `<promise>TEXT</promise>` 精确匹配（优先级 1）
2. **最大迭代**：达到 --max 指定的次数（优先级 2，安全网）

> ⚠️ **v6 变更**：复选框 100% 完成不再触发自动退出，仅作为进度指示器显示。

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
检测到完成标记 (Promise)？ → 允许退出，删除状态文件
达到最大迭代？ → 允许退出，删除状态文件
检测到 Bash 中断？ → 阻止退出，systemMessage 添加恢复指令
否则 → 阻止退出，返回原始 prompt 继续迭代
```

> ⚠️ **v6 变更**：复选框 100% 完成不再作为退出条件，仅在 systemMessage 中显示进度。

### 状态文件格式 (v8)

```markdown
---
iteration: 1
max_iterations: 10
completion_promise: "DONE"
wrap_mode: false              # 🆕 v8: 包装器模式标记
wrapped_command: ""           # 🆕 v8: 被包装的命令
same_error_count: 0           # 🆕 v8: 连续相同错误计数
last_error: ""                # 🆕 v8: 上次错误信息
session_id: "abc123"          # 🆕 v8: 会话 ID
openspec_mode: false
openspec_tasks_file: ""
started_at: "2026-01-13T10:30:00Z"
interruption_count: 0
last_interruption_type: null
---

原始 prompt 内容...
```

### Hook 输出格式 (v8)

v8 增强了 Hook 输出，支持优雅退出和重复失败检测：

**继续迭代**：
```json
{
  "decision": "block",
  "reason": "原始 prompt 内容（纯净）",
  "systemMessage": "🔄 SoloLoop 迭代 2/10 | 进度: 22/22 (100%) | 等待完成标记"
}
```

**继续迭代（检测到重复失败）**：
```json
{
  "decision": "block",
  "reason": "原始 prompt 内容",
  "systemMessage": "🔄 SoloLoop 迭代 5/10 | ⚠️ 检测到连续 3 次相同错误，建议换一种方法"
}
```

**允许退出（Promise 匹配）**：
```json
{
  "decision": "allow",
  "continue": false,
  "stopReason": "✅ SoloLoop 完成：Promise 匹配成功"
}
```

**允许退出（最大迭代）**：
```json
{
  "decision": "allow",
  "continue": false,
  "stopReason": "⚠️ SoloLoop 完成：达到最大迭代次数 (10/10)"
}
```

## 文件结构

```
sololoop/
├── .claude-plugin/
│   ├── plugin.json          # 插件元数据（v8.0.0）
│   └── marketplace.json     # Marketplace 配置
├── commands/
│   ├── sololoop.md          # 纯循环命令
│   ├── openspec.md          # OpenSpec 桥接命令
│   ├── cancel-sololoop.md   # 取消命令
│   ├── wrap.md              # 🆕 v8 插件包装器命令
│   ├── stats.md             # 🆕 v8 统计命令
│   └── init-steering.md     # 初始化 Steering 模板命令
├── hooks/
│   ├── hooks.json           # Hook 配置（v8: 新增 SessionStart）
│   ├── stop-hook.sh         # Stop Hook 脚本（v8: 重复失败检测、统计更新）
│   └── session-start.sh     # 🆕 v8 SessionStart Hook 脚本
├── scripts/
│   ├── setup-sololoop.sh    # 初始化脚本（v8: 扩展状态字段）
│   ├── openspec-bridge.sh   # OpenSpec 桥接脚本
│   ├── cancel-sololoop.sh   # 取消脚本
│   ├── wrap-plugin.sh       # 🆕 v8 包装器脚本
│   ├── show-stats.sh        # 🆕 v8 统计显示脚本
│   └── init-steering.sh     # Steering 模板初始化脚本
├── steering/                # Steering 模板目录
│   └── manus-rules.md       # Manus 最佳实践模板
├── tests/                   # 测试文件
│   ├── setup-sololoop.bats
│   ├── openspec-bridge.bats
│   ├── stop-hook.bats
│   ├── cancel-sololoop.bats
│   ├── command-format.bats
│   ├── integration.bats
│   ├── wrap-plugin.bats     # 🆕 v8 包装器测试
│   ├── stats.bats           # 🆕 v8 统计测试
│   ├── session-start.bats   # 🆕 v8 会话恢复测试
│   ├── format-compliance-v8.bats  # 🆕 v8 格式合规测试
│   ├── state-cleanup.bats   # 🆕 v8 状态清理测试
│   └── helpers/
└── README.md

# 运行时生成的文件
project/
└── .claude/
    └── sololoop.local.md    # 状态文件（v8: 扩展字段）

# 全局统计文件（🆕 v8）
~/.claude/sololoop/
└── stats.json               # 使用统计数据
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
| openspec 命令失败 | 确认 `openspec/` 目录存在且包含 tasks.md |
| --plan/--spec 警告 | 这些参数已废弃，请使用 `/sololoop:openspec` |
| 进度不显示 | 确认 tasks.md 中使用标准复选框格式 `- [ ]` / `- [x]` |
| 复选框 100% 但不退出 | 正常行为，需要输出 `<promise>DONE</promise>` 才能退出 |
| `+` 触发符无输出 | 确认 `openspec/changes/` 目录存在 |
| 🆕 wrap 命令无效 | 确认插件命令格式正确，需用引号包裹 |
| 🆕 stats 无数据 | 首次使用，完成一次循环后会有统计数据 |
| 🆕 会话恢复提示 | 正常行为，可继续或运行 `/sololoop:cancel-sololoop` 重新开始 |
| 🆕 重复失败建议 | 连续 3 次相同错误时的正常提示，建议尝试不同方法 |

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

v8 采用 `systemMessage` 分离迭代信息，支持优雅退出：

**阻止退出**：
```json
{
  "decision": "block",
  "reason": "原始 prompt（纯净）",
  "systemMessage": "🔄 SoloLoop 迭代 2/10 | 进度: 3/5 (60%) | 等待完成标记"
}
```

**允许退出**：
```json
{
  "decision": "allow",
  "continue": false,
  "stopReason": "✅ SoloLoop 完成：Promise 匹配成功"
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
| v8.0.0 | 插件包装器模式、会话恢复检测、重复失败检测、使用统计追踪、优雅退出增强 |
| v7.0.0 | 修复 hooks.json 格式符合官方规范、移除 OpenSpec 默认 Promise、Stop Hook 正常触发 |
| v6.0.0 | Promise 驱动退出、`+` 触发符列出变更、默认 Promise 为 DONE、移除复选框自动退出 |
| v5.0.0 | 架构重构：职责分离、移除 `--plan`/`--spec`、新增 `/sololoop:openspec` 桥接、systemMessage 分离迭代信息 |
| v4.0.0 | 规格驱动规划：增强 Spec 模板、`--spec` 严格模式、退出条件优先级优化、`/sololoop:update-spec` 命令 |
| v3.0.0 | 中断恢复机制、`.sololoop/` 目录结构、严格退出条件、中断计数跟踪 |
| v2.0.0 | 规划文件模式 (`--plan`)、复选框进度跟踪、task_plan.md/notes.md/deliverable.md |
| v1.0.0 | 基础迭代循环、Stop Hook 机制、`--max` 和 `--promise` 参数 |

### v8 迁移指南

从 v7 迁移到 v8：

1. **新增命令**：
   - `/sololoop:wrap` - 包装任意插件命令使其具有循环能力
   - `/sololoop:stats` - 查看使用统计

2. **新增 Hook**：SessionStart Hook 自动检测未完成的循环

3. **状态文件扩展**：新增 `wrap_mode`、`wrapped_command`、`same_error_count`、`last_error`、`session_id` 字段

4. **统计文件**：使用统计存储在 `~/.claude/sololoop/stats.json`

5. **向后兼容**：所有 v7 功能保持不变

### v7 迁移指南

从 v6 迁移到 v7：

1. **hooks.json 格式变更**：v7 使用官方规范的嵌套对象格式，Stop Hook 现在能正确触发
2. **OpenSpec 默认 Promise 移除**：不再自动设置 `COMPLETION_PROMISE="DONE"`，需要显式使用 `--promise` 参数

### v6 迁移指南

从 v5 迁移到 v6：

1. **退出行为变更**：复选框 100% 完成不再自动退出，需要 Claude 输出 `<promise>DONE</promise>`
2. **默认 Promise**：v6 默认使用 `DONE` 作为完成标记，无需手动指定 `--promise`
3. **新功能**：使用 `/sololoop:openspec +` 快速查看可用变更

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
