---
slug: orchestrator-compliance-gap
source: issue #113 P1
tester: orchestrator relay (subagent a755592c9873d59c2)
created: 2026-04-24
result: Pass-with-post-fix (C1+W1+W2 applied)
---

# Orchestrator Compliance Gap P1 对抗性测试报告

P1 改动落盘 4 文件（`commands/workflow.md` +§Step 5c + §Step 6.1 ref 行 / `docs/bugfixes/orchestrator-compliance-gap.md` new / `docs/log.md` +1 entry / `docs/INDEX.md` +1 条目），lint 双层 exit 0。针对 issue #113 AC 4 维度对抗性扫描，发现 1 Critical + 2 Warning + 2 Suggestion；均 in-place 可修，不阻断 pipeline。

## Findings

### Critical

**C1. DEC-029 §2(a) title 标签 DEC ref 零存量底线被破坏**
DEC-029 决定 2(a) 硬规则：*"删全部 title 标签 DEC/issue ref（现 5 处）"*。`grep -nE "^#{2,6} .*DEC-[0-9]+" skills/ agents/ commands/` 现命中**唯一 1 处** = `commands/workflow.md:338 ## Step 5c: Skill→Orchestrator Handoff Checklist (DEC-030)`。清理后 5→0 的底线被本 PR 打破重回 1，直接违反 Accepted DEC（非 Refined，非 post-fix 豁免）。architect exec-plan P1.2 / L34 明示该 header 形态，developer 按 plan 落盘属 plan-over-DEC 冲突。

**Post-fix**：去掉 L338 header 尾部 `(DEC-030)` → 纯 `## Step 5c: Skill→Orchestrator Handoff Checklist`；DEC-030 γ-锚点**首处**下移到 body 规则主体（如 Runtime enforcement 行改为 `**Runtime enforcement**（DEC-030 P2 follow-up 生效）：...`）。成本 2 行改动。

### Warning

**W1. INDEX.md bugfixes 段顺序破坏现有惯例**
既有 `docs/INDEX.md` §bugfixes 修改前为 `batch-97(2026-04-22)` → `lint-cmd-multifield(2026-04-24 10:55)` 升序时间。新条目 `orchestrator-compliance-gap(2026-04-24 11:24)` 被插到**中间**，两向都不一致。同文件 §reviews 采逆时间序（newest first），bugfixes 既有 2 条是升序。**Post-fix**：把 orchestrator-compliance-gap 条目移到 lint-cmd-multifield 之后末尾（保升序惯例）。

**W2. §Step 5c action 4 未覆盖 Stage 9 b-9 特例**
L345 action 4 `[fwd-b]` 引 `§Step 5b 事件类 b`，未提 Stage 9 Closeout bundle 走 b-9（3 section >3500 chars 拆 2-3 reply）。Stage 9 A 类终点用 §Step 5c 时，action 4 格式需由 b-9 主管。**Post-fix**（可选，非阻）：action 4 括注改 `详见 §Step 5b 事件类 b（Stage 9 走 b-9 变体）`。

### Suggestion

**S1. 未跟踪文件**：`docs/analyze/feature-inventory.md` / `docs/pre.md` 在 working tree 但非本 PR scope，reviewer stage 前需甄别。

**S2. Postmortem §3/§4 P2 ref**：明示 P2 scope，无 404 欺骗；可加 "(P2 merged 后生效)" 一句对 P1 读者更友好，非必需。

## 验证 AC 4 维度

| AC | 结果 |
|----|------|
| §Step 6.1 A 类模板不冲突 | Pass（§Step 6.1 原文未动 + A 类模板 ref 行 + action 6 pause 显式 ref §Step 6.1 避免重复定义）|
| architect 变体（go-with-plan / go-without-plan）| Pass（action 5 [menu] 显式 defer §Step 6.1）|
| Stage 9 Closeout 变体 | Pass-with-W2（action 5 defer，但 action 4 格式需旁注 b-9）|
| Q&A 循环 | Pass（flush per-slug union（§Step 6.1 Q&A 边界保证）+ 每轮 digest/menu fire 与 §Step 5b 事件类 c 一致）|

## 结论

**Pass-with-post-fix**

Post-fix applied 2026-04-24 orchestrator inline（同 PR within ~4 行）：

- C1：`commands/workflow.md:338` header 去尾部 `(DEC-030)` + Runtime enforcement 行加 `DEC-030 P2 follow-up` anchor（γ-锚点首处下移到 body）
- W1：`docs/INDEX.md` §bugfixes 顺序调整 batch-97 → lint-cmd-multifield → orchestrator-compliance-gap（保升序惯例）
- W2：`commands/workflow.md` action 4 括注加 `Stage 9 走 b-9 变体`

Post-fix 后 `lint_cmd_hardcode` exit 1（grep 无命中 = pass）/ `lint_cmd_density` exit 0；title-tag DEC ref 零命中恢复 DEC-029 §2(a) 底线。

S1 / S2 为 reviewer stage 甄别 / 非阻风格建议，保留给 reviewer 或 closeout 处理。
