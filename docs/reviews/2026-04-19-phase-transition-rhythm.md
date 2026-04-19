---
slug: phase-transition-rhythm
source: design-docs/phase-transition-rhythm.md
dispatch_id: c2d55c0d
created: 2026-04-19
role: reviewer
---

# DEC-006 phase gating taxonomy 最终合并审查

> 范围：`commands/workflow.md`（Phase Matrix + Step 3 artifact chain + Step 6 rule 1 + Step 7 bridging clause）、`docs/design-docs/phase-transition-rhythm.md`、`docs/decision-log.md` DEC-006、`CLAUDE.md` critical_modules 条目 6；对照 tester 报告（2C/9W/5S）+ analyst 报告 + DEC-001~DEC-005。
>
> 本次为 critical_modules-tagged 变更（workflow command Phase Matrix + phase gating taxonomy），强制落盘审查。

## 执行摘要

| 等级 | 数量 | 代表 |
|---|---|---|
| Critical | 0 | — |
| Warning | 3 | RW-01（template drift）、RW-02（design-doc §3.1 仍含"Steps 5 / 6.5 / 6.6"残留幽灵指针）、RW-03（W-10 仅半兑现） |
| Suggestion | 5 | RS-01 ~ RS-05 |

**最终裁定**：**Approved-with-caveats**。tester 提出的 2 条 Critical 已由 inline developer 落实（C-01 指针修复、C-02 Step 7 桥接），W-08 artifact chain 补全也已落地。DEC-006 与 DEC-001~DEC-005 无语义冲突，三段式分类与 user north-star（减选项疲劳、保 FAQ 空间、保硬 gate 纪律）对齐。遗留的 3 条 Warning 均为**非阻塞性文档漂移**，建议在本 PR 内顺手修一次收口；如工期紧，最小必修项仅 RW-01 和 RW-02。

---

## 1. DEC 对齐审查（对照 DEC-001 ~ DEC-005）

| 既有 DEC | 可能的冲突面 | 核验结论 |
|---|---|---|
| DEC-001 D2（零 userConfig） | 新规则是否引入 plugin 元协议外的用户配置？ | ✅ 无。三段式全部硬编码在 workflow.md prompt 本体。 |
| DEC-001 D5（Scope=user） | analyst 报告曾指出 issue 原文引用 D5 不准确 | ✅ DEC-006 正文未再引用 D5，避免了误引。 |
| DEC-001 D8（role→form 单射） | 形态分配未改 | ✅ DEC-006 只改 transition 节奏。 |
| DEC-002（Resource Access / Escalation / Phase Matrix） | Phase Matrix 被扩展 | ✅ 扩展方式为 append（Stage 9）+ 语义分类层，未替换 DEC-002 结构。 |
| DEC-003（research agent） | research 是 architect 内部 fan-out | ✅ 不涉 phase transition，无冲突。 |
| DEC-004（progress event protocol） | C 自动前进时 progress stream 是否仍正确？ | ✅ 每个 sub-dispatch 独立 emit，DEC-004 `Monitor` tail 语义保留；workflow.md Phase Matrix 下"Real-time progress stream"描述未被 DEC-006 破坏。 |
| DEC-005（developer 双形态） | §6b per-dispatch AskUserQuestion 落在 C 类 stage 内 | ✅ 本质是 pre-dispatch 配置性决策，不违反 C 类"phase 边界无用户决策"纪律。见 RW-03 建议。 |

**结论**：**不需要 Superseded 任何既有 DEC**；DEC-006 设为 Accepted 符合 append-only 铁律。

---

## 2. Tester Critical/Warning 处置核验

### ✅ C-01（悬空指针 Step 6.5/6.6）— 已修

- `commands/workflow.md:266` 现为 `"per Step 5 and Step 6 rules 5–6"`，指向真实存在的 Step 6 规则 5（lint/test）和规则 6（tester business bug）——根因级修复，非字面替换。
- design-doc §3.1 "新文本" 块（第 107 行）也已同步为 `"per Step 5 and Step 6 rules 5–6"`。**但** design-doc §6 变更记录里描述为 "Step 6.5/6.6 → Step 5 + Step 6 rules 5–6"——作为历史变更注记合理。
- 见 **RW-02** 对 design-doc 其他位置残留指针的补充核验。

