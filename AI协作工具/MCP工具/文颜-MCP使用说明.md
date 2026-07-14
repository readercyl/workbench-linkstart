---
name: wenyan-mcp-usage
description: 文颜 MCP 使用说明 — Markdown 排版并发布到公众号草稿箱
tool: caol64/wenyan-mcp
version: 2.0.3
install: npm install -g @wenyan-md/mcp
star: 1233
updated: 2026-05-26
---

# 文颜 MCP · 使用说明

> GitHub: [caol64/wenyan-mcp](https://github.com/caol64/wenyan-mcp) | 1,233 stars
> 定位: Markdown 排版 → 微信公众号草稿箱
> 协议: MCP，AI 可直接调用

## 安装

```bash
npm install -g @wenyan-md/mcp
```

## MCP 配置

`.mcp.json`：

```json
{
  "mcpServers": {
    "wenyan-公众号名称": {
      "command": "wenyan-mcp",
      "env": {
        "WECHAT_APP_ID": "wx...",
        "WECHAT_APP_SECRET": "..."
      }
    }
  }
}
```

多账号配多个 server，env 不同即可。

## 前置条件

- Node.js ≥ v20.10.0
- 公众号 AppID + AppSecret（开发 → 基本配置）
- **IP 白名单**已配置（开发 → 基本配置 → IP 白名单，填入当前网络出口 IP）

## 可用工具

| 工具 | 用途 | 参数 |
|------|------|------|
| `list_themes` | 列出所有可用主题 | 无 |
| `publish_article` | 排版 Markdown 并推送到草稿箱 | file/content/content_url/theme_id |
| `register_theme` | 注册自定义 CSS 主题 | name, path |
| `remove_theme` | 删除自定义主题 | name |

## 文章格式要求

**必须**使用 YAML frontmatter，`title` 必填：

```yaml
---
title: 文章标题（必填）
cover: /path/to/cover.jpg  # 封面图，可选
author: 作者名，可选
---
```

正文为 Markdown，支持 `**加粗**`、列表、段落等标准语法。

**注意**：不要用 `# 标题` 作为文章标题，标题必须写在 frontmatter 的 `title` 字段里。

## 内置 8 大主题

| 主题 | 风格 | 适用 |
|------|------|------|
| Default | 黑白灰，简洁经典 | 通用长文 |
| OrangeHeart | 暖橙，活力优雅 | 情感、生活 |
| Rainbow | 多彩点缀，生动克制 | 创意、年轻化 |
| Lapis | 清凉蓝，极简清新 | 科技 |
| Pie | 深色调，现代时尚 | 专业媒体 |
| Maize | 柔和玉米黄，明快 | 生活、温暖 |
| Purple | 薰衣紫，简约 | 文艺、女性 |
| Phycat | 薄荷绿，结构清晰 | 清新、技术 |

## 发布流程

1. 写 Markdown 文章，添加 frontmatter（含 `title`）
2. AI 调 `list_themes` 选主题（如 Default）
3. AI 调 `publish_article`，传入 `file` 路径和 `theme_id`
4. 文章推送到草稿箱，返回 media_id
5. 人工在公众号后台预览确认后手动发布

**只推草稿，不自动发布。** 符合微信内容安全要求。

## 已知坑

- v2.0.3 本地模式下主题列表可能为空，需在发布前置调一次 `register_theme` 注册 Default 主题
- IP 必须是公众号后台白名单中的地址
- 图片支持本地绝对路径和 HTTP URL

## 密钥存储

只在本机环境变量或未提交的 `.env` 中保存公众号 AppID / AppSecret，不要写入文章目录或提交到 Git。

## 文章存放

待发布文章建议放在：`05-项目运营/{项目名}/待发布/`
