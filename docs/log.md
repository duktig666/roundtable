# 操作日志

> append-only，新条目追加在顶部（最新在前）。
> 定位：**设计层文档的时间索引**（"何时、谁、动了哪份文档"）。

## 边界

**记录**：analyst 报告、architect design-docs / api-docs / exec-plan、DEC 条目、关键 review / test-plan **落盘**、lint 发现、冲突裁决。

**不记录**：
- 代码变更、skill/agent/command prompt 文件调整 → 归 `git log`，在 PR 描述里说清
- 文档内措辞 / 排版 / 小修订 → 归文档自己的"变更记录"章节
- 对话讨论、未落盘的审查 → 不入账

**合并原则**：agent / skill **不直接写本文件**。每轮 workflow 由 orchestrator 按 `commands/workflow.md` §Step 8 log.md Batching 协议（bugfix 流程按 `commands/bugfix.md` §log.md Batching 简化版）收集各 agent final report 中的 `log_entries:` YAML block 聚合写入；同一 agent 在同一轮产出多份文档（如 architect 同时输出 design-doc + DEC + exec-plan）**合并为一条**，`影响文件` 列全部路径（union）；不拆多条。DEC-009 决定 2 落地。

## decide | coding-principles-revert-to-claudemd | 2026-04-22
- 操作者: 用户
- 影响文件: docs/design-docs/coding-principles.md (重定位 Active → Reference-Template 附 §4 决策历史); docs/INDEX.md (条目同步); agents/developer.md / tester.md / reviewer.md / dba.md (revert `## Coding Principles` section); skills/architect/SKILL.md / skills/analyst/SKILL.md (同); roundtable/CLAUDE.md (revert Rule A/B)
- 说明: 阶段 C 撤销，改走用户 CLAUDE.md 路径。关键发现：CLAUDE.md 自动传导到 subagent cwd 层级（本会话实测验证），plugin 内嵌反造成 DRY 违反 + 外部使用者被强加风格 + 6 处同步 drift 风险。rsw 本仓库在 /data/rsw/CLAUDE.md §通用规则 §编码原则 段启用四原则；roundtable plugin 保持工作流中立。coding-principles.md 降级为"推荐模板"以供外部使用者按需复制。

## design | coding-principles | 2026-04-22
- 操作者: architect (inline) + reviewer (subagent, orchestrator relay-free audit)
- 影响文件: docs/design-docs/coding-principles.md (new); docs/INDEX.md (design-docs 条目追)
- 说明: 六角色共用四条编码基线 P1-P4（Think Before / Simplicity / Surgical / Goal-Driven，源自 andrej-karpathy-skills）；仅作人类设计 + review 载体，agent 不 Read，落地走 6 prompt 内嵌（§4.1 否决 _helper 共享模式：4 行静态文本不值每派发额外 6 Read）。Reviewer audit 2 Critical + 4 Warning + 3 Suggestion 全部已修（C1 分级误引 DEC-009 改 agents/reviewer.md 三档；C2 §4.2 插入位点校准到实际 `## 职责`；W1-4 + S1-4 并入同轮）。Draft 状态；阶段 C（批量改 6 agent/skill prompt 内嵌）另起 workflow 轮次。**本条已被 2026-04-22 revert 决策 supersede（上一条）**，保留作审计轨迹。

## fix | step7-relay-write-failure-ux | 2026-04-21
- 操作者: developer (inline)
- 影响文件: commands/workflow.md (§Step 7 Relay contract bullet 6 新增)
- 说明: issue #66 P3 enhancement —— DEC-017 §5 Q2 "走常规 error handling" UX 细化：orchestrator relay Write 失败时 fail-fast（无自动重试），final summary 顶部明示 ⚠️ + path + reason，subagent 原文附响应末尾作 fallback，人工救场路径提示；log_entries 追加 fix 审计条目。Append-only refinement under DEC-017 §Step 7 authority，不新增 DEC

## docs | dec014-nits-40 | 2026-04-21
- 操作者: developer (inline, lane-β)
- 影响文件: commands/workflow.md (§Step 8 YAML 契约 analysis 可选字段注释); commands/bugfix.md (§步骤 2 Tier 表 LOC 脚注 + override 警示 decision_mode 引用; §步骤 4 Postmortem 锚点 1 跨 session 边界说明); docs/design-docs/bugfix-rootcause-layered.md (§7 待确认项 5 条全部勾选)
- 说明: issue #40 DEC-014 follow-up nits —— W5/S1 workflow.md analysis 可选字段显式化 / S2 Tier LOC 计量口径 / S3 override 警示 decision_mode 渲染路径 / S4 session 边界说明 / S5 §7 闭环项打 ✅；不改 DEC 本体，纯 clarification

## analyze | subagent-coldstart-overhead-20 | 2026-04-21
- 操作者: analyst (skill, inline)
- 影响文件: docs/analyze/subagent-coldstart-overhead-20.md (new); docs/INDEX.md (analyze 条目追)
- 说明: issue #20 P3 调研 —— DEC-005 强制 tester/reviewer/dba subagent 在小任务场景的冷启开销权衡；3 选项客观代价表 + 6 事实层开放问题；analyst 不选型留 architect

## design | dec016-auto-halt-text-render | 2026-04-21
- 操作者: architect (inline)
- 影响文件: docs/design-docs/dec016-auto-halt-text-render.md (new); docs/decision-log.md (DEC-020 置顶); docs/INDEX.md (design-docs 条目追注)
- 说明: issue #61 P3 —— DEC-016 §3.3 auto_mode 与 text mode 交叉路径 Tester S-03 identified 3 未定义点；DEC-020 Refines DEC-016 锁定：render 顺序 audit-first / 转发 1 audit + N blocks / fallback 块 id `batch-<slug>-<n>-q<m>`（D3=A 用户延迟 auto-pick ★）；clarification 1+2 自明采纳

## decide | DEC-020 | 2026-04-21
- 操作者: architect (inline)
- 影响文件: docs/decision-log.md
- 说明: DEC-020 DEC-016 auto-halt text-mode render 形态命名 Accepted；3 决定（audit-first render 顺序 / 1 audit + N blocks 转发 fan-out / fallback id `batch-<slug>-<n>-q<m>`）；Refines DEC-016 §3.3 非 Supersede；DEC-016 其他 D1-D3 / max_concurrent=3 / DEC-013 / DEC-018 全保留

## implement | dec020-auto-halt-text-render | 2026-04-21
- 操作者: developer (inline, orchestrator relay)
- 影响文件: commands/workflow.md (§Step 4b Auto_mode 段 +3 clarification 子句; §Step 5b 事件类 e 表格行扩写 auto-halt case)
- 说明: DEC-020 落地到 workflow.md 规则本体 —— §Step 4b 新增 `Auto-halt text-mode fallback 渲染` 三点子句（render 顺序 audit-first / 转发 1+N / id `batch-<slug>-<n>-q<m>`）；§Step 5b 事件类 e 格式列追加 `DEC-020 auto-halt text fallback` 注记；4 agent prompt 本体 0 改动

## decide | DEC-018 | 2026-04-21
- 操作者: developer (inline, orchestrator relay)
- 影响文件: docs/decision-log.md (DEC-018 置顶); docs/design-docs/tg-forwarding-expansion.md (frontmatter + §3.4 表注 + §3.5 新增 + 变更记录); commands/workflow.md (Step 5 text §3.1a 改写 + Step 4b 批量段追加); skills/architect/SKILL.md (text §3.1a 改写); skills/analyst/SKILL.md (text §3.1a 改写); docs/INDEX.md (design-docs 条目追注)
- 说明: issue #63 方案 X —— DEC-013 §3.1a `<decision-needed>` 转发从"字节等价" raw YAML 松弛为"语义等价" pretty markdownv2（保 `id` / `question` / `option label` 三字段不改写）；终端 stdout 保留原 YAML 供 orchestrator fuzzy parse；TG/remote channel 只收人类可读渲染。Refines DEC-013 §3.1a 非 Supersede；sticky 语义、触发条件、§Step 5b 5 类事件全保留；orchestrator response -50% / TG payload -50% / UX 显著提升

