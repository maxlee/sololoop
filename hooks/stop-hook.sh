#!/bin/bash
# ============================================================================
# SoloLoop Stop Hook - 迭代循环的核心脚本 (v3)
# ============================================================================
#
# 功能说明：
#   当 Claude 完成响应并尝试停止时，此脚本会被自动调用。
#   如果存在活动的 SoloLoop 循环，脚本会阻止停止并将相同的 prompt 反馈回去，
#   让 Claude 继续在同一任务上迭代。
#
# v3 新增功能：
#   - 规划文件目录隔离：从 .sololoop/ 目录读取规划文件
#   - Bash 中断恢复机制：自动检测中断并添加恢复指令
#   - 严格退出条件（待实现）
#
# v2 功能：
#   - plan_mode 支持：读取规划文件进度
#   - 复选框进度跟踪：计算 task_plan.md 中的完成百分比
#   - 复选框完成退出：所有复选框勾选时允许退出
#   - 增强错误处理：优雅处理各种异常情况
#
# 工作原理：
#   1. 检查状态文件是否存在（.claude/sololoop.local.md）
#   2. 检查是否达到最大迭代次数
#   3. 检查 Claude 输出中是否包含完成标记 <promise>TEXT</promise>
#   4. 检查 task_plan.md 中所有复选框是否完成（plan_mode）
#   5. 如果需要继续，输出 JSON 格式的 block 决策
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
PLANNING_DIR=".sololoop"
TASK_PLAN_FILE="$PLANNING_DIR/task_plan.md"

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
#   plan_mode: true
#   started_at: "2026-01-06T10:30:00Z"
#   ---
#   prompt 内容...
# ----------------------------------------------------------------------------
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" 2>/dev/null || echo "")

# 处理畸形状态文件 - Requirements 8.5, 12.1
if [[ -z "$FRONTMATTER" ]]; then
  echo "⚠️ SoloLoop: 状态文件损坏（无 frontmatter），循环已停止" >&2
  rm -f "$STATE_FILE"
  exit 0
fi

ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//' || echo "")
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//' || echo "")
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/' || echo "")
PLAN_MODE=$(echo "$FRONTMATTER" | grep '^plan_mode:' | sed 's/plan_mode: *//' || echo "false")

# ----------------------------------------------------------------------------
# 验证数值字段
# 如果状态文件损坏，清理并允许退出 - Requirements 8.5, 12.1
# ----------------------------------------------------------------------------
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]] || [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "⚠️ SoloLoop: 状态文件损坏（无效的迭代值），循环已停止" >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# ----------------------------------------------------------------------------
# 注意：最大迭代次数检查移到后面，与其他退出条件一起处理
# 这样可以确保严格的退出条件判断 - Requirements 3.2, 3.6, 3.7
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# 读取中断状态字段 - Requirements 4.1, 4.4
# ----------------------------------------------------------------------------
INTERRUPTION_COUNT=$(echo "$FRONTMATTER" | grep '^interruption_count:' | sed 's/interruption_count: *//' || echo "0")
LAST_INTERRUPTION_TYPE=$(echo "$FRONTMATTER" | grep '^last_interruption_type:' | sed 's/last_interruption_type: *//' || echo "null")

# 处理缺失的中断字段
if [[ -z "$INTERRUPTION_COUNT" ]] || [[ ! "$INTERRUPTION_COUNT" =~ ^[0-9]+$ ]]; then
  INTERRUPTION_COUNT=0
fi

# ----------------------------------------------------------------------------
# 获取 transcript 路径并检查完成标记和中断状态 - Requirements 2.1, 2.3, 12.2
# ----------------------------------------------------------------------------
TRANSCRIPT_PATH=""
if command -v jq &>/dev/null; then
  TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || echo "")
fi

PROMISE_MATCHED=false
INTERRUPTION_DETECTED=false

if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
  # 提取最后一条 assistant 消息的文本内容
  LAST_OUTPUT=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1 | \
    jq -r '.message.content | map(select(.type == "text")) | map(.text) | join("\n")' 2>/dev/null || echo "")
  
  # ----------------------------------------------------------------------------
  # 中断检测 - Requirements 2.1
  # 检测 transcript 中的 "Interrupted" 模式
  # ----------------------------------------------------------------------------
  if grep -q '"Interrupted"' "$TRANSCRIPT_PATH" 2>/dev/null || \
     grep -q '"type":"bash_interrupted"' "$TRANSCRIPT_PATH" 2>/dev/null || \
     grep -qi 'interrupted' "$TRANSCRIPT_PATH" 2>/dev/null | tail -5 | grep -q 'bash'; then
    # 检查最近的消息是否包含中断信号
    LAST_MESSAGES=$(tail -10 "$TRANSCRIPT_PATH" 2>/dev/null || echo "")
    if echo "$LAST_MESSAGES" | grep -qi 'interrupt'; then
      INTERRUPTION_DETECTED=true
    fi
  fi
  
  # ----------------------------------------------------------------------------
  # 严格的 Promise 匹配 - Requirements 3.8
  # 使用精确字符串匹配 <promise>TEXT</promise> 格式
  # 不接受部分匹配或变体
  # ----------------------------------------------------------------------------
  if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]] && [[ -n "$LAST_OUTPUT" ]]; then
    # 使用 grep 进行精确匹配 <promise>EXACT_TEXT</promise>
    EXACT_PROMISE_PATTERN="<promise>$COMPLETION_PROMISE</promise>"
    if echo "$LAST_OUTPUT" | grep -qF "$EXACT_PROMISE_PATTERN"; then
      PROMISE_MATCHED=true
    fi
  fi
