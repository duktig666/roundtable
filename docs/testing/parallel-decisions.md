---
slug: parallel-decisions
source: design-docs/parallel-decisions.md
dispatch_id: parallel-decisions-tester
created: 2026-04-21
role: tester
description: DEC-016 §Step 4b Decision Parallelism 对抗性测试（4 条件正确性 / 上限 / 失败路径 / auto_mode batch / text 模式 / TG 限流 / 工具 cap / critical_modules 传播 / 顺序回归）
---

# Orchestrator Decision Parallelism (DEC-016 / §Step 4b) 对抗性测试报告

> 测试范围：`commands/workflow.md` 新增 §Step 4b + Step 1 / 3.4 / 6b 三处 ref + Step 6.9 §Auto-pick 表 batch 行 + Step 5b 事件类 e 批量围栏注记；`docs/design-docs/parallel-decisions.md` 全文；`docs/decision-log.md` DEC-016；`CLAUDE.md` critical_modules 对 "并行判定树" 项的表述。

## 执行摘要

| 等级 | 数量 | 典型代表 |
|---|---|---|
| Critical | 0 | — |
| Warning | 5 | W-01 batch 内部分 cancel 的 auto_mode 行为措辞有歧义；W-02 "all A / 都选推荐" cross-reference 回复规则未显式覆盖；W-03 TG 每块独立 reply 在 batch 下可能触发 Bot API rate limit；W-04 critical_modules 条目文字未升级提示 §Step 4b；W-05 DEC-013 §3.1.1 vs §3.4 两条规则的优先级仅在 design-doc 交待，workflow.md 本体缺 cross-note |
| Suggestion | 4 | S-01 §Step 4b 正文未回链 design-doc §3.2 的"ambiguous answer"恢复路径；S-02 `max_concurrent_decisions=3` 超限后的行为未规定；S-03 `auto_mode=true` + text 批量 halt 时渲染形态未点名；S-04 §Auto-pick batch 行 `<batch_id>` 生成规则未定义 |

**总体判断**：Pass w/ warnings。DEC-016 的 4 条件在 critical_modules 命中的 `commands/workflow.md` 新增章节中落实正确，Step 4 / Step 4b 语义分离表述清晰。对 inventory 表（design-doc §2.1）中 7 个决策点逐一套用 4 条件均能正确分类（并行三点 ✅ / 串行四点 ❌ 符合设计意图）。主要风险是规范边界的若干 spec gap，非阻塞发布。

---

## 1. §Step 4b 4 条件正确性矩阵

对 workflow.md 内全部决策点套用 4 条件（IN-IND / OPT-DISJ / PARS-SEP / NO-LOCK），验证 DEC-016 分类是否正确。

| # | 决策点 | 位置 | IN-IND | OPT-DISJ | PARS-SEP | NO-LOCK | 结论 | 分类是否正确? |
|---|------|------|-------|---------|---------|---------|------|--------------|
| 1 | Size judgment | Step 1 | ✅ | ✅ | ✅（size=S/M/L label 唯一）| ✅ | **可并行** | ✅ 与 DEC-016 一致 |
| 2 | Dispatch mode fg/bg | Step 3.4 步骤 3 模糊兜底 | ✅ | ✅ | ✅（fg/bg label 唯一）| ✅ | **可并行** | ✅ 与 DEC-016 一致 |
| 3 | Developer form inline/subagent | Step 6b 步骤 3 | ✅ | ✅ | ✅（inline/subagent label 唯一）| ✅ | **可并行** | ✅ 与 DEC-016 一致 |
| 4 | Architect skill Stage 1 多决策 | skills/architect Stage 1 | ❌（后决策常依赖前答）| ❌（常是同一决策的拆问）| — | ❌（常有 order lock）| **保持串行** | ✅ DEC-013 §3.1.1 保留一致 |
| 5 | Step 5 subagent escalation | Step 5 | 部分 ✅（独立 subagent）| ✅ | ✅ | ✅ | **保持串行**（blocking cognitive load）| ✅ rationale 成立（非结构而是 UX 判断）|
| 6 | Stage 4 design-confirm (B 类) | Step 6 B | —— | —— | —— | —— | **保持串行**（方向性锁）| ✅ DEC-006 守约 |
| 7 | A 类 producer-pause menu | Step 6 A | —— | —— | —— | —— | **保持串行**（菜单穷举心智）| ✅ DEC-006 守约 |

