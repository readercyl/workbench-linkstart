# 春风 API 调用指南

> ⚠️ **已停用**（2026-05-20）：gpt-5.5 图像生成不稳定（频繁返回文字/403），gpt-image-2 端点间歇超时且价格是 apimart 的 20 倍。主力已切换至 apimart，本指南仅保留备查。
>
> 中转站：mentalout.top  
> 整理日期：2026-05-06

---

## 基本信息

| 项目 | 值 |
|------|-----|
| API Key | 从本机环境变量 `CHUNFENG_API_KEY` 读取 |
| 文字 / 图像（chat） | `https://chunfeng.mentalout.top/v1/chat/completions` |
| 纯图像（备用） | `https://chunfeng.mentalout.top/v1/images/generations` |
| 查询可用模型 | `https://chunfeng.mentalout.top/v1/models` |
| 图像网页版 | `https://image.mentalout.top`（仅手动，不支持 API） |

> 安全规则：真实 Key 只保存在本机环境变量或未提交的 `.env` 中，禁止写入代码、文档和 Git 历史。

---

## 模型选择

| 用途 | 模型 | 端点 | 单张价格 | 说明 |
|------|------|------|---------|------|
| 文字对话 | `gpt-5.5` | chat/completions | — | 默认 |
| **图像生成（永远首选）** | `gpt-5.5` | chat/completions | **~¥0.005** | ✅ 质量优秀，便宜24倍 |
| 图像生成（禁止日常用） | `gpt-image-2` | images/generations | ~¥0.12 | ❌ 贵24倍，仅极端情况 |

> 💰 **价格说明**：gpt-5.5 每张约 ¥0.005，gpt-image-2 约 ¥0.12，相差 **24倍**。所有图像生成任务一律用 gpt-5.5。

### 降级策略（重要）

**同一张图用 gpt-5.5 失败 2 次 → 切换 gpt-image-2**

失败判定（满足其一即算失败）：
- 返回空响应 / JSONDecodeError
- 超时（timeout=180）
- 返回 SVG 代码而非图片（调整 prompt 后仍然如此）

```
第1次：gpt-5.5，正常 prompt
  ↓ 失败
第2次：gpt-5.5，简化 prompt 重试（去掉复杂描述，只保留核心）
  ↓ 再次失败
第3次：切换 gpt-image-2（见示例3），接受额度消耗
```

---

## ⚠️ 已知坑（必读）

### 坑1：gpt-5.5 默认返回流式响应

**现象**：`resp.json()` 报错 `JSONDecodeError: Expecting value`  
**原因**：gpt-5.5 默认开启 SSE 流式输出，响应体是 `data: {...}` 格式，不是标准 JSON  
**解决**：请求 body 里加 `"stream": False`

### 坑2：gpt-5.5 返回 SVG 代码或文字而不是图片

**现象**：`message.images` 为空，`message.content` 是 SVG 代码或「我帮你设计了…」文字  
**原因**：排版/设计类描述（"居中三行文字""白色背景"）触发模型的「代码生成」或「文字回复」模式  
**解决**：用「写实拍照」语气而不是「设计排版」语气，见下方封面模板

### 坑3：PowerShell 中文变问号

**现象**：提示词里的中文全变成 `?`  
**原因**：PowerShell `Invoke-RestMethod` 默认不强制 UTF-8  
**解决**：改用 `HttpWebRequest` 手动指定 UTF-8 字节流（见示例4）  
**Python 不受此问题影响**

---

## 调用示例

### 小红书封面 prompt 模板（✅ 最终定版）

```
You are an expert Xiaohongshu (Little Red Book) content designer.
Create a high-performing cover image, portrait 3:4 ratio.
Light background, large bold text, highlight one key phrase.
Key text: [关键词1], [关键词2], [关键词3]
```

**为什么这样写：**
- 角色身份（expert designer）让模型主动按平台审美决策，不需要硬约束颜色
- `Light background` 对齐竞品主流（白/米白/浅色），排除深色背景
- `highlight one key phrase` 触发黄色高亮或彩色衬底，符合竞品视觉规律
- 只给关键词，不限布局，模型创意更强

**曾经踩过的坑（不要回头）：**

| 写法 | 结果 |
|------|------|
| 纯排版描述（居中三行文字、白色背景…） | 返回 SVG 代码或文字回复 |
| 过度限制（指定字体/px/颜色值/具体布局） | 出图死板，视觉张力弱 |
| 「请生成一张图片：竖版…」中文语气 | 偶发返回文字，不稳定 |
| ✅ 角色身份 + 浅色背景 + 关键词 | 稳定出图，风格符合竞品主流 |

---

### 示例1：图像生成 — gpt-5.5（✅ 日常首选）

