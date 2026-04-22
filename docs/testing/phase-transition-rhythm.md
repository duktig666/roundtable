---
slug: phase-transition-rhythm
source: design-docs/phase-transition-rhythm.md
dispatch_id: d96f30b8
created: 2026-04-19
role: tester
---

# phase gating taxonomy（DEC-006）对抗性测试报告

> 测试范围：`commands/workflow.md` §Step 6 规则 1 重写 + Phase Matrix 新增 Stage 9 Closeout；`docs/design-docs/phase-transition-rhythm.md` 全文；`docs/decision-log.md` DEC-006；`CLAUDE.md` critical_modules 条目 6。

## 执行摘要

| 等级 | 数量 | 典型代表 |
|---|---|---|
| Critical | 2 | C-01（Step 6.5/6.6 悬空引用）、C-02（Index Maintenance 与 C-auto-advance 批处理语义冲突）|
| Warning | 9 | W-01 ~ W-09 |
| Suggestion | 3 | S-01 ~ S-03 |

**总体判断**：三段式分类本身**心智正确、与 DEC-001~DEC-005 无语义冲突**；但新规则与既有的 workflow.md Step 3 artifact chain、Step 7 Index Maintenance、DEC-005 §6b 的连接处存在**规范空隙**（spec gap），少数指针是**断链**。在发正式合并前需至少修复 2 条 Critical。

---

## 1. 自洽性测试（workflow.md 内部）

### C-01 Critical · 悬空引用：Step 6.5 / 6.6 不存在

- **位置**：`commands/workflow.md` §Step 6 规则 1 新文本，以及 `docs/design-docs/phase-transition-rhythm.md` §3.1 新文本。
- **原文**：
  > "Critical findings, escalations, or lint/test failures still interrupt per Steps 5 / 6.5 / 6.6."
- **事实**：`commands/workflow.md` 的小节编号序列为 Step 5 → Step 6 → Step 6b → Step 7。**不存在 Step 6.5 / 6.6**。lint/test 执行规则实际在 Step 6 规则 4（"developer 完成后跑 lint_cmd + test_cmd"），tester 业务 bug 处理在 Step 6 规则 5（DEC-028 / issue #104 Step 6 rule 删 4 renumber 后；历史快照对应规则 5 / 6）。
- **影响**：文档断链；读者按指针跳转无果；LLM orchestrator 按此规则自查时引用不到规范。
- **复现路径**：在 workflow.md 中 `grep -nE "Step 6\.[56]"` 找不到被指引的 anchor。
- **建议修复**：将 `Steps 5 / 6.5 / 6.6` 改为 `Step 5 and Step 6 rules 5–6`（或把 Step 6 拆分并重编号）。

### C-02 Critical · Step 7 Index Maintenance 批处理语义与 C-verification-chain 自动前进冲突

- **位置**：workflow.md §Step 7（Batching rule）vs §Step 6 规则 1 C 类"auto-advance"。
- **矛盾**：
  - Step 7：`INDEX.md` 更新"once per phase gate (before reporting phase summary to the user), or at workflow completion"。
  - DEC-006 把 developer → tester / tester → reviewer / reviewer → dba → closeout 全归 C，orchestrator **auto-advance，1 行 handoff**，**没有向用户的 phase-gate summary**。
- **歧义**：C 链上每次 role 产出新 artifact（例如 tester 写 `testing/[slug].md`）时，Step 7 说"before phase-gate summary"——若 C 无 summary，INDEX.md 是否延迟到下一个 A 边界（Stage 9 Closeout）或工作流结束才批量更新？还是每个 C handoff 行之前也 Edit INDEX.md？
- **影响**：读 INDEX.md 的下游（`/roundtable:lint` 的 orphan 扫描）在 C 链中段可能看到过时索引；也可能出现"tester 产出了 testing/[slug].md 但 INDEX 在 closeout 才体现"的 24-hour stale window。
- **建议修复**：在 Step 7 Batching rule 增加一条 DEC-006 桥接说明：
  > "Under DEC-006 C-verification-chain, every C→C handoff notice is also an index flush point: orchestrator runs Step 7 single-Edit before emitting the 1-line handoff. At Stage 9 Closeout the final flush covers any still-pending entries."

