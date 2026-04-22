---
slug: phase-matrix-render-and-forward
source: 原创（issue #79）
created: 2026-04-22
status: Accepted
decisions: [DEC-024 Phase Matrix 渲染 locus + 转发绑定, DEC-027 Phase Matrix TG 快照格式（Refines DEC-024 决定 4）]
---

# Phase Matrix 渲染 locus 明确化 + TG 转发补齐 设计文档

## 1. 背景与目标

### 1.1 背景

2026-04-21 Level 2 E2E dogfood（issue #61 / PR #78）观察：

1. **渲染 drift**：`commands/workflow.md §Phase Matrix L18` 明文要求 "在整个派发生命周期维护本 matrix；每次 phase 切换或用户询问进度时重新报告"；§起点 L533 复述 "每次 phase transition 更新 matrix 并报告"。然而 execution 层 architect 子 agent 在 Stage 1 init / phase 切换时均**未**在输出流 emit 矩阵。§Step 6 只写 "初始化 Phase Matrix（全部 ⏳）"，未把 "re-emit on transition" 明确绑定到 A/B/C phase gating 分类，渲染义务悬空。

2. **TG forwarding 缺失**：`§Step 5b` 事件类表 a-e 不含 Phase Matrix 状态变更。TG-driven session 下即便 orchestrator 终端渲染 matrix，TG 用户也收不到 —— 宏观进度视图缺失。用户 2026-04-21 TG msg 599 明确提出 "注意 tg 是不是也要回复 Phase Matrix"。

### 1.2 目标

- 明确 Phase Matrix **渲染 locus = orchestrator**（与 `tg-forwarding-expansion.md §D1` orchestrator-only 落点一致）
- 把 "re-emit on transition" 义务**绑定到 §Step 6 A/B/C 三类 phase gating**，使 execution 无法漂移
- TG channel 下每次 phase transition 随既有事件类 b/d/e 同块携带 matrix 快照片段（**不新增事件类 f**）
- 零 agent / skill prompt 改动
- 节流天然成立（Phase Matrix 状态仅在 phase transition 时变更，本就无 "tick" 概念）

### 1.3 非目标

- 不改 Phase Matrix 表结构 / 图例 / 9 阶段划分
- 不新增 §Step 5b 事件类（避免表面扩张）
- 不抬 target CLAUDE.md
- 不改 DEC-006 phase gating taxonomy（A/B/C 三类语义）/ DEC-013 §3.1a / DEC-022 事件类 a 格式
- 不动 4 agent prompt / 2 skill prompt

## 2. 关键决策

### 2.1 D1：Path 1 渲染 locus —— orchestrator vs subagent vs both

**选择**：**orchestrator**（★ 推荐）

**备选**：

| 方案 | 描述 | 评分 |
|------|------|------|
| **A. orchestrator ★** | §Step 6 三类 gating 统一绑定 re-emit；0 subagent 改动 | **47** |
| B. subagent | 每个 subagent prompt 加 "phase transition 时 emit matrix" | 28 |
| C. both | orchestrator 主路径 + subagent 兜底 | 32 |

量化评分（0-10）：

| 维度 | A ★ | B | C |
|------|-----|---|---|
| 改动最小 | 10 | 3 | 2 |
| 职责单一 | 10 | 5 | 4 |
| 一致性（tg-forwarding-expansion §D1 先例）| 10 | 5 | 7 |
| critical_modules 触及面 | 9 | 5 | 4 |
| 可测试性 | 8 | 5 | 5 |
| **合计** | **47** | **23** | **22** |

**理由**：
1. **一致性**：`tg-forwarding-expansion.md §D1` 把 5 类事件（context / producer-pause / role digest / C handoff / auto audit）落点 orchestrator-only 评分 46 vs 33 胜出；Phase Matrix re-emit 是同类 orchestrator-emitted 宏观事件，自然沿用同一模式
2. **DEC-013 决定 8 边界**：展现与接收解耦 —— orchestrator 内部状态（Phase Matrix 就是编排状态镜像）由 orchestrator 自己输出；不下放 subagent
3. **issue 作者偏好**：issue body "是 orchestrator 职责，不是 subagent"
4. **零 subagent prompt 改动**：sticky prompt economy（DEC-022 / DEC-013 / tg-forwarding-expansion 共同纪律）
5. **可观察性**：orchestrator 单点渲染便于后续审计 / test；subagent 分散渲染会出现 multi-source race（subagent 版本漂移风险）

### 2.2 D2：Path 2 TG 转发形态 —— 新事件类 f vs 折叠进 b/d/e

