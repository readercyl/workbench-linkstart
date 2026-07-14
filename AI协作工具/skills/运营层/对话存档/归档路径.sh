#!/usr/bin/env bash
# 归档路径.sh — 根据当前时间确定对话存档的目标文件
# 用法: bash AI协作工具/skills/运营层/对话存档/归档路径.sh [标题]
#   - 追加模式（已有文件）：标题参数可选，忽略
#   - 新建模式（无文件）：标题参数必填，作为文件名中的主题关键词
# 输出: 归档日期、目标文件路径、操作类型（追加/新建）
#
# 规则: 6点为界。6点前属于前一天归档日，6点后属于当天归档日。

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT=${WORKBENCH_ROOT:-$(cd "$SCRIPT_DIR/../../../.." && pwd)}
ARCHIVE_DIR="$PROJECT/00-运转日志/对话记录"
TITLE="${1:-}"

HOUR=$(date +%H)
MINUTE=$(date +%M)

if [ "$HOUR" -lt 6 ]; then
    # 6点前：归档日 = 昨天
    if date -v-1d +%Y-%m-%d >/dev/null 2>&1; then
        ARCHIVE_DATE=$(date -v-1d +%Y-%m-%d)
    else
        ARCHIVE_DATE=$(date -d 'yesterday' +%Y-%m-%d)
    fi
    TIME_NOTE="凌晨 $(printf '%02d:%02d' "$HOUR" "$MINUTE")，属于前一天归档日"
else
    # 6点后：归档日 = 今天
    ARCHIVE_DATE=$(date +%Y-%m-%d)
    TIME_NOTE="$(printf '%02d:%02d' "$HOUR" "$MINUTE")，属于当天归档日"
fi

# 查找归档日的已有文件
EXISTING_FILES=("$ARCHIVE_DIR/$ARCHIVE_DATE"*.md)

if [ -e "${EXISTING_FILES[0]}" ]; then
    FILE_COUNT=${#EXISTING_FILES[@]}
    if [ "$FILE_COUNT" -eq 1 ]; then
        TARGET_FILE="${EXISTING_FILES[0]}"
        ACTION="追加"
    else
        # 多个文件：选最新的
        TARGET_FILE=$(ls -t "${EXISTING_FILES[@]}" | head -1)
        ACTION="追加（注意：归档日有 ${FILE_COUNT} 个文件，应考虑合并）"
    fi
else
    # 新建模式：标题必填
    if [ -z "$TITLE" ]; then
        echo "❌ 错误：新建归档文件必须提供标题参数" >&2
        echo "用法: bash $0 \"主题关键词\"" >&2
        echo "标题应概括当天核心内容，如「三层架构建立与全系统收口」" >&2
        exit 1
    fi
    TARGET_FILE="$ARCHIVE_DIR/${ARCHIVE_DATE}-${TITLE}.md"
    ACTION="新建"
fi

echo "归档日期: $ARCHIVE_DATE"
echo "当前时间: $TIME_NOTE"
echo "目标文件: $TARGET_FILE"
echo "操作类型: $ACTION"