---

## 2. 三段式分类的边界测试

### W-01 Warning · architect 纯精炼产出（无 decision-log 变更）是否仍 A 类？

- **场景**：用户 `调范围: 补几句 FAQ`，architect 仅更新 `design-docs/[slug].md` 不写新 DEC、不改 exec-plan。
- **DEC-006 原文**：A 类定义是 "phase ends with user-consumable artifacts"。design-doc 更新也是 artifact。**结论：仍为 A 类**，orchestrator 应继续 producer-pause 等用户 `go`。
- **风险**：小更新让用户觉得"第二次停下过度"——但这是 DEC-006 主动选择（见 design-doc Q3 裁决，"reviewer/architect 节奏"）。可接受。
- **建议**：在 workflow.md §Step 6 规则 1 A 条目补一句"任意 A-role 的后续 re-dispatch 返回后仍为 A，orchestrator 继续 producer-pause"以避免 LLM 错判"只改一点点不用停"。

### W-02 Warning · Medium 任务跳过 analyst：C 链起点是什么？

- **场景**：Step 1 pipeline Medium = `analyst (optional) → architect → ...`，用户任务描述不含研究需求。
- **Phase Matrix**：Stage 2 Research 状态 `⏩ skipped`。那么 C 类链表里 "context-detect → analyst" 不成立；实际是 context-detect → **architect**。但 architect 是 A 类。
- **DEC-006 描述**：C 链条列的是 `context-detect → analyst`，没列 `context-detect → architect`。
- **歧义**：C → A 转换本身是"C 的终点自动触发 A 的开始"。A 的开始（architect skill 激活）是否需要用户先 `go`？按 producer-pause 定义"phase **ends** with user-consumable artifacts"——A 的开头不 pause，A 的结尾才 pause。所以 orchestrator 从 context-detect 直接激活 architect 是合理的。
- **建议**：补充一行说明"C → A 边界：C 自动进入 A；A 的 producer-pause 在 A 产出后触发"——避免 LLM 把 Stage 2 Research ⏩ 后卡在等待上。

### W-03 Warning · critical_modules 为空 + reviewer 可选：C 链的可达性

- **场景**：target CLAUDE.md 未声明 critical_modules，Medium 任务。Pipeline：developer → tester（skip，非 critical）→ reviewer（optional, user may skip）→ closeout。
- **DEC-006 原文**：C 链条列 `developer → tester / tester → reviewer / reviewer → closeout`。
- **断点**：tester skipped 时 C 链如何跳接？`developer → reviewer`？还是 `developer → closeout`？两者都没在规则里明示。
- **建议**：把 C 链从枚举式（"developer → tester"）改为图式（"C 类任意跳过的 stage 透传到下一个存在的 C stage；全部跳过时直连 Stage 9 Closeout"）。

### W-04 Warning · 产出-暂停期间用户永不回话

- **场景**：A 完成后 orchestrator 3 行总结停下；用户离开 24h+。
- **design-doc §5 FAQ Q2** 回答 "无限"——orchestrator 不调用工具 = 不消耗 context。**此点正确**：Claude Code session 允许长暂停，不主动消耗 token。
- **验证**：确认 workflow.md 新文本中 A 规则明确写了"invoking no tools"。✅ workflow.md:251 有该文字。
- **风险**：session 一旦超出 server-side TTL（非 Anthropic 官方给出的硬上限但存在），用户重连后 orchestrator 需要复现 Phase Matrix。Phase Matrix 状态需要能从对话 transcript 重建。当前设计 ✅ 满足（Matrix 在每次 phase transition 报告）。
- **建议**：Suggestion 级别——在 design-doc §5 加一句"session 复连后 orchestrator 可由最近一次 Phase Matrix 回执定位"。

### W-05 Warning · 用户回复 `ok 但是 X`：go 还是 FAQ？

