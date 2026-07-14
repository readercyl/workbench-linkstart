#!/usr/bin/env python3
"""
微信聊天记录全量去噪清洗批处理包装器 (run_batch_clean.py)

该脚本会：
1. 扫描微信记录目录。
2. 自动检测并跳过已拥有 .bak 备份（代表在之前测试中已清洗）的 6 个文件。
3. 依次对剩余 31 个文件调用 weflow_filter_pipeline.py 执行双层过滤。
4. 运行结束后，按照用户指令，自动删除目录下产生的所有 .bak 备份文件。
"""

import os
import sys
import subprocess
import glob
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
WORKBENCH_ROOT = Path(os.environ.get("WORKBENCH_ROOT", SCRIPT_DIR.parents[2]))
WECHAT_DIR = str(WORKBENCH_ROOT / "素材箱/_待处理/微信记录")
PIPELINE_SCRIPT = str(SCRIPT_DIR / "weflow_filter_pipeline.py")
LOG_FILE = os.environ.get(
    "WEFLOW_LOG_FILE",
    str(WORKBENCH_ROOT / "00-运转日志/weflow-batch-clean.log"),
)

def main():
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    if not os.path.exists(WECHAT_DIR):
        print(f"❌ 目录不存在: {WECHAT_DIR}")
        sys.exit(1)

    # 1. 扫描目录下所有的 txt 文件
    all_files = sorted([
        os.path.join(WECHAT_DIR, f) for f in os.listdir(WECHAT_DIR)
        if f.endswith('.txt') and not f.endswith('.bak') and '副本' not in f
    ])

    files_to_clean = []
    skipped_files = []

    for f in all_files:
        bak_file = f + ".bak"
        if os.path.exists(bak_file):
            skipped_files.append(f)
        else:
            files_to_clean.append(f)

    # 写入初始日志
    with open(LOG_FILE, 'w', encoding='utf-8') as log:
        log.write("="*80 + "\n")
        log.write("🎬 微信聊天记录全量清洗批处理任务启动\n")
        log.write(f"📂 目标目录: {WECHAT_DIR}\n")
        log.write(f"🔍 发现 TXT 文件共: {len(all_files)} 个\n")
        log.write(f"⏭️ 已跳过（测试中已清洗）: {len(skipped_files)} 个\n")
        log.write(f"⚡ 待清洗文件共: {len(files_to_clean)} 个\n")
        log.write("="*80 + "\n\n")
        
        for sf in skipped_files:
            log.write(f"[已跳过] {os.path.basename(sf)} (存在 .bak 备份)\n")
        log.write("\n" + "-"*80 + "\n\n")
        log.flush()

    print(f"🔍 扫描完成。共 {len(all_files)} 个文件，跳过已清洗的 {len(skipped_files)} 个，开始清洗剩余的 {len(files_to_clean)} 个...")
    print(f"📄 运行过程将记录在日志中: {LOG_FILE}")

    # 2. 依次运行清洗命令
    success_count = 0
    fail_count = 0

    for i, f in enumerate(files_to_clean, 1):
        filename = os.path.basename(f)
        msg = f"⏳ [{i}/{len(files_to_clean)}] 正在清洗: {filename} ...\n"
        print(msg.strip())
        
        with open(LOG_FILE, 'a', encoding='utf-8') as log:
            log.write(msg)
            log.flush()

        try:
            # 调用 weflow_filter_pipeline.py 处理该文件
            cmd = ["python3", PIPELINE_SCRIPT, f]
            # 捕获并合并输出到我们的全局日志文件中
            with open(LOG_FILE, 'a', encoding='utf-8') as log:
                res = subprocess.run(cmd, stdout=log, stderr=log, text=True, check=True)
            
            if res.returncode == 0:
                success_count += 1
                with open(LOG_FILE, 'a', encoding='utf-8') as log:
                    log.write(f"✓ 成功完成: {filename}\n\n")
                    log.flush()
            else:
                fail_count += 1
                with open(LOG_FILE, 'a', encoding='utf-8') as log:
                    log.write(f"❌ 失败: {filename} (返回码 {res.returncode})\n\n")
                    log.flush()
        except Exception as e:
            fail_count += 1
            with open(LOG_FILE, 'a', encoding='utf-8') as log:
                log.write(f"💥 异常: {filename} ({e})\n\n")
                log.flush()

    # 3. 清理收尾工作 (删除所有 .bak 文件)
    with open(LOG_FILE, 'a', encoding='utf-8') as log:
        log.write("="*80 + "\n")
        log.write("🧹 任务执行完成，开始按用户指令清理所有 .bak 备份文件...\n")
        log.flush()

    print("\n🧹 任务执行完成，开始清理备份文件...")
    
    bak_files = glob.glob(os.path.join(WECHAT_DIR, "*.txt.bak"))
    deleted_count = 0
    for bf in bak_files:
        try:
            os.remove(bf)
            deleted_count += 1
        except Exception as e:
            print(f"⚠️ 无法删除备份 {os.path.basename(bf)}: {e}")

    with open(LOG_FILE, 'a', encoding='utf-8') as log:
        log.write(f"✓ 成功删除 {deleted_count} 个 .bak 备份文件，目录已恢复纯净。\n")
        log.write(f"🎉 任务结束。成功: {success_count} 个，失败: {fail_count} 个。\n")
        log.write("="*80 + "\n")
        log.flush()

    print(f"🎉 全量处理结束！成功 {success_count} 个，失败 {fail_count} 个，已清理 {deleted_count} 个备份。")

if __name__ == '__main__':
    main()
