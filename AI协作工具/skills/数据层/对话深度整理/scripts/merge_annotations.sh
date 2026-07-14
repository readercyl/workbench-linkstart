#!/bin/bash
# 标注索引合并 · v1.0
# 用法：bash merge_annotations.sh <旧标注索引> <补充标注文件> [输出文件]
# 退出码 0 = 合并成功，1 = 错误
#
# 补充标注模式下，标注子代理产出新的标注行（仅遗漏段落），
# 需要与旧标注索引合并。本脚本自动处理：去重、行号排序、格式一致性。
#
# 输出到 stdout（默认）或指定的输出文件。

set -euo pipefail

OLD_FILE="$1"
NEW_LINES="$2"
OUTPUT="${3:-}"

if [ ! -f "$OLD_FILE" ]; then
    echo "❌ 旧标注索引不存在: $OLD_FILE"
    exit 1
fi

if [ ! -f "$NEW_LINES" ]; then
    echo "❌ 补充标注文件不存在: $NEW_LINES"
    exit 1
fi

echo "==========================================="
echo "  标注索引合并"
echo "==========================================="

# ── 1. 提取旧标注的数据行（跳过头部章节和表头） ──
# 找到「三、信息点标注索引」之后的表格数据行
OLD_TABLE_START=$(grep -n '信息点标注索引' "$OLD_FILE" | head -1 | cut -d: -f1)
if [ -z "$OLD_TABLE_START" ]; then
    echo "❌ 旧标注索引中未找到「信息点标注索引」节"
    exit 1
fi

# 提取旧标注的头部（从文件开头到表格数据之前的所有内容，包括章节标题和表头）
HEAD_LINES=$((OLD_TABLE_START + 3))  # 标题行后一般是空行+表头+分隔行，多取几行确保包含完整表头
OLD_HEAD=$(head -n "$HEAD_LINES" "$OLD_FILE")
OLD_DATA=$(tail -n +$((OLD_TABLE_START + 1)) "$OLD_FILE" | grep -E '^\|[^-].*\|.*\|' | grep -vE '^\|.*段落.*\|' || true)

# ── 2. 提取补充标注的数据行 ──
# 补充标注文件可能只有数据行，也可能包含章节标题
NEW_DATA=$(grep -E '^\|[^-].*\|.*\|' "$NEW_LINES" | grep -vE '^\|.*段落.*\|' || true)

if [ -z "$NEW_DATA" ]; then
    echo "❌ 补充标注文件中无数据行"
    exit 1
fi

OLD_COUNT=$(echo "$OLD_DATA" | wc -l | tr -d ' ')
NEW_COUNT=$(echo "$NEW_DATA" | wc -l | tr -d ' ')
echo "  旧标注: $OLD_COUNT 条"
echo "  补充标注: $NEW_COUNT 条"

# ── 3. 合并 + 按段落位置排序 + 去重 ──
# 合并所有数据行
ALL_DATA=$(printf '%s\n%s\n' "$OLD_DATA" "$NEW_DATA")

# 按第一列（段落位置）的数字排序——提取起始行号作为排序键
SORTED_DATA=$(echo "$ALL_DATA" | sort -t'|' -k2,2n -s 2>/dev/null || echo "$ALL_DATA" | sort -t'-' -k1,1n -s 2>/dev/null || echo "$ALL_DATA")

# 去重：按段落位置列去重（同一段落范围只保留第一次出现的行——即旧标注优先）
DEDUPED=$(echo "$SORTED_DATA" | awk -F'|' '{
    key = $2
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
    if (!seen[key]++) print
}')

DUP_COUNT=$((OLD_COUNT + NEW_COUNT - $(echo "$DEDUPED" | wc -l | tr -d ' ')))
FINAL_COUNT=$(echo "$DEDUPED" | wc -l | tr -d ' ')

echo "  去重: $DUP_COUNT 条（补充标注中的段落已在旧标注中）"
echo "  合并后: $FINAL_COUNT 条"
echo ""

# ── 4. 组装输出 ──
{
    echo "$OLD_HEAD"
    echo ""
    echo "$DEDUPED"
    echo ""
} > "${OUTPUT:-/dev/stdout}"

if [ -n "$OUTPUT" ]; then
    echo "✅ 合并结果已写入: $OUTPUT"
else
    echo "✅ 合并结果已输出到 stdout"
fi
