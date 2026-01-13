#!/bin/bash
# ============================================================================
# SoloLoop Stats Script - 显示使用统计 (v8)
# ============================================================================
#
# 功能说明：
#   读取并显示 SoloLoop 的使用统计数据
#
# 输出：
#   格式化的统计信息
#
# Requirements: 4.4, 4.5
# ============================================================================

set -euo pipefail

# ----------------------------------------------------------------------------
# 常量定义
# ----------------------------------------------------------------------------
STATS_DIR="$HOME/.claude/sololoop"
STATS_FILE="$STATS_DIR/stats.json"

# ----------------------------------------------------------------------------
# 检查 jq 是否可用
# ----------------------------------------------------------------------------
if ! command -v jq &>/dev/null; then
  echo "❌ 错误: jq 未安装，无法读取统计数据"
  echo ""
  echo "请安装 jq:"
  echo "  macOS: brew install jq"
  echo "  Ubuntu/Debian: sudo apt-get install jq"
  exit 1
fi

# ----------------------------------------------------------------------------
# 检查统计文件是否存在
# ----------------------------------------------------------------------------
if [[ ! -f "$STATS_FILE" ]]; then
  echo "📊 SoloLoop 使用统计"
  echo ""
  echo "暂无统计数据"
  echo ""
  echo "统计数据会在每次循环结束时自动记录。"
  exit 0
fi

# ----------------------------------------------------------------------------
# 检查统计文件是否为空
# ----------------------------------------------------------------------------
if [[ ! -s "$STATS_FILE" ]]; then
  echo "📊 SoloLoop 使用统计"
  echo ""
  echo "暂无统计数据"
  exit 0
fi

# ----------------------------------------------------------------------------
# 读取并验证统计文件
# ----------------------------------------------------------------------------
STATS=$(cat "$STATS_FILE" 2>/dev/null) || {
  echo "❌ 错误: 无法读取统计文件"
  exit 1
}

if ! echo "$STATS" | jq empty 2>/dev/null; then
  echo "❌ 错误: 统计文件格式损坏"
  echo ""
  echo "可以删除统计文件重新开始: rm $STATS_FILE"
  exit 1
fi

# ----------------------------------------------------------------------------
# 提取统计数据 - Requirements 4.5
# ----------------------------------------------------------------------------
TOTAL_SESSIONS=$(echo "$STATS" | jq -r '.total_sessions // 0')
TOTAL_ITERATIONS=$(echo "$STATS" | jq -r '.total_iterations // 0')
AVG_ITERATIONS=$(echo "$STATS" | jq -r '.avg_iterations_per_session // 0 | . * 100 | floor / 100')
PROMISE_MATCHED=$(echo "$STATS" | jq -r '.exit_reasons.promise_matched // 0')
MAX_ITERATIONS=$(echo "$STATS" | jq -r '.exit_reasons.max_iterations // 0')
USER_CANCELLED=$(echo "$STATS" | jq -r '.exit_reasons.user_cancelled // 0')
LAST_SESSION=$(echo "$STATS" | jq -r '.last_session // "N/A"')

# ----------------------------------------------------------------------------
# 格式化输出 - Requirements 4.4
# ----------------------------------------------------------------------------
echo "📊 SoloLoop 使用统计"
echo ""
echo "总会话数:     $TOTAL_SESSIONS"
echo "总迭代数:     $TOTAL_ITERATIONS"
echo "平均迭代:     $AVG_ITERATIONS"
echo ""
echo "退出原因分布:"
echo "  ✅ 完成标记匹配:   $PROMISE_MATCHED"
echo "  🛑 最大迭代次数:   $MAX_ITERATIONS"
echo "  ❌ 用户取消:       $USER_CANCELLED"
echo ""
if [[ "$LAST_SESSION" != "N/A" ]] && [[ -n "$LAST_SESSION" ]]; then
  echo "最后会话 ID: $LAST_SESSION"
fi
