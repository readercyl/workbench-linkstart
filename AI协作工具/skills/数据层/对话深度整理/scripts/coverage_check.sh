#!/bin/bash
# 标注覆盖率检查 · v1.2
# 用法：
#   单文件：bash coverage_check.sh <标注索引文件> <原始逐字稿文件>
#   多文件：bash coverage_check.sh <标注索引文件> -f <编号1>:<文件1> <编号2>:<文件2> ...
# 退出码 0 = 通过（≥95%），1 = 不通过
#
# v1.1→v1.2：支持多文件素材。旧版只接受单文件参数，无法处理 F1-/F2- 前缀标注格式。
# 新版增加 -f 参数，读取标注索引头部的「文件编号映射」表，按文件分组统计覆盖率。

set -euo pipefail

ANNOTATION_FILE="$1"
shift

# ── 解析参数：单文件模式 vs 多文件模式 ──
declare -A FILE_MAP
SINGLE_SOURCE=""

if [ "${1:-}" = "-f" ]; then
    shift
    while [ $# -gt 0 ] && [[ "${1:-}" =~ ^[A-Za-z0-9]+: ]]; do
        prefix="${1%%:*}"
        path="${1#*:}"
        FILE_MAP["$prefix"]="$path"
        shift
    done
    if [ ${#FILE_MAP[@]} -eq 0 ]; then
        echo "❌ -f 参数后需要至少一个 编号:文件路径 映射"
        exit 1
    fi
else
    SINGLE_SOURCE="${1:-}"
    if [ -z "$SINGLE_SOURCE" ] || [ ! -f "$SINGLE_SOURCE" ]; then
        echo "❌ 单文件模式需要提供原始逐字稿文件路径，或多文件模式使用 -f"
        exit 1
    fi
fi

if [ ! -f "$ANNOTATION_FILE" ]; then
    echo "❌ 标注索引文件不存在: $ANNOTATION_FILE"
    exit 1
fi

# ── 通用函数：从单文件提取标注行号 ──
extract_covered_lines() {
    local src_file="$1"
    local prefix="$2"
    local covered_tmp="$3"

    local total_lines=$(wc -l < "$src_file" | tr -d ' ')
    local content_lines=$(grep -c '[^[:space:]]' "$src_file" || echo 0)

    while IFS= read -r line; do
        if echo "$line" | grep -qE '^\|.*\|.*\|'; then
            col1=$(echo "$line" | awk -F'|' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            # 多文件模式：解析 F1-3-5 格式
            if [ -n "$prefix" ]; then
                col1=$(echo "$col1" | sed -n "s/^${prefix}-//p")
            fi
            if [ -z "$col1" ]; then continue; fi
            range=$(echo "$col1" | grep -oE '^[0-9]+[-–][0-9]+$|^[0-9]+$' 2>/dev/null || true)
            if [ -n "$range" ]; then
                if echo "$range" | grep -qE '[-–]'; then
                    start=$(echo "$range" | sed 's/[-–].*//')
                    end=$(echo "$range" | sed 's/.*[-–]//')
                    if [ "${start:-0}" -le "${end:-0}" ] 2>/dev/null; then
                        seq "$start" "$end" 2>/dev/null || true
                    fi
                else
                    echo "$range"
                fi
            fi
        fi
    done < "$ANNOTATION_FILE" | sort -n | uniq > "$covered_tmp"

    local covered_count=$(wc -l < "$covered_tmp" | tr -d ' ')
    echo "$total_lines|$content_lines|$covered_count"
}

echo "==========================================="
echo "  标注覆盖率检查"
echo "==========================================="

OVERALL_COVERED=0
OVERALL_CONTENT=0
ALL_PASS=true

if [ -n "$SINGLE_SOURCE" ]; then
    # 单文件模式
    COVERED_TMP=$(mktemp)
    stats=$(extract_covered_lines "$SINGLE_SOURCE" "" "$COVERED_TMP")
    TOTAL_LINES=$(echo "$stats" | cut -d'|' -f1)
    CONTENT_LINES=$(echo "$stats" | cut -d'|' -f2)
    COVERED_COUNT=$(echo "$stats" | cut -d'|' -f3)

    COVERAGE=$(echo "scale=1; $COVERED_COUNT * 100 / ${CONTENT_LINES:-1}" | bc 2>/dev/null || echo "0")
    echo "  文件: $(basename "$SINGLE_SOURCE")"
    echo "  原文总行数:    $TOTAL_LINES"
    echo "  有内容行数:    $CONTENT_LINES"
    echo "  标注覆盖行数:  $COVERED_COUNT"
    echo "  覆盖率:        ${COVERAGE}%"

    PASS=$(echo "$COVERAGE >= 95" | bc 2>/dev/null || echo "0")
    if [ "$PASS" -eq 1 ]; then
        echo "  ✅ 通过"
    else
        echo "  ❌ 不通过 — 覆盖率 < 95%"
        ALL_PASS=false
    fi
    rm -f "$COVERED_TMP"
else
    # 多文件模式
    for prefix in "${!FILE_MAP[@]}"; do
        src="${FILE_MAP[$prefix]}"
        if [ ! -f "$src" ]; then
            echo "  ⚠️  文件不存在: $src，跳过"
            continue
        fi
        COVERED_TMP=$(mktemp)
        stats=$(extract_covered_lines "$src" "$prefix" "$COVERED_TMP")
        TOTAL_LINES=$(echo "$stats" | cut -d'|' -f1)
        CONTENT_LINES=$(echo "$stats" | cut -d'|' -f2)
        COVERED_COUNT=$(echo "$stats" | cut -d'|' -f3)

        COVERAGE=$(echo "scale=1; $COVERED_COUNT * 100 / ${CONTENT_LINES:-1}" | bc 2>/dev/null || echo "0")
        echo ""
        echo "  [$prefix] $(basename "$src")"
        echo "  有内容行数:    $CONTENT_LINES"
        echo "  标注覆盖行数:  $COVERED_COUNT"
        echo "  覆盖率:        ${COVERAGE}%"

        OVERALL_CONTENT=$((OVERALL_CONTENT + CONTENT_LINES))
        OVERALL_COVERED=$((OVERALL_COVERED + COVERED_COUNT))

        PASS=$(echo "$COVERAGE >= 95" | bc 2>/dev/null || echo "0")
        if [ "$PASS" -eq 1 ]; then
            echo "  ✅ 通过"
        else
            echo "  ❌ 不通过"
            ALL_PASS=false
        fi
        rm -f "$COVERED_TMP"
    done

    if [ "$OVERALL_CONTENT" -gt 0 ]; then
        OVERALL_COVERAGE=$(echo "scale=1; $OVERALL_COVERED * 100 / $OVERALL_CONTENT" | bc 2>/dev/null || echo "0")
        echo ""
        echo "  总体覆盖率:    ${OVERALL_COVERAGE}%"
        echo "  健康线:        ≥ 95%"
    fi
fi

echo ""

if $ALL_PASS; then
    echo "  ✅ 通过 — 全部文件覆盖率 ≥ 95%"
    exit 0
else
    echo "  ❌ 不通过 — 存在文件覆盖率 < 95%"
    exit 1
fi
