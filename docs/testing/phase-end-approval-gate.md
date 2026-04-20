---
slug: phase-end-approval-gate
source: design-docs/phase-end-approval-gate.md
created: 2026-04-21
---

# Phase-End Approval Gate 测试计划（对抗性 prompt 审查）

issue #30 P1 bug 修复对抗性审查。critical_modules 命中 3/3（workflow Phase Matrix + Escalation Protocol + skill/agent/command prompt 本体），tester 必触发。改动形态为 prompt markdown 编辑，无运行时代码；对抗重点在**语义一致性、规则冲突、回归保护、auto_mode 兼容性、Q&A 循环可终止性**。

## 审查范围

- `commands/workflow.md` Step 6.1 A 类扩写（行 242-264）
- `skills/architect/SKILL.md` §阶段 3（行 63-76）
- `skills/analyst/SKILL.md` §工作流程 step 8（行 168）
- `docs/decision-log.md` DEC-006 影响范围 post-fix 2026-04-21（行 309）
- `docs/design-docs/phase-end-approval-gate.md`（新建）

## lint 结果

`grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/` → **0 命中** ✓

---

## 严重度分级汇总

| 编号 | 严重度 | 主题 |
|------|--------|------|
| F1 | **Critical** | architect A 类与 B 类 Design confirmation（Stage 4）边界混淆 |
| F2 | **Critical** | `go-without-plan` 豁免理由落盘路径与 architect Resource Access 冲突（已 Accepted design-doc 再 append section） |
| F3 | **Warning** | auto_mode 下 architect A 类 `go-with-plan` / `go-without-plan` 无 recommended 标记，§Auto-pick 触发 auto-halt |
| F4 | **Warning** | fuzzy 降级 `go` → `go-with-plan` 单向掩盖用户"想 skip"的意图（UX 反向） |
| F5 | **Warning** | Q&A 循环无显式终止语义 / 递归深度保护 / 幂等保证 |
| F6 | **Warning** | Stage 9 Closeout 也属 A 类但菜单协议未同步扩展 |
| F7 | **Suggestion** | analyst step 8 "返回 orchestrator" 缺可机读信号，orchestrator 无法区分 "FAQ answered" vs "user said go" |
| F8 | **Suggestion** | design-doc §1.3 称 bugfix "无 A 类不受影响"，但 Stage 9 Closeout 对 bugfix 仍属 A 类，表述不准 |
| F9 | **Suggestion** | Q&A 多轮循环与 analyst `log_entries:` 上报交互：Step 8 flush 重复触发风险 |
| F10 | **Suggestion** | architect 菜单改 2 option 后，design-doc §5 测试策略 "6 option 兼容性" 缺 regression 表 |
| P1 | **Positive** | critical_modules 3/3 命中 + tester 触发 + lint 0 命中，影响面声明充分 |
| P2 | **Positive** | 豁免必落盘 + 菜单穷举原则 + 禁止 silent default 与 DEC-006 心智同源 |

---

## Critical

### F1：architect A 类与 B 类 Design confirmation 边界混淆

**定位**：`commands/workflow.md` 行 260-262（architect 阶段变体）+ design-doc §1.3 / §3.1。

**问题**：
- DEC-006 Phase Matrix 映射（workflow.md 行 272）明确 **Stage 4 Design confirmation = B 类**，协议是 `AskUserQuestion`（Accept / Modify / Reject）。
- 但本 post-fix 让 architect Stage 3 结束（A 类 producer-pause）emit `go-with-plan` / `go-without-plan` 菜单后**直接推进 Stage 4**（design-doc §3.1 写 "跳过 exec-plan 直接 Stage 4 design confirmation"）。
- 这让 A 类（Stage 3 architect done）菜单选项承担了 "是否写 exec-plan" 的业务决策，而 Stage 4（真正的 B 类 approval-gate）本应是 design-doc 本身的 Accept/Modify/Reject。
- **规则冲突**：`go-with-plan` 同时触发两件事（1）写 exec-plan；（2）进入 B 类。但用户点了 `go-with-plan` 不等于 Accept design-doc；如果用户既想写 exec-plan 又想 Modify design-doc，当前菜单无表达路径。
- 原 DEC-006 的 A 类 `go` 语义是"推进下一阶段"，下一阶段即 B 类 Stage 4 gate。本改动把 exec-plan 决策**嵌入** A 类菜单，事实上让 A 类承担了部分 B 类决策逻辑。

