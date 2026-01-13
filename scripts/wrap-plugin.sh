#!/bin/bash
# ============================================================================
# SoloLoop Wrap Plugin Script - 包装其他插件命令
# ============================================================================
#
# 功能说明：
#   将 SoloLoop 的迭代循环能力应用到其他插件命令。
#
# 使用方法：
#   /sololoop:wrap "<plugin-command>" --max 10 --promise "DONE"
#
# 参数说明：
#   "<plugin-command>"  要包装的插件命令（必需，需用引号包裹）
#   --max <n>           最大迭代次数（默认：10）
#   --promise <t>       完成标记文本
#   --help              显示帮助信息
#
# ============================================================================

set -euo pipefail

# ----------------------------------------------------------------------------
# 默认值
# ----------------------------------------------------------------------------
PLUGIN_COMMAND=""
MAX_ITERATIONS=10
COMPLETION_PROMISE=""

# ----------------------------------------------------------------------------
# 解析命令行参数
# ----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'EOF'
SoloLoop Wrap - 包装其他插件命令

用法：
  /sololoop:wrap "<plugin-command>" [选项]

选项：
  --max <n>       最大迭代次数（默认：10）
  --promise <t>   完成标记（多词需加引号）
  -h, --help      显示帮助

示例：
  /sololoop:wrap "@code-review:review src/"
  /sololoop:wrap "@linter:fix ." --max 5
  /sololoop:wrap "@test:run" --promise "ALL_TESTS_PASSED"

工作流程：
  1. 创建状态文件，记录被包装的命令
  2. 输出 Skill Tool 使用指令
  3. Stop Hook 检测 wrap_mode，构造循环 prompt
  4. 循环执行直到完成

退出条件：
  1. 输出 <promise>完成标记</promise>
  2. 达到最大迭代次数
  3. 运行 /sololoop:cancel-sololoop
EOF
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
    *)
      # 第一个非选项参数作为 plugin-command
      if [[ -z "$PLUGIN_COMMAND" ]]; then
        PLUGIN_COMMAND="$1"
      else
        echo "❌ 错误：多余的参数 '$1'" >&2
        echo "提示：plugin-command 需要用引号包裹" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

# ----------------------------------------------------------------------------
# 验证 plugin-command
# ----------------------------------------------------------------------------
if [[ -z "$PLUGIN_COMMAND" ]]; then
  echo "❌ 错误：请提供要包装的插件命令" >&2
  echo "示例：/sololoop:wrap \"@code-review:review src/\" --max 5" >&2
  exit 1
fi

# ----------------------------------------------------------------------------
# 创建状态文件
# v8: 添加 wrap_mode, wrapped_command, same_error_count, last_error, session_id
# ----------------------------------------------------------------------------
mkdir -p .claude

if [[ -n "$COMPLETION_PROMISE" ]]; then
  PROMISE_YAML="\"$COMPLETION_PROMISE\""
else
  PROMISE_YAML="null"
fi

# 获取 session_id（如果可用）
SESSION_ID="${CLAUDE_SESSION_ID:-}"

cat > .claude/sololoop.local.md << EOF
---
iteration: 1
max_iterations: $MAX_ITERATIONS
completion_promise: $PROMISE_YAML
wrap_mode: true
wrapped_command: "$PLUGIN_COMMAND"
same_error_count: 0
last_error: ""
session_id: "$SESSION_ID"
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
interruption_count: 0
last_interruption_type: null
---

请使用 Skill Tool 执行以下命令：$PLUGIN_COMMAND

每次迭代后，评估结果并决定是否需要继续改进。
EOF

# 添加 promise 指令（如果设置了）
if [[ -n "$COMPLETION_PROMISE" ]]; then
  echo "当任务完成时，输出 <promise>$COMPLETION_PROMISE</promise>" >> .claude/sololoop.local.md
fi

# ----------------------------------------------------------------------------
# 输出启动信息
# ----------------------------------------------------------------------------
echo "🔄 SoloLoop Wrap 模式已启动！"
echo ""
echo "包装命令：$PLUGIN_COMMAND"
echo "迭代：1 / $MAX_ITERATIONS"
if [[ -n "$COMPLETION_PROMISE" ]]; then
  echo "完成标记：$COMPLETION_PROMISE"
fi
echo ""
echo "📋 完成条件（按优先级）："
if [[ -n "$COMPLETION_PROMISE" ]]; then
  echo "  1. 输出 <promise>$COMPLETION_PROMISE</promise>"
  echo "  2. 达到最大迭代次数 ($MAX_ITERATIONS)"
else
  echo "  1. 达到最大迭代次数 ($MAX_ITERATIONS)"
fi
echo "  - 运行 /sololoop:cancel-sololoop 取消"
echo ""
echo "--- Skill Tool 使用指令 ---"
echo ""
echo "请使用 Skill Tool 执行以下命令："
echo "  $PLUGIN_COMMAND"
echo ""
echo "执行后评估结果，决定是否需要继续迭代改进。"