- **场景**：用户写 `ok 但是我想先确认一下 §3 的描述`。
- **design-doc §2.5** 的触发词包含 `ok` → 进入下一 stage。按关键字匹配，`ok 但是...` 会被判为 `ok`，跳过用户的 FAQ 意图。
- **对比**：严格前缀匹配（`^ok\s*$`）会漏掉"ok, move on"；宽松子串匹配会吞掉 `ok 但是`。
- **建议**：在 §2.5 补充优先级规则：
  > 1. 若消息含问号 / `问:` / `调:` / `停` / `但是` / `however` / 多行段落 → 视为 FAQ 或范围调整，**不** advance；
  > 2. 否则若以 `go` / `ok` / `继续` / `下一步` 开头且消息整体 ≤ 10 字 → advance；
  > 3. 其他情况 orchestrator 回显意图确认。

### W-06 Warning · DEC-005 per-dispatch AskUserQuestion 位于 C 类内部

- **位置**：DEC-005 §6b.2 per-dispatch → AskUserQuestion 弹窗选 inline/subagent。
- **冲突点**：DEC-006 §2.1 C 类定义"无用户决策点，orchestrator 自动前进"。而 developer 形态切换在进入 Stage 5（C 类）前**有用户决策**。
- **判读**：该 AskUserQuestion 属于"dispatch 前的配置性决策"，不是"phase transition 决策"。但 DEC-006 新文本未明示这一豁免。
- **影响**：未来开发者读规则时可能误认为 DEC-006 禁止 Stage 5 内部的 AskUserQuestion，从而错删 DEC-005 §6b.2 弹窗。
- **建议**：在 workflow.md §Step 6 规则 1 C 条目补一句"C 类仅规定 phase 边界行为，不禁止 stage 内部的配置性 AskUserQuestion（如 DEC-005 §6b.2 developer 形态切换、Step 1 任务尺寸 AskUserQuestion）"。

### W-07 Warning · Step 6 规则 2 "in-phase decisions MUST AskUserQuestion IMMEDIATELY" vs C 类 auto-advance

- **位置**：workflow.md §Step 6 规则 2（未改动）："In-phase decisions MUST AskUserQuestion IMMEDIATELY"。
- **与 DEC-006 关系**：规则 2 谈 **同一 role 内部** 的用户决策（architect 发现需选方案）；DEC-006 规则 1 谈 **跨 role** 的 phase 边界。两者正交。
- **但**：对 C 类 role 的"in-phase"（例如 developer subagent 内部想问用户选 A/B）——subagent 不能用 AskUserQuestion（DEC-002 Escalation），规则 2 对 subagent 已有 escalation 路径覆盖。**无冲突**，但 workflow.md 规则 2 文本未区分 skill / agent 语境，可能误读。
- **建议**：修改规则 2 文本为"In-phase decisions within **skills** MUST AskUserQuestion IMMEDIATELY; subagents emit `<escalation>` per Step 5"。

### W-08 Warning · Step 3 artifact chain 不含 Closeout stage

- **位置**：workflow.md §Step 3 Artifact chain（行 104-128）。
- **事实**：chain 终止于 `dba → reviews/[YYYY-MM-DD]-db-[slug].md`，没有 Closeout 行。
- **CLAUDE.md 条件触发规则** 明示："新增或修改 Phase Matrix 的 stages → 必须同步更新 `commands/workflow.md` §Step 3 artifact chain"。
- **结论**：**规则违反**——DEC-006 新加 Stage 9 但未同步 Step 3。
- **建议**：在 Step 3 末尾补：
  ```
  closeout → aggregates findings across reviewer / dba output
             produces no new files
             user drives commit / PR / amend decision (A producer-pause)
  ```

### W-09 Warning · Step 6 规则 1 A 类的"stops, invoking no tools" 与 Step 7 Index Maintenance 的"before reporting phase summary to the user"

