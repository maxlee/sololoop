#!/bin/bash
# ============================================================================
# SoloLoop Stop Hook - 迭代循环的核心脚本 (v6)
# ============================================================================
#
# 功能说明：
#   当 Claude 完成响应并尝试停止时，此脚本会被自动调用。
#   如果存在活动的 SoloLoop 循环，脚本会阻止停止并将相同的 prompt 反馈回去，
#   让 Claude 继续在同一任务上迭代。
#
# v6 变更：
#   - 移除复选框自动退出逻辑（复选框仅作进度指示器）
#   - Promise 驱动退出：必须输出 <promise>TEXT</promise> 才退出
#   - 更新退出条件优先级：
#      - 优先级 1: Promise 匹配 → 退出
#      - 优先级 2: 最大迭代次数 → 退出
#   - 100% 复选框完成时显示"等待完成标记"
#
# 工作原理：
#   1. 检查状态文件是否存在（.claude/sololoop.local.md）
#   2. 检查退出条件（按优先级）：
#      - 优先级 1: Promise 匹配
#      - 优先级 2: 最大迭代次数
#   3. 如果需要继续，输出 JSON 格式的 block 决策
#      - reason: 原始 prompt（纯净）
#      - systemMessage: 迭代信息和进度
#
# 输入：
#   通过 stdin 接收 JSON 格式的 hook 输入，包含 transcript_path 等信息
#
# 输出：
#   - 允许停止：exit 0（无输出或空输出）
#   - 阻止停止：输出 JSON {"decision": "block", "reason": "...", "systemMessage": "..."}
#
# ============================================================================

set -euo pipefail

# ----------------------------------------------------------------------------
# 常量定义 (v5: 移除 PLANNING_DIR 和 TASK_PLAN_FILE)
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
# 解析状态文件的 YAML frontmatter (v5 格式)
# 状态文件格式：
#   ---
#   iteration: 1
#   max_iterations: 10
#   completion_promise: "DONE"
#   openspec_mode: true
#   openspec_tasks_file: "openspec/changes/feature-x/tasks.md"
#   started_at: "2026-01-06T10:30:00Z"
#   interruption_count: 0
#   last_interruption_type: null
#   ---
#   prompt 内容...
# ----------------------------------------------------------------------------
# 检查文件是否为空
if [[ ! -s "$STATE_FILE" ]]; then
  echo "⚠️ SoloLoop: 状态文件为空，循环已停止" >&2
  rm -f "$STATE_FILE"
  exit 0
fi

FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" 2>/dev/null || echo "")

# 处理畸形状态文件
if [[ -z "$FRONTMATTER" ]]; then
  echo "⚠️ SoloLoop: 状态文件损坏（无 frontmatter），循环已停止" >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# 检查 frontmatter 是否包含必需字段
if ! echo "$FRONTMATTER" | grep -q '^iteration:' || ! echo "$FRONTMATTER" | grep -q '^max_iterations:'; then
  echo "⚠️ SoloLoop: 状态文件损坏（缺少必需字段），循环已停止" >&2
  rm -f "$STATE_FILE"
  exit 0
fi

ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//' || echo "")
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//' || echo "")
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/' || echo "")

# ----------------------------------------------------------------------------
# 解析 OpenSpec 模式字段 (v5 新增)
# ----------------------------------------------------------------------------
OPENSPEC_MODE=$(echo "$FRONTMATTER" | grep '^openspec_mode:' | sed 's/openspec_mode: *//' || echo "false")
OPENSPEC_TASKS_FILE=$(echo "$FRONTMATTER" | grep '^openspec_tasks_file:' | sed 's/openspec_tasks_file: *//' | sed 's/^"\(.*\)"$/\1/' || echo "")

# 处理缺失字段的向后兼容
if [[ -z "$OPENSPEC_MODE" ]]; then
  OPENSPEC_MODE="false"
fi

