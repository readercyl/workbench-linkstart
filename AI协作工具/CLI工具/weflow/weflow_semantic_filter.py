#!/usr/bin/env python3
# /// script
# dependencies = []
# ///
"""
WeFlow 微信记录第二层语义过滤 (就地覆盖版)
使用 DeepSeek v4-flash（非思考模式）对第一层过滤后的群聊 TXT 文件做语义判断，
删除废话/闲聊/链接/自我介绍，保留有信息价值的内容。
直接就地覆盖写入原文件，不产生多余文件。

用法：
  python3 weflow_semantic_filter.py <文件路径>          # 处理单个文件
  python3 weflow_semantic_filter.py <目录路径>          # 批量处理目录下所有群聊 .txt
"""

import re, os, sys, json, time
import urllib.request, urllib.error
from typing import List, Tuple, Optional

# ============================================================
# 配置
# ============================================================
API_KEY    = os.getenv("DEEPSEEK_API_KEY")
API_URL    = "https://api.deepseek.com/chat/completions"
MODEL      = "deepseek-v4-flash"
DEFAULT_CHUNK_SIZE     = 300   # 默认每批发送的消息条数（合适的消息数目）
SINGLE_BATCH_THRESHOLD = 500   # 如果消息总数小于或等于此值，则进行单批次发送，避免截断上下文关系

# ============================================================
# 正则
# ============================================================
DATE_HEADER_RE = re.compile(r'^# \d{4}-\d{2}-\d{2}\s*$')
# 消息首行：<发送者（不含冒号，最多40字）>: <内容>
MSG_START_RE   = re.compile(r'^([^:\n]{1,40}): (.+)')
LINK_RE        = re.compile(r'https?://')
AT_RE          = re.compile(r'@\S+')

# ============================================================
# System Prompt
# ============================================================
SYSTEM_PROMPT = """你是一个微信群聊记录的语义过滤助手。

你收到的每条消息格式为：
[编号] 发送者: 内容

你的任务是判断哪些消息有信息价值，返回应该【保留】的编号列表。

## 保留标准（满足任一即保留）
1. AI工具讨论：Coze/扣子、Claude、DeepSeek、Cursor、MidJourney、ComfyUI、Suno 等工具的使用方法、配置、踩坑、技巧
2. 商业/变现讨论：AI变现、副业、项目进展、营收数据、商业模式、定价策略
3. 技术/方法论：API配置、工作流搭建、自动化、代码、SOP、可复用方法、策略
4. 内容创作：小红书/公众号/视频号运营、爆款选题、文案技巧、封面设计
5. 实质性问答：有具体信息量的提问 and 解答（即使简短）
6. 洞察与分析：行业趋势、信息差、商机分析、经验总结
7. 有价值的推荐：工具、课程、模板推荐（不含链接本身）
8. 教练点评与指导：所有教练对学员打卡日志、作业的点评、解析和指导建议（即使包含鼓励性客套话，也必须整条保留，因为其中包含极具价值的技术/业务微调建议、工具推荐与实操指引！）
9. 深度话题讨论：对于特定事物、电影/文化/书籍、科技、金融投资、行业动态等的深入讨论与高信息密度的交流（不论是否与 AI 相关，只要有实质信息量、有独特观点或长文探讨，全部保留！）

## 删除标准（满足任一即删除）
1. 废话/附和：哈哈/好的/是的/谢谢/加油/棒棒/厉害/学到了/收到/明白/了解/太牛了/好棒 等无新增信息的回应
2. 闲聊/寒暄：打招呼、问候、调侃、天气、饮食等与主题无关的内容
3. 自我介绍：介绍自己的背景、位置、技能、项目、目标等（即使没有固定模板格式）
4. 纯运营与活动事务：打卡（如打卡规则、是否需要打卡、如何打卡、写日志等）、问卷填写、活动预告、接龙、拉群等纯活动日常事务性讨论
5. 无法理解的孤立片段：脱离上下文完全无法理解的残句

## 重要规则
- 自我介绍无条件删除（最高优先级）：只要是自我介绍（无论是否符合典型模板如【我的昵称】、【坐标】、【航海目标】、【我能提供】、【我寻求的资源】等，或以自由文本介绍个人背景、擅长、资源和对接资源目的的内容），【无论是否包含 AI工具、变现、多维表格等保留关键词，都必须无条件删除】！
- 航海活动事务无条件删除（最高优先级）：所有关于“打卡”（如何打卡、打卡要求、打卡界面、满贯打卡等）、“写日志/手册/打卡链接”等航海活动本身的日常事务性信息，不论谁发的，全部删除！
- 教练作业点评无条件保留（最高优先级）：只要是教练对学员日志/作业的指导点评内容，必须整条保留！绝对不能因为开头或结尾包含“你好/真棒/优秀/继续加油/感谢”等客套话而被误杀！
- 不管是谁发的，废话就删，有价值就留（不因发送人特殊而无条件保留）
- 消息长短不是判断标准，有价值的短消息也保留
- 不确定时倾向于保留

## 输出
只返回 JSON 数组，包含所有应该保留的消息编号，不要任何解释。
例如：[1, 3, 4, 7, 9]"""


