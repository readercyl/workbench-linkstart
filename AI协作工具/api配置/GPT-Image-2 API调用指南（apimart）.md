# GPT-Image-2 API 调用指南（apimart.ai）

> 整理日期：2026-05-20 | 更新：按用户使用习惯改
> 平台：apimart.ai | 模式：**异步**（提交 → task_id → 轮询取图）

---

## 用户专用：一条命令出图

```python
import requests, time, base64, os
from datetime import datetime

API_KEY = os.environ["APIMART_API_KEY"]
HEADERS = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

# ===== 默认配置（按你的使用习惯） =====
DEFAULT_RESOLUTION = "1k"     # 快速出图
DEFAULT_TIMEOUT = 120         # 1k 够用
SAVE_DIR = os.path.expanduser("~/Downloads")
POLL_INTERVAL = 4             # 轮询间隔秒数
FIRST_POLL_DELAY = 10         # 提交后等多久首次查询
# =======================================
# 比例不设默认值，AI 根据内容自动判断：
#   风景/动作/横构图 → 3:2
#   人物/竖版社交 → 3:4
#   通用 → 1:1
#   小红书封面 → 3:4
#   公众号封面 → 1881x800 (2.35:1)


def 生成图片(描述, 比例=None, 分辨率=DEFAULT_RESOLUTION, 参考图=None, 超时=DEFAULT_TIMEOUT):
    """
    你说想要什么图 → 自动提交、轮询、下载到本地 → 返回文件路径
    不传比例则由 AI 根据内容判断
    """
    image_urls = 参考图

    # 1. 提交
    body = {
        "model": "gpt-image-2",
        "prompt": 描述,
        "n": 1,
        "resolution": 分辨率
    }
    if 比例:
        body["size"] = 比例
    if image_urls:
        body["image_urls"] = image_urls

    resp = requests.post(
        "https://api.apimart.ai/v1/images/generations",
        headers=HEADERS, json=body
    )
    resp.raise_for_status()
    task_id = resp.json()["data"][0]["task_id"]
    print(f"已提交 → {task_id}")

    # 2. 等待 + 轮询
    time.sleep(FIRST_POLL_DELAY)
    deadline = time.time() + 超时
    while time.time() < deadline:
        resp = requests.get(
            f"https://api.apimart.ai/v1/tasks/{task_id}",
            headers=HEADERS
        )
        resp.raise_for_status()
        data = resp.json()["data"]
        status = data["status"]

        if status == "completed":
            url = data["result"]["images"][0]["url"][0]
            break
        elif status == "failed":
            msg = data.get("error", {}).get("message", "未知错误")
            raise RuntimeError(f"生成失败：{msg}")

        print(f"  {status}… 再等{POLL_INTERVAL}秒")
        time.sleep(POLL_INTERVAL)
    else:
        raise TimeoutError(f"超时（{超时}s）：{task_id}")

    # 3. 下载
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"img_{timestamp}.png"
    filepath = os.path.join(SAVE_DIR, filename)

    img_resp = requests.get(url)
    with open(filepath, "wb") as f:
        f.write(img_resp.content)
    print(f"已保存 → {filepath}")
    return filepath


# ===== 使用示例 =====
if __name__ == "__main__":
    # AI 自动判断比例（不传比例参数）
    生成图片("特朗普滑雪，写实动态抓拍，阳光照在雪地上")

    # 小红书封面（指定 3:4）
    生成图片("小红书封面：极简穿搭，浅灰色背景，韩系ins风", 比例="3:4")

    # 公众号封面（2.35:1，用自定义像素）
    生成图片("公众号封面：AI 工具推荐，深色科技风", 比例="1881x800")

    # 方图
    生成图片("一只橘猫坐在窗台上看夕阳，水彩画风格", 比例="1:1")
```

---

## 比例判断规则

AI 根据内容场景自动选择，用户无需指定：

| 场景 | 比例 | 典型画面 |
|------|------|---------|
| 风景/动作/横构图 | `3:2` | 自然风光、运动、城市全景 |
| 人物/竖版社交 | `3:4` | 人像、穿搭、日常随拍 |
| 通用/无明确方向 | `1:1` | 方图，多平台通用 |
| **小红书封面（强制）** | `3:4` | 竖版信息流 |
| **公众号封面（强制）** | `1881x800` | 2.35:1，用自定义像素 |

## 用户常用尺寸（手动指定时参考）

| 场景 | size | 1k 实际像素 | 说明 |
|------|------|-----------|------|
| 小红书封面 | `3:4` | 768×1024 | ✅ 默认，竖版信息流 |
| 公众号封面 | `1881x800` | — | 2.35:1，API 不支持此比例，用自定义像素 |
| 方图 | `1:1` | 1024×1024 | 朋友圈/多平台通用 |
| 横版 Banner | `3:2` | 1536×1024 | 公众号头图/文章内图 |