# ----------------------------------------------------------------------------
# 验证数值字段
# 如果状态文件损坏，清理并允许退出
# ----------------------------------------------------------------------------
# 处理空值情况
if [[ -z "$ITERATION" ]] || [[ -z "$MAX_ITERATIONS" ]]; then
  echo "⚠️ SoloLoop: 状态文件损坏（迭代值为空），循环已停止" >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# 处理非数字情况
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]] || [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "⚠️ SoloLoop: 状态文件损坏 (无效的迭代值: iteration=${ITERATION}, max=${MAX_ITERATIONS}), 循环已停止" >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# 处理不合理的数值范围（防止溢出或无意义的值）
if [[ "$ITERATION" -lt 0 ]] || [[ "$MAX_ITERATIONS" -lt 1 ]] || [[ "$MAX_ITERATIONS" -gt 10000 ]]; then
  echo "⚠️ SoloLoop: 状态文件损坏（迭代值超出合理范围），循环已停止" >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# ----------------------------------------------------------------------------
# 读取中断状态字段
# ----------------------------------------------------------------------------
INTERRUPTION_COUNT=$(echo "$FRONTMATTER" | grep '^interruption_count:' | sed 's/interruption_count: *//' || echo "0")
LAST_INTERRUPTION_TYPE=$(echo "$FRONTMATTER" | grep '^last_interruption_type:' | sed 's/last_interruption_type: *//' || echo "null")

# 处理缺失的中断字段
if [[ -z "$INTERRUPTION_COUNT" ]] || [[ ! "$INTERRUPTION_COUNT" =~ ^[0-9]+$ ]]; then
  INTERRUPTION_COUNT=0
fi

# ----------------------------------------------------------------------------
# 获取 transcript 路径并检查完成标记和中断状态
# ----------------------------------------------------------------------------
TRANSCRIPT_PATH=""
JQ_AVAILABLE=false

if command -v jq &>/dev/null; then
  JQ_AVAILABLE=true
  TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || echo "")
else
  # jq 不可用时使用备用方法解析
  TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | grep -o '"transcript_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || echo "")
fi

PROMISE_MATCHED=false
INTERRUPTION_DETECTED=false

if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
  # 检查 transcript 文件是否为空
  if [[ ! -s "$TRANSCRIPT_PATH" ]]; then
    echo "⚠️ SoloLoop: transcript 文件为空，跳过完成标记检查" >&2
  else
    # 提取最后一条 assistant 消息的文本内容
    if [[ "$JQ_AVAILABLE" == "true" ]]; then
      LAST_OUTPUT=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1 | \
        jq -r '.message.content | map(select(.type == "text")) | map(.text) | join("\n")' 2>/dev/null || echo "")
    else
      # jq 不可用时的备用方法
      LAST_OUTPUT=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1 || echo "")
    fi
    
    # ----------------------------------------------------------------------------
    # 中断检测
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
    # Promise 匹配
    # 使用正则匹配 <promise>TEXT</promise> 格式，允许标签内首尾空白
    # ----------------------------------------------------------------------------
    if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]] && [[ -n "$LAST_OUTPUT" ]]; then
      if echo "$LAST_OUTPUT" | grep -qE "<promise>[[:space:]]*${COMPLETION_PROMISE}[[:space:]]*</promise>"; then
        PROMISE_MATCHED=true
      fi
    fi
  fi
else
  # 处理缺失 transcript
  if [[ -n "$TRANSCRIPT_PATH" ]] && [[ ! -f "$TRANSCRIPT_PATH" ]]; then
    echo "⚠️ SoloLoop: transcript 文件不存在 ($TRANSCRIPT_PATH)，跳过完成标记检查" >&2
  fi
fi


