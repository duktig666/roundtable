---
slug: step7-relay-contract-tightening
source: docs/design-docs/step7-relay-contract-tightening.md
created: 2026-04-21
reviewer: subagent (orchestrator relay; DEC-017 §Step 7 / DEC-019)
critical_modules_hit:
  - commands/workflow.md §Step 7 Relay contract（hot-path）
  - DEC-006 phase gating 落盘契约（DEC-019 Refines DEC-017 Refines DEC-006）
verdict: Approve (0 Critical / 1 Warning non-blocking / 2 Suggestion follow-up)
---

# Review: issue #65 DEC-019 Step 7 relay 契约收紧

## Critical

无。

## Warning

- `commands/workflow.md §Step 7 触发条件 bullet 2` — Critical finding 识别规则里"`## Critical` section 非空（至少一条 bullet，排除纯 `无。` / `(无)` / `(空)` 占位）" 未定义**代码块内** Critical 如何处理；若 reviewer 产出 `## Critical\n\`\`\`\n- 纯示例 bullet\n\`\`\`` 代码块包裹一条示例 bullet，orchestrator 是否算"非空"？建议后续 follow-up 补一句"代码块/引用块内的 bullet 不计入非空判定"。非阻塞本 PR。

## Suggestion

- `docs/design-docs/step7-relay-contract-tightening.md` §W2 用户归档白名单 —— 白名单里未列 `sink`、`落盘` 的中文语境分别；实际 `sink` 属英文动词、`落盘` 属中文术语。建议把 "zh `归档` / `落盘` / `sink`" 整理为 "zh `归档` / `落盘`；en `archive` / `sink`"（与 workflow.md 内 bullet 措辞同步）。属微调，可在 follow-up。当前 workflow.md 内写法"zh `归档` / `落盘` / `sink`；en `archive`"把 `sink` 归中文亦能工作（OR 语义下白名单集合不变）。
- `docs/decision-log.md` DEC-019 §影响范围 —— "不改 agent prompt 本体" 与 issue #65 主诉一致；但若未来 tester prompt §输出落盘段仍引用 "Step 7 Relay contract" 而本 DEC 改了触发条件，tester prompt 的引用是否要同步加注 DEC-019？建议 follow-up 扫一次 `agents/{reviewer,tester,dba}.md` §输出落盘 确认引用锚点仍有效（本次 scope 内 grep 确认 3 agent 引用 `commands/workflow.md §Step 7` 作为权威，不引 DEC 号 → 无需改）。

## 决策一致性

DEC-019 决定 1-6 逐条验证：

| 决定 | 落地位置 | 一致性 |
|---|---|---|
| D1 W1 frontmatter 剥离 | `commands/workflow.md` Relay contract bullet 1 | ✅ 追加 "若正文以 `---\n` 开头且含闭合 `\n---\n` frontmatter block，先剥离后作 body" |
| D2 W2 Critical finding 识别 | `commands/workflow.md` 触发条件 bullet 2 | ✅ `## Critical` 非空 OR `🔴`+`critical` 词；排除占位与散文引用 |
| D3 W2 归档白名单 | `commands/workflow.md` 触发条件 bullet 3 | ✅ zh/en 白名单 + 用户 prompt 正文限定 + subagent 自述不触发明禁 |
| D4 W3 tester 布尔优先级 | `commands/workflow.md` 触发条件 bullet 4 | ✅ `critical_modules 命中 OR (size ∈ {medium, large} AND 需产出测试计划)` |
| D5 Refines DEC-017 非 Supersede | `docs/decision-log.md` DEC-017 状态行未改；DEC-019 状态 Accepted；相关文档段显式 "Refines DEC-017" | ✅ |
| D6 不改 agent prompt / log_entries prefix / 失败 UX / Phase Matrix / critical_modules 机制 | grep 确认 3 agent prompt 本体无改动；workflow.md 仅 §Step 7 一节动 | ✅ |

## 与 DEC-006 / DEC-017 关系复议

- **DEC-006 §A/B/C 三分类**：未改
- **DEC-006 §critical_modules 机械触发归 C**：未改（DEC-019 仅收紧触发条件字面匹配规则，不变判定类别）
- **DEC-017 D1 契约反转**：未改（subagent 不 Write 归档 .md 仍有效）
- **DEC-017 D2 触发条件（critical_modules OR Critical finding OR 用户归档）**：本 DEC 对 Critical finding / 用户归档 加白名单；tester 独有 size 条件补 OR 括号显式
- **DEC-017 D6 orchestrator 自造 `created:` / `log_entries:`**：未改；frontmatter 剥离规则只影响 body 拼接，不影响 orchestrator 自造字段

结论：**Refines 纪律保持正确**，DEC-017 / DEC-006 状态行均不动。

## 总结

**可合并**（Approve with 1 Warning 非阻塞 + 2 Suggestion follow-up）。

- W1/W2/W3 三项 findings 全部落地，触发条件与 Relay contract 措辞闭合
- diff ≤ 20 行，scope 严格限 `commands/workflow.md §Step 7`
- decision-log append-only 纪律保持（DEC-017 / DEC-006 状态行不动，DEC-019 置顶）
- INDEX.md / exec-plan / design-doc 三项产出同步
- 与并行 lane（#66 relay 失败 UX / #67 dba prefix 分离 / #68 dispatch 绝对路径）互不冲突职责

**本 agent 本次派发未调用 Write 工具**（reviewer 契约反转后按 DEC-017 主路径；本 review 报告作为 final message 返回，orchestrator 按 Step 7 Relay contract 代写本 path）。
