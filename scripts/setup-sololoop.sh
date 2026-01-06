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
PLAN_MODE=false
PLANNING_DIR=".sololoop"

# ----------------------------------------------------------------------------
# 解析命令行参数
# ----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'EOF'
SoloLoop v3 - 迭代循环插件（支持规划文件）

用法：
  /sololoop:sololoop "任务描述" [选项]

选项：
  --max <n>       最大迭代次数（默认：10）
  --promise <t>   完成标记（多词需加引号）
  --plan          启用规划文件模式（创建 .sololoop/ 目录下的规划文件）
  -h, --help      显示帮助

示例：
  /sololoop:sololoop "实现登录功能" --max 5
  /sololoop:sololoop "重构代码" --promise "DONE" --max 20
  /sololoop:sololoop "开发新功能" --plan --max 15

停止方式：
  - 达到最大迭代次数
  - 输出 <promise>完成标记</promise>
  - 所有 .sololoop/task_plan.md 复选框完成（--plan 模式）
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
    --plan)
      PLAN_MODE=true
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
plan_mode: $PLAN_MODE
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
interruption_count: 0
last_interruption_type: null
---

$PROMPT
EOF

# ----------------------------------------------------------------------------
# 创建规划文件（--plan 模式）
# v3: 规划文件存放在 .sololoop/ 目录
# ----------------------------------------------------------------------------
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
PLANNING_FILES_STATUS=""

if [[ "$PLAN_MODE" == "true" ]]; then
  # 创建规划文件目录
  mkdir -p "$PLANNING_DIR"
  
  # task_plan.md - 任务计划文件
  if [[ -f "$PLANNING_DIR/task_plan.md" ]]; then
    # 追加新 session marker
    cat >> "$PLANNING_DIR/task_plan.md" << EOF

---

## Session: $TIMESTAMP

[继续上次任务]

EOF
    PLANNING_FILES_STATUS="$PLANNING_DIR/task_plan.md (已存在，追加新会话)"
  else
    cat > "$PLANNING_DIR/task_plan.md" << EOF
# Task Plan

Started: $TIMESTAMP

## Task

$PROMPT

## Phases

- [ ] Phase 1: 分析需求
- [ ] Phase 2: 设计方案
- [ ] Phase 3: 实现核心功能
- [ ] Phase 4: 测试验证
- [ ] Phase 5: 文档和清理
EOF
    PLANNING_FILES_STATUS="$PLANNING_DIR/task_plan.md (新建)"
  fi

  # notes.md - 迭代笔记文件
  if [[ -f "$PLANNING_DIR/notes.md" ]]; then
    cat >> "$PLANNING_DIR/notes.md" << EOF

---

## Session: $TIMESTAMP

### Iteration 1
- 开始新会话

EOF
    PLANNING_FILES_STATUS="$PLANNING_FILES_STATUS, $PLANNING_DIR/notes.md (已存在，追加新会话)"
  else
    cat > "$PLANNING_DIR/notes.md" << EOF
# Iteration Notes

## Session: $TIMESTAMP

### Iteration 1
- 开始任务

EOF
    PLANNING_FILES_STATUS="$PLANNING_FILES_STATUS, $PLANNING_DIR/notes.md (新建)"
  fi

  # deliverable.md - 交付物文件
  if [[ -f "$PLANNING_DIR/deliverable.md" ]]; then
    cat >> "$PLANNING_DIR/deliverable.md" << EOF

---

## Session: $TIMESTAMP

[新会话交付物]

EOF
    PLANNING_FILES_STATUS="$PLANNING_FILES_STATUS, $PLANNING_DIR/deliverable.md (已存在，追加新会话)"
  else
    cat > "$PLANNING_DIR/deliverable.md" << EOF
# Deliverable

## Summary

[最终输出将放置在此处]

## Files Modified

[修改的文件列表]
EOF
    PLANNING_FILES_STATUS="$PLANNING_FILES_STATUS, $PLANNING_DIR/deliverable.md (新建)"
  fi
fi

# ----------------------------------------------------------------------------
# 非规划模式下检测已存在的规划目录（Requirements 1.1, 1.3）
# ----------------------------------------------------------------------------
EXISTING_PLANNING_DIR_WARNING=false
if [[ "$PLAN_MODE" == "false" ]] && [[ -d "$PLANNING_DIR" ]]; then
  EXISTING_PLANNING_DIR_WARNING=true
fi

# ----------------------------------------------------------------------------
# 输出启动信息
# ----------------------------------------------------------------------------
echo "🔄 SoloLoop v3 循环已启动！"
echo ""
echo "迭代：1 / $MAX_ITERATIONS"
if [[ -n "$COMPLETION_PROMISE" ]]; then
  echo "完成标记：$COMPLETION_PROMISE"
fi
if [[ "$PLAN_MODE" == "true" ]]; then
  echo "规划模式：已启用"
  echo "规划目录：$PLANNING_DIR/"
  echo "规划文件：$PLANNING_FILES_STATUS"
fi

# 非规划模式下显示已存在规划目录的警告（Requirements 1.1, 1.3）
if [[ "$EXISTING_PLANNING_DIR_WARNING" == "true" ]]; then
  echo ""
  echo "⚠️ 检测到已存在的规划文件目录: $PLANNING_DIR/"
  echo "   本次任务未启用规划模式 (--plan)，请勿修改该目录下的文件。"
  echo "   如需使用规划模式，请添加 --plan 参数重新启动。"
fi

echo ""
echo "📋 完成条件："
echo "  - 达到最大迭代次数 ($MAX_ITERATIONS)"
if [[ -n "$COMPLETION_PROMISE" ]]; then
  echo "  - 输出 <promise>$COMPLETION_PROMISE</promise>"
fi
if [[ "$PLAN_MODE" == "true" ]]; then
  echo "  - 完成 $PLANNING_DIR/task_plan.md 中所有复选框"
fi
echo "  - 运行 /sololoop:cancel-sololoop 取消"
echo ""
echo "--- 任务开始 ---"
echo ""
echo "$PROMPT"
if [[ "$PLAN_MODE" == "true" ]]; then
  echo ""
  echo "💡 提示：请先查看 $PLANNING_DIR/task_plan.md 了解任务进度，完成后勾选对应复选框。"
fi

# 非规划模式下的明确指令（Requirements 1.2, 1.4）
if [[ "$PLAN_MODE" == "false" ]]; then
  echo ""
  echo "📌 注意：本次任务未启用规划模式，请勿修改 .sololoop/ 目录下的任何文件。"
fi