# ----------------------------------------------------------------------------
# OpenSpec 模式检测和进度跟踪 (v5 新增, v6 修改)
# Requirements 5.1, 5.2, 5.3, 5.4, 5.5
# v6: 复选框仅作进度指示器，不触发退出
# ----------------------------------------------------------------------------
OPENSPEC_CHECKBOX_TOTAL=0
OPENSPEC_CHECKBOX_CHECKED=0
OPENSPEC_PROGRESS_INFO=""
ALL_OPENSPEC_CHECKBOXES_CHECKED=false
DETECTED_TASKS_FILE=""

# 提取 prompt 内容（frontmatter 之后的所有内容）
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$STATE_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "⚠️ SoloLoop: 状态文件中没有 prompt 内容" >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# 检测 OpenSpec 模式：从 prompt 中检测 openspec/changes/*/tasks.md 路径
# Requirements 5.1, 5.2
if [[ "$OPENSPEC_MODE" == "true" ]] && [[ -n "$OPENSPEC_TASKS_FILE" ]]; then
  DETECTED_TASKS_FILE="$OPENSPEC_TASKS_FILE"
elif echo "$PROMPT_TEXT" | grep -qE 'openspec/changes/[^/]+/tasks\.md'; then
  # 从 prompt 中提取 tasks.md 路径
  DETECTED_TASKS_FILE=$(echo "$PROMPT_TEXT" | grep -oE 'openspec/changes/[^/]+/tasks\.md' | head -1)
fi

# 如果检测到 OpenSpec tasks.md，计算复选框进度
# Requirements 5.3, 5.4, 5.5
if [[ -n "$DETECTED_TASKS_FILE" ]] && [[ -f "$DETECTED_TASKS_FILE" ]]; then
  if [[ -s "$DETECTED_TASKS_FILE" ]]; then
    # 计算复选框数量 - 匹配 "- [ ]" 和 "- [x]" 或 "- [X]"
    OPENSPEC_CHECKBOX_TOTAL=$(grep -cE '^\s*-\s*\[[ xX]\]' "$DETECTED_TASKS_FILE" 2>/dev/null) || OPENSPEC_CHECKBOX_TOTAL=0
    OPENSPEC_CHECKBOX_CHECKED=$(grep -cE '^\s*-\s*\[[xX]\]' "$DETECTED_TASKS_FILE" 2>/dev/null) || OPENSPEC_CHECKBOX_CHECKED=0
    
    if [[ $OPENSPEC_CHECKBOX_TOTAL -gt 0 ]]; then
      OPENSPEC_PERCENTAGE=$((OPENSPEC_CHECKBOX_CHECKED * 100 / OPENSPEC_CHECKBOX_TOTAL))
      OPENSPEC_PROGRESS_INFO="进度: $OPENSPEC_CHECKBOX_CHECKED/$OPENSPEC_CHECKBOX_TOTAL ($OPENSPEC_PERCENTAGE%)"
      
      # 标记是否所有复选框都已完成
      if [[ $OPENSPEC_CHECKBOX_CHECKED -ge $OPENSPEC_CHECKBOX_TOTAL ]]; then
        ALL_OPENSPEC_CHECKBOXES_CHECKED=true
      fi
    else
      OPENSPEC_PROGRESS_INFO="进度: 无复选框"
    fi
  else
    OPENSPEC_PROGRESS_INFO="进度: tasks.md 为空"
  fi
fi

# ----------------------------------------------------------------------------
# 多重 OR 退出条件优先级判断 (v6)
# Requirements 2.1, 2.2, 2.4, 5.1, 5.2
# v6 变更：移除复选框自动退出，改为 Promise 驱动
# 按优先级检查退出条件：
#   1. Promise 精确匹配 <promise>TEXT</promise> - 最高优先级
#   2. 达到最大迭代次数 - 安全网
# 注意：复选框完成不再触发退出，仅作进度指示器
# ----------------------------------------------------------------------------

EXIT_ALLOWED=false
EXIT_REASON=""

# 优先级 1: Promise 精确匹配 - Requirements 2.2, 5.1
if [[ "$PROMISE_MATCHED" == "true" ]]; then
  EXIT_ALLOWED=true
  EXIT_REASON="完成标记匹配"
