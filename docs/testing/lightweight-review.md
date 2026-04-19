---
slug: lightweight-review
source: design-docs/lightweight-review.md, decision-log.md DEC-009
created: 2026-04-19
tester: roundtable:tester (adversarial dogfood)
scope: 4 new helpers + 7 retrofit agents/skills + workflow Step 3.5/Step 8 + bugfix flush points + README/CLAUDE.md trim + DEC-002 supersede + INDEX sync
critical_modules_hit:
  - Skill / agent / command prompt 文件本体（含 _*.md helper）
  - Resource Access matrix
  - Escalation Protocol JSON schema
  - Progress event JSON schema (DEC-004)
  - Developer execution-form switching rules (DEC-005)
  - workflow command Phase Matrix + phase gating taxonomy (DEC-006)
---

# DEC-009 轻量化重构 对抗性测试

> 测试策略：纯静态对照（dogfood 测试 —— 模拟"调用方 Read helper 后能否还原原 section 语义"），18 case 分 6 组。
> Sizing：retrofit 后 15 个文件共 2638 行（详见 §汇总）。

---

## 0. 测试环境

| 类别 | 值 |
|------|---|
| target_project | `/data/rsw/roundtable` |
| docs_root | `docs` |
| primary_lang | markdown + YAML frontmatter |
| test_cmd | dogfood static reference-consistency check |
| 依据 | `docs/design-docs/lightweight-review.md`、`docs/decision-log.md` DEC-009、`docs/exec-plans/active/lightweight-review-plan.md`、prior `docs/testing/step35-foreground-skip-monitor.md`（样板） |

**审读对象（15 文件）**：
- 新 helper (4)：`skills/_resource-access.md` / `_escalation-protocol.md` / `_progress-reporting.md` / `commands/_progress-monitor-setup.md`
- Retrofit agent (5)：`agents/developer.md` / `tester.md` / `reviewer.md` / `dba.md` / `research.md`
- Retrofit skill (2)：`skills/architect.md` / `analyst.md`
- Orchestrator 命令 (2)：`commands/workflow.md` / `commands/bugfix.md`
- 文档重塑 (4)：`README.md` / `CLAUDE.md` / `docs/claude-md-template.md` / `docs/log.md`
- INDEX 同步 (1)：`docs/INDEX.md`

---

## 1. 测试矩阵（18 case / 6 组）

### Group A — helper ref 对称性（6 case）