```python
import os
import requests, base64

API_KEY = os.environ["CHUNFENG_API_KEY"]
URL = "https://chunfeng.mentalout.top/v1/chat/completions"
OUTPUT_PATH = "output.jpg"

# prompt 必须用「请生成一张图片」语气，不能只写规格描述
prompt = "Generate a social media cover image for Claude Code, portrait 3:4 ratio. Key text: Claude Code, 国内也可以用, 一键安装, 5分钟跑起来"

resp = requests.post(URL, headers={
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}, json={
    "model": "gpt-5.5",
    "stream": False,        # 必须！否则 JSON 解析报错
    "messages": [{"role": "user", "content": prompt}]
}, timeout=180)   # gpt-5.5 出图需要 50-150 秒，必须设 180

message = resp.json()['choices'][0]['message']
images = message.get("images", [])

if images:
    b64 = images[0]["image_url"]["url"].split(",", 1)[1]
    with open(OUTPUT_PATH, "wb") as f:
        f.write(base64.b64decode(b64))
    print("图片已保存:", OUTPUT_PATH)
else:
    print("未返回图片，文字回复：", message.get("content", "")[:200])
```

**响应结构**：
```json
{
  "choices": [{
    "message": {
      "role": "assistant",
      "content": null,
      "images": [
        {
          "type": "image_url",
          "image_url": { "url": "data:image/png;base64,..." }
        }
      ]
    }
  }]
}
```

---

### 示例2：文字对话 — gpt-5.5

```python
import os
import requests

API_KEY = os.environ["CHUNFENG_API_KEY"]
URL = "https://chunfeng.mentalout.top/v1/chat/completions"

resp = requests.post(URL, headers={
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}, json={
    "model": "gpt-5.5",
    "messages": [{"role": "user", "content": "你好，介绍一下自己"}]
})

print(resp.json()["choices"][0]["message"]["content"])
```

---

### 示例3：图像生成 — gpt-image-2（⚠️ 备用，高消耗）

```python
import os
import requests, base64

API_KEY = os.environ["CHUNFENG_API_KEY"]
URL = "https://chunfeng.mentalout.top/v1/images/generations"

resp = requests.post(URL, headers={
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}, json={
    "model": "gpt-image-2",
    "prompt": "小红书封面，白色背景，橙色大标题",
    "n": 1,
    "size": "1024x1536"    # 竖版小红书尺寸
}, timeout=120)

b64 = resp.json()["data"][0]["b64_json"]
with open("output.jpg", "wb") as f:
    f.write(base64.b64decode(b64))
print("图片已保存")
```

**响应结构**：
```json
{ "data": [{ "b64_json": "iVBORw0KGgo..." }] }
```

---

### 示例4：PowerShell 图像生成 — gpt-5.5（UTF-8 强制编码）

> 仅当必须用 PowerShell 时参考，Python 优先

```powershell
$key    = $env:CHUNFENG_API_KEY
$url    = "https://chunfeng.mentalout.top/v1/chat/completions"
$output = "C:\output.jpg"

$bodyObj = @{
    model    = "gpt-5.5"
    stream   = $false   # 必须！否则 JSON 解析报错
    messages = @(@{
        role    = "user"
        content = "请生成一张小红书封面图片：白色背景，橙色大标题：2026国内用Claude"
    })
}

# 强制 UTF-8 编码，否则中文变问号
$bodyJson  = $bodyObj | ConvertTo-Json -Depth 5
$utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($bodyJson)

$request = [System.Net.HttpWebRequest]::Create($url)
$request.Method      = "POST"
$request.ContentType = "application/json; charset=utf-8"
$request.Headers.Add("Authorization", "Bearer $key")
$request.ContentLength = $utf8Bytes.Length
$request.Timeout       = 180000   # 180秒，gpt-5.5出图需50-150秒

$stream = $request.GetRequestStream()
$stream.Write($utf8Bytes, 0, $utf8Bytes.Length)
$stream.Close()

$response = $request.GetResponse()
$reader   = [System.IO.StreamReader]::new($response.GetResponseStream(), [System.Text.Encoding]::UTF8)
$json     = $reader.ReadToEnd()
$reader.Close()

$data   = $json | ConvertFrom-Json
$images = $data.choices[0].message.images
if ($images) {
    $b64 = $images[0].image_url.url.Split(",", 2)[1]
    [System.IO.File]::WriteAllBytes($output, [System.Convert]::FromBase64String($b64))
    Write-Host "图片已保存：$output"
} else {
    Write-Host "未返回图片，文字回复：" $data.choices[0].message.content
}
```

---

## 支持的图片尺寸

| 尺寸 | 比例 | 适用场景 |
|------|------|---------|
| `1024x1536` | 2:3 | ✅ 小红书竖版封面（首选） |
| `1024x1024` | 1:1 | 方图，通用 |
| `1536x1024` | 3:2 | 横图，banner |

> gpt-5.5 出图尺寸由模型自行决定，gpt-image-2 支持上表所有尺寸指定

---

## 常见错误速查

| 错误现象 | 原因 | 解决 |
|---------|------|------|
| `JSONDecodeError: Expecting value` | gpt-5.5 默认 SSE 流式响应 | body 加 `"stream": False` |
| 返回 SVG 代码而非图片 | prompt 没有「请生成图片」语气 | 改为「请生成一张...图片」 |
| 中文变问号 | PowerShell 编码问题 | 用 HttpWebRequest + UTF-8 字节流 |
| 503 Server Unavailable | 后端宕机 | 等待或换模型 |
| 405 Method Not Allowed | 用错端点 | 检查 URL，用 chunfeng 端点 |
| 图片内容不符合要求 | 模型创意发挥 | 细化 prompt，加具体约束 |
