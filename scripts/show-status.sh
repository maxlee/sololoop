#!/bin/bash
# ============================================================================
# SoloLoop Status Script - 显示目标记忆状态 (v9)
# ============================================================================
#
# 功能说明：
#   读取并显示 SoloLoop 目标记忆的当前状态
#
# 输出：
#   - 当前目标摘要 (goal.md 前 5 行)
#   - 迭代计数
#   - 重锚计数
#   - 漂移警告计数
#   - 最后活动时间
#
# Requirements: 6.2, 6.5
# ============================================================================

set -euo pipefail

# ----------------------------------------------------------------------------
# 常量定义
# ----------------------------------------------------------------------------
STATE_FILE=".claude/sololoop.local.md"
SOLOLOOP_DIR=".sololoop"
GOAL_FILE="$SOLOLOOP_DIR/goal.md"

# ----------------------------------------------------------------------------
# 检查目标记忆是否初始化
# ----------------------------------------------------------------------------
if [[ ! -d "$SOLOLOOP_DIR" ]]; then
  echo "📊 SoloLoop 目标记忆状态"
  echo ""
  echo "⚠️ 目标记忆未初始化"
  echo ""
  echo "运行以下命令初始化："
  echo "  /sololoop:init"
  echo ""
  echo "或直接运行 /sololoop 命令，将自动初始化目标记忆。"
  exit 0
fi

# ----------------------------------------------------------------------------
# 读取目标摘要 (goal.md Summary 部分)
# Requirements: 6.2
# ----------------------------------------------------------------------------
GOAL_SUMMARY=""
if [[ -f "$GOAL_FILE" ]]; then
  # 提取 Summary 部分的内容（## Summary 到下一个 ## 之间）
  GOAL_SUMMARY=$(awk '
    /^## Summary/ { found=1; next }
    /^## / && found { exit }
    found && NF { print; count++ }
    count >= 5 { exit }
  ' "$GOAL_FILE" 2>/dev/null || echo "")
  
  # 如果 Summary 为空，尝试读取前 5 行非空内容
  if [[ -z "$GOAL_SUMMARY" ]]; then
    GOAL_SUMMARY=$(grep -v '^#' "$GOAL_FILE" 2>/dev/null | grep -v '^$' | head -5 || echo "")
  fi
fi

# ----------------------------------------------------------------------------
# 读取状态文件字段
# Requirements: 6.2, 6.5
# ----------------------------------------------------------------------------
ITERATION="N/A"
MAX_ITERATIONS="N/A"
GOAL_MEMORY_ENABLED="false"
ITERATION_SINCE_ANCHOR="0"
ANCHOR_INTERVAL="15"
DRIFT_WARNING_COUNT="0"
TOTAL_ANCHORS="0"
LAST_ACTIVITY="N/A"
STARTED_AT="N/A"

if [[ -f "$STATE_FILE" ]] && [[ -s "$STATE_FILE" ]]; then
  # 解析 YAML frontmatter
  FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" 2>/dev/null || echo "")
  
  if [[ -n "$FRONTMATTER" ]]; then
    # 提取各字段
    ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//' || echo "N/A")
    MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//' || echo "N/A")
    GOAL_MEMORY_ENABLED=$(echo "$FRONTMATTER" | grep '^goal_memory_enabled:' | sed 's/goal_memory_enabled: *//' || echo "false")
    ITERATION_SINCE_ANCHOR=$(echo "$FRONTMATTER" | grep '^iteration_since_anchor:' | sed 's/iteration_since_anchor: *//' || echo "0")
    ANCHOR_INTERVAL=$(echo "$FRONTMATTER" | grep '^anchor_interval:' | sed 's/anchor_interval: *//' || echo "15")
    DRIFT_WARNING_COUNT=$(echo "$FRONTMATTER" | grep '^drift_warning_count:' | sed 's/drift_warning_count: *//' || echo "0")
    TOTAL_ANCHORS=$(echo "$FRONTMATTER" | grep '^total_anchors:' | sed 's/total_anchors: *//' || echo "0")
    LAST_ACTIVITY=$(echo "$FRONTMATTER" | grep '^last_activity_timestamp:' | sed 's/last_activity_timestamp: *//' | sed 's/^"\(.*\)"$/\1/' || echo "N/A")
    STARTED_AT=$(echo "$FRONTMATTER" | grep '^started_at:' | sed 's/started_at: *//' | sed 's/^"\(.*\)"$/\1/' || echo "N/A")
  fi
fi

# ----------------------------------------------------------------------------
# 格式化输出
# Requirements: 6.2, 6.5
# ----------------------------------------------------------------------------
echo "📊 SoloLoop 目标记忆状态"
echo ""

# 目标记忆状态指示器
if [[ "$GOAL_MEMORY_ENABLED" == "true" ]]; then
  echo "🎯 [Goal Memory Active]"
else
  echo "⚪ [Goal Memory Inactive]"
fi
echo ""

# 当前目标摘要
echo "📋 当前目标:"
if [[ -n "$GOAL_SUMMARY" ]]; then
  echo "$GOAL_SUMMARY" | sed 's/^/   /'
else
  echo "   (无目标摘要)"
fi
echo ""

# 迭代状态
if [[ "$ITERATION" != "N/A" ]] && [[ "$MAX_ITERATIONS" != "N/A" ]]; then
  echo "🔄 迭代进度:     $ITERATION / $MAX_ITERATIONS"
else
  echo "🔄 迭代进度:     无活动循环"
fi

# 重锚状态
echo "⚓ 重锚间隔:     $ITERATION_SINCE_ANCHOR / $ANCHOR_INTERVAL"
echo "📌 总重锚次数:   $TOTAL_ANCHORS"

# 漂移警告 - Requirements 6.5
if [[ "$DRIFT_WARNING_COUNT" != "0" ]] && [[ -n "$DRIFT_WARNING_COUNT" ]]; then
  echo "⚠️ 漂移警告:     $DRIFT_WARNING_COUNT (连续)"
else
  echo "✅ 漂移警告:     0"
fi
echo ""

# 时间信息
echo "⏱️ 时间信息:"
if [[ "$STARTED_AT" != "N/A" ]] && [[ -n "$STARTED_AT" ]]; then
  echo "   开始时间:     $STARTED_AT"
fi
if [[ "$LAST_ACTIVITY" != "N/A" ]] && [[ -n "$LAST_ACTIVITY" ]]; then
  echo "   最后活动:     $LAST_ACTIVITY"
fi

