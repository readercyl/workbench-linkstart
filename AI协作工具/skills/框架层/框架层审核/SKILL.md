---
name: 框架层审核
description: 框架层机制唯一审核入口——宪法+自动化链+Skill+配置+MCP+Memory+Git全覆盖。11步全量审计+Token审计+流程评估三种模式。触发：「审核」「框架层」「框架层审核」「评估一下」「评估」「上下文太重」「负载审计」「审计流程」；结构性改动后自动触发。
may_propose: [数据层体检]
---

# 框架层审核

> 版本：v5.3 · 2026-07-14 · 维护系统全量对齐
> v5.2→v5.3：①「为什么需要」→「角色」（维护系统三层定位）；② 路由表通知改主动（「不修→归」改为「通知」）；③ 新增自我进化；④ CHANGELOG 死引用清理

> 每次结构性改动后必须执行。审核范围：工作空间运转所需的全部机制文件——不只是宪法和 Skill，还包括让它自动跑起来的 hook、cron、settings、MCP、memory 等。

## 角色

维护系统三层之一，管框架机制层的健康。11 层组件全覆盖——宪法、自动化链、Skill 定义、配置、Memory、目录、Git、运转日志、外部集成、知识库设施、Obsidian。上游被运营层巡检委托（基础设施异常），下游 `may_propose` 提议数据层体检（机制改动后验证知识数据）。

## 三模式路由

| 用户说什么 | 走哪个 | 做什么 |
|-----------|--------|--------|
| 「框架层审核」「框架审核」、结构性改动后 | **全量 10 步** | 11 层审计 + 优化，输出完整报告 |
| 「上下文太重」「负载审计」 | **直达步骤 11** | 只跑 Token 审计 |
| 「评估一下 XX」「审查 XX 流程」 | **流程评估** | 加载 `references/流程评估.md`，单项深度诊断 |

> 单项任务跳过全量扫描，结果直接输出。不写 checkpoint。

触发源：结构性改动后强制 · 用户手动 · 数据层体检联动 · 运营层巡检委托

## 11 层：审计与优化双模

每层先审计（在不在/对不对），再优化（能不能更好）。🔴🟡 走修复路由，🔵 记入报告。

| 层 | 内容 | 审计 | 优化 |
|---|------|------|------|
| 🎯 宪法 | 全部 CLAUDE.md + soul.md | 文件存在、版本号对齐 | **读全文**：过时引用、被后续改动覆盖的规则、新机制未写入→提议整合/重写 |
| ⚡ 自动化 | Hook + Cron | 脚本可执行、Cron 合法 | 频率合理、无死任务。**不加新任务** |
| 🔧 Skill | 全部 SKILL.md + 软链接 | 存在、可解析、frontmatter 完整 | description 精准、无废弃残留 |
| ⚙️ 配置 | settings ×3 + .mcp.json | JSON 合法、env 关键字段 | 过期权限、冗余 env |
| 🧠 Memory | memory/ + MEMORY.md | 索引一致、frontmatter 完整 | 内容矛盾、遗漏主题 |
| 📁 目录 | 一级目录 + 子目录结构 | 磁盘≈文档 | 空壳目录、命名统一 |
| 🔒 Git | .gitignore + remote | 灾备可达、关键文件不排斥 | 大文件、该忽略未忽略 |
| 📋 运转日志 | 对话/日报/周复盘/体检/框架审核 | 子目录存在 | 异常积压 |
| 🔌 外部集成 | MCP + CLI + API 配置 | 可运行、文档匹配 | 装了没用的 |
| 📚 知识库设施 | index/log/MOC/脚本/缓存 | 文件存在 | 数字对齐、脚本语法 |
| 🏠 Obsidian | .obsidian/ | 配置存在 | 无用插件 |

## 审核流程（10 步 · 4 阶段）

> **执行策略**：同阶段内步骤并行跑，跨阶段串行。每步走完审计→顺手扫优化。每阶段结束写 checkpoint `touch 00-运转日志/框架审核/.checkpoint/phase-{N}`。

---

### 阶段一：存在性（文件都在不在？）

#### 1. 文件清单 + 目录结构

