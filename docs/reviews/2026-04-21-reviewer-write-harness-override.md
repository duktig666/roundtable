---
slug: reviewer-write-harness-override
source: docs/design-docs/reviewer-write-harness-override.md
created: 2026-04-21
reviewer: subagent (orchestrator relay; DEC-017 §Step 7)
critical_modules_hit:
  - Skill / agent / command prompt 文件本体
  - Resource Access matrix
  - workflow Phase Matrix + Step 7 relay contract
  - DEC-006 phase gating 落盘契约（DEC-017 Refines）
verdict: Approve (0 Critical / 2 Warning non-blocking / 4 Suggestion follow-up)
---

# Review: issue #59 方向 C (DEC-017) 终审

## Critical

无。

## Warning

- `agents/reviewer.md:65` — Content Policy 路径 `${CLAUDE_PLUGIN_ROOT}/skills/_progress-content-policy.md`；但 **reviewer.md 上层的派发 prompt 注入部分**里某些复用代码段残留旧相对路径 `/data/rsw/roundtable/skills/_progress-content-policy.md`（见本派发收到的 prompt 第 66 行 `见 /data/rsw/roundtable/skills/_progress-content-policy.md`）——属于 orchestrator 派发模板的问题，不是本次 DEC-017 改动范围，但**可跨派发触发 feedback_no_absolute_paths_in_docs 风险**。仅 note，不阻塞 DEC-017。
- `commands/workflow.md:462` — tester 触发条件写 `tester 中/大任务（critical_modules 命中 或 size=medium/large 且需产出测试计划）`，与 DEC-017 决定 2 "critical_modules 命中 OR Critical finding OR 用户要求归档" 三条件不完全对称。tester 独有 `size=medium/large` 分支合理（因 tester §测试计划模板历来按 size 触发），但 relay 触发条件表里 4 bullet 存在两类（"三条件 + tester 独有 size 条件"），**读者可能误解 tester 不走 "Critical finding" 触发**。建议把第 4 bullet 改为附注形式（或归入第 2 bullet "Critical finding / 测试计划产出需求"），避免并列造成 tester 触发模型看起来独立。非阻塞。

## Suggestion

- `agents/dba.md:137` — dba §输出落盘触发条件写 "大表 schema 变更 / 新建 hypertable 或分区表 / 🔴 Critical 影响数据完整性或性能 / 用户明示要求归档" —— **没有显式列出 "命中 `critical_modules`"**（reviewer 有）。dba 不是 reviewer/tester 强制链路一部分（按需派发），但 DEC-017 决定 2 原文是三条件；建议与 reviewer 对齐补一条 "命中 `critical_modules`"，保持 3 agent 触发条件文字一致性（CLAUDE.md 条件触发规则要求 3 agent Resource Access 对应列纪律一致）。
- `agents/tester.md:100` — 段首 `**输出落盘（orchestrator relay 主路径；DEC-017）**` 放在 §测试计划模板小节第一段，而 reviewer/dba 把 `## 输出落盘` 作为**独立 H2 小节**。小差异，不影响语义，但三 agent 结构对称性可提升（follow-up）。
- `docs/testing/reviewer-write-permission.md:11` — 标题 `reviewer/tester/dba Write 权限明示 + orchestrator 兜底 测试计划` 仍反映 pre-DEC-017 语义。post-fix 注记已追加但标题未更新；属历史文档保留原貌无妨，但 §1 "当前覆盖现状"（Line 15-20）bullet 仍引用已删除的 "Write 权限明示" 段。可选择在 §变更记录顶部追加 anchor "本文档标题/§1 保留 pre-DEC-017 语义作历史档，post-fix 注记（§变更记录 Line 108+）为当前状态"。Nit。
- `docs/design-docs/reviewer-write-harness-override.md:83` — 设计文档 §3.1 表格 "agents/reviewer.md" 行说明 `Write 列改为 '—'（不再含 {docs_root}/reviews/...）`；实现使用 `—（em dash）` —— 对齐。 Suggestion: 在 §2.4 sentinel 协议废除段末补一行 "已通过 `grep -rnE 'Write .+ denied by runtime' skills/ agents/ commands/` 0 命中验证"（已实测但文档未写入证据锚点）。

