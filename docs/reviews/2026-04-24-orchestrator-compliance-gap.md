---
slug: orchestrator-compliance-gap
source: issue #113 P1
reviewer: orchestrator relay (subagent a7cfd6845db06dd65)
created: 2026-04-24
result: Approve
---

# Orchestrator Compliance Gap P1 §Step 5c 终审报告

## 审查总结

P1 改动 scope 精确（4 处改 + 2 新文件），lint 双层 pass，Critical 底线 `title-tag DEC ref=0` 恢复（L349 现为 body γ-锚点），INDEX 升序惯例修复，action 4 b-9 旁注补齐。对照 6 条 DEC 验证，Refines 语义自洽，`<escalation>` / C 类边界显式排除合 DEC-024 / DEC-013 §3.1a / DEC-006。**发现 1 Warning**（Tier 2 postmortem 五段式 vs DEC-014 决定 5 硬规定 7 section + frontmatter 三字段），非阻塞 —— 属存量惯例漂移（`lint-cmd-multifield-propagation.md` 同症），建议开 follow-up audit issue 统一。

## 审查维度

| DEC / § | 检查点 | 结论 |
|---|---|---|
| **DEC-024** | Phase Matrix locus = orchestrator 不下放 | §Step 5c 全程 orchestrator tick；action 4 fwd-b 尾段 Matrix 快照沿用；未推翻 |
| **DEC-013 §3.1a** | sticky channel forwarding | action 3 fwd-c / action 4 fwd-b 明示 "sticky channel 必 fire，纯终端 session 降级"；OR 路径语义保留 |
| **§Step 6 (DEC-006)** | A/B/C taxonomy + A 类 "停下不调用任何工具" | 适用范围声明 A 类专属；action 6 `[pause]` defer §Step 6.1；action 5 `[menu]` defer §Step 6.1；原文未动 |
| **DEC-030** | γ 锚点首处 + P1 layout / P2 enforcement 拆分 | `grep -c DEC-030 commands/workflow.md` = 1，唯一命中 Runtime enforcement 行 = §Step 5c 规则主体首处 |
| **DEC-029 §2(a)** | title-tag DEC ref 零存量底线 | `grep -nE "^#{2,6} .*DEC-[0-9]+" skills/ agents/ commands/` 无命中；C1 post-fix 闭环 |
| **DEC-014** | Tier 2 postmortem 模板 | 决定 5 硬规定 7 section + frontmatter `severity` / `related_issue` / `related_dec`；**本 PR postmortem 5 段 + 缺 3 frontmatter 字段** → W1 |
| **Refines 语义** | DEC-024 / DEC-013 §3.1a / §Step 6 全 Accepted 保留 | 未 Supersede；P2 enforcement 归 issue #114 独立 |
| **lint_cmd_hardcode** | exit 0 / 无硬编码命中 | Pass |
| **lint_cmd_density** | baseline 回归 | Pass（exit 0） |
| **critical_modules 命中** | reviewer relay 必触发 | 已预期，本报告作 relay body |
| **scope 边界** | `docs/analyze/feature-inventory.md` + `docs/pre.md` 不在本 PR | 工作区 untracked，未纳入 staging，不阻塞 |
| **plan-over-DEC** | exec-plan P1.2 header `(DEC-030)` 与 DEC-029 §2(a) 曾冲突 | 已在 runtime 层 post-fix 消解；plan 本身属 `docs/` 豁免（DEC-029 决定 1），无需 post-fix |

## Findings

### Critical
无。C1（title-tag DEC ref 破坏底线）tester 阶段 post-fix 已闭环（workflow.md header `(DEC-030)` 已去；γ-锚点下移 Runtime enforcement body）。

### Warning
**W1. Postmortem 模板不合 DEC-014 决定 5（存量惯例漂移）**
`docs/bugfixes/orchestrator-compliance-gap.md` 当前 5 段（根因 / 复现 / 修复 / 验证 / Follow-ups）且 frontmatter 缺 `severity` / `related_issue` / `related_dec` 三字段。DEC-014 决定 5 硬规定 7 section（现象 / 根因 / 修复 / 复现 / 验证 / 后续动作 / 变更记录）+ frontmatter 三字段。存量 `lint-cmd-multifield-propagation.md` 同症（亦 5 段、缺同字段），属已 merged 惯例漂移，**非本 PR 独引入**。
**建议**：开 P2/P3 audit follow-up issue 统一补齐两 postmortem（或修 DEC-014 决定 5 以 Refines 承认 5 段现实）；**本 PR 不阻塞 merge**（与存量先例一致，发散讨论超本 PR scope）。

### Suggestion
**S1. Postmortem §4 验证段 P2 状态** 已显式标 "本节由 P2 收尾时 update"，清晰，零 404 欺骗 —— 已足够，无须改动。

**S2. tester 报告 frontmatter `result: Pass-with-post-fix (C1+W1+W2 applied)`** 是 orchestrator relay 补的权威字段，但 DEC-017 relay contract 第 1 条只枚举 `slug` / `source` / `created` / `reviewer|tester`，`result` 字段属扩展字段，建议 DEC-017 follow-up 时补 schema 说明（out of scope）。

## 审查结论

**Approve**

P1 改动精准、Refines 语义自洽、critical_modules 命中已 relay、lint 双层 pass、6 条 DEC 对齐、AC 4 维度 tester Pass-with-post-fix 全闭环。W1 属存量惯例漂移（非本 PR 引入），不阻塞 merge，建议开 follow-up audit issue。
