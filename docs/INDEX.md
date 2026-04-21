# roundtable 文档索引

> 按产出类型分类的文档导航。**决策权威性**：`decision-log.md` > `design-docs/` > `exec-plans/`。
>
> **维护契约**：新落盘的 design-docs / analyze / testing / reviews / exec-plans 条目必须同步追加到「当前文档清单」section；根级别文档（CHANGELOG / CONTRIBUTING / LICENSE 等）变动在「决策与索引」table 维护。

## 👤 用户向（装 plugin 的人看）

| 文件 | 用途 |
|------|-----|
| [../README.md](../README.md) | GitHub 首页：roundtable 是什么、怎么装、角色分工 |
| [onboarding.md](onboarding.md) | 5 分钟上手手册 |
| [claude-md-template.md](claude-md-template.md) | 给用户抄到自己项目 CLAUDE.md 的完整模板（含填写提示 + FAQ） |
| [migration-from-local.md](migration-from-local.md) | 从项目本地 `.claude/agents/` 切换到 plugin 的迁移 runbook |
| [../examples/rust-backend-snippet.md](../examples/rust-backend-snippet.md) | Rust 后端 / CLI 项目的 CLAUDE.md 示例 |
| [../examples/ts-frontend-snippet.md](../examples/ts-frontend-snippet.md) | TypeScript + React 前端项目的 CLAUDE.md 示例 |
| [../examples/python-datapipeline-snippet.md](../examples/python-datapipeline-snippet.md) | Python 数据管道 / ML 项目的 CLAUDE.md 示例 |

## 🧑‍💻 维护者向（内部开发纪律）

### 决策与索引

| 文件 | 用途 |
|------|-----|
| [decision-log.md](decision-log.md) | **项目决策权威注册表**（DEC-xxx），append-only |
| [log.md](log.md) | 设计层文档时间索引（"何时、谁、动了哪份文档"） |
| [faq.md](faq.md) | 全局 FAQ 沉淀（orchestrator 按 `commands/workflow.md` Step 0.2 自动追加机制类 Q&A；issue #27） |
| [../CHANGELOG.md](../CHANGELOG.md) | 发布面 changelog（Keep a Changelog 格式 + SemVer） |
| [../CONTRIBUTING.md](../CONTRIBUTING.md) | 贡献指南 + 本地测试清单 |

### 按工作流阶段分类

| 目录 | 产出者 | 说明 |
|------|-------|------|
| `analyze/` | analyst | 调研报告，文件名 `[slug].md` |
| [design-docs/](design-docs/) | architect | 核心设计文档，文件名 `[slug].md` |
| `exec-plans/active/` | architect | 进行中的执行计划，文件名 `[slug]-plan.md` |
| `exec-plans/completed/` | developer（归档） | 已完成的执行计划 |
| `testing/` | tester | 测试产出（测试计划 / 对抗性 bug 分析 / benchmark 报告），文件名 `[slug].md` 或 `[slug]-<type>.md` |
| `reviews/` | reviewer / dba | 关键审查归档，文件名 `[YYYY-MM-DD]-[slug].md` 或 `[YYYY-MM-DD]-db-[slug].md` |
| `bugfixes/` | developer | Tier 2 postmortem（根因+修复+复现+验证+后续），文件名 `[slug].md`（DEC-014） |

## 当前文档清单

### analyze