else
  # 处理缺失 transcript - Requirements 12.2
  if [[ -n "$TRANSCRIPT_PATH" ]] && [[ ! -f "$TRANSCRIPT_PATH" ]]; then
    echo "⚠️ SoloLoop: transcript 文件不存在，跳过完成标记检查" >&2
  fi
fi

# ----------------------------------------------------------------------------
# 复选框进度检查 - Requirements 3.1, 3.2, 2.4
# 注意：这里只计算进度，不直接退出。退出条件在后面统一判断
# 规划模式隔离：只有当 plan_mode=true 时才读取和检查规划文件
# ----------------------------------------------------------------------------
CHECKBOX_TOTAL=0
CHECKBOX_CHECKED=0
CHECKBOX_PERCENTAGE=0
PROGRESS_INFO=""
ALL_CHECKBOXES_CHECKED=false

# 规划模式隔离 - Requirements 2.1, 2.3 (plan-mode-isolation)
# 只有当 plan_mode=true 时才读取 .sololoop/task_plan.md
if [[ "$PLAN_MODE" == "true" ]]; then
  if [[ -f "$TASK_PLAN_FILE" ]]; then
    # 计算复选框数量 - 匹配 "- [ ]" 和 "- [x]" 或 "- [X]"
    CHECKBOX_TOTAL=$(grep -cE '^\s*-\s*\[[ xX]\]' "$TASK_PLAN_FILE" 2>/dev/null) || CHECKBOX_TOTAL=0
    CHECKBOX_CHECKED=$(grep -cE '^\s*-\s*\[[xX]\]' "$TASK_PLAN_FILE" 2>/dev/null) || CHECKBOX_CHECKED=0
    
    if [[ $CHECKBOX_TOTAL -gt 0 ]]; then
      CHECKBOX_PERCENTAGE=$((CHECKBOX_CHECKED * 100 / CHECKBOX_TOTAL))
      PROGRESS_INFO="进度: $CHECKBOX_CHECKED/$CHECKBOX_TOTAL ($CHECKBOX_PERCENTAGE%)"
      
      # 标记是否所有复选框都已完成 - Requirements 3.3
      if [[ $CHECKBOX_CHECKED -ge $CHECKBOX_TOTAL ]]; then
        ALL_CHECKBOXES_CHECKED=true
      fi
    else
      PROGRESS_INFO="进度: 无复选框"
    fi
  else
    # 处理缺失 task_plan.md - Requirements 12.3
    echo "⚠️ SoloLoop: .sololoop/task_plan.md 不存在，跳过复选框检查" >&2
    PROGRESS_INFO="进度: .sololoop/task_plan.md 不存在"
  fi
fi
# 当 plan_mode=false 时，完全跳过规划文件读取，不设置任何进度信息

# ----------------------------------------------------------------------------
# 严格退出条件判断 - Requirements 3.2, 3.3, 3.6, 3.7
# 只有以下两种情况允许退出：
#   1. Promise 精确匹配 <promise>TEXT</promise>
#   2. 所有复选框已勾选（plan_mode）
# 即使达到最大迭代次数，也需要满足上述条件之一才能退出
# 如果 iteration < max 且无完成条件，必须返回 block
# ----------------------------------------------------------------------------

# 检查是否满足显式完成条件
EXPLICIT_COMPLETION=false
COMPLETION_REASON=""

if [[ "$PROMISE_MATCHED" == "true" ]]; then
  EXPLICIT_COMPLETION=true
  COMPLETION_REASON="检测到完成标记 <promise>$COMPLETION_PROMISE</promise>"
elif [[ "$ALL_CHECKBOXES_CHECKED" == "true" ]]; then
  EXPLICIT_COMPLETION=true
  COMPLETION_REASON="所有任务已完成 ($CHECKBOX_CHECKED/$CHECKBOX_TOTAL)"
fi

# 如果满足显式完成条件，允许退出
if [[ "$EXPLICIT_COMPLETION" == "true" ]]; then
  echo "✅ SoloLoop: $COMPLETION_REASON"
  rm -f "$STATE_FILE"
  exit 0
fi

