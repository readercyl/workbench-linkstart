#!/bin/bash
# 标注索引格式校验 · v1.2
# 用法：
#   bash validate_annotation_format.sh <标注索引文件>           基础模式：结构+格式
#   bash validate_annotation_format.sh <标注索引文件> --strict  严格模式：含字段值语义校验
# 退出码 0 = 合格，1 = 缺陷
#
# v1.1→v1.2：修复跨章节表格行泄漏。v1.1 从全文搜索表格行，导致「二、说话人清单」
# 的 4 列表格被误当作标注数据校验——列数、段落位置、字段值全部误报。
# v1.2 限定所有表格检查的作用域到「三、信息点标注索引」节之后的行。
# 同时过滤表头行（含"段落"关键词的行）避免表头被当作数据行校验。

set -euo pipefail

ANNOTATION_FILE="$1"
STRICT=false
if [ "${2:-}" = "--strict" ]; then
    STRICT=true
fi

if [ ! -f "$ANNOTATION_FILE" ]; then
    echo "❌ 标注索引文件不存在: $ANNOTATION_FILE"
    exit 1
fi

PASS=true
HAS_TABLE=false

MODE_LABEL="基础模式"
if $STRICT; then
    MODE_LABEL="严格模式"
fi

echo "==========================================="
echo "  标注索引格式校验 · $MODE_LABEL"
echo "==========================================="

# ── 1. 检查三个必要章节存在 ──
if grep -q '主题清单' "$ANNOTATION_FILE" 2>/dev/null; then
    echo "  ✅ 一、主题清单 节存在"
else
    echo "  ❌ 缺少「一、主题清单」节"
    PASS=false
fi

if grep -q '说话人清单' "$ANNOTATION_FILE" 2>/dev/null; then
    echo "  ✅ 二、说话人清单 节存在"
else
    echo "  ❌ 缺少「二、说话人清单」节"
    PASS=false
fi

if grep -q '信息点标注索引' "$ANNOTATION_FILE" 2>/dev/null; then
    echo "  ✅ 三、信息点标注索引 节存在"
else
    echo "  ❌ 缺少「三、信息点标注索引」节"
    PASS=false
fi

# ── 辅助：提取「三、信息点标注索引」节之后的所有行 ──
SECTION3_START=$(grep -n '信息点标注索引' "$ANNOTATION_FILE" | head -1 | cut -d: -f1)
if [ -z "$SECTION3_START" ]; then
    echo "  ⚠️  未找到「三、信息点标注索引」节起始行，跳过表格检查"
    echo ""
    if $PASS; then
        echo "  ✅ 格式校验通过（无法定位表格节，仅检查章节存在性）"
        exit 0
    else
        echo "  ❌ 格式校验不通过"
        exit 1
    fi
fi

# 提取第三节之后的所有行到临时文件
SECTION3_CONTENT=$(mktemp)
trap "rm -f $SECTION3_CONTENT" EXIT
tail -n +"$SECTION3_START" "$ANNOTATION_FILE" > "$SECTION3_CONTENT"

# ── 2. 检查标注索引表格行数（限定第三节） ──
TABLE_ROWS=$(grep -cE '^\|.*\|.*\|.*\|' "$SECTION3_CONTENT" 2>/dev/null || echo 0)
# 排除表头行（含"段落"关键词）和分隔行（含"---"）
HEADER_ROWS=$(grep -cE '^\|.*段落.*\|' "$SECTION3_CONTENT" 2>/dev/null || echo 0)
SEP_ROWS=$(grep -cE '^\|.*---.*\|' "$SECTION3_CONTENT" 2>/dev/null || echo 0)
DATA_ROWS=$((TABLE_ROWS - HEADER_ROWS - SEP_ROWS))

if [ "$DATA_ROWS" -ge 1 ]; then
    echo "  ✅ 标注索引数据行数: $DATA_ROWS"
    HAS_TABLE=true
else
    echo "  ❌ 标注索引表格为空——无标注条目"
    PASS=false
fi

# ── 辅助：提取第三节的数据行（排除表头和分隔行） ──
get_section3_data() {
    grep -E '^\|[^-].*\|.*\|' "$SECTION3_CONTENT" | grep -vE '^\|.*段落.*\|' || true
}

# ── 3. 检查表格列数（限定第三节） ──
if $HAS_TABLE; then
    FIRST_DATA_ROW=$(get_section3_data | head -1)
    if [ -n "$FIRST_DATA_ROW" ]; then
        COL_COUNT=$(echo "$FIRST_DATA_ROW" | awk -F'|' '{print NF-2}')
        COL_COUNT=${COL_COUNT:-0}
        echo "  ℹ️  表格列数: $COL_COUNT（预期 ≥8，含情绪强度和对话弧段）"
        if [ "${COL_COUNT:-0}" -lt 8 ]; then
            echo "  ❌ 列数不足——标注索引至少需要 8 列（段落|主题|说话人|类型|情绪|弧段|摘要|原话）"
            PASS=false
        fi
    fi
