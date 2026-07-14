#!/bin/bash
# 更新调用记录 · v1.0
# 从对话存档 AI 摘要中提取「核心引用卡片」，更新 00-运转日志/知识卡片调用记录.md
# 用法：bash 更新调用记录.sh <对话存档文件路径>
# 退出码 0 = 成功，1 = 无核心引用卡片或文件不存在

set -euo pipefail

ARCHIVE_FILE="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
CALL_LOG="$REPO_ROOT/00-运转日志/知识卡片调用记录.md"

[ -z "$ARCHIVE_FILE" ] && echo "用法: $0 <对话存档文件路径>" && exit 1
[ ! -f "$ARCHIVE_FILE" ] && echo "❌ 文件不存在: $ARCHIVE_FILE" && exit 1
[ ! -f "$CALL_LOG" ] && echo "❌ 调用记录文件不存在: $CALL_LOG" && exit 1

# 1. 从存档文件中提取「核心引用卡片」行
#    格式：**核心引用卡片**：[[卡1]]、[[卡2]]、[[卡3]]（...）
CARD_LINE=$(grep '核心引用卡片' "$ARCHIVE_FILE" | head -1 || true)

if [ -z "$CARD_LINE" ]; then
    echo "⏭️  未找到「核心引用卡片」字段，跳过"
    exit 0
fi

# 检查是否为「无」
if echo "$CARD_LINE" | grep -q '无'; then
    echo "⏭️  核心引用卡片填「无」，跳过"
    exit 0
fi

# 2. 提取所有 [[卡片名]]
CARD_NAMES=$(echo "$CARD_LINE" | grep -oE '\[\[[^]]+\]\]' | sed 's/\[\[//;s/\]\]//')

if [ -z "$CARD_NAMES" ]; then
    echo "⏭️  未解析到有效卡片名，跳过"
    exit 0
fi

echo "📊 核心引用卡片："
echo "$CARD_NAMES" | while read -r card; do echo "   - [[$card]]"; done
echo ""

# 3. 逐卡更新计数
UPDATED=0
ADDED=0

while IFS= read -r card; do
    [ -z "$card" ] && continue
    card_escaped=$(echo "$card" | sed 's/[\/&]/\\&/g')

    if grep -q "\[\[$card_escaped\]\]" "$CALL_LOG"; then
        # 卡片已存在 → count +1
        current_count=$(grep "\[\[$card_escaped\]\]" "$CALL_LOG" | head -1 | grep -oE '[0-9]+' | tail -1)
        new_count=$((current_count + 1))
        # macOS sed 兼容：用 perl 做原地替换
        perl -i -pe "s/(\[\[$card_escaped\]\] \| )$current_count/\${1}$new_count/" "$CALL_LOG"
        echo "   ✅ [[$card]]: $current_count → $new_count"
        UPDATED=$((UPDATED + 1))
    else
        # 新卡片 → 追加行，count=1
        echo "| [[$card]] | 1 |" >> "$CALL_LOG"
        echo "   🆕 [[$card]]: 新增 (count=1)"
        ADDED=$((ADDED + 1))
    fi
done <<< "$CARD_NAMES"

# 4. 按 count 降序重排（保持表头在前）
HEADER=$(head -2 "$CALL_LOG")
BODY=$(tail -n +3 "$CALL_LOG" | sort -t'|' -k3 -rn)
echo "$HEADER" > "$CALL_LOG"
echo "$BODY" >> "$CALL_LOG"

echo ""
echo "✅ 完成：更新 $UPDATED 张，新增 $ADDED 张"
