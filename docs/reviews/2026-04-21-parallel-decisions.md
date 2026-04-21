---
slug: parallel-decisions
source: issue #28 / DEC-016
created: 2026-04-21
reviewer: roundtable:reviewer (orchestrator relay due to subagent Write failure)
description: DEC-016 §Step 4b parallel-decisions 代码审查 — Approve-with-nits（0 Critical / 2 Warning / 3 Nit）
---

# Review: DEC-016 §Step 4b Parallel Decisions (issue #28)

**Verdict**: Approve-with-nits

## Critical
(none)

## Warning

### R-W-01 · §Step 4b max_concurrent_decisions=3 overflow behavior still undefined
- **位置**: `commands/workflow.md:259`
- **观察**: tester S-02 flagged this as Suggestion; reviewer 升为 Warning（critical_modules 命中文件，规则 runtime 可见）。>3 fuzzy decisions 同轮共现时 orchestrator 无确定行为（split 3+1 / 全串行 / drop 4th）；auto_mode 下不可 audit。
- **建议**: line 259 后补 `> 3 → 前 3 批量，第 4+ 串行续跑`（单行闭合）。

### R-W-02 · Step 4b failure-path 缺歧义重问 retry cap
- **位置**: `commands/workflow.md:261`（W-02 patched 段）
- **观察**: per-question ambiguous answers → `§3.6` 逐层澄清，**无重问 cap**；DEC-006 `不静默替决策` 不等价于 unbounded retry。
- **建议**: 非阻塞本 PR；follow-up issue（P3）补 retry cap（建议 3 次后降级 halt + emit 审计）。

## Nit

- **R-N-01 INDEX.md linkage**: orchestrator Step 7 批量维护，非 reviewer 作用域，flag for visibility。
- **R-N-02 §Step 5b event class e 轻微冗余**: `batch auto-pick 合并单围栏` 与表格列字面略重；可读性优先保留。
- **R-N-03 <batch_id> format 只在 design-doc 显式**: §6.9 table row 用 `<batch_id>` opaque；design-doc §3.4 cross-ref 充分。

## Dimension-by-dimension

| 维度 | 结论 |
|------|------|
| 1 Design correctness | Pass — DEC-016 与 DEC-001~015 coherent；scope B 正确排除 §3.1.1 / DEC-006 A+B / DEC-003 边界 |
| 2 Implementation fidelity | Pass — §Step 4b 4 条件与 design-doc §3.1 字面一致；3 refs + §6.9 batch row + §5b e note 全部到位 |
| 3 Security / deadlock | Pass — 整组 halt 显式走 manual；runtime cancel 不被 auto 吞；都选推荐需 per-question 验证 |
| 4 Consistency | Pass — CLAUDE.md 文字升级 + §Step 4b cross-note 锁死 §3.1.1 不倒灌 |
| 5 Tester W-01~W-05 closure | Pass — 5/5 all resolved by inline patches |
| 6 DEC-016 scope accuracy | Acceptable — patched 段略增但 DEC 影响范围为 qualitative |
| 7 Rollback safety | Clean — 无 schema/agent/skill 改动需回 |
| 8 Docs linkage | INDEX.md 未加，orchestrator Step 7 处理 |

## Decision coherence audit

| DEC | 关系 | 状态 |
|-----|------|------|
| DEC-013 §3.1.1 | 显式保留 + cross-note 防倒灌 | ✅ |
| DEC-013 Option Schema | batch 直接复用 | ✅ |
| DEC-013 §3.1a forwarding | §3.4 correction 已修 direction | ✅ |
| DEC-015 §Auto-pick | batch 行复用 `🟢 auto-pick` / `🔴 auto-halt` | ✅ |
| DEC-006 A/B/C | 显式排除 scope | ✅ |
| DEC-003 fan-out | orthogonal（决定 9）| ✅ |
| DEC-011/012 | max_concurrent=3 硬编码不抬 CLAUDE.md | ✅ |

## 总结

- **Approvable with 2 nits**. 0 Critical；2 Warnings 均为规则边界 spec gap（非阻塞）。
- **主关注点**: R-W-01 若能单行补齐则 in-PR 闭合；否则 R-W-01 / R-W-02 开 P3 follow-up。

## 变更记录

| 日期 | 变更 |
|------|------|
| 2026-04-21 | 初稿（orchestrator relay） |
