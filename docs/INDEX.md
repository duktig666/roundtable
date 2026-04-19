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

## 当前文档清单

### analyze

- [parallel-research.md](analyze/parallel-research.md) — architect 派发 parallel research subagent 能力的对标调研（CrewAI / LangGraph / Claude Code sub-agents，12 事实层开放问题交 architect）
- [subagent-progress-and-execution-model.md](analyze/subagent-progress-and-execution-model.md) — subagent 进度可见性 + 执行模型选择 5 路径对比（Claude Code/SDK/Monitor + CrewAI/AutoGen/LangGraph；8 事实层开放问题交 architect，解 issue #7）
- [phase-transition-rhythm.md](analyze/phase-transition-rhythm.md) — issue #10 workflow phase transition 节奏对标研究（git/terraform/apt/kubectl/Make/CrewAI/AutoGen/LangGraph/Claude Code 9 种 CLI/orchestrator UX；6 事实层开放问题交 architect）
- [lightweight-review.md](analyze/lightweight-review.md) — issue #9 轻量化审计（archive 826 vs 现状 2708 行 = 3.16× / 8 个 DEC 增量分类 / 3 大抽取热区 DEC-002/004/007 / 7 事实层开放问题）

### design-docs

- [roundtable.md](design-docs/roundtable.md) — roundtable plugin 本身的完整设计（D1-D9 决策 + 量化评分 + §12 FAQ）
- [parallel-research.md](design-docs/parallel-research.md) — architect skill 派发 parallel research subagent 的完整设计（7 条决策，DEC-003 锁定；触发条件 / 派发协议 / 返回 schema / 失败处理 / 并行安全论证）
- [subagent-progress-and-execution-model.md](design-docs/subagent-progress-and-execution-model.md) — subagent progress 透传（P1 push）+ developer 双形态（inline \| subagent）设计，解 issue #7；DEC-004 + DEC-005 落定
- [phase-transition-rhythm.md](design-docs/phase-transition-rhythm.md) — issue #10 workflow phase gating 三段式分类设计（producer-pause / approval-gate / verification-chain + Stage 9 Closeout），DEC-006 落定
- [progress-content-policy.md](design-docs/progress-content-policy.md) — issue #14 subagent progress 内容策略（代理节拍 / 去重 / 差异化 / 终止-失败分离），DEC-007 落定；补丁 DEC-004
- [lightweight-review.md](design-docs/lightweight-review.md) — issue #9 轻量化重构（DEC-009 Proposed；4 shared helper 抽取 + log.md closeout batching + README/CLAUDE.md 结构重塑；预估省 22-25%）

**Plugin 内部 include-only helper**（下划线前缀约定；非独立可激活 skill；不在用户向 skill 清单露出）：

- `skills/_detect-project-context.md` — 4 步 target-project 识别 + toolchain + docs_root + CLAUDE.md 加载（被 workflow / bugfix / lint / architect / analyst 5 方引用）
- `skills/_progress-content-policy.md` — DEC-007 subagent progress 内容策略（被 developer / tester / reviewer / dba 引用）

### exec-plans

- active/
  - [roundtable-plan.md](exec-plans/active/roundtable-plan.md) — roundtable umbrella 实施计划（P0-P4 完成；P5 外部试装 + P6 v0.1 发布未做；24 个 unchecked 主要在 v0.1 release 环节）
- completed/
  - [lightweight-review-plan.md](exec-plans/completed/lightweight-review-plan.md) — issue #9 轻量化重构（DEC-009 + DEC-010 Accepted；tree 2708→1672 / -38%；PR #17 merged）
  - [subagent-progress-and-execution-model-plan.md](exec-plans/completed/subagent-progress-and-execution-model-plan.md) — issue #7 + DEC-004/005/008（26 checkbox 全勾；PR #16 merged）
  - [progress-content-policy-plan.md](exec-plans/completed/progress-content-policy-plan.md) — issue #14 DEC-007（P0.1-P0.4 完成；PR #16 merged；归档时补勾 18 checkbox）

### testing

- [p4-self-consumption.md](testing/p4-self-consumption.md) — P4 自消耗闭环观察报告（gleanforge dogfood 实录：9 subagent 派发 / 3 次并行 / 242 tests / 3 条 top 改进 + 9 摩擦点 + 6 条工作良好设计）
- [subagent-progress-and-execution-model.md](testing/subagent-progress-and-execution-model.md) — issue #7 P0.1-P0.10 对抗性测试（30+ case / 34 PASS + 4 FAIL + 18 WARN / 1 Critical escalation：Monitor jq pipe 被单行非 JSON 击穿）
- [phase-transition-rhythm.md](testing/phase-transition-rhythm.md) — issue #10 DEC-006 三段式对抗测试（2 Critical / 9 Warning / 5 Suggestion；C-01 悬空指针 + C-02 Step 7 与 C 自动前进语义冲突）
- [progress-content-policy.md](testing/progress-content-policy.md) — issue #14 DEC-007 对抗测试（25 cases：0 Critical / 3 Warning / 4 Suggestion；D1 原 dogfood 刷屏回归修复确认 `(x5)`）
- [step35-foreground-skip-monitor.md](testing/step35-foreground-skip-monitor.md) — issue #15 DEC-008（workflow §3.5.0 前台派发免 Monitor gate）对抗测试（18 cases：2 Critical / 3 Warning / 1 Suggestion → post-fix 全绿）
- [lightweight-review.md](testing/lightweight-review.md) — issue #9 DEC-009 轻量化重构对抗测试（19 cases：1 Critical 升级为 Warning / 5 Warning；W-01 design-doc §5 决定编号漂移 7/8/9→8/9/10 已 post-fix；A6 helper role-specific 泄漏已清；D1/E2/B2/F2 post-fix 全绿）

### reviews

- [2026-04-19-step35-foreground-skip-monitor.md](reviews/2026-04-19-step35-foreground-skip-monitor.md) — issue #15 DEC-008 终审 Approve（0 Critical / 0 Warning / 0 new Suggestion / 4 Positive；tester 前轮 2 Critical + 3 Warning + 1 Suggestion 全修复复验通过）
- [2026-04-19-subagent-progress-and-execution-model.md](reviews/2026-04-19-subagent-progress-and-execution-model.md) — issue #7 终审（Approved with caveats：0 Critical / 3 Warning / 4 Suggestion，5 DEC 对齐 + user north-star 满足度 85%）
- [2026-04-19-phase-transition-rhythm.md](reviews/2026-04-19-phase-transition-rhythm.md) — issue #10 DEC-006 终审（Approved-with-caveats：0 Critical / 3 Warning / 5 Suggestion；DEC-001~DEC-005 全对齐；2C+W-08 已根因修复）
- [2026-04-19-progress-content-policy.md](reviews/2026-04-19-progress-content-policy.md) — issue #14 DEC-007 终审（Approve-with-caveats：0 Critical / 2 Warning / 3 Suggestion / 5 Positive；4 agent 逐字对称；推荐 back-feed fflush 到 design-doc §3.4）
- [2026-04-19-lightweight-review.md](reviews/2026-04-19-lightweight-review.md) — issue #9 DEC-009 终审（Approve-with-caveats：0 Critical / 3 Warning / 4 Suggestion / 5 Positive；DEC-001 D1-D9 + DEC-002~008 全保；decision-log 3 铁律遵守；DEC-004 schema 零改；lint 0 命中；W-01 已 post-fix）

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