### ✅ C-02（Step 7 Batching vs C-auto-advance 批处理冲突）— 已修

- `commands/workflow.md:380` 新增 "DEC-006 C-verification-chain bridging clause"，明示 "每次 C→C handoff 之前先跑 Step 7 single Read+Edit"；Stage 9 的 final flush 兜底。
- 语义完整：既保住 `/roundtable:lint` 索引扫描的鲜度，又维持 single-Edit per boundary 的 token 成本天花板。**根因级修复**。

### ✅ W-08（Step 3 artifact chain 未同步 Stage 9）— 已修

- `commands/workflow.md:128-130` 新增 `closeout → aggregates findings ... (DEC-006 A producer-pause)` 行。
- 满足 CLAUDE.md 条件触发规则硬性要求（"新增 Phase Matrix stages → 必须同步 Step 3 artifact chain"）。

### ⚠️ W-10（C 链中 Critical 静默漏过）— 部分兑现

- workflow.md §Step 6 规则 1 C 条目末尾已加断言："Before emitting the C-class handoff notice, the orchestrator MUST scan the subagent's final message for `<escalation>` tags; if present, suspend auto-advance and route through Step 5."
- **但**：reviewer.md / tester.md 的 `## Progress Reporting` Critical-finding ordering discipline 是否同步提及"phase_blocked 优先于 handoff"？tester 报告 W-10 要求的是完整链条（`phase_blocked` → write report → `<escalation>` → orchestrator Step 5）。workflow.md 只覆盖 orchestrator 侧扫 escalation；agent 侧 discipline 仍靠各 agent 自身的 Progress Reporting 节。见 **RW-03**。

### 其他 Warning / Suggestion 未修处置

| 编号 | tester 提出 | 是否在本 PR 修复 | reviewer 意见 |
|---|---|---|---|
| W-01（A-role re-dispatch 后仍为 A） | 未 | 可接受，顺理成章 | 延后可 |
| W-02（Medium 跳过 analyst 时 C→A 边界） | 未 | 顺理成章 | 延后可 |
| W-03（critical_modules 为空 + tester skip 时 C 链断点） | 未 | 非零概率 UX 缺陷 | 见 RS-01 |
| W-05（`ok 但是 X` 语义） | 未 | 低概率但存在 | 见 RS-02 |
| W-06（DEC-005 §6b.2 AskUserQuestion 落 C 类内） | 未 | 易被未来读者误读 | 见 RW-03 |
| W-07（Step 6 规则 2 skill/subagent 语境） | 未 | 文字小 polish | 延后 |
| W-09（A 类 stops 措辞 vs Step 7 Read/Edit） | 未 | 读者易误读 | 延后 |
| W-11（`看看` 歧义） | 未 | 与 W-05 同类 | 延后 |
| S-01 ~ S-05 | 未 | 均为 polish | 延后 |

---

## 3. User north-star 核验

| 目标 | DEC-006 表现 |
|---|---|
| 减选项疲劳 | ✅ AskUserQuestion 由"每 cross-role transition"收窄到仅 design-confirm (Stage 4)。 |
| 保 FAQ 空间 | ✅ A 类 producer-pause 自由文本 `问:` 不受弹窗切断；orchestrator 不调用工具 = 不消耗 context。 |
| 保硬 gate 纪律 | ✅ design-confirm 仍 AskUserQuestion，符合 terraform apply / apt install 行业共识。 |
| 与 feedback_no_auto_push / _pr 同构 | ✅ Stage 9 Closeout 等用户驱动 commit/PR/amend，零自动 git。 |
| 方向与 CrewAI/LangGraph 主流对齐 | ✅ "默认自动 + 显式 gate 声明" 翻转旧"默认 gate + 例外自动"。 |

---

## 4. Reviewer 新增发现

### 🟡 RW-01 Warning · `docs/claude-md-template.md` / `README.md` 未同步 DEC-006 心智