> 完整 15 种比例及对应像素见底部参考表。

---

## 两种模式

### 模式一：文生图（日常主力）

直接用中文描述你要的画面，AI会转成合适的 prompt：

```python
生成图片("小红书封面：AI 工具推荐，极简白底大字，突出重点")
```

### 模式二：图生图（偶尔用，局部修改/风格迁移）

传入本地图片或 URL：

```python
# 参考图 URL
生成图片("把这张照片背景换成海边", 参考图=["https://example.com/photo.jpg"])

# 本地文件转 base64
import base64
with open("原图.jpg", "rb") as f:
    b64 = "data:image/jpeg;base64," + base64.b64encode(f.read()).decode()
生成图片("把衣服颜色改成红色", 参考图=[b64])
```

最多 16 张参考图，URL 和 base64 可混填。

---

## 申请任务

| 参数 | 必填 | 默认 | 说明 |
|------|------|------|------|
| `model` | ✅ | — | 固定 `gpt-image-2` |
| `prompt` | ✅ | — | 直接说中文即可，AI 会自动优化 |
| `size` | | `3:4` | 比例或像素尺寸 |
| `resolution` | | `1k` | `1k` / `2k` / `4k` |
| `n` | | 1 | 只能填 1，别加引号 |

---

## 任务状态

| 状态 | 含义 |
|------|------|
| `submitted` | 已提交 |
| `processing` | 生成中 |
| `completed` | 完成，自动下载 |
| `failed` | 失败，看 error.message |

---

## 错误速查

| 错误码 | 原因 | 处理 |
|--------|------|------|
| 400 | 参数不合法 | 检查 size 格式 |
| 401 | Key 无效 | 换 Key |
| 402 | 余额不足 | 充值 |
| 429 | 频率过高 | 等一会 |
| 500/503 | 服务器端 | 重试 |
| 任务 failed | content 触发审核 | 改 prompt |

---

## 注意事项

- prompt 里别写比例，用 `size` 参数控制
- 结果 URL 有效期 24 小时，但代码已自动下载，不用管
- 单张 1k 一般 30~60 秒出图，2k/4k 更久
- 违规内容会被拒绝，不扣费

---

## 附录：完整尺寸-像素对照表

| size | 1k | 2k | 4k |
|------|----|----|-----|
| `1:1` | 1024×1024 | 2048×2048 | 2880×2880 |
| `3:2` | 1536×1024 | 2048×1360 | 3520×2336 |
| `2:3` | 1024×1536 | 1360×2048 | 2336×3520 |
| `4:3` | 1024×768 | 2048×1536 | 3312×2480 |
| `3:4` | 768×1024 | 1536×2048 | 2480×3312 |
| `5:4` | 1280×1024 | 2560×2048 | 3216×2576 |
| `4:5` | 1024×1280 | 2048×2560 | 2576×3216 |
| `16:9` | 1536×864 | 2048×1152 | 3840×2160 |
| `9:16` | 864×1536 | 1152×2048 | 2160×3840 |
| `2:1` | 2048×1024 | 2688×1344 | 3840×1920 |
| `1:2` | 1024×2048 | 1344×2688 | 1920×3840 |
| `3:1` | 1881×836 | 3072×1024 | 3840×1280 |
| `1:3` | 887×1774 | 1024×3072 | 1280×3840 |
| `21:9` | 2016×864 | 2688×1152 | 3840×1648 |
| `9:21` | 864×2016 | 1152×2688 | 1648×3840 |

---

## 附录：apimart 官方完整文档（备查）

> 来源：apimart.ai 官网使用手册，Clippings 剪存于 2026-05-20
> 用途：当上方定制代码出问题、或需要查原始参数细节时使用

---

### 官方参数详细说明

**model** — 固定填 `gpt-image-2`。

**prompt** — 图像描述，支持中英文，建议详细描述。提交前会经过平台敏感词/安全审核，命中违规内容会直接返回错误。

**n** — 生成图片张数，取值范围只有 `1`。必须传入纯数字，不要加引号。

**size** — 图像比例，默认 `1:1`。支持 15 种比例：`auto`、`1:1`、`3:2`、`2:3`、`4:3`、`3:4`、`5:4`、`4:5`、`16:9`、`9:16`、`2:1`、`1:2`、`3:1`、`1:3`、`21:9`、`9:21`。也支持直接传入像素尺寸，例如 `1881x836`。

**resolution** — 输出分辨率档位，可选 `1k` / `2k` / `4k`，默认 `1k`。

