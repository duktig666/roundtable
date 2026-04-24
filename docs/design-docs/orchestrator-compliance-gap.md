---
slug: orchestrator-compliance-gap
source: analyze/orchestrator-compliance-gap.md
created: 2026-04-24
status: Draft
decisions: [DEC-030]
---

# Orchestrator Handoff Forwarding 合规缺口 设计文档

## 1. 背景与目标

### 背景

2026-04-23 `/roundtable:workflow #110`（TG 驱动 / active channel sticky）跑 analyst pipeline 时，orchestrator 在 skill 返回后漏执行 `commands/workflow.md` §Step 5b 事件类 b/c forwarding、§Step 6.1 A 类 producer-pause 3 行 summary + 菜单 emit + pause 协议。Phase Matrix 未更新；TG 零 reply；用户补发"进展"后 orchestrator 才 recover。同类 pattern 2026-04-22 memory `feedback_tg_workflow_updates_to_tg` 已记录一次，本次是第 2 次直接观测——**非首次**。

DEC-024（Phase Matrix 渲染 locus = orchestrator + re-emit 绑定 §Step 6 A/B/C）、DEC-013 §3.1a（sticky channel 下 `<decision-needed>` / phase summary 必转发）、§Step 6.1（A 类 producer-pause 停下不调用任何工具）**均已 Accepted**。缺口**不是 SPEC 层面规则缺失**，而是 **SPEC→RUNTIME 合规性 drift**：prose 层规则清晰但 runtime 未收敛，且无机械 enforcement 兜底。

### 目标

- 对 Finding 1（primary bug）落定独立修复方向：§Step 5b/6.1 提取 skill→orchestrator handoff checklist + runtime enforcement（scripts/orchestrator-compliance-check.sh + audit log JSONL + CLAUDE.md §工具链扩展 lint_cmd_compliance）
- 对 Finding 2（YAML 契约终端可见 cosmetic smell）显式论证 accepted，不做结构性改动
- 通过新 DEC-030 Refines DEC-024 + DEC-013 §3.1a + §Step 6 合规性维度（non-Supersede；全部 Accepted 决定保留）
- 产出 2 follow-up issue drafts（P1 layout+postmortem / P2 enforcement）供 Stage 9 Closeout bundle 使用
- 建立 roundtable 首个 "SPEC→RUNTIME 合规性 enforcement" 范式（镜 DEC-029 ref density + DEC-028 SessionStart hook 基础设施组合）

### 非目标

- 不改 `commands/workflow.md` 552 行 prose 本体（layout 改的**具体条款**实施归 P1 follow-up issue；本 DEC 只定方向）
- 不实施 runtime enforcement（audit log schema + scripts + lint 字段归 P2 follow-up）
- 不做 workflow.md 系统性 rule density 精简（per issue #111 out-of-scope；若 P2 enforcement design 过程中发现需收敛，开独立 P3 umbrella）
- 不改 final message YAML 契约（`log_entries:` / `created:`）位置或形态
- 不改 4 agent prompt / 2 skill prompt 本体（critical_modules 命中但 P1/P2 实施时才真改）
- 不改 Resource Access matrix / Escalation Protocol JSON schema / Progress event schema

## 2. 业务逻辑

### Finding 1 现象路径（analyst 报告已详列；此处 anchor 关键点）

```
TG active channel sticky session
  → /roundtable:workflow #N
  → orchestrator Stage 0/1/2 (dispatch analyst skill)
  → analyst skill final message with log_entries: + created: YAML (tail)
  → orchestrator tick resume
  → [EXPECTED 6 fire] Step 8 flush / Step 7 INDEX / 事件类 c digest / 事件类 b summary / A 类 menu / pause
  → [ACTUAL observed] 仅终端自然语言 summary，TG 零 reply，Phase Matrix stale，无 menu，未 pause
  → 用户补发"进展"触发 orchestrator recover
```

### 修复 posture

**Layout 改（i）**：在 `commands/workflow.md` §Step 5b 之后、§Step 6 之前插入 **§Step 5c Skill→Orchestrator Handoff Checklist** 章节（新 Step 编号：5c，非 6，与事件类 c/d 号段区分；**实际 Step 编号由 P1 developer 确定，本 DEC 不 commit 具体号**）。章节内容明示 6 条应 fire 动作及执行顺序，§Step 6.1 A 类模板行内 ref 该 checklist（`详见 §Step 5c` 一行）。

