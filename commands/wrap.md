---
description: "包装其他插件命令，使其具有迭代循环能力"
argument-hint: '"<plugin-command>" [--max N] [--promise TEXT]'
allowed-tools: Bash(*)
---

# 包装器命令

将 SoloLoop 的迭代循环能力应用到其他插件命令，让任何命令都能持续执行直到完成。

## 参数说明

- `"<plugin-command>"`: 要包装的插件命令（必需，需用引号包裹）
- `--max N`: 最大迭代次数，默认 10
- `--promise TEXT`: 完成标记文本

## 使用示例

基本用法：
```
/sololoop:wrap "@code-review:review src/"
```

设置最大迭代次数：
```
/sololoop:wrap "@linter:fix ." --max 5
```

使用完成标记：
```
/sololoop:wrap "@test:run" --promise "ALL_TESTS_PASSED"
```

组合使用：
```
/sololoop:wrap "@refactor:optimize src/" --max 20 --promise "DONE"
```

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/wrap-plugin.sh" $ARGUMENTS
```

## 工作流程

1. 包装器创建状态文件，记录被包装的命令
2. 输出 Skill Tool 使用指令，让 Claude 执行被包装的命令
3. Stop Hook 检测到 wrap_mode，构造包含 Skill Tool 调用的 prompt
4. 循环执行直到 Promise 匹配或达到最大迭代次数

### 退出条件

1. **承诺匹配**：输出 `<promise>完成标记</promise>` 匹配时退出
2. **最大迭代**：达到最大迭代次数时强制退出

> 💡 提示：被包装的命令会通过 Skill Tool 机制执行，确保目标插件已正确安装。
