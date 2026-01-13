#!/bin/bash
set -euo pipefail

STEERING_DIR=".claude/steering"
TEMPLATE_DIR="${CLAUDE_PLUGIN_ROOT}/steering"

# 创建目录
mkdir -p "$STEERING_DIR"

# 复制模板
if [[ -f "$STEERING_DIR/manus-rules.md" ]]; then
    echo "⚠️  manus-rules.md 已存在，跳过复制"
    echo ""
    echo "如需更新，请手动删除后重新运行此命令："
    echo "  rm $STEERING_DIR/manus-rules.md"
    echo "  /sololoop:init-steering"
else
    cp "$TEMPLATE_DIR/manus-rules.md" "$STEERING_DIR/"
    echo "✅ 已复制 manus-rules.md 到 $STEERING_DIR/"
fi

echo ""
echo "📋 使用方法："
echo "   在对话中输入 #manus-rules 启用 Manus 最佳实践"
echo ""
echo "💡 提示："
echo "   你可以编辑 $STEERING_DIR/manus-rules.md 自定义规则"