扫描全项目，确认 11 层框架组件的关键文件存在且可读。不用逐条手工 `test -f`——用 `find` 批量扫描并汇总：

- **宪法**：项目根 + 全部子目录的 `CLAUDE.md`、`soul.md`、`~/.claude/CLAUDE.md`
- **自动化**：`AI协作工具/hooks/` 下脚本 + `.claude/scheduled_tasks.json`
- **Skill**：`AI协作工具/skills/` + `03|04|06|07/skills/` 下全部 `SKILL.md`
- **配置**：`.claude/settings.json`、`.claude/settings.local.json`、`~/.claude/settings.json`、`~/.claude/.mcp.json`
- **运转日志**：`00-运转日志/` 下 5 个子目录 + `数据看板/` + `Clippings/`
- **知识库设施**：`02-知识卡片/index.md`、`log.md`、MOC 文件、`.network_index.json`、`dashboard_data.json`
- **编译/体检/日报脚本**：`AI协作工具/skills/数据层/知识编译/编译收口.sh`、`数据层/数据层体检/S1-机械扫描.sh`、`运营层/日报/日报数据.sh`

同时比对磁盘一级目录与子宪法「目录结构」节，确认一致。

#### 2. Git 审计

- `.gitignore` 不排斥 `.claude/settings.json`、`scheduled_tasks.json`、`AI协作工具/hooks/`
- `.gitignore` 排斥 `.mcp.json`、`cookies.json`、API 密钥文件
- 运行 `bash AI协作工具/skills/框架层/框架层审核/灾备检查.sh`——remote 可达性 + 同步状态 + .git 完整性 + 大文件。exit 1 = 🔴

> 步骤 1 和 2 并行执行。

---

### 阶段二：自动化链（自动跑的链路通不通？）

#### 3. Hook 体系

- `settings.json` hooks 节完整（`type: command` + `command` + `timeout`）
- 脚本可执行（`test -x`）+ 语法有效（`bash -n`）
- `AI协作工具/hooks/CLAUDE.md` 描述与实际文件一致
- 脚本内引用的路径全部存在

#### 4. Cron 任务

- JSON 合法，字段完整（`cron`/`prompt`/`recurring`）
- Cron 表达式语法正确，任务未超 7 天过期
- Prompt 中引用的 Skill 全部存在

#### 5. 链路验证

沿着自动化链走一遍：Hook 注入 → workbench-prep.sh → 引用的 Skill，确认每个节点都存在。Cron → Skill 引用同样验证。这是验证性步骤——不复查步骤 3/4 已确认的内容，只检查跨节点引用不断。

> 步骤 3 和 4 并行执行，5 在两者完成后运行。

---

### 阶段三：配置（开关对不对？）

#### 6. Settings 三份

json 合法、hooks 完整、env 关键字段存在（`ANTHROPIC_AUTH_TOKEN`、`ANTHROPIC_BASE_URL`、模型映射）。`settings.local.json` 的 `permissions.allow` 无过期路径。

#### 7. MCP + 外部集成

- MCP：`.mcp.json` 合法，服务端启动命令可解析，server 数与文档一致
- CLI 工具：lark-cli、weflow、wx-cli 的二进制和使用说明对应
- MCP 文档：`AI协作工具/MCP工具/` 下文档与启用的 server 匹配

> 步骤 6 和 7 并行执行。

---

### 阶段四：一致性（各处版本号、路径、引用对得上吗？）

#### 8. Skill 全量审计

收集所有 Skill 的版本号（用于步骤 10 比对）。检查：
- 每个 Skill frontmatter 含 `name` + `description`
- 每个 Skill 有版本号行 `> 版本：vX.X · YYYY-MM-DD`
- 无空 SKILL.md
- 内部路径引用目标存在（抽样重点 Skill）

#### 9. Memory 体系

- Memory 目录下 `.md` 文件与 `MEMORY.md` 索引一一对应
- 每条 memory 含合法 frontmatter（`name`/`description`/`metadata.type`）
- 无孤儿文件、无着落条目

#### 10. 版本号 + 路径一致性

