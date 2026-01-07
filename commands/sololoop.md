---
description: "启动 SoloLoop 迭代循环 - 纯粹的顽强循环引擎"
argument-hint: "PROMPT [--max N] [--promise TEXT]"
allowed-tools: Bash(*)
---

# SoloLoop 命令

启动迭代循环，让 Claude 在同一任务上持续工作直到完成。

## 参数说明

- `PROMPT`: 任务描述（必需）
- `--max N`: 最大迭代次数，默认 10
- `--promise TEXT`: 完成标记文本

## ⚠️ 废弃参数警告

以下参数在 v5 中已废弃，使用时会显示警告：

- `--plan`: 已废弃，请使用 `/sololoop:openspec` 命令配合 OpenSpec 进行规格驱动开发
- `--spec`: 已废弃，请使用 `/sololoop:openspec` 命令配合 OpenSpec 进行规格驱动开发

如需规格驱动的迭代循环，请参考 OpenSpec 桥接命令：
```
/sololoop:openspec <change-name> [--max N] [--promise TEXT]
```

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

组合使用：
```
/sololoop:sololoop "开发新功能" --max 20 --promise "DONE"
```

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-sololoop.sh" $ARGUMENTS
```

## 工作流程

循环启动后，请开始处理任务。当你尝试退出时，Stop Hook 会将相同的 prompt 反馈回来，让你继续迭代改进。

### 退出条件（优先级从高到低）

1. **承诺匹配**：如果设置了完成标记，输出 `<promise>完成标记</promise>` 匹配时退出
2. **最大迭代**：达到最大迭代次数时强制退出（安全网）

> 💡 提示：如需规格驱动的任务管理和进度跟踪，请使用 `/sololoop:openspec` 命令。

### 中断恢复机制

当 Bash 命令执行被中断时，SoloLoop 会自动检测并添加恢复指令：
- 检测到中断后，会在 systemMessage 中添加恢复指令
- 自动添加 "继续执行任务，跳过或重试失败的命令" 指令
- 连续中断 3 次以上时，会建议替代方案

这确保了工作流不会因为命令中断而停止，无需手动干预。