**选择**：**折叠进既有事件类 b/d/e**（★ 推荐，不新增 f）

**备选**：

| 方案 | 描述 | 评分 |
|------|------|------|
| **A. 折叠 b/d/e ★** | Phase Matrix 快照作为 b/d/e reply 的尾段 bullet，不新增事件类 | **44** |
| B. 新 f = 全量快照 / 每次 transition 独立 reply | 独立事件类；每 phase transition 单独发 matrix | 28 |
| C. 新 f = delta-only（`stage N: 🔄→✅`）| 独立事件类；仅发状态差分 | 22 |
| D. 全部拒 Path 2 | 只改 Path 1 渲染，TG 仍无宏观进度视图 | 25 |

量化评分（0-10）：

| 维度 | A ★ | B | C | D |
|------|-----|---|---|---|
| TG 可见性覆盖 | 9 | 10 | 7 | 3 |
| 表面最小 / 不扩 §Step 5b 事件类 | 10 | 4 | 4 | 10 |
| 与事件类 d 重叠风险 | 10 | 3 | 4 | 10 |
| TG 刷屏压力 | 9 | 4 | 7 | 10 |
| 实现复杂度 | 8 | 6 | 6 | 10 |
| **合计** | **46** | **27** | **28** | **43** |

**理由**：
1. **事件类 d 已覆盖 C 类 phase transition**：格式 `🔄 X 完成 → dispatching Y` —— 已是 phase transition 事件；再加独立 f = 冗余
2. **事件类 b 已覆盖 A 类 producer-pause（Stage 2/3/9）**：每次 A 类 pause 正是 phase 切换点；可在 b 尾段追加 matrix 快照
3. **事件类 e 已覆盖 auto_mode 决策审计**：`auto-accept` / `auto-go` 也隐含 phase 切换；同样可尾段追加
4. **节流天然成立**：Phase Matrix 状态仅在 transition 时变更，b/d/e 本就是 transition 事件 → 一一对应，无 "tick" 刷屏风险
5. **DEC-022 + tg-forwarding-expansion 纪律**：删 "事件类 a 唯一围栏特例" 割裂同款精神；此处同样 "不因单点需求开新事件类"
6. **向下兼容**：b/d/e 既有格式（markdownv2 结构化）天然支持尾段 bullet 追加，无 parser / 格式破坏

### 2.3 D3：Matrix 快照形态 —— 全量 9 行 vs 当前 stage line vs 精简进度条

**选择**：**11 行 ASCII 伪表**（DEC-027 Refines DEC-024 决定 4；原单行进度条 2026-04-22 TG dogfood 用户反馈 stage 名不可见不可接受）

格式（code fence，无语言标签，零转义）：

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

- 列内容宽度 byte-exact：Stage 19 / Role 9 / Status 6（含 emoji 对齐 padding；emoji 视觉宽 2 的取舍，详见 `phase-matrix-tg-pseudo-table.md §2.2`）
- Stage / Role 字面固定：orchestrator 只替换 Status emoji
- 图例复用：⏳ 待办 / 🔄 进行中 / ✅ 完成 / ⏩ skipped / — 不适用（图例不随快照附带）

**理由**：
1. **stage 名可见**：TG 用户不再需心算 "5 是什么"；issue #88 用户直选方案 A
2. **全量 vs delta 权衡**：全量快照对 "刚加入 TG 订阅的用户" 友好（无历史包袱就能知宏观）；delta 需用户维护自己的状态机，UX 差
3. **与事件类 d 重叠度再降**：d 是 "X → Y" role 交接；此处是 "9 stage 全局状态" —— 信息维度不同
4. **代价**：每次 transition 快照 payload ~430 codepoints（vs 单行 ≤120），medium pipeline 5-7 次 transition 总 payload ~3-4k chars，远低于 TG Bot API 4096 char 单 reply 上限（事件类 b/d/e 本体 + 伪表可共单 reply 或拆独立 fence block 按现行 reply 结构）
5. **DEC-022 分隔符和谐 supersede**：DEC-024 原理由 "与 DEC-022 事件类 a `·` 分隔符一致" 被本 refinement supersede —— 两者 UX 语境不同（a 是 in-stream 短字段；matrix 是宏观视图），readability priority 胜出；DEC-022 事件类 a 格式保持不变

### 2.4 D4：§Step 6 绑定点 —— 三 gating 统一 vs 仅 A 类

**选择**：**A/B/C 三类统一绑定**（自明采纳）