- **事实**：design-doc §3.4 "其他受影响文件" 明列 `docs/claude-md-template.md` "同步更新 roundtable 自身 CLAUDE.md 模板里对应条目，保持 template 权威" 和 `README.md` "可选：用户向文档若提到每 phase 停下确认，更新为产出阶段停下等 go / approval gate 强弹窗 / verification chain 自动"。
- **核验**：`Grep "phase gat|Phase Matrix|workflow command|producer-pause|verification-chain|approval-gate|closeout|DEC-006"` 在 `docs/claude-md-template.md` 和 `README.md` 中均 0 命中；`docs/onboarding.md` 同样 0 命中。
- **影响**：外部用户项目从 template 抄 CLAUDE.md 时不会传导"三段式"心智；且 template 的 critical_modules 示例条目 6 若复制自旧版，会缺 "phase gating taxonomy (DEC-006)" 后缀——与 roundtable 自身 CLAUDE.md 不一致，违反 design-doc "保持 template 权威" 的声明。
- **建议修复**：在 template 的 critical_modules 示例 + FAQ 区添加最小提及；README 可延迟到 issue #9 文档 polish 一并处理，但 template 权威性问题本 PR 应闭环。

### 🟡 RW-02 Warning · design-doc §3.1 "旧文本" 块保留"Steps 5 / 6.5 / 6.6"措辞合理，但变更记录叙述有瑕疵

- **事实**：`design-docs/phase-transition-rhythm.md:99-100` 的 "旧文本" quote 是对 workflow.md 修改前文本的历史引述，**不应改**。但 §6 变更记录第 222 行 "修 C-01 悬空指针（Step 6.5/6.6 → Step 5 + Step 6 rules 5–6）" 的描述会让未来读者误以为 workflow.md 历史上真存在过 Step 6.5/6.6。实际情况是 tester 提出的新文本初稿写错了指针，而非 workflow.md 原本存在这些 anchor。
- **影响**：low——仅文档叙述准确性；不阻塞合并。
- **建议修复**：把变更记录改为 "修 C-01：新文本初稿误写的 Steps 5 / 6.5 / 6.6 改为真实存在的 Step 5 + Step 6 rules 5–6"。

### 🟡 RW-03 Warning · W-10 只半闭环 + W-06 未补豁免注记

- **W-10 半闭环**：workflow.md C 条目已加 "scan `<escalation>` before handoff" 断言；但 reviewer.md / tester.md 在 critical 发现时的 `phase_blocked` 先发（progress）→ 报告落盘 → `<escalation>` 顺序，仍依赖各 agent 自身 `## Progress Reporting` 节的 Critical-finding ordering discipline。未校验这些 agent prompt 是否都有对应条款。
- **W-06 未补**：C 类 orchestrator 规则里没有显式声明 "stage 内部的配置性 AskUserQuestion（DEC-005 §6b.2、Step 1 任务尺寸 ambiguous）不被 C 类自动前进禁止"。未来读者可能误删 §6b.2 弹窗。
- **建议修复**：C 条目末尾再加一句 "C 类仅约束 phase 边界行为，不禁止 stage 内部配置性 AskUserQuestion（如 DEC-005 §6b.2 developer 形态切换、Step 1 任务尺寸 ambiguous 分支）"。

### 🔵 RS-01 Suggestion · C 链 skip 透传规则

- tester W-03 指出 `developer → (tester skip) → reviewer?` 的跳接未明示。建议在 workflow.md §Step 6 规则 1 C 条目补 "被 skipped 的 C 类 stage 透传到下一个存在的 C stage；所有 C stage 都 skip 或完成时直接进 Stage 9 Closeout"。

### 🔵 RS-02 Suggestion · producer-pause 文本触发词优先级

- tester W-05、W-11 涉及自由文本驱动的歧义（`ok 但是`、`看看`）。建议 design-doc §2.5 加优先级规则：含问号/`问:`/`调:`/`停`/多行或 "但是/however" 判 FAQ；纯 `go`/`ok`/`继续`/`下一步`（≤10 字）判 advance；其他回显确认。

### 🔵 RS-03 Suggestion · feedback_askuserquestion_options 与 B 类 recommended 字段语义

- tester S-02 观察到 B 类文本 "optional `recommended`" 与用户记忆 "必含推荐标记" 字面冲突。建议改 B 条目为 "each option carries `rationale` + `tradeoff`; `recommended` field is mandatory but its value MAY be null (architect allows ≤ 1 true; analyst forbids true)"。