**Runtime enforcement 改（ii）**：
- orchestrator 在每次 event class b/c/d/e fire + A 类 menu emit + pause 点各 emit 一条 JSONL audit 行到 `${ROUNDTABLE_AUDIT_PATH:-/tmp/roundtable-audit/${SESSION_ID}.jsonl}`
- 新 `scripts/orchestrator-compliance-check.sh`：post-session 或 on-demand 扫 audit log，对每个 skill→orchestrator transition 验证 "should fire" checklist 全命中；miss 打印 `COMPLIANCE FAIL: dispatch=<id> missed [event-c, menu-emit, ...]` 并 exit 1
- CLAUDE.md §工具链追 `lint_cmd_compliance: scripts/orchestrator-compliance-check.sh`（与 `lint_cmd_hardcode` / `lint_cmd_density` 并列，独立 exit code）
- DEC-028 SessionStart hook 扩：session 启动时在 `<roundtable-preflight>` 追 `ROUNDTABLE_AUDIT_PATH` echo

**Tier 2 postmortem（DEC-014）**：P1 follow-up 附写 `docs/bugfixes/orchestrator-compliance-gap.md`（root cause / reproduction / fix / verification / follow-ups 五段式 per DEC-014），`docs/log.md` 一条 `fix-rootcause` tier=2 entry 关联该 postmortem。本 DEC 落盘时**不**写 postmortem（归 P1 实施阶段，与 layout 改同 PR 合入）。

### Finding 2 accepted cosmetic 显式论证

analyst 维度 3 拆耦论证：Finding 2 是否是 Finding 1 contributing factor **无 A/B 实证**；维度 9 cross-map 表明 mitigation a/b/c 对 hypothesis A（rule density）+ B（enforcement）均 0 响应，仅 c 对 hypothesis C（cognitive load）强响应。analyst 维度 4 又校正 issue #111 body 的参照前提（superpowers `<SUBAGENT-STOP>` 是 skill 自跳过 marker，非 handoff sentinel）——mitigation a 无前例。

按"证据驱动，不预支结构性改动"原则：
- 承认 YAML 在终端 + TG 是 cosmetic clutter（用户可读，orchestrator 机读）
- 不改 YAML 位置 / 包裹 / 渠道（4 agent + 2 skill + workflow.md Step 7/8 解析路径保持）
- 若未来 P2 enforcement 落地后仍高频 miss，可开新 DEC（P3 umbrella）重新评估结构性改动（届时有 enforcement 收集的 miss 证据作输入）

## 3. 技术实现

### 3.1 §Step 5c Handoff Checklist 结构草图（P1 实施时 refines）

```markdown
## Step 5c: Skill→Orchestrator Handoff Checklist (DEC-030)

skill 返回后 orchestrator tick 重启时 **按序** 执行：

1. [flush] Step 8 log.md flush（若 phase 满足 flush trigger point 2）
2. [sync] Step 7 INDEX.md sync（若 created[] 有新路径）
3. [fwd-c] Step 5b 事件类 c — role completion digest ≤200 Unicode codepoints（独立 TG reply；sticky channel 下必 fire）
4. [fwd-b] Step 5b 事件类 b — A 类 producer-pause 3 行 summary + Phase Matrix 尾段单行进度条（独立 TG reply；sticky channel 下必 fire）
5. [menu] Step 6.1 A 类菜单 终端 emit（`go / 问 / 调 / 停`；architect 变体 + Stage 9 变体见 §Step 6.1）
6. [pause] Step 6.1 pause 不调用任何工具 等用户下一条

每步 orchestrator **必须** emit 一条 JSONL audit 行到 `${ROUNDTABLE_AUDIT_PATH}`（ref §3.2）。纯终端 session fwd-c / fwd-b 降级为 terminal stdout but audit 行照写。
```

**为什么 Step 5c 而非整合进 §Step 6.1**：§Step 6.1 是 A/B/C 三类 phase gating 主体，已含 ~60 行 A 类菜单模板 + architect 变体 + Stage 9 变体；handoff checklist 语义上是"Step 5 Subagent Escalation 的后继正常路径（非 escalation）"，与 §Step 5 / §Step 5b 同家族。作为 §Step 5c 独立小节，maintainer + LLM grep "handoff" / "skill 返回" 时定位直接；不冲击 §Step 6.1 已有结构。

### 3.2 Runtime enforcement audit log schema（P2 实施时 refines）