- **A 类 producer-pause**（Stage 2/3/9）：orchestrator emit 3 行 summary 前后，Phase Matrix 状态已从 `🔄 → ✅`（当前 stage）、可能下一 stage `⏳ → 🔄`；re-emit matrix 一行置于 3 行 summary 之后、"请阅读后告诉我" 之前
- **B 类 approval-gate**（Stage 4）：AskUserQuestion 弹窗前，Stage 3 从 `🔄 → ✅`、Stage 4 从 `⏳ → 🔄`；re-emit matrix 一行置于 AskUserQuestion emit 之前
- **C 类 verification-chain**（Stage 1/5-8）：C 类事件类 d 一行 `🔄 X 完成 → dispatching Y` 之后紧贴一行 matrix

**理由**：三类 gating 语义一致 —— 都是 phase 切换点；不做特例 minimize 规则复杂度。

## 3. 技术实现

### 3.1 §Step 6 Re-emit 绑定规则

`commands/workflow.md §Step 6` 三类 gating 各自追加一句 "Phase Matrix re-emit" 义务子句（明确 orchestrator 责任、不下放 subagent）。

### 3.2 §Step 5b 事件类 b / d / e 尾段 Matrix 快照

`commands/workflow.md §Step 5b` 事件类表 b / d / e 格式列追加注："尾段随附 11 行 ASCII 伪表 Matrix 快照（独立 code fence，无语言标签，列宽 Stage 19 / Role 9 / Status 6 byte-exact）"（DEC-027 Refines DEC-024 决定 4；原单行进度条因 stage 名不可见被 refine）。

不新增事件类 f。不改事件类 a / b-9 / c。

### 3.3 落点清单

| 文件 | 改动 |
|------|------|
| `commands/workflow.md` | §Step 6 三类 gating 追加 re-emit 子句（~3 行）；§Step 5b 事件类表 b / d / e 格式列追加尾段注 + 起点 L533 追加 locus 明示（~4 行） |
| `docs/design-docs/phase-matrix-render-and-forward.md` | 新建本文件 |
| `docs/design-docs/tg-forwarding-expansion.md` | §3.1 forwarding 规则段 + 新 §3.7 记录 DEC-024 绑定；frontmatter `decisions:` 追加 DEC-024 |
| `docs/decision-log.md` | DEC-024 置顶 |
| `docs/INDEX.md` | design-docs 新增 phase-matrix-render-and-forward 条目 + tg-forwarding-expansion §3.7 追注 |
| `docs/log.md` | Step 8 flush by orchestrator |

**不改**：
- `skills/architect/SKILL.md` / `skills/analyst/SKILL.md`
- 4 agent prompt（developer / tester / reviewer / dba）
- DEC-006 / DEC-013 / DEC-018 / DEC-022 任何 Accepted 决定
- Phase Matrix 9 stage 表结构 / 图例
- target CLAUDE.md 业务规则边界

### 3.4 与现有转发规则关系

| 事件 | 规则归属 | 触发点 | 本 DEC 绑定 |
|------|---------|--------|-----------|
| `<decision-needed>` block | DEC-013 §3.1a（DEC-018 松弛） | Step 5 Escalation / skill in-phase 决策 | 无变化 |
| 事件类 a（context / size） | DEC-013 §3.1a 扩展（DEC-022 markdownv2 hybrid） | Step 0 / Step 1 | 无变化（非 phase transition）|
| 事件类 b（A 类 producer-pause） | tg-forwarding-expansion §3.1 | Step 6.1 A 类 | **尾段追加 matrix 一行** |
| 事件类 b-9（Stage 9 closeout bundle） | 同上 | Stage 9 变体 | 无变化（长文本拆包独立，matrix 由 b 路径 emit）|
| 事件类 c（role completion digest） | 同上 | subagent final message 解析 | 无变化（非 phase transition，是 role 返回）|
| 事件类 d（C 类 handoff） | 同上 | Step 6.1 C 类 | **尾段追加 matrix 一行** |
| 事件类 e（auto_mode audit） | 同上 | §Auto-pick 触发点 | **尾段追加 matrix 一行**（仅 `auto-accept` / `auto-go` 伴 phase 切换；`auto-pick` 单独决策点不伴 phase 切换则不追加）|

**与事件类 d 重叠**：d 是 "X role → Y role" 交接单行；matrix 是 "9 stage 全局状态" 单行；信息维度不同 —— d 局部 + matrix 全局。TG 用户同时看到 "哪两个 role 在交接" + "整体跑到哪" 两个互补视角。

### 3.5 节流 / 刷屏防御

