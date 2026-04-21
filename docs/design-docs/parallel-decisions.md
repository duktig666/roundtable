---
slug: parallel-decisions
source: issue #28
created: 2026-04-21
status: Draft
decisions: [DEC-016]
description: orchestrator 无依赖决策批量化（Step 1 size / Step 3.4 dispatch mode / Step 6b developer form 合并为单次 multi-question AskUserQuestion），新增 §Step 4b Decision parallelism judgment。
---

# Orchestrator Decision Parallelism 设计文档

## 1. 背景与目标

### 1.1 问题

`commands/workflow.md` 当前 orchestrator 决策流程基本串行：Step 1 size → Step 3.4 dispatch mode → Step 6b developer form → architect 阶段 1 逐决策 →  Step 5 escalation 逐块 emit。

issue #28 指出：**相互独立**的决策点强制串行带来——

- 整体 latency 增加（每步等前步）
- Claude 同一消息并发工具调用能力未用
- #43 batch orchestrator（多 issue 并行编排）强依赖本前置

### 1.2 目标（D1=B 中等 scope）

允许 orchestrator 把 2+ **无依赖** fuzzy 决策合并为**单次** `AskUserQuestion({questions: [...]})` 调用。

### 1.3 非目标

- **不改** architect skill 阶段 1 单问单答（DEC-013 §3.1.1 `架构决策不批量` 保留）
- **不改** DEC-013 §3.1.1 `<decision-needed>` 多块串行 emit（text 模式）
- **不改** DEC-006 B 类 design-confirm approval-gate
- **不覆盖** subagent Task 并行派发（Step 4 已覆盖；本设计只补决策层）
- **不覆盖** 并行 subagent 同时返回 escalation 的批量 resolve（属 §3.1.1 supersede，scope 之外）

## 2. 业务逻辑

### 2.1 并行决策适用点

当前 orchestrator 串行决策 inventory：

| 决策点 | 所在 Step | 类型 | 可并行? |
|--------|----------|------|---------|
| Size judgment | Step 1 | orchestrator fuzzy | ✅ |
| Dispatch mode (fg/bg) | Step 3.4 | orchestrator fuzzy | ✅（模糊兜底走 AskUserQuestion 分支） |
| Developer form (inline/subagent) | Step 6b | per-dispatch AskUserQuestion | ✅ |
| Architect decisions (in skill Stage 1) | skills/architect | skill AskUserQuestion | ❌ 保留串行（DEC-013 §3.1.1） |
| Subagent escalation resolve | Step 5 | orchestrator → user | ❌ 保留串行（DEC-013 §3.1.1） |
| Design confirm (Stage 4) | Step 6 B 类 | approval-gate | ❌ 保留串行（DEC-006） |
| Phase-gate A 类 menu | Step 6 A 类 | producer-pause | ❌ 保留串行（菜单穷举 / Q&A 循环心智） |

**可并行合并的决策池**：Size / Dispatch mode / Developer form 三点。典型场景：size 判定 fuzzy + 多 Task 并行派发（#43 batch）触发 dispatch mode 决策 + 每个 Task 的 developer form per-dispatch 弹窗。

### 2.2 Multi-question AskUserQuestion

`AskUserQuestion` 工具原生支持 `questions: []` 数组。canonical 包装：

```javascript
AskUserQuestion({
  questions: [
    { header: "规模", question: "...", multiSelect: false, options: [...] },
    { header: "派发", question: "...", multiSelect: false, options: [...] },
    { header: "形态", question: "...", multiSelect: false, options: [...] }
  ]
})
```

每项遵循 DEC-013 Option Schema（description 打包 rationale + tradeoff + ★ recommended）。

## 3. 技术实现

### 3.1 §Step 4b Decision parallelism judgment（新增节）

位于 `commands/workflow.md` 的 Step 4 之后、Step 5 之前。

**四条件（决策语义版）**：