else
    echo "  ⏭️  跳过列数检查（无表格数据行）"
fi

# ── 4. 检查段落位置列格式（限定第三节） ──
if $HAS_TABLE; then
    BAD_RANGES=$(get_section3_data | awk -F'|' '{print $2}' | grep -vE '^[[:space:]]*[0-9]+[-–][0-9]+[[:space:]]*$|^[[:space:]]*[0-9]+[[:space:]]*$|^[[:space:]]*$' | head -5)
    if [ -z "$BAD_RANGES" ]; then
        echo "  ✅ 段落位置列格式正确"
    else
        echo "  ❌ 段落位置列存在非标准格式"
        echo "$BAD_RANGES" | while read -r bad; do
            echo "     → '$bad'（应为纯数字，如 3-5 或 12）"
        done
        PASS=false
    fi
else
    echo "  ⏭️  跳过段落位置列检查（无表格数据行）"
fi

# ══════════════════════════════════════════
# 严格模式：字段值语义校验
# ══════════════════════════════════════════
if $STRICT && $HAS_TABLE; then
    echo ""
    echo "  ── 严格模式：字段值语义校验 ──"

    STRICT_FAILS=0
    DATA_LINES=$(get_section3_data)

    # 4a. 信息类型列（第5列 = awk $5，因为 $1=空, $2=段落, $3=主题, $4=说话人, $5=类型）——八类之一
    VALID_TYPES="框架/方法论|判断/原则|市场/数据|反直觉洞察|案例/故事|预测/趋势|失败教训|金句原话"
    BAD_TYPES=$(echo "$DATA_LINES" | awk -F'|' '{print $5}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -vE "^($VALID_TYPES)$|^[[:space:]]*$" | head -5)
    if [ -z "$BAD_TYPES" ]; then
        echo "  ✅ 信息类型列：值均合规"
    else
        echo "  ❌ 信息类型列存在非标准值："
        echo "$BAD_TYPES" | while read -r bad; do
            echo "     → '$bad'（应为八类之一）"
        done
        STRICT_FAILS=$((STRICT_FAILS + 1))
    fi

    # 4b. 情绪强度列（第6列）——整数 1-5
    BAD_EMOTIONS=$(echo "$DATA_LINES" | awk -F'|' '{print $6}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -vE '^[1-5]$|^[[:space:]]*$' | head -5)
    if [ -z "$BAD_EMOTIONS" ]; then
        echo "  ✅ 情绪强度列：值均在 1-5 范围"
    else
        echo "  ❌ 情绪强度列存在越界值："
        echo "$BAD_EMOTIONS" | while read -r bad; do
            echo "     → '$bad'（应为 1-5）"
        done
        STRICT_FAILS=$((STRICT_FAILS + 1))
    fi

    # 4c. 对话弧段列（第7列）——四选一
    VALID_ARCS="铺垫|高潮|转折|收束"
    BAD_ARCS=$(echo "$DATA_LINES" | awk -F'|' '{print $7}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -vE "^($VALID_ARCS)$|^[[:space:]]*$" | head -5)
    if [ -z "$BAD_ARCS" ]; then
        echo "  ✅ 对话弧段列：值均合规（四选一）"
    else
        echo "  ❌ 对话弧段列存在非标准值："
        echo "$BAD_ARCS" | while read -r bad; do
            echo "     → '$bad'（应为 铺垫/高潮/转折/收束）"
        done
        STRICT_FAILS=$((STRICT_FAILS + 1))
    fi

    # 4d. 是否含原话列（倒数第2列 = awk $(NF-1)）——是/否
    BAD_QUOTES=$(echo "$DATA_LINES" | awk -F'|' '{print $(NF-1)}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -vE '^是$|^否$|^[[:space:]]*$' | head -5)
    if [ -z "$BAD_QUOTES" ]; then
        echo "  ✅ 是否含原话列：值均为 是/否"
    else
        echo "  ❌ 是否含原话列存在非标准值："
        echo "$BAD_QUOTES" | while read -r bad; do
            echo "     → '$bad'（应为 是/否）"
        done
        STRICT_FAILS=$((STRICT_FAILS + 1))
    fi

    if [ "$STRICT_FAILS" -gt 0 ]; then
        echo "  ❌ 严格模式：$STRICT_FAILS 项不通过"
        PASS=false
    else
        echo "  ✅ 严格模式：全部通过"
    fi
elif $STRICT && ! $HAS_TABLE; then
    echo "  ⏭️  严格模式跳过（无表格数据行）"
fi

echo ""

if $PASS; then
    echo "  ✅ 格式校验通过"
    exit 0
else
    echo "  ❌ 格式校验不通过——修正后重跑"
    exit 1
fi