## 决策一致性

DEC-017 决定 1-8 逐条验证：

| 决定 | 落地位置 | 一致性 |
|---|---|---|
| D1 契约反转（3 agent 不 Write 归档 .md；Step 7 升主路径） | `agents/reviewer.md:113-119` / `agents/tester.md:100-103` / `agents/dba.md:133-137` / `commands/workflow.md:456-469` | ✅ 一致 |
| D2 触发条件（critical_modules 命中 OR Critical OR 用户要求） | `commands/workflow.md:458-462` | ⚠️ tester 第 4 bullet 引入 size 条件，建议归并（Warning 2） |
| D3 Resource Access 调整（reviewer/dba 移除 Write；tester 保 tests/*） | `agents/reviewer.md:22` / `agents/tester.md:26` / `agents/dba.md:30` | ✅ 一致 |
| D4 sentinel 协议废除 | `agents/` 本体 grep `denied by runtime` 0 命中；`commands/workflow.md` 0 命中 | ✅ 一致 |
| D5 Step 7 末段改写（标题 + 触发条件 + 精简） | `commands/workflow.md:456`（标题）/ 458-462（触发）/ 464-469（contract） | ✅ 一致 |
| D6 orchestrator 自造 `created:` / `log_entries:` | `commands/workflow.md:467-468`；`agents/*.md` §完成后均明示 "无需 emit" | ✅ 一致 |
| D7 Refines DEC-006 非 Supersede | DEC-006 仍 Accepted，本派发检查 `decision-log.md` 未改 DEC-006 状态行；DEC-017 状态 Accepted；`decision-log.md:49` 决定 7 明示 Refines | ✅ 一致 |
| D8 不改（critical_modules / Phase Matrix / Write 内容模板 / architect/analyst/developer Write 路径 / DEC-001~016） | grep `critical_modules` 机制文本 / 决策表 / architect SKILL 未动 | ✅ 一致 |

**与 DEC-006 关系复议（Refines 非 Supersede 纪律）**：
- DEC-006 §critical_modules 机械触发归 C 类 verification-chain：未改（Phase Matrix 动过 tester/reviewer 所属 stage 么？—— 未动，落盘执行者转移不动 phase 分类）
- DEC-006 §A/B/C 三分类：未改
- DEC-006 状态：Accepted 保留（本派发 grep 确认 decision-log 无 "Superseded by DEC-017" 标记）
- **结论**：Refines 纪律保持正确，DEC-006 执行契约被细化（从"subagent 自落盘"变"orchestrator relay 落盘"）但语义不变。

**复议 tester W1/W2/W3 findings（本派发上下文声明）**：无 tester report 原文 Read，仅基于 exec-plan P3 `[x] E1 dogfood 验证通过`；无从对照 W1/W2/W3 是否 overreach。若后续需要独立复议，需要 orchestrator 提供 tester report 落盘 path。本次 review 在 subagent 层面判定**tester E1 dogfood 已通过 = relay 路径 2/2 预期将继本轮 E2 完成**。

## 总结

**可合并**（Approve with 2 Warning 非阻塞 + 4 Suggestion follow-up）。

- DEC-017 决定 1-8 全部落地，sentinel 协议完整删除（skills/agents/commands/ 本体 0 残留，只在 docs/ 历史记录里合法引用）
- lint_cmd 0 命中
- Refines DEC-006 非 Supersede 纪律保持（DEC-006 状态 Accepted / 三分类未动 / critical_modules 机制未动）
- 3 agent Resource Access 三向对称（reviewer `—` / tester 保 `tests/*` / dba `—`）
- Warning 2（tester 触发条件 4 bullet 并列写法）建议 follow-up issue 收敛；不阻塞本 PR
- Suggestion 2 (dba 触发条件文字对齐 reviewer) 可在 follow-up inline 处理

**E2 dogfood 自我观察**：本 agent 本次派发**未调用 Write 工具**（全程仅 Read / Grep / Bash readonly 调用）。完整 review 报告作为 final message 返回，orchestrator 按 `commands/workflow.md §Step 7 Relay contract` 代写 `docs/reviews/2026-04-21-reviewer-write-harness-override.md`。