**Spec gap**：#5 Step 5 escalation 的并行判断上 **4 条件实际都满足**（多个独立 subagent 的 escalation 输入独立、options 正交、label 独立、无 order lock），DEC-016 保留串行的理由是"blocking signal + cognitive load"——这是 **UX 判断，不是 §Step 4b 4 条件判据**。这让 §Step 4b 表述在被严格审读时出现语义缝隙：条件全过但仍强制串行，判据不再是"4 条件"而是叠加的 cognitive budget。详见 W-05。

---

## 2. Warning / Suggestion 详解

### W-01 Warning · batch 内部分 cancel 的 auto_mode 边界措辞

- **位置**：design-doc §3.3 FAQ Q3 vs DEC-016 决定 5；workflow.md §Step 4b "Auto_mode" 段。
- **矛盾来源**：design-doc 原文 "auto_mode 下若 batch 生成时任一 question 缺 recommended → 整组 halt"，但 FAQ Q3 又说 "用户 runtime 取消不受 auto_mode 控制"。DEC-016 决定 5 只写 "任一缺 recommended → 整组 halt" 未提 runtime cancel。
- **歧义**：workflow.md §Step 4b "Auto_mode" 段只有两句（全 recommended → 合并审计 / 任一缺 → 整组降级 halt），读者难以从 workflow 本体推断 FAQ Q3 的 runtime 语义。
- **影响**：auto_mode 启动的 dogfood 若用户在 AskUserQuestion modal 里 2 答 1 cancel，orchestrator 可能错判"整组 halt"或"对未答的也强走 recommended"。
- **建议**：在 workflow.md §Step 4b 的 "Auto_mode" 最后补半句 `（runtime cancel 不受 auto 控制，走 D3=A per-decision 路径）`。

### W-02 Warning · 跨问 cross-reference 自由回复规则缺位

- **位置**：design-doc §3.2 失败处理；workflow.md §Step 4b 失败处理句。
- **场景**：text 模式下用户回 `全部按推荐` / `都选 A` / `都 go` / `all A`。design-doc §3.2 的 fuzzy 示例列的都是 **per-question** 格式（`A` / `选 A` / `go with size=medium`），对跨问聚合回复是否合法规则沉默。
- **影响**：orchestrator LLM 要么自解析 + 全赋 recommended（越权 / 绕过 D3=A），要么全部当作歧义逐个重问（UX 倒退）。
- **建议**：明确两条路——(a) "都选推荐" 视为每 question 独立匹配 recommended label（= auto-pick 语义延展，不触发 auto mode）；(b) "都 A" 仅当每 question 都确存在 A label 且不跨问歧义时才批量解析，否则退化为歧义走 §3.6 层级澄清。

### W-03 Warning · TG 3+ 块同时 reply 可能触发 Bot API rate limit

- **位置**：design-doc §3.4 / §3.1a 每块独立字节等价 reply；workflow.md §Step 4b text-mode 段。
- **事实**：Telegram Bot API 每 chat 限 ~1 message/s（非官方软限 30 msg/s 全局）。`max_concurrent_decisions=3` 下 batch 3 块独立 reply 打包在同一 orchestrator response 里可能挨上限。
- **证据**：§3.4 原文注记 "每块独立字节等价（非合并为单 reply payload，减一次 TG 限流风险）"——**把风险方向写反了**：独立 N 块 reply 比合并单 payload 更容易触发 per-chat 1/s 限流，不是更少。
- **影响**：远程 text 模式 dogfood 偶发第 2/3 块 delay 或 fail；orchestrator 不知重发还是算已 emit。
- **建议**：(a) 修正 §3.4 rationale 表述：独立 N reply 的动机是 "字节等价 + 可独立 parse"，**不是**减限流；(b) 明示 "如检测到 reply 失败，走标准 reply retry / fallback（不新引入 batch 专属路径）"；(c) 考虑为 TG channel 特例提供"合并单 reply 多块体" 转发形态作为 follow-up issue。

### W-04 Warning · `CLAUDE.md` critical_modules 文字未显式提 §Step 4b

- **位置**：`/data/rsw/roundtable/CLAUDE.md` §critical_modules 第 6 条 `workflow command Phase Matrix + 并行判定树 + phase gating taxonomy (DEC-006)`。
- **观察**：DEC-016 新增的 §Step 4b **是第二棵**并行判定树（决策并行 vs Task 并行）。现有 critical_modules 文字只提 "并行判定树（单数）+ phase gating taxonomy (DEC-006)"，未提 DEC-016 / §Step 4b / "决策并行"。
- **影响**：未来对 §Step 4b 的改动是否 critical_modules 命中的 tester/reviewer 强制触发，规则面存在解释弹性（读"并行判定树"字面可覆盖，也可能被读成"仅指 Step 4"）。
- **建议**：CLAUDE.md 条目文字微调为 `... Step 4 Task 并行判定树 + Step 4b 决策并行判定树（DEC-016） + phase gating taxonomy (DEC-006)`，明文闭合。**注**：本 tester dispatch forbidden 改 CLAUDE.md，仅 escalate 为建议。