| 条件 | Task 版（Step 4） | 决策版（Step 4b） |
|------|------------------|------------------|
| 1 | PREREQ MET | **INPUT INDEPENDENT** — 决策 A 的输入不依赖决策 B 的答 |
| 2 | PATH DISJOINT | **OPTION SPACE DISJOINT** — 决策 A 的 option 集合与 B 不重叠语义（不是同一决策的拆问） |
| 3 | SUCCESS-SIGNAL INDEPENDENT | **RESPONSE PARSABLE SEPARATELY** — 用户回复能 per-question 解析（label 唯一不跨问歧义） |
| 4 | RESOURCE SAFE | **NO HIDDEN ORDER LOCK** — 没有"决策 A 答了才揭示 B 选项"的动态生成依赖 |

**默认串行。** 仅 4 条件**全满足且**同轮待决 ≥2 才升并行。

**上限**：`max_concurrent_decisions = 3`（硬编码常量；复用 DEC-003 `≤4 research fan-out` 心智减 1；人脑 working memory 经验值 3）。

### 3.2 Failure / Partial response 处理（D3=A Per-decision）

用户回复后 orchestrator per-question 解析：

- 每个 question 独立尝试 label 匹配（fuzzy：`A` / `选 A` / `go with size=medium`）
- 匹配成功 → 该 decision 记录生效
- 匹配失败 / 模糊 / 用户 cancel → 该 decision **单独降级重问**（emit 单 question AskUserQuestion 或 text `<decision-needed>`）
- **不回滚已答决策**（与 DEC-006 "用户自由文本驱动 / 不静默替决策" 一致）

### 3.3 Auto_mode 交互（D6 默认）

`auto_mode=true` 下批量决策 per-question 独立走 §Auto-pick：

- 每个 question 有 `recommended: true` → `🟢 auto-pick <context>` 审计行
- 多 question 全部 recommended → 合并一条 ``` 围栏批量 audit 转发（Step 5b 事件类 e）
- 任一 question 缺 recommended → 整组降级 halt（`🔴 auto-halt: no recommended option at <batch_id>/<q_header>`），所有 question 回退到 manual 路径（`decision_mode` 决定 modal / text）

**不允许部分 auto-pick**：混合策略会让 audit 难读；全或全无更清晰。

### 3.4 Text mode 批量形态（`decision_mode=text`）

text 模式下批量 decision 渲染为**多个 `<decision-needed>` 块**同时 emit（同一 orchestrator response），每块独立 id：

```
<decision-needed id="batch-<slug>-1">
question: 规模？
options: ...
</decision-needed>

<decision-needed id="batch-<slug>-2">
question: 派发？
options: ...
</decision-needed>

