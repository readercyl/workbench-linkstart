---
name: getnote-mcp-usage
description: Get笔记 MCP 使用说明 — 27 个工具，笔记管理、知识库、博主订阅、直播
tool: getnote-mcp
install: ~/工具库/全局技能包/getnote/bin/launch.sh
updated: 2026-06-07
---

# Get笔记 MCP · 使用说明

> 定位：个人笔记管理 + 知识库 + 博主订阅 + 直播转写
> 协议：MCP stdio，Claude Code 直接调用
> 配置：`~/.claude/.mcp.json`

## 安装

已安装在 `~/工具库/全局技能包/getnote/`，通过 launch.sh 启动。

## 可用工具（27 个）

### 笔记管理
| 工具 | 用途 |
|------|------|
| `list_notes` | 笔记列表（每次 20 条，since_id 翻页） |
| `get_note` | 获取笔记详情（正文、标签、附件、音频转录） |
| `save_note` | 新建笔记（plain_text / link / img_text） |
| `update_note` | 更新笔记标题/内容/标签（仅 plain_text） |
| `delete_note` | 删除笔记（移入回收站） |
| `share_note` | 生成公开分享链接 |
| `add_note_tags` | 给笔记添加标签 |
| `delete_note_tag` | 删除笔记标签 |
| `get_note_task_progress` | 查询链接笔记处理进度 |

### 知识库
| 工具 | 用途 |
|------|------|
| `list_topics` | 知识库列表（每页 20 条） |
| `create_topic` | 创建新知识库（每天上限 50） |
| `list_topic_notes` | 知识库内笔记列表 |
| `batch_add_notes_to_topic` | 批量添加笔记到知识库（每批 ≤20） |
| `remove_note_from_topic` | 从知识库移除笔记 |

### 博主订阅
| 工具 | 用途 |
|------|------|
| `list_topic_bloggers` | 知识库订阅的博主列表 |
| `list_topic_blogger_contents` | 博主发布的内容列表 |
| `get_blogger_content_detail` | 博主内容详情（含完整原文） |

### 直播
| 工具 | 用途 |
|------|------|
| `follow_topic_live` | 订阅直播到知识库（目前仅支持得到 App） |
| `list_topic_lives` | 知识库已完成直播列表 |
| `get_live_detail` | 直播详情（含 AI 摘要+完整转写） |

### 搜索与发现
| 工具 | 用途 |
|------|------|
| `recall` | 全局语义搜索（在所有笔记中搜） |
| `recall_knowledge` | 知识库语义搜索（限定知识库范围） |
| `list_subscribe_topics` | 已订阅的知识库列表 |

### 上传与配额
| 工具 | 用途 |
|------|------|
| `upload_image` | 上传图片到 OSS |
| `get_upload_token` | 获取图片上传凭证 |
| `get_upload_config` | 查询上传配置（文件类型、大小限制） |
| `get_quota` | 查询 API 配额（read/write 日/月剩余） |

## 核心使用场景

**视频日记导出**：配置本机环境变量 `GETNOTE_TOPIC_ID` 后，每日启动自检会检查对应知识库的最新笔记，并导出为 Markdown 到 `素材箱/视频日记/`。

**语义搜索**：`recall` 全局搜 + `recall_knowledge` 限定知识库搜。top_k 默认 3，最大 10。

**笔记创建**：`save_note` 支持三种类型——plain_text（默认）、link（链接笔记）、img_text（图片笔记）。链接笔记中分享链接同步返回 ID，普通链接异步需轮询。

## 已配置的知识库

| 知识库 | topic_id |
|--------|----------|
| 用户配置的视频日记知识库 | 本机环境变量 `GETNOTE_TOPIC_ID` |
| （其他按需查询 list_topics） | |