### W-05 Warning · DEC-013 §3.1.1 vs DEC-016 §3.4 双规则并存的优先级仅在 design-doc

- **位置**：DEC-016 决定 7 / design-doc §Q2 / workflow.md §Step 4b 的 "Text mode 批量形态" 段。
- **问题**：§3.1.1（多块串行 emit）与 §3.4（batch 多块同 response emit）语义**相反**。DEC-016 的 rationale "正交补齐，§3.1.1 保留在单决策 escalation 语境" 只写在 design-doc 与 DEC entry，**workflow.md §Step 4b 本体没提 §3.1.1**——读 workflow.md 的 orchestrator LLM 可能在 Step 5 escalation 流里误把 §3.4 "同 response emit" 倒灌回 escalation 场景。
- **影响**：规则二义性可能让未来 LLM 把 3 个 subagent 并行返回的 escalation 合批 emit，违背 §3.1.1 保留初衷。
- **建议**：workflow.md §Step 4b 末尾（或 Step 5 text 分支内）加一句 cross-ref：`Step 5 subagent escalation 多块保持 §3.1.1 串行 emit，不适用本 §Step 4b batch 形态`。

### S-01 Suggestion · §Step 4b 未回链 design-doc §3.2 "ambiguous answer recovery"

workflow.md §Step 4b "失败处理" 句仅提 "匹配失败 / 模糊 / cancel → 单独降级重问"，但 design-doc §3.6 层级澄清的具体步骤 / 重问上限未引用。建议补 `ambiguous → per-question 走 §3.6 层级澄清`。

### S-02 Suggestion · `max_concurrent_decisions=3` 超限行为未规定

若某轮同时出现 4 个满足 4 条件的 fuzzy 决策（Size + Dispatch + Form + 某个未来新增点），workflow.md 只声明 `max_concurrent_decisions=3` 上限但**未说超限怎么办**（拆 3+1 两批？强串行？降级 3）。建议显式规则："超限 → 前 3 个批量 + 第 4+ 个串行续跑（保守）"。

### S-03 Suggestion · auto_mode text 批量 halt 的渲染形态未点名

§3.3 "任一 question 缺 recommended → 整组降级 halt，所有 question 回退到 manual 路径（decision_mode 决定 modal / text）"。text 模式下"整组回退"——是 3 块仍在同 response emit，还是按 §3.1.1 降级为串行多块？两处规则在 halt 路径有可能相撞。建议明示："text halt → 3 块仍同 response emit（保持 batch 形态），仅 `recommended` 缺省导致无 auto 选"。

### S-04 Suggestion · §Auto-pick batch 行 `<batch_id>` 生成规则

workflow.md §6.9 §Auto-pick 表新加的 batch 行 event 模板 `🟢 auto-pick batch <batch_id>: [...]`，但 `<batch_id>` 生成规则未定义。建议复用 `<slug>-batch-<n>` 形态（与 §3.4 `<decision-needed id="batch-<slug>-<n>">` 一致），避免审计行与 decision block id 漂移。

---

## 3. 测试场景清单（未来 dogfood 验收）

### 3.1 正向 batch（全 4 条件满足 + 3 question）

