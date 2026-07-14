#!/usr/bin/env python3
# /// script
# dependencies = [
#   "pyyaml",
# ]
# ///

"""
WeFlow 微信记录处理管道 (就地修改版)
直接读取 WeFlow 导出的 TXT 聊天记录，翻译 wxid 为真实昵称，剔除社交噪音，
并将清洗后的数据【原地写入覆盖】原来的 TXT 文件，绝不产生多余的 Markdown 文件或造成跨文件夹串台。
"""

import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple, Optional

SCRIPT_DIR = Path(__file__).resolve().parent
WORKBENCH_ROOT = Path(os.environ.get("WORKBENCH_ROOT", SCRIPT_DIR.parents[2]))

# ============================================================
# 正则与配置
# ============================================================

# WeFlow 消息头部正则，支持单/双引号包裹的发送者 ID
# 例如: 2026-04-28 16:13:42 'wxid_duw9sfaxv0bm22'
HEADER_PATTERN = re.compile(r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) [\'"]([^\'"]+)[\'"]\s*$')

# 必须删除的噪音模式
MUST_DELETE = [
    # 匹配撤回消息提示
    re.compile(r'撤回了一条消息'),
    # 匹配版本不支持的空白占位
    re.compile(r'当前版本不支持展示该内容'),
    # 其他特定的无价值卡片
    re.compile(r'\[appmsg type=2001\].*红包'),
    re.compile(r'^和.+共同群聊\+1'),
    re.compile(r'\[appmsg type=63\]'),  # 直播卡片
    re.compile(r'拍了拍'),  # 拍一拍
    re.compile(r'^\[链接\]\s.*拍了拍'),
    # 新增显式系统提示噪音过滤
    re.compile(r'加入了群聊'),
    re.compile(r'与群里其他人都不是朋友关系，请注意隐私安全'),
    re.compile(r'邀请你加入了群聊'),
    re.compile(r'已启用“群聊邀请确认”'),
    re.compile(r'修改群名为'),
]

# 纯占位符行：整行仅由一个或多个 [xxx] 组成（不含其他文字）
PLACEHOLDER_ONLY_RE = re.compile(r'^(\s*\[[^\]]+\]\s*)+$')


# 运营垃圾过滤词库
OPS_NOTICE = [
    re.compile(r'已提交.*谢谢'),
    re.compile(r'已填写.*谢谢'),
    re.compile(r'已注册.*谢谢'),
    re.compile(r'谢谢波波'),
    re.compile(r'谢谢.*老师.*生财'),
    re.compile(r'填写.*表单'),
    re.compile(r'抖查查.*会员'),
    re.compile(r'周边.*申请'),
    re.compile(r'寄送周边'),
    re.compile(r'龙珠月报'),
    re.compile(r'晋升仪式'),
    re.compile(r'传术师.*布道师.*理念'),
    re.compile(r'独行者速.*众行者远'),
    re.compile(r'小灯塔'),
    re.compile(r'#接龙'),
    # 新增直播预约/刷屏等重复文本正则
    re.compile(r'已预约.*不见不散|不见不散.*已预约|已预约.*直播间'),
]