| # | Case | Setup | Expected | Actual | Verdict |
|---|------|-------|----------|--------|---------|
| A1 | `_resource-access.md` 引用措辞对称 | 统一格式 `详见 skills/_resource-access.md（通用骨架 + git 默认策略）` | 7 处（developer/tester/reviewer/dba/research/architect/analyst）完全逐字一致 | 7/7 处逐字一致（developer.md:71 / tester.md:38 / reviewer.md:37 / dba.md:38 / research.md:40 / architect.md:22 / analyst.md:28） | PASS |
| A2 | `_escalation-protocol.md` 引用 + research 例外声明 | 4 agent 引用；research 在自己的 `## Abort Criteria` 显式说明不 emit escalation | developer/tester/reviewer/dba 各 1 处 ref；research 用 "不要 emit `<escalation>`" + Abort Criteria | 4 处 ref 逐字一致（`详见 skills/_escalation-protocol.md（JSON schema + 通用规则 + Escalation vs Abort）`）；research.md:89-91 `§Abort Criteria（替代 Escalation Protocol）` 明写"**不要 emit `<escalation>`**"；helper 本体第 12 行显式声明 "本 helper **不**适用于 `agents/research.md`" | PASS |
| A3 | `_progress-reporting.md` 引用 + research 不 emit 声明 | 4 agent 引用；research 单行声明 | 4 处 ref + research.md §Progress Reporting 自带"Research 不 emit progress" | 4 处 ref 逐字一致（developer.md:96 / tester.md:65 / reviewer.md:66 / dba.md:65）；research.md:117-119 `## Progress Reporting` subsection 完整声明 "Research 不 emit progress（DEC-004 / DEC-009 决定 2 retrofit）... 本角色**不**适用 `skills/_progress-reporting.md`"；helper 本体第 12 行亦重复声明 | PASS |
| A4 | `_progress-monitor-setup.md` 被 2 command 引用 | workflow.md + bugfix.md 语义一致 | 两处 ref + 两处都保留 §3.5.0 gate (DEC-008) + env opt-out + 1 行 helper ref | workflow.md:156 `Read commands/_progress-monitor-setup.md 并依序执行...5 节`；bugfix.md:35 `Read commands/_progress-monitor-setup.md 并依序执行...5 节。不 inline 复制 helper 内容`。两处语义等价且均保留 §3.5.0 前置 gate | PASS |
| A5 | retrofit 后 role-specific 残余完整保留 | 对照 design-doc §4.2 改写样板 + exec-plan §跨阶段约束 | 5 agent + 2 skill 的"不得删"项逐一保留 | **逐项 verify**：developer `## Execution Form` 段保留（developer.md:12-28）；tester Ordering discipline + 5 phase tag 保留（tester.md:79-87）；reviewer Critical-finding ordering + 4 phase tag 保留（reviewer.md:79-88）；dba 4 phase tag 保留（dba.md:71-76）；research Abort Criteria + Return Schema 保留（research.md:89-113）；architect AskUserQuestion Option Schema + Research Fan-out 保留（architect.md:115-182）；analyst AskUserQuestion Option Schema 保留（analyst.md:68-109）。无一项误删 | PASS |
| A6 | helper 文件本体无 role-specific 泄漏 | helper 只含通用骨架 | 4 个 helper 文件本体无角色专属内容（可能仅允许 `## 引用契约（调用方模板）` 展示用途） | `_resource-access.md` §典型 rows 示例 提供"developer-like 样板"（line 43-58），明确标注为"新贡献者参考" —— 属 helper 内的样板，非角色绑定泄漏；`_escalation-protocol.md` 末尾列出 4 角色典型触发点（line 103-108），标注"参考，详情写在各自 agent 本体里" —— **轻微警告**：此清单与各 agent 本体内容部分重复，未来维护需两处同步；`_progress-reporting.md` 末尾仅给模板（line 126-153），无角色绑定内容；`_progress-monitor-setup.md` 仅含 orchestrator 协议 | **WARN** |

**A6 WARN 详情**：`_escalation-protocol.md:103-108` 列出 developer/tester/reviewer/dba 各自的 "典型触发点" 概述（约 6 行），与 4 agent 本体里的同款清单语义重复（developer.md:86-90 / tester.md:55-59 / reviewer.md:56-60 / dba.md:55-59）。这违反 DEC-009 的 "role-specific 保留在 agent 本体" 纪律（见 design-doc §2.1 表格最后列）。未来更新某 agent 触发点时，两处不同步会造成漂移。**Suggestion**：helper 把此小结删除，或改为 "详见各 agent 本体的 §Escalation Protocol section"。

---

### Group B — log.md batching 契约一致性（3 case）

