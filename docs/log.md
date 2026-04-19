# 操作日志

> append-only，新条目追加在顶部（最新在前）。
> 定位：**设计层文档的时间索引**（"何时、谁、动了哪份文档"）。

## 边界

**记录**：analyst 报告、architect design-docs / api-docs / exec-plan、DEC 条目、关键 review / test-plan **落盘**、lint 发现、冲突裁决。

**不记录**：
- 代码变更、skill/agent/command prompt 文件调整 → 归 `git log`，在 PR 描述里说清
- 文档内措辞 / 排版 / 小修订 → 归文档自己的"变更记录"章节
- 对话讨论、未落盘的审查 → 不入账

**合并原则**：同一 agent 在同一轮产出多份文档（如 architect 同时输出 design-doc + DEC + exec-plan），**合并为一条**，`影响文件` 列全部路径；不要拆成多条。

## 前缀规范

| 前缀 | 含义 | 示例 |
|------|------|------|
| `analyze` | analyst 产出新分析报告 | `analyze \| some-topic \| 2026-04-17` |
| `design` | architect 产出/更新设计文档 | `design \| roundtable \| 2026-04-17` |
| `decide` | 新增或变更设计决策 (DEC-xxx) | `decide \| DEC-001 \| 2026-04-17` |
| `exec-plan` | 产出或完成执行计划 | `exec-plan \| some-slug completed \| 2026-04-17` |
| `review` | reviewer/dba 完成关键审查（落盘的） | `review \| some-slug \| 2026-04-17` |
| `test-plan` | tester 产出测试计划 | `test-plan \| some-slug \| 2026-04-17` |
| `lint` | 健康检查发现的问题及处理 | `lint \| 3 issues found \| 2026-04-17` |
| `fix` | 裁决冲突后的修复 | `fix \| DEC-xxx updated \| 2026-04-17` |

## 条目格式

```markdown
## [前缀] | [标题/slug] | [日期]
- 操作者: [agent 名 / 用户]
- 影响文件: [文件列表]
- 说明: [一句话]
```

---

## review | progress-content-policy | 2026-04-19
- 操作者: reviewer subagent (critical_modules hit → 必落盘)
- 影响文件: docs/reviews/2026-04-19-progress-content-policy.md（新建）
- 说明: DEC-007 终审 Approve-with-caveats；0 Critical / 2 Warning / 3 Suggestion / 5 Positive；4 agent 正文逐字对称、DEC-004 schema 未动、DEC-002/005/006 正交；RW-01 推荐 closeout 前 back-feed `fflush()` 到 design-doc §3.4；RW-02 awk 末行延迟关联 issue #15

## test-plan | progress-content-policy | 2026-04-19
- 操作者: tester subagent (critical_modules hit → 必落盘)
- 影响文件: docs/testing/progress-content-policy.md（新建）
- 说明: DEC-007 对抗测试 25 cases；0 Critical / 3 Warning / 4 Suggestion；D1 原 issue #14 刷屏回归修复确认（5 identical → `(x5)`）；W-01 awk last-line hold 建议 orchestrator MonitorStop 缓解

## design | progress-content-policy + decide DEC-007 + plan progress-content-policy | 2026-04-19
- 操作者: architect skill (inline)
- 影响文件: docs/design-docs/progress-content-policy.md（新建）, docs/decision-log.md（新增 DEC-007）, docs/exec-plans/active/progress-content-policy-plan.md（新建）
- 说明: issue #14 follow-up of DEC-004 dogfood 刷屏；4 决策点 AskUserQuestion 确认完毕：共享 helper 文件 / 代理节拍门阁 / 复用 DEC-004 event 枚举 / 源端规范+awk 连续 dedup 兼底；不改 Monitor/DEC-004 schema/CLAUDE.md；待 design-confirm 后派 developer