# ============================================================
# API 调用
# ============================================================
def call_api(text: str, max_retries: int = 3) -> str:
    """调用 DeepSeek API（非思考模式），返回模型的文本响应"""
    if not API_KEY:
        raise RuntimeError("未配置 DEEPSEEK_API_KEY。请只在本机环境变量中设置，禁止写入仓库。")
    payload = {
        "model": MODEL,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user",   "content": text},
        ],
        "temperature": 0,
        "thinking": {"type": "disabled"},  # 关闭思考模式
    }
    data = json.dumps(payload, ensure_ascii=False).encode('utf-8')
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}",
    }

    for attempt in range(max_retries):
        try:
            req = urllib.request.Request(API_URL, data=data, headers=headers)
            with urllib.request.urlopen(req, timeout=120) as resp:
                result = json.loads(resp.read().decode('utf-8'))
                return result["choices"][0]["message"]["content"].strip()
        except urllib.error.HTTPError as e:
            body = e.read().decode('utf-8', errors='replace')
            if e.code == 429:
                wait = 2 ** (attempt + 1)
                print(f"    [限流] 等待 {wait}s...", flush=True)
                time.sleep(wait)
                continue
            print(f"    [HTTP {e.code}] {body[:200]}")
            if attempt < max_retries - 1:
                time.sleep(2)
                continue
            raise
        except Exception as e:
            if attempt < max_retries - 1:
                wait = 2 ** attempt
                print(f"    [错误] {e}，重试 {attempt+1}/{max_retries}...", flush=True)
                time.sleep(wait)
                continue
            raise
    return "[]"


def parse_keep_list(response: str) -> Optional[List[int]]:
    """从 LLM 响应中提取保留的编号列表。返回 None 表示解析失败（降级保留全部）"""
    try:
        m = re.search(r'\[[\d\s,]*\]', response)
        if m:
            return [int(x) for x in json.loads(m.group())]
        return [int(x) for x in json.loads(response)]
    except Exception:
        print(f"    [警告] 无法解析 LLM 响应: {response[:100]}", flush=True)
        return None


# ============================================================
# 文件解析
# ============================================================
class Msg:
    """代表一条完整消息（可能跨多行）"""
    __slots__ = ('sender', 'full_text', 'line_indices', 'deleted')

    def __init__(self, sender: str, full_text: str, line_indices: List[int]):
        self.sender       = sender
        self.full_text    = full_text          # 所有行拼接后的完整文本
        self.line_indices = line_indices       # 在原始文件中的行索引
        self.deleted      = False              # 是否被标记删除