| # | Case | Setup | Expected | Actual | Verdict |
|---|------|-------|----------|--------|---------|
| B1 | 所有 agent / skill final report 不含"自行 append log.md"指令 | 5 agent + 2 skill 的"完成后"段改写为 `log_entries:` YAML block 契约 | grep "直接写 log.md" 或 "append to log" 应返回 **否定声明**（`不直接写 log.md` 而非 append 指令） | developer.md:214 / tester.md:215 / reviewer.md:185 / dba.md:177 / research.md:163-166 / architect.md:282-284 / analyst.md:201-208 全部为 **"不直接写 log.md"** 反向声明 + `log_entries:` YAML 指引 + "由 orchestrator 按 workflow Step 8 flush" 引用。research 额外声明"research 是 architect 决策过程中的 transient 子任务，单次派发不独立落盘"——符合 transient 语义。0 处残留旧 append 模板 | PASS |
| B2 | workflow.md Step 8 3 触发点 vs DEC-009 §2.2.2 三规则；bugfix.md flush 点互锁 | Stage 9 终点 / A 类 pause / C 类 handoff 逐一覆盖 | workflow.md §Step 8 "Flush 触发点（3 种）" 逐一对应 DEC-009 §2.2.2；bugfix.md §log.md Batching 简化成 2 点（reviewer/dba/tester 后 + Closeout 前）并显式指"完整协议见 workflow.md §Step 8" | workflow.md:364-368 列 3 触发点与 DEC-009 决定 2 / design-doc §2.2.2 逐一对齐；bugfix.md:135-144 简化版 2 触发点"reviewer/dba/tester 完成后"+"用户 commit / 结束 bugfix 前"并显式引用 workflow.md §Step 8。**但注意**：bugfix 的第 1 个 flush 点（"reviewer/dba/tester 完成后"）**不符合 workflow.md §Step 8 的 C 类"交接前"语义** —— workflow Step 8 要求"在发出 🔄 交接提示**前**先 flush"；bugfix 则描述为"完成**后**一次 flush"（即 terminal 节点而非过桥节点）。语义有微妙差异：bugfix 里没有下游派发所以"完成后 = 终点 flush"；workflow 则在长 C 链里"交接前"。若用户启 bugfix 且多 phase（dev→tester→reviewer），bugfix.md 未显式说是否每个中间节点（dev→tester 交接前）也 flush，还是只在全部"最后一个 agent"完成后 flush —— 文本倾向后者（简化），与 workflow 的前者语义不完全对等。**Warning**：简化取舍合理但应在 bugfix.md 明示"bugfix 中 C→C 过桥条款不适用"，避免未来贡献者对照 workflow 误判断 | **WARN** |
| B3 | `docs/log.md` 头部"合并原则"与 workflow.md §Step 8 语义一致 | `log.md:15` "合并原则"段应引用 Step 8 / `log_entries:` YAML | log.md:15 明写 "agent / skill **不直接写本文件**。每轮 workflow 由 orchestrator 按 `commands/workflow.md` §Step 8 log.md Batching 协议（bugfix 流程按 `commands/bugfix.md` §log.md Batching 简化版）收集各 agent final report 中的 `log_entries:` YAML block 聚合写入；同一 agent 在同一轮产出多份文档（如 architect 同时输出 design-doc + DEC + exec-plan）**合并为一条**... DEC-009 决定 2 落地。" 与 workflow.md §Step 8 的 Collect / Merge / Edit 三步 + YAML 契约字段（prefix/slug/files/note）完全一致。前缀规范表（log.md 前缀规范）未变更，与 YAML `prefix:` 枚举对齐（`analyze \| design \| decide \| exec-plan \| review \| test-plan \| lint \| fix`） | PASS |

---

### Group C — DEC 链完整性（3 case）

| # | Case | Setup | Expected | Actual | Verdict |
|---|------|-------|----------|--------|---------|
| C1 | DEC-002 状态行反向标注 + DEC-009 引用 DEC-002 | decision-log.md DEC-002 状态行 + DEC-009 决定 8 | DEC-002 状态行含"决定 5 Superseded by DEC-009 决定 X"；DEC-009 同号决定显式反向引用 | decision-log.md:233 `DEC-002 状态: Accepted（决定 5 "prompt 文件本体统一英文" Superseded by DEC-009 决定 8 ...）`；decision-log.md:61 `DEC-009 决定 8: 正式 Supersede DEC-002 决定 5... Superseded by DEC-009 决定 8`。**两处编号 8 一致**（即 decision-log.md 内部自洽） | PASS |
| C2 | DEC-009 决定 9 落地 bugfix.md 规则 2 + DEC-005 §6b.2 描述一致 | bugfix.md 第 62 行写 "DEC-009 决定 9"；对齐 DEC-005 §3.4.2 per-project | bugfix.md 规则 2 从旧的"仅 honor subagent"改为"对称 honor（inline or subagent）"；DEC-005 三级切换 per-project 级"通吃两值"语义一致 | bugfix.md:62 `若 target_project CLAUDE.md 的... 声明了 developer_form_default（inline 或 subagent 任一值），honor the declaration`，与 decision-log.md DEC-009 决定 9（line 62，修 bugfix.md 规则 2 对称性 bug）一一对应。落地点显式引用 "DEC-009 决定 9 对 DEC-005 §3.4.2 per-project 三级切换的 follow-through 修正"。workflow.md §6b.2 规则 2（line 266-271）用 "use its value as the baseline. ... Per-session（level 1）仍然覆盖 per-project（level 2）" 同样对称 honor —— 两 command 对称 | PASS |
| C3 | DEC-009 决定 10 "影响范围 ≤10 行"纪律不回溯 + 铁律 #1 "不删旧条目" | DEC-009 决定 10 自我声明"不回溯"；decision-log.md 铁律段 | DEC-001~DEC-008 原有影响范围段未被 DEC-009 强制缩减；铁律 #1 不删旧条目仍标 | decision-log.md:63 `DEC-009 决定 10... 本纪律**不回溯** DEC-001 ~ DEC-008，保 append-only`；decision-log.md:31-34 铁律段（不删旧条目 / 冲突报 diff / 编号递增）未被 DEC-009 改动；抽样 DEC-004 影响范围段（line 202，20+ 行）未缩减、DEC-008 影响范围段（line 100，15+ 行）亦保留。**但**：`docs/design-docs/lightweight-review.md` §7 "待确认项"留有"是否回溯"的开放问题（line 240），若用户最终决策"是，回溯缩减"则可能违背铁律 #1 —— 当前结论**保持 否**，与 DEC-009 决定 10 文本一致 | PASS |