**证据**：
- workflow.md 行 266-267：B 类 "唯一 B 类是 Design confirmation（Stage 4）"
- workflow.md 行 260-261：`go-with-plan` "写 ... 后进入 Stage 4"
- design-doc §3.1 行 120：`go-without-plan` "跳过 exec-plan **直接 Stage 4 design confirmation**"

**建议修复**：
- 澄清 exec-plan 是 Stage 3 architect producer-pause 的**产出选项**（决定是否多产出一个文档），不是 "推进 Stage 4" 的 gate 本身。用户点 `go-with-plan` 后仍须经过独立的 Stage 4 B 类 gate。
- 或在 design-doc §2.2 D2 补一段明说：A 类菜单的 `go-*` 二选一决定"产出范围"，**不跳过** B 类 Stage 4 Accept/Modify/Reject。
- workflow.md 行 260-261 改为 "写 exec-plan 后**进入 Stage 4（B 类 gate 照常）**"，消除 "直接 Stage 4" 的歧义。

---

### F2：`go-without-plan` 豁免理由落盘冲突 architect Resource Access

**定位**：`commands/workflow.md` 行 261 + `skills/architect/SKILL.md` 行 71 + design-doc §3.1 行 120。

**问题**：
- 三处均写 "orchestrator 落盘到 design-doc 末尾新增「§执行计划豁免」section **或** log.md 条目"。**双落点选择权未定义**（哪种情况用哪种？）。
- 更严重：**时序冲突**。阶段 2 结束时 architect 已写完 design-doc 并 `log_entries:` 上报（SKILL §阶段 2 step 9）；design-doc frontmatter `status` 可能已是 `Draft` 或用户已审阅。此时 orchestrator 追加 §执行计划豁免 section 是否改动一个**已在同轮 log_entries 声明的文件**？orchestrator 在 Step 8 flush 前的中间态写入会让 Step 7 INDEX 和 Step 8 log 描述与实际 byte 内容脱钩。
- architect Resource Access matrix（SKILL.md 行 17-19）明确 **Write** 限 architect；orchestrator 自身要 Edit architect 写的 design-doc 违背 shared-resource 转发纪律（Step 7/8 的前置假设是 orchestrator 只 Edit INDEX.md / log.md）。
- 若选 log.md 条目：走哪个 `prefix`？`decide`？`fix-rootcause`？design-doc §4 只提 "fix-rootcause-style entry 或 design-doc inline 均接受"（§4 行 181），没给确定 prefix。Step 8 YAML 契约 `prefix` 枚举内无 "exec-plan-waiver"。

**建议修复**：
- 二选一**确定**：建议走 **log.md 条目**路径，prefix 复用 `decide`（decision 性质）或 `exec-plan`（与 exec-plan 产出同前缀 flip 语义）。避免 orchestrator 回写 design-doc。
- 若坚持 design-doc inline，需在 SKILL Resource Access 加例外行：orchestrator **允许** Edit architect 已写 design-doc 末尾追加 §执行计划豁免（限本 section）。
- 明确 `go-without-plan: <理由>` 的理由文本 orchestrator 应如何**提取**：用户自由文本回复，fuzzy 解析是否 strip 前缀 `go-without-plan:`？还是整句入库？

---

## Warning

### F3：auto_mode 下 architect A 类菜单 recommended 缺失触发 auto-halt

**定位**：`commands/workflow.md` §Auto-pick 表行 294（`A 类 producer-pause ... 无条件 auto-go`）vs 行 260-262（architect 变体拆 2 option）。

**问题**：
- §Auto-pick 表规定 A 类无条件 `auto-go <role> ✅`（单一动作无需选项）。但改动后 architect A 类变成**有 2 可见选项**的 pause，且 **design-doc / prompt 本体未在菜单内标 `recommended: true`**（只在 SKILL §阶段 3 括号提 "推荐：中/大任务"，这不是 schema 信号）。
- auto_mode=true 时 orchestrator 走 §Auto-pick 的哪条规则？
  - 若走 "A 类无条件 auto-go"：orchestrator 该 auto-go 到哪个分支？design-doc §5 测试策略行 192 说 "auto-pick `go-with-plan`（保守默认）"，但这是 **orchestrator 的启发式**，不是 agent 的 `recommended` 预授权，违反 §Auto-pick 行 300 "`recommended: true` 即 agent/skill 在设计阶段的**预授权**" 的原则。
  - 若走 "B 类 approval-gate 含 recommended 才 auto-accept"：A 类两 option 都未标 recommended → 触发 `🔴 auto-halt`，auto_mode 退化为 manual。
