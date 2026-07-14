#!/bin/bash
# 编译收口.sh · v3.0
# 知识编译第二阶段收口：机械同步全自动 + AI 语义步骤提示。
# v2.0→v3.0：队列文件改为 frontmatter 自描述——扫描 moc_added=false 卡片替代读队列文件，消除单点故障。
#
# 用法：
#   bash 编译收口.sh                脚本自动判断是否收口
#   bash 编译收口.sh --force         手动触发，跳过条件检查
#   bash 编译收口.sh --done          AI 完成语义步骤后调，标记 moc_added=true
#
# 退出码：
#   0 = 无需收口
#   1 = 错误
#   2 = 机械同步完成，AI 需执行语义步骤

set -eo pipefail

source "$(dirname "$0")/lib/common.sh"

ACTION="${1:-}"
FORCE=false
CLEAR_ONLY=false
if [ "$ACTION" = "--force" ]; then FORCE=true; fi
if [ "$ACTION" = "--done" ]; then CLEAR_ONLY=true; fi

# ── 扫描待收口卡片（moc_added: false）──
scan_pending() {
    PENDING_CARDS=()
    PENDING_COUNT=0
    for card in "$CARDS_DIR"/*.md; do
        [ -f "$card" ] || continue
        if grep -q '^moc_added: false' "$card" 2>/dev/null; then
            name=$(basename "$card" .md)
            PENDING_CARDS+=("$name")
            PENDING_COUNT=$((PENDING_COUNT + 1))
        fi
    done
}

# ── 数字同步 + log 写入 ──
do_number_sync() {
    local count=$1
    shift
    local card_names=("$@")

    ACTUAL=$(find "$CARDS_DIR" -name "*.md" ! -name "index.md" ! -name "log.md" | wc -l | tr -d ' ')
    sed -i '' "s/\*\*当前规模\*\*：[0-9][0-9]* 张原子卡片/**当前规模**：$ACTUAL 张原子卡片/" "$INDEX_FILE"
    sed -i '' "s/最近更新：[0-9-][0-9-]*/最近更新：$TODAY/" "$INDEX_FILE"
    sed -i '' "s/[0-9][0-9]* 张卡片/$ACTUAL 张卡片/" "$CLAUDE_FILE"
    sed -i '' "s/[0-9][0-9]* 张原子卡片/$ACTUAL 张原子卡片/" "$PROFILE_FILE"
    green "✅ 卡片数量同步：$ACTUAL 张（index.md / CLAUDE.md / 人物档案）"

    # log.md 追加
    local name_list=""
    for cn in "${card_names[@]}"; do name_list="${name_list}\`${cn}\`、"; done
    name_list="${name_list%?}"
    local prev=$((ACTUAL - count))
    local log_entry="| $TODAY | 编译收口：${count} 张新卡 → ${name_list}。卡片总数 ${prev}→${ACTUAL}。 |"
    sed -i '' "2a\\
\\
${log_entry}" "$LOG_FILE"
    green "✅ log.md 已追加"

    # 调用记录补写
    for cn in "${card_names[@]}"; do
        grep -qF "[[$cn]]" "$CALL_RECORD" 2>/dev/null || echo "| [[$cn]] | 0 |" >> "$CALL_RECORD"
    done
}

# ══════════════════════════════════════════
# --done：AI 完成语义步骤后，标记完成
# ══════════════════════════════════════════
if $CLEAR_ONLY; then
    scan_pending
    if [ "$PENDING_COUNT" -gt 0 ]; then
        for cn in "${PENDING_CARDS[@]}"; do
            sed -i '' 's/^moc_added: false/moc_added: true/' "$CARDS_DIR/$cn.md"
        done
        echo "$TODAY $(date +%H:%M) 收口 · $PENDING_COUNT 张卡片" >> "$SYNC_LOG"
        green "✅ 标记 moc_added=true：$PENDING_COUNT 张卡，收口完成。"
    else
        green "无待收口卡片。"
    fi
    exit 0
fi

# ══════════════════════════════════════════
# 触发条件判断
# ══════════════════════════════════════════

echo ""

scan_pending

if [ "$PENDING_COUNT" -eq 0 ]; then
    green "📭 无待收口卡片（moc_added=false），跳过。"
    exit 0
