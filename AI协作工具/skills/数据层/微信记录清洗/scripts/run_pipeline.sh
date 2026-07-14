#!/bin/bash
# WeFlow 记录处理 — 双层高精过滤管道启动器
# 用法: bash run_pipeline.sh <WeFlow .txt 文件路径或目录路径>
# 此脚本是 weflow_filter_pipeline.py 的入口封装

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PIPELINE="$SCRIPT_DIR/../../../CLI工具脚本/weflow/weflow_filter_pipeline.py"

if [ ! -f "$PIPELINE" ]; then
    echo "错误: 找不到管道脚本 $PIPELINE"
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "用法: bash run_pipeline.sh <WeFlow .txt 文件或目录路径>"
    echo "示例: bash run_pipeline.sh 素材箱/_待处理/微信记录/群聊_xxx.txt"
    echo "示例: bash run_pipeline.sh 素材箱/_待处理/微信记录/"
    exit 1
fi

python3 "$PIPELINE" "$@"