## review | phase-transition-rhythm | 2026-04-19
- 操作者: reviewer subagent (critical_modules hit → 必落盘)
- 影响文件: docs/reviews/2026-04-19-phase-transition-rhythm.md（新建）
- 说明: DEC-006 最终合并审查；0 Critical / 3 Warning / 5 Suggestion；Approved-with-caveats；DEC-001~DEC-005 全对齐无 Superseded；lint 0 命中；建议合并前最小修 RW-01 onboarding.md 措辞漂移 + RW-02 design-doc §6 措辞（orchestrator 已 inline 修复）；RW-03 + RS-01~RS-05 延后

## fix | phase-transition-rhythm RW-01/RW-02 | 2026-04-19
- 操作者: orchestrator (inline)
- 影响文件: docs/onboarding.md (§3 第 75 行"每阶段都确认"改为 DEC-006 三段式措辞), docs/design-docs/phase-transition-rhythm.md (§6 变更记录措辞修正)
- 说明: reviewer flag 的 2 条 non-blocking drift；README.md 无需改（其现有描述兼容 DEC-006）；claude-md-template.md 无需改（属用户自填模板）

## test-plan | phase-transition-rhythm | 2026-04-19
- 操作者: tester subagent (critical_modules 1 项触发 — workflow command Phase Matrix + phase gating taxonomy)
- 影响文件: docs/testing/phase-transition-rhythm.md（新建）
- 说明: DEC-006 三段式对抗测试；2 Critical / 9 Warning / 5 Suggestion；C-01 悬空指针 (Step 6.5/6.6 不存在) + C-02 Step 7 批处理与 C 自动前进语义冲突；发 `<escalation>` 要求修复

## fix | phase-transition-rhythm Critical+W-08 | 2026-04-19
- 操作者: developer (inline, 主会话修 tester flag 的 2 Critical + 1 rule-violation Warning)
- 影响文件: commands/workflow.md (§Step 3 artifact chain +closeout row / §Step 6 规则 1 C 类 pointer 修正 + `<escalation>` scan 前置 / §Step 7 批处理加 DEC-006 C 桥接条款), docs/design-docs/phase-transition-rhythm.md (§3.1 同步 + 变更记录)
- 说明: C-01（Step 6.5/6.6 → Step 5+Step 6 rules 5–6）/ C-02（C-chain 每次 handoff 前 Step 7 flush；closeout 最终兜底）/ W-08（Step 3 artifact chain 加 closeout 行，满足 CLAUDE.md 条件触发规则）；lint 0 命中；其余 W-01~W-07/W-09~W-11 + S-01~S-05 留作后续 issue 跟进