# 核心价值保留关键词（群聊激进过滤时使用）
VALUE_KEYWORDS = re.compile(
    r'(?i)('
    # AI工具
    r'cursor|claude\s*code|coze|扣子|deepseek|chatgpt|gpt-?4|claude|gemini|copilot|midjourney|comfyui|suno|可灵|即梦|stable.?diffusion|openai|openrouter|ollama'
    r'|bolt|lovable|v0|vercel|replit|n8n|make\.com|zapier|dify|langchain|flowise|rag|llm|agent|mcp'
    # 工作工具
    r'|飞书|多维表格|字段捷径|notion|obsidian|flomo|airtable|feishu'
    # 平台
    r'|小红书|公众号|视频号|抖音|tiktok|youtube|shorts|bilibili|知乎|即刻|小程序|独立站|shopify|etsy'
    # 商业
    r'|变现|月入|年入|营收|利润|流水|毛利|eCPM|广告收入|私域|公域|流量池|粉丝量|转化率|ROI|GMV|客单价|复购率|付费率'
    r'|商业模式|盈利模式|赚钱方式|副业|创业|自由职业|被动收入|蓝海|红海|信息差|痛点|卖点|定价|成本'
    # 内容创作方法
    r'|爆款|爆文|选题|标题党|封面|SEO|搜索词|算法|推荐机制|分发|矩阵|IP定位|人设|涨粉|带货|种草|投放|引流|获客'
    r'|文案|脚本|拍摄|剪辑|CapCut|剪映'
    # 技术
    r'|api|sdk|python|javascript|react|nextjs|swift|ios\s*app|android|部署|上架|审核|代码|编程|工作流|自动化|rpa|影刀|webhook'
    r'|prompt|提示词|fine.?tune|embedding|token|向量'
    # 方法论
    r'|方法论|SOP|复盘|经验总结|教程|技巧|策略|框架|模型|模板|清单|案例|数据分析'
    r')'
)

QINGCHENG = re.compile(r'用户|@用户')

# ============================================================
# 工具函数
# ============================================================

def clean_text(content: str) -> str:
    """去除中括号占位符、@、引用标记等，提取纯净文本用于字数计算"""
    t = content
    t = re.sub(r'\[引用[^\]]*\]', '', t)
    t = re.sub(r'\[[\w\u4e00-\u9fff]+\]', '', t)
    t = re.sub(r'@\S+\s*', '', t)
    return t.strip()


def should_keep(sender: str, content: str, is_group: bool, strict_private: bool = False, layer1_only: bool = False) -> bool:
    """语义级别过滤器"""
    stripped = content.strip()
    
    # 1. 纯占位符/独立表情包过滤
    if not stripped or PLACEHOLDER_ONLY_RE.match(stripped):
        return False
        
    # 2. 必须删除的硬垃圾/系统噪音过滤
    for p in MUST_DELETE:
        if p.search(stripped):
            return False
            
    # 3. 运营与刷屏通知过滤
    for p in OPS_NOTICE:
        if p.search(content):
            return False

    # 如果仅执行第一层过滤 (Layer 1)，在此直接返回 True
    if layer1_only:
        return True

    # 如果是群聊，或者启用了私聊严格过滤，则执行激进过滤以节省 Token
    if is_group or strict_private:
        # 用户发的内容或提到用户的内容 -> 保留 (保持上下文连贯性)
        if '用户' in sender or QINGCHENG.search(content):
            return True
            
        # 包含高密度价值关键词 -> 保留
        if VALUE_KEYWORDS.search(content):
            return True
            
        # 包含链接 -> 保留
        if 'http' in content:
            return True
            
        # 大批量 @ 人 -> 删除
        if len(re.findall(r'@\S+', content)) >= 3:
            return False
            
        # 长度过滤逻辑
        net = clean_text(content)
        if not net:
            return False
            
        if len(net) < 20:
            return False
            
        if len(net) < 50:
            # 中等长度需包含特定实质词汇才保留
            has_substance = bool(re.search(
                r'(\d+[万w%]+|经验|方法|建议|推荐|发现|思路|逻辑|关键|核心|本质|规律|趋势|机会|风险|问题|解决|优化|提升|增长)',
                net
            ))
            return has_substance
            
        # >= 50 字默认保留
        return True
    
    else:
        # 如果是私聊且未开启严格模式，只做硬噪音剔除（保留大部分完整上下文）
        net = clean_text(content)
        # 过滤完全空的消息（如仅有被删表情包的消息）
        if not net and not any(tag in content for tag in ['[图片]', '[语音]', '[视频]', '[文件]', '[语音转文字]']):
            return False
            
        return True