```yaml
# JSONL one line per orchestrator-emitted event or menu/pause action
ts: <iso-utc>
session_id: <CLAUDE_SESSION_ID or fallback>
dispatch_id: <8-hex id of return-from-skill transition>
slug: <workflow slug>
event: flush | sync | fwd-c | fwd-b | menu | pause | fwd-d | fwd-e-audit
phase_from: <stage name>  # optional
phase_to: <stage name>    # optional
channel: <telegram_chat_id | terminal>  # for fwd-b/c/d; terminal otherwise
payload_ref: <path if large, else null>
```

`scripts/orchestrator-compliance-check.sh` 扫算法（简化）：
- Per `dispatch_id` group 所有 events
- 对 "skill return" dispatch（识别标：prior `Skill(...)` tool call 完成 + session active channel sticky），assert { flush|skip-if-no-new, sync|skip-if-no-new, fwd-c, fwd-b, menu, pause } 全部出现
- Missing → 打印 COMPLIANCE FAIL + dispatch_id + missing set；exit 1
- 所有 transition pass → exit 0

**P2 design 决策点（承接到 P2 follow-up 内自己的 architect round）**：
- audit log 持久化：tmpfs vs project 内 / git-ignored 目录
- Scan 粒度：per-transition strict vs per-session loose
- "skip-if-no-new" 判定边界（何时 flush/sync 允许空 event 算 pass）
- 纯终端 session 的 fwd-b/c 降级为 terminal-only 是否仍需 audit 行

这些决策**不在本 DEC 内 commit**；P2 follow-up issue 单独 design round。

### 3.3 Tier 2 postmortem 结构（P1 实施时 refines）

`docs/bugfixes/orchestrator-compliance-gap.md` 按 DEC-014 Tier 2 五段式：
1. Root cause — analyst 3 hypothesis A/B/C（density / enforcement / cognitive load）的 architect posture
2. Reproduction — 2026-04-22 + 2026-04-23 两次 observed 证据链 + 触发条件
3. Fix — §Step 5c layout + runtime enforcement（指向 P1 PR + P2 PR）
4. Verification — dogfood TG pipeline `/roundtable:workflow` 新 analyst 派发全流程 6 条 fire 清单 + compliance-check.sh exit 0
5. Follow-ups — 若 enforcement 仍捕获 miss 触发 P3 umbrella（Finding 2 结构性 revisit）

`docs/log.md` 一条 fix-rootcause tier=2 entry 关联该 postmortem（P1 commit 时 orchestrator relay 写入）。

### 3.4 影响文件清单（超 DEC-009 10 行硬约束，放本段）

**本 DEC 落盘影响（~0 代码 / ~3 文档）**：
- `docs/design-docs/orchestrator-compliance-gap.md`（本文件）
- `docs/decision-log.md` +DEC-030 Provisional 置顶
- `docs/exec-plans/active/orchestrator-compliance-gap-plan.md`（go-with-plan）

**P1 follow-up 实施影响**（~60-80 行）：
- `commands/workflow.md` 新 §Step 5c Handoff Checklist（~30 行）+ §Step 6.1 A 类模板旁 ref 一行（~1 行）
- `docs/bugfixes/orchestrator-compliance-gap.md`（new，~30-40 行 五段式 postmortem）
- `docs/log.md` +1 fix-rootcause tier=2 entry
- `docs/INDEX.md` +bugfixes 段条目
- critical_modules 命中 → tester（对抗性验证 layout 不冲突 §Step 6.1 已有模板）+ reviewer（对齐 DEC-024/013/006 维度）

**P2 follow-up 实施影响**（~40-60 行）：
- `scripts/orchestrator-compliance-check.sh`（new，~50 行）
- `CLAUDE.md` §工具链 追 `lint_cmd_compliance`（~2 行）
- `commands/workflow.md` §Step 5c + 事件类 b/c/d/e fire 处各加 "emit audit JSONL" 注（~6 行）；§Step 6.1 menu + pause 同加（~4 行）
- `hooks/session-start` + `scripts/preflight.sh` 追 ROUNDTABLE_AUDIT_PATH echo（~4 行）
- P2 自己可能开 DEC-031 Refines DEC-030（audit log schema / scan 算法决策）