- design-doc §4 行 179 声称 "auto_mode 下 `go-with-plan` = recommended → auto-accept"，但 prompt 本体**没让 architect 标 recommended**（SKILL.md 行 67 只写 "推荐：中/大任务" 这是 description 文本非 schema）。

**建议修复**：
- 二选一：
  - **方案 A**：SKILL §阶段 3 明确要求 architect 在菜单里给 `go-with-plan` 标 `recommended: true`（中/大任务）或 `go-without-plan` 标 `recommended: true`（小任务，根据 Step 1 size 判定）。workflow §Auto-pick 行 294 对 architect A 类加例外：按 recommended 走 auto-pick 语义（与 B 类同型）。
  - **方案 B**：design-doc §5 行 192-193 的 "auto-pick `go-with-plan`（保守默认）" 上升为正式规则写入 workflow.md Step 6.1 architect 变体：`auto_mode=true` → 默认 `go-with-plan`，emit 审计行 `🟢 auto-go architect (default: go-with-plan)`。

---

### F4：fuzzy 降级 `go` → `go-with-plan` 单向掩盖用户 skip 意图

**定位**：`commands/workflow.md` 行 262 + design-doc §5 测试用例行 195。

**问题**：
- fuzzy 规则：用户只输 `go` → 保守默认 `go-with-plan`。
- 但 DEC-006 §A 原协议里 `go` = "推进下一阶段"，**无 with-plan 含义**。用户若长期习惯输 `go`（或通过 TG 键盘快捷输入），实际可能想 skip 而被系统**默认写 exec-plan**。
- 这是**保守默认**但反向 UX：对小任务（1 文件 bug fix）用户输 `go` 以为推进，orchestrator 却多写一个 exec-plan.md，浪费 token 且违反 DEC-010 "轻量化心智"。
- 反向：无 fuzzy `go` → `go-without-plan` 降级，意味着 skip 必须显式输 `go-without-plan: <理由>` 完整串。

**建议修复**：
- fuzzy 降级前先**反问一次**：用户输 `go` → orchestrator emit 一次澄清 `<decision-needed>`（"您是想 `go-with-plan` 还是 `go-without-plan: <理由>`？默认 with-plan。"），避免 silent 降级。
- 或基于 Step 1 size 判定决定 fuzzy 方向：小任务 `go` → `go-without-plan: (task 小，已闭合)` 自动填理由；中大任务 `go` → `go-with-plan`。
- 至少在 workflow.md 行 262 加一句 "fuzzy 降级时 orchestrator **必须** 在 audit 行打 `🟡 fuzzy-go → go-with-plan (default)` 让用户看到并可纠正"。

---

### F5：Q&A 循环无显式终止语义 / 递归深度保护 / 幂等保证

**定位**：`commands/workflow.md` 行 255 + `skills/analyst/SKILL.md` 行 168 + design-doc §3.1 行 114。

**问题**：
- "Q&A 循环直到 `go` / `调` / `停`" —— 三个 token 作为 terminator，但用户可能一直输 `问: X`。prompt 本体未声明：
  - **上限**：是否有"超过 N 轮 FAQ orchestrator 提示 '您已问 N 轮，要 go 吗'"之类保护？无 → 潜在无限循环（尤其 auto_mode=true 下会被 auto-go 豁免，此风险仅 manual 路径）。
  - **幂等性**：每次 `问: X` → skill 回答 → orchestrator 重 emit 菜单。若 skill 每次都 re-run full context detection（architect SKILL.md 行 9-10 "必须 inline 执行" context detection），多轮 FAQ 会重复执行 Read `_detect-project-context.md` —— SKILL.md 行 10 有 "结果存 session 记忆；后续从记忆引用，不重测" 保护，但 orchestrator 层面**重派 skill** 是否重置 session 记忆？没有明确说明。
  - **递归深度**：workflow.md 行 255 说 "orchestrator 回派**同一** skill 回答 FAQ" —— "回派" 是 `Task` 派发还是 inline skill 激活？architect/analyst = skill（§6 行 279-280），主会话内激活不是 Task；"回派" 语义需澄清。

**建议修复**：
- workflow.md 行 255 加一句："Q&A 循环无硬上限；skill 每轮只追加 FAQ（不重跑 Phase 1 识别/调研），orchestrator 不新派 Task（skill 激活路径）。"
- 可选：第 5 轮 FAQ 后 orchestrator 提示 "已 5 轮 FAQ，是否 `go`/`调`/`停`？" 软提醒不强制。
- analyst SKILL.md 行 168 补：skill 进入 Q&A 模式跳过步骤 1（context detection 已做）、步骤 2（同 slug 已识别）、步骤 3（信息已收集），仅做步骤 6 FAQ 追加。