# 优先级 2: 达到最大迭代次数（安全网）- Requirements 2.4, 5.1
elif [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  EXIT_ALLOWED=true
  EXIT_REASON="最大迭代次数 ($ITERATION/$MAX_ITERATIONS)"
fi
# 注意：v6 移除了复选框 100% 退出逻辑 - Requirements 2.1, 5.2
# 复选框进度仅在 systemMessage 中显示

# 如果满足退出条件，允许退出并清理状态文件 - Requirements 5.3, 5.4
if [[ "$EXIT_ALLOWED" == "true" ]]; then
  if [[ "$EXIT_REASON" == "完成标记匹配" ]]; then
    echo "✅ SoloLoop: $EXIT_REASON"
  else
    echo "🛑 SoloLoop: $EXIT_REASON"
  fi
  rm -f "$STATE_FILE"
  exit 0
fi

# ----------------------------------------------------------------------------
# 继续循环：更新迭代计数并返回 block 决策
# ----------------------------------------------------------------------------
NEXT_ITERATION=$((ITERATION + 1))

# ----------------------------------------------------------------------------
# 更新中断状态 - Requirements 7.2, 7.5
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
# 构建 systemMessage (v5 新增, v6 更新)
# Requirements 2.6, 4.1, 4.2, 4.3, 4.4
# systemMessage 包含迭代信息，reason 只包含原始 prompt
# v6: 100% 完成时显示"等待完成标记"
# ----------------------------------------------------------------------------
SYSTEM_MESSAGE="🔄 SoloLoop 迭代 $NEXT_ITERATION/$MAX_ITERATIONS"

# 添加 OpenSpec 进度信息
if [[ -n "$OPENSPEC_PROGRESS_INFO" ]]; then
  SYSTEM_MESSAGE="$SYSTEM_MESSAGE | $OPENSPEC_PROGRESS_INFO"
  # v6: 100% 完成时显示等待完成标记提示 - Requirements 2.6
  if [[ "$ALL_OPENSPEC_CHECKBOXES_CHECKED" == "true" ]]; then
    SYSTEM_MESSAGE="$SYSTEM_MESSAGE | 等待完成标记"
  fi
fi

# 添加 promise 提示
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  SYSTEM_MESSAGE="$SYSTEM_MESSAGE | 完成后输出: <promise>$COMPLETION_PROMISE</promise>"
fi

# ----------------------------------------------------------------------------
# 中断恢复指令 - Requirements 7.1, 7.3, 7.4
# 将恢复指令放入 systemMessage
# ----------------------------------------------------------------------------
if [[ "$INTERRUPTION_DETECTED" == "true" ]]; then
  SYSTEM_MESSAGE="[中断恢复] $SYSTEM_MESSAGE

⚠️ 检测到命令中断。继续执行任务，跳过或重试失败的命令。"
  
  # 中断升级处理 - Requirements 7.4
  if [[ $NEW_INTERRUPTION_COUNT -ge 3 ]]; then
    SYSTEM_MESSAGE="$SYSTEM_MESSAGE

🚨 已连续中断 $NEW_INTERRUPTION_COUNT 次。建议采取替代方案：
- 将长时间运行的命令拆分为更小的步骤
- 使用后台执行或异步方式
- 考虑跳过当前命令，先完成其他任务
- 如果命令持续失败，请检查命令本身是否有问题"
  fi
fi

# ----------------------------------------------------------------------------
# 输出 JSON 决策 (v5 格式)
# Requirements 4.1, 4.2, 4.3, 4.4, 10.5
# reason: 原始 prompt（纯净，不包含迭代信息）
# systemMessage: 迭代信息和进度
# ----------------------------------------------------------------------------
jq -n \
  --arg reason "$PROMPT_TEXT" \
  --arg systemMessage "$SYSTEM_MESSAGE" \
  '{"decision": "block", "reason": $reason, "systemMessage": $systemMessage}'
