---
description: "启动 SoloLoop 迭代循环 - 支持规格驱动规划模式"
argument-hint: "PROMPT [--max N] [--promise TEXT] [--plan] [--spec]"
allowed-tools: Bash(*)
---

# SoloLoop 命令

启动迭代循环，让 Claude 在同一任务上持续工作直到完成。

## 参数说明

- `PROMPT`: 任务描述（必需）
- `--max N`: 最大迭代次数，默认 10
- `--promise TEXT`: 完成标记文本
- `--plan`: 启用规划文件模式，创建增强 Spec 模板
- `--spec`: 🆕 v4 启用严格规格模式（需配合 `--plan` 使用）

## 使用示例

基本用法：
```
/sololoop:sololoop "实现一个计算器功能"
```

设置最大迭代次数：
```
/sololoop:sololoop "重构代码" --max 5
```

使用完成标记：
```
/sololoop:sololoop "修复 bug" --promise "BUG_FIXED"
```

启用规划文件模式：
```
/sololoop:sololoop "开发新功能" --plan --max 20
```

🆕 v4 启用严格规格模式：
```
/sololoop:sololoop "实现用户认证功能" --plan --spec --max 15
```

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-sololoop.sh" $ARGUMENTS
```

## 工作流程

循环启动后，请开始处理任务。当你尝试退出时，Stop Hook 会将相同的 prompt 反馈回来，让你继续迭代改进。

### 退出条件（优先级从高到低）

1. **计划完成**：如果启用 `--plan` 模式，当 task_plan.md 中所有复选框都勾选时退出
2. **承诺匹配**：如果设置了完成标记，输出 `<promise>完成标记</promise>` 匹配时退出
3. **最大迭代**：达到最大迭代次数时强制退出（安全网）

> 💡 v4 优化：退出条件按优先级检查，任务完成优先于最大迭代限制，确保循环及时终止。

### 规划文件模式 (--plan)

启用后会在 `.sololoop/` 目录创建以下文件：
- `.sololoop/task_plan.md`: 🆕 v4 增强 Spec 模板，包含 Requirements、Acceptance Criteria、Test Cases、Phases
- `.sololoop/notes.md`: 迭代笔记，追加式记录
- `.sololoop/deliverable.md`: 交付物文件

每次迭代时请检查 `.sololoop/task_plan.md` 更新进度，勾选已完成的任务。

### 🆕 v4 严格规格模式 (--spec)

启用 `--spec` 参数后，Claude 将严格遵循 spec 中定义的约束：

**功能特性：**
- 强制遵循 `.sololoop/task_plan.md` 中的 Requirements 和 Acceptance Criteria
- 自动验证 Test Cases 中定义的测试用例
- 在 block reason 中列出未完成的验收标准

**使用建议：**
- 适用于需要高确定性和可验证性的任务
- 建议先完善 spec 内容再启用严格模式
- 可配合 `/sololoop:update-spec` 命令中途调整需求

**示例 .sololoop/task_plan.md (v4 增强模板)：**
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
- [ ] Phase 2: 设计方案
- [ ] Phase 3: 实现核心功能
- [ ] Phase 4: 测试验证
- [ ] Phase 5: 文档和清理

## Change Log

| Timestamp | Change |
|-----------|--------|
| 2026-01-06T10:30:00Z | Initial spec created |
```

#### ⚠️ 规划文件使用须知

**规划文件仅在使用 `--plan` 参数时创建和使用：**
- 规划文件（`.sololoop/` 目录）只有在启动任务时明确指定 `--plan` 参数才会被创建
- 如果不使用 `--plan` 参数，即使 `.sololoop/` 目录已存在，也不会被读取或修改

**已存在的规划文件不会自动使用：**
- 如果之前的任务创建了规划文件，新任务不会自动继承这些文件
- 新任务必须显式使用 `--plan` 参数才能操作规划文件
- 不使用 `--plan` 启动时，系统会显示警告提示已存在的规划文件

**建议：相关任务应一致使用 `--plan`：**
- 如果一个项目需要使用规划文件，建议所有相关任务都使用 `--plan` 参数
- 这样可以确保任务进度的连续性和规划文件的正确更新
- 混合使用（有时用 `--plan`，有时不用）可能导致规划文件状态不一致

### 中断恢复机制 (v3)

当 Bash 命令执行被中断时，SoloLoop 会自动检测并添加恢复指令：
- 检测到中断后，会在 prompt 前添加 "[中断恢复]" 前缀
- 自动添加 "继续执行任务，跳过或重试失败的命令" 指令
- 连续中断 3 次以上时，会建议替代方案

这确保了工作流不会因为命令中断而停止，无需手动干预。

### 🆕 v4 Spec 更新命令

在迭代过程中可以使用 `/sololoop:update-spec` 命令更新 spec 内容：

```
/sololoop:update-spec "新增需求：支持用户头像上传"
```

该命令会：
- 将新需求追加到 task_plan.md 的 Requirements 部分
- 在 Change Log 中添加更新时间戳和变更记录
- 输出确认信息显示更新内容