# 检查是否达到最大迭代次数 - Requirements 3.1, 5.4
if [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "🛑 SoloLoop: 已达到最大迭代次数 $MAX_ITERATIONS"
  rm -f "$STATE_FILE"
  exit 0
fi

# 如果 iteration < max 且无完成条件，必须继续迭代 - Requirements 3.2, 3.4, 3.6

# ----------------------------------------------------------------------------
# 继续循环：更新迭代计数并返回 block 决策 - Requirements 2.5, 2.6
# ----------------------------------------------------------------------------
NEXT_ITERATION=$((ITERATION + 1))

# 提取 prompt 内容（frontmatter 之后的所有内容）
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$STATE_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "⚠️ SoloLoop: 状态文件中没有 prompt 内容" >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# ----------------------------------------------------------------------------
# 更新中断状态 - Requirements 4.2, 4.5
# ----------------------------------------------------------------------------
if [[ "$INTERRUPTION_DETECTED" == "true" ]]; then
  # 中断检测到：增加中断计数
  NEW_INTERRUPTION_COUNT=$((INTERRUPTION_COUNT + 1))
  NEW_INTERRUPTION_TYPE="bash_interrupted"
else
  # 成功迭代：重置中断计数
  NEW_INTERRUPTION_COUNT=0
  NEW_INTERRUPTION_TYPE="null"
fi

# 更新迭代计数和中断状态
sed -e "s/^iteration: .*/iteration: $NEXT_ITERATION/" \
    -e "s/^interruption_count: .*/interruption_count: $NEW_INTERRUPTION_COUNT/" \
    -e "s/^last_interruption_type: .*/last_interruption_type: $NEW_INTERRUPTION_TYPE/" \
    "$STATE_FILE" > "${STATE_FILE}.tmp"
mv "${STATE_FILE}.tmp" "$STATE_FILE"

# ----------------------------------------------------------------------------
# 构建迭代信息 - Requirements 3.4, 5.1, 5.2, 5.3
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# 中断恢复指令 - Requirements 2.2, 2.3, 2.4, 2.7, 5.2
# ----------------------------------------------------------------------------
INTERRUPTION_PREFIX=""
RECOVERY_INSTRUCTION=""

if [[ "$INTERRUPTION_DETECTED" == "true" ]]; then
  INTERRUPTION_PREFIX="[中断恢复] "
  RECOVERY_INSTRUCTION="

⚠️ 检测到命令中断。继续执行任务，跳过或重试失败的命令。"
  
  # ----------------------------------------------------------------------------
  # 中断升级处理 - Requirements 2.6, 4.3
  # 当连续中断次数 >= 3 时，添加升级建议
  # ----------------------------------------------------------------------------
  if [[ $NEW_INTERRUPTION_COUNT -ge 3 ]]; then
    RECOVERY_INSTRUCTION="$RECOVERY_INSTRUCTION

🚨 已连续中断 $NEW_INTERRUPTION_COUNT 次。建议采取替代方案：
- 将长时间运行的命令拆分为更小的步骤
- 使用后台执行或异步方式
- 考虑跳过当前命令，先完成其他任务
- 如果命令持续失败，请检查命令本身是否有问题"
  fi
fi

if [[ "$PLAN_MODE" == "true" ]]; then
  # plan_mode 下包含进度信息和 task_plan.md 引用
  if [[ -n "$PROGRESS_INFO" ]]; then
    ITERATION_INFO="${INTERRUPTION_PREFIX}🔄 SoloLoop 迭代 $NEXT_ITERATION/$MAX_ITERATIONS | $PROGRESS_INFO"
  else
    ITERATION_INFO="${INTERRUPTION_PREFIX}🔄 SoloLoop 迭代 $NEXT_ITERATION/$MAX_ITERATIONS"
  fi
  
  if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
    ITERATION_INFO="$ITERATION_INFO | 完成后输出: <promise>$COMPLETION_PROMISE</promise>"
  fi
  
  # 添加 task_plan.md 引用提醒 - Requirements 5.1, 5.2
  PLAN_REMINDER="

📋 请检查 .sololoop/task_plan.md 更新进度，完成的任务请勾选复选框。"
else
  # 非 plan_mode - 规划模式隔离 Requirements 2.2, 2.4 (plan-mode-isolation)
  # 不包含进度信息，不包含 .sololoop/ 文件引用
  if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
    ITERATION_INFO="${INTERRUPTION_PREFIX}🔄 SoloLoop 迭代 $NEXT_ITERATION/$MAX_ITERATIONS | 完成后输出: <promise>$COMPLETION_PROMISE</promise>"
  else
    ITERATION_INFO="${INTERRUPTION_PREFIX}🔄 SoloLoop 迭代 $NEXT_ITERATION/$MAX_ITERATIONS"
  fi
  # 添加规划模式隔离提示 - Requirements 2.2, 2.4 (plan-mode-isolation)
  PLAN_REMINDER="

📌 注意：本次任务未启用规划模式，请勿修改 .sololoop/ 目录下的任何文件。"
fi

# ----------------------------------------------------------------------------
# 输出 JSON 决策 - Requirements 2.6, 9.5
# 根据官方文档，Stop hook 的 JSON 输出格式：
#   decision: "block" - 阻止停止
#   reason: string - 将作为新的 prompt 发送给 Claude
# ----------------------------------------------------------------------------
jq -n --arg reason "$ITERATION_INFO$RECOVERY_INSTRUCTION
$PROMPT_TEXT$PLAN_REMINDER" '{"decision": "block", "reason": $reason}'
