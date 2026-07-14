#!/bin/bash
# 视频日记导出保护 · v1.0
# 每次 getnote 导出视频日记到素材箱后立即运行。
# 检查：原语转写节存在 / 有实际内容 / 含说话人标记
# 退出码 0 = 通过，1 = 违规（打印违规项，AI 必须重新导出）

set -euo pipefail

FILE="$1"
[ -z "$FILE" ] && echo "[导出保护] 用法: $0 <导出文件路径>" && exit 1
[ ! -f "$FILE" ] && echo "[导出保护] ❌ 文件不存在: $FILE" && exit 1

ERRORS=0
red()   { echo -e "\033[31m[导出保护] $1\033[0m"; ERRORS=$((ERRORS + 1)); }
green() { echo -e "\033[32m[导出保护] $1\033[0m"; }

# 1. 原语转写节必须存在（H2 级别）
if ! grep -q '^## 原语转写' "$FILE"; then
    red "❌ 缺少「## 原语转写」节——导出不完整，必须包含 audio.original 字段"
else
    green "✅ 原语转写节存在"

    # 2. 原语转写节下面必须有实际内容（不是空节）
    # 从 ## 原语转写 行之后取内容，跳过空行，检查是否有文字
    AFTER_TRANSCRIPT=$(sed -n '/^## 原语转写/,$ p' "$FILE" | tail -n +2)
    if [ -z "$(echo "$AFTER_TRANSCRIPT" | tr -d '[:space:]')" ]; then
        red "❌ 原语转写节为空——未导出 audio.original 内容"
    else
        green "✅ 原语转写节有内容"

        # 3. 必须包含说话人标记（确认是真实转写文本而非 AI 摘要）
        SPEAKER_COUNT=$(echo "$AFTER_TRANSCRIPT" | grep -c '🟢 说话人' || echo 0)
        SPEAKER_COUNT=$(echo "$SPEAKER_COUNT" | tr -d ' \n\t')
        if [ "$SPEAKER_COUNT" -eq 0 ]; then
            red "❌ 原语转写中未检测到「🟢 说话人」标记——内容可能不是逐字转写"
        else
            green "✅ 检测到 $SPEAKER_COUNT 处说话人标记"
        fi

        # 4. 原语转写内容量检查——至少 200 字符（防止只导出一两句）
        CHAR_COUNT=$(echo "$AFTER_TRANSCRIPT" | wc -m | tr -d ' ')
        if [ "$CHAR_COUNT" -lt 200 ]; then
            red "⚠️ 原语转写内容过短（${CHAR_COUNT} 字符）——可能导出不完整"
        fi
    fi
fi

# 5. 智能总结节必须存在
if ! grep -q '^### 📑 智能总结' "$FILE"; then
    red "⚠️ 缺少「📑 智能总结」节"
else
    green "✅ 智能总结节存在"
fi

# 6. 章节概要节必须存在
if ! grep -q '^### 📅 章节概要' "$FILE"; then
    red "⚠️ 缺少「📅 章节概要」节"
else
    green "✅ 章节概要节存在"
fi

echo ""
if [ "$ERRORS" -eq 0 ]; then
    # 6. 文件名格式校验——必须含「第N天」和描述性标题
    FILENAME=$(basename "$FILE")
    if ! echo "$FILENAME" | grep -qE '第[0-9]+天'; then
        red "❌ 文件名缺少「第N天」——格式应为 YYYY-MM-DD-第N天-简短描述.md"
    elif echo "$FILENAME" | grep -qE '第[0-9]+天-视频日记\.md$'; then
        red "⚠️ 文件名以「视频日记」结尾——应替换为描述性标题（如「线下聚会与软件维护」）"
    else
        green "✅ 文件名格式正确"
    fi
fi

echo ""
if [ "$ERRORS" -eq 0 ]; then
    green "✅ 全部通过——导出内容完整"
    exit 0
else
    red "❌ $ERRORS 项违规，必须重新导出完整内容后再继续"
    echo ""
    echo "   常见原因："
    echo "   1. 用了 getnote notes（摘要模式）而非 getnote note <id>（详情模式）"
    echo "   2. 导出时漏了 audio.original 字段"
    echo "   3. API 返回不完整——重试 getnote note <id>"
    exit 1
fi
