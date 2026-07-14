# MiMo 多模态调用参考

> 更新：2026-06-20 · 来源：https://mimo.mi.com/docs/zh-CN/quick-start/usage-guide/multimodal-understanding/image-understanding

## 基本信息

| 项目 | 值 |
|------|-----|
| 模型 | `mimo-v2.5`（推荐）或 `mimo-v2-omni` |
| OpenAI 端点 | `https://api.xiaomimimo.com/v1/chat/completions` |
| Anthropic 端点 | `https://api.xiaomimimo.com/anthropic/v1/messages` |
| 认证 | Header `api-key` |
| API Key | 从本机环境变量 `MIMO_API_KEY` 读取 |
| 官方文档 | https://mimo.mi.com/docs/zh-CN/quick-start/usage-guide/multimodal-understanding/image-understanding |
| 定价 | https://mimo.mi.com/#/docs/pricing |

> 安全规则：真实 Key 只保存在本机环境变量或未提交的 `.env` 中，禁止写入代码、文档和 Git 历史。

## 支持格式与限制

| 项目 | 值 |
|------|-----|
| 图片格式 | JPEG / PNG / GIF / WebP / BMP |
| 单图上限 | 50 MB（URL 或 Base64 均可） |
| 多图 | 支持，总 token 不超过模型上下文长度 |
| 本地文件 | **不支持**直接上传，必须转 URL 或 Base64 |

## AI调用方式（OpenAI 兼容·Base64）

这是最常用的场景——本地有图片文件，需要让 MiMo 识别。

```bash
# 1. base64 编码图片
B64=$(base64 -i <图片路径>)

# 2. 调用 API
curl -s --max-time 120 https://api.xiaomimimo.com/v1/chat/completions \
  -H "api-key: $MIMO_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "
import json
payload = {
    'model': 'mimo-v2.5',
    'max_completion_tokens': 4096,
    'messages': [{
        'role': 'user',
        'content': [
            {'type': 'text', 'text': '请描述这张图片的全部内容'},
            {'type': 'image_url', 'image_url': {
                'url': 'data:image/png;base64,$B64'
            }}
        ]
    }]
}
print(json.dumps(payload))
")"
```

**注意**：`max_completion_tokens` 是必填字段，旧版文档错误地用了 `max_tokens`。

## AI调用方式（OpenAI 兼容·URL 图片）

图片已有公网 URL 时，省去 base64 步骤：

```bash
curl -s --max-time 120 https://api.xiaomimimo.com/v1/chat/completions \
  -H "api-key: $MIMO_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mimo-v2.5",
    "max_completion_tokens": 4096,
    "messages": [{
      "role": "user",
      "content": [
        {"type": "text", "text": "请描述这张图片"},
        {"type": "image_url", "image_url": {"url": "https://example.com/image.png"}}
      ]
    }]
  }'
```

## Anthropic 兼容端点

MiMo 同时提供 Anthropic 格式端点，图片格式不同（`type: "image"` 而非 `image_url`）：

### Base64

```bash
curl -s --max-time 120 https://api.xiaomimimo.com/anthropic/v1/messages \
  -H "api-key: $MIMO_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "
import json
payload = {
    'model': 'mimo-v2.5',
    'max_tokens': 4096,
    'messages': [{
        'role': 'user',
        'content': [
            {'type': 'text', 'text': '请描述这张图片'},
            {'type': 'image', 'source': {
                'type': 'base64',
                'media_type': 'image/png',
                'data': '\$B64'
            }}
        ]
    }]
}
print(json.dumps(payload))
")"
```

### URL

```bash
curl -s --max-time 120 https://api.xiaomimimo.com/anthropic/v1/messages \
  -H "api-key: $MIMO_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mimo-v2.5",
    "max_tokens": 4096,
    "messages": [{
      "role": "user",
      "content": [
        {"type": "text", "text": "请描述这张图片"},
        {"type": "image", "source": {
          "type": "url",
          "url": "https://example.com/image.png"
        }}
      ]
    }]
  }'
```

**两种端点选择**：OpenAI 和 Anthropic 端点功能等价，选哪个看调用方便。区别仅在请求/响应格式。

## 多图输入

一个请求可以传多张图，content 数组里放多个 `image_url`（或 Anthropic 的 `image`）块即可。所有图片和文本的总 token 数必须小于模型上下文长度。

```bash
curl -s --max-time 120 https://api.xiaomimimo.com/v1/chat/completions \
  -H "api-key: $MIMO_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "
import json
payload = {
    'model': 'mimo-v2.5',
    'max_completion_tokens': 4096,
    'messages': [{
        'role': 'user',
        'content': [
            {'type': 'image_url', 'image_url': {'url': 'data:image/png;base64,$B64_1'}},
            {'type': 'image_url', 'image_url': {'url': 'data:image/png;base64,$B64_2'}},
            {'type': 'text', 'text': '比较这两张图的异同'}
        ]
    }]
}
print(json.dumps(payload))
")"
```

