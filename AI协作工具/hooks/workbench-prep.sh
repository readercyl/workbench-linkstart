#!/usr/bin/env bash
# workbench-prep.sh · 用户工作台工作空间
# 每日启动自检：工作台准备——5 项任务，AI 顺序执行。
#
# 触发闸门（双重）:
#   【闸门1·时间窗口】6:00 ≤ 当前小时 < 18:00。凌晨和晚间静默退出，推迟到次日
#   【闸门2·消息匹配】AI 检查用户是否发送了早上问候语（如「早上好」「早啊」「早」等），不是则跳过全部

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT=${WORKBENCH_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}
if [ -f "$PROJECT/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    . "$PROJECT/.env"
    set +a
fi
NOW_HOUR=$(date +%k | tr -d ' ')
TODAY=$(date +%Y-%m-%d)
if date -v-1d +%Y-%m-%d >/dev/null 2>&1; then
    YESTERDAY=$(date -v-1d +%Y-%m-%d)
else
    YESTERDAY=$(date -d 'yesterday' +%Y-%m-%d)
fi

# ============================================================
# 闸门1：时间窗口检查——6:00 前或 18:00 后静默退出
# ============================================================
if [ "$NOW_HOUR" -lt 6 ] || [ "$NOW_HOUR" -ge 18 ]; then
    exit 0
fi

TASKS=()

# ============================================================
# 任务 1：周一检测 → 提议周复盘
# ============================================================
DOW=$(date +%u)
if [ "$DOW" = "1" ]; then
    TASKS+=("[周复盘] 周一，调周复盘 Skill")
fi

# ============================================================
# 任务 2：日报（整理昨日存档 + 生成今日日报，日报 Skill 内部先整理再生成，AI 只调一次）
# ============================================================
YESTERDAY_ARCHIVES=("$PROJECT/00-运转日志/对话记录/$YESTERDAY-"*.md)
DAILY_NEED_CONSOLIDATE=false
if [ -e "${YESTERDAY_ARCHIVES[0]}" ]; then
    for f in "${YESTERDAY_ARCHIVES[@]}"; do
        if ! grep -q '^consolidated:[[:space:]]*true' "$f" 2>/dev/null; then
            DAILY_NEED_CONSOLIDATE=true
            break
        fi
    done
fi
DAILY_REPORT_MATCH=$(ls "$PROJECT/00-运转日志/日报/${TODAY}"*.md 2>/dev/null | head -n 1)
DAILY_NEED_REPORT=false
[ -z "$DAILY_REPORT_MATCH" ] && DAILY_NEED_REPORT=true

if $DAILY_NEED_CONSOLIDATE && $DAILY_NEED_REPORT; then
    TASKS+=("[日报] 昨日存档缺 consolidated + ${TODAY} 日报未生成 → 调日报 Skill")
elif $DAILY_NEED_CONSOLIDATE; then
    TASKS+=("[日报] 昨日存档缺 consolidated:true → 调日报 Skill 整理修订")
elif $DAILY_NEED_REPORT; then
    TASKS+=("[日报] ${TODAY} 日报未生成 → 调日报 Skill")
fi

# ============================================================
# 任务 3：视频日记导出检查
# ============================================================
LATEST_VIDEO_EXPORT=$(ls -1 "$PROJECT/素材箱/视频日记/"*.md 2>/dev/null | sort -r | head -1)
VIDEO_NEED_CHECK=false
LATEST_EXPORT_DATE="无"
if [ -z "$LATEST_VIDEO_EXPORT" ]; then
    VIDEO_NEED_CHECK=true
else
    LATEST_EXPORT_DATE=$(basename "$LATEST_VIDEO_EXPORT" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || true)
    LATEST_NUM=${LATEST_EXPORT_DATE//-/}
    YESTERDAY_NUM=${YESTERDAY//-/}
    if ! [[ "$LATEST_NUM" =~ ^[0-9]{8}$ ]] || [ "$LATEST_NUM" -lt "$YESTERDAY_NUM" ]; then
        VIDEO_NEED_CHECK=true
    fi
fi

if [ "$VIDEO_NEED_CHECK" = true ]; then
    if [ -n "${GETNOTE_TOPIC_ID:-}" ]; then
        TASKS+=("[视频日记] 最新导出 ${LATEST_EXPORT_DATE}，用 list_topic_notes 检查 getnote topic ${GETNOTE_TOPIC_ID}，有则导出到素材箱/_待处理/视频日记/。导出后立即跑视频日记导出保护.sh，不通过则重新导出")
        # ============================================================
        # 任务 4：知识编译（依赖任务 3）
        # ============================================================
        TASKS+=("[知识编译] 任务3导出新文件且内容值得编译 → 调知识编译 Skill；不值得编译 → 直接归档到素材箱/视频日记/。编译和归档是两件独立的事")
    else
        TASKS+=("[视频日记] 未配置 GETNOTE_TOPIC_ID，跳过自动检查；需要时在本机环境变量中配置")
    fi
fi

# ============================================================
# 任务 5：安全网——深度内容候选
# ============================================================

DEEP_CANDIDATE=$(grep -rl "DEEP_ORGANIZE_CANDIDATE: true" "$PROJECT/00-运转日志/对话记录/" 2>/dev/null | head -1)
if [ -n "$DEEP_CANDIDATE" ]; then
    TASKS+=("[深度内容] $(basename "$DEEP_CANDIDATE") 标记为深度内容候选 → 建议调「对话深度整理」+「知识编译」")
fi

# 没有待执行任务 → 静默退出
if [ ${#TASKS[@]} -eq 0 ]; then
    exit 0
fi

# 拼接输出：闸门2 + 顺序执行标记 + 待执行任务
TASK_LINES=$(printf ' · %s\n' "${TASKS[@]}")
CONTEXT="工作台准备 [$(date '+%Y-%m-%d %H:%M')] · 闸门2: 仅用户发送早上问候语才执行 · 顺序：1→2→3→4→5 · 任务2/5 内部可并行，3→4 串行
${TASK_LINES}"

if command -v jq >/dev/null 2>&1; then
    jq -nc --arg ctx "$CONTEXT" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json, sys; print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": sys.argv[1]}}, ensure_ascii=False))' "$CONTEXT"
fi