**不改**（DEC-025 铁律 6 默认边界 + 本 DEC 显式声明）：
- DEC-024 / DEC-013 / DEC-006 / DEC-028 任何 Accepted 决定（Refines 不推翻）
- 4 agent prompt 本体（developer / tester / reviewer / dba）
- 2 skill prompt 本体（architect / analyst）—— P1 只改 workflow.md 章节，不改 skill prompt
- Resource Access matrix / Escalation Protocol JSON schema / Progress event schema / AskUserQuestion Option Schema
- Phase Matrix 9 stage 表结构 / critical_modules 触发机制
- target CLAUDE.md 业务规则边界
- final message `log_entries:` + `created:` YAML 位置 / 形态（D1=D）
- Resource Access 扩展 `/tmp/roundtable-contracts/`（拒 mitigation c 时顺带不改）

## 4. 关键决策与权衡

### D1 Finding 2 mitigation（4 options，recommended=D）

| 维度 (0-10) | A HTML comment | B frontmatter 前置 | C 外挂 contracts | D 保持现状 ★ |
|------------|---------------|-------------------|----------------|-------------|
| 对 hypothesis C 响应强度 | 2 | 3 | **9** | 0 |
| 对 hypothesis A/B 响应 | 0 | 0 | 0 | 0（独立修）|
| 实施复杂度反分（低=高分）| 7 | 6 | 2 | **9** |
| 架构一致性 | 5（原创无前例）| 4（违反 UX 惯例）| **8**（镜 DEC-004）| **9**（保现状）|
| 风险（双 critical_modules 命中反分）| 5 | 5 | 2 | **9** |
| 证据支撑（analyst 维度 3 拆耦）| 4 | 4 | 5 | **8**（承认无实证）|
| **合计** | 23 | 22 | 26 | **44** |

理由：Finding 2 无 A/B 实证 + a/b 对 hypothesis C 响应弱 + c 实施面 5-8x 于 d + 无参照前例（`<SUBAGENT-STOP>` 校正后）= 不预支结构性改动。

### D2 Finding 1 独立修复 posture（4 options，recommended=C）

| 维度 (0-10) | A 仅 layout | B 仅 enforcement | C 双层 ★ | D 仅文档化 |
|------------|-----------|----------------|---------|----------|
| 对 hypothesis A 响应 | 6 | 3 | **8** | 0 |
| 对 hypothesis B 响应 | 0 | **9** | **9** | 0 |
| 对 hypothesis C 响应 | 4 | 2 | **7** | 0 |
| 实施复杂度反分 | 8 | 5 | 4 | **9** |
| 收敛信心（基于 2026-04-22 复发证据）| 3 | **8** | **9** | 1 |
| 与 DEC-024/013 MUST 语义一致 | 7 | 8 | **9** | 2（冲突）|
| **合计** | 28 | 35 | **46** | 12 |

理由：Finding 1 已非首次 + soft rule 证不收敛 → 需 hard enforcement；layout 单独信心低；double-layer 是 analyst 维度 9 唯一 full-hypothesis 响应组合；DEC-029 ref density 已证 prose+scripts 双层在 roundtable 可落地。

### D3 follow-up issue 拆分（4 options，recommended=B）

| 维度 (0-10) | A 1 combined | B P1+P2 分 ★ | C P1 先 serialized | D 3 independent |
|------------|-------------|-------------|------------------|----------------|
| PR review 可管理性 | 4（120-160 行 3 类）| **8**（60-80 + 40-60）| 7 | 6 |
| 设计阶段独立性 | 3 | **9**（P2 独立 design 空间）| 5 | **9** |
| Acceptance criteria 满足（postmortem 及时）| 8 | **9** | 3（延 P2 违 AC）| 8 |
| 迭代节奏 | 5 | **9** | 7 | 4 |
| 实施依赖清晰度 | 5 | 8 | **9** | 6 |
| **合计** | 25 | **43** | 31 | 33 |

理由：P1 绑 layout+postmortem 同源结构修 + 一次 critical_modules 触发；P2 enforcement 需独立 audit log schema / scan 算法 architect round（可能开 DEC-031 Refines 本 DEC）；C 的延迟 postmortem 违反 issue #111 AC。

### D4（隐含，非 AskUserQuestion）是否新开 DEC

