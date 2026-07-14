#!/usr/bin/env bash
# cron-refresh.sh · 工作台工作空间
# 每次 Claude Code 启动时执行。刷新全部 recurring cron 的 lastFiredAt，
# 防止 7 天过期上限导致任务静默消失。不设闸门。

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT=${WORKBENCH_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}
CRON_FILE="$PROJECT/.claude/scheduled_tasks.json"
LOCK_FILE="$PROJECT/.claude/scheduled_tasks.lock"

[ -f "$CRON_FILE" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# 锁检查：防止与 cron daemon 并发写冲突
if [ -f "$LOCK_FILE" ]; then
    LOCK_SESSION=$(jq -r '.sessionId // empty' "$LOCK_FILE" 2>/dev/null)
    if [ -n "$LOCK_SESSION" ] && [ "$LOCK_SESSION" != "null" ]; then
        exit 0
    fi
fi

NOW_MS=$(($(date +%s) * 1000))
REFRESH_IDS=$(jq -r '.tasks[]? | select((.recurring // false) == true) | .id // empty' "$CRON_FILE")

for id in $REFRESH_IDS; do
    jq --arg now "$NOW_MS" --arg id "$id" \
      '(.tasks[]? | select(.id == $id) | .lastFiredAt) |= ($now | tonumber)' \
      "$CRON_FILE" > "$CRON_FILE.tmp" && mv "$CRON_FILE.tmp" "$CRON_FILE"
done