def parse_file(lines: List[str]) -> Tuple[List[Tuple[int, str]], List[Msg]]:
    """
    解析文件，返回：
    - date_headers: [(line_idx, date_str), ...]
    - messages:     [Msg, ...]（按文件顺序）
    """
    date_headers: List[Tuple[int, str]] = []
    messages:     List[Msg]             = []
    current_msg:  Optional[Msg]         = None

    for i, line in enumerate(lines):
        stripped = line.rstrip('\r\n')

        if DATE_HEADER_RE.match(stripped):
            if current_msg:
                messages.append(current_msg)
                current_msg = None
            date_headers.append((i, stripped))
            continue

        m = MSG_START_RE.match(stripped)
        if m:
            if current_msg:
                messages.append(current_msg)
            current_msg = Msg(
                sender      = m.group(1).strip(),
                full_text   = stripped,
                line_indices= [i],
            )
        elif current_msg:
            # 续行（包括空行，只要在当前消息段落内都保留，保证大段完整信息不被截断）
            current_msg.full_text += '\n' + stripped
            current_msg.line_indices.append(i)

    if current_msg:
        messages.append(current_msg)

    return date_headers, messages


# ============================================================
# 过滤逻辑
# ============================================================
def pre_filter(messages: List[Msg]) -> int:
    """
    规则预过滤（不调用 LLM）：
    - 含链接 → 删除
    - 3个以上 @ → 删除
    - 结构化自我介绍模板消息 → 删除
    返回删除条数。
    """
    deleted = 0
    
    # 典型自我介绍特征词（括号包裹）
    INTRO_KEYWORDS = [
        '【微信昵称】', '【昵称】', '【我的昵称】', '【姓名】', '【名称】', '【星球昵称】',
        '【所在地区】', '【地区】', '【坐标】', '【城市】', '【常驻】', '【位置】', '【所在城市】', '【我的位置】',
        '【自我介绍】', '【介绍】', '【个人介绍】', '【一句话介绍自己】', '【过往经历】', '【我的经历】', '【职业】', '【所属行业】',
        '【我能提供】', '【我可以提供】', '【我可以为其他船员提供什么帮助】', '【我提供】', '【提供资源】', '【可提供资源】', '【我能帮你】', '【我可以为大家提供什么帮助】',
        '【我寻求的资源】', '【需求】', '•【我寻求的资源】', '【我寻求的资源/链接】', '【我需要的】', '【我需要什么】', '【我需要的资源】', '【我想链接的资源】',
        '【航海目标】', '【我的航海目标】', '【目标】', '【本次航海目标】',
        '【核心优势】', '【擅长领域】', '【期待线下】', '【最有成就感的三件事】'
    ]

    for msg in messages:
        # 1. 链接过滤
        if LINK_RE.search(msg.full_text):
            # 特例：如果是教练点评，或包含点评/作业/日志词汇，或者包含高价值内容推荐链接（如飞书文档、B站视频、YouTube、小宇宙、Github、公众号、生财精华帖等），不进行程序一键过滤，而是交给 LLM 决定，防止误杀干货
            valuable_domains = [
                'feishu.cn', 'bilibili.com', 'b23.tv', 'youtube.com', 'youtu.be',
                'xiaoyuzhoufm.com', 'winrobot360.com', 'github.com', 'mp.weixin.qq.com',
                'scys.com/articleDetail', 'scys.com/activity/task'
            ]
            is_valuable_asset = (
                any(domain in msg.full_text for domain in valuable_domains) or
                any(kw in msg.full_text for kw in ['点评', '作业', '日志', '航海手册']) or
                any(kw in msg.sender for kw in ['教练', '领队', '志愿者', 'Lisa', 'ing', '飞掌柜', '米斗', '相柳', '大刘'])
            )
            if not is_valuable_asset:
                msg.deleted = True
                deleted += 1
                continue
            
        # 2. @ 过滤
        if len(AT_RE.findall(msg.full_text)) >= 3:
            msg.deleted = True
            deleted += 1
            continue

        # 3. 结构化自我介绍过滤
        # 如果包含 2 个或以上典型的自我介绍括号，则判定为结构化自我介绍，直接程序过滤
        intro_hit_count = sum(1 for kw in INTRO_KEYWORDS if kw in msg.full_text)
        if intro_hit_count >= 2:
            msg.deleted = True
            deleted += 1
            continue

        # 4. 纯活动事务性打卡/写日志过滤
        # 清理日常碎碎念提醒、提问打卡入口等纯事务性消息，但保留长篇有价值的实操心得/反馈
        if any(keyword in msg.full_text for keyword in ['打卡', '写日志', '日志打卡', '连打']):
            # 特征A：消息很短（小于 45 个字），多数为简单提问或日常打卡监督提醒，直接删除
            if len(msg.full_text) < 45:
                msg.deleted = True
                deleted += 1
                continue
            # 特征B：包含常见的打卡日常客服/规则词汇，且不包含高价值技术词汇（如 deepseek, AI, coze, claude 等）
            admin_words = ['入口', '界面', '服务号', '公众号', '官网', '规则', '里程碑', '航线图', '按钮', '提醒', '忘记', '补卡', '督促', '保证金', '监督', '打卡链接']
            tech_words = ['deepseek', 'ds', 'ai', 'coze', 'claude', 'cursor', '工作流', '多维表格', '变现', '商业', '落地', '爆款', '提示词', '模型', 'gpt', '技术']
            
            has_admin = any(aw in msg.full_text for aw in admin_words)
            has_tech = any(tw in msg.full_text.lower() for tw in tech_words)
            
            if has_admin and not has_tech:
                msg.deleted = True
                deleted += 1
                continue

    return deleted



