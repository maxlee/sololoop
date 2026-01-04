#!/bin/bash
# ============================================================================
# SoloLoop Setup Script - 初始化迭代循环
# ============================================================================
#
# 功能说明：
#   解析命令行参数，创建状态文件，启动迭代循环。
#
# 使用方法：
#   /sololoop:sololoop "你的任务描述" --max 10 --promise "DONE"
#
# 参数说明：
#   PROMPT        任务描述（必需）
#   --max <n>     最大迭代次数（默认：10）
#   --promise <t> 完成标记文本
#   --help        显示帮助信息
#
# ============================================================================

set -euo pipefail

# ----------------------------------------------------------------------------
# 默认值
# ----------------------------------------------------------------------------
PROMPT_PARTS=()
MAX_ITERATIONS=10
COMPLETION_PROMISE=""

# ----------------------------------------------------------------------------
# 解析命令行参数
# ----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'EOF'
SoloLoop - 简化版迭代循环插件

用法：
  /sololoop:sololoop "任务描述" [选项]

选项：
  --max <n>       最大迭代次数（默认：10）
  --promise <t>   完成标记（多词需加引号）
  -h, --help      显示帮助

示例：
  /sololoop:sololoop "实现登录功能" --max 5
  /sololoop:sololoop "重构代码" --promise "DONE" --max 20

停止方式：
  - 达到最大迭代次数
  - 输出 <promise>完成标记</promise>
  - 运行 /sololoop:cancel-sololoop
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
      PROMPT_PARTS+=("$1")
      shift
      ;;
  esac
done

# ----------------------------------------------------------------------------
# 验证 prompt
# ----------------------------------------------------------------------------
PROMPT="${PROMPT_PARTS[*]:-}"
if [[ -z "$PROMPT" ]]; then
  echo "❌ 错误：请提供任务描述" >&2
  echo "示例：/sololoop:sololoop \"实现登录功能\" --max 5" >&2
  exit 1
fi

# ----------------------------------------------------------------------------
# 创建状态文件
# 文件格式使用 YAML frontmatter，便于解析
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
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

$PROMPT
EOF

# ----------------------------------------------------------------------------
# 输出启动信息
# ----------------------------------------------------------------------------
echo "🔄 SoloLoop 循环已启动！"
echo ""
echo "迭代：1 / $MAX_ITERATIONS"
if [[ -n "$COMPLETION_PROMISE" ]]; then
  echo "完成标记：$COMPLETION_PROMISE"
  echo ""
  echo "完成后请输出：<promise>$COMPLETION_PROMISE</promise>"
fi
echo ""
echo "取消命令：/sololoop:cancel-sololoop"
echo ""
echo "--- 任务开始 ---"
echo ""
echo "$PROMPT"