---

### F6：Stage 9 Closeout 也属 A 类但菜单协议未同步扩展

**定位**：`commands/workflow.md` 行 272（category 映射 "9 Closeout = **A**"）+ design-doc §1.3 非目标 vs §3.1 A 类改写。

**问题**：
- Phase Matrix 映射：Stage 9 Closeout = A 类（producer-pause 终点）。Step 6 行 272 明确。
- 本 post-fix 改写 A 类菜单**通用规则**（workflow.md 行 242-264），按字面应用到 Stage 9。
- 但 design-doc 聚焦 analyst / architect，Stage 9 Closeout 的菜单该长什么样？
  - Stage 9 产出是 "汇总 findings；用户驱动 commit / PR / amend"（workflow.md 行 30）。
  - 菜单穷举会含 `commit` / `PR` / `amend` / `问` / `调` / `停`？还是只 `go` / `问` / `调` / `停`？
  - Closeout 有无 producer-skill 角色可回派 FAQ？（没有 —— Stage 9 无具体 skill/agent，是 orchestrator 汇总）。那 `问: X` 谁回答？
- Stage 9 与 analyst/architect 不对称的部分本 post-fix 未处理，造成 "A 类菜单协议" 规则声称通用但实际两种子场景。

**建议修复**：
- design-doc §1.3 非目标加一条："不改 Stage 9 Closeout 菜单协议"，或在 §3.1 补 Stage 9 变体（例如 `问: X` → orchestrator 自己回答从 findings 提取，无 skill 回派）。
- workflow.md Step 6.1 A 类块加注："Stage 9 Closeout 的 `问: ...` 由 orchestrator 直接回答（无 producer skill 可回派）"。

---

## Suggestion

### F7：analyst step 8 "return to orchestrator" 缺可机读信号

**定位**：`skills/analyst/SKILL.md` 行 168。

**问题**：
- analyst 步骤 8："回答用户追问 → 追加到 FAQ → return to orchestrator" —— skill 的 final message 如何让 orchestrator 区分 "FAQ answered, please re-emit menu" vs "just returning normally"？
- orchestrator 看到 skill return 后：如果 session state 记录 "上一条用户输入是 `问: X`" → 重 emit 菜单；否则推进。这依赖 orchestrator 维护 user-input 历史，prompt 本体未声明契约。
- design-doc §2.1 D1 "orchestrator-only" 把循环控制放 orchestrator，依赖其 "记得上一轮 user 输了 `问: ...`" —— 可行但脆弱（跨 compaction / session restore 可能丢）。

**建议修复**：
- analyst/architect skill 在 Q&A return 时，final message 末尾 emit 一行固定信号如 `<faq-added id="<slug>-<n>">` —— orchestrator 见信号即重 emit 菜单，不依赖 user-input 历史。
- 或 workflow.md Step 6.1 补一句："orchestrator 接 skill return 后，若上条 user input 匹配 `问: ...` 则重 emit 菜单；否则推进。"

---

### F8：design-doc §1.3 bugfix 豁免表述不准

**定位**：`docs/design-docs/phase-end-approval-gate.md` §1.3 行 33（"不动 ... developer"）+ §3.4 行 175（"不改 commands/bugfix.md（bugfix 无 A 类 producer-pause）"）。

**问题**：
- bugfix developer 完成后 → Stage 9 Closeout（汇总 + 用户决定 commit/PR/amend）= A 类。
- design-doc 声称 "bugfix 无 A 类" 不成立 —— bugfix 仍经 Stage 9 A 类。
- 但若 bugfix 不走 workflow.md Step 6.1 新协议（仅 `commands/bugfix.md` 内部 gate）则无问题，design-doc 行 175 用 "不改 bugfix.md" 体现这一点，可澄清为 "bugfix command 使用独立 gate 协议，不受本扩展影响"。

**建议修复**：
- §1.3 改 "不动 tester / reviewer / dba / developer（均属 C 类）" 为 "不动 bugfix 独立协议（走 `commands/bugfix.md` §自带 gate 不经本 Step 6.1 A 类）"。
- 确认 bugfix.md 内 Stage 9 等效 closeout 是否也需菜单穷举 —— 若是另一个 issue 范围。

---

### F9：Q&A 多轮 log_entries 上报重复 / flush 幂等

**定位**：`commands/workflow.md` Step 8 行 354-365 + `skills/analyst/SKILL.md` 行 172 "完成后 log_entries:"。

