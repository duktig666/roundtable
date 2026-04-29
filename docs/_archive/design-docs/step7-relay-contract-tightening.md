---
slug: step7-relay-contract-tightening
source: issue #65
created: 2026-04-21
author: architect (roundtable dogfood lane A)
status: Accepted
refines: DEC-017
---

# Step 7 Relay Write contract 收紧（W1/W2/W3）

## 上下文

[issue #65](https://github.com/duktig666/roundtable/issues/65) —— DEC-017 落地后，`commands/workflow.md §Step 7 Orchestrator Relay Write 主路径` 遗留 3 处契约模糊：

- **W1** frontmatter 剥离规则缺失（tester A2 / reviewer Warning 1）
- **W2** Critical finding / 用户归档意图 trigger 缺白名单（tester A3+A4+A7 / reviewer Warning 2 相关）
- **W3** tester 触发条件布尔优先级歧义（tester A5 / reviewer Warning 2）

`#59` 合并时判为 non-blocking，本 DEC（DEC-019 Refines DEC-017）在下一次 relay 派发前闭环。

## 决定（逐 W 定稿）

### W1 frontmatter 剥离

**规则**：orchestrator relay 时，若 subagent final message body 以 `---\n` 开头并含闭合 `\n---\n` 的 frontmatter block，**剥离该 block 后再作为 artifact body**；orchestrator 自造的 frontmatter（`slug` / `source` / `created` / `reviewer|tester` 字段）为权威。

**落点**：`commands/workflow.md §Step 7 Relay contract` bullet 1（"Content 源"）末尾追加一句。

### W2 Critical finding + 归档意图 白名单

**Critical finding 识别规则**（满足任一即触发）：

1. `## Critical` section 非空（至少一条 bullet，不含纯 `无。` / `(无)` / `(空)`）
2. 正文出现 emoji `🔴` 且**同段或相邻段**包含单词 `critical`（大小写不敏感）

**不触发**：`## Critical` section 存在但为空（显式声明无 Critical）；自然语言散文引用 `critical`（无 `🔴` emoji 锚点且无 section 命中）。

**用户归档意图白名单**（OR）：

- 中文：`归档` / `落盘` / `sink`
- 英文：`archive`

**限定**：匹配源仅限 **用户派发 prompt 正文**；subagent 自述"应归档 / 建议归档 / 本次是关键改动"**不触发** relay（orchestrator 单边判定）。

**落点**：`commands/workflow.md §Step 7 触发条件` bullet 2 + bullet 3 展开为带括号注解的版本，并在段后追加 "subagent 自述不触发" 明禁。

### W3 tester 触发条件布尔优先级

**原文**（歧义）：`tester 中/大任务（critical_modules 命中 或 size=medium/large 且需产出测试计划）`

**定稿**：`critical_modules 命中 OR (size ∈ {medium, large} AND 需产出测试计划)`

语义 = tester 在 critical_modules 命中时**总是** relay（无论 size）；非 critical_modules 时仅在 medium/large 且有测试计划产出时 relay。

**落点**：`commands/workflow.md §Step 7 触发条件` bullet 4 改写为明确括号。

## 不改

- DEC-017 主路径反转决定本体（D1-D8）
- `agents/{reviewer,tester,dba}.md` 本体（本 DEC scope 严格限 workflow.md §Step 7）
- log_entries prefix 命名（dba vs reviewer 混用由 #67 处理）
- relay Write 失败 UX（由 #66 处理）
- critical_modules 机制 / Phase Matrix / architect/analyst/developer Write 路径

## 补丁概览（供 developer 参照）

`commands/workflow.md` §Step 7 预计改 3 段：

1. **触发条件** 4 bullet：bullet 2/3 加识别规则，bullet 4 加括号；段末追加"subagent 自述不触发"明禁
2. **Relay contract** bullet 1：追加 frontmatter 剥离规则
3. 其他 bullet 不动

预估 diff ≤ 20 行，含注释。

## decision-log 登记

DEC-019 Refines DEC-017；status: Accepted；不改 DEC-017 状态行。

## 风险

- 与 lane B（#66 relay 失败 UX）同改 §Step 7：本 DEC 只碰触发条件 + Relay contract bullet 1；#66 预计改 Relay contract 末尾新增失败分支 bullet。冲突面小但 merge 时 hunks 邻接，需人工对齐。