- 根宪法版本号 vs 子宪法引用版本 → 不一致则同步
- 子宪法版本号引用格式 `遵从根宪法 vX.XX`
- 全项目扫描旧路径残留（目录重命名后常见遗漏）
- 根宪法版本号与子宪法引用一致

> 步骤 8 和 9 并行执行，10 在两者完成后运行（依赖 8 收集的版本号）。

---

### 11. Token 审计

查常驻上下文有没有膨胀浪费。四步机械执行：

**① 测体积**（并行跑）：
```bash
wc -c CLAUDE.md soul.md ~/.claude/CLAUDE.md                                          # 宪法
find -L .claude/skills -name "SKILL.md" -exec grep "description:" {} \; | wc -c      # Skill 描述
find AI协作工具/skills -name "*.sh" -exec wc -c {} \; | awk '{s+=$1} END {print s}' # 脚本
wc -c ~/.claude/projects/*/memory/MEMORY.md 2>/dev/null                               # Memory
jq -r '.tasks[].prompt' .claude/scheduled_tasks.json 2>/dev/null | wc -c            # Cron
```
token 估算 = 字符数 / 2.5。汇总一张表。

**② 找浪费**：三刀——
- Skill 描述 >100 字符的，精简到一句话（自建 40-60 字符，外部 60-120）
- frontmatter 有重复 description 行 → 去重
- 工具索引每条压缩到「能力+一个触发词」

**③ 修完重测**：重跑步骤 ①，对比节省量。

**④ 质量自检**：精简后逐条问「AI 还能在正确场景匹配到这个 Skill 吗？」不能 → 回退。怀疑即保留——多 10 个 token 不会压垮上下文，少一个关键词会让工具匹配不到。

---

## 输出

写入 `00-运转日志/框架审核/YYYY-MM-DD-框架审核报告.md`。

报告骨架：
```
# 框架层审核报告
> 审核时间 · 模式 · 触发原因

## 总体健康度
🟢/🟡/🔴 一句话总结

## 四阶段速览
| 阶段 | 结果 | 异常 |
|------|:--:|------|
| 存在性 | ✅/🔴 | N 项 |
| 自动化链 | ✅/🟡 | N 项 |
| 配置 | ✅ | - |
| 一致性 | 🟡 | N 项 |

## 发现明细
🔴 ... 🟡 ...

## 优化建议
🔵 宪法：... / Skill：... / 配置：... （有则写，无则略）

## Token 审计（步骤 11）

## 修复清单
| 优先级 | 位置 | 问题 | 状态 |
```

---

## 审完怎么修

### 分级

| 标记 | 含义 | 动作 |
|:--:|------|------|
| 🔴 | 确定性 bug | 立即修复，不等确认 |
| 🟡 | 可能有问题 | 列清单+方案，等用户确认 |
| 🔵 | 优化建议 | 记入报告，不主动修 |

### 路由

| 问题类型 | 交给谁 |
|---------|-------|
| 路径过期、脚本 bug、JSON 非法 | 自己修（Edit/Bash） |
| Skill frontmatter 残缺、版本号缺失 | 委托 `工具自修正` |
| Skill 流程设计缺陷 | 加载 `references/流程评估.md` |
| 知识数据层问题 | 不修——通知 `数据层体检` |
| 日常运营问题（脚本路径、Cron 过期、积压） | 通知 `运营层巡检` |
| 安全配置、Memory 内容 | 标 ℹ️ 等用户确认 |

### 验证

修复后不自查——用独立子代理对抗验证。同一问题来回 ≥2 轮 → 升级用户裁决。

## 铁律

- **改动即审核**：结构性改动后立即触发
- **全量不抽样**：11 层组件全部检查
- **数字不硬编码**：文件数、Skill 数通过 `find`/`ls` 动态扫描
- **修复必回写**：报告→修复→验证→回写闭环
- **权限变更需确认**：settings/Memory 不自动改
- **三层定位**：只管框架机制层，知识数据归数据层体检，日常运营归运营层巡检

## 自我进化

- 同一问题被审计发现 ≥3 次 → 不是执行问题，是规则/Skill 定义问题 → 根因分析 → 向用户提议修正
- 用户纠正 → 委托工具自修正。累计 ≥3 条纠正 → 调流程评估深度诊断