- [subagent-coldstart-overhead-20.md](analyze/subagent-coldstart-overhead-20.md) — issue #20 DEC-005 强制 subagent 小任务冷启开销调研（3 选项代价表；6 事实层开放问题交 architect）
- [parallel-research.md](analyze/parallel-research.md) — architect 派发 parallel research subagent 能力的对标调研（CrewAI / LangGraph / Claude Code sub-agents，12 事实层开放问题交 architect）
- [subagent-progress-and-execution-model.md](analyze/subagent-progress-and-execution-model.md) — subagent 进度可见性 + 执行模型选择 5 路径对比（Claude Code/SDK/Monitor + CrewAI/AutoGen/LangGraph；8 事实层开放问题交 architect，解 issue #7）
- [phase-transition-rhythm.md](analyze/phase-transition-rhythm.md) — issue #10 workflow phase transition 节奏对标研究（git/terraform/apt/kubectl/Make/CrewAI/AutoGen/LangGraph/Claude Code 9 种 CLI/orchestrator UX；6 事实层开放问题交 architect）
- [lightweight-review.md](analyze/lightweight-review.md) — issue #9 轻量化审计（archive 826 vs 现状 2708 行 = 3.16× / 8 个 DEC 增量分类 / 3 大抽取热区 DEC-002/004/007 / 7 事实层开放问题）
- [dispatch-mode-strategy.md](analyze/dispatch-mode-strategy.md) — issue #19 前台/后台派发选择策略调研（F1-F6 事实 + 3 选项对比 + 5 场景评估 + 判据 D1-D4 + 8 事实层开放问题 P1-P8 交 architect）

### design-docs

- [roundtable.md](design-docs/roundtable.md) — roundtable plugin 本身的完整设计（D1-D9 决策 + 量化评分 + §12 FAQ）
- [parallel-research.md](design-docs/parallel-research.md) — architect skill 派发 parallel research subagent 的完整设计（7 条决策，DEC-003 锁定；触发条件 / 派发协议 / 返回 schema / 失败处理 / 并行安全论证）
- [subagent-progress-and-execution-model.md](design-docs/subagent-progress-and-execution-model.md) — subagent progress 透传（P1 push）+ developer 双形态（inline \| subagent）设计，解 issue #7；DEC-004 + DEC-005 落定
- [phase-transition-rhythm.md](design-docs/phase-transition-rhythm.md) — issue #10 workflow phase gating 三段式分类设计（producer-pause / approval-gate / verification-chain + Stage 9 Closeout），DEC-006 落定
- [progress-content-policy.md](design-docs/progress-content-policy.md) — issue #14 subagent progress 内容策略（代理节拍 / 去重 / 差异化 / 终止-失败分离），DEC-007 落定；补丁 DEC-004
- [lightweight-review.md](design-docs/lightweight-review.md) — issue #9 轻量化重构（DEC-009 Proposed；4 shared helper 抽取 + log.md closeout batching + README/CLAUDE.md 结构重塑；预估省 22-25%）
- [decision-log-entry-order.md](design-docs/decision-log-entry-order.md) — issue #18 DEC 条目顺序约定传导到目标项目（SKILL.md 补插入规则 + Minimal header 初始化 + template 补一行），DEC-011 Accepted
- [dispatch-mode-strategy.md](design-docs/dispatch-mode-strategy.md) — issue #19 subagent 派发 run_in_background 选择策略（方向 1 规则补齐 + D2 并行度判据 + D4 两级逃生门；DEC-008 正交补齐），DEC-012 Accepted
- [decision-mode-switch.md](design-docs/decision-mode-switch.md) — issue #31 orchestrator 可切换决策模式 modal \| text（最小改动：agent 零改动 + orchestrator 渲染分支 + skill 条件分支；支持 TG / CI / 日志回放远程前端），DEC-013 Accepted
- [bugfix-rootcause-layered.md](design-docs/bugfix-rootcause-layered.md) — issue #37 bugfix 根因分层落盘（Tier 0 对话 / Tier 1 log.md fix-rootcause entry / Tier 2 docs/bugfixes postmortem；D1-D4 锁定；C1 执行锚点 4 条 + W1-W4 post-fix），DEC-014 Accepted
- [workflow-auto-execute-mode.md](design-docs/workflow-auto-execute-mode.md) — issue #33 `/roundtable:workflow --auto` 批量预授权 A/B 类 gate 自动采纳 recommended（CLI+env 两级优先链 / recommended 缺失强停 / #30 正交 / 4 agent 零改动），DEC-015 Accepted
- [tg-forwarding-expansion.md](design-docs/tg-forwarding-expansion.md) — issue #48 DEC-013 §3.1a 转发语义扩展到 5 类 orchestrator-emitted 事件（context / producer-pause / role digest / C handoff / auto_mode audit；orchestrator-only 落点；markdownv2 结构化 TG 可读性增强），append-only clarification；§3.5 issue #63 DEC-018 松弛 `<decision-needed>` 字节等价 → 语义等价 pretty markdownv2（raw YAML 仅终端 stdout）
- [phase-end-approval-gate.md](design-docs/phase-end-approval-gate.md) — issue #30 phase-end approval gate 统一协议（A 类 producer-pause 菜单穷举 + Q&A 循环 + architect `go-with-plan` / `go-without-plan: <理由>` 拆分；orchestrator + 2 skill 落点），DEC-006 §A append-only clarification
- [faq-sink-protocol.md](design-docs/faq-sink-protocol.md) — issue #27 FAQ 沉淀协议（orchestrator 启发式触发 + `{docs_root}/faq.md` 全局落点 + 70% 词重叠去重 + 📚 回复标注；与 slug 级 FAQ 互补）
- [closeout-spec.md](design-docs/closeout-spec.md) — issue #26 Stage 9 Closeout 用户驱动流程规范（closeout bundle：commit msg + PR body + follow-up issues 3 section；`go-all`/`go-commit`/`skip-*`；memory `feedback_no_auto_*` 硬边界）
- [parallel-decisions.md](design-docs/parallel-decisions.md) — issue #28 orchestrator decision parallelism（D1=B 中等 scope / D2=A 新 §Step 4b 判定树 / D3=A per-decision 失败 / max_concurrent=3 硬编码 / text mode 多块同 response emit），DEC-016 Accepted
- [reviewer-write-harness-override.md](design-docs/reviewer-write-harness-override.md) — issue #59 DEC-017 reviewer/tester/dba 落盘契约反转：orchestrator relay 升主路径（3 agent 不 Write 归档 .md；Step 7 从兜底升主路径；sentinel 协议废除；Refines DEC-006 非 Supersede），DEC-017 Accepted
- [step7-relay-contract-tightening.md](design-docs/step7-relay-contract-tightening.md) — issue #65 DEC-019 Step 7 relay 契约收紧：W1 frontmatter 剥离 + W2 Critical/归档 trigger 白名单 + W3 tester 触发布尔优先级（Refines DEC-017），DEC-019 Accepted

