---
name: chrome-devtools-mcp-usage
description: Chrome DevTools MCP 使用说明 — 浏览器自动化，截图/点击/填表/JS执行
tool: chrome-devtools-mcp
source: Claude Code 内置
updated: 2026-06-07
---

# Chrome DevTools MCP · 使用说明

> 定位：浏览器自动化——操控真实浏览器完成交互操作
> 来源：Claude Code 内置（v2.1.x）
> 谨慎：部分站点对自动化操作检测严格，存在封号风险

## 可用工具

### 页面导航
| 工具 | 用途 |
|------|------|
| `navigate_page` | 导航到 URL / 前进 / 后退 / 刷新 |
| `new_page` | 新建标签页 |
| `close_page` | 关闭标签页 |
| `list_pages` | 列出所有打开的页面 |
| `select_page` | 切换到指定页面 |

### 页面交互
| 工具 | 用途 |
|------|------|
| `take_snapshot` | 文本快照（基于 a11y tree，列出页面元素+uid） |
| `take_screenshot` | 页面/元素截图（PNG/JPEG/WebP） |
| `click` | 点击元素（通过 uid） |
| `hover` | 悬停在元素上 |
| `fill` | 输入文本到 input/textarea/select |
| `fill_form` | 批量填写表单 |
| `press_key` | 按键/组合键 |
| `drag` | 拖拽元素 |
| `upload_file` | 上传文件 |
| `type_text` | 逐字输入文本 |

### 调试与监控
| 工具 | 用途 |
|------|------|
| `evaluate_script` | 执行 JS 并返回 JSON 结果 |
| `get_console_message` | 获取控制台消息详情 |
| `list_console_messages` | 列出所有控制台消息 |
| `get_network_request` | 获取网络请求详情 |
| `list_network_requests` | 列出所有网络请求 |
| `wait_for` | 等待指定文本出现 |
| `handle_dialog` | 处理浏览器对话框 |

### 模拟与仿真
| 工具 | 用途 |
|------|------|
| `emulate` | 模拟网络/CPU/地理/UA/颜色主题/视口 |
| `resize_page` | 调整页面窗口尺寸 |

### 性能与分析
| 工具 | 用途 |
|------|------|
| `performance_start_trace` | 开始性能追踪 |
| `performance_stop_trace` | 停止性能追踪 |
| `performance_analyze_insight` | 分析性能洞察详情 |
| `lighthouse_audit` | Lighthouse 审计（SEO/可访问性/最佳实践） |
| `take_heapsnapshot` | 堆快照（内存分析） |

## 使用场景

- **动态渲染页面**：小红书、微信公众号等反爬站点，需真实浏览器环境
- **登录后操作**：日常浏览器天然携带登录态
- **表单交互**：填写、提交、验证
- **视觉验证**：截图确认页面状态
- **性能调试**：LCP、INP、CLS 等 Core Web Vitals

## 已知限制

- **浏览器冲突**：用户正在使用的 Chrome 如已开启，需 `--isolated` 模式
- **反爬风险**：部分站点（如小红书）频繁自动化操作可能触发验证/封号
- **UserDataDir**：同一 Chrome profile 不能两个进程同时使用
