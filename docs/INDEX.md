# 文档索引

> 由 /roundtable:lint 自动生成。手动修改会被下次 lint 覆盖。
> 上次更新：2026-04-28

## 调研报告 (analyze/)

- [decision-log-sustainability](analyze/decision-log-sustainability.md) — decision-log 可持续性分析报告
- [dispatch-mode-strategy](analyze/dispatch-mode-strategy.md) — 前台/后台派发选择策略 调研报告
- [feature-inventory](analyze/feature-inventory.md) — roundtable 功能实现梳理
- [lightweight-review](analyze/lightweight-review.md) — roundtable 轻量化审计报告
- [orchestrator-compliance-gap](analyze/orchestrator-compliance-gap.md) — Orchestrator Handoff Forwarding 合规缺口分析报告
- [parallel-research](analyze/parallel-research.md) — Parallel Research Subagent Dispatch 调研报告
- [phase-transition-rhythm](analyze/phase-transition-rhythm.md) — workflow phase transition 节奏重构 分析报告
- [prompt-language-policy](analyze/prompt-language-policy.md) — Plugin prompt 本体语言策略调研报告
- [prompt-reference-density-audit](analyze/prompt-reference-density-audit.md) — Runtime Prompt 引用密度回归审计
- [subagent-coldstart-overhead-20](analyze/subagent-coldstart-overhead-20.md) — Subagent 冷启开销与小任务形态调研（issue #20）
- [subagent-progress-and-execution-model](analyze/subagent-progress-and-execution-model.md) — subagent 执行进度可见性 + 主会话/子会话执行模型可选配 分析

## 执行计划 (exec-plans/active/)

- [orchestrator-compliance-gap-plan](exec-plans/active/orchestrator-compliance-gap-plan.md) — Orchestrator Handoff Forwarding 合规性修复 执行计划
- [parallel-decisions-plan](exec-plans/active/parallel-decisions-plan.md) — Orchestrator Decision Parallelism 执行计划
- [refactor-minimal-rewrite](exec-plans/active/refactor-minimal-rewrite.md) — Roundtable 全面重构 — 极简轻量化
- [roundtable-plan](exec-plans/active/roundtable-plan.md) — roundtable Plugin 执行计划
- [workflow-auto-execute-mode-plan](exec-plans/active/workflow-auto-execute-mode-plan.md) — Workflow Auto-Execute Mode 执行计划

## 已归档执行计划 (exec-plans/completed/)

- [decision-log-sustainability-plan](exec-plans/completed/decision-log-sustainability-plan.md) — decision-log 可持续性执行计划
- [decision-mode-switch-plan](exec-plans/completed/decision-mode-switch-plan.md) — 可切换决策模式 执行计划
- [lightweight-review-plan](exec-plans/completed/lightweight-review-plan.md) — 轻量化重构 执行计划
- [progress-content-policy-plan](exec-plans/completed/progress-content-policy-plan.md) — Progress Content Policy 执行计划
- [prompt-reference-density-audit-plan](exec-plans/completed/prompt-reference-density-audit-plan.md) — Runtime Prompt 引用密度精简执行计划
- [reviewer-write-harness-override-plan](exec-plans/completed/reviewer-write-harness-override-plan.md) — reviewer-write-harness-override 执行计划
- [step7-relay-contract-tightening](exec-plans/completed/step7-relay-contract-tightening.md) — step7-relay-contract-tightening 执行计划
- [subagent-progress-and-execution-model-plan](exec-plans/completed/subagent-progress-and-execution-model-plan.md) — subagent 进度可见性 + 执行模型可选配 执行计划

## 测试 (testing/)

- [abspath-residue-68](testing/abspath-residue-68.md) — 测试报告：issue #68 绝对路径残留修复回归
- [bugfix-rootcause-layered](testing/bugfix-rootcause-layered.md) — DEC-014 bugfix 根因分层落盘测试计划（prompt 层静态对抗）
- [closeout-spec](testing/closeout-spec.md) — Stage 9 Closeout 结构化流程 测试计划
- [decision-log-sustainability](testing/decision-log-sustainability.md) — decision-log-sustainability 对抗性测试报告（DEC-025 + DEC-026）
- [decision-mode-switch](testing/decision-mode-switch.md) — 可切换决策模式 测试计划与对抗性审查
- [dedupe-produce-created](testing/dedupe-produce-created.md) — 禁 `产出:` 自然语言清单 / 保留 `created:` YAML 唯一机读源 对抗
- [faq-sink-protocol](testing/faq-sink-protocol.md) — FAQ Sink Protocol 测试计划
- [fix-analyst-askuserquestion-params](testing/fix-analyst-askuserquestion-params.md) — analyst/architect AskUserQuestion 参数修复 测试计划
- [lightweight-review](testing/lightweight-review.md) — DEC-009 轻量化重构 对抗性测试
- [orchestrator-bootstrap-hardening](testing/orchestrator-bootstrap-hardening.md) — orchestrator-bootstrap-hardening 对抗性测试报告（DEC-028）
- [orchestrator-compliance-gap](testing/orchestrator-compliance-gap.md) — Orchestrator Compliance Gap P1 对抗性测试报告
- [p4-self-consumption](testing/p4-self-consumption.md) — P4 自消耗闭环验证观察报告
- [parallel-decisions](testing/parallel-decisions.md) — Orchestrator Decision Parallelism (DEC-016 / §Step 4b) 对抗性测试报告
- [phase-end-approval-gate](testing/phase-end-approval-gate.md) — Phase-End Approval Gate 测试计划（对抗性 prompt 审查）
- [phase-transition-rhythm](testing/phase-transition-rhythm.md) — phase gating taxonomy（DEC-006）对抗性测试报告
- [progress-content-policy](testing/progress-content-policy.md) — Progress Content Policy (DEC-007) 对抗性测试报告
- [prompt-reference-density-audit](testing/prompt-reference-density-audit.md) — Runtime Prompt 引用密度回归审计测试报告
- [prune-dec-refs](testing/prune-dec-refs.md) — Prune DEC / issue refs in runtime prompts — 测试计划 & 对抗性审查
- [reviewer-write-harness-override](testing/reviewer-write-harness-override.md) — DEC-017 relay 主路径反转契约 对抗性测试计划
- [reviewer-write-permission](testing/reviewer-write-permission.md) — reviewer/tester/dba Write 权限明示 + orchestrator 兜底 测试计划
- [step35-foreground-skip-monitor](testing/step35-foreground-skip-monitor.md) — Step 3.5 前台派发免 Monitor（DEC-008）对抗性测试
- [subagent-progress-and-execution-model](testing/subagent-progress-and-execution-model.md) — issue #7 对抗性测试报告 — subagent 进度协议 + developer 双形态
- [tg-forwarding-expansion](testing/tg-forwarding-expansion.md) — DEC-013 §3.1a Active Channel Forwarding 扩展 对抗性 Prompt 审查

