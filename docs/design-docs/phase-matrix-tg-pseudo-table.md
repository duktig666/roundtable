---
slug: phase-matrix-tg-pseudo-table
source: 原创（issue #88）
created: 2026-04-22
status: Provisional
decisions: [DEC-027 Phase Matrix TG 快照格式：伪表替换单行进度条（Refines DEC-024 决定 4）]
---

# Phase Matrix TG 快照格式：ASCII 伪表 设计文档

## 1. 背景与目标

### 1.1 背景

DEC-024（PR #87，issue #79）把 Phase Matrix 快照折入 §Step 5b 事件类 `b` / `d` / `e` 尾段，格式 = 单行压缩进度条：

```
*Phase*: `1✅ · 2⏩ · 3✅ · 4🔄 · 5⏳ · 6⏳ · 7⏳ · 8⏳ · 9⏳`
```

2026-04-22 TG dogfood 用户反馈可读性差：

1. 只看到数字，需心算 "5 = Implementation / 6 = Adversarial testing"
2. 数字与 emoji 紧贴视觉粘连
3. 宏观进度视图对 TG 用户仍需外部记忆对应表

用户在三方案（保持现状 / 双行拆分 / ASCII 伪表）中选 **ASCII 伪表** 换 stage 名可见性。

### 1.2 目标

- 把 DEC-024 决定 4 的 **matrix 快照形态** 从单行进度条改为 ASCII 伪表
- 保持 DEC-024 其他 7 条决定（locus / 绑定 A/B/C / 折叠 b/d/e / 节流 / 终端渲染 / 转发边界 / Refines 非 Supersede）不变
- 零 agent / skill prompt 改动

### 1.3 非目标

- **不改** DEC-024 触发逻辑 / 渲染 locus / fold-into-b/d/e 任何决定
- **不改** 事件类 b / d / e 本体格式（仅改它们尾部附的快照片段）
- **不新增** 事件类 f
- **不改** §Phase Matrix 9 stage 表结构 / 图例 / 终端全量表格渲染

## 2. 目标格式规范

### 2.1 字面

TG reply 的 matrix 快照为单一三反引号 code fence（无语言标签）包裹，内含 11 行（表头 2 行 + 9 stage 行）：

```
| # | Stage               | Role      | Status |
|---|---------------------|-----------|--------|
| 1 | Context detection   | inline    | ✅     |
| 2 | Research (optional) | analyst   | ⏩     |
| 3 | Design              | architect | ✅     |
| 4 | Design confirmation | user      | ✅     |
| 5 | Implementation      | developer | 🔄     |
| 6 | Adversarial testing | tester    | ⏳     |
| 7 | Review              | reviewer  | ⏳     |
| 8 | DB review           | dba       | ⏳     |
| 9 | Closeout            | user      | ⏳     |
```

### 2.2 列宽规范（byte-exact，load-bearing）

列内容宽度（两端各 1 空格 padding 之外的部分）：

| 列 | 宽度 | 说明 |
|----|------|------|
| `#` | 1 char | 1-9 单数字 |
| Stage | 19 chars | stage 名 + 右填充空格至 19 |
| Role | 9 chars | 角色名 + 右填充空格至 9 |
| Status | 6 chars | emoji + 右填充 5 空格（emoji 视觉宽 2 的对齐 hack） |

**整行格式**：`| <#> | <stage 19> | <role 9> | <status 6> |`

分隔行：`|---|---------------------|-----------|--------|`（与表头列宽一致）

**Status 单元格特例**：表头 `Status` 6 chars 前后各 1 空格 → 单元内共 8 chars；数据行 emoji 1 codepoint + 5 空格 trailing → 单元内共 7 chars（前 1 空格 + emoji + 5 空格，末空格被表头的对齐冗余吸收）。此模式是 TG monospace emoji 视觉宽 2 的对齐取舍，需 byte-exact 保留。

### 2.3 Stage / Role 固定内容

9 行内容与 §Phase Matrix 表 1-9 stage 一一对应，**Stage 名与 Role 为固定字面值**（orchestrator 只替换 Status emoji）：

| # | Stage | Role |
|---|-------|------|
| 1 | `Context detection` | `inline` |
| 2 | `Research (optional)` | `analyst` |
| 3 | `Design` | `architect` |
| 4 | `Design confirmation` | `user` |
| 5 | `Implementation` | `developer` |
| 6 | `Adversarial testing` | `tester` |
| 7 | `Review` | `reviewer` |
| 8 | `DB review` | `dba` |
| 9 | `Closeout` | `user` |

### 2.4 Emoji 集与图例

emoji 集沿用 §Phase Matrix 图例：`⏳` 待办 / `🔄` 进行中 / `✅` 完成 / `⏩` skipped / `—` 不适用。

**图例不随快照附带**：每次 transition reply 不再重复图例；图例仅在 §Phase Matrix 终端 9 行全量表格下方一处（现状保留）。

### 2.5 MarkdownV2 转义

code fence（triple-backtick 无语言标签）内部为零转义区域；表头 `|` / `-` / `#` / `(` / `)` 等字符无需转义。fence 外的 prose（`*Phase*` 粗体等）按现行 MarkdownV2 规则转义。

