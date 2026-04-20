---
slug: dispatch-mode-strategy
reviewer: roundtable:reviewer（subagent）+ orchestrator relay
date: 2026-04-20
status: Approve-with-caveats
decisions: [DEC-012]
---

# DEC-012 实施审查 —— dispatch-mode-strategy

> 本 review 由 reviewer subagent 审计并经 orchestrator 转写落盘。reviewer agent 自声明其 prompt 约束不允许 Write .md 报告（"Do NOT Write report/summary/findings/analysis .md files. Return findings directly as your final assistant message"），故 findings 以对话返回，orchestrator 按 critical_modules hit 纪律代写本归档。此约束与 `agents/reviewer.md` Resource Access 的 reviews/ Write 授权存在冲突，建议另开 issue 追踪（非本 review scope）。

## 审查范围

- `commands/workflow.md` 新增 §Step 3.4 Dispatch Mode Selection
- `commands/bugfix.md` Step 0.5 加 1 句 §3.4 引用
- `docs/decision-log.md` 追加 DEC-012 置顶（DEC-011 之前）
- `docs/design-docs/dispatch-mode-strategy.md` 新建
- `docs/INDEX.md` 追加 design-doc 条目

## 结论

**Approve-with-caveats** —— 0 Critical / 3 Warning / 2 Suggestion。

核心规则（D2+D4 两层 fallback）实装正确；§3.5.0 gate 串联无死角；DEC-012 6 段齐全；影响范围 ≤ 10 行满足 DEC-009 决定 10 纪律；置顶于 DEC-011 之前已 dogfood 本项目 DEC-011 约定；lint 0 命中；DEC-001~DEC-011 全对齐。

## Critical

（无）

## Warning

### W-01 · Section-number 不一致 贯穿 4 文档（高优先）

- `commands/workflow.md` —— 实装为 `## Step 3.4`
- `docs/design-docs/dispatch-mode-strategy.md` §3.1 / §3.2 / §3.4 / P8 —— 多处写 `§3.4.5`
- `docs/decision-log.md` DEC-012 决定 6 + 影响范围段 —— 写 `§3.4.5`
- `commands/bugfix.md` —— 对的（`§3.4`）

**影响**：design-doc 的"新增位置"规格和 DEC-012 决定 6 的"不触发本 DEC §3.4.5"成为悬空指针。

**修复**：统一为 `§3.4`（推荐方向；3 位小数编号观感臃肿；workflow.md 既有 Step 3.5.0 / 3.5.1 体系下 3.4 一致）。

### W-02 · design-doc §3.1 代码块与 workflow.md 实装文字不逐字一致

- design-doc L73 "Step 4 并行派发判定树已通过" vs workflow.md L95 "Step 4 并行判定树已判可升级"
- 措辞不同语义等价 —— 不强制逐字对称，但需配合 W-01 section 统一

### W-03 · Step 3.4 与 Step 4 并行判定树顺序描述偏弱

markdown 顺序是 Step 3.4 (L90) 先于 Step 4 (L162)，读者按序阅读撞到 Step 3.4 的 D2 规则会"Step 4 并行判定树已判可升级"反向回看。

**修复建议**：Step 3.4 开头加一句前置声明："**前置**：Step 4 并行判定树必须先于本 Step 执行；Step 4 的串/并行结论是 D2 的直接输入。"

## Suggestion

### S-01 · Per-session 声明等价列表可加 1-2 条

workflow.md L94 当前：`@roundtable:<role> bg` / `@roundtable:<role> fg` / "后台派 <role>" / "前台派 <role>" / "用后台跑 <role>"。

建议补：`<role> 用 bg` / `bg 跑 <role>` 等同构例子，让 LLM 模式匹配覆盖更全。非 blocker。

### S-02 · P8 验收可测性加 testing anchor

design-doc §5 给出 4 个验收场景是事后描述性，无自测步骤。参考 DEC-008 落地有专门 testing/ doc（`docs/testing/step35-foreground-skip-monitor.md`），建议 §5 补一行 "测试归档位置：`docs/testing/dispatch-mode-strategy.md`（按需 tester 兜底）"。非 blocker。

## 决策一致性

| DEC | 一致性 |
|-----|--------|
| DEC-001 D2（零 userConfig 边界） | ✅ |
| DEC-002（RA matrix） | ✅ |
| DEC-004（Progress schema） | ✅ |
| DEC-005（developer 双形态 + per-session 心智） | ✅ |
| DEC-006（phase gating taxonomy） | ✅ |
| DEC-007（Content Policy） | ✅ |
| DEC-008（前台免 Monitor gate 正交补齐） | ✅ |
| DEC-009 决定 10（影响范围 ≤10 行纪律） | ✅ |
| DEC-011（decision-log 置顶约定 + dogfood） | ✅ |

## 推荐动作

1. **必修**：W-01 section-number 统一（4 处 `§3.4.5` → `§3.4`）
2. **建议修**：W-03 Step 3.4 / Step 4 顺序前置声明
3. **可选**：S-01 @声明列表加 1-2 条；S-02 testing anchor

W-01 修完即可合并；W-03/S-01/S-02 不阻塞合并。