## impl | phase-transition-rhythm | 2026-04-19
- 操作者: developer (inline 档，主会话执行)
- 影响文件: commands/workflow.md (§Phase Matrix +Stage 9 Closeout / §Step 6 规则 1 重写为三段式), CLAUDE.md (§critical_modules 条目 6 描述加 "+ phase gating taxonomy (DEC-006)")
- 说明: DEC-006 落实；lint_cmd 0 命中；不改 bugfix.md / agents/* / skills/* / 其他 DEC

## design | phase-transition-rhythm | 2026-04-19
- 操作者: architect (inline skill)
- 影响文件: docs/design-docs/phase-transition-rhythm.md（新建）, docs/decision-log.md（+DEC-006）
- 说明: issue #10 phase gating 三段式分类设计；Path B 路径 + 新 DEC-006（producer-pause / approval-gate / verification-chain）；Stage 9 Closeout 新增；6 个 analyst 开放问题全部裁决（Q3 reviewer 归 verification / Q4 design-confirm 保 AskUserQuestion / Q5 critical_modules 归 C 子项 / Q6 Closeout 新增 / Q1 新 DEC-006 / Q2 合入 Path B）；不 Supersede 任何既有 DEC

## analyze | phase-transition-rhythm | 2026-04-19
- 操作者: analyst (inline skill, 因 roundtable:analyst 未作为 plugin skill 注册，按 workflow.md 精神 Read + 主会话执行)
- 影响文件: docs/analyze/phase-transition-rhythm.md（新建）
- 说明: Issue #10 phase transition 节奏重构对标研究；调研 git/terraform/apt/kubectl/Make/CrewAI/AutoGen/LangGraph/Claude Code 9 种 CLI/orchestrator 的 stage transition UX；识别"产出 vs approval vs verification"三分类在工业界有先例但命名不统一；事实层 6 个开放问题交接 architect（DEC 归属、与现行 Exception 整合、reviewer 归类歧义、design-confirm UI 形式、critical_modules 机械触发定位、closeout 阶段是否新增）

## review | subagent-progress-and-execution-model | 2026-04-19
- 操作者: reviewer subagent (critical_modules 4+2 项全触发 → 必落盘)
- 影响文件: docs/reviews/2026-04-19-subagent-progress-and-execution-model.md（新建）
- 说明: 终审结论 Approved with caveats（0 Critical / 3 Warning / 4 Suggestion，非阻塞）。Critical 已在上轮修复且 reviewer 独立 jq 语义复验通过；3 Warning：W-R1 workflow.md §6b.2 示例两 recommended 违反 Option Schema / W-R2 bugfix.md §规则 2 `developer_form_default` 处理 inline 非对称 / W-R3 5 agent Bash emit 缺空值守卫。5 DEC 对齐 compliance: D2 ✓ / D8 ✓（正交补强不破）/ DEC-002 1 处示例违例（W-R1）/ DEC-003 ✓ / DEC-004 schema 一致性 ✓ / DEC-005 三级切换正确但 bugfix 不对称（W-R2）。user north-star 满足度 85%（实时感知 / 判断活着 / 关键点介入 / opt-out 均 High；判断卡住/快完了依赖 subagent 自觉 — push 模型固有）

## fix | subagent-progress-and-execution-model Critical | 2026-04-19
- 操作者: developer (inline 档，主会话执行)
- 影响文件: commands/workflow.md (§3.5.3 jq 模板 + 鲁棒性 Notes), commands/bugfix.md (§Step 0.5 inline jq 模板), docs/design-docs/subagent-progress-and-execution-model.md (§3.3 + §3.6 变更记录)
- 说明: 按用户裁决修 tester 标记的 Critical bug —— Monitor jq pipe 被单行非 JSON 击穿。`jq --unbuffered -c 'select(.event) | ...'` → `jq -R --unbuffered -c 'fromjson? | select(.event) | ...'`（-R 读 raw string，fromjson? 带问号 try-parse 在坏行时 silently no-op）；smoke 复验 3 合规 + 2 坏行 → 3 合规全过 exit 0；lint 0 命中

## test-plan | subagent-progress-and-execution-model | 2026-04-19
- 操作者: tester subagent (critical_modules 4 项全触发)
- 影响文件: docs/testing/subagent-progress-and-execution-model.md（新建）
- 说明: 对 issue #7 P0.1-P0.10 实施做对抗性测试；30+ case 覆盖 6 维度（JSON schema / Monitor 启动 / form 切换 / 正交性 / Phase Matrix / lint+smoke）；34 PASS / 4 FAIL / 18 WARN；发现 1 Critical（Monitor jq pipe 被单行非 JSON 击穿，后续 event 永久丢失）+ 5 Warning；产出 1 `<escalation>` 等待用户决策

## impl | subagent-progress-and-execution-model | 2026-04-19
- 操作者: 5× developer subagent (P0.1-P0.8 两批 4+4 并行) + orchestrator inline (P0.9-P0.10)
- 影响文件: agents/developer.md, agents/tester.md, agents/reviewer.md, agents/dba.md, agents/research.md, commands/workflow.md, commands/bugfix.md, docs/claude-md-template.md, CLAUDE.md, docs/exec-plans/active/subagent-progress-and-execution-model-plan.md（10 个 checkbox 全勾）
- 说明: issue #7 P0.1-P0.10 实施完成；lint 0 命中（regex 修正）；smoke 测试通过（3 event 过 jq 过滤格式对齐设计文档 §3.3）；progress + execution-model 机制已就绪待 tester 对抗测试

## design | subagent-progress-and-execution-model | 2026-04-19
- 操作者: architect (inline, 本会话) + Claude (orchestrator)
- 影响文件: docs/design-docs/subagent-progress-and-execution-model.md（新建）, docs/exec-plans/active/subagent-progress-and-execution-model-plan.md（新建）, docs/decision-log.md（+DEC-004 progress protocol +DEC-005 developer 双形态）
- 说明: 7 决策落定 —— 范围 A+B 合并 / developer 双形态（其他三角色仅 subagent）/ P1 push 模型 / phase checkpoint 颗粒度 / plugin 元协议 / 全部默认开启 / DEC-001 D8 正交补强；解 issue #7；exec-plan 10 phase 两批并行（P0.1-P0.8 4+4，P0.9-P0.10 串行）

## analyze | subagent-progress-and-execution-model | 2026-04-19
- 操作者: analyst (inline, 本会话执行)
- 影响文件: docs/analyze/subagent-progress-and-execution-model.md
- 说明: 对标 Claude Code subagent / Agent SDK / Monitor / transcript + CrewAI / AutoGen / LangGraph；列 6 条技术路径 + 8 条事实层开放问题交 architect；解 issue #7（subagent 进度可见性 + 执行模型可选配）

## design | parallel-research | 2026-04-19
- 操作者: architect (inline, 本会话) + Claude (orchestrator)
- 影响文件: docs/design-docs/parallel-research.md（新建）, docs/decision-log.md（+DEC-003）, skills/architect.md（§阶段 1 插入 3.5 Research Fan-out 子步骤）, agents/research.md（新建）
- 说明: 7 条决策落定 —— 独立 research agent / DEC-003 正交补充 D8 / Tool set (Read+Grep+Glob+WebFetch+WebSearch) / 扇出 ≤4 / 结构化 `<research-result>` JSON / abort-on-vague-scope / partial success；解 issue #2

## analyze | parallel-research | 2026-04-19
- 操作者: analyst (inline, 本会话执行)
- 影响文件: docs/analyze/parallel-research.md
- 说明: 对标 CrewAI / LangGraph / Claude Code sub-agents；12 事实层开放问题交 architect；解 issue #2 parallel research subagent dispatch

## test-plan | p4-self-consumption | 2026-04-18
- 操作者: Claude (observer) + 用户（gleanforge P4 session）
- 影响文件: docs/testing/p4-self-consumption.md（新建）, docs/exec-plans/active/roundtable-plan.md（勾 P4 checkbox + 更新进度 + 追加变更记录）
- 说明: P4 自消耗闭环在 gleanforge 项目完成：从零 build 到 P0 完成 + dry-run smoke 通过（9 次 subagent 派发 / 3 次并行 / 7 DEC / 242 tests 全绿）；落盘观察报告，识别 3 条 top 改进（共享资源协议 / agent→orchestrator 决策协议 / workflow command checklist 化）+ 9 条摩擦点 + 6 条工作良好设计；plugin 核心能力（skill+agent 双形态 / critical_module 触发 tester / exec-plan 共享契约 / 分级 review）通过端到端验证

## refactor | 抽取共享 skill `_detect-project-context` + lint 参数支持 | 2026-04-17
- 操作者: Claude + 用户
- 影响文件: skills/_detect-project-context.md（新建 114 行）, skills/architect.md（-51 行）, skills/analyst.md（-10 行；删除越权路径 + 合并重复追问框架）, commands/workflow.md, commands/bugfix.md, commands/lint.md（+13 行，加 argument-hint `$ARGUMENTS`，支持子项目名 / 绝对路径 / `.`）
- 说明: 用户指出 analyst "复用 architect 开工第一步" 是伪依赖、架构师列分析师路径越权、追问框架重复、lint 过度挂 architect。抽出 `_detect-project-context` shared skill 作为 D9 + 工具链 + docs_root + CLAUDE.md 加载的单一权威源，其他 skill / command 都 thin delegate；analyst 合并追问框架 + 删越权；lint 增加参数支持。硬编码扫描仍 0 命中

## docs | P3 用户文档 + 模板 + onboarding | 2026-04-17
- 操作者: Claude + 用户
- 影响文件: docs/claude-md-template.md (139 行), docs/onboarding.md (125 行), docs/migration-from-local.md (139 行), examples/rust-backend-snippet.md (80 行), examples/ts-frontend-snippet.md (89 行), examples/python-datapipeline-snippet.md (93 行), docs/INDEX.md（更新链接）
- 说明: P3 用户向文档完成。claude-md-template.md 是核心（完整模板 + 填写提示 + FAQ + 最小可用示例）；onboarding.md 5 分钟上手手册；migration-from-local.md 给已有本地 `.claude/` 的项目的迁移 runbook；3 个 examples 片段覆盖 Rust 后端 / TS 前端 / Python 数据管道典型场景

## feat | P2 批量通用化剩余 5 角色 + 2 命令 | 2026-04-17
- 操作者: Claude + 用户
- 影响文件: skills/analyst.md (新建 157 行), agents/developer.md (163 行), agents/tester.md (163 行), agents/reviewer.md (130 行), agents/dba.md (134 行), commands/bugfix.md (97 行), commands/lint.md (106 行)
- 说明: 基于 P1 已验证的机制批量通用化。skill 形态：analyst（六问框架 + 研究澄清 AskUserQuestion）。agent 形态（subagent 隔离 + AskUserQuestion 不可用，需调度方注入上下文变量）：developer（plan-then-code + 自动工具链检测）、tester（对抗性 + benchmark + critical_modules 触发）、reviewer（决策一致性审查 + 按 critical_modules 落盘）、dba（schema/SQL/迁移审查，支持 PG/MySQL/SQLite/等多种 DB 类型自动识别）。command：bugfix（跳过 design，强制回归测试）、lint（8 项文档健康检查，纯只读报告）。全部 7 个新文件通过硬编码 grep 扫描 0 命中

## verify | P1 POC 方式 A 端到端通过 | 2026-04-17
- 操作者: 用户（Claude Code 真实会话）+ Claude
- 影响文件: docs/exec-plans/active/roundtable-plan.md（勾选方式 A 验收项）
- 说明: `claude --plugin-dir` 从 workspace 根启动；`/roundtable:workflow` 命令被识别；architect skill 激活；**D9 目标项目识别 AskUserQuestion 原生弹窗触发且可点选** —— 证明零 userConfig + Skill 形态 + AskUserQuestion 机制在 Claude Code 端到端可工作。方式 B（子项目内启动 git rev-parse 短路）及 design-doc 落盘路径 / CLAUDE.md 加载验证，待下一轮真实设计任务时观察

## feat | P1 POC：architect skill + workflow command | 2026-04-17
- 操作者: Claude + 用户
- 影响文件: skills/architect.md（新建，242 行）, commands/workflow.md（新建，118 行）
- 说明: P1 首批通用化产出 —— `skills/architect.md` 包含项目上下文识别（D9 + 工具链检测 + CLAUDE.md 加载）、三阶段工作流、AskUserQuestion 强制规则、design-doc / exec-plan / api-doc 模板；`commands/workflow.md` 实现规模判断 + 编排逻辑（skill 用 Skill 工具激活、agent 用 Task 派发时注入 target_project 上下文）；零业务术语硬编码，全部走占位符 + 运行时检测 / CLAUDE.md 声明

## design | roundtable (含 DEC-001 + exec-plan) | 2026-04-17
- 操作者: Claude (architect) + 用户
- 影响文件: docs/design-docs/roundtable.md, docs/decision-log.md, docs/exec-plans/active/roundtable-plan.md
- 说明: roundtable plugin 初始设计文档落盘；确认 D1-D9 九项关键决策并记入 DEC-001；产出 P0-P6 六阶段实施计划
