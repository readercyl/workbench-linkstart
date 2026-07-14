#!/bin/bash
# 编译后校验 · v3.0
# 收口时运行，验证系统级数字一致性（MOC覆盖归 S1-机械扫描.sh）
# 用法：bash 编译后校验.sh
# 退出码 0 = 全部一致，1 = 存在不一致

set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

ERRORS=0
WARNINGS=0

check_count() {
    local label="$1" file="$2" pattern="$3"
    local file_count=$(grep -oE "$pattern" "$file" 2>/dev/null | head -1 | grep -oE '[0-9]+' || echo "")
    if [ -z "$file_count" ] || [ "$file_count" = "0" ]; then
        yellow "  ⚠️  $label: 未找到数字格式"
        WARNINGS=$((WARNINGS + 1))
    elif [ "$file_count" = "$actual_count" ]; then
        green "  ✅ $label ($file_count) = 实际 ($actual_count)"
    else
        red "  ❌ $label: 写 ${file_count}，实际 ${actual_count}"
        ERRORS=$((ERRORS + 1))
    fi
}

echo "编译后校验 · 系统数字一致性"
echo "=============================="

actual_count=$(find "$CARDS_DIR" -name "*.md" ! -name "index.md" ! -name "log.md" | wc -l | tr -d ' ')
echo "实际卡片数: $actual_count"
echo ""

check_count "index.md"       "$INDEX_FILE"   '[0-9]+ 张原子卡片'
check_count "CLAUDE.md"      "$CLAUDE_FILE"  '[0-9]+ 张卡片'
check_count "人物档案.md"     "$PROFILE_FILE" '[0-9]+ 张原子卡片'

if grep -q "$TODAY" "$LOG_FILE" 2>/dev/null; then
    green "  ✅ log.md 今日编译记录存在"
else
    yellow "  ⚠️  log.md: 未找到今日 ($TODAY) 记录"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
[ "$ERRORS" -eq 0 ] && green "通过" || red "$ERRORS 项不一致"
exit "$ERRORS"