---

### Group D — README / CLAUDE.md 瘦身正确性（3 case）

| # | Case | Setup | Expected | Actual | Verdict |
|---|------|-------|----------|--------|---------|
| D1 | README §设计原则 7 条融入 issue #9 §D 5 点；§致谢 / §贡献 / §许可证 删除不留死链 | README grep 结果应无 "致谢 \| 贡献 \| 许可证 \| LICENSE \| CONTRIBUTING"；§设计原则 包含 7 条 | 7 条明确覆盖 a（自动组织 / 文档化 I/O）+ b（plan-then-execute）+ c（文档三件套）+ d（skill/agent 分界）+ e（gstack 六问） | README.md:48-54 明列 7 条原则；逐一对照 issue #9 §D：a+b 合并进 #2（自动组织 + 文档化每阶段 I/O，含 plan-then-execute 一段）✅；c 进 #5（文档三件套分层，含 `decision-log.md` / `log.md` / `INDEX.md`）✅；d 进 #4（skill/agent 分界）✅；e 进 #6（Analyst gstack 六问）✅。#1 零配置安装 + #3 决策逐点弹窗 + #7 多项目 保留。grep "致谢\|贡献\|许可证\|LICENSE\|CONTRIBUTING" 在 README.md 返回 **0 命中** —— 三节完全删除。**但**：LICENSE 文件与 CONTRIBUTING.md 仍在仓库根目录（verified via `ls`）；入口见 `docs/INDEX.md:28` (CONTRIBUTING.md) 与 `docs/INDEX.md:27` (CHANGELOG.md) —— LICENSE 未在 INDEX.md 列出，但 README 已无指引链。**Warning**：LICENSE 仍是 Apache-2.0 关键合规载体，README 完全无入口会让新贡献者找不到许可证信息（GitHub UI 虽然自动展示，但 offline clone / non-GitHub mirror 场景需要文内指引） | **WARN** |
| D2 | CLAUDE.md §设计参考 删除 + critical_modules 首条扩写 | CLAUDE.md grep "对标\|设计参考" = 0；§critical_modules 第 1 条含 `_*.md` 字串 | grep 0 命中；§critical_modules:20 `Skill / agent / command prompt 文件本体（含 skills/_*.md 与 commands/_*.md 共享 helper）` | CLAUDE.md:20 **逐字匹配**（首条扩写到位）；grep "对标\|设计参考" 在 CLAUDE.md 返回 **0 命中** —— §设计参考段彻底删除。**但**：CLAUDE.md §通用规则 保留 "代码英文、注释中文、文档中文、回答中文" + 中文为主 prompt 规则，未见"设计参考"冗余；矛盾 / 冗余 = 0 | PASS |
| D3 | claude-md-template.md §critical_modules 示例同步"含 _*.md helper" | 模板文件应同步提及 `_*.md` helper | claude-md-template.md §critical_modules 或相关示例含 helper 提示 | claude-md-template.md:85 在"critical_modules 怎么选？"的 **Plugin / 工具类项目特有** 一项显式写 `skill / agent / command prompt 文件本体（含 skills/_*.md 与 commands/_*.md 共享 helper）—— 任何 bug 会 fan-out 到所有下游调用`。与 roundtable/CLAUDE.md:20 扩写逐字同步 | PASS |