**问题**：
- Q&A 每轮 skill return 若都上报 `log_entries:`（analyst SKILL 行 172 "in-session output 末尾 `log_entries:` YAML 上报"），3 轮 FAQ = 3 条重复 `prefix: analyze`。
- Step 8 flush 合并规则（行 366 "同 agent 同轮多 entry 合并一条；files union；note 取首条"）只处理**同轮**合并，跨轮不合并。
- 结果：log.md 出现同 slug 同 prefix 3 条 entry，仅 note 微异。

**建议修复**：
- analyst SKILL 行 172 补："Q&A 追加模式（非首轮）**不重复上报** `log_entries:`；首轮落盘时已含 analyze entry 即可。"
- 或 Step 8 flush 合并规则扩展 "跨轮同 agent 同 slug 同 prefix 仍合并（files union / note 取首次）"。

---

### F10：design-doc §5 测试策略缺 6 option 兼容性 regression 表

**定位**：`docs/design-docs/phase-end-approval-gate.md` §5 行 183-196。

**问题**：
- DEC-006 §A 原 4 option `go / 问 / 调 / 停`，本扩展在 architect 变体下变 5 option（`go-with-plan` / `go-without-plan` / `问` / `调` / `停`），analyst 仍 4 option。
- §5 测试策略无 "DEC-006 旧案例（纯 `go` 用户）回归" 场景。用户历史习惯 `go` 是否还可 work？§5 表倒数第 1 行覆盖了 fuzzy 降级，但未覆盖 `go` in analyst 阶段（应仍按原语义 "推进" 无歧义）。
- 需明确：fuzzy 降级**仅 architect 阶段**还是**全 A 类**？workflow.md 行 262 上下文在 architect 变体块内，按缩进只 architect。但 §5 用例行 195 无上下文界定。

**建议修复**：
- design-doc §5 补一行："analyst 阶段 `go` 维持原语义（推进 architect Stage 3），不触发 fuzzy 降级。"
- §5 补 "DEC-006 兼容性" 小节：列举 `go` 在 4 阶段（Stage 2/3/9/Stage 4 前）的处理差异表。

---

## Positive

### P1：critical_modules 3/3 命中 + lint 0 命中 + tester 必触发路径完整

- design-doc §5.1 明示 critical_modules 3/3（Phase Matrix + Escalation Protocol + skill/agent/command prompt 本体）→ tester 必触发 + reviewer 落盘。符合 roundtable 自身 CLAUDE.md 的 `条件触发规则`。
- 本轮 lint（`grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/`）0 命中，符合 prompt 本体合并门槛。

### P2：append-only clarification to DEC-006 守约 + 落盘路径完整

- 不新开 DEC 沿用 DEC-013 §3.1a 的 append-only 范式（design-doc §2.3 D3）。
- DEC-006 影响范围段已按范式追加 **post-fix 2026-04-21（issue #30）** 行（decision-log 行 309），明示不改 DEC-006 A/B/C 三分、B 类 approval-gate、C 类 verification-chain 任何语义。心智一致。
- "菜单穷举 + 禁止 silent default" 原则与 DEC-006 §A 的 `go / 问 / 调 / 停` 心智同源，扩展非替换。

---

## 修复优先级建议

1. **Critical（必改）**：F1（A/B 边界澄清）+ F2（豁免落盘路径二选一 + RA matrix 对齐）
2. **Warning（应改）**：F3（auto_mode recommended 绑定）+ F4（fuzzy 降级反问或 audit）+ F5（Q&A 循环终止契约）+ F6（Stage 9 协议声明）
3. **Suggestion（可选）**：F7-F10 文档类小澄清，下轮 post-fix 批量纳入

## 变更记录

- 2026-04-21 初版对抗性审查（tester 派发 #30 post-fix）
- 2026-04-21 post-fix（orchestrator inline，auto_mode=on）：F1+F2 Critical 与 F3/F4/F5/F6 Warning 全 inline 修复，F7-F10 nit 列 follow-up

---

log_entries:
  - prefix: test-plan
    slug: phase-end-approval-gate
    files: [docs/testing/phase-end-approval-gate.md]
    note: issue #30 phase-end approval gate post-fix 对抗性审查 —— 10 findings（2 Critical / 4 Warning / 4 Suggestion）+ 2 Positive；lint 0 命中；Critical 聚焦 A/B 边界混淆与豁免落盘路径冲突 architect RA；Warning 覆盖 auto_mode recommended 绑定 / fuzzy 降级反向 UX / Q&A 循环终止契约 / Stage 9 协议未同步