## 响应格式

```json
{
    "id": "be319773af414195b27a9b1cefc3fe6f",
    "choices": [{
        "finish_reason": "stop",
        "index": 0,
        "message": {
            "content": "<模型回答文本>",
            "role": "assistant",
            "reasoning_content": "<模型内部推理过程>"
        }
    }],
    "usage": {
        "completion_tokens": 574,
        "prompt_tokens": 1085,
        "total_tokens": 1659,
        "completion_tokens_details": { "reasoning_tokens": 288 },
        "prompt_tokens_details": {
            "cached_tokens": 1081,
            "image_tokens": 1024
        }
    }
}
```

**关键字段**：
- `choices[0].message.content` → 最终回答
- `choices[0].message.reasoning_content` → 推理过程（可选读取）
- `usage.prompt_tokens_details.image_tokens` → 图片消耗的 token 数
- `usage.prompt_tokens_details.cached_tokens` → 缓存命中的 token 数

## 图片 Token 估算

官方给出的计算函数（供参考，实际以 API 返回的 `image_tokens` 为准）：

```python
import math
from PIL import Image

PATCH_SIZE = 16
SPATIAL_MERGE_SIZE = 2
IMAGE_MIN_PIXELS = 8192
IMAGE_MAX_PIXELS = 8388608

def calc_image_tokens(image_path: str) -> int:
    image = Image.open(image_path)
    height, width = image.height, image.width
    factor = PATCH_SIZE * SPATIAL_MERGE_SIZE  # 32

    h_bar = round(height / factor) * factor
    w_bar = round(width / factor) * factor

    if h_bar * w_bar > IMAGE_MAX_PIXELS:
        beta = math.sqrt((height * width) / IMAGE_MAX_PIXELS)
        h_bar = math.floor(height / beta / factor) * factor
        w_bar = math.floor(width / beta / factor) * factor
    elif h_bar * w_bar < IMAGE_MIN_PIXELS:
        beta = math.sqrt(IMAGE_MIN_PIXELS / (height * width))
        h_bar = math.ceil(height / beta / factor) * factor
        w_bar = math.ceil(width / beta / factor) * factor

    grid_h = h_bar // PATCH_SIZE
    grid_w = w_bar // PATCH_SIZE
    return (1 * grid_h * grid_w) // (SPATIAL_MERGE_SIZE ** 2)
```

**原理**：图片缩放到 8192~8388608 像素区间，按 16×16 patch 切分后 2×2 合并，token 数 = 合并后的 patch 网格数。

**实测参考**：~300KB 的截图（如 946×1098）约 1,024 image_tokens，加上文本 prompt 约 1,000+ total prompt tokens。

## Python SDK 调用

### OpenAI SDK

```python
import os
from openai import OpenAI

client = OpenAI(
    api_key=os.environ["MIMO_API_KEY"],
    base_url="https://api.xiaomimimo.com/v1"
)

completion = client.chat.completions.create(
    model="mimo-v2.5",
    max_completion_tokens=4096,
    messages=[{
        "role": "user",
        "content": [
            {"type": "image_url", "image_url": {"url": "data:image/png;base64,..."}},
            {"type": "text", "text": "描述图片"}
        ]
    }]
)
print(completion.choices[0].message.content)
```

### Anthropic SDK

```python
import os
from anthropic import Anthropic

client = Anthropic(
    api_key=os.environ["MIMO_API_KEY"],
    base_url="https://api.xiaomimimo.com/anthropic"
)

message = client.messages.create(
    model="mimo-v2.5",
    max_tokens=4096,
    messages=[{
        "role": "user",
        "content": [
            {"type": "image", "source": {
                "type": "base64",
                "media_type": "image/png",
                "data": "..."
            }},
            {"type": "text", "text": "描述图片"}
        ]
    }]
)
print(message.content)
```

## 注意事项

1. 用 `mimo-v2.5`，不是 `mimo-v2.5-pro`（后者纯文本）；多模态也可用 `mimo-v2-omni`
2. OpenAI 格式用 `max_completion_tokens`，Anthropic 格式用 `max_tokens`
3. Base64 前缀必须带 `data:{MIME};base64,`，不能只传裸 base64
4. 不支持本地文件直接上传，必须走 URL 或 Base64
5. 图片总 token + 文本 token < 模型上下文长度
6. Token 估算仅供参考，实际用量看 `usage.prompt_tokens_details.image_tokens`