## design | step7-relay-contract-tightening | 2026-04-21
- 操作者: architect (inline)
- 影响文件: docs/design-docs/step7-relay-contract-tightening.md (new); docs/decision-log.md (DEC-019 置顶)
- 说明: issue #65 P2 bug —— DEC-017 落地后 tester（A2/A3/A4/A5/A7）+ reviewer（Warning 1/2）identified §Step 7 三处契约模糊；DEC-019 Refines DEC-017 收紧 W1 frontmatter 剥离 + W2 Critical/归档 trigger 白名单 + W3 tester 布尔优先级

## decide | DEC-019 | 2026-04-21
- 操作者: architect (inline)
- 影响文件: docs/decision-log.md
- 说明: DEC-019 Step 7 Relay Write 契约收紧 Accepted；6 条决定（W1 frontmatter 剥离 / W2 Critical finding 识别规则 / W2 归档白名单 + subagent 自述不触发 / W3 tester 布尔优先级括号显式 / Refines DEC-017 非 Supersede / 不改 agent prompt 本体）

## exec-plan | step7-relay-contract-tightening | 2026-04-21
- 操作者: architect + developer (inline) + orchestrator (Step 7 relay)
- 影响文件: docs/exec-plans/completed/step7-relay-contract-tightening.md (new, completed)
- 说明: P0 architect 定稿 / P1 developer Step 7 文本补丁 / P2 decision-log + exec-plan 落盘 / P3 reviewer 自审 Approve

## fix | step7-relay-contract-tightening | 2026-04-21
- 操作者: developer (inline)
- 影响文件: commands/workflow.md (§Step 7 触发条件 bullet 2/3/4 + Relay contract bullet 1 收紧)
- 说明: issue #65 实施 DEC-019；diff ≤ 20 行；不触碰 agent prompt 本体

## review | step7-relay-contract-tightening | 2026-04-21
- 操作者: orchestrator (relay for reviewer)
- 影响文件: docs/reviews/2026-04-21-step7-relay-contract-tightening.md (new, orchestrator relay)
- 说明: DEC-019 自审 Approve（0 Critical / 1 Warning non-blocking / 2 Suggestion）；critical_modules 2 项命中（workflow.md §Step 7 hot-path / DEC-006 落盘契约）；reviewer 工具 Write=0，orchestrator 按 Step 7 代写 (orchestrator relay)

## design | reviewer-write-harness-override | 2026-04-21
- 操作者: architect (skill, inline)
- 影响文件: docs/design-docs/reviewer-write-harness-override.md (new); docs/decision-log.md (DEC-017 置顶)
- 说明: issue #59 P2 bug —— PR #53 (#23 fix) prompt 层 "绝对优先" 措辞 3/3 失败（#27/#23/#28 dogfood 实证）；方向 C 契约反转：reviewer/tester/dba 不 Write 归档 .md，Step 7 orchestrator 兜底升主路径。Refines DEC-006 非 Supersede（DEC-006 Phase Gating 三分类全保留）；design-doc §4.1 量化评分 C=50 > A=27 / B=27 / D=35

## decide | DEC-017 | 2026-04-21
- 操作者: architect (skill, inline)
- 影响文件: docs/decision-log.md
- 说明: DEC-017 reviewer/tester/dba 落盘契约反转 Accepted；8 条决定（D1 契约反转 / D2 触发条件三条件不变 / D3 Resource Access 调整 / D4 sentinel 协议废除 / D5 Step 7 末段改写 / D6 orchestrator 自造 created+log_entries / D7 Refines DEC-006 非 Supersede / D8 不改 DEC-001~016）；不 Supersede 任何既存 DEC

## exec-plan | reviewer-write-harness-override | 2026-04-21
- 操作者: architect (skill) + developer (inline) + orchestrator (Step 7 relay)
- 影响文件: docs/exec-plans/completed/reviewer-write-harness-override-plan.md (new, completed after E1+E2 dogfood pass)
- 说明: P0 3 agent prompt 契约反转 / P1 workflow.md Step 7 主路径化 / P2 testing/reviewer-write-permission.md F1-F5 close 追加 / P3 lint 2/2 + E1 tester dogfood 通过 + E2 reviewer dogfood 通过；所有 checkbox [x]

