---
description: "更新 SoloLoop Spec - 在迭代过程中追加新需求"
argument-hint: "DESCRIPTION"
allowed-tools: Bash(*)
---

# Update-Spec 命令

在 SoloLoop 迭代过程中更新 spec 内容，将新需求追加到 task_plan.md。

## 参数说明

- `DESCRIPTION`: 要追加的需求描述（必需）

## 使用示例

追加新需求：
```
/sololoop:update-spec "添加用户认证功能"
```

追加多个需求点：
```
/sololoop:update-spec "1. 支持 OAuth 登录 2. 添加密码重置功能"
```

## 前置条件

- 必须先使用 `--plan` 模式启动 SoloLoop
- `.sololoop/task_plan.md` 文件必须存在

## 行为说明

执行此命令后：
1. 新需求会追加到 task_plan.md 的 Requirements 部分
2. Change Log 部分会记录更新时间戳和变更描述
3. 输出确认信息显示更新内容

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/update-spec.sh" $ARGUMENTS
```

## 注意事项

- 如果 task_plan.md 不存在，命令会输出错误提示并建议使用 `--plan` 模式启动
- 更新后请检查 task_plan.md 确认变更内容
- 建议在更新 spec 后重新评估 Acceptance Criteria 和 Test Cases
