#!/bin/bash
# ============================================================================
# SoloLoop Setup Script - 初始化迭代循环
# ============================================================================
#
# 功能说明：
#   解析命令行参数，创建状态文件，启动迭代循环。
#   v9: 添加目标记忆状态字段支持
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
# Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6
# ============================================================================

set -euo pipefail

# ----------------------------------------------------------------------------
# 默认值
# ----------------------------------------------------------------------------
PROMPT_PARTS=()
MAX_ITERATIONS=10
COMPLETION_PROMISE=""
DEPRECATED_PARAM_USED=false

# ----------------------------------------------------------------------------
# 解析命令行参数
# ----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'EOF'
SoloLoop v9 - 纯粹的顽强循环引擎（带目标记忆）

用法：
  /sololoop:sololoop "任务描述" [选项]

选项：
  --max <n>       最大迭代次数（默认：10）
  --promise <t>   完成标记（多词需加引号）
  -h, --help      显示帮助

示例：
  /sololoop:sololoop "实现登录功能" --max 5
  /sololoop:sololoop "重构代码" --promise "DONE" --max 20

退出条件（按优先级）：
  1. 输出 <promise>完成标记</promise>
  2. 达到最大迭代次数
  3. 运行 /sololoop:cancel-sololoop

目标记忆（v9 新功能）：
  首次运行时自动初始化 .sololoop/ 目录
  支持周期性重锚和漂移检测

规格驱动开发：
  如需规格驱动的迭代循环，请使用 /sololoop:openspec 命令。
  详见：/sololoop:openspec --help
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
    --plan)
      DEPRECATED_PARAM_USED=true
      echo "⚠️ 警告：--plan 参数已废弃 (deprecated)" >&2
      echo "   请使用 /sololoop:openspec <change-name> 进行规格驱动开发" >&2
      echo "" >&2
      shift
      ;;
    --spec)
      DEPRECATED_PARAM_USED=true
      echo "⚠️ 警告：--spec 参数已废弃 (deprecated)" >&2
      echo "   请使用 /sololoop:openspec <change-name> 进行规格驱动开发" >&2
      echo "" >&2
      shift
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
# 自动初始化目标记忆（v9 新功能）
# 如果 .sololoop/ 目录不存在，自动调用 init-sololoop.sh
# Requirements: 1.2.1, 1.2.2, 1.2.3
# ----------------------------------------------------------------------------
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"
INIT_SCRIPT="$PLUGIN_ROOT/scripts/init-sololoop.sh"

if [[ ! -d ".sololoop" ]]; then
  echo "🎯 首次使用，自动初始化目标记忆..."
  echo ""
  if [[ -x "$INIT_SCRIPT" ]]; then
    # 调用 init-sololoop.sh 并传递 prompt 用于提取目标
    "$INIT_SCRIPT" "$PROMPT"
    echo ""
  else
    # 如果脚本不存在，使用内联初始化
    mkdir -p ".sololoop/archived-goals"
    cat > ".sololoop/goal.md" << EOF
# Current Goal

## Summary

$PROMPT

## Success Criteria

- [ ] 完成上述目标描述的任务
- [ ] 通过所有相关测试
- [ ] 代码符合项目规范

## Scope Boundaries

### 包含 (In Scope)

- 上述目标描述中明确提到的功能

### 不包含 (Out of Scope)

- 未在目标中明确提到的功能扩展
- 性能优化（除非明确要求）
EOF
    cat > ".sololoop/invariants.md" << 'EOF'
# Core Invariants

核心约束清单 - 这些是不可妥协的底线要求。

## Must Have

- [关键约束 1]
- [关键约束 2]

## Must Not

- [禁止事项 1]
- [禁止事项 2]

## Performance Constraints

- [性能要求 1]
EOF
    cat > ".sololoop/decisions-log.md" << 'EOF'
# Decision Log

记录执行过程中的重要决策和目标调整。

---
EOF
    echo "✅ 目标记忆已自动初始化"
    echo ""
  fi
fi

# ----------------------------------------------------------------------------
# 创建状态文件
# 文件格式使用 YAML frontmatter，便于解析
# v8: 添加 wrap_mode, wrapped_command, same_error_count, last_error, session_id
# v9: 添加 goal_memory_enabled, iteration_since_anchor, anchor_interval,
#     drift_warning_count, total_anchors, last_activity_timestamp
# ----------------------------------------------------------------------------
mkdir -p .claude

if [[ -n "$COMPLETION_PROMISE" ]]; then
  PROMISE_YAML="\"$COMPLETION_PROMISE\""
else
  PROMISE_YAML="null"
fi

# 获取 session_id（如果可用）
SESSION_ID="${CLAUDE_SESSION_ID:-}"

# 获取当前时间戳 (ISO 8601 格式)
CURRENT_TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# 检测目标记忆是否启用（.sololoop/ 目录存在）
GOAL_MEMORY_ENABLED="false"
if [[ -d ".sololoop" ]] && [[ -f ".sololoop/goal.md" ]]; then
  GOAL_MEMORY_ENABLED="true"
fi

cat > .claude/sololoop.local.md << EOF
---
iteration: 1
max_iterations: $MAX_ITERATIONS
completion_promise: $PROMISE_YAML
wrap_mode: false
wrapped_command: ""
same_error_count: 0
last_error: ""
session_id: "$SESSION_ID"
started_at: "$CURRENT_TIMESTAMP"
interruption_count: 0
last_interruption_type: null
goal_memory_enabled: $GOAL_MEMORY_ENABLED
iteration_since_anchor: 0
anchor_interval: 15
drift_warning_count: 0
total_anchors: 0
last_activity_timestamp: "$CURRENT_TIMESTAMP"
---

$PROMPT
EOF

# ----------------------------------------------------------------------------
# 输出启动信息
# ----------------------------------------------------------------------------
echo "🔄 SoloLoop v9 循环已启动！"
echo ""
echo "迭代：1 / $MAX_ITERATIONS"
if [[ -n "$COMPLETION_PROMISE" ]]; then
  echo "完成标记：$COMPLETION_PROMISE"
fi
if [[ "$GOAL_MEMORY_ENABLED" == "true" ]]; then
  echo "🎯 [Goal Memory Active]"
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
echo "--- 任务开始 ---"
echo ""
echo "$PROMPT"