- [ ] **T1**：自由文本任务"加 P2 feature X" → size 模糊 + fg/bg 模糊 + developer form 模糊 → 同轮 3 决策待决 → orchestrator emit 单次 `AskUserQuestion({questions: [size, dispatch, form]})`（modal）或 3 个 `<decision-needed id="batch-..."` 块（text）
- [ ] **T2**：T1 同场景 auto_mode=true 全 recommended → emit 单 ``` 围栏 `🟢 auto-pick batch ...: [M, fg, subagent]`（Step 5b 事件类 e 批量）
- [ ] **T3**：T1 auto_mode=true 其中 dispatch 缺 recommended → 整组 halt `🔴 auto-halt: no recommended option at <batch_id>/dispatch` 回退 modal/text

### 3.2 部分失败 per-decision 降级

- [ ] **T4**：T1 text 模式用户回 `1=B` 只答 size → 已答 size=B 保留，dispatch+form 各自单块重问
- [ ] **T5**：T1 modal 用户回 `选 medium, 其他不确定` → size=medium 保留，dispatch+form 单问重派
- [ ] **T6**：T1 用户整批 cancel → 全部不保留，3 个单决策分别按 `auto_mode` / `decision_mode` 重走（非 abort workflow）

### 3.3 4 条件边界反例（应**保持串行**）

- [ ] **T7**：architect Stage 1 同时浮现 3 决策 → OPTION SPACE DISJOINT fail → 串行（§3.1.1 保留）
- [ ] **T8**：storage=SQL/NoSQL 再问 SQLite/Postgres → NO-HIDDEN-ORDER-LOCK fail → 串行
- [ ] **T9**：两个并行 subagent 同时返 escalation → 按 §3.1.1 串行 emit（**即使** 4 条件全过）；cover W-05

### 3.4 上限 / 压测

- [ ] **T10**：构造 4 个同轮 fuzzy 决策 → 超 `max_concurrent_decisions=3`；观察实际行为（S-02）
- [ ] **T11**：TG sticky channel + text batch 3 块 → 观察 reply timing / 是否 rate-limited（W-03）
- [ ] **T12**：`AskUserQuestion({questions: [...]})` 实际传 3 items（modal）→ 观察 Claude Code runtime 是否接受（技术前置，skill prompt 里 "1 item only" 是心智约束非 tool cap）

### 3.5 顺序回归

- [ ] **T13**：同一 orchestrator response 内同时需要 Step 4 Task 并行派发 + Step 4b batch 决策 → 两棵树并用不相互 shadow；output 顺序保持 Task 并发 + `AskUserQuestion` 单次
- [ ] **T14**：DEC-015 Stage 9 Closeout `auto_mode` 豁免 vs DEC-016 batch auto-pick → Closeout bundle 生成阶段无 §Step 4b 触发点（只一个 `go`），零 cross-overlap 验证

---

## 4. 未命中问题的反向确认

- **§Step 4b 章节位置**：位于 Step 4 后 Step 5 前 ✅（exec-plan P0 描述匹配）
- **三点 ref（Step 1 / 3.4 / 6b）**：grep 确认各 1 处 `同轮待决 ≥2 fuzzy 决策时走 §Step 4b` ✅
- **Step 5b 事件类 e 批量围栏注记**：workflow.md §5b e 行 `batch auto-pick 事件合并单 ``` 围栏；非 batch 单事件仍 markdownv2 粗体` ✅
- **§Auto-pick 表 batch 行**：Step 6.9 表内 "§Step 4b 批量 orchestrator 决策" 行存在 ✅
- **DEC-006 A/B/C 未被动**：A 类 menu / B 类 design-confirm / C verification-chain 语义零改动 ✅
- **DEC-015 Stage 9 memory 硬边界**：workflow.md §6.9 "Stage 9 Closeout bundle 例外" 保留 ✅，DEC-016 无覆盖
- **DEC-003 research fan-out**：本 DEC 与 DEC-003 正交（DEC-003 subagent 派发并行；DEC-016 用户决策并行）✅ 一致
- **AskUserQuestion Option Schema 不动**：batch question 的每 item 仍遵 DEC-013 canonical schema ✅

## 5. 发现的潜在问题反馈 developer / architect

| 项 | 严重度 | 归属 | 建议动作 |
|---|-------|------|---------|
| W-01 auto_mode runtime cancel 措辞 | Warning | architect 回补 workflow.md §Step 4b Auto_mode 段半句 | 回 architect 复批 |
| W-02 跨问"都选推荐"规则 | Warning | architect 补 design-doc §3.2 或 §3.6 | 回 architect 复批 |
| W-03 TG reply 限流方向写反 | Warning | architect 修正 design-doc §3.4 rationale 方向 + 评估 follow-up issue | 回 architect 复批 |
| W-04 CLAUDE.md critical_modules 文字升级 | Warning | orchestrator 决定是否开独立 PR（本 dispatch forbidden 写 CLAUDE.md）| escalate |
| W-05 DEC-013 §3.1.1 vs §3.4 cross-ref | Warning | architect 在 workflow.md §Step 4b 补一句 cross-note | 回 architect 复批 |
| S-01~S-04 | Suggestion | 可合并到 W-01/W-03 回批或下个 iteration | 酌情 |

---

## 6. 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-04-21 | 初稿 | DEC-016 落盘后对抗性审读 |