**Plugin 内部 include-only helper**（下划线前缀约定；非独立可激活 skill；不在用户向 skill 清单露出）：

- `skills/_detect-project-context.md` — 4 步 target-project 识别 + toolchain + docs_root + CLAUDE.md 加载（被 workflow / bugfix / lint / architect / analyst 5 方引用）
- `skills/_progress-content-policy.md` — DEC-007 subagent progress 内容策略（被 developer / tester / reviewer / dba 引用）

### exec-plans

- active/
  - [roundtable-plan.md](exec-plans/active/roundtable-plan.md) — roundtable umbrella 实施计划（P0-P4 完成；P5 外部试装 + P6 v0.1 发布未做；24 个 unchecked 主要在 v0.1 release 环节）
  - [workflow-auto-execute-mode-plan.md](exec-plans/active/workflow-auto-execute-mode-plan.md) — issue #33 DEC-015 auto 模式实施计划（P0 bootstrap → P1 Step 5 Escalation → P2 Step 6 A/B gating → P3-P4 inline + bugfix ref → P5-P6 tester/reviewer → P7 dogfood E2E → P8 PR）
  - [parallel-decisions-plan.md](exec-plans/active/parallel-decisions-plan.md) — issue #28 DEC-016 §Step 4b 决策并行化 P0-P3 实施（§Step 4b 新增 + 3 处 ref + §Auto-pick batch 行 + §5b e 批注；P0/P1 checkbox 已 [x]）