**本 DEC 不再在 fence 前保留 `*Phase*:` 粗体标签**：伪表本身已含 `Stage` 列标题自明。折入事件类 b / d / e 时，伪表紧贴事件主体之后作为独立 fence 块。

## 3. DEC-022 分隔符和谐性说明

DEC-024 决定 4 理由段写："与 DEC-022 事件类 a 分隔符一致"（`·` 中点分隔）。本 DEC 明确 **优先级倒转**：

- **DEC-022 事件类 a 上下文是 in-stream 键值进度信息**（Step 0 context / Step 1 size / pipeline / mode），`·` 分隔短字段适合 inline 阅读
- **Phase Matrix 快照上下文是宏观进度视图**，用户诉求是 stage 名可见（issue #88 body）
- 两者 UX 语境不同，**readability priority** 胜过 "分隔符视觉同款"

因此本 DEC 显式 supersede DEC-024 决定 4 的 "分隔符一致" 论据；DEC-022 事件类 a 格式保持不变，**不** 引发连锁 Refines。

## 4. 迁移计划

### 4.1 单次原子替换

- **无版本开关**：不引入 `phase_matrix_format = line | table` 配置
- **无过渡期**：PR merge 后下一次 `/roundtable:workflow` transition 即用新格式
- 历史 TG 消息保留单行格式（不回溯修订）

### 4.2 落点清单

| 文件 | 改动 |
|------|------|
| `commands/workflow.md` | §Phase Matrix 定义段 `*Phase*: \`…\`` 描述改为伪表；§Step 5b 事件类表 b / d / e 格式列 "尾段随附 `*Phase*: \`…\``" → "尾段随附 11 行 code fence 伪表"；§Step 6 A/B/C 三类 re-emit 子句内 `*Phase*: \`…\`` 表述同步 |
| `docs/design-docs/phase-matrix-render-and-forward.md` | §2.3 D3 格式规范段替换单行进度条示例为伪表；§3.2 尾段描述同步 |
| `docs/design-docs/tg-forwarding-expansion.md` | §3.7 3 个 sample（b / d / e 尾段）替换 |
| `docs/decision-log.md` | DEC-027 Provisional 置顶；DEC-024 状态行追加 `Refined by DEC-027`（不降级 Accepted） |
| `docs/INDEX.md` | design-docs 新增本条目；决策索引段追加 DEC-027 行 |
| `docs/log.md` | design + decide 两条 entry |

**不改**：
- `skills/architect/SKILL.md` / `skills/analyst/SKILL.md`
- 4 agent prompt（developer / tester / reviewer / dba）
- DEC-006 phase gating taxonomy / DEC-013 §3.1a / DEC-018 / DEC-022（事件类 a 格式保留）/ DEC-024 决定 1/2/3/5/6/7/8
- Phase Matrix 9 stage 表结构 / 图例 / 终端全量表格渲染
- critical_modules / target CLAUDE.md

## 5. 代价与权衡

### 5.1 TG payload 放大

| 指标 | DEC-024 单行 | DEC-027 伪表 | 放大倍数 |
|------|-------------|-------------|----------|
| 每次 transition 快照行数 | 1 | 11 | 11× |
| 每次 transition 快照 codepoints | ≤120 | ~430 | ~3.6× |
| medium pipeline 5-7 次 transition 总快照行数 | 5-7 | 55-77 | 11× |

**用户决策**（issue #88 body）：接受此代价换 stage 名可见。

### 5.2 TG Bot API 上限

单条 reply 4096 char 上限：11 行伪表 ~430 chars，折入事件类 b（3 行 summary ~150 chars）/ d（1 行 handoff ~80 chars）/ e（1 行 audit ~60 chars）后总长 ≤600 chars，远低于上限。

### 5.3 节流

节流天然成立不变（DEC-024 决定 5）：Phase Matrix 状态仅在 phase transition 时变更；b / d / e 本就是 transition 事件；不新增 tick 源。

## 6. 测试策略

| 场景 | 期望 |
|------|------|
| TG-driven + architect 完成 Stage 3 | TG 收到事件类 b 3 行 summary + 独立 code fence 11 行伪表 |
| TG-driven + C 类 handoff（Stage 5 → 6） | TG 收到事件类 d 1 行 `🔄 X → Y` + 独立 fence 11 行伪表 |
| TG-driven + auto_mode B 类 auto-accept | TG 收到事件类 e 1 行 `🟢 auto-accept` + 独立 fence 11 行伪表 |
| TG-driven + Step 1 规模 auto-pick | 不附带伪表（非 phase transition，DEC-024 决定 7） |
| `<decision-needed>` 块 / Q&A 循环 / FAQ sink | 不附带伪表（状态无变更） |
| 终端 session | 9 行全量表格渲染不变（§Phase Matrix 原语） |
| 列宽 byte-exact 验证 | 9 行数据行每行 Stage 列 21 chars / Role 列 11 chars / Status 列 7 chars |

## 7. 变更记录

- 2026-04-22 初版（issue #88，DEC-027 Provisional）
