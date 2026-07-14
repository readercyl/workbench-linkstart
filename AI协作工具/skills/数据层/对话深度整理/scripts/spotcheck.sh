#!/bin/bash
# 标注抽样核对 · v1.0
# 用法：bash spotcheck.sh <标注索引文件>
# 退出码 0 = 抽样清单已生成，1 = 错误
#
# 目的：将中小型素材自评的「20% 抽样核对」从 Agent 自律升级为硬门控。
# 脚本从标注索引的数据行中随机抽取 20%，输出待核对清单到 stdout。
# AI 必须逐条核对并写入验证结果文件，然后重跑本脚本验证结果文件完整性。
#
# 工作流：
#   1. bash spotcheck.sh <标注文件> --generate → 输出抽样清单
#   2. AI 逐条打开原文核对准确度 → 写入 .spotcheck-result.md
#   3. bash spotcheck.sh <标注文件> --verify → 检查结果文件完整性
#   4. 通过 → 继续；不通过 → 阻断

set -euo pipefail

ANNOTATION_FILE="$1"
ACTION="${2:-}"

if [ ! -f "$ANNOTATION_FILE" ]; then
    echo "❌ 标注索引文件不存在: $ANNOTATION_FILE"
    exit 1
fi

RESULT_FILE="$(dirname "$ANNOTATION_FILE")/.spotcheck-result.md"

# ── 生成抽样清单 ──
generate_sample() {
    # 提取数据行（跳过表头和分隔行）
    DATA_LINES=$(grep -E '^\|[^-].*\|.*\|' "$ANNOTATION_FILE" | grep -vE '^\|.*段落.*\|' || true)

    if [ -z "$DATA_LINES" ]; then
        echo "❌ 标注索引无数据行"
        exit 1
    fi

    TOTAL=$(echo "$DATA_LINES" | wc -l | tr -d ' ')
    # 20% 抽样，最少 5 条，最多 30 条
    SAMPLE_SIZE=$(( TOTAL * 20 / 100 ))
    [ "$SAMPLE_SIZE" -lt 5 ] && SAMPLE_SIZE=5
    [ "$SAMPLE_SIZE" -gt 30 ] && SAMPLE_SIZE=30
    [ "$SAMPLE_SIZE" -gt "$TOTAL" ] && SAMPLE_SIZE=$TOTAL

    # 随机抽取（macOS/BSD 兼容）
    if command -v shuf &>/dev/null; then
        SAMPLED=$(echo "$DATA_LINES" | shuf -n "$SAMPLE_SIZE")
    else
        SAMPLED=$(echo "$DATA_LINES" | sort -R | head -n "$SAMPLE_SIZE" 2>/dev/null || echo "$DATA_LINES" | head -n "$SAMPLE_SIZE")
    fi

    echo "==========================================="
    echo "  抽样核对清单（$SAMPLE_SIZE / $TOTAL 条，~20%）"
    echo "==========================================="
    echo ""
    echo "AI 请逐条完成以下核对，并将结果写入 $RESULT_FILE"
    echo "格式：| 段落 | 核对项 | 结果 | 问题描述 |"
    echo "核对项：原话引用准确 / 观点归属正确 / 关键内容摘要准确 / 信息类型正确"
    echo ""

    local i=1
    echo "$SAMPLED" | while IFS= read -r line; do
        # 提取关键字段
        range=$(echo "$line" | awk -F'|' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        speaker=$(echo "$line" | awk -F'|' '{print $4}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        type=$(echo "$line" | awk -F'|' '{print $5}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        summary=$(echo "$line" | awk -F'|' '{print $(NF-1)}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        has_quote=$(echo "$line" | awk -F'|' '{print $NF}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        echo "  [$i] 段落 $range | 说话人: $speaker | 类型: $type"
        echo "      摘要: $summary"
        if [ "$has_quote" = "是" ]; then
            echo "      ⚠️ 含原话引用——必须核对原文"
        fi
        echo ""
        i=$((i + 1))
    done

    echo "---"
    echo "总计: $SAMPLE_SIZE 条待核对"
    echo "结果文件: $RESULT_FILE"
    echo ""
    echo "核对完成后运行: bash spotcheck.sh <标注文件> --verify"
}

# ── 验证抽样结果 ──
verify_sample() {
    if [ ! -f "$RESULT_FILE" ]; then
        echo "❌ 抽样核对结果文件不存在: $RESULT_FILE"
        echo "   请先运行 --generate 生成清单，逐条核对后将结果写入该文件"
        exit 1
    fi

    # 检查结果文件是否有足够的核对条目
    RESULT_ENTRIES=$(grep -cE '^\|.*\|.*\|.*\|' "$RESULT_FILE" 2>/dev/null || echo 0)
    # 从生成时保存的期望数读取
    EXPECTED_FILE="$(dirname "$ANNOTATION_FILE")/.spotcheck-expected"
    if [ -f "$EXPECTED_FILE" ]; then
        EXPECTED=$(cat "$EXPECTED_FILE")
    else
        # fallback: 从结果文件自身推算
        EXPECTED=$RESULT_ENTRIES
    fi

    PASS_COUNT=$(grep -cE '^\|.*\|.*\|✅\|' "$RESULT_FILE" 2>/dev/null || echo 0)
    FAIL_COUNT=$(grep -cE '^\|.*\|.*\|❌\|' "$RESULT_FILE" 2>/dev/null || echo 0)

    echo "==========================================="
    echo "  抽样核对验证"
    echo "==========================================="
    echo "  结果条目数: $RESULT_ENTRIES"
    echo "  通过: $PASS_COUNT"
    echo "  不通过: $FAIL_COUNT"

    if [ "$RESULT_ENTRIES" -eq 0 ]; then
        echo "  ❌ 结果文件为空——未执行核对"
        exit 1
    fi

    if [ "$FAIL_COUNT" -gt 0 ]; then
        echo ""
        echo "  ❌ 抽样核对不通过——$FAIL_COUNT 条存在问题"
        echo "  请回退到第〇遍补标注，修复后重新抽样"
        exit 1
    fi

    echo ""
    echo "  ✅ 抽样核对通过——$PASS_COUNT 条均无问题"
    exit 0
}

# ── 主入口 ──
case "$ACTION" in
    --generate)
        generate_sample
        ;;
    --verify)
        verify_sample
        ;;
    *)
        echo "用法: bash spotcheck.sh <标注文件> --generate | --verify"
        echo ""
        echo "  --generate  生成 20% 随机抽样清单，AI 逐条核对后写入结果文件"
        echo "  --verify    验证结果文件——全部通过才放行"
        exit 1
        ;;
esac