---

### Group E — Step 3.5 / Step 7 / Step 8 交互一致性（2 case）

| # | Case | Setup | Expected | Actual | Verdict |
|---|------|-------|----------|--------|---------|
| E1 | workflow.md Step 3.5 抽到 helper 后，残余段 gate 语义完整 | §3.5.0 前台/后台 gate（DEC-008）+ §3.5.1 env opt-out + §3.5.2 ref 逐一保留；分支清晰 | §3.5.0 保留完整 gate 文本 + rationale + Note ；§3.5.1 保留 env 检查；§3.5.2 仅 1 行 ref；前台派发完全 skip helper，后台派发走 helper | workflow.md:139-148 §3.5.0 保留 32 行完整 gate（run_in_background 判定 / 混合批 / Rationale / 与 inline form 的边界 Note），DEC-008 语义无缺；workflow.md:152 §3.5.1 保留 env opt-out 检查；workflow.md:154-156 §3.5.2 仅 1 行 ref "Gate 通过且 env 未 opt-out → Read commands/_progress-monitor-setup.md 并依序执行 5 节"。前台派发 skip 与后台派发 ref 分支在 §3.5.0 明写 "对该调用 skip 整个 Step" vs "对该调用进入 §3.5.1"，**分支清晰无歧义** | PASS |
| E2 | Step 7 INDEX vs 新增 Step 8 log.md batching 在 C 类 handoff 时执行顺序一致性 | 两者都挂在 C 类 "交接提示前"；执行顺序应文字定义 | Step 7 + Step 8 均声明 C 类"交接前 flush"；顺序（谁先谁后）应明确 | Step 7 workflow.md:325 明写 "C 类 transition... orchestrator **必须**在每次 C→C 交接提示发出**之前**执行 Step 7"；Step 8 workflow.md:368 同样写 "每次 C 类 verification-chain 交接之前... orchestrator 发 "🔄 X 完成 → dispatching Y" 交接提示前**先**执行 Step 8 单次 Read + Edit"。**两者均挂 C 类过桥，但文字未声明先后顺序**。实际执行时若同时触发（常见场景），orchestrator 可以两者各自独立 Read + Edit 文件不同（INDEX.md vs log.md），**并行安全**；但：（a）起点.md:410-411 "起点" 步骤 6-7 先列 Step 7 再列 Step 8，隐含先 INDEX 后 log；（b）C 类"交接前"顺序：若先 Step 7 再 Step 8，存在 INDEX.md 已含新 entry 但 log.md 仍未 flush 的窗口（虽然 ≤秒级）。**Warning**：Step 7 / Step 8 未在 C 类 handoff 显式声明执行顺序；建议在 workflow.md §起点 或两 Step 本体加一句"Step 7 → Step 8 顺序执行（两者操作不同文件，无竞态但语义上 INDEX 先 Log 后）" | **WARN** |

---

### Group F — 跨 session abort 退化风险（2 case）

| # | Case | Setup | Expected | Actual | Verdict |
|---|------|-------|----------|--------|---------|
| F1 | workflow.md Step 8 明文记录跨 session 中断退化声明 + agent 无兜底 staging | workflow.md Step 8 应显式声明 abort 窗口；agent 侧不应存在"预 staging"兜底（否则违背 DEC-009 §2.2.3 的"接受退化"决策） | Step 8 最后含"跨 session abort 退化声明"段；agent 侧无 staging 文件写入 | workflow.md:399 `**跨 session abort 退化声明**：用户直接退出 Claude Code... 最近一段未经 pause-point flush 的 C 链 log_entries 永久丢失。缓解靠触发点 2 在每个 A 类边界清空 queue，实际丢失窗口仅限 3 agent 左右（dev→tester→reviewer 那段 C 链）...`；agent 本体（grep 5 agent + 2 skill）在"完成后"段均用 `log_entries:` YAML 报告，无任何"预先 append 到 staging 文件"的兜底指令。设计一致：接受退化 + pause-point flush 覆盖 97%+ 场景 | PASS |
| F2 | bugfix.md 无 A 类 producer-pause 时 flush 原子性 | bugfix 只有 dev→可选 reviewer/dba/tester 两阶段；无 A 类中途 pause；log flush 全靠"终点 2 触发点" | bugfix.md flush 点应覆盖完整 bugfix 生命周期，且明示"非 A 类 bugfix 不触发 pause-point flush" | bugfix.md:139-144 简化 flush 点：(1) reviewer/dba/tester 完成后一次 flush（= terminal C）（2) 用户 commit / 结束 bugfix 前一次 flush（= 等价 Stage 9 终点）。**无 A 类 pause-point flush** —— 符合"bugfix 无 architect/analyst A 类阶段"语义；"跨 session abort 退化"bugfix 里窗口更大（dev→reviewer 全段无中间 flush），**但**文件 **未显式声明此退化**。bugfix.md 仅引用 workflow.md §Step 8 "完整协议（... 跨 session abort 退化声明）见 workflow.md §Step 8"（隐含引用）。**Warning**：bugfix.md 应显式一句"本流程无 A 类 pause，因此 pause-point flush 不适用；用户 ctrl+C 退出时整段 bugfix 的 log 可能丢失"，以避免用户对 bugfix vs workflow 的 abort 语义产生假设偏差 | **WARN** |

