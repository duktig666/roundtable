---
slug: step7-relay-contract-tightening
source: design-docs/step7-relay-contract-tightening.md
created: 2026-04-21
completed: 2026-04-21
status: Completed
---

# step7-relay-contract-tightening 执行计划

## 总览

| Phase | 标题 | 预估 | 前置 | 关键风险 |
|-------|------|------|------|---------|
| P0 | architect 定稿 DEC-019 收紧规则 | 10min | issue #65 / DEC-017 tester+reviewer findings | W1-W3 规则文本失准 |
| P1 | developer 改 `commands/workflow.md §Step 7` | 10min | P0 | 与 lane B（#66）hunk 邻接冲突 |
| P2 | decision-log DEC-019 置顶 + exec-plan 落盘 | 5min | P1 | DEC 编号冲突 |
| P3 | reviewer 自审（critical_module 命中） | 10min | P2 | 规则漏洞 |

## P0 architect 定稿

### 目标

把 issue #65 W1/W2/W3 三项模糊点收敛为 `commands/workflow.md §Step 7` 可直接 apply 的文本补丁。

### 任务清单

- [x] 复用 `docs/testing/reviewer-write-harness-override.md` A2/A3/A4/A5/A7 + `docs/reviews/2026-04-21-reviewer-write-harness-override.md` Warning 1/2 已提议文本
- [x] 产出 `docs/design-docs/step7-relay-contract-tightening.md` 迷你设计注记（规则 + 落点 + 不改清单）
- [x] scope 严格限 workflow.md 一节，不触碰 agent prompt 本体

### 成功信号

- 设计文档 ≤ 40 行
- W1/W2/W3 每项给出明确落点 bullet 号 + 改写后文本

## P1 developer 改 workflow.md §Step 7

### 目标

按 P0 设计注记 apply 文本补丁，diff ≤ 20 行。

### 任务清单

- [x] 标题 `Orchestrator Relay Write（主路径；DEC-017）` → 追加 `触发与 frontmatter 规则收紧 DEC-019`
- [x] 触发条件段开头加 `判定源 = 派发 context 与 subagent final message 字面匹配，不采 subagent 自述升级`
- [x] bullet 2（Critical finding）展开为 `## Critical` 非空 OR `🔴` + `critical` 词白名单；加"自然语言散文不触发"
- [x] bullet 3（用户归档）加白名单 `归档 / 落盘 / sink / archive`；限"用户 prompt 正文"；subagent 自述不触发明禁
- [x] bullet 4（tester）改写布尔优先级：`critical_modules 命中 OR (size ∈ {medium, large} AND 需产出测试计划)`
- [x] Relay contract bullet 1 追加 frontmatter 剥离规则

### 成功信号

- `commands/workflow.md` §Step 7 本节自洽，术语与 DEC-017 本体一致
- 不引入与 `agents/*.md` 的交叉依赖
- 不删除任何既有 bullet（仅扩展）

## P2 decision-log + exec-plan 落盘

### 任务清单

- [x] `docs/decision-log.md` 顶部追加 DEC-019；Refines DEC-017 显式
- [x] `docs/exec-plans/completed/step7-relay-contract-tightening.md`（本文件）落盘

### 成功信号

- DEC-019 编号无冲突
- decision-log append-only 纪律保持（DEC-017 状态行不动）

## P3 reviewer 自审

见 `docs/reviews/2026-04-21-step7-relay-contract-tightening.md`（orchestrator relay 落盘）。

关键观察点：
- W1/W2/W3 三规则文本字面正确
- 不与 DEC-017 D1-D8 冲突
- 不触及 lane B（#66）/lane C（#67）/lane D（#68）的职责范围

## 风险与预案

- **与 lane B（#66 relay 失败 UX）workflow.md §Step 7 hunk 邻接**：本 PR 只扩展触发条件段 + Relay contract bullet 1；#66 预计扩展末尾新 bullet（失败分支）；merge 时若冲突走人工 rebase
- **DEC-019 编号与 lane C/D 并发分配冲突**：lane C/D 是否需 DEC 未知；若冲突走 decision-log append-only 纪律重分配编号

## 变更记录

- 2026-04-21：初版 + 实施闭环
