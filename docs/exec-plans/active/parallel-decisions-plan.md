---
slug: parallel-decisions
source: design-docs/parallel-decisions.md
created: 2026-04-21
status: Active
---

# Orchestrator Decision Parallelism 执行计划

## 总览

| Phase | 标题 | 预估 | 前置 | 关键风险 |
|-------|------|------|------|----------|
| P0 | commands/workflow.md §Step 4b 新增 | 15 行 | DEC-016 | critical_modules 命中，必过 lint+tester+reviewer |
| P1 | Step 1 / 3.4 / 6b 三点 ref 注记 | 3×1 行 | P0 | 心智引导准确性 |
| P2 | Step 6 §Auto-pick 表扩 batch 行 | 2 行 | P0 | auto_mode 审计一致 |
| P3 | Step 5b 事件类 e 批量围栏注记 | 1 行 | P0 | TG 转发格式规范 |

## P0 §Step 4b 新增

### 目标
在 `commands/workflow.md` 的 Step 4（Task 并行判定树）之后、Step 5（Subagent Escalation）之前，新增 `## Step 4b: Decision Parallelism Judgment` 章节。

### 任务清单
- [x] 定位 Step 4 末尾（`**Exec-plan checkbox 写入保持串行**...` 行之后）
- [x] 新增 §Step 4b 节，正文：
  - 引言 2 句：适用范围 = orchestrator 顶层 fuzzy 决策（Size / Dispatch mode / Developer form 三点），不含 architect skill 内单问 / escalation
  - 4 条件表（INPUT INDEPENDENT / OPTION SPACE DISJOINT / RESPONSE PARSABLE SEPARATELY / NO HIDDEN ORDER LOCK）
  - 默认串行 + 全 4 条件满足且同轮待决 ≥2 才升并行
  - `max_concurrent_decisions = 3` 硬编码常量声明
  - 失败处理一句：Per-decision 降级重问（ref design-doc §3.2）
  - text mode 批量形态一句：多 `<decision-needed>` 块同 response emit（ref §3.4）

### 成功信号
- Grep `Step 4b` 在 `commands/workflow.md` 恰好 1 次定义 + 3 处 ref（Step 1/3.4/6b）
- Lint 扫描（CLAUDE.md 硬编码项目名）0 命中
- design-doc §3.1 与 workflow.md §Step 4b 内容一致（4 条件字面相同）

### 风险与预案
- **风险**: §Step 4b 与 Step 4 概念混淆 → **预案**: 引言显式声明"Step 4 = Task 派发 / Step 4b = 决策"
- **风险**: max_concurrent_decisions=3 硬编码，未来改动需改 prompt → **预案**: DEC-016 明示"先保守，需要时改到 4 或 5"

## P1 三点 ref 注记

### 目标
Step 1 size 判定 / Step 3.4 dispatch mode 模糊兜底 / Step 6b per-dispatch form 三处各加一行 ref：

```
同轮待决 ≥2 fuzzy 决策时走 §Step 4b 判定是否批量 AskUserQuestion。
```

### 任务清单
- [x] Step 1 规模模糊兜底 `AskUserQuestion medium/large 两选项` 行后补 ref
- [x] Step 3.4 步骤 3 模糊兜底 `AskUserQuestion fg/bg` 行后补 ref
- [x] Step 6b 步骤 3 per-dispatch `AskUserQuestion` 行后补 ref

### 成功信号
3 处 grep 到相同 ref 句式。

## P2 §Auto-pick 表扩 batch 行

### 目标
Step 6.9 §Auto-pick 通用规则表加一行 batch 语义：

| 触发点 | 事件 | 条件 |
|--------|------|------|
| **§Step 4b 批量 orchestrator 决策** | `🟢 auto-pick batch <batch_id>: [<q1_label>, <q2_label>, ...]` | 所有 question 全部含 `recommended: true` |

任一 question 缺 recommended → 沿用现有"缺 recommended → auto-halt"条款，整组降级。

### 成功信号
表中新增行 render 正确；rationale 一句明示"全或全无"。

## P3 §Step 5b 事件类 e 批量围栏注记

### 目标
Step 5b 事件类 e 描述补一句："batch auto-pick 事件合并单 ``` 围栏；非 batch 单事件仍 markdownv2 粗体"（明确 DEC-016 §3.3 行为）。

### 成功信号
§5b 事件类 e 行补注记；与 Step 6.9 §Auto-pick 表 batch 行 cross-ref 自洽。

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-04-21 | 初稿 Active | DEC-016 落盘后 |