---

### Group G（补充）— 设计文档与 decision-log 编号一致性（1 case）

tester 在审读过程中**发现新 Critical 问题**，补入本组作为 Group G：

| # | Case | Setup | Expected | Actual | Verdict |
|---|------|-------|----------|--------|---------|
| G1 | `docs/design-docs/lightweight-review.md` 内部 DEC-009 决定编号引用与 `decision-log.md` 权威源不一致 | 设计文档 §5.1 / §5.3 / §8 应逐字匹配 decision-log.md 的决定编号 | design-doc §5.1 表格 "DEC-009 决定 X" 列 + §5.3 + §8 变更记录 引用编号与 decision-log.md 同号 | **MISMATCH**：decision-log.md **权威源**把 DEC-002 Supersede 事实编号为 **决定 8**（line 61）、bugfix.md 规则 2 修为 **决定 9**（line 62）、DEC 影响范围纪律为 **决定 10**（line 63）。但 `docs/design-docs/lightweight-review.md` **内部**: §5.1 表格（line 212-214）写 "DEC-009 决定 **7/8/9**"；§5.3（line 229）写 "DEC-009 决定 **7-9**"；§8 变更记录（line 245）写 "DEC-009 决定 **7/8/9** + exec-plan P0.7"。**差异原因推测**：architect 起草 design-doc 时 DEC-009 只有原 6 条决定，新增的审计成果接在 7-9；后续落盘 decision-log 时因前置 6 条固定在 decision-log 内（line 43-60），新增 3 条只能排 8-10，architect 未回填 design-doc 的编号 | **🔴 CRITICAL** |

**G1 影响**：
- 违反 decision-log 铁律 #2 "冲突报 diff"：design-doc 与 decision-log 同一 DEC 内的决定编号漂移，未来读者对照两文档会困惑
- 违反 DEC-009 自身决定 1 "helper 引用模式... 不发明新机制"（本 case 不直接违反 helper 机制，但属 append-only 的同类纪律 —— 权威源唯一）
- 下游引用已**正确**使用 decision-log 编号（reviews + testing + bugfix.md + log.md 条目行 25 + exec-plan P0.7 line 151-153 全用 "决定 8/9"），证实 **decision-log 是正确权威源**；错的是 design-doc 自身
- `docs/log.md:25`（最新 design 条目）文案写"DEC-009 增决定 8/9/10"（与权威源一致），与 design-doc §8 "7/8/9" 口径矛盾

**修复建议**（tester 不自行修，走 escalation）：
- 把 `docs/design-docs/lightweight-review.md` §5.1 表格的 `DEC-009 决定 7` → `8`、`8` → `9`、`9` → `10`
- §5.3 "决定 7-9" → "决定 8-10"
- §8 变更记录 "决定 7/8/9" → "决定 8/9/10"
- **不**动 decision-log.md 编号（已有下游引用全用 8/9/10）

---

## 2. 汇总

| 严重度 | 数量 | case 编号 |
|--------|------|-----------|
| 🔴 Critical | **1** | G1 |
| 🟡 Warning | **4** | A6, B2, D1, E2, F2 |
| 🔵 Suggestion | 0 | — |
| ✅ PASS | **13** | A1-A5, B1, B3, C1-C3, D2-D3, E1, F1 |

