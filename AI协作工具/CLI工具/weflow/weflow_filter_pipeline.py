#!/usr/bin/env python3
"""
WeFlow 微信聊天记录双层过滤一键管道启动器 (weflow_filter_pipeline.py)

该脚本充当统一启动器，串联执行：
1. Layer 1 结构清洗与 wxid 翻译 (weflow_processor.py -l)
2. Layer 2 大模型高精语义过滤 (weflow_semantic_filter.py)

功能特性：
- 完美支持单个 .txt 文件或整个目录的批量处理。
- 自动为所有被处理的原始文件创建 .bak 安全备份，确保不可逆操作的数据安全。
- 自动计算并输出详细的字数压缩比及降噪率统计报告。
"""

import os
import sys
import shutil
import subprocess
from typing import List, Dict

# 获取当前脚本所在文件夹的绝对路径，确保内部调用路径的稳定性
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROCESSOR_SCRIPT = os.path.join(SCRIPT_DIR, "weflow_processor.py")
SEMANTIC_FILTER_SCRIPT = os.path.join(SCRIPT_DIR, "weflow_semantic_filter.py")

def get_char_count(filepath: str) -> int:
    """获取文件字符数（不含空白字符，以进行公平且准确的字数对比）"""
    if not os.path.exists(filepath):
        return 0
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
            # 移除所有空白字符计算纯净字符数
            return len("".join(content.split()))
    except Exception:
        return 0

def run_command(cmd: List[str]) -> bool:
    """运行外部命令并返回是否成功"""
    try:
        # 使用 subprocess.run，将 stdout/stderr 实时打印，提供极佳的交互体感
        res = subprocess.run(cmd, check=True)
        return res.returncode == 0
    except subprocess.CalledProcessError as e:
        print(f"\n❌ 命令执行失败: {' '.join(cmd)}")
        print(f"   错误代码: {e.returncode}")
        return False
    except Exception as e:
        print(f"\n❌ 执行命令时发生异常: {e}")
        return False

def clean_single_file(filepath: str) -> Dict:
    """清洗单个微信聊天记录文件，串联执行双层过滤并在最外层进行安全备份"""
    filename = os.path.basename(filepath)
    print(f"\n" + "="*80)
    print(f"🚀 开始处理文件: {filename}")
    print(f"📂 路径: {filepath}")
    print("="*80)

    # 1. 初始统计与安全备份
    orig_chars = get_char_count(filepath)
    bak_path = filepath + ".bak"
    
    # 始终在第一步为原始记录制作备份，杜绝意外丢失
    print(f"💾 正在创建安全备份...")
    try:
        shutil.copy2(filepath, bak_path)
        print(f"   ✓ 备份已就绪: {os.path.basename(bak_path)}")
    except Exception as e:
        print(f"   ❌ 备份创建失败 ({e})，为确保数据安全，终止处理！")
        return None

    # 2. 执行 Layer 1 (结构清洗、wxid 翻译与去重)
    print(f"\n⚡ [Layer 1] 运行结构清洗与 wxid 翻译 ({os.path.basename(PROCESSOR_SCRIPT)})...")
    layer1_cmd = ["python3", PROCESSOR_SCRIPT, filepath, "-l"]
    if not run_command(layer1_cmd):
        print(f"❌ Layer 1 失败，终止该文件后续处理。")
        return None
    
    layer1_chars = get_char_count(filepath)
    layer1_diff = orig_chars - layer1_chars
    print(f"   ✓ Layer 1 完成: 字符数 {orig_chars} -> {layer1_chars} (降噪: -{layer1_diff} 字, {(layer1_diff/orig_chars*100):.1f}%)" if orig_chars > 0 else "")

    # 3. 执行 Layer 2 (大模型高精语义过滤)
    print(f"\n🧠 [Layer 2] 运行大模型语义去噪 ({os.path.basename(SEMANTIC_FILTER_SCRIPT)})...")
    layer2_cmd = ["python3", SEMANTIC_FILTER_SCRIPT, filepath]
    if not run_command(layer2_cmd):
        print(f"❌ Layer 2 失败，保留 Layer 1 的清洗状态。")
        final_chars = layer1_chars
    else:
        final_chars = get_char_count(filepath)

    # 4. 计算统计数据
    total_diff = orig_chars - final_chars
    reduction_rate = (total_diff / orig_chars * 100) if orig_chars > 0 else 0.0
    
    print(f"\n✨ {filename} 清洗完成！")
    print(f"   原始字数: {orig_chars} 字")
    print(f"   脱水字数: {final_chars} 字")
    print(f"   整体降噪率: -{total_diff} 字 ({reduction_rate:.1f}%)")
    
    return {
        "filename": filename,
        "orig": orig_chars,
        "layer1": layer1_chars,
        "final": final_chars,
        "reduction": reduction_rate,
        "success": True
    }