fi

MATERIAL_PENDING=$(find "$PENDING_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')

MANUAL=false
if [ -f "$MANUAL_FLAG" ]; then
    MANUAL=true
    rm -f "$MANUAL_FLAG"
fi

TRIGGER_REASON=""

if $FORCE; then
    TRIGGER_REASON="手动触发 (--force)"
elif $MANUAL; then
    TRIGGER_REASON="手动触发（标记文件）"
elif [ "$MATERIAL_PENDING" -eq 0 ] && [ "$PENDING_COUNT" -gt 0 ]; then
    TRIGGER_REASON="待处理已空，编译自然终点"
elif [ "$PENDING_COUNT" -ge "$FORCE_SYNC_THRESHOLD" ]; then
    TRIGGER_REASON="待收口卡片已达 $PENDING_COUNT 张，强制收口"
else
    # 检查最早 moc_added=false 卡片的创建时间
    OLDEST_CARD=""
    OLDEST_TIME=0
    for cn in "${PENDING_CARDS[@]}"; do
        created=$(grep '^created:' "$CARDS_DIR/$cn.md" 2>/dev/null | sed 's/created: //' | head -1)
        if [ -n "$created" ]; then
            ts=$(date -j -f "%Y-%m-%d" "$created" +%s 2>/dev/null || echo 0)
            if [ "$ts" -gt 0 ]; then
                age=$(($(date +%s) - ts))
                if [ "$age" -gt "$OLDEST_TIME" ]; then
                    OLDEST_TIME=$age
                    OLDEST_CARD="$cn"
                fi
            fi
        fi
    done
    if [ "$OLDEST_TIME" -gt 86400 ]; then
        TRIGGER_REASON="最旧待收口卡超过 24 小时"
    fi
fi

if [ -z "$TRIGGER_REASON" ]; then
    yellow "⏳ 待收口 $PENDING_COUNT 张 · 待处理 $MATERIAL_PENDING 件 · 继续编译"
    exit 0
fi

green "🔔 收口触发：$TRIGGER_REASON ($PENDING_COUNT 张卡)"
echo ""

# ══════════════════════════════════════════
# 机械同步（全自动）
# ══════════════════════════════════════════

CHECK_FAILED=false

# ── 1. 数字同步 + log 写入 ──
do_number_sync "$PENDING_COUNT" "${PENDING_CARDS[@]}"

# ── 2. 编译后校验 ──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CARD_PATHS=""
for cn in "${PENDING_CARDS[@]}"; do CARD_PATHS="$CARD_PATHS $CARDS_DIR/$cn.md"; done
if bash "$SCRIPT_DIR/编译后校验.sh" $CARD_PATHS; then
    green "✅ 编译后校验：全部通过"
else
    red "❌ 编译后校验：存在不合格项"
    CHECK_FAILED=true
fi

echo ""

# ══════════════════════════════════════════
# AI 语义待办
# ══════════════════════════════════════════

cyan "┌─────────────────────────────────────────┐"
cyan "│     🤖 AI 待办（收口·必须执行）        │"
cyan "└─────────────────────────────────────────┘"
echo ""

echo "  1. MOC 归入"
echo "     对以上 $PENDING_COUNT 张新卡做语义 MOC 归入"
echo ""

if [ "$PENDING_COUNT" -le 2 ]; then
    echo "  2. 矛盾检测 [跳过]"
    echo "     本批仅 $PENDING_COUNT 张卡，矛盾影响面太小"
else
    echo "  2. 矛盾检测"
    echo "     grep 关键词预筛 → AI 语义判断 → 输出结果"
fi
echo ""

echo "  3. 简化报告"
echo "     📦 收口：新增 $PENDING_COUNT 张卡（MOC分布），校验✅/❌"
echo ""

echo "  4. 发布提醒"
echo "     💡 编译完成后检查：自上次发布以来是否已累积足够内容值得发布？"
echo ""

echo "  5. 标记收口完成"
echo "     bash AI协作工具/skills/数据层/知识编译/编译收口.sh --done"
echo ""

cyan "──────────────────────────────────────────"
echo ""

$CHECK_FAILED && exit 1 || exit 2
