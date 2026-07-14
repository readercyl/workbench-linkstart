---
name: wx-cli-usage
description: 微信本地数据 CLI 使用说明 — 聊天记录查询、搜索、导出
tool: @jackwener/wx-cli
version: 0.3.0
install: npm install -g @jackwener/wx-cli
author: jackwener（xhs-cli 同作者）
updated: 2026-06-07
---

# 微信本地数据 CLI · 使用说明

> 定位：查询本地微信数据——聊天记录、联系人、朋友圈、公众号文章
> 作者：jackwener（xhs-cli、bilibili-cli 同作者）
> 底层：读取本地微信数据库 + 解密密钥

## 安装

```bash
npm install -g @jackwener/wx-cli
wx init                # 检测数据目录并扫描加密密钥
```

## 可用命令

### 聊天记录
| 命令 | 用途 |
|------|------|
| `sessions` | 列出最近会话 |
| `history <id>` | 查看聊天记录 |
| `search "关键词"` | 搜索消息 |
| `unread` | 有未读消息的会话 |
| `new-messages` | 自上次检查以来的新消息 |

### 联系人
| 命令 | 用途 |
|------|------|
| `contacts` | 查看联系人列表 |
| `members <id>` | 查看群成员 |

### 导出与分析
| 命令 | 用途 |
|------|------|
| `export <id>` | 导出聊天记录到文件 |
| `stats` | 聊天统计分析 |
| `attachments <id>` | 列出会话图片附件 |
| `extract <id>` | 解密导出单个附件 |

### 朋友圈
| 命令 | 用途 |
|------|------|
| `sns-feed` | 朋友圈时间线 |
| `sns-search "关键词"` | 朋友圈全文搜索 |
| `sns-notifications` | 朋友圈互动通知 |

### 公众号
| 命令 | 用途 |
|------|------|
| `biz-articles` | 公众号文章推送（本地缓存） |

### 收藏与后台
| 命令 | 用途 |
|------|------|
| `favorites` | 微信收藏内容 |
| `daemon` | 管理 wx-daemon 后台进程 |

## 与 WeFlow 的分工

| 场景 | wx-cli | WeFlow |
|------|:---:|:---:|
| 实时查询聊天记录 | ✅ | — |
| 朋友圈搜索 | ✅ | — |
| 公众号文章缓存 | ✅ | — |
| 批量聊天记录清洗 | — | ✅ |
| 语义去噪 | — | ✅ |
| AI 调用 | CLI 直接查 | Skill 管道处理 |