- **位置**：workflow.md §Step 6 规则 1 A 类 vs §Step 7 步骤 3 "Before the phase-gate summary to the user, Read INDEX.md..."。
- **时序**：INDEX.md 的 Read/Edit 必须在 A 类 producer-pause summary **之前**。但 A 类 summary 发出即停；INDEX.md Read + Edit 是 pre-summary 操作，仍消耗 tool calls。
- **描述一致性**："stops, invoking no tools, waiting for the user's next message"——此"stops"是 summary emit 之后的状态。INDEX.md 更新是 summary 之前。**无冲突**。但文本可能让读者误以为 "A 类全程不 call tool"。
- **建议**：A 类文本改为"emits a 3-line summary (after any Step 7 INDEX.md update) and then stops, invoking no further tools"。

---

## 3. 与既有决策的兼容性

### S-01 Suggestion · DEC-001 ~ DEC-005 语义完整性

- **DEC-001 D8**（role→form 单射）：**无冲突**。DEC-006 不改角色形态，只改 transition 节奏。
- **DEC-002**（Resource Access / Escalation / Phase Matrix）：**无冲突**。DEC-006 是在 Phase Matrix 上加一层 gating 语义而非替换。
- **DEC-003**（research agent）：**无冲突**。research 是 architect 内部 fan-out，不属 phase transition 范畴。
- **DEC-004**（progress event protocol）：**无冲突**。C 自动前进时每个 sub-dispatch 仍独立 emit progress；user 看到的 1-line handoff 与 progress stream 解耦。
- **DEC-005**（developer 双形态）：潜在边界见 W-06，但本质**无冲突**——inline 形态跳过 Step 3.5 Monitor 与 DEC-006 C 类逻辑正交。

### S-02 Suggestion · feedback_askuserquestion_options 与 B 类 option schema

- 用户记忆："弹窗选项必带说明+推荐（每个选项必含 rationale/tradeoff/推荐标记；analyst 只陈事实不推荐）"。
- workflow.md §Step 6 规则 1 B 类新文本："Each option carries `rationale` + `tradeoff` + **optional** `recommended`"。
- "optional" vs "必含 推荐标记" 字面冲突；但 analyst 不允许设 `recommended: true`（仅保留字段 = `null` / false）——"字段必含，值可为空"才是正解。
- **建议**：B 类文本改为"each option carries `rationale` + `tradeoff`; `recommended` field is mandatory but its value MAY be null (architect allows ≤ 1 true; analyst forbids true)"。

### S-03 Suggestion · Step 5 Escalation 与 A 类 producer-pause

- 两者都让 orchestrator 停——**机制**不同：Escalation 走 AskUserQuestion 选项化；producer-pause 走自由文本。
- 理论边界：agent 完成后最终报告里同时有完成信息 + `<escalation>` block，orchestrator 应优先处理 escalation（走 Step 5 AskUserQuestion）而非 producer-pause 行为——但 agent 位于 C 类（developer/tester/reviewer/dba），本就不触发 producer-pause。所以实际**无冲突**。
- **建议**：在 Step 6 规则 1 C 类条目末尾补半句"C 类中间若出现 `<escalation>`，按 Step 5 处理（优先于 C auto-advance）"，把当前"仍中断"的模糊表述落实成具体路由。

---

## 4. 失败模式覆盖（对照 analyst §失败模式事实）

| analyst 列出的失败模式 | DEC-006 规则是否解决 | 复核 |
|---|---|---|
| 选项疲劳（每次 transition 弹窗）| ✅ B 类仅 design-confirm 一处 | 通过 |
| 自动链路静默推过 Critical | ⚠️ 见 W-11 补强 | 部分通过 |
| producer-pause 被误解为 FAQ | ⚠️ 见 W-05 语义规则 | 需补 |
| 选项疲劳诱发 `ok` 惯性点击 | ✅ 只剩 1 个 AskUserQuestion | 通过 |

### W-10 Warning · C 自动链路下 Critical 能否"静默漏过"

- **场景**：reviewer subagent 在 C 链中段产出 Critical finding。
- **要求链条**：
  1. reviewer.md §Critical-finding ordering discipline → 先 emit `phase_blocked`（progress 流）
  2. 写 `reviews/[date]-[slug].md`
  3. 发 `<escalation>` block
  4. workflow.md Step 5 → orchestrator 解析 escalation → AskUserQuestion