## fix | reviewer-write-harness-override | 2026-04-21
- 操作者: developer (inline)
- 影响文件: agents/reviewer.md (Write 列 →`—` / §输出落盘整段重写); agents/tester.md (Write 列 保`tests/*` 移除 testing/*.md / §测试计划模板首段重写); agents/dba.md (Write 列 →`—` / §输出落盘整段重写); commands/workflow.md (§Step 7 `兜底 Write` → `Relay Write 主路径` + 触发条件 + 5 sub-bullet); docs/testing/reviewer-write-permission.md (§变更记录追加 DEC-017 post-fix 条目 + 对抗清单回响表 5 行 🟡→✅)
- 说明: issue #59 方向 C 实施 —— 3 agent prompt Resource Access + §输出落盘重写为 "orchestrator relay 主路径"；sentinel 协议 `Write ... denied by runtime` 整段删除；lint 2/2 通过（硬编码扫描 + 残留措辞扫描 0 命中）

## test-plan | reviewer-write-harness-override | 2026-04-21
- 操作者: tester (subagent, fg; DEC-017 E1 dogfood — Write=0, orchestrator relay)
- 影响文件: docs/testing/reviewer-write-harness-override.md (new, orchestrator relay)
- 说明: DEC-017 relay 主路径首次 dogfood；tester 工具调用 Read/Grep/Bash only，Write=0；final message 完整测试计划 orchestrator 按 Step 7 代写；12 A 类对抗用例 + 3 E2E 场景；findings 0 Critical / 3 Warning (W1 frontmatter 剥离 / W2 触发白名单 / W3 tester 条件歧义) / 3 Suggestion / 5 Positive；critical_modules 4 项命中 (orchestrator relay)

## review | reviewer-write-harness-override | 2026-04-21
- 操作者: reviewer (subagent, fg; DEC-017 E2 dogfood — Write=0, orchestrator relay)
- 影响文件: docs/reviews/2026-04-21-reviewer-write-harness-override.md (new, orchestrator relay)
- 说明: issue #59 DEC-017 终审 Approve；reviewer 工具调用 Read/Grep/Bash only，Write=0；DEC-017 决定 1-8 逐条对照全部落地；sentinel 协议完整删除（本体 0 残留）；Refines DEC-006 非 Supersede 纪律保持；3 agent 对称；0 Critical / 2 Warning (W1 派发模板 absolute path / W2 tester 触发 bullet 排版) non-blocking / 4 Suggestion follow-up；relay 路径 2/2 (tester + reviewer) 通过 (orchestrator relay)

## design | parallel-decisions | 2026-04-21
- 操作者: architect (skill, inline) + developer (subagent, fg) + tester (subagent, fg) + reviewer (subagent, fg; Write harness-denied → orchestrator relay)
- 影响文件: docs/design-docs/parallel-decisions.md (new); docs/decision-log.md (DEC-016 置顶); docs/exec-plans/active/parallel-decisions-plan.md (new); commands/workflow.md (+§Step 4b + 3 refs + §6.9 batch 行 + §5b e 批注 + post-fix W-01/W-02/W-05 + R-W-01 overflow 行为); docs/testing/parallel-decisions.md (new tester); docs/reviews/2026-04-21-parallel-decisions.md (new, orchestrator relay); CLAUDE.md critical_modules item 6 文字升级; docs/INDEX.md (4 条目追加)
- 说明: issue #28 P2 enhancement —— orchestrator 独立决策批量化。D1 scope=B 中等（合并 Size / Dispatch mode / Developer form 三点为 multi-question AskUserQuestion）+ D2 judgment=A 新增 §Step 4b 决策并行判定树（4 条件：INPUT INDEPENDENT / OPTION SPACE DISJOINT / RESPONSE PARSABLE SEPARATELY / NO HIDDEN ORDER LOCK）+ D3 failure=A per-decision 降级重问 + max_concurrent=3 硬编码（复用 DEC-003 fan-out 心智）+ auto_mode 全或全无 batch auto-pick 审计 + text mode 多块同 response emit；不改 5 agent / 2 skill prompt 本体 / DEC-001~015 / Phase Matrix / Step 4 本体 / DEC-013 §3.1.1 serial emit 条款 / DEC-006 A/B/C 三分；tester W-01~W-05 全 inline post-fix（auto_mode runtime cancel 半句 / 跨问聚合回复规则 / §3.4 TG 限流 rationale 方向修正 / CLAUDE.md critical_modules 文字升级 / §3.1.1 vs §3.4 cross-note）；reviewer Approve-with-nits 0 Critical / 2 Warning / 3 Nit，R-W-01 overflow 行为（>3 → 前 3 批量第 4+ 串行）inline fix，R-W-02 ambiguity retry cap follow-up；Step 7 兜底第三次 dogfood（reviewer Write harness-denied，#23 fix 未完全生效 follow-up）

## decide | DEC-016 | 2026-04-21
- 操作者: architect (skill, inline)
- 影响文件: docs/decision-log.md
- 说明: DEC-016 orchestrator decision parallelism Accepted；不 Supersede 任何既存 DEC；scope B 量化评分 39 胜 A=36 / C=28 / D=现状；judgment tree A=新 §Step 4b 评分 34 胜 B=扩 Step 4 27 / C=无判定树 19；failure A 评分 34 胜 B=all-or-nothing 24 / C=fail-fast 18

## exec-plan | parallel-decisions | 2026-04-21
- 操作者: architect (skill) + developer (subagent)
- 影响文件: docs/exec-plans/active/parallel-decisions-plan.md
- 说明: P0 §Step 4b 新增 / P1 3 处 ref / P2 §Auto-pick batch 行 / P3 §5b e 批注；P0/P1 checkbox 全 [x]；P2/P3 无 explicit checkbox 但内容实现

## review | parallel-decisions | 2026-04-21
- 操作者: reviewer (subagent, fg; critical_modules 命中 → 必落盘；Write harness-denied → orchestrator relay — Step 7 兜底第三次 dogfood)
- 影响文件: docs/reviews/2026-04-21-parallel-decisions.md (new, orchestrator relay)
- 说明: issue #28 DEC-016 终审 Approve-with-nits —— 0 Critical / 2 Warning (R-W-01 overflow 行为已 inline / R-W-02 retry cap follow-up) / 3 Nit；DEC-001~015 coherent；自举 dogfood 发现 #23 reviewer Write 绝对优先级 fix 未完全生效

## test-plan | parallel-decisions | 2026-04-21
- 操作者: tester (subagent, fg)
- 影响文件: docs/testing/parallel-decisions.md
- 说明: issue #28 DEC-016 §Step 4b 对抗性测试 —— 0 Critical / 5 Warning W-01~W-05 / 4 Suggestion；14 dogfood 场景；4 条件对 7 决策点分类 100% 与 DEC-016 一致；W-01~W-05 orchestrator inline fix 全闭合

## fix | prune-dec-refs | 2026-04-21
- 操作者: orchestrator (inline bugfix) / tester (subagent) / reviewer (subagent)
- 影响文件: commands/workflow.md (-11 title labels + inline refs); commands/bugfix.md (-2 title + inline); skills/architect/SKILL.md (-1 title); skills/analyst/SKILL.md (-0 inline); agents/{developer,tester,reviewer,dba,research}.md (-inline issue labels); docs/testing/prune-dec-refs.md (new tester report)
- 说明: issue #22 P3 runtime prompt DEC-xxx / issue #N 标签精简；parenthesized labels 52→12 (-77%)；issue #N labels 18→0 (-100%)；Phase Matrix Stage 9 cell 保留 (A) 类型信号 (M2 post-fix)；M1 (跨 prompt label 对称) + M3 (DEC-014 进一步瘦身) 列 follow-up；lint 0 命中；DEC-010 north star 尊重 (docs/ 内 DEC 溯源全保留)；_progress-content-policy.md 6 schema anchor 保留；DEC-013 §3.1a 3× 契约 anchor 保留；cross-doc 详见 ref 全保留

## design | closeout-spec | 2026-04-21
- 操作者: architect (skill, inline; bugfix-scope)
- 影响文件: docs/design-docs/closeout-spec.md (new); commands/workflow.md (Step 6.1 A 类 Stage 9 变体 + §Auto-pick 例外); commands/bugfix.md (+1 行 ref); docs/decision-log.md (DEC-006 影响范围 post-fix #26); docs/INDEX.md (append design-docs)
- 说明: issue #26 P2 enhancement —— Stage 9 Closeout 结构化流程 spec；D1 Conventional Commits `<type>(<scope>): <summary> (#N)` + D2 本批 5 PR 稳定 PR body 模板 + D3 follow-up issues 从 tester/reviewer/dba non-blocking findings 提取草稿 P2/P3 label + D4 `go → bundle → go-all/go-commit/skip-*` 二次驱动；memory `feedback_no_auto_push` / `feedback_no_auto_pr` 硬边界优先于 auto_mode §Auto-pick；不新开 DEC append-only clarification to DEC-006；不改 5 agent / 2 skill prompt / target CLAUDE.md

## fix-rootcause | dedupe-produce-created | 2026-04-21
- 操作者: orchestrator (inline bugfix)
- 影响文件: skills/architect/SKILL.md (+1 行 §完成后); skills/analyst/SKILL.md (+1 行 §完成后); agents/developer.md (+1 行); agents/tester.md (+1 行); agents/reviewer.md (+1 行); agents/dba.md (+1 行); commands/workflow.md (Step 7 +1 行 "单一产出字段原则")
- 分析: |
    issue #29 P2 bug —— architect final message 同时输出 `产出:` 自然语言清单 + `created:` YAML 结构化清单，两者描述同一批文件路径冗余。
    根因：5 skill/agent prompt 的 "完成后" 段仅规定 `log_entries:` / `created:` 机读契约，未禁自由文本 `产出:` 重复输出；习惯性模板导致 token 浪费 + orchestrator 解析歧义（两处来源不一致风险）。
    修复：7 处 prompt inline 加"Final message 输出规范"条款，明示 `created:` 是唯一机读源；workflow.md Step 7 契约补"单一产出字段原则"。orchestrator 端从 `created:` 自动生成 A 类 producer-pause summary，skill/agent 不再自带。
    验证：lint 0 命中；后续 /roundtable:workflow 派发观察 final message 应不再含 `产出:` 段。

## review | faq-sink-protocol | 2026-04-21
- 操作者: reviewer (subagent, fg; critical_modules 命中 → 必落盘；orchestrator relay due to subagent Write unavailable — Step 7 兜底第二次 dogfood)
- 影响文件: docs/reviews/2026-04-21-faq-sink-protocol.md (new, orchestrator relay)
- 说明: issue #27 终审 Approve-with-caveats —— C1 Step 0.2→0.5 位置修复 + W1/W2/W4/W5 + S2/S4 全 inline 修 / W3/S1/S3 follow-up；DEC-006/013/014/015/002/009 一致；自举验证 Step 7 兜底 contract 稳定（第二次 dogfood）

## test-plan | faq-sink-protocol | 2026-04-21
- 操作者: tester (subagent, fg; critical_modules 命中 → 必落盘)
- 影响文件: docs/testing/faq-sink-protocol.md (new)
- 说明: issue #27 FAQ sink protocol 对抗审查 —— 2 High (F1 70% dedupe 算法未指定 / F2 `<project>` 填充规则未定义) + 4 Medium (F3 A 类 menu 裸问歧义 / F4 log prefix 语义过载 / F5 命令识别大小写冲突 / F6 白名单中文通用词漂移) + 5 Low follow-up；lint 0 命中

## fix | faq-sink-protocol | 2026-04-21
- 操作者: orchestrator (inline post-fix)
- 影响文件: commands/workflow.md (Step 0.2→0.5 位置移到 Step 0 后 + 位置说明段 + F1 Jaccard 算法 + F2 basename 填充 + F3 A 类裸问消歧 + F4 faq-sink 新前缀 + F5 命令识别规则 + F6 中文通用词共现约束 + W4 强制 sink 机制类前提); commands/bugfix.md (ref Step 0.5); docs/design-docs/faq-sink-protocol.md (§2.4 / §3.1 / §6 同步 post-fix); docs/log.md (§前缀规范 +faq-sink 行); docs/faq.md (头部 ref 泛化 S2)
- 说明: tester 2 High + 4 Medium 合并 post-fix；reviewer C1 + W1-W5 + S2/S4 合并 post-fix；W3/S1/S3 归 follow-up

## design | faq-sink-protocol | 2026-04-21
- 操作者: architect (inline; bugfix-level, no full architect phase)
- 影响文件: docs/design-docs/faq-sink-protocol.md (new); docs/faq.md (new, minimal header); commands/workflow.md (Step 0.2 新增); commands/bugfix.md (+1 行 ref); docs/INDEX.md (append design-docs + 决策与索引 faq.md 导航)
- 说明: issue #27 P2 bug —— 用户直接问 roundtable 机制类问题 orchestrator 回答后未沉淀 FAQ。协议：白名单关键词启发式触发 + `{docs_root}/faq.md` 全局落点（不存在则创建 minimal header，`<project>` = basename(target_project)）+ Jaccard bag-of-words ≥0.7 去重 + 📚 回复标注 + `log_entries:` 自造 `prefix: faq-sink` slug `faq-sink` + 用户命令覆盖（加入 FAQ / 别沉淀，冲突时 skip 胜出，加入 FAQ 仍需机制类前提 W4）；与 DEC-006 §A `问:` 菜单循环正交；Step 0.5 位置已从 bootstrap 区调整到 Step 0 之后（C1 修复）；纯 orchestrator 动作不动 5 agent / 2 skill / target CLAUDE.md

## review | reviewer-write-permission | 2026-04-21
- 操作者: reviewer (subagent, fg; critical_modules 3/3 命中 → 必落盘；orchestrator relay due to subagent Write unavailable — Step 7 兜底 dogfood)
- 影响文件: docs/reviews/2026-04-21-reviewer-write-permission.md (new, orchestrator relay)
- 说明: issue #23 终审 Approve-with-caveats —— 0 Critical / 3 Warning (reviewer prompt 400 字过长 / F3 sentinel-vs-escalation 双通道 follow-up / testing commit hash merge 后回填) / 3 Suggestion / 5 Positive；F4 Critical post-fix Step 7 4 sub-bullet 实质性修复有效；F1 绝对优先措辞合格；F5 anchor 判据有效；F3 短期保留 sentinel 合理（Write denial 非 decision request）；自举验证：本次 reviewer runtime 未暴露 Write → 触发 Step 7 兜底 dogfood；决策一致性 DEC-002/009/014 兼容

## fix-rootcause | reviewer-write-permission | 2026-04-21
- 操作者: orchestrator (inline bugfix)
- 影响文件: agents/reviewer.md (+1 段 §输出落盘 Write 权限明示); agents/tester.md (+1 段 §测试计划模板 Write 权限明示); agents/dba.md (+1 段 §输出落盘 Write 权限明示); commands/workflow.md (Step 7 +1 段 Orchestrator 兜底 Write)
- 分析: |
    issue #23 P2 bug —— reviewer subagent 在 critical_modules 命中时拒绝落盘 `docs/reviews/*.md`，自声明 "Do NOT Write report/summary/findings/analysis .md files" 受 Claude Code subagent runtime 通用提示约束，违反 agent prompt Resource Access matrix 授权。
    根因：Claude Code subagent runtime base prompt 含通用"不写 report .md"指引，与 roundtable 专门化 agent（reviewer/tester/dba）的 Resource Access matrix 矛盾；agent LLM 默认偏向 runtime 基线而非 prompt 覆盖。
    修复：3 agent prompt 显式加"Write 权限明示"段 —— 声明本 agent **被授权** Write 指定路径 + runtime 通用提示**不适用**本 agent + 遇冲突以本 prompt 为准 + 仅在**真实工具层 denial** 才降级对话返回并 emit `Write <path> denied by runtime` 供 orchestrator 兜底。workflow.md Step 7 加兜底规则 —— critical_modules 命中场景 subagent 未落盘时 orchestrator 代写并归因注。
    验证：下次 reviewer/tester/dba 派发观察是否恢复正常落盘；lint 0 命中。

## test-plan | phase-end-approval-gate | 2026-04-21
- 操作者: tester (subagent, fg; critical_modules 3/3 命中 → 必落盘)
- 影响文件: docs/testing/phase-end-approval-gate.md (new)
- 说明: issue #30 P1 bug 修复对抗审查 —— 2 Critical (F1 Stage 4 B 类与 exec-plan 产出决定混同 / F2 豁免理由双落点+越 architect Resource Access) + 4 Warning (F3 recommended 信号缺 / F4 fuzzy 单向降级 / F5 Q&A 循环终止边界模糊 / F6 Stage 9 A 类未覆盖) + 4 Suggestion + 2 Positive；lint 0 命中；post-fix inline 完成 F1/F2/F3/F4/F5/F6，F7-F10 列 follow-up

## fix | phase-end-approval-gate | 2026-04-21
- 操作者: orchestrator (inline post-fix)
- 影响文件: commands/workflow.md (A 类块 F1 正交注释 + F4 fuzzy size 分岔 + F5 Q&A 边界 + F6 Stage 9 变体); skills/architect/SKILL.md (§阶段 3 F1 正交 + F2 log.md decide 落点 + F3 recommended 信号); docs/design-docs/phase-end-approval-gate.md (§1.3 非目标 F6 澄清 + §6 变更记录 post-fix 段); docs/testing/phase-end-approval-gate.md (变更记录同步)
- 说明: tester 2 Critical + 4 Warning 合并 post-fix —— F1 明示与 Stage 4 B 类正交不再写"进 design confirmation" / F2 豁免理由落 log.md prefix decide 不回写 design-doc / F3 go-with-plan 标 ★ 推荐供 §Auto-pick / F4 fuzzy go 按 size 分岔 / F5 循环不重跑 Phase 0 + 5 轮软上限 + log_entries 跨轮合并 / F6 Stage 9 Closeout orchestrator 直接回答 FAQ；lint 0；F7-F10 nit follow-up

## design | phase-end-approval-gate | 2026-04-21
- 操作者: architect (skill, inline)
- 影响文件: docs/design-docs/phase-end-approval-gate.md (new); commands/workflow.md (Step 6.1 A 类条款扩写); skills/architect/SKILL.md (§阶段 3 改写); skills/analyst/SKILL.md (§工作流程 step 8 改写); docs/decision-log.md (DEC-006 影响范围 post-fix 2026-04-21 追加); docs/INDEX.md (append design-docs 条目)
- 说明: issue #30 P1 bug —— DEC-006 A 类 producer-pause 菜单穷举 + 禁 silent default + Q&A 循环 + architect `go-with-plan` / `go-without-plan: <理由>` 拆分；D1 orchestrator-only Q&A 循环落点 (A=46 vs B skill-level=32) + D2 双落点 architect SKILL 菜单 + orchestrator 校验理由落盘 (A=44 vs B orchestrator-only 二次询问=35) + D3 append-only clarification to DEC-006 (延续 DEC-013 §3.1a 先例)；auto_mode=on 全 3 决策 auto-pick recommended；不新开 DEC / 不改 DEC-006 A/B/C 三分 / 不动 4 agent / bugfix 流程无 A 类不受影响；lint 0 命中

## review | tg-forwarding-expansion | 2026-04-21
- 操作者: reviewer (subagent, fg; critical_modules 3/3 命中 → 必落盘)
- 影响文件: docs/reviews/2026-04-21-tg-forwarding-expansion.md (new)
- 说明: issue #48 DEC-013 §3.1a 扩展终审 Approve-with-caveats —— DEC-013 决定 1/3/8/9 全守住；tester post-fix 7 项（F13 Critical + F1/F2/F3/F4/F5/F10 Warning）全部实质性修复非贴补；4 项 follow-up non-blocking（F14 已被 F2 覆盖可关闭）；Reviewer 新增 1 Warning（W1 Step 5b ~31 行膨胀监控）+ 3 Suggestion（R1 design-doc §5 测试场景补 4 新 / R2 DEC-013 影响范围段累积超 DEC-010 ≤10 行需脚注豁免 / R3 bugfix ref 清晰度 OK）均不阻塞；lint 0 命中；验收 8/8 通过；合入后跟进 R1+R2 + dogfood 实测 F8/F9

## test-plan | tg-forwarding-expansion | 2026-04-21
- 操作者: tester (subagent, fg; critical_modules 3/3 命中 → 必落盘)
- 影响文件: docs/testing/tg-forwarding-expansion.md (new)
- 说明: issue #48 DEC-013 §3.1a 扩展对抗性 prompt 审查 —— 1 Critical (F13 Step 5b 末段 "3 处 skill-emitted" 措辞偏差) + 7 Warning (F1 a/d 重叠 / F2 ordering / F3 ≤200 字计量 / F4 纯/混合边界 / F5 sticky 语义 / F8 字节等价与 markdownv2 混合 / F10 session 定义) + 4 Suggestion + 2 Positive；lint 0 命中；post-fix 已 inline 完成 F13+F1+F2+F3+F4+F5+F10

## fix | tg-forwarding-expansion | 2026-04-21
- 操作者: orchestrator (inline post-fix)
- 影响文件: commands/workflow.md (+~22 行 F1/F2/F3/F4/F5/F10/F13 inline 修复); commands/bugfix.md (+0 行，ref 段微调 F6); docs/testing/tg-forwarding-expansion.md (+变更记录 2026-04-21 post-fix 条目)
- 说明: tester 1 Critical + 4 Warning + 2 collateral Warning 合并 post-fix 一次出 —— Step 5b 末段改精确列 3 处 prompt 本体（workflow Step 5 text / architect text / analyst text）/ 新增 Ordering & 批次规则子段（c 独立、d+e 合并、a+Step 1 合并、b 独立）/ 格式按事件类硬绑定段（事件类格式列优先）/ Unicode codepoint 计量 + 超长截断策略段（路径>findings>单行引用）/ Sticky 语义扩展段（tag 一次永久 + 多 channel 广播）/ Step 6.1 C 类末尾加 Stage 1 不重发 d 条款 / bugfix ref 显式标注 b 不适用；lint 0 命中；F8/F9/F12/F14 4 项 non-blocking 列为 follow-up

## design | tg-forwarding-expansion | 2026-04-21
- 操作者: architect (skill, inline)
- 影响文件: docs/design-docs/tg-forwarding-expansion.md (new); docs/decision-log.md (DEC-013 post-fix 2026-04-21 追加); docs/INDEX.md (append design-docs 条目)
- 说明: issue #48 —— DEC-013 §3.1a Active channel forwarding 语义扩展到 5 类 orchestrator-emitted 事件 (context/producer-pause/role digest/C handoff/auto_mode audit)；D1 落点 orchestrator-only (workflow.md + bugfix.md，skill 零改动) + D2 append-only clarification + D3 ≤200 字 digest + markdownv2 结构化 TG 可读性增强 (用户反馈 msg_id=428) + D4 全 4 auto_mode audit 事件转发；auto_mode=on 全 4 决策 auto-pick recommended；不新开 DEC / 不改 DEC-013 决定 8 边界 / 不改 skill/agent prompt / 不抬 target CLAUDE.md

## design | workflow-auto-execute-mode | 2026-04-20
- 操作者: architect (skill, inline)
- 影响文件: docs/design-docs/workflow-auto-execute-mode.md (new); docs/decision-log.md (DEC-015 置顶); docs/exec-plans/active/workflow-auto-execute-mode-plan.md (new); docs/INDEX.md (append design-docs + exec-plans 条目)
- 说明: issue #33 D1-D5 一揽子 Accepted by 用户 msg 380 → architect 产出 DEC-015 (11 决定) + 完整设计（§2 业务逻辑矩阵 auto×gate / §3 orchestrator 唯一改动落点 / §4 D1 量化评分 B=46 vs A=23 / §5 影响清单明示 4 agent + 5 skill + README + CLAUDE.md 零改动）+ P0-P8 exec-plan；对齐 DEC-013 三级链 / DEC-006 Phase Matrix 守约 / DEC-010 token 节约 / DEC-011/012 不抬 CLAUDE.md 边界

## fix | dec013-active-channel-forwarding | 2026-04-20
- 操作者: developer (inline) / tester (subagent, fg; critical_modules 多命中 → 必评审) / orchestrator
- 影响文件: commands/workflow.md (Step 5 text 分支加 sub-bullet); skills/architect/SKILL.md (decision_mode text 段加 sub-bullet); skills/analyst/SKILL.md (decision_mode text 段加 sub-bullet); docs/design-docs/decision-mode-switch.md (新增 §3.1a + §10 变更记录追加); docs/decision-log.md (DEC-013 entry 追加 post-fix 2026-04-20 注记)
- 说明: issue #38 P0 修复 —— DEC-013 text 模式 orchestrator/skill emit `<decision-needed>` 时必须同步调 active MCP channel (TG/Slack/CI) reply 工具转发字节等价块体；append-only clarification (§3.1a，不新开 DEC)；采纳 sticky channel 语义 + id/内容守恒 + out-of-scope 边界明言（tester H1/H2/M1/L1/L2 round-2 applied）；lint 0 命中；不改 4 agent prompt / DEC-013 决定 8 边界 / target CLAUDE.md

## merge | bugfix-rootcause-layered + claude-md-issue-rules | 2026-04-20
- 操作者: orchestrator / 用户
- 影响文件: main 分支 squash merge (PR #39 b55a201 + PR #42 49fc2be); 分支 feat/37-bugfix-rootcause-layered + feat/41-claude-md-issue-rules 已删
- 说明: PR #39 DEC-014 分层根因落盘 squash-merge to main (issue #37 auto-closed); PR #42 CLAUDE.md issue 标签+英文标题+priority 规则 squash-merge (issue #41 auto-closed); follow-up issue #40 (P3) 跟 W5 + 5 Suggestion; DEC-014 Accepted 生效

## review | bugfix-rootcause-layered | 2026-04-20
- 操作者: reviewer (subagent, fg; critical_modules 多命中 → 必落盘)
- 影响文件: docs/reviews/2026-04-20-bugfix-rootcause-layered.md (new)
- 说明: DEC-014 终审 Approve-with-caveats —— 0 Critical / 3 Warning (W1 PR 实施 commit 未推送 / W2 CLAUDE.md scope 溢出 DEC-014 / W3 INDEX 导航 table 未同步 bugfixes 行) / 5 Suggestion (analysis 字段显式声明 / LOC 计量口径 / 警示 UI decision_mode 引用 / session 记忆 {slug}.tier 跨 session 边界 / §7 待确认项勾选)；DEC-008/010/011/013/006/005/004 全正交对齐；tester 双轮 C1+W1-W4 闭环；W3 已 inline post-fix（INDEX.md nav table 加 bugfixes/ 行 + design-docs/testing/reviews section 各加 1 条）；W1 post-review commit 解；W2 保留为 follow-up（不阻本 DEC）

## test-plan | bugfix-rootcause-layered | 2026-04-20
- 操作者: tester (subagent, fg; critical_modules 多命中 → 必落盘)
- 影响文件: docs/testing/bugfix-rootcause-layered.md (new)
- 说明: DEC-014 prompt 层 10 项静态对抗（round 1）—— 1 Critical (C1 postmortem 硬约束缺 orchestrator 执行锚点) + 4 Warning (W1 LOC 未纳入 / W2 生产事故 label 未定义 + critical override / W3 "50 字" i18n 歧义 / W4 INDEX 未预建 bugfixes 分类)；PASS 项：前缀白名单 3 处同步 / _detect-project-context 0 命中 / DEC-008 正交 / DEC-010 token +57 行合理 / lint 0 命中。**round 2 post-fix 回归**：C1/W1/W2/W3/W4 全 PASS 无 regression；新 W5 非阻塞（workflow.md Step 8 YAML 契约未显式声明 `analysis` 可选字段）+ 3 nit 列入 follow-up

## fix | bugfix-rootcause-layered | 2026-04-20
- 操作者: developer (subagent, fg；两轮)
- 影响文件: commands/bugfix.md (+20 行), commands/workflow.md (+5 行), docs/log.md (+27 行 —— 含本条及历史 entry；§前缀规范 1 行 + §条目格式 fix-rootcause YAML 示例), docs/claude-md-template.md (+1 行), docs/INDEX.md (+4 行，### bugfixes 空占位)
- 说明: DEC-014 落地 + post-fix C1/W1-W4 合并一次产出 —— 首轮实施 +57 行被 tester 复审发现 C1 + 4 Warning；第二轮 post-fix 激进压缩 + 5 项全修：bugfix.md §步骤 2 改表格（Tier 判定双轴 + LOC 维度 W1 + `production-incident` label 来源 W2 + critical override 警示 W2 + ≤3 句捷径 W3 + 灰区 decision-needed 门）+ §步骤 4 Postmortem 硬约束 4 条 orchestrator 执行锚点（C1：session 记忆 {slug}.tier + mini-loop 回派 + closeout gate 校验）；workflow.md §Step 8 渲染规则压到 2 行（analysis 合并字段）；log.md 示例用合并 `analysis` 多行字段；INDEX.md 预建 `### bugfixes` 空占位（W4）；prompt 本体 commands 净增 25 行对齐 DEC-010；lint 0 命中

## design | bugfix-rootcause-layered | 2026-04-20
- 操作者: architect (post-fix, orchestrator inline)
- 影响文件: docs/design-docs/bugfix-rootcause-layered.md, docs/decision-log.md
- 说明: tester C1/W1/W2/W3/W4 + 用户"激进精简"指示 inline 回填 —— §2 Tier 表加 LOC 维度 + production-incident label source / §3.2 "≤50 字" 改 "≤3 句" 消 i18n 歧义 / §4.2-4.3 `root_cause` + `fix_summary` + `reproduction` 3 字段合并为 `analysis` 多行字段（省 5 行）/ §5.3 postmortem 硬约束新增 4 步 orchestrator 执行锚点（C1）/ §6 INDEX 预建 `### bugfixes`；DEC-014 §影响范围 post-fix 段注标；不新开 DEC（属 clarification scope）

## design | bugfix-rootcause-layered | 2026-04-20
- 操作者: architect
- 影响文件: docs/design-docs/bugfix-rootcause-layered.md, docs/decision-log.md
- 说明: issue #37 —— DEC-014 Accepted：bugfix 根因分层落盘三档（Tier 0 对话 / Tier 1 log.md fix-rootcause entry / Tier 2 docs/bugfixes postmortem）；D1 双轴自动判定（critical_modules + 规模），D2 新前缀 fix-rootcause（扩 DEC-008 白名单，可选字段 root_cause/fix_summary/reproduction），D3 developer Stage 4 验证后写 postmortem，D4 critical 硬自动 + 灰区 decision-needed 问一次；不改 5 agent prompt / _detect-project-context.md / target CLAUDE.md；与 DEC-008/010/013 正交；bugfix 轻量化心智对齐

## fix | fix-analyst-askuserquestion-params | 2026-04-20
- 操作者: developer (inline)
- 影响文件: skills/analyst/SKILL.md, skills/architect/SKILL.md
- 说明: issue #25 —— 两处 SKILL.md 的 AskUserQuestion Option Schema 章节重写；展示真实 Claude Code 工具 schema `{questions: [{header, question, multiSelect, options: [{label, description}]}]}`；内部字段 rationale/tradeoff/recommended/fact/why_recommended 打包进 description 字符串；示例代码块同步；显式告警"不要引入非 schema 字段，否则触发 Invalid tool parameters"；modal 分支行从 `AskUserQuestion(question, options)` 改成 `AskUserQuestion({questions: [...]})`；lint_cmd 0 命中

## test-plan | fix-analyst-askuserquestion-params | 2026-04-20
- 操作者: tester
- 影响文件: docs/testing/fix-analyst-askuserquestion-params.md
- 说明: 对抗性验证 issue #25 修复 —— 6 类反例（wrapper 多层/LLM 照搬伪字段/multiSelect 误 string/questions 传单 object/长度超限/漏必填）均无法击穿新 prompt；grep 静态扫描 skills+agents+commands 0 命中残留伪字段；docs/ 4 处叙述性残留属合法引用；产出 schema 新旧对比表 + 4 条手动 dogfood 验收场景（analyst/architect × modal/text）+ 未来 lint 扩展建议；结论 PASS

## merge | decision-mode-switch | 2026-04-20
- 操作者: orchestrator / 用户
- 影响文件: exec-plan active/ → completed/ (archive), docs/INDEX.md (active 条目移除 + completed 补入)
- 说明: PR #34 squash-merge to main（merge commit f76a740）；issue #31 auto-closed via fixes ref；branch feat/decision-mode-switch deleted；exec-plan 归档 completed/；剩 6/7 acceptance 等 plugin reload E2E

## design | decision-mode-switch | 2026-04-20
- 操作者: architect
- 影响文件: docs/design-docs/decision-mode-switch.md, docs/exec-plans/active/decision-mode-switch-plan.md, docs/decision-log.md
- 说明: issue #31 —— DEC-013 Accepted：双模式 modal/text，agent prompt 零改动（最小改动 D1=A），orchestrator 按 decision_mode 渲染 Escalation（modal→AskUserQuestion/text→`<decision-needed>` 块），skill 条件分支，3 级优先级链（CLI > env > default），不抬 CLAUDE.md 边界（DEC-011/012 对齐），全散 inline 不新增 helper（DEC-010 对齐 per-workflow token 省 3×），LLM fuzzy 用户回复解析，展现与接收解耦（TG/terminal/CI 下游自处理）；本设计过程自身即 text 模式 dogfood（TG 驱动 D1~D7 全程走 `<decision-needed>`）；3 项决策量化评分；exec-plan P0.1-P0.7 初版

## fix | decision-mode-switch | 2026-04-20
- 操作者: developer (inline)
- 影响文件: commands/workflow.md (+11 行 Step -1 + Step 5 分支), commands/bugfix.md (+4 行 Step -1 ref), skills/architect/SKILL.md (+5 行 mode 分支), skills/analyst/SKILL.md (+5 行 mode 分支 + recommended 禁用保留), README.md / README-zh.md (+10 行 §决策模式章节), docs/INDEX.md (+2 条)
- 说明: DEC-013 落地 —— 5 处 prompt 本体 + 2 README 镜像共 44 行（prompt 本体 25 行，design-doc §7 硬纪律 ≤40 通过）；lint_cmd 0 命中；per-workflow 新增 token ≤40 行达标

## test-plan | decision-mode-switch | 2026-04-20
- 操作者: tester
- 影响文件: docs/testing/decision-mode-switch.md
- 说明: 对抗性审查 + acceptance 映射 —— 14 项静态一致性（发现 F1/F2/F3/F4/F5 schema 漂移）+ 7 类边界条件对抗（发现 E1/E2/E4/E5/E6/E7 设计遗漏）+ 4 个 E2E 场景预期观察清单（未实跑 等 plugin reload）+ 7 项 acceptance 映射（1 done / 5 待 E2E 验 / 1 soft dogfood）；全 Warning Info 级 无 Critical 不 block 落地

## design | decision-mode-switch | 2026-04-20
- 操作者: architect (post-fix)
- 影响文件: docs/design-docs/decision-mode-switch.md, docs/decision-log.md, commands/workflow.md, skills/architect/SKILL.md, skills/analyst/SKILL.md
- 说明: tester F1/F2/F3/F5/E1/E2/E4/E5/E7 + reviewer W1/W2 全部 inline 回填 —— design-doc 新增 §2.1 非法值 fallback / §2.1a timeout 非目标 / §3.1 canonical schema (行格式 `<letter>（★ 推荐）：<label> — <rationale> / <tradeoff>`) / §3.1.1 多块串行 emit / §3.1.2 id 命名空间 / §3.6 歧义处理 4 层；3 处 prompt 本体 canonical 行格式对齐；DEC-013 §影响范围 post-fix 注标；不新开 DEC (属 clarification scope)

## review | decision-mode-switch | 2026-04-20
- 操作者: reviewer (subagent, 对话报告)
- 影响文件: (无落盘；对话报告后 W1/W2 立即 inline 回填)
- 说明: Approve w/ 3 Warning 0 Critical —— W1 design-doc §3.1 canonical 代码框 vs 文字描述自相矛盾 (architect post-fix 清除) / W2 §5 路径滞后 SKILL.md 子目录 (architect post-fix 清除) / W3 tester 文档行号引用易漂 (历史不改)；DEC-002/003/005/006/010/011/012 边界全对齐；lint_cmd 0 命中；10 file diff 与 DEC-013 §影响范围匹配；剩余 6/7 acceptance 依赖 plugin reload 后 E2E 实跑闭环

## design | dispatch-mode-strategy | 2026-04-20
- 操作者: architect
- 影响文件: docs/design-docs/dispatch-mode-strategy.md, docs/decision-log.md
- 说明: issue #19 —— DEC-012 Accepted：方向 1 规则补齐（保留 DEC-004/007/008）+ D2 并行度判据（单发 fg / 并行批 bg）+ D4 两级逃生门（per-session @声明 + per-dispatch AskUserQuestion）；不抬 CLAUDE.md 配置；DEC-008 正交补齐保留；#20 scope 边界声明；P8 dogfood bug 由 D2 自动修复；3 项决策量化评分；DEC-012 置顶 dogfood DEC-011 约定

## fix | dispatch-mode-strategy | 2026-04-20
- 操作者: developer (inline)
- 影响文件: commands/workflow.md (+16 行 §Step 3.4), commands/bugfix.md (Step 0.5 加 1 句), docs/INDEX.md (+1 条)
- 说明: DEC-012 落地 —— workflow.md 新增 §Step 3.4 Dispatch Mode Selection（3 层 fallback：per-session → D2 并行度 → per-dispatch AskUserQuestion）；bugfix.md 引用；lint 0 命中；reviewer W-01 section-number 统一 §3.4.5→§3.4（6 处）+ W-03 前置顺序声明 + S-01 补 2 条 @声明等价模式 + S-02 testing anchor 一并 post-fix

## review | dispatch-mode-strategy | 2026-04-20
- 操作者: reviewer subagent (critical_modules 多命中 → 必落盘；orchestrator relay)
- 影响文件: docs/reviews/2026-04-20-dispatch-mode-strategy.md (new, orchestrator 代写 —— reviewer agent 自声明 prompt 约束不允许 Write .md report，冲突于其 RA matrix，另记 issue)
- 说明: DEC-012 终审 Approve-with-caveats（0 Critical / 3 Warning / 2 Suggestion）；W-01 section-number 贯穿 4 文档不一致 + W-03 Step 4 前置顺序 + S-01 @声明列表 + S-02 testing anchor 全部 post-fix；DEC-001~DEC-011 逐项对齐

## analyze | dispatch-mode-strategy | 2026-04-20
- 操作者: analyst
- 影响文件: docs/analyze/dispatch-mode-strategy.md
- 说明: issue #19 前台/后台派发选择策略调研 —— 确认根因（workflow.md/bugfix.md/5 agent 零规则，Task `run_in_background` 由 orchestrator 自由心证）；3 选项对比（规则补齐 / 删 Monitor 全前台 / 强制全后台）+ 5 场景 × 3 选项矩阵 + 判据候选 D1-D4；8 事实层开放问题 P1-P8 交 architect（P7 标注 #19/#20 耦合）；FAQ Q1 补 orchestrator 概念解释

## design | decision-log-entry-order | 2026-04-20
- 操作者: architect
- 影响文件: docs/design-docs/decision-log-entry-order.md, docs/decision-log.md
- 说明: issue #18 —— DEC-011 Accepted：SKILL.md 补插入位置规则 + Minimal header（3 行）初始化 + 锚点 = "第一个 `### DEC-` 行"；template L46 同步；DEC-011 自身置顶 dogfood

## fix | decision-log-entry-order | 2026-04-20
- 操作者: developer (inline)
- 影响文件: skills/architect/SKILL.md (+~13 行), docs/claude-md-template.md (L46 改 1 行), docs/INDEX.md (+1 条)
- 说明: DEC-011 落地 SKILL.md L19 / L59 / L165 + §完成后 新增 "### decision-log 条目顺序约定" 小节；lint 0 命中；reviewer W-01（"仅 header 无 DEC" fallback）+ Suggestion 1/2 + 用户精简诉求一并 post-fix 合并

## review | decision-log-entry-order | 2026-04-20
- 操作者: reviewer subagent (critical_modules "Skill prompt 本体" 命中 → 必落盘)
- 影响文件: docs/reviews/2026-04-20-decision-log-entry-order.md (new)
- 说明: DEC-011 终审 Approve with 1 Warning（0 Critical / 1 Warning / 3 Suggestion）；DEC-002 / DEC-006 / DEC-009 决定 10 / DEC-010 全对齐；影响范围 7 行 ≤ 10 合规；W-01 + Suggestion 1/2 已 post-fix

## analyze | lightweight-review | 2026-04-19
- 操作者: analyst
- 影响文件: docs/analyze/lightweight-review.md
- 说明: issue #9 轻量化审计 —— archive 对比、3 大抽取热区识别（DEC-002/004/007）、4 大目标可行性 + 7 事实层开放问题交 architect

## design | lightweight-review | 2026-04-19
- 操作者: architect
- 影响文件: docs/design-docs/lightweight-review.md, docs/decision-log.md, docs/exec-plans/active/lightweight-review-plan.md
- 说明: DEC-009 Proposed —— 4 shared helper 抽取 + log.md closeout batching + README/CLAUDE.md 重塑；user Modify 扩 scope 加 DEC 审计 → DEC-009 增决定 8/9/10（DEC-002 决定 5 正式 Superseded / bugfix.md 规则 2 对称性修 / DEC 影响范围纪律）+ exec-plan 增 P0.7；P0.1-P0.7 执行路线

## exec-plan | lightweight-review P0.1+P0.2 | 2026-04-19
- 操作者: developer subagent
- 影响文件: skills/_resource-access.md (new 58), skills/_escalation-protocol.md (new 108), skills/_progress-reporting.md (new 153), commands/_progress-monitor-setup.md (new 128), agents/developer.md, agents/tester.md, agents/reviewer.md, agents/dba.md, agents/research.md, skills/architect.md, skills/analyst.md
- 说明: P0.1 新建 4 shared helper（447 行）+ P0.2 retrofit 7 文件到 ref 模式（5 agent 净省 349 行；architect/analyst 平齐）；lint 0 命中；role-specific ordering/phase tag/Content Policy 示例/模板全保留

## exec-plan | lightweight-review P0.3+P0.4+P0.7 | 2026-04-19
- 操作者: developer subagent
- 影响文件: commands/workflow.md (437→414), commands/bugfix.md (138→144), README.md (144→123), CLAUDE.md (60→48), docs/claude-md-template.md (204→205), docs/log.md (191→191), docs/INDEX.md (100→106), docs/testing/subagent-progress-and-execution-model.md (+2 lines), docs/reviews/2026-04-19-subagent-progress-and-execution-model.md (+1 line)
- 说明: P0.3 workflow.md Step 3.5 抽 helper + 新增 Step 8 log.md Batching + bugfix.md 同步；P0.4 README §设计原则 扩至 7 条 + 删 §致谢/§贡献/§许可证 + CLAUDE.md 删 §设计参考 + INDEX.md helper 清单；P0.7 DEC-009 决定 9 bugfix.md 规则 2 对称修 + testing/reviews 报告补 Resolved 标注；lint 0 命中

## test-plan | lightweight-review | 2026-04-19
- 操作者: tester subagent (critical_modules 多项命中 → 必落盘)
- 影响文件: docs/testing/lightweight-review.md (new)
- 说明: DEC-009 对抗测试 19 cases；1 Critical（G1 design-doc DEC-009 决定编号 7/8/9 vs decision-log 8/9/10 漂移）+ 5 Warning（A6 helper role-specific 泄漏 / B2 bugfix C 链说明缺 / D1 LICENSE 无 README 入口 / E2 Step 7-8 顺序未声明 / F2 bugfix abort 窗口未声明）；6 PASS 证实 helper 引用对称 + log batching 契约 + DEC 链完整

## review | lightweight-review | 2026-04-19
- 操作者: reviewer subagent (critical_modules 多项命中 → 必落盘)
- 影响文件: docs/reviews/2026-04-19-lightweight-review.md (new)
- 说明: DEC-009 终审 Approve-with-caveats；0 Critical / 3 Warning / 4 Suggestion / 5 Positive；DEC-001 D1-D9 + DEC-002~008 Accepted 条款全保；decision-log 3 铁律遵守（不删 / 报 diff / 编号递增）；DEC-004 event schema 零改；lint 0 命中；helper 引用 7×4 处逐字一致；判 W-01 tester 升级的 Critical 实为 Warning（design-doc 内部错位，下游已正确）

## fix | lightweight-review W-01+A6+B2+D1+E2+F2 post-fix | 2026-04-19
- 操作者: orchestrator (inline, 基于 tester + reviewer findings)
- 影响文件: docs/design-docs/lightweight-review.md (§5.1/§5.3/§7/§8 决定编号 7/8/9 → 8/9/10), commands/bugfix.md (rule 2 "honor" 中文化 + abort 退化窗口声明), README.md (+LICENSE/CONTRIBUTING 1 行入口), skills/_escalation-protocol.md (删末尾 4 agent 典型触发点 role-specific 泄漏), commands/workflow.md (Step 8 加 Step 7/8 执行顺序声明)
- 说明: tester W-01 Critical + reviewer W-01 Warning 裁决（reviewer 判级更准）后 6 项修复全部 post-fix；lint 0 命中；design-doc 与 decision-log 编号自洽；W-02 cosmetic 样式差异 + reviewer 4 Suggestion 延后 follow-up

## exec-plan | lightweight-review completed | 2026-04-19
- 操作者: orchestrator (Stage 9 Closeout)
- 影响文件: docs/exec-plans/completed/lightweight-review-plan.md (从 active/ 移动), docs/decision-log.md (DEC-009 状态 Proposed → Accepted), docs/INDEX.md (exec-plans active/ → completed/ 条目更新)
- 说明: DEC-009 归档完成；P0.1-P0.7 全部通过 tester + reviewer 终审；issue #9 轻量化重构闭环

## decide | DEC-010 | 2026-04-19
- 操作者: architect (inline)
- 影响文件: docs/decision-log.md
- 说明: DEC-010 Accepted —— 矫正 DEC-009 决定 1 运行期 token 账误判；Supersede 4 helper 抽取；revert + 激进 inline 精简；DEC-009 其他 9 条决定保留

## exec-plan | subagent-progress-and-execution-model + progress-content-policy completed | 2026-04-19
- 操作者: orchestrator (active/ 审计)
- 影响文件: docs/exec-plans/completed/subagent-progress-and-execution-model-plan.md (从 active/ 移动 + 状态 Active→Completed + decisions 补 DEC-008), docs/exec-plans/completed/progress-content-policy-plan.md (从 active/ 移动 + 补勾 18 checkbox + 状态 Active→Completed), docs/INDEX.md (exec-plans active/ → completed/ 条目更新)
- 说明: issue #7 + #14 相关 plan 实际已通过 PR #16 merged 到 main，但 active/ 下 checkbox / status 未同步；本次审计补齐；roundtable-plan.md 仍 Active（P5/P6 v0.1 发布未做）

## fix | lightweight-review-revert P1.1~P1.5 | 2026-04-19
- 操作者: developer subagent (DEC-010 机械落地)
- 影响文件: skills/_resource-access.md, skills/_escalation-protocol.md, skills/_progress-reporting.md, commands/_progress-monitor-setup.md (4 files deleted); agents/developer.md (223→121), agents/tester.md (217→127), agents/reviewer.md (186→121), agents/dba.md (177→140), agents/research.md (167→119), skills/architect.md (284→167), skills/analyst.md (208→139), commands/workflow.md (416→306), commands/bugfix.md (146→107), CLAUDE.md, docs/INDEX.md, docs/claude-md-template.md, docs/design-docs/lightweight-review.md (+§9/§10)
- 说明: DEC-010 落地 —— 4 helper 删除 + 5 agent / 2 skill / 2 command 激进 inline 精简；tree skills+agents+commands 2791→1672（净省 1119 行 / 40%）；单次典型 workflow 负载 ~1800→~1100（省 ~39%）；role-specific 纪律全保（Execution Form / Ordering discipline / Abort Criteria / Research Fan-out / 追问框架）；DEC-004 event schema 4 agent 逐字对齐；lint 0 命中

---

## 前缀规范

| 前缀 | 含义 | 示例 |
|------|------|------|
| `analyze` | analyst 产出新分析报告 | `analyze \| some-topic \| 2026-04-17` |
| `design` | architect 产出/更新设计文档 | `design \| roundtable \| 2026-04-17` |
| `decide` | 新增或变更设计决策 (DEC-xxx) | `decide \| DEC-001 \| 2026-04-17` |
| `exec-plan` | 产出或完成执行计划 | `exec-plan \| some-slug completed \| 2026-04-17` |
| `review` | reviewer 完成关键审查（落盘的） | `review \| some-slug \| 2026-04-17` |
| `db-review` | dba 完成关键 DB 审查（落盘的；issue #67 从 `review` 拆分） | `db-review \| some-slug \| 2026-04-21` |
| `test-plan` | tester 产出测试计划 | `test-plan \| some-slug \| 2026-04-17` |
| `lint` | 健康检查发现的问题及处理 | `lint \| 3 issues found \| 2026-04-17` |
| `fix` | 裁决冲突后的修复 | `fix \| DEC-xxx updated \| 2026-04-17` |
| `fix-rootcause` | bug 根因结构化 entry（Tier 1/2，DEC-014） | `fix-rootcause \| some-bug \| 2026-04-20` |
| `faq-sink` | orchestrator 自动沉淀机制类 Q&A 到 `{docs_root}/faq.md`（issue #27） | `faq-sink \| faq-sink \| 2026-04-21` |

## 条目格式

```markdown
## [前缀] | [标题/slug] | [日期]
- 操作者: [agent 名 / 用户]
- 影响文件: [文件列表]
- 说明: [一句话]
```

**fix-rootcause 扩展示例**（Tier 1/2，DEC-014）：

```yaml
log_entries:
  - prefix: fix-rootcause
    slug: some-bug
    files: [src/foo.rs, tests/foo_test.rs]
    note: <一句话>
    analysis: |
      根因: <2-5 句>
      修复: <1-3 句>
      复现: <步骤；有回归测试则省略>
```

Tier 2 同产 `{docs_root}/bugfixes/some-bug.md` postmortem。

---

## review | step35-foreground-skip-monitor | 2026-04-19
- 操作者: reviewer subagent (critical_modules hit → 必落盘)
- 影响文件: docs/reviews/2026-04-19-step35-foreground-skip-monitor.md（新建）
- 说明: issue #15 DEC-008 终审 Approve；tester 2 Critical + 3 Warning + 1 Suggestion 全修复复验通过；0 new finding；5 agent prompt Fallback 未动兼容 / lint 0 命中 / DEC-004 append-only + DEC-007 正交性双向自证

## test-plan | step35-foreground-skip-monitor | 2026-04-19
- 操作者: tester subagent (critical_modules hit → 必落盘)
- 影响文件: docs/testing/step35-foreground-skip-monitor.md（新建）
- 说明: issue #15 DEC-008 对抗测试 18 cases；2 Critical + 3 Warning + 1 Suggestion；T12 §3.2 vs §3.6 引用错位 + T13 §3.7 heading 丢失悬空指针 — 全部 post-fix 落地

## decide | DEC-008 + design patch §3.8 | 2026-04-19
- 操作者: architect skill (inline)
- 影响文件: docs/decision-log.md（DEC-008 新增 + DEC-004 状态行追加 §3.6 Superseded 注记）, docs/design-docs/subagent-progress-and-execution-model.md（frontmatter decisions 增列 DEC-008 + 新增 §3.8 Foreground vs background gate + §6 变更记录条目）
- 说明: 解 issue #15；Step 3.5 触发条件从"所有 Task 派发"收紧为"`run_in_background: true` 派发"；与 DEC-007 正交可分别合并；不改 5 份 agent prompt 本体；待 design-confirm 后派 developer 改 commands/workflow.md + commands/bugfix.md

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
