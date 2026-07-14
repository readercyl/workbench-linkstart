---
created: 2026-05-22
source_type: AI对话
status: growing
---

# Skill 包是 AI 指引层，CLI 是工具层，两者不该混在同一个目录

Skill 和它底层调用的 CLI 工具是**两层不同的东西**，但在实操中经常被混在一起。

- **Skill 层（AI 指引）**：SKILL.md 写「什么场景调用 / 怎么调用 / 参数怎么填」，是给 AI 看的中文文档
- **CLI 层（执行工具）**：实际的可执行文件 / npm 包 / Python 库，是给系统跑的二进制

AI 通过 SKILL.md 学会调用方式，最终落地是调用底层 CLI 跑出结果。两者职责清晰：一层管「怎么用」，一层管「能用」。

## 典型反例

`~/.claude/skills/wx-cli/` 这个文件夹里同时装着：
- `SKILL.md`（AI 指引层）
- `src/`、`Cargo.toml`、`npm/`（CLI 源码层）
- `install.sh`（把 CLI 编译/下载到 `/usr/local/bin/wx`）

结果是「skill 包」和「CLI 源码」混在同一个目录。直觉上以为删 skill 就是删 CLI，实际上 SKILL.md 删了也不影响 `/usr/local/bin/wx` 能跑。

## 对照：飞书 CLI 的清爽分层

`~/.claude/skills/lark-doc/` 等 24 个 lark-* skill 都只是 SKILL.md + 参考文档，没有源码——因为底层 CLI 是 npm 全局包 `@larksuite/cli`，独立装在 `~/.nvm/.../lib/node_modules/`。两层完全解耦：

- skill 包升级 → 改 SKILL.md
- CLI 升级 → `npm update -g @larksuite/cli`
- 两件事互不影响

## 为什么会混在一起

通常是 skill 作者图方便——把安装脚本顺手放在 skill 目录里，让用户跑 `~/.claude/skills/<x>/install.sh` 就完事。但代价是层次不清，迁移和审计时容易判断错。

## 实操建议

设计 skill 包时坚持：
- **skill 包只放 SKILL.md + 参考资料**
- CLI 装到系统标准路径（独立二进制 → `/usr/local/bin`，npm 包 → `npm i -g`，Python 库 → `pip install`）
- install.sh 如果必须放在 skill 包里，目的是「引导用户/AI 把 CLI 装到正确位置」，而不是「把 CLI 留在 skill 包里运行」

判断标准：把 skill 文件夹整个删掉，CLI 应该还能跑。否则就是两层混在一起。

**相关链接**：
- [[AI Native的判断标准-拿掉AI就断流]]
- [[AI半自动化与Agent协作思维]]
- [[Agent不是回答问题是把事情做完]]
- [[四层工具选择逻辑]]
- [[知识库分两层管-根宪法全局子宪法局部]]
- [[买现成工具不自己写-AI写一周不如150元买]]
**来源**：5/22 排查 wx-cli 安装路径时，用户一句「这个应该不属于 skill 吧」点破。详见 2026-05-22-体检修复与协作系统v1.0 主题 9。