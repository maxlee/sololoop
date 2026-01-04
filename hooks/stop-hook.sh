#!/bin/bash
# ============================================================================
# SoloLoop Stop Hook - 迭代循环的核心脚本
# ============================================================================
#
# 功能说明：
#   当 Claude 完成响应并尝试停止时，此脚本会被自动调用。
#   如果存在活动的 SoloLoop 循环，脚本会阻止停止并将相同的 prompt 反馈回去，
#   让 Claude 继续在同一任务上迭代。
#
# 工作原理：
#   1. 检查状态文件是否存在（.claude/sololoop.local.md）
#   2. 检查是否达到最大迭代次数
#   3. 检查 Claude 输出中是否包含完成标记 <promise>TEXT</promise>
#   4. 如果需要继续，输出 JSON 格式的 block 决策
#
# 输入：
#   通过 stdin 接收 JSON 格式的 hook 输入，包含 transcript_path 等信息
#
# 输出：
#   - 允许停止：exit 0（无输出或空输出）
#   - 阻止停止：输出 JSON {"decision": "block", "reason": "..."}
#
# ============================================================================

set -euo pipefail

# ----------------------------------------------------------------------------
# 常量定义
# ----------------------------------------------------------------------------
STATE_FILE=".claude/sololoop.local.md"

# ----------------------------------------------------------------------------
# 读取 hook 输入
# ----------------------------------------------------------------------------
HOOK_INPUT=$(cat)

# ----------------------------------------------------------------------------
# 检查状态文件是否存在
# 如果不存在，说明没有活动的循环，允许正常退出
# ----------------------------------------------------------------------------
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# ----------------------------------------------------------------------------
# 解析状态文件的 YAML frontmatter
# 状态文件格式：
#   ---
#   iteration: 1
#   max_iterations: 10
#   completion_promise: "DONE"
#   ---
#   prompt 内容...
# ----------------------------------------------------------------------------
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/')

# ----------------------------------------------------------------------------
# 验证数值字段
# 如果状态文件损坏，清理并允许退出
# ----------------------------------------------------------------------------
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]] || [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "⚠️ SoloLoop: 状态文件损坏，循环已停止" >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# ----------------------------------------------------------------------------
# 检查是否达到最大迭代次数
# ----------------------------------------------------------------------------
if [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "🛑 SoloLoop: 已达到最大迭代次数 ($MAX_ITERATIONS)"
  rm -f "$STATE_FILE"
  exit 0
fi

# ----------------------------------------------------------------------------
# 获取 transcript 路径并检查完成标记
# ----------------------------------------------------------------------------
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty')

if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
  # 提取最后一条 assistant 消息的文本内容
  LAST_OUTPUT=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1 | \
    jq -r '.message.content | map(select(.type == "text")) | map(.text) | join("\n")' 2>/dev/null || echo "")
  
  # 检查完成标记 <promise>TEXT</promise>
  if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]] && [[ -n "$LAST_OUTPUT" ]]; then
    PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s' 2>/dev/null || echo "")
    if [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
      echo "✅ SoloLoop: 检测到完成标记 <promise>$COMPLETION_PROMISE</promise>"
      rm -f "$STATE_FILE"
      exit 0
    fi
  fi
fi

# ----------------------------------------------------------------------------
# 继续循环：更新迭代计数并返回 block 决策
# ----------------------------------------------------------------------------
NEXT_ITERATION=$((ITERATION + 1))

# 提取 prompt 内容（frontmatter 之后的所有内容）
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$STATE_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "⚠️ SoloLoop: 状态文件中没有 prompt 内容" >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# 更新迭代计数
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$STATE_FILE" > "${STATE_FILE}.tmp"
mv "${STATE_FILE}.tmp" "$STATE_FILE"

# ----------------------------------------------------------------------------
# 输出 JSON 决策
# 根据官方文档，Stop hook 的 JSON 输出格式：
#   decision: "block" - 阻止停止
#   reason: string - 将作为新的 prompt 发送给 Claude
# ----------------------------------------------------------------------------
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  ITERATION_INFO="🔄 SoloLoop 迭代 $NEXT_ITERATION/$MAX_ITERATIONS | 完成后输出: <promise>$COMPLETION_PROMISE</promise>"
else
  ITERATION_INFO="🔄 SoloLoop 迭代 $NEXT_ITERATION/$MAX_ITERATIONS"
fi

jq -n --arg reason "$ITERATION_INFO

$PROMPT_TEXT" '{"decision": "block", "reason": $reason}'