## 评审 (reviews/)

- [2026-04-19-lightweight-review](reviews/2026-04-19-lightweight-review.md) — DEC-009 轻量化重构 终审 Review
- [2026-04-19-phase-transition-rhythm](reviews/2026-04-19-phase-transition-rhythm.md) — DEC-006 phase gating taxonomy 最终合并审查
- [2026-04-19-progress-content-policy](reviews/2026-04-19-progress-content-policy.md) — DEC-007 Progress Content Policy 代码审查
- [2026-04-19-step35-foreground-skip-monitor](reviews/2026-04-19-step35-foreground-skip-monitor.md) — DEC-008 落地终审：Step 3.5 前台派发免 Monitor
- [2026-04-19-subagent-progress-and-execution-model](reviews/2026-04-19-subagent-progress-and-execution-model.md) — issue #7 终审报告 — subagent 进度透传 + developer 双形态
- [2026-04-20-bugfix-rootcause-layered](reviews/2026-04-20-bugfix-rootcause-layered.md) — DEC-014 bugfix 根因分层落盘 终审
- [2026-04-20-decision-log-entry-order](reviews/2026-04-20-decision-log-entry-order.md) — 审查：DEC-011 decision-log 条目顺序约定传导
- [2026-04-20-dispatch-mode-strategy](reviews/2026-04-20-dispatch-mode-strategy.md) — DEC-012 实施审查 —— dispatch-mode-strategy
- [2026-04-21-closeout-spec](reviews/2026-04-21-closeout-spec.md) — Stage 9 Closeout 结构化流程 审查（issue #26 P2）
- [2026-04-21-dedupe-produce-created](reviews/2026-04-21-dedupe-produce-created.md) — issue #29 dedupe `产出:` vs `created:` —— 终审报告
- [2026-04-21-faq-sink-protocol](reviews/2026-04-21-faq-sink-protocol.md) — Review: FAQ Sink Protocol (issue #27)
- [2026-04-21-parallel-decisions](reviews/2026-04-21-parallel-decisions.md) — Review: DEC-016 §Step 4b Parallel Decisions (issue #28)
- [2026-04-21-reviewer-write-harness-override](reviews/2026-04-21-reviewer-write-harness-override.md) — Review: issue #59 方向 C (DEC-017) 终审
- [2026-04-21-reviewer-write-permission](reviews/2026-04-21-reviewer-write-permission.md) — Review: issue #23 P2 bug fix — reviewer Write 权限明示
- [2026-04-21-step7-relay-contract-tightening](reviews/2026-04-21-step7-relay-contract-tightening.md) — Review: issue #65 DEC-019 Step 7 relay 契约收紧
- [2026-04-21-tg-forwarding-expansion](reviews/2026-04-21-tg-forwarding-expansion.md) — DEC-013 §3.1a Active Channel Forwarding 扩展 Final Review
- [2026-04-22-decision-log-sustainability](reviews/2026-04-22-decision-log-sustainability.md) — 审查报告：decision-log-sustainability（issue #84 / DEC-025 + DEC-026）
- [2026-04-22-orchestrator-bootstrap-hardening](reviews/2026-04-22-orchestrator-bootstrap-hardening.md) — 审查报告：orchestrator-bootstrap-hardening（issue #104 / DEC-028）
- [2026-04-23-prompt-reference-density-audit](reviews/2026-04-23-prompt-reference-density-audit.md) — Review: Runtime Prompt Reference Density Audit (issue #99)
- [2026-04-24-orchestrator-compliance-gap](reviews/2026-04-24-orchestrator-compliance-gap.md) — Orchestrator Compliance Gap P1 §Step 5c 终审报告

## Bug 复盘 (bugfixes/)

- [batch-97-dogfood-findings](bugfixes/batch-97-dogfood-findings.md) — #84 DEC-025/026 落盘后 dogfood findings batch follow-up Postmortem
- [lint-cmd-multifield-propagation](bugfixes/lint-cmd-multifield-propagation.md) — lint_cmd_* 多字段契约传导面覆盖 Postmortem
- [orchestrator-compliance-gap](bugfixes/orchestrator-compliance-gap.md) — Orchestrator skill→orchestrator handoff forwarding 合规缺口 Postmortem

