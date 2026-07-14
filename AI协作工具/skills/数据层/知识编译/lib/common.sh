#!/bin/bash
# lib/common.sh · v1.0
# 知识编译脚本共享库：路径常量、色值函数、工具函数、配置常量。
# 用法：source "$(dirname "$0")/lib/common.sh"

# ── REPO_ROOT 统一计算 ──
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$_LIB_DIR/../../../../.." && pwd)"

# ── 路径常量 ──
CARDS_DIR="$REPO_ROOT/02-知识卡片/知识卡片"
MOC_DIR="$REPO_ROOT/02-知识卡片/MOC"
INDEX_FILE="$REPO_ROOT/02-知识卡片/index.md"
CLAUDE_FILE="$REPO_ROOT/CLAUDE.md"
PROFILE_FILE="$REPO_ROOT/01-关于我/人物档案.md"
LOG_FILE="$REPO_ROOT/02-知识卡片/log.md"
CALL_RECORD="$REPO_ROOT/00-运转日志/知识卡片调用记录.md"
MATERIAL_DIR="$REPO_ROOT/素材箱"
PENDING_DIR="$REPO_ROOT/素材箱/_待处理"
MANUAL_FLAG="$REPO_ROOT/素材箱/.compile-force-sync"
SYNC_LOG="$REPO_ROOT/素材箱/.compile-sync-log"
NETWORK_INDEX="$REPO_ROOT/02-知识卡片/.network_index.json"

# ── 色值函数（统一前缀：[知识编译]）──
red()    { echo -e "\033[31m[知识编译] $1\033[0m"; }
green()  { echo -e "\033[32m[知识编译] $1\033[0m"; }
yellow() { echo -e "\033[33m[知识编译] $1\033[0m"; }
cyan()   { echo -e "\033[36m[知识编译] $1\033[0m"; }

# ── 工具函数 ──
trim() {
    # 去除首尾空白
    echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

safe_grep_count() {
    # grep -c 的 set -e 安全包装：匹配 0 次返回 0 而非 exit 1
    local pattern="$1" file="$2"
    grep -c "$pattern" "$file" 2>/dev/null || echo 0
}

# ── 配置常量 ──
VALID_SOURCE_TYPES="flomo|视频日记|文章|分享|课程|讨论|AI对话|个人实践"
TYPED_LINK_PREFIXES="支撑|互见|张力|应用于"
FORCE_SYNC_THRESHOLD=20

TODAY=$(date +%Y-%m-%d)
