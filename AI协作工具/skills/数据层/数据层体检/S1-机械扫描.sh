#!/bin/bash
# S1 机械扫描 — 数据层体检 Skill 快速模式
# 版本：v2.0 · 2026-07-11
# 精简至 4 项核心：死链（由 analyze_network.py 单独执行）、卡片计数+frontmatter、MOC覆盖、调用记录统计
# 全部零 AI token，exit 0 = 全通过

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
CARDS_DIR="$REPO_ROOT/02-知识卡片/知识卡片"
MOC_DIR="$REPO_ROOT/02-知识卡片/MOC"
CALL_LOG="$REPO_ROOT/00-运转日志/知识卡片调用记录.md"
FAILED=0
WARNINGS=0

red()   { echo "  🔴 $*"; FAILED=$((FAILED + 1)); }
yellow(){ echo "  🟡 $*"; WARNINGS=$((WARNINGS + 1)); }
green() { echo "  🟢 $*"; }
check() { local label="$1" level="$2" msg="$3"; case "$level" in fail) red "[$label] $msg";; warn) yellow "[$label] $msg";; pass) green "[$label] $msg";; esac; }

echo "🔍 数据层体检 · S1 机械扫描（4 项核心）"
echo "=========================================="
echo ""

# ── S1.2 卡片计数 + frontmatter 完整性 ──
echo "📊 S1.2 卡片计数 + frontmatter 完整性"
CARD_COUNT=$(ls "$CARDS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
NO_CREATED=$(for f in "$CARDS_DIR"/*.md; do grep -q '^created:' "$f" 2>/dev/null || echo "$f"; done | wc -l | tr -d ' ')
NO_SOURCE=$(for f in "$CARDS_DIR"/*.md; do grep -q '^source_type:' "$f" 2>/dev/null || echo "$f"; done | wc -l | tr -d ' ')
NO_STATUS=$(for f in "$CARDS_DIR"/*.md; do grep -q '^status:' "$f" 2>/dev/null || echo "$f"; done | wc -l | tr -d ' ')

echo "  卡片总数: $CARD_COUNT"
[ "$NO_CREATED" -eq 0 ] && check "frontmatter" pass "created 字段完整" || check "frontmatter" fail "$NO_CREATED 张卡缺少 created 字段"
[ "$NO_SOURCE" -eq 0 ] && check "frontmatter" pass "source_type 字段完整" || check "frontmatter" fail "$NO_SOURCE 张卡缺少 source_type 字段"
[ "$NO_STATUS" -eq 0 ] && check "frontmatter" pass "status 字段完整" || check "frontmatter" fail "$NO_STATUS 张卡缺少 status 字段"

# ── S1.3 MOC 覆盖 ──
echo ""
echo "📂 S1.3 MOC 覆盖"
MOC_CARDS=$(mktemp)
ALL_CARDS=$(mktemp)
for moc in "$MOC_DIR"/MOC-*.md; do
    [ -f "$moc" ] || continue
    grep -o '\[\[[^]]*\]\]' "$moc" 2>/dev/null | sed 's/\[\[//;s/\]\]//' | sort -u >> "$MOC_CARDS" || true
done
sort -u "$MOC_CARDS" -o "$MOC_CARDS"
for card in "$CARDS_DIR"/*.md; do
    basename "$card" .md >> "$ALL_CARDS"
done
sort "$ALL_CARDS" -o "$ALL_CARDS"
UNCOVERED=$(comm -23 "$ALL_CARDS" "$MOC_CARDS" | wc -l | tr -d ' ')
MOC_COUNT=$(comm -12 "$ALL_CARDS" "$MOC_CARDS" | wc -l | tr -d ' ')
COVERAGE=$(python3 -c "print(round($MOC_COUNT/$CARD_COUNT*100,1))" 2>/dev/null || echo '?')

echo "  MOC 已收录: $MOC_COUNT / $CARD_COUNT (${COVERAGE}%)"
[ "$UNCOVERED" -eq 0 ] && check "MOC覆盖" pass "全部卡片已归入 MOC" || check "MOC覆盖" fail "$UNCOVERED 张卡未被任何 MOC 收录"
rm -f "$MOC_CARDS" "$ALL_CARDS"

# ── S1.4 调用记录统计 ──
echo ""
echo "📈 S1.4 调用记录统计"
if [ -f "$CALL_LOG" ]; then
    CALL_CARD_COUNT=$(grep -c '^| \[' "$CALL_LOG" 2>/dev/null || echo 0)
    # 检查是否有 count=1 基线的新卡未入调用记录
    NEW_CARDS_WITHOUT_CALL=0
    for card in "$CARDS_DIR"/*.md; do
        name=$(basename "$card" .md)
        if ! grep -q "\[\[$name\]\]" "$CALL_LOG" 2>/dev/null; then
            NEW_CARDS_WITHOUT_CALL=$((NEW_CARDS_WITHOUT_CALL + 1))
        fi
    done
    echo "  调用记录卡片数: $CALL_CARD_COUNT / 实际: $CARD_COUNT"
    [ "$NEW_CARDS_WITHOUT_CALL" -eq 0 ] && check "调用记录" pass "所有卡片已入调用记录" || check "调用记录" warn "$NEW_CARDS_WITHOUT_CALL 张卡未入调用记录"
else
    check "调用记录" warn "调用记录文件不存在，跳过检查"
fi

# ── 汇总 ──
echo ""
echo "============================"
if [ "$FAILED" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    green "✅ S1 全通过——系统健康，可跳深度模式"
    exit 0
elif [ "$FAILED" -eq 0 ]; then
    yellow "⚠️  S1 通过但有 $WARNINGS 项警告——建议继续深度模式确认"
    exit 0
else
    red "🔴 S1 失败：$FAILED 项致命 + $WARNINGS 项警告——必须进入深度模式"
    exit 1
fi