<decision-needed id="batch-<slug>-3">
question: 形态？
options: ...
</decision-needed>
```

orchestrator 等用户一次回复含 3 个答（`1=B 2=A 3=inline` 或自由文本）。DEC-013 §3.1.1 "多块串行 emit" 在**单决策 escalation** 语境保留；batch-decision 是新增 parallel 语义，正交补齐。

**§3.1a Active channel forwarding 适用**：batch 块同步 TG reply；每块独立字节等价（动机是 **per-block 字节等价可独立 parse + 与 §3.1a sticky 语义一致**，非减限流 —— 独立 N reply 反而比合并单 payload 更可能触发 per-chat ~1msg/s 软限）。若任一 block reply 失败 → 走标准 reply retry / fallback，不新增 batch 专属路径。TG channel 的"合并多块体单 reply"形态可作 follow-up issue（非本 DEC scope）。

### 3.5 不影响的部分

- Step 4 Task 并行判定树**本体不动**（只加 §Step 4b 新章节）
- DEC-013 §3.1.1 multi-escalation serial emit **保留**（subagent escalation 是 blocking signal，cognitive load 天然不该批量）
- architect skill 阶段 1 单问（DEC-013 `架构决策不批量`）**保留**（架构决策跨问有隐含依赖，OPTION SPACE DISJOINT 常违反）
- DEC-006 A 类菜单 / B 类 directional lock **保留**

## 4. 关键决策与权衡

### 4.1 D1 Scope 评分

| 维度 (0-10) | A 窄 | B 中 ★ | C 宽 |
|------------|------|--------|------|
| 覆盖场景 | 4 | **7** | 9 |
| 实现成本 | 8 | **7** | 3 |
| UX 风险 | 9 | **8** | 4 |
| DEC 冲突 | 10 | **9** | 3（Supersede §3.1.1） |
| #43 解锁 | 5 | **8** | 9 |
| **合计** | 36 | **39** | 28 |

B 胜在"覆盖常态 single-issue 场景"（A 只解 batch）+ 零现存 DEC Supersede（C 要改 §3.1.1）。

### 4.2 D2 Judgment tree 评分

| 维度 (0-10) | A 新 §Step 4b ★ | B 扩 Step 4 | C 启发 |
|------------|----------------|-------------|--------|
| 清晰度 | **9** | 6 | 3 |
| critical_modules 可 audit | **9** | 7 | 2 |
| 体量 | 7 | 8 | **10** |
| 未来扩展 | **9** | 6 | 4 |
| **合计** | **34** | 27 | 19 |

A 胜在语义分离清晰 + critical_modules 命中 commands/workflow.md 规则 audit 有形式化依据。

### 4.3 D3 Failure 评分

| 维度 (0-10) | A Per-decision ★ | B All-or-nothing | C Fail-fast |
|------------|------------------|-------------------|-------------|
| 用户体验 | **9** | 4 | 3 |
| 实现复杂度 | 7 | **9** | 8 |
| 与 DEC-006 一致 | **9** | 5 | 4 |
| auto_mode 兼容 | **9** | 6 | 3 |
| **合计** | **34** | 24 | 18 |

A 胜在 UX + 与现有心智一致；per-question 解析额外成本小。

## 5. 讨论 FAQ

### Q1: 为什么 max_concurrent_decisions = 3 而不是 DEC-003 的 4？

研究任务是 subagent 做，用户只看结果；决策是用户**当场**要读完选 —— working memory 上限更低。3 个决策每个 2-4 options 已经 6-12 选项，接近人类短时记忆上限。需要时可后续调到 4 或 5，先保守。

### Q2: 为什么不 Supersede DEC-013 §3.1.1 一起做激进化？

§3.1.1 有两种情景：
- (a) architect skill 同一 phase 内多决策串行 emit — 决策间有隐含 dependency（设计 A 定了才能问 B），**天然不该批量**
- (b) 多 subagent 并行返回 escalation — 都是 blocking signal，用户要读完 context 才能判断，批量 cognitive load 过高

本 DEC 的 scope 是 **orchestrator 顶层无依赖 fuzzy 决策**（Size / Dispatch mode / Developer form），本质不同于 (a) (b)。并存不冲突。

### Q3: 如果用户在 batch 里只答了 1/3，其他 2 个 cancel，auto_mode=true 下行为？

按 §3.3：auto_mode 下若 batch 生成时任一 question 缺 recommended → 整组 halt；但**用户 runtime 取消**不受 auto_mode 控制（auto 只决定 generate 阶段，不拦 user input 阶段）。user cancel 的 2 个走 D3=A per-decision 单独重问路径，已答的 1 个保留。

### Q4: §Step 4b 条件 4 "NO HIDDEN ORDER LOCK" 具体指什么？

例：architect 问 "存储选 SQL / NoSQL" 后 → 若选 SQL 再问 "SQLite / Postgres"。这种"B 的 option 取决于 A 的答"有隐含 order lock，**不可**批量。Orchestrator 识别方法：检查 question generation 是否依赖前一答（`if prev_answer == X then questions.push(...)`）。本设计覆盖的 Size / Dispatch mode / Developer form 三点天然无此依赖。

## 6. 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-04-21 | 初稿 Draft | issue #28 分析 + 3 决策点闭合 |

## 7. 待确认项

无。阶段 1 闭合，进入阶段 2 落盘 + 阶段 3 exec-plan 决定。