def parse_weflow_txt(filepath: str) -> List[Dict]:
    """解析 WeFlow TXT 文件"""
    messages = []
    current_msg = None
    
    with open(filepath, 'r', encoding='utf-8-sig') as f:
        for line in f:
            stripped = line.rstrip('\r\n')
            match = HEADER_PATTERN.match(stripped)
            if match:
                if current_msg:
                    messages.append(current_msg)
                current_msg = {
                    'time': match.group(1),
                    'sender_id': match.group(2),
                    'content_lines': []
                }
            else:
                if current_msg is not None:
                    current_msg['content_lines'].append(line)
                    
        if current_msg:
            messages.append(current_msg)
            
    # 合并多行内容
    for msg in messages:
        msg['content'] = ''.join(msg['content_lines']).strip()
        del msg['content_lines']
        
    return messages


def load_whitelist_mappings() -> Dict[str, str]:
    """加载 whitelist.yaml 映射"""
    whitelist_path = Path(os.environ.get(
        "WEFLOW_WHITELIST",
        WORKBENCH_ROOT / "AI协作工具/skills/微信记录导出/whitelist.yaml",
    ))
    id_to_name = {'我': '用户'}
    if os.path.exists(whitelist_path):
        try:
            import yaml
            with open(whitelist_path, 'r', encoding='utf-8') as f:
                data = yaml.safe_load(f)
                # 导入私聊映射
                for contact in data.get('contacts', []):
                    if 'username' in contact and 'chat' in contact:
                        id_to_name[contact['username']] = contact['chat']
                # 导入群聊映射
                for group in data.get('groups', []):
                    if 'username' in group and 'chat' in group:
                        id_to_name[group['username']] = group['chat']
        except Exception as e:
            print(f"⚠️ 提示: 加载 whitelist.yaml 失败 ({e})，将主要依赖目录昵称反查。")
    return id_to_name


def get_clean_duplicate_key(text: str) -> str:
    """移除所有空白字符、标点、常用表情中括号等，只保留核心文字内容用于重复检测"""
    t = text.strip().lower()
    t = re.sub(r'\[引用[^\]]*\]', '', t) # 忽略引用部分，只比较正文
    t = re.sub(r'[\s[\]玫瑰抱拳捂脸~，。！？!,!?_]+', '', t)
    return t


