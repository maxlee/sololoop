#!/bin/bash
# ============================================================================
# OpenSpec Bridge Script - OpenSpec 桥接初始化
# ============================================================================
#
# 功能说明：
#   检查 OpenSpec 前置条件，构建引用 tasks.md 的 prompt，创建状态文件。
#
# 使用方法：
#   /sololoop:openspec <change-name> [--max N] [--promise TEXT]
#
# 参数说明：
#   <change-name>  OpenSpec 变更名称（必需）
#   --max <n>      最大迭代次数（默认：10）
#   --promise <t>  完成标记文本
#   --help         显示帮助信息
#
# ============================================================================

set -euo pipefail

# ----------------------------------------------------------------------------
# 默认值
# ----------------------------------------------------------------------------
CHANGE_NAME=""
MAX_ITERATIONS=10
COMPLETION_PROMISE=""
OPENSPEC_DIR="openspec"

# ----------------------------------------------------------------------------
# 显示帮助信息
# ----------------------------------------------------------------------------
show_help() {
  cat << 'EOF'
SoloLoop v5 OpenSpec 桥接命令

用法：
  /sololoop:openspec <change-name> [选项]

参数：
  <change-name>   OpenSpec 变更名称（必需）

选项：
  --max <n>       最大迭代次数（默认：10）
  --promise <t>   完成标记（多词需加引号）
  -h, --help      显示帮助

示例：
  /sololoop:openspec feature-login
  /sololoop:openspec feature-login --max 20
  /sololoop:openspec feature-login --promise "DONE" --max 15

前置条件：
  1. 项目中需要安装 OpenSpec（存在 openspec/ 目录）
  2. 需要创建对应的变更目录 openspec/changes/<change-name>/
  3. 变更目录中需要存在 tasks.md 文件

退出条件（按优先级）：
  1. tasks.md 中所有复选框完成
  2. 输出 <promise>完成标记</promise>
  3. 达到最大迭代次数
  4. 运行 /sololoop:cancel-sololoop
EOF
}

# ----------------------------------------------------------------------------
# 列出可用的变更目录
# ----------------------------------------------------------------------------
list_available_changes() {
  local changes_dir="$OPENSPEC_DIR/changes"
  if [[ -d "$changes_dir" ]]; then
    local changes
    changes=$(find "$changes_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort)
    if [[ -n "$changes" ]]; then
      echo "可用的变更目录："
      echo "$changes" | while read -r change; do
        if [[ -f "$changes_dir/$change/tasks.md" ]]; then
          echo "  ✅ $change"
        else
          echo "  ⚠️ $change (缺少 tasks.md)"
        fi
      done
    else
      echo "暂无可用的变更目录。"
    fi
  fi
}

# ----------------------------------------------------------------------------
# 解析命令行参数
# ----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      exit 0
      ;;
    --max)
      if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
        echo "❌ 错误：--max 需要一个正整数" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --promise)
      if [[ -z "${2:-}" ]]; then
        echo "❌ 错误：--promise 需要一个文本参数" >&2
        exit 1
      fi
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    -*)
      echo "❌ 错误：未知选项 $1" >&2
      echo "使用 --help 查看帮助信息" >&2
      exit 1
      ;;
    *)
      if [[ -z "$CHANGE_NAME" ]]; then
        CHANGE_NAME="$1"
      else
        echo "❌ 错误：只能指定一个变更名称" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

# ----------------------------------------------------------------------------
# 验证 change-name 参数
# ----------------------------------------------------------------------------
if [[ -z "$CHANGE_NAME" ]]; then
  echo "❌ 错误：请提供 OpenSpec 变更名称" >&2
  echo "示例：/sololoop:openspec feature-login --max 10" >&2
  echo "" >&2
  show_help
  exit 1
fi

# ----------------------------------------------------------------------------
# 前置检查 1: openspec/ 目录存在
# ----------------------------------------------------------------------------
if [[ ! -d "$OPENSPEC_DIR" ]]; then
  echo "❌ 错误：未找到 OpenSpec 目录 ($OPENSPEC_DIR/)" >&2
  echo "" >&2
  echo "请先安装 OpenSpec：" >&2
  echo "  1. 访问 https://github.com/openspec/openspec 获取安装说明" >&2
  echo "  2. 或运行 openspec init 初始化项目" >&2
  exit 1
