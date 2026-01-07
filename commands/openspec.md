---
description: "使用 OpenSpec 规格驱动的迭代循环"
argument-hint: "<change-name> [--max N] [--promise TEXT]"
allowed-tools: Bash(*)
---

# OpenSpec 桥接命令

使用 OpenSpec 规格驱动的迭代循环，让 Claude 按照 tasks.md 中的任务列表持续工作直到完成。

## 参数说明

- `<change-name>`: OpenSpec 变更名称（必需）
- `--max N`: 最大迭代次数，默认 10
- `--promise TEXT`: 完成标记文本

## 前置条件

1. 项目中需要安装 OpenSpec（存在 `openspec/` 目录）
2. 需要创建对应的变更目录 `openspec/changes/<change-name>/`
3. 变更目录中需要存在 `tasks.md` 文件

## 使用示例

基本用法：
```
/sololoop:openspec feature-login
```

设置最大迭代次数：
```
/sololoop:openspec feature-login --max 20
```

使用完成标记：
```
/sololoop:openspec feature-login --promise "FEATURE_DONE"
```

组合使用：
```
/sololoop:openspec feature-login --max 15 --promise "DONE"
```

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/openspec-bridge.sh" $ARGUMENTS
```

## 工作流程

1. 脚本检查 OpenSpec 目录和 tasks.md 文件是否存在
2. 构建引用 tasks.md 的 prompt
3. 创建状态文件并启动迭代循环
4. 每次迭代时检查 tasks.md 中的复选框进度
5. 当所有复选框完成时自动退出

### 退出条件（优先级从高到低）

1. **任务完成**：tasks.md 中所有复选框都勾选时退出
2. **承诺匹配**：如果设置了完成标记，输出 `<promise>完成标记</promise>` 匹配时退出
3. **最大迭代**：达到最大迭代次数时强制退出（安全网）

### 与纯循环模式的区别

- OpenSpec 模式自动跟踪 tasks.md 中的复选框进度
- 无需手动管理规划文件
- 与 OpenSpec 工具链无缝集成