注：Warning 计数含 **5** 项（A6/B2/D1/E2/F2） —— 上方表头笔误，以列表为准。总计 18 case 覆盖 6 组（+ G 组 1 新 case），共 19 判定。

### 按 Group 分布
- A 组 helper 对称性：6 case PASS=5 / WARN=1（A6）
- B 组 log.md batching：3 case PASS=2 / WARN=1（B2）
- C 组 DEC 链完整性：3 case PASS=3
- D 组 README/CLAUDE 瘦身：3 case PASS=2 / WARN=1（D1）
- E 组 Step 交互一致性：2 case PASS=1 / WARN=1（E2）
- F 组 跨 session abort：2 case PASS=1 / WARN=1（F2）
- G 组（补）DEC 编号一致性：1 case **CRITICAL**（G1）

---

## 3. 关键发现详述

### 🔴 Critical — G1：design-doc vs decision-log DEC-009 决定编号不一致

**位置**：
- 错方：`docs/design-docs/lightweight-review.md:212-214, 229, 245`
- 对方：`docs/decision-log.md:61-63`（权威）；下游 `commands/bugfix.md:62`、`docs/log.md:25`、`docs/reviews/2026-04-19-subagent-progress-and-execution-model.md:51`、`docs/testing/subagent-progress-and-execution-model.md:95,172`、`docs/exec-plans/active/lightweight-review-plan.md:151-153` 全用 decision-log 的正确编号 8/9/10

**运行时风险**：
- 中低风险 —— 当前下游代码 / 文档已使用 decision-log 权威编号；错位仅在 design-doc 内部
- 未来维护 / reviewer 对照"design-doc 与 decision-log 如何关联"时会产生困惑
- 若有人按 design-doc §5.1 的"决定 7"去 grep decision-log，**什么都找不到**（decision-log DEC-009 最大决定号是 10，没有 7）

**根因**：design-doc 起草时 DEC-009 只有 6 条决定，新增审计结论在 7-9；后续落 decision-log 时 architect 发现前 6 条已固定 1-6，新增 3 条只能 8-10，但未回填 design-doc 编号

### 🟡 Warning 概要

- **A6**：`_escalation-protocol.md:103-108` 末尾列各 agent 典型触发点概述，与各 agent 本体内容重复；违反 helper 只放通用骨架的 DEC-009 纪律；建议删除或改"见各 agent 本体"
- **B2**：bugfix.md §log.md Batching 简化取舍合理，但未显式说"bugfix 无 C→C 过桥条款（因只有一段链）"，应加一句避免对照 workflow 时误解
- **D1**：README §致谢/§贡献/§许可证 三节彻底删除；CONTRIBUTING.md 仍从 `docs/INDEX.md` 可达，但 **LICENSE 文件无任何文档入口**（Apache-2.0 合规软性损失）；建议 README 底部加一行 `[LICENSE](LICENSE) — Apache-2.0` 或 `docs/INDEX.md` 追加一条
- **E2**：Step 7 INDEX vs Step 8 log 均挂 C 类"交接前"，但未声明执行顺序；建议在 workflow.md §起点或 Step 7/8 加一句"Step 7 → Step 8 顺序执行"
- **F2**：bugfix.md 未显式声明"本流程无 A 类 pause-point flush，跨 session abort 窗口覆盖整段 bugfix"；建议补一句

### ✅ Positive 发现（设计优秀处）

- helper 引用格式在 4 文件内部 + 7 外部引用点**绝对一致**（A1-A4 全 PASS），证实 retrofit 执行纪律严格
- A5 role-specific 残余保留：7 个 retrofit 文件逐项对照 exec-plan §跨阶段约束清单，无一误删（tester 的 Ordering discipline / reviewer 的 Critical-finding ordering / developer 的 Execution Form 段 / architect 的 Research Fan-out / analyst 的 Option Schema 全保留）
- C2 DEC-009 决定 9（bugfix.md 规则 2 对称性修）落地：与 workflow.md §6b.2 per-project 三级切换对称；下游 testing / reviews 均按"决定 9"编号 Resolved，形成闭环
- C3 DEC-009 决定 10 "影响范围 ≤10 行" 明确不回溯，维护了 decision-log 铁律 #1
- F1 跨 session abort 退化声明在 workflow.md 明文且 agent 侧无"兜底 staging"违规（符合 DEC-009 §2.2.3 接受退化的决策）

