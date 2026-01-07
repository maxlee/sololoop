#!/bin/bash
# ============================================================================
# SoloLoop Update-Spec Script - 更新 Spec 内容
# ============================================================================
#
# 功能说明：
#   在迭代过程中追加新需求到 task_plan.md
#
# 使用方法：
#   /sololoop:update-spec "新需求描述"
#
# 参数说明：
#   DESCRIPTION   要追加的需求描述（必需）
#
# ============================================================================

set -euo pipefail

# ----------------------------------------------------------------------------
# 常量定义
# ----------------------------------------------------------------------------
PLANNING_DIR=".sololoop"
TASK_PLAN_FILE="$PLANNING_DIR/task_plan.md"

# ----------------------------------------------------------------------------
# 解析命令行参数
# ----------------------------------------------------------------------------
DESCRIPTION_PARTS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'EOF'
SoloLoop Update-Spec - 更新 Spec 内容

用法：
  /sololoop:update-spec "新需求描述"

参数：
  DESCRIPTION   要追加的需求描述（必需）
  -h, --help    显示帮助

示例：
  /sololoop:update-spec "添加用户认证功能"
  /sololoop:update-spec "1. 支持 OAuth 登录 2. 添加密码重置功能"

前置条件：
  - 必须先使用 --plan 模式启动 SoloLoop
  - .sololoop/task_plan.md 文件必须存在
EOF
      exit 0
      ;;
    *)
      DESCRIPTION_PARTS+=("$1")
      shift
      ;;
  esac
done

# ----------------------------------------------------------------------------
# 验证参数
# ----------------------------------------------------------------------------
DESCRIPTION="${DESCRIPTION_PARTS[*]:-}"
if [[ -z "$DESCRIPTION" ]]; then
  echo "❌ 错误：请提供需求描述" >&2
  echo "示例：/sololoop:update-spec \"添加用户认证功能\"" >&2
  exit 1
fi

# ----------------------------------------------------------------------------
# 验证 task_plan.md 存在
# ----------------------------------------------------------------------------
if [[ ! -f "$TASK_PLAN_FILE" ]]; then
  echo "❌ 错误：$TASK_PLAN_FILE 不存在" >&2
  echo "" >&2
  echo "请先使用 --plan 模式启动 SoloLoop：" >&2
  echo "  /sololoop:sololoop \"任务描述\" --plan" >&2
  exit 1
fi

# ----------------------------------------------------------------------------
# 获取时间戳
# ----------------------------------------------------------------------------
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ----------------------------------------------------------------------------
# 追加需求到 Requirements 部分
# ----------------------------------------------------------------------------
# 检查是否存在 Requirements 部分
if grep -q "^## Requirements" "$TASK_PLAN_FILE"; then
  # 找到 Requirements 部分，在下一个 ## 之前追加
  # 使用 awk 在 Requirements 部分末尾追加新需求
  awk -v desc="$DESCRIPTION" -v ts="$TIMESTAMP" '
    /^## Requirements/ { in_req=1; print; next }
    /^## / && in_req { 
      print "- REQ-" ts ": " desc
      print ""
      in_req=0
    }
    { print }
    END { if (in_req) { print "- REQ-" ts ": " desc; print "" } }
  ' "$TASK_PLAN_FILE" > "$TASK_PLAN_FILE.tmp" && mv "$TASK_PLAN_FILE.tmp" "$TASK_PLAN_FILE"
else
  # 如果没有 Requirements 部分，在文件末尾添加
  cat >> "$TASK_PLAN_FILE" << EOF

## Requirements

- REQ-$TIMESTAMP: $DESCRIPTION
EOF
fi

# ----------------------------------------------------------------------------
# 更新 Change Log 部分
# ----------------------------------------------------------------------------
if grep -q "^## Change Log" "$TASK_PLAN_FILE"; then
  # 找到 Change Log 部分，在表格末尾追加
  awk -v desc="$DESCRIPTION" -v ts="$TIMESTAMP" '
    /^## Change Log/ { in_log=1; print; next }
    /^## / && in_log { 
      print "| " ts " | Added requirement: " desc " |"
      print ""
      in_log=0
    }
    /^\|.*\|$/ && in_log { print; found_table=1; next }
    in_log && found_table && !/^\|/ {
      print "| " ts " | Added requirement: " desc " |"
      print ""
      in_log=0
      found_table=0
    }
    { print }
    END { if (in_log) { print "| " ts " | Added requirement: " desc " |"; print "" } }
  ' "$TASK_PLAN_FILE" > "$TASK_PLAN_FILE.tmp" && mv "$TASK_PLAN_FILE.tmp" "$TASK_PLAN_FILE"
else
  # 如果没有 Change Log 部分，在文件末尾添加
  cat >> "$TASK_PLAN_FILE" << EOF

## Change Log

| Timestamp | Change |
|-----------|--------|
| $TIMESTAMP | Added requirement: $DESCRIPTION |
EOF
fi

# ----------------------------------------------------------------------------
# 输出确认信息
# ----------------------------------------------------------------------------
echo "✅ Spec 已更新"
echo ""
echo "📝 新增需求："
echo "   $DESCRIPTION"
echo ""
echo "📋 变更记录："
echo "   时间：$TIMESTAMP"
echo "   操作：追加需求"
echo ""
echo "💡 提示：请检查 $TASK_PLAN_FILE 确认变更内容"
echo "   建议同时更新 Acceptance Criteria 和 Test Cases"