**image_urls** — 参考图数组，传入后走图生图。最多 16 张，超过返回 `image_urls exceeds max 16`。支持图片 URL 和 base64 data URI，同一数组可混填。不传 `size` 时输出分辨率等于输入图分辨率，传 `size` 则强制按指定尺寸出图。

**official_fallback** — 是否使用官方渠道兜底，默认 `false`。

---

### 多语言提交示例

<details>
<summary>cURL</summary>

```bash
curl --request POST \
  --url https://api.apimart.ai/v1/images/generations \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
    "model": "gpt-image-2",
    "prompt": "一只橘猫坐在窗台上看夕阳，水彩画风格",
    "n": 1,
    "size": "16:9",
    "resolution": "2k"
  }'
```
</details>

<details>
<summary>Python（最简）</summary>

```python
import requests

url = "https://api.apimart.ai/v1/images/generations"
payload = {
    "model": "gpt-image-2",
    "prompt": "一只橘猫坐在窗台上看夕阳，水彩画风格",
    "n": 1,
    "size": "16:9",
    "resolution": "2k"
}
headers = {
    "Authorization": "Bearer <token>",
    "Content-Type": "application/json"
}
response = requests.post(url, json=payload, headers=headers)
print(response.json())
```
</details>

<details>
<summary>JavaScript</summary>

```javascript
const url = "https://api.apimart.ai/v1/images/generations";
const payload = {
  model: "gpt-image-2",
  prompt: "一只橘猫坐在窗台上看夕阳，水彩画风格",
  n: 1,
  size: "16:9",
  resolution: "2k"
};
fetch(url, {
  method: "POST",
  headers: {
    "Authorization": "Bearer <token>",
    "Content-Type": "application/json"
  },
  body: JSON.stringify(payload)
})
  .then(response => response.json())
  .then(data => console.log(data))
  .catch(error => console.error('Error:', error));
```
</details>

---

### 响应结构

**提交成功（200）：**

```json
{
  "code": 200,
  "data": [
    {
      "status": "submitted",
      "task_id": "task_01KPQ7J7DWB7QZ3WCEK3YVPBRA"
    }
  ]
}
```

**查询完成（200）：**

```json
{
  "code": 200,
  "data": {
    "id": "task_01KPQ7J7DWB7QZ3WCEK3YVPBRA",
    "status": "completed",
    "progress": 100,
    "created": 1776748674,
    "completed": 1776748726,
    "actual_time": 52,
    "cost": 0.05279,
    "estimated_time": 100,
    "result": {
      "images": [
        {
          "url": ["https://upload.apimart.ai/f/image/xxx.png"],
          "expires_at": 1776835126
        }
      ]
    }
  }
}
```

取图路径：`data.result.images[0].url[0]`

---

### 完整错误响应

| 状态码 | message | type |
|--------|---------|------|
| 400 | 参数错误：size 不合法 / resolution 不支持 / 像素违规等 | `invalid_request_error` |
| 401 | 身份验证失败，请检查您的API密钥 | `authentication_error` |
| 402 | 账户余额不足，请充值后再试 | `payment_required` |
| 429 | 请求过于频繁，请稍后再试 | `rate_limit_error` |
| 500 | 服务器错误 | `server_error` |
| 503 | 上游暂时不可用，请稍后再试 | `service_unavailable` |

---

### 官方轮询建议

- 提交后等待 10~20 秒再开始查询
- 查询间隔 3~5 秒一次，避免无脑毫秒级轮询
- 单张图一般 30~60 秒完成（实测 actual_time 44~53 秒）
- 批量查询：`POST /v1/tasks/batch`，请求体 `{"task_ids": ["task_xxx", "task_yyy"]}`

---

### 官方注意事项（原文保留）

1. **异步处理**：提交后返回 `task_id`，需轮询 `/v1/tasks/{task_id}` 获取最终图片 URL
2. **内容审核**：`prompt` 会先经过平台敏感词/安全审核，命中违规内容会直接拒绝并不会计费
3. **结果 URL**：平台已将上游临时签名链接镜像到自家 R2 对象存储，返回的是稳定链接，客户端可直接访问
4. **URL 时效**：响应中的 `expires_at = completed + 24h`，建议尽快下载或转存
5. **比例冲突**：推荐只通过 `size` 字段传比例，不要在 `prompt` 里重复写比例，避免上游理解冲突
6. **计费规则**：按分辨率档位（1K / 2K / 4K）计费，失败不扣费，审核未通过不扣费
7. **4K 支持比例**：上述 15 个比例均支持 4K，也可以直接通过 `size` 传入对应像素尺寸
8. **任务保留**：`task_id` 在数据库里默认保留若干天（由 TASK_RETENTION_DAYS 配置），过期后查询会返回"任务不存在或已过期"