**天然节流**：Phase Matrix 状态仅在 phase transition 时变更；b / d / e 本就是 phase transition 事件 → 状态变更与转发一一对应，无额外 tick 源。最坏情况：medium 任务 pipeline `architect → design-confirm → developer → tester → reviewer` 约 5-7 次 transition → 5-7 条 matrix 快照（含在 b/d/e payload 尾段，不额外 reply），远低于 TG Bot API 速率限制。

**不转发**：
- Stage 内 in-phase 决策 / Q&A 循环 / FAQ sink（状态无变更）
- 事件类 a / c / b-9（非 phase transition 或长文本拆包独立）
- 事件类 e 中非伴 phase 切换的 `auto-pick`（如 Step 1 规模判定 auto-pick —— 属于 Step 1 内部决策而非 transition）

### 3.6 渲染伪码（orchestrator 视角）

```
on_phase_transition(from_stage, to_stage):
    matrix[from_stage] = ✅
    matrix[to_stage] = 🔄
    emit_to_terminal(render_matrix())      # 终端始终 emit（§Phase Matrix 原语）
    if channel_sticky:
        base_reply = build_b_or_d_or_e_event(from_stage, to_stage)
        full_reply = base_reply + "\n" + render_matrix_pseudo_table()  # DEC-027: 11 行 ASCII 伪表
        channel.reply(full_reply)
```

终端 matrix 保持 9 行全量表格渲染不变（`§Phase Matrix` 语义）；TG 走 11 行 ASCII 伪表（D3；DEC-027 Refines DEC-024 决定 4）。

## 4. 影响文件清单

新建：
- `docs/design-docs/phase-matrix-render-and-forward.md`（本文件）

修改：
- `commands/workflow.md`（+~7 行：§Step 6 A/B/C 三类 re-emit 子句 + §Step 5b 事件类 b/d/e 尾段注 + §起点 L533 locus 明示）
- `docs/design-docs/tg-forwarding-expansion.md`（frontmatter + §3.1 forwarding 段追加一行 + 新 §3.7 记录 DEC-024 + §6 变更记录）
- `docs/decision-log.md`（DEC-024 置顶）
- `docs/INDEX.md`（design-docs 新增 + tg-forwarding-expansion §3.7 追注）
- `docs/log.md`（Step 8 flush by orchestrator）

**不改**：skills/* / agents/* / CLAUDE.md / DEC-006 / DEC-013 / DEC-018 / DEC-022 任何 Accepted 决定 / Phase Matrix 9 stage 表结构 / critical_modules 机械触发 / Option Schema / Progress Event schema。

## 5. 测试策略

按 issue #79 验收 + 回归：

| 场景 | 期望 |
|------|------|
| TG-driven + architect 完成 Stage 3 | TG 收到 b 类 producer-pause 3 行 summary 末尾紧贴 11 行 ASCII 伪表 Matrix 快照 |
| TG-driven + C 类 handoff（如 Stage 5 → Stage 6 / critical_modules 触发 tester）| TG 收到 d 类 `🔄 X 完成 → dispatching Y` 末尾紧贴 matrix 快照 |
| TG-driven + auto_mode=on + B 类 Stage 4 auto-accept | TG 收到 e 类 `🟢 auto-accept` 末尾紧贴 matrix 快照 |
| TG-driven + Step 1 规模 auto-pick（非 phase transition）| 不追加 matrix（不伴 phase 切换）|
| 终端始终渲染 9 行全量表格 | `§Phase Matrix` 语义保持不变 |
| 纯终端 session（无 channel tag）| TG reply 不触发；终端 matrix 渲染同现状 |
| medium pipeline 5-7 次 transition | TG 收到 5-7 条含 matrix 尾段的 b/d/e reply；无额外 reply |
| `<decision-needed>` 块（§3.1a） | 行为不变；不追加 matrix（in-phase 决策非 phase transition）|
| Q&A 循环 / FAQ sink | 不追加 matrix（状态无变更）|

### 5.1 critical_modules 命中

- `commands/workflow.md §Phase Matrix + §Step 6 phase gating taxonomy (DEC-006) + §Step 5b event class b/d/e` —— Phase Matrix + phase gating + event forwarding 三命中

→ **tester 必触发**；reviewer 亦宜加（critical_modules prompt 本体改动）。

## 6. 变更记录

- 2026-04-22 初版（issue #79，DEC-024 Accepted）
- 2026-04-22 §2.3 D3 格式段 + §3.2 尾段描述从单行进度条更新为 11 行 ASCII 伪表（issue #88，DEC-027 Provisional Refines DEC-024 决定 4；主设计文档见 `phase-matrix-tg-pseudo-table.md`）

## 7. 待确认项

无阻塞项；AUTO mode 下两决策均 auto-pick recommended。
