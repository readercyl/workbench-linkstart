---
name: crawl-mcp-usage
description: Crawl MCP 使用说明 — 网页抓取，微信公众号文章智能提取
tool: crawl-mcp
source: Claude Code 内置
updated: 2026-06-07
---

# Crawl MCP · 使用说明

> 定位：网页抓取——微信公众号文章抓取 + 服务器状态监控
> 来源：Claude Code 内置（v2.1.x）

## 可用工具

| 工具 | 用途 | 参数 |
|------|------|------|
| `crawl_wechat_article` | 抓取微信公众号文章 | url（必填）, clean_content, save_images, output_format, strategy, timeout |
| `crawl_server_status` | 获取抓取服务器状态统计 | 无 |

## 公众号文章抓取

```
url: 微信文章完整 URL（mp.weixin.qq.com）
clean_content: 是否清理广告/无关内容（默认 true）
save_images: 是否下载图片（默认 true）
output_format: markdown | json（默认 markdown）
strategy: basic | conservative | fast（默认 basic）
timeout: 超时毫秒（5000-120000，默认 30000）
```

**注意**：该工具返回抓取指令，由 Agent 调用 chrome-devtools-mcp 执行实际抓取。不是自己直接下载页面。

## 使用场景

- **微信公众号文章**：唯一官方支持的抓取目标
- **内容提取**：自动清理广告、提取正文、保存图片
- **Markdown 导出**：适合后续知识编译

## 与其他工具的配合

```
crawl_wechat_article → 返回抓取指令 → chrome-devtools-mcp 执行 → Markdown 输出 → 知识编译 Skill
```
