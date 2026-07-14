#!/bin/bash
# 错字扫描 · v1.0
# 对指定文件扫描常见同音/形近替换错字。日报和对话存档写入后必须运行。
# 用法：bash 错字扫描.sh <文件路径>
# 退出码 0 = 未发现可疑，1 = 发现可疑字符（需人工逐处判断）

set -euo pipefail

FILE="$1"
[ -z "$FILE" ] && echo "用法: $0 <文件路径>" && exit 1
[ ! -f "$FILE" ] && echo "❌ 文件不存在: $FILE" && exit 1

# 已知的错字对：正确 → 常见错误
# 格式：错误写法（grep 正则）
PATTERNS=(
    # 辨证/辩证 互换
    '辩证'    # 应为「辩证」时写成「辨证」
    '辨证'    # 应为「辨证」时写成「辩证」（两者都扫，人工判断）
    # 形近替换
    '锡点'    # anchor point → 应为「锚点」
    '沉澳'    # 应为「沉淀」
    '祠魅'    # 应为「祛魅」
    '一卆'    # 应为「一卒」
    '炸耀'    # 应为「炫耀」
    # 其他低频同音/形近
    '辩正'    # 应为「辩证」
    '祛魅'    # 扫到提醒——「祛魅」本身正确但常被写成「祠魅」
    '锚点'    # 扫到提醒——「锚点」本身正确但常被写成「锡点」
)

FOUND=0
FOUND_ITEMS=()

for pattern in "${PATTERNS[@]}"; do
    matches=$(grep -n "$pattern" "$FILE" 2>/dev/null || true)
    if [ -n "$matches" ]; then
        # 过滤：跳过在代码块/命令示例中的匹配（以 ``` 或 $ 开头的行）
        real_matches=$(echo "$matches" | grep -v '^\s*[0-9]*:\s*```' | grep -v '^\s*[0-9]*:\s*$' || true)
        if [ -n "$real_matches" ]; then
            FOUND=$((FOUND + 1))
            FOUND_ITEMS+=("$real_matches")
        fi
    fi
done

if [ "$FOUND" -eq 0 ]; then
    echo -e "\033[32m[错字扫描] ✅ 未发现可疑字符\033[0m"
    exit 0
else
    echo -e "\033[31m[错字扫描] ⚠️ 发现 $FOUND 处可疑字符，需人工逐处判断：\033[0m"
    for item in "${FOUND_ITEMS[@]}"; do
        echo "$item"
    done
    echo ""
    echo "常见错字对参考："
    echo "  辨证 ↔ 辩证（语境决定）"
    echo "  锚点 ≠ 锡点"
    echo "  沉淀 ≠ 沉澳"
    echo "  祛魅 ≠ 祠魅"
    echo "  一卒 ≠ 一卆"
    echo "  炫耀 ≠ 炸耀"
    exit 1
fi