### 🔵 RS-04 Suggestion · bugfix.md 加 DEC-006 豁免声明

- `commands/bugfix.md` 不走 Phase Matrix，与 DEC-006 正交。但外部读者可能跨命令复用心智。建议 bugfix.md 报告格式或执行规则区加 1 行 "DEC-006 phase gating taxonomy does not apply to bugfix; this command has no phase-gate concept."

### 🔵 RS-05 Suggestion · Stage 9 Closeout 产出类型 "aggregate summary" 未指定格式

- Step 3 artifact chain "closeout → produces no new files"；但 aggregate summary 是否有固定结构（findings 条数 / 影响文件 / 建议下一步）？当前靠 orchestrator 即兴。建议 design-doc 或后续 exec-plan 定义 3 字段最小契约：`findings_by_severity: {critical, warning, suggestion}`、`impacted_files`、`suggested_next_step`。

---

## 5. 决策一致性（per DEC-xxx 检查）

- ✅ **与 DEC-001** 一致：append-only 铁律保守；D8 role→form 未改。
- ✅ **与 DEC-002** 一致：Resource Access / Escalation / Phase Matrix 三件套结构保留，DEC-006 是其上的语义层。
- ✅ **与 DEC-003** 一致：不涉 research fan-out。
- ✅ **与 DEC-004** 一致：C 自动前进不削弱 progress event 链；每 sub-dispatch 独立 emit；workflow.md "Real-time progress stream" 条仍完整。
- ✅ **与 DEC-005** 一致：developer 双形态切换机制保留；见 RW-03 W-06 建议补豁免注记避免未来误读。
- ✅ **DEC-006 本身**：Accepted 状态，无需 Superseded 任何条目；正文与 design-doc 完整对齐（Q3~Q6 四条裁决均有映射）。

---

## 6. Prompt 文件健康 / Lint

- ✅ `grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/` = **0 命中**。
- ✅ `commands/workflow.md` 本体全英文（中英混杂整改纪律保持），符合 CLAUDE.md 通用规则。
- ✅ `docs/design-docs/phase-transition-rhythm.md`、`docs/decision-log.md` DEC-006、CLAUDE.md 中文——符合"用户产出文档中文"纪律。

---

## 7. Dogfood 兼容

- ✅ `commands/bugfix.md` 未被 DEC-006 波及（设计层明确声明）；dogfood 场景下 bugfix 流程不变。
- ✅ issue #7 的 DEC-005 双形态（inline / subagent）与 DEC-006 正交：inline 跳过 Step 3.5；C 类自动前进对 inline/subagent 一视同仁。RW-03 建议补豁免注记防未来误读。
- ⚠️ template / README / onboarding 未同步 DEC-006（RW-01），外部新用户仍会看到旧"每 phase confirm"心智。

---

## 8. 最终裁决

**Approved-with-caveats**

**阻塞性问题**：0（无 Critical）

**合并前最小必修项**（建议但非强阻）：
1. RW-01 的 `docs/claude-md-template.md` critical_modules 示例条目 6 同步扩展（template 权威性硬要求）
2. RW-02 的 design-doc §6 变更记录措辞微调（避免历史叙述不准）

**可延后项**：RW-03、RS-01 ~ RS-05 + tester 未修的 W-01~W-07/W-09/W-11、S-01~S-05 中的 polish 项，可并入下一轮 issue #9（文档 polish）或独立小 PR。

**核心价值判断**：DEC-006 的三段式分类从根本上解决了 issue #10 提出的 UX 问题（选项疲劳 / FAQ 切断 / 与 no-auto-push 纪律不同构），实施面小（仅 workflow.md + decision-log.md + CLAUDE.md + design-doc 四处结构性改动），回归风险可控（不改形态、不改 Phase Matrix 状态机、不改 Option Schema），与 AI agent 框架主流方向对齐。**值得合并**。

---

## 变更记录

- 2026-04-19 创建；dispatch_id c2d55c0d。

---

## created

- path: docs/reviews/2026-04-19-phase-transition-rhythm.md
  description: DEC-006 phase gating taxonomy 最终合并审查（0 Critical / 3 Warning / 5 Suggestion；Approved-with-caveats）
