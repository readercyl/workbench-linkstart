#!/bin/bash
# 日报数据.sh · v1.0
# 收集日报所需机械数据，输出 JSON 供 AI 引用。
# 用法：bash 日报数据.sh [date_covered]

set -euo pipefail

# 前置依赖检查
if ! command -v jq &>/dev/null; then
    echo '{"error":"jq 未安装——日报数据不可用。请安装 jq（brew install jq）后重试。"}' >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
DATE_COVERED="${1:-$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d 'yesterday' +%Y-%m-%d)}"
TODAY=$(date +%Y-%m-%d)

CARDS_DIR="$REPO_ROOT/02-知识卡片/知识卡片"
PROFILE_DIR="$REPO_ROOT/01-关于我"
ARCHIVE_DIR="$REPO_ROOT/00-运转日志/对话记录"
REPORT_DIR="$REPO_ROOT/00-运转日志/日报"
PENDING_DIR="$REPO_ROOT/素材箱/_待处理"
LOG_FILE="$REPO_ROOT/02-知识卡片/log.md"

# 卡片总数
CARD_COUNT=$(find "$CARDS_DIR" -name "*.md" ! -name "index.md" ! -name "log.md" | wc -l | tr -d ' ')

# 个人说明书文件数（排除子宪法）
PROFILE_COUNT=$(find "$PROFILE_DIR" -name "*.md" ! -name "CLAUDE.md" | wc -l | tr -d ' ')

# 对话存档数
ARCHIVE_COUNT=$(ls "$ARCHIVE_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')

# 日报数
REPORT_COUNT=$(ls "$REPORT_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')

# 待处理文件数
PENDING_COUNT=$(find "$PENDING_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')

# 前日报告（用于算增量）
YESTERDAY_REPORT=$(ls "$REPORT_DIR/${TODAY}"*.md 2>/dev/null | head -1 || echo "")

# 昨日 log 中的编译记录
LOG_ENTRIES=$(grep "$DATE_COVERED" "$LOG_FILE" 2>/dev/null | head -5 || echo "")

# 昨日 git commits
GIT_COMMITS=$(cd "$REPO_ROOT" && git log --oneline --since="$DATE_COVERED" --until="$TODAY" 2>/dev/null | head -5 || echo "")

# 昨日 consolidated 对话存档
CONSOLIDATED=$(ls "$ARCHIVE_DIR/${DATE_COVERED}"*.md 2>/dev/null | while read f; do
    grep -q "consolidated: true" "$f" 2>/dev/null && echo "$f"
done || echo "")

# 前日卡片数（从覆盖日前一天的日报提取）
PREV_REPORT_FILE=$(ls "$REPORT_DIR/${DATE_COVERED}"*.md 2>/dev/null | head -1 || echo "")
if [ -n "$PREV_REPORT_FILE" ]; then
    PREV_CARD_COUNT=$(grep '知识卡片总数' "$PREV_REPORT_FILE" 2>/dev/null | grep -oE '\| [0-9]+' | head -1 | grep -oE '[0-9]+' || echo "?")
    CARD_DELTA=$((CARD_COUNT - PREV_CARD_COUNT))
else
    PREV_CARD_COUNT="?"
    CARD_DELTA="?"
fi

# 输出
cat << JSON
{
  "date_covered": "$DATE_COVERED",
  "today": "$TODAY",
  "card_count": $CARD_COUNT,
  "prev_card_count": "$PREV_CARD_COUNT",
  "card_delta": "$CARD_DELTA",
  "prev_report": "$YESTERDAY_REPORT",
  "profile_count": $PROFILE_COUNT,
  "archive_count": $ARCHIVE_COUNT,
  "report_count": $REPORT_COUNT,
  "pending_count": $PENDING_COUNT,
  "log_entries": $(echo "$LOG_ENTRIES" | jq -R -s . 2>/dev/null || echo '""'),
  "git_commits": $(echo "$GIT_COMMITS" | jq -R -s . 2>/dev/null || echo '""'),
  "consolidated_archive": $(echo "$CONSOLIDATED" | jq -R -s -c 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]'),
  "yesterday_substantive": $( [ -n "$CONSOLIDATED" ] && echo "true" || echo "false" )
}
JSON
