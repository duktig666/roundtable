---
slug: faq-sink-protocol
source: issue #27 P2 bug fix
reviewer: roundtable:reviewer (orchestrator relay due to subagent Write unavailable — Step 7 兜底)
created: 2026-04-21
judgment: Approve-with-caveats (after C1 inline fix)
---

# Review: FAQ Sink Protocol (issue #27)

## Critical

**C1（已 inline 修复）** — `commands/workflow.md` — **Step 0.2 位置与 `{docs_root}` 依赖序错位**

原 Step 0.2 位于 Step -1 与 Step 0 之间（line 54 vs Step 0 line 106），但 semantics 引用 `{docs_root}` / `target_project`，这两项由 Step 0 populate。实际修复：
- rename Step 0.2 → **Step 0.5**
- 物理位置 move 到 Step 0 之后（已用 Python 重排 lines）
- 在 Step 0.5 开头加"**位置说明**（C1 修复）"段明示 standing rule 语义 + "Step 0 完成前的提问延后 sink"
- `commands/bugfix.md` ref 同步 → Step 0.5

## Warning

**W1（已修）** — `docs/design-docs/faq-sink-protocol.md:65` §2.4 "grep 用户原问关键词 + ≥70% 词重叠" stale → 改 Jaccard bag-of-words + ref `commands/workflow.md` Step 0.5 权威

**W2（已修）** — `docs/design-docs/faq-sink-protocol.md:98` §3.1 draft `prefix: analyze` stale → 改 `prefix: faq-sink` + 加"正文以 commands/workflow.md Step 0.5 为权威"

**W3（follow-up）** — 同义词去重盲区（`orchestrator` vs `编排器`）留 follow-up 扩词典

**W4（已修）** — 强制 sink 命令 (`add to FAQ`) 需机制类前提；纯业务问题即使强制也拒绝 + 引导改写

**W5（已修）** — `docs/log.md:26` 条目说明 `prefix analyze slug faq-sink` 笔误 → 改 `prefix: faq-sink slug: faq-sink`

## Suggestion

**S1（follow-up）** — Tokenization 对 `DEC-\d+` / `Step \d+(\.\d+)?` 预归一化为原子 token

**S2（已修）** — `docs/faq.md:4` 绝对路径 ref `commands/workflow.md Step 0.2` → 改泛化 "roundtable FAQ Sink Protocol"

**S3（follow-up）** — slug `faq-sink` reserve 注释加到 §前缀规范

**S4（已修）** — bugfix.md ref 同步 Step 0.5

## 决策一致性

- **DEC-006 §A**: **一致** —— A 类 `问:` 菜单循环专属显式 `问:` 前缀，裸问走 global FAQ + 回 menu，双路径互补
- **DEC-013**: **一致** —— 与 decision_mode 正交
- **DEC-014**: **一致** —— `faq-sink` 新前缀独立
- **DEC-015**: **一致** —— orchestrator 自动动作非决策点，auto/manual 同款
- **DEC-002 / DEC-009**: **一致** —— escalation 正交；log batching 沿用 Step 8 union/append

## 积极项

- **自举 dogfood Step 7 兜底（第二次）**：本次 reviewer runtime 再次未暴露 Write → Step 7 兜底 contract 再次触发 relay；F4 修复稳定有效
- **critical_modules 命中判定准确** + 必落盘
- **白名单关键词 + 中文通用词共现约束** 有效避免业务语境误伤（F6 修复心智正确）
- **A 类 menu 互补规则清晰** (`问:` 前缀走 menu / 裸问走 Step 0.5)
- **`faq-sink` 独立前缀** 避免 `analyze` 语义过载

## 总结

**判定：Approve-with-caveats** 合并前 C1 + W1/W2/W4/W5 + S2/S4 已 inline 修复。W3/S1/S3 归 follow-up。

合入后跟进：
1. 同义词去重扩词典（W3）
2. Tokenization 原子化 DEC/Step 编号（S1）
3. slug `faq-sink` reserve 注释（S3）

## 变更记录

- 2026-04-21 initial（reviewer + orchestrator relay）
