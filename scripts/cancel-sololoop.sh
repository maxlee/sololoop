#!/bin/bash
# ============================================================================
# SoloLoop Cancel Script - 取消迭代循环
# ============================================================================

STATE_FILE=".claude/sololoop.local.md"

if [[ -f "$STATE_FILE" ]]; then
  ITER=$(grep '^iteration:' "$STATE_FILE" | sed 's/iteration: *//')
  MAX=$(grep '^max_iterations:' "$STATE_FILE" | sed 's/max_iterations: *//')
  rm -f "$STATE_FILE"
  echo "🔄 已取消 SoloLoop 循环（迭代 $ITER/$MAX）"
else
  echo "没有活动的 SoloLoop 循环"
fi