- **DEC-006 新规则"仍中断"是否兑现**：依赖 orchestrator 实际执行 Step 5 解析。若 orchestrator 因 C auto-advance 字面而直接进 dba/closeout 忽略 `<escalation>`，静默失败成立。
- **测试用例（伪）**：构造一个 review subagent 返回同时含 `<escalation>` 和正常 review 摘要；检查 orchestrator 是否先调 AskUserQuestion。
- **建议**：在 workflow.md §Step 6 规则 1 C 类末尾加 1 行测试性断言："Before emitting the C-class handoff notice, the orchestrator MUST scan the subagent's final message for `<escalation>` tags; if present, suspend auto-advance and invoke Step 5."。

### W-11 Warning · 用户 `看看` 歧义

- **场景**：producer-pause 后用户回 `看看`。
- **解读分支**：
  - `看看` = "我看看" = "我在阅读" = 不 advance；
  - `看看` = "看看（确认）go 继续" = advance（低概率）；
  - `看看 §3` = "请 orchestrator 帮我解释 §3" = FAQ。
- **design-doc §2.5** 触发词不含 `看看`，**默认会走 orchestrator 回显意图确认**（若采纳 W-05 建议的优先级规则）。
- **建议**：与 W-05 合并处理——orchestrator 对未匹配的短消息采取"回显确认"而非盲推进。

---

## 5. 回归测试

### S-04 Suggestion · issue #7（DEC-005 double-form）工作流是否被新规则破坏

- issue #7 落地在 DEC-005 `developer` 双形态：
  - inline：跳过 Step 3.5 Monitor，AskUserQuestion 直连；
  - subagent：走 Step 3.5 + Escalation。
- DEC-006 改的是 phase transition 粒度（role 与 role 之间的 gate），与 DEC-005 改的是 role **内** 形态，**正交**。
- **验证**：P4 dogfood 实录中 inline developer 路径在新规则下：
  - design-confirm (B) 通过 → 自动进 Stage 5 (C) → inline 执行 developer → lint/test → 自动进 Stage 6 (tester, C) 或直接 Stage 9 Closeout (A)
  - 任何中段 AskUserQuestion（例如 DEC-005 §6b.2 形态切换）仍照常触发。见 W-06 文本建议使其显式。
- **结论**：无回归。

### S-05 Suggestion · `/roundtable:bugfix` 是否受 DEC-006 影响

- `commands/bugfix.md` 不含 Phase Matrix，不走三段式分类。
- design-doc §3.4 明示 "不动文件：commands/bugfix.md"。
- **潜在混淆点**：bugfix 内部 developer → (optional) reviewer/dba 的 handoff 不需走 DEC-006；但 bugfix.md 未声明豁免，若读者跨命令复用心智可能误用。
- **建议**：bugfix.md 增加 1 句免责声明 "DEC-006 phase gating taxonomy 不适用于 bugfix 流程；本命令无 phase gate 概念"。

---

## 6. 发现的潜在问题（反馈给 developer / architect）

高优先级：
1. **Critical C-01**（Step 6.5 / 6.6 悬空）——文档断链，必须修
2. **Critical C-02**（Index Maintenance vs C auto-advance 批处理语义）——需补桥接条款
3. **Warning W-08**（Step 3 artifact chain 未同步 Stage 9）——违反 CLAUDE.md 条件触发规则硬性纪律

中优先级：
4. W-01 / W-02 / W-03 / W-05 / W-06 / W-10 / W-11——规则边界不清，需补细则
5. W-07 / W-09——文本措辞，易误读

低优先级：
6. S-01 ~ S-05——建议优化项，可分批合并

---

## 7. 变更记录

- 2026-04-19 创建；dispatch_id d96f30b8。

---

## created

- path: docs/testing/phase-transition-rhythm.md
  description: DEC-006 三段式 phase gating 对抗性测试（2 Critical + 9 Warning + 5 Suggestion）