def process_weflow_in_place(target_path: str, strict: bool = False, layer1: bool = False):
    """就地修改 WeFlow 导出的 TXT 文件"""
    
    # 如果传入的是目录，自动定位其中的 .txt 文件
    if os.path.isdir(target_path):
        txt_files = [f for f in os.listdir(target_path) if f.endswith('.txt')]
        if not txt_files:
            print(f"❌ 错误: 文件夹 {target_path} 下没有找到 .txt 文本记录")
            return
        txt_path = os.path.join(target_path, txt_files[0])
        folder_path = os.path.abspath(target_path)
    else:
        txt_path = os.path.abspath(target_path)
        folder_path = os.path.dirname(txt_path)
        
    folder_name = os.path.basename(folder_path)
    parts = folder_name.split('_')
    
    chat_type = None
    target_nickname = None
    
    if len(parts) >= 2:
        chat_type = parts[0]       # '私聊' 或 '群聊'
        target_nickname = parts[1] # 对方昵称（如“示例联系人”）
    else:
        # 尝试从文件名解析，例如 "群聊_中午吃啥、怎么还不下班_全部时间.txt"
        file_name = os.path.basename(txt_path)
        file_parts = file_name.replace('.txt', '').split('_')
        if len(file_parts) >= 2:
            chat_type = file_parts[0]
            target_nickname = file_parts[1]
            
    if not chat_type or not target_nickname:
        print(f"❌ 错误: 无法从文件夹名 '{folder_name}' 或文件名 '{os.path.basename(txt_path)}' 解析出聊天类型和名称 (需符合 '类型_名称_...' 格式)")
        return
        
    is_group = (chat_type == '群聊')
    
    print(f"📦 正在原地解析: {txt_path} ({chat_type} - {target_nickname}, 严格模式={strict}, 仅第一层过滤={layer1})")
    
    # 1. 解析原始消息
    raw_messages = parse_weflow_txt(txt_path)
    total_raw = len(raw_messages)
    print(f"✓ 共解析出 {total_raw} 条原始记录")
    if total_raw == 0:
        print("⚠️ 警告: 没有解析出任何微信消息（可能文件已经是清洗后的格式，或者格式不匹配，直接退出）")
        return
    
    # 2. 获取映射字典
    id_to_name = load_whitelist_mappings()
    
    # 3. 翻译并过滤消息
    clean_messages = []
    filtered_count = 0
    
    # 每日内容重复检测集合，key为日期 YYYY-MM-DD，value为已看见的内容核心 key 的集合
    daily_seen_contents = {}
    
    for msg in raw_messages:
        msg_date = msg['time'][:10]
        
        sender_id = msg['sender_id']
        
        # 好友昵称对齐
        if sender_id in id_to_name:
            sender_name = id_to_name[sender_id]
        elif not is_group and sender_id != '我':
            sender_name = target_nickname
        else:
            sender_name = sender_id
            
        # 如果是群聊，且发送者为群组昵称，则是群系统消息，直接过滤
        if is_group and sender_name == target_nickname:
            filtered_count += 1
            continue
            
        content = msg['content']
        
        # 过滤与保留逻辑
        if should_keep(sender_name, content, is_group, strict_private=strict, layer1_only=layer1):
            # 重复信息去重逻辑 (每天内相同核心内容的消息仅保留第一条)
            dup_key = get_clean_duplicate_key(content)
            if dup_key:
                if msg_date not in daily_seen_contents:
                    daily_seen_contents[msg_date] = set()
                
                if dup_key in daily_seen_contents[msg_date]:
                    filtered_count += 1
                    continue
                else:
                    daily_seen_contents[msg_date].add(dup_key)
                    
            clean_messages.append({
                'time': msg['time'],
                'sender': sender_name,
                'content': content
            })
        else:
            filtered_count += 1
            
    # 4. 原地写回 TXT 文件 (极简日期归档与剧本格式)
    output_lines = []
    current_date = None
    
    for msg in clean_messages:
        # 提取 YYYY-MM-DD 日期
        msg_date = msg['time'][:10]
        
        # 如果日期发生改变，插入日期标题
        if msg_date != current_date:
            if current_date is not None:
                output_lines.append("\n") # 天与天之间保留一个空行
            output_lines.append(f"# {msg_date}\n")
            current_date = msg_date
            
        # 写入剧本格式：第一行加"发送人: "，多行消息的后续行直接输出
        content = msg['content']
        lines = [l.strip() for l in content.split('\n') if l.strip()]
        for i, line_stripped in enumerate(lines):
            if i == 0:
                output_lines.append(f"{msg['sender']}: {line_stripped}\n")
            else:
                output_lines.append(f"{line_stripped}\n")
        
    # 执行原地重写
    with open(txt_path, 'w', encoding='utf-8') as out_f:
        out_f.writelines(output_lines)
        
    print(f"✓ 已完成就地清洗与翻译！")
    print(f"✓ 过滤掉 {filtered_count} 条噪音消息，保留 {len(clean_messages)} 条有价值记录 ({len(clean_messages)/total_raw*100:.1f}%)")
    print(f"💾 原地写回覆盖成功: {txt_path}")


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description="WeFlow 微信记录处理管道 (就地修改版)")
    parser.add_argument(
        "target",
        nargs="?",
        default=str(WORKBENCH_ROOT / "素材箱/_待处理/微信记录"),
        help="目标文件夹或文件路径",
    )
    parser.add_argument("--strict", "-s", action="store_true", help="对私聊启用激进的内容/语义过滤")
    parser.add_argument("--layer1", "-l", action="store_true", help="仅执行第一层基础过滤（结构性清洗，保留 casual 对话，不执行激进关键词过滤）")
    args = parser.parse_args()
    
    if not os.path.exists(args.target):
        print(f"❌ 目标路径不存在: {args.target}")
        sys.exit(1)
        
    process_weflow_in_place(
        args.target,
        strict=args.strict,
        layer1=args.layer1,
    )
