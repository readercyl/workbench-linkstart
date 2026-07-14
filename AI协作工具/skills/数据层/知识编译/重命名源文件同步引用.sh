#!/bin/bash
# 重命名源文件同步引用 v1.0
# 用法：bash 重命名源文件同步引用.sh <源文件路径> <新文件名>
# 示例：bash 重命名源文件同步引用.sh 素材箱/flomo导出/flomo-2024.md flomo-2024-export.md
#
# 功能：
#   1. 重命名源文件
#   2. 扫描全库知识卡片，找到引用旧文件名的卡片
#   3. 同步更新这些卡片的 [[来源引用]]
#   4. 报告变更清单

set -e

cd "$(dirname "$0")/../../../.."

if [ $# -lt 2 ]; then
    echo "用法: $0 <源文件路径> <新文件名>"
    echo "示例: $0 素材箱/flomo导出/flomo-2024.md flomo-2024-export.md"
    exit 1
fi

OLD_PATH="$1"
NEW_NAME="$2"

if [ ! -f "$OLD_PATH" ]; then
    echo "❌ 源文件不存在: $OLD_PATH"
    exit 1
fi

OLD_BASE=$(basename "$OLD_PATH" .md)
NEW_BASE=$(basename "$NEW_NAME" .md)
NEW_DIR=$(dirname "$OLD_PATH")

echo "📄 重命名: $OLD_BASE → $NEW_BASE"
echo ""

# 1. 扫描引用旧文件名的卡片
echo "🔍 扫描引用 [[$OLD_BASE]] 的卡片..."
AFFECTED=$(grep -l "\[\[$OLD_BASE\]\]" 02-知识卡片/知识卡片/*.md 2>/dev/null)

if [ -z "$AFFECTED" ]; then
    echo "   无卡片引用此文件"
else
    count=$(echo "$AFFECTED" | wc -l | tr -d ' ')
    echo "   发现 $count 张卡片"
    echo ""

    # 2. 更新引用
    echo "✏️  更新引用..."
    for card in $AFFECTED; do
        card_name=$(basename "$card" .md)
        perl -i -pe "s|\[\[$OLD_BASE\]\]|[[$NEW_BASE]]|g" "$card"
        echo "   ✅ $card_name"
    done
    echo ""
fi

# 3. 检查调用记录
echo "🔍 检查调用记录..."
if grep -q "\[\[$OLD_BASE\]\]" "00-运转日志/知识卡片调用记录.md" 2>/dev/null; then
    perl -i -pe "s|\[\[$OLD_BASE\]\]|[[$NEW_BASE]]|g" "00-运转日志/知识卡片调用记录.md"
    echo "   ✅ 调用记录已同步"
else
    echo "   无调用记录"
fi

# 4. 重命名文件
echo ""
echo "📁 重命名文件..."
mv "$OLD_PATH" "$NEW_DIR/$NEW_NAME"
echo "   ✅ $OLD_PATH → $NEW_DIR/$NEW_NAME"

echo ""
echo "✅ 完成：重命名源文件 + 同步 $count 处引用"