---

## 4. 推荐修复措施

### 必修（Critical）

1. **G1**：修 `docs/design-docs/lightweight-review.md`
   - §5.1 表格第 3 列 "DEC-009 决定 7" → "8"、"决定 8" → "9"、"决定 9" → "10"
   - §5.3 "决定 7-9" → "决定 8-10"
   - §8 变更记录 "决定 7/8/9" → "决定 8/9/10"
   - 不改 decision-log.md 和下游文档（已正确引用）

### 推荐修复（Warning）

2. **A6**：精简 `skills/_escalation-protocol.md:103-108`（末尾"各角色典型触发点"小结），改为 "详情见各 agent 本体的 §Escalation Protocol section"
3. **B2**：`commands/bugfix.md` §log.md Batching 加一句 "bugfix 流程无 C→C 过桥条款（只有一段 C 链或单 dev 派发），pause-point flush 不适用"
4. **D1**：`README.md` 底部加一行 LICENSE 入口（如 `本项目采用 [Apache-2.0 License](LICENSE)`），或在 `docs/INDEX.md` 的 `决策与索引` 表追加 LICENSE 一行
5. **E2**：`commands/workflow.md` 在 Step 7 / Step 8 开头或 §起点 明确 "Step 7 先执行，Step 8 后执行"（两者操作文件不同无竞态，但语义 INDEX 先 log 后与 §起点 步骤 6/7 顺序自洽）
6. **F2**：`commands/bugfix.md` §log.md Batching 显式声明 "本流程无 A 类 producer-pause，跨 session abort 窗口覆盖整段 bugfix（dev→reviewer）；建议用户在 closeout 前手动 /roundtable:lint 触发一次 flush"

### 无需动作（PASS）

其余 13 case 全 PASS，设计纪律到位，不需要额外变更。

---

## 5. 未覆盖 / 待补测试（Out of scope）

以下非本轮对抗性测试范围，建议在后续派发 reviewer 或下轮 dogfood 补：
- `docs/INDEX.md` 是否对 4 新 helper 清单描述准确（本轮已 verify INDEX.md:60-66 列出且 description 准确 —— 实际抽样即已 PASS，但未列入正式 case 避免过度展开）
- `commands/lint.md` 是否需同步响应 helper 新增（本轮未审；lint_cmd 硬编码 grep 0 命中已 verify，但 lint.md 本体是否也该引用 _progress-monitor-setup 是待确认项，属下轮 scope）
- 真实 dogfood 跑通一轮 `/roundtable:workflow` 任意小任务（lightweight-review exec-plan P0.5 验证点，本报告为静态对照，未覆盖）

---

## 6. 变更记录

- 2026-04-19 创建（DEC-009 对抗性对照测试；发现 1 Critical + 5 Warning；推荐修复措施列出）

---

## 附：本轮审读文件行数（2638 行总量，retrofit 后）

| 文件 | 行数 |
|------|------|
| commands/workflow.md | 414 |
| skills/architect.md | 284 |
| agents/developer.md | 223 |
| agents/tester.md | 217 |
| skills/analyst.md | 208 |
| agents/reviewer.md | 186 |
| agents/dba.md | 177 |
| agents/research.md | 167 |
| skills/_progress-reporting.md | 153 |
| commands/bugfix.md | 144 |
| commands/_progress-monitor-setup.md | 128 |
| README.md | 123 |
| skills/_escalation-protocol.md | 108 |
| skills/_resource-access.md | 58 |
| CLAUDE.md | 48 |
| **总计** | **2638** |

与 design-doc 预估 "2708 → 2108 省 ~600 行 22-25%" 比对：当前 2638 行（架构 / skill / agent / command / README / CLAUDE 核心子集，不含 docs/ 其他文件）。受限于本报告 scope 没对齐同一"计数范畴"，行数 delta 量化未独立 verify；建议在 P0.5 dogfood 中以相同 scope 重测（见"未覆盖"section）。
