#!/bin/bash
# 灾备检查 — 框架层审核 Skill 框架审计项
# 版本：v1.1 · 2026-07-12
# 检查 git remote 可达性、上次 push 状态、.git 完整性

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$REPO_ROOT"

DEFAULT_BRANCH=$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null | sed 's|origin/||')
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
export DEFAULT_BRANCH

FAILED=0
green() { echo "  🟢 $*"; }
red()   { echo "  🔴 $*"; FAILED=$((FAILED + 1)); }
yellow(){ echo "  🟡 $*"; }

echo "🔍 灾备检查"
echo "============"

# 1. Git remote 可达性
REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
if [ -z "$REMOTE" ]; then
    red "无 git remote origin"
else
    echo "  Remote: $REMOTE"
    if git ls-remote --heads origin "${DEFAULT_BRANCH}" &>/dev/null; then
        green "Remote 可达（分支: ${DEFAULT_BRANCH}）"
    else
        red "Remote 不可达——无法推送或拉取"
    fi
fi

# 2. 本地领先远程的提交数
AHEAD=$(git rev-list --count "origin/${DEFAULT_BRANCH}..HEAD" 2>/dev/null || echo "?")
BEHIND=$(git rev-list --count "HEAD..origin/${DEFAULT_BRANCH}" 2>/dev/null || echo "?")
if [ "$AHEAD" = "?" ]; then
    yellow "无法比较本地与远程（可能无网络或首次推送）"
else
    if [ "$AHEAD" -eq 0 ] && [ "$BEHIND" -eq 0 ]; then
        green "本地与远程同步"
    elif [ "$AHEAD" -gt 0 ] && [ "$BEHIND" -eq 0 ]; then
        yellow "本地领先远程 $AHEAD 个提交——需要 push"
    elif [ "$BEHIND" -gt 0 ] && [ "$AHEAD" -eq 0 ]; then
        yellow "远程领先本地 $BEHIND 个提交——需要 pull"
    else
        red "本地与远程分叉：领先 $AHEAD / 落后 $BEHIND"
    fi
fi

# 3. .git 目录完整性
if [ -d ".git" ]; then
    if [ -f ".git/HEAD" ] && [ -d ".git/objects" ] && [ -d ".git/refs" ]; then
        green ".git 目录结构完整"
    else
        red ".git 目录结构不完整——仓库可能损坏"
    fi
else
    red ".git 目录不存在"
fi

# 4. 未跟踪的大文件（可能该加入 .gitignore 或 LFS）
BIG_FILES_ALL=$(find . -type f -size +50M -not -path './.git/*' 2>/dev/null)
BIG_FILES=$(echo "$BIG_FILES_ALL" | head -5)
TOTAL_BIG=$(echo "$BIG_FILES_ALL" | grep -c . 2>/dev/null || echo 0)
if [ -n "$BIG_FILES" ]; then
    yellow "发现大文件（>50MB）："
    echo "$BIG_FILES" | while read f; do echo "    $f"; done
    if [ "$TOTAL_BIG" -gt 5 ]; then
        echo "    ... 仅显示前 5 个，共 ${TOTAL_BIG} 个"
    fi
else
    green "无超大文件"
fi

# 5. .gitignore 是否排斥关键目录
for dir in ".claude/" "AI协作工具/skills/" "02-知识卡片/知识卡片/" "01-关于我/"; do
    if git check-ignore "$dir" &>/dev/null; then
        red "$dir 被 .gitignore 排斥——不会被备份！"
    fi
done

echo ""
if [ "$FAILED" -eq 0 ]; then
    green "✅ 灾备检查通过"
    exit 0
else
    red "🔴 灾备检查失败：$FAILED 项"
    exit 1
fi