- completed/
  - [reviewer-write-harness-override-plan.md](exec-plans/completed/reviewer-write-harness-override-plan.md) — issue #59 DEC-017 4-phase 实施（P0 3 agent prompt / P1 workflow.md Step 7 / P2 testing post-fix / P3 E1+E2 dogfood 验证通过 2/2；lint 2/2）
  - [step7-relay-contract-tightening.md](exec-plans/completed/step7-relay-contract-tightening.md) — issue #65 DEC-019 P0-P3 实施（architect 定稿 → developer Step 7 文本补丁 → decision-log + exec-plan 落盘 → reviewer 自审）
  - [lightweight-review-plan.md](exec-plans/completed/lightweight-review-plan.md) — issue #9 轻量化重构（DEC-009 + DEC-010 Accepted；tree 2708→1672 / -38%；PR #17 merged）
  - [subagent-progress-and-execution-model-plan.md](exec-plans/completed/subagent-progress-and-execution-model-plan.md) — issue #7 + DEC-004/005/008（26 checkbox 全勾；PR #16 merged）
  - [progress-content-policy-plan.md](exec-plans/completed/progress-content-policy-plan.md) — issue #14 DEC-007（P0.1-P0.4 完成；PR #16 merged；归档时补勾 18 checkbox）
  - [decision-mode-switch-plan.md](exec-plans/completed/decision-mode-switch-plan.md) — issue #31 DEC-013（P0.1-P0.7 全完成；PR #34 merged 2026-04-20；剩 6/7 acceptance 待 plugin reload 后 E2E 实跑）

### testing

- [p4-self-consumption.md](testing/p4-self-consumption.md) — P4 自消耗闭环观察报告（gleanforge dogfood 实录：9 subagent 派发 / 3 次并行 / 242 tests / 3 条 top 改进 + 9 摩擦点 + 6 条工作良好设计）
- [subagent-progress-and-execution-model.md](testing/subagent-progress-and-execution-model.md) — issue #7 P0.1-P0.10 对抗性测试（30+ case / 34 PASS + 4 FAIL + 18 WARN / 1 Critical escalation：Monitor jq pipe 被单行非 JSON 击穿）
- [phase-transition-rhythm.md](testing/phase-transition-rhythm.md) — issue #10 DEC-006 三段式对抗测试（2 Critical / 9 Warning / 5 Suggestion；C-01 悬空指针 + C-02 Step 7 与 C 自动前进语义冲突）
- [progress-content-policy.md](testing/progress-content-policy.md) — issue #14 DEC-007 对抗测试（25 cases：0 Critical / 3 Warning / 4 Suggestion；D1 原 dogfood 刷屏回归修复确认 `(x5)`）
- [step35-foreground-skip-monitor.md](testing/step35-foreground-skip-monitor.md) — issue #15 DEC-008（workflow §3.5.0 前台派发免 Monitor gate）对抗测试（18 cases：2 Critical / 3 Warning / 1 Suggestion → post-fix 全绿）
- [lightweight-review.md](testing/lightweight-review.md) — issue #9 DEC-009 轻量化重构对抗测试（19 cases：1 Critical 升级为 Warning / 5 Warning；W-01 design-doc §5 决定编号漂移 7/8/9→8/9/10 已 post-fix；A6 helper role-specific 泄漏已清；D1/E2/B2/F2 post-fix 全绿）
- [fix-analyst-askuserquestion-params.md](testing/fix-analyst-askuserquestion-params.md) — issue #25 analyst/architect AskUserQuestion schema 修复的对抗性验证（6 类反例 + schema 新旧对比 + 4 条手动 dogfood 验收场景 + 未来 lint 扩展建议；静态扫描 0 命中残留伪字段；结论 PASS）
- [bugfix-rootcause-layered.md](testing/bugfix-rootcause-layered.md) — issue #37 DEC-014 两轮对抗（round 1: 1 Critical C1 + 4 Warning W1-W4 / round 2 post-fix 全 PASS；新 W5 非阻塞 + 3 nit follow-up；lint 0 命中）
- [tg-forwarding-expansion.md](testing/tg-forwarding-expansion.md) — issue #48 DEC-013 §3.1a 扩展对抗性 prompt 审查（1 Critical F13 措辞 + 7 Warning + 4 Suggestion + 2 Positive；post-fix inline 修 F13+F1/F2/F3/F4/F5/F10；F8/F9/F12/F14 follow-up；lint 0 命中）
- [phase-end-approval-gate.md](testing/phase-end-approval-gate.md) — issue #30 phase-end approval gate 对抗审查（2 Critical F1/F2 + 4 Warning F3-F6 + 4 Suggestion + 2 Positive；post-fix inline 修 F1-F6；F7-F10 follow-up；lint 0 命中）
- [reviewer-write-permission.md](testing/reviewer-write-permission.md) — issue #23 reviewer/tester/dba Write 权限明示对抗审查（1 Critical F4 兜底 contract + 3 Warning + 2 Suggestion + 3 Positive；post-fix 修 F4/F1/F5；F3 follow-up；lint 0）
- [faq-sink-protocol.md](testing/faq-sink-protocol.md) — issue #27 FAQ sink protocol 对抗审查（2 High F1/F2 + 4 Medium F3-F6 + 5 Low F7-F11；post-fix 修 F1-F6；F7-F11 follow-up；lint 0）
- [parallel-decisions.md](testing/parallel-decisions.md) — issue #28 DEC-016 §Step 4b 对抗性测试（0 Critical / 5 Warning W-01~W-05 / 4 Suggestion；4 条件对 7 决策点分类 100% 一致；14 dogfood 场景；W-01~W-05 orchestrator 全 inline fix）
- [reviewer-write-harness-override.md](testing/reviewer-write-harness-override.md) — issue #59 DEC-017 relay 反转契约对抗性测试（0 Critical / 3 Warning W1-W3 / 3 Suggestion / 5 Positive；A1-A12 对抗 + E1-E3 E2E；E1 本派发即 dogfood 通过 orchestrator relay；critical_modules 4 项命中）