def llm_filter(messages: List[Msg]) -> int:
    """
    LLM 语义过滤。动态选择单批次或合适数目分批发送。
    返回被 LLM 删除的条数。
    """
    active = [m for m in messages if not m.deleted]
    if not active:
        return 0

    active_count = len(active)
    if active_count <= SINGLE_BATCH_THRESHOLD:
        chunk_size = active_count
        print(f"  [批次选择] 活跃消息数 {active_count} <= 阈值 {SINGLE_BATCH_THRESHOLD}，启用【单批次】发送，避免截断上下文", flush=True)
    else:
        chunk_size = DEFAULT_CHUNK_SIZE
        print(f"  [批次选择] 活跃消息数 {active_count} > 阈值 {SINGLE_BATCH_THRESHOLD}，启用【多批次】发送（每批最多 {chunk_size} 条）", flush=True)

    deleted = 0
    total_chunks = (active_count + chunk_size - 1) // chunk_size

    for chunk_idx in range(total_chunks):
        chunk = active[chunk_idx * chunk_size : (chunk_idx + 1) * chunk_size]

        # 构建带编号的文本。完整保留多行消息（不截断），并对续行做缩进，防格式混淆
        lines_for_llm = []
        for local_no, msg in enumerate(chunk, 1):
            lines = msg.full_text.split('\n')
            formatted_lines = []
            for j, line in enumerate(lines):
                if j == 0:
                    formatted_lines.append(f"[{local_no}] {line}")
                else:
                    formatted_lines.append(f"    {line}")
            lines_for_llm.append('\n'.join(formatted_lines))

        payload_text = '\n'.join(lines_for_llm)

        print(f"  块 {chunk_idx+1}/{total_chunks} ({len(chunk)} 条)...",
              end=" ", flush=True)

        response  = call_api(payload_text)
        keep_nos  = parse_keep_list(response)

        if keep_nos is None:
            # 降级：保留全部
            print("[解析失败，降级保留全部]", flush=True)
            continue

        keep_set     = set(keep_nos)
        chunk_deleted = 0
        for local_no, msg in enumerate(chunk, 1):
            if local_no not in keep_set:
                msg.deleted = True
                chunk_deleted += 1

        deleted += chunk_deleted
        kept = len(chunk) - chunk_deleted
        print(f"保留 {kept}/{len(chunk)}", flush=True)

        # 简单限流：连续块之间等 0.3s
        if chunk_idx < total_chunks - 1:
            time.sleep(0.3)

    return deleted


