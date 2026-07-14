---
name: lark-cli-usage
description: 飞书 CLI 使用说明 — IM/文档/日历/Base/邮件/OKR 等全套操作
tool: @larksuite/cli (npm)
version: 1.0.32
install: npm install -g @larksuite/cli
updated: 2026-06-07
---

# 飞书 CLI · 使用说明

> 定位：飞书全套操作命令行工具——IM、文档、日历、Base、邮件、OKR、任务、会议……
> 协议：CLI，AI 通过 Bash 调用（配合 lark-* Skill 使用）
> 路径：`~/.nvm/.../bin/lark-cli`

## 核心原则

**永远通过 lark-* Skill 调用，不直接手写命令。** Skill 内封装了正确的参数格式和流程。这里只列概要供快速参考。

## 可用模块

| Skill | 命令前缀 | 核心能力 |
|-------|---------|---------|
| lark-im | `lark-cli im` | 收发消息、群聊管理、文件上传下载 |
| lark-doc | `lark-cli docs` | 云文档/Docx/Wiki 读写编辑 |
| lark-calendar | `lark-cli calendar` | 日程管理、会议室预定 |
| lark-base | `lark-cli base` | 多维表格 CRUD、字段/视图管理 |
| lark-mail | `lark-cli mail` | 邮件收发、草稿管理 |
| lark-task | `lark-cli task` | 任务/清单管理 |
| lark-drive | `lark-cli drive` | 云空间文件管理 |
| lark-contact | `lark-cli contact` | 通讯录/用户查询 |
| lark-minutes | `lark-cli minutes` | 妙记（会议录制转写） |
| lark-vc | `lark-cli vc` | 视频会议查询 |
| lark-okr | `lark-cli okr` | OKR 管理 |
| lark-slides | `lark-cli slides` | 幻灯片创建编辑 |
| lark-wiki | `lark-cli wiki` | 知识库管理 |
| lark-approval | `lark-cli approval` | 审批管理 |
| lark-attendance | `lark-cli attendance` | 考勤打卡 |
| lark-whiteboard | `lark-cli whiteboard` | 画板操作 |
| lark-markdown | `lark-cli markdown` | Markdown 文件操作 |

## 高频快捷操作

```bash
# 日程概览
lark-cli calendar +agenda

# 搜索聊天记录
lark-cli im search --keyword "xxx"

# 读取飞书文档
lark-cli docs +fetch --token <doc_token>

# 搜索多维表格
lark-cli base search --name "xxx"
```

## 认证

```bash
lark-cli auth login
```
