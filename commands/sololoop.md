---
description: "启动 SoloLoop 迭代循环 - 支持规划文件模式"
argument-hint: "PROMPT [--max N] [--promise TEXT] [--plan]"
allowed-tools: Bash(*)
---

# SoloLoop 命令

启动迭代循环，让 Claude 在同一任务上持续工作直到完成。

## 参数说明

- `PROMPT`: 任务描述（必需）
- `--max N`: 最大迭代次数，默认 10
- `--promise TEXT`: 完成标记文本
- `--plan`: 启用规划文件模式，创建 task_plan.md、notes.md、deliverable.md

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

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-sololoop.sh" $ARGUMENTS
```

## 工作流程

循环启动后，请开始处理任务。当你尝试退出时，Stop Hook 会将相同的 prompt 反馈回来，让你继续迭代改进。

### 退出条件

1. 达到最大迭代次数
2. 如果设置了完成标记，输出 `<promise>完成标记</promise>` 匹配时退出
3. 如果启用 `--plan` 模式，当 task_plan.md 中所有复选框都勾选时退出

### 规划文件模式 (--plan)

启用后会在 `.sololoop/` 目录创建以下文件：
- `.sololoop/task_plan.md`: 任务计划，包含阶段和复选框进度
- `.sololoop/notes.md`: 迭代笔记，追加式记录
- `.sololoop/deliverable.md`: 交付物文件

每次迭代时请检查 `.sololoop/task_plan.md` 更新进度，勾选已完成的任务。

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