# ============================================================
# 写回文件
# ============================================================
def write_output(filepath: str, lines: List[str],
                 date_headers: List[Tuple[int, str]], messages: List[Msg]):
    """
    重写文件：只保留未删除的消息，以及仍有内容的日期标题。
    天与天之间保留一个空行。
    """
    # 计算哪些日期标题有至少一条保留的消息
    # 通过行索引顺序推断每条消息属于哪个日期
    all_events: List[Tuple[int, str, object]] = []
    for line_idx, date_str in date_headers:
        all_events.append((line_idx, 'date', line_idx))
    for msg in messages:
        all_events.append((msg.line_indices[0], 'msg', msg))
    all_events.sort(key=lambda x: x[0])

    date_has_content = {line_idx: False for line_idx, _ in date_headers}
    current_date_line_idx = None
    for _, etype, ref in all_events:
        if etype == 'date':
            current_date_line_idx = ref
        elif etype == 'msg' and not ref.deleted:
            if current_date_line_idx is not None:
                date_has_content[current_date_line_idx] = True

    # 收集保留的行索引集合
    keep_line_indices: set = set()
    for line_idx, _ in date_headers:
        if date_has_content[line_idx]:
            keep_line_indices.add(line_idx)
    for msg in messages:
        if not msg.deleted:
            keep_line_indices.update(msg.line_indices)

    # 按顺序生成输出
    output_lines = []
    first_line   = True

    for i, line in enumerate(lines):
        if i not in keep_line_indices:
            continue
        stripped = line.rstrip('\r\n')
        if DATE_HEADER_RE.match(stripped):
            if not first_line and output_lines and output_lines[-1].strip():
                output_lines.append('\n')    # 日期标题前插空行（天与天之间）
            output_lines.append(stripped + '\n')
            first_line = False
        else:
            output_lines.append(stripped + '\n')
            first_line = False

    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(output_lines)


# ============================================================
# 主流程
# ============================================================
def process_file(filepath: str):
    """处理单个文件"""
    print(f"\n📄 {os.path.basename(filepath)}", flush=True)

    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    date_headers, messages = parse_file(lines)
    total = len(messages)

    if total == 0:
        print("  ⚠️ 没有解析到任何消息，跳过（可能已是空文件或格式不符）")
        return

    print(f"  共 {total} 条消息")

    # 第一步：规则预过滤
    pre_del = pre_filter(messages)
    remaining = total - pre_del
    print(f"  规则预过滤删除: {pre_del} 条（含链接/批量@）→ 剩余 {remaining} 条")

    # 第二步：LLM 语义过滤
    llm_del = llm_filter(messages)

    kept = total - pre_del - llm_del
    print(f"  最终保留: {kept}/{total} 条 ({kept/total*100:.1f}%)", flush=True)

    # 写回文件
    write_output(filepath, lines, date_headers, messages)
    print(f"  💾 已写回覆盖: {filepath}", flush=True)


def main():
    if len(sys.argv) < 2:
        print("用法:")
        print("  python3 weflow_semantic_filter.py <文件路径>    # 处理单个文件")
        print("  python3 weflow_semantic_filter.py <目录路径>    # 批量处理所有群聊 .txt")
        sys.exit(1)

    target = sys.argv[1]

    if os.path.isfile(target):
        files = [os.path.abspath(target)]
    elif os.path.isdir(target):
        d = os.path.abspath(target)
        files = sorted([
            os.path.join(d, f) for f in os.listdir(d)
            if f.endswith('.txt')
            and not f.endswith('.bak')
            and '副本' not in f
            and f.startswith('群聊_')
        ])
    else:
        print(f"❌ 路径不存在: {target}")
        sys.exit(1)

    if not files:
        print("❌ 没有找到符合条件的 .txt 文件")
        sys.exit(1)

    print(f"🔍 共找到 {len(files)} 个文件，开始第二层语义过滤...")
    print(f"   模型: {MODEL}  |  思考模式: 关闭  |  默认分批大小: {DEFAULT_CHUNK_SIZE}  |  单批次合并阈值: {SINGLE_BATCH_THRESHOLD}")

    total_files = len(files)
    for i, filepath in enumerate(files, 1):
        print(f"\n[{i}/{total_files}]", end="")
        process_file(filepath)

    print("\n\n✅ 全部文件处理完成")


if __name__ == '__main__':
    main()