def main():
    if len(sys.argv) < 2:
        print("💡 用法:")
        print("  python3 weflow_filter_pipeline.py <文件路径>    # 清洗单个聊天记录")
        print("  python3 weflow_filter_pipeline.py <目录路径>    # 批量清洗目录下的所有聊天记录")
        sys.exit(1)

    target = os.path.abspath(sys.argv[1])

    if not os.path.exists(target):
        print(f"❌ 错误: 路径不存在 '{target}'")
        sys.exit(1)

    # 收集待处理的 txt 文件列表
    files_to_process = []
    if os.path.isfile(target):
        if target.endswith('.txt') and not target.endswith('.bak'):
            files_to_process.append(target)
        else:
            print("❌ 错误: 指定文件不是合法的微信聊天记录 .txt 文本")
            sys.exit(1)
    elif os.path.isdir(target):
        # 扫描目录下所有的群聊和私聊 TXT 文件
        for f in sorted(os.listdir(target)):
            full_path = os.path.join(target, f)
            if (f.endswith('.txt') 
                and not f.endswith('.bak') 
                and '副本' not in f 
                and (f.startswith('群聊_') or f.startswith('私聊_'))):
                files_to_process.append(full_path)

    if not files_to_process:
        print(f"❌ 未在指定路径下找到符合条件的微信聊天记录文件 (*.txt)")
        sys.exit(1)

    print("\n" + "="*80)
    print(f"🎬 微信聊天记录一键清洗管道启动 (共 {len(files_to_process)} 个文件)")
    print(f"   [Layer 1] -> {os.path.basename(PROCESSOR_SCRIPT)}")
    print(f"   [Layer 2] -> {os.path.basename(SEMANTIC_FILTER_SCRIPT)}")
    print("="*80)

    stats = []
    for i, filepath in enumerate(files_to_process, 1):
        print(f"\n📂 正在执行第 {i}/{len(files_to_process)} 个文件...")
        res = clean_single_file(filepath)
        if res:
            stats.append(res)

    # 5. 输出汇总报告
    if stats:
        print("\n\n" + "="*80)
        print("📊 微信聊天记录双层过滤一键管道汇总报告")
        print("="*80)
        print(f"{'文件名称':<40} | {'原始字符':<10} | {'最终字符':<10} | {'降噪率':<10}")
        print("-"*80)
        
        total_orig = 0
        total_final = 0
        
        for s in stats:
            print(f"{s['filename'][:38]:<40} | {s['orig']:<10,} | {s['final']:<10,} | -{s['reduction']:.1f}%")
            total_orig += s['orig']
            total_final += s['final']
            
        print("-"*80)
        total_reduction = ((total_orig - total_final) / total_orig * 100) if total_orig > 0 else 0.0
        print(f"{'【全局汇总统计】':<40} | {total_orig:<10,} | {total_final:<10,} | -{total_reduction:.1f}%")
        print("="*80)
        print("🎉 所有文件处理完成，原始备份已就地以 .bak 格式完好保存！")
    else:
        print("\n❌ 未能成功处理任何文件。")

if __name__ == '__main__':
    main()