### reviews

- [2026-04-19-step35-foreground-skip-monitor.md](reviews/2026-04-19-step35-foreground-skip-monitor.md) — issue #15 DEC-008 终审 Approve（0 Critical / 0 Warning / 0 new Suggestion / 4 Positive；tester 前轮 2 Critical + 3 Warning + 1 Suggestion 全修复复验通过）
- [2026-04-19-subagent-progress-and-execution-model.md](reviews/2026-04-19-subagent-progress-and-execution-model.md) — issue #7 终审（Approved with caveats：0 Critical / 3 Warning / 4 Suggestion，5 DEC 对齐 + user north-star 满足度 85%）
- [2026-04-19-phase-transition-rhythm.md](reviews/2026-04-19-phase-transition-rhythm.md) — issue #10 DEC-006 终审（Approved-with-caveats：0 Critical / 3 Warning / 5 Suggestion；DEC-001~DEC-005 全对齐；2C+W-08 已根因修复）
- [2026-04-19-progress-content-policy.md](reviews/2026-04-19-progress-content-policy.md) — issue #14 DEC-007 终审（Approve-with-caveats：0 Critical / 2 Warning / 3 Suggestion / 5 Positive；4 agent 逐字对称；推荐 back-feed fflush 到 design-doc §3.4）
- [2026-04-19-lightweight-review.md](reviews/2026-04-19-lightweight-review.md) — issue #9 DEC-009 终审（Approve-with-caveats：0 Critical / 3 Warning / 4 Suggestion / 5 Positive；DEC-001 D1-D9 + DEC-002~008 全保；decision-log 3 铁律遵守；DEC-004 schema 零改；lint 0 命中；W-01 已 post-fix）
- [2026-04-20-decision-log-entry-order.md](reviews/2026-04-20-decision-log-entry-order.md) — issue #18 DEC-011 终审（Approve with 1 Warning；0 Critical / 1 Warning / 3 Suggestion；W-01 Minimal header 无 DEC fallback + S1/S2 措辞 post-fix）
- [2026-04-20-dispatch-mode-strategy.md](reviews/2026-04-20-dispatch-mode-strategy.md) — issue #19 DEC-012 终审（Approve-with-caveats；0 Critical / 3 Warning / 2 Suggestion；W-01 section-number §3.4.5→§3.4 + W-03 Step 4 前置顺序 + S-01/S-02 全 post-fix）
- [2026-04-20-bugfix-rootcause-layered.md](reviews/2026-04-20-bugfix-rootcause-layered.md) — issue #37 DEC-014 终审（Approve-with-caveats；0 Critical / 3 Warning / 5 Suggestion；W1 PR 实施 commit 未推送 + W2 CLAUDE.md scope 溢出 + W3 INDEX 导航 table 已同步；tester 双轮 C1+W1-W4 闭环；critical_modules 1/6 命中必落盘）
- [2026-04-21-tg-forwarding-expansion.md](reviews/2026-04-21-tg-forwarding-expansion.md) — issue #48 DEC-013 §3.1a 扩展终审（Approve-with-caveats；0 Critical / 1 Warning W1 / 3 Suggestion R1-R3；tester post-fix 7 项全实质修复；验收 8/8；合入后跟进 R1+R2）
- [2026-04-21-dedupe-produce-created.md](reviews/2026-04-21-dedupe-produce-created.md) — issue #29 dedupe 产出/created 终审 (Approve；tester W1-W3 实质吸收；W4+S1-S3 follow-up)
- [2026-04-21-reviewer-write-permission.md](reviews/2026-04-21-reviewer-write-permission.md) — issue #23 reviewer/tester/dba Write 权限明示终审 (Approve-with-caveats；0 Critical / 3 Warning / 3 Suggestion / 5 Positive；自举 dogfood Step 7 兜底；F3 sentinel-vs-escalation follow-up issue 建议创建)
- [2026-04-21-faq-sink-protocol.md](reviews/2026-04-21-faq-sink-protocol.md) — issue #27 FAQ sink protocol 终审 (Approve-with-caveats；C1 Step 0.2→0.5 位置修复 + W1-W5 inline / S2/S4 inline；W3/S1/S3 follow-up；自举 dogfood Step 7 兜底 ×2)
- [2026-04-21-parallel-decisions.md](reviews/2026-04-21-parallel-decisions.md) — issue #28 DEC-016 §Step 4b 终审 (Approve-with-nits；0 Critical / 2 Warning R-W-01 R-W-02 / 3 Nit；R-W-01 overflow 行为 inline fix + R-W-02 retry cap follow-up；自举 dogfood Step 7 兜底：reviewer Write 被 harness override → orchestrator relay；#23 fix 未完全生效 follow-up issue)
- [2026-04-21-reviewer-write-harness-override.md](reviews/2026-04-21-reviewer-write-harness-override.md) — issue #59 DEC-017 终审 Approve（0 Critical / 2 Warning non-blocking / 4 Suggestion；DEC-017 决定 1-8 全落地；sentinel 协议完整删除；Refines DEC-006 纪律保持；E2 dogfood 通过 reviewer Write=0 + orchestrator relay）
- [2026-04-21-step7-relay-contract-tightening.md](reviews/2026-04-21-step7-relay-contract-tightening.md) — issue #65 DEC-019 Approve（0 Critical / 1 Warning non-blocking / 2 Suggestion；W1/W2/W3 全落地；Refines DEC-017 非 Supersede；diff ≤ 20 行；orchestrator relay 落盘）

### bugfixes

（Tier 2 postmortem 暂无条目；DEC-014）

## 主题 slug 约定

**文件名使用统一的"主题 slug"**，贯穿整个工作流便于关联：

- `analyze/[slug].md` → `design-docs/[slug].md` → `exec-plans/active/[slug]-plan.md` → `testing/[slug].md`
- 主题 slug 使用 kebab-case 英文，例：`roundtable`、`role-profile-system`

## 变更记录约定（三件套）

| 位置 | 记录什么 |
|------|---------|
| 文档内"变更记录"章节 | **改了什么、为什么改**（design-docs / exec-plans / analyze 都要有） |
| `log.md` | **哪个文档在何时被更新**（时间索引） |
| `decision-log.md` | **决策层面演进**（Superseded 机制） |

三者互补：log.md 是索引，变更详情在文档自己的"变更记录"章节里，决策演进走 decision-log。