**判定 DEC-025 §开立门槛**：
- 5 类必开：✅ 第 4 类"推翻或细化已有 Accepted DEC 的决定条款"（Refines DEC-024 合规性维度 + 新 enforcement layer refining DEC-013 §3.1a 执行保障）
- 补充：第 1 类"跨模块接口 / 协议"（新 JSONL audit log schema 是 orchestrator emit 契约，与 DEC-004 progress_path 同形态）
- Red Flags：全部避开（非"看起来重要"/ 非 "3 文件"/ 非"同类都开"/ 非纯记录需求 / 非纯讨论追溯 / 非 tester findings）

开新 DEC-030。Refines DEC-024 + DEC-013 §3.1a + §Step 6 非 Supersede（保 decision-log 单调递增 + 对齐 DEC-021 / DEC-022 / DEC-023 的 Refines 模式）。

## 5. 讨论 FAQ

### Q1: 为什么不走"铁律 4 inline post-fix DEC-024"而开新 DEC？

**A**：铁律 4 明定 "clarification / 文本补丁 / 边角场景 id 格式" 走 inline post-fix；本 DEC 引入 **新备选评估** (mitigation a/b/c/d 4 方向) + **新 tradeoff**（SPEC→RUNTIME 合规性维度是新 lever）+ **跨 DEC 语义重构**（DEC-024 locus + DEC-013 §3.1a sticky + §Step 6.1 pause 三者合流） → 符合铁律 4 末句 "仅当改动引入新 tradeoff / 新备选评估 / 跨 DEC 语义重构时才开新 DEC"。

### Q2: Mitigation c (外挂 contracts) 是最干净的结构性答案，为什么推荐 d？

**A**：analyst 维度 3 明示 Finding 2 → Finding 1 因果**无 A/B 实证**；c 的 280-400 行 delta + double critical_modules 是基于 "倾向支持" 推论决策。按"证据驱动，不预支结构性改动"原则，先用 d + 独立修 Finding 1（D2=C）；若 P2 enforcement 落地后仍捕获 miss，届时有实证证据支撑 c 改造（届时开新 DEC，本 DEC § 5 "Follow-ups" anchor）。

### Q3: 为什么 layout 用 §Step 5c 而非整合 §Step 6.1？

**A**：§Step 6.1 A 类模板已 ~60 行（含 architect / Stage 9 / Q&A 循环 变体），整合会造成"找 checklist 要跨 60 行"的 grep 负担；§Step 5c 独立小节与 §Step 5 Subagent Escalation / §Step 5b 转发事件分类同家族，maintainer+LLM grep "handoff" 定位直接。同时 §Step 6.1 模板旁 ref 一行 `详见 §Step 5c` 保留 cross-ref affordance。

### Q4: Runtime enforcement 的 audit log 会不会又变成一个 orchestrator 漏写的点？

**A**：会。但：(1) audit log emit 是 "deterministic per-action" 而非 "conditional per-rule"，LLM attention 负担低于 §Step 5b 多事件类判定；(2) P2 enforcement 包含对 audit log 完整性的自检（若 event 未记录则 compliance-check 会 False-negative，dogfood 阶段可发现并加 meta-assertion "session active 但 audit log 空")；(3) 相比继续靠 prose rule，有 log 的漏比无 log 的漏更可归因可追溯。

### Q5: 为什么不同时修 workflow.md rule density（hypothesis A）？

**A**：issue #111 明示 workflow.md 精简重构 out-of-scope（独立 P2 umbrella）。本 DEC 的 layout 改（§Step 5c 抽小节）局部**微降** density（grep 命中率升 → LLM 检索成本降），但不做 §Step -0..§Step 8 全文精简。若 P2 enforcement 落地后仍捕获高频 miss + audit log 归因到 rule density dominant，开 P3 umbrella 独立 design。

## 6. 变更记录

- 2026-04-24（初稿）：基于 analyst 报告 + 3 决策点（D1=D / D2=C / D3=B）落盘 Draft；Stage 4 B 类 Accept/Modify/Reject 待用户裁决

## 7. 待确认项

- P1 follow-up issue title + body 草稿（Stage 9 Closeout bundle 产出）
- P2 follow-up issue title + body 草稿（同上）
- Tier 2 postmortem 在 P1 PR 内的具体章节顺序 / 5 段式字数上限
- runtime enforcement 的 audit log 是否在 plugin 分发时加入 .gitignore（tmpfs 路径默认不入仓）
- P2 自己是否必开 DEC-031 Refines 本 DEC（audit log schema 若有架构分歧则开；若只是 schema 确定则铁律 4 inline post-fix 本 DEC）—— P2 architect round 自行判断