fi

# ----------------------------------------------------------------------------
# 前置检查 2: openspec/changes/<change-name>/ 目录存在
# ----------------------------------------------------------------------------
CHANGE_DIR="$OPENSPEC_DIR/changes/$CHANGE_NAME"
if [[ ! -d "$CHANGE_DIR" ]]; then
  echo "❌ 错误：未找到变更目录 ($CHANGE_DIR/)" >&2
  echo "" >&2
  list_available_changes >&2
  echo "" >&2
  echo "创建新变更：" >&2
  echo "  openspec change new $CHANGE_NAME" >&2
  exit 1
fi

# ----------------------------------------------------------------------------
# 前置检查 3: tasks.md 文件存在
# ----------------------------------------------------------------------------
TASKS_FILE="$CHANGE_DIR/tasks.md"
if [[ ! -f "$TASKS_FILE" ]]; then
  echo "❌ 错误：未找到任务文件 ($TASKS_FILE)" >&2
  echo "" >&2
  echo "请在变更目录中创建 tasks.md 文件：" >&2
  echo "  openspec change tasks $CHANGE_NAME" >&2
  exit 1
fi

# ----------------------------------------------------------------------------
# 构建 prompt
# ----------------------------------------------------------------------------
PROMPT="按照 $TASKS_FILE 实现所有任务。

参考规格：$CHANGE_DIR/specs/（如存在）
项目约定：$OPENSPEC_DIR/project.md（如存在）

完成每个任务后在 tasks.md 中勾选对应复选框。"

# ----------------------------------------------------------------------------
# 创建状态文件
# ----------------------------------------------------------------------------
mkdir -p .claude

if [[ -n "$COMPLETION_PROMISE" ]]; then
  PROMISE_YAML="\"$COMPLETION_PROMISE\""
else
  PROMISE_YAML="null"
fi

cat > .claude/sololoop.local.md << EOF
---
iteration: 1
max_iterations: $MAX_ITERATIONS
completion_promise: $PROMISE_YAML
openspec_mode: true
openspec_tasks_file: "$TASKS_FILE"
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
interruption_count: 0
last_interruption_type: null
---

$PROMPT
EOF

# ----------------------------------------------------------------------------
# 计算初始进度
# ----------------------------------------------------------------------------
TOTAL_CHECKBOXES=$(grep -cE '^\s*-\s*\[[ xX]\]' "$TASKS_FILE" 2>/dev/null) || TOTAL_CHECKBOXES=0
CHECKED_CHECKBOXES=$(grep -cE '^\s*-\s*\[[xX]\]' "$TASKS_FILE" 2>/dev/null) || CHECKED_CHECKBOXES=0
if [[ "$TOTAL_CHECKBOXES" -gt 0 ]]; then
  PROGRESS_PCT=$((CHECKED_CHECKBOXES * 100 / TOTAL_CHECKBOXES))
else
  PROGRESS_PCT=0
fi

# ----------------------------------------------------------------------------
# 输出启动信息
# ----------------------------------------------------------------------------
echo "🔄 SoloLoop v5 OpenSpec 模式已启动！"
echo ""
echo "变更名称：$CHANGE_NAME"
echo "任务文件：$TASKS_FILE"
echo "迭代：1 / $MAX_ITERATIONS"
echo "进度：$CHECKED_CHECKBOXES / $TOTAL_CHECKBOXES ($PROGRESS_PCT%)"
if [[ -n "$COMPLETION_PROMISE" ]]; then
  echo "完成标记：$COMPLETION_PROMISE"
fi
echo ""
echo "📋 完成条件（按优先级）："
echo "  1. 完成 $TASKS_FILE 中所有复选框"
if [[ -n "$COMPLETION_PROMISE" ]]; then
  echo "  2. 输出 <promise>$COMPLETION_PROMISE</promise>"
  echo "  3. 达到最大迭代次数 ($MAX_ITERATIONS)"
else
  echo "  2. 达到最大迭代次数 ($MAX_ITERATIONS)"
fi
echo "  - 运行 /sololoop:cancel-sololoop 取消"
echo ""
echo "--- 任务开始 ---"
echo ""
echo "$PROMPT"
