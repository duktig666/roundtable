---
slug: phase-transition-rhythm
source: analyze/phase-transition-rhythm.md
created: 2026-04-19
status: Draft
decisions: [DEC-006]
---

# workflow phase transition 节奏重构 设计文档

> slug: `phase-transition-rhythm` | 状态: Draft | 参考: [issue #10](https://github.com/duktig666/roundtable/issues/10), analyze/phase-transition-rhythm.md

## 1. 背景与目标（含非目标）

### 背景
参见 `analyze/phase-transition-rhythm.md` §背景。核心问题：现行 `commands/workflow.md` Step 6 规则 1 把所有 cross-role transition 统一走"wait for user confirmation"（实务上落地为 AskUserQuestion 4-option 弹窗），造成**选项疲劳、产出文档未读完即决策、FAQ 空间被切断**。

### 目标
用显式**三段式分类**替换现行 Step 6 规则 1，使 phase gate 规则与"用户主动驱动 + 只在真正决策点保留 AskUserQuestion"的心智对齐。

### 非目标
- 不改 subagent 执行模型（issue #7 已定）
- 不改 prompt 语言策略（issue #8 范畴）
- 不改 prompt 文件体量（issue #9 范畴）
- 不改 AskUserQuestion Option Schema 的 `rationale/tradeoff/recommended` 约定（`feedback_askuserquestion_options` 保留）
- 不改 Phase Matrix 状态机 ⏳/🔄/✅/⏩ 本身

---

## 2. 业务逻辑（三段式分类 + Gating 决策流）

### 2.1 三段式分类

每个 phase transition 归入以下三类之一，gating 行为由所属类决定：

| 类别 | 定义 | Gating 行为 | 例子 |
|---|---|---|---|
| **A. producer-pause**<br>产出阶段结束停下 | phase 产出的 artifact 用户需要阅读、评估、可能提问或调范围 | orchestrator 输出"✅ 完成 + 产出清单 + `请 go / 提问 / 调范围`" 三行总结，**不调用任何工具，等用户输入** | analyst 完成 / architect 完成（Draft design-docs）/ reviewer 完成 |
| **B. approval-gate**<br>硬批准关卡 | 过了这点就是不可逆方向性锁定，后续返工成本高 | 必须调用 `AskUserQuestion`，选项含 Accept/Modify/Reject 等，按现有 Option Schema | design-confirm（唯一硬 gate）|
| **C. verification-chain**<br>内部校验链 | phase 之间是机器/AI 内部纪律性衔接，无用户决策点 | orchestrator **自动前进**，只在 handoff 时报告 1 行状态；Critical 发现仍立即中断 | developer → tester / tester → reviewer / reviewer 完成 → closeout / context-detect → analyst / design-confirm 通过 → developer |

### 2.2 Phase Matrix 分类映射（完整表）

| Stage | Role | 分类 | Gating |
|---|---|---|---|
| 1. Context detection | inline | C | 自动进 |
| 2. Research | analyst | **A producer-pause** | 等 user `go` |
| 3. Design | architect | **A producer-pause** | 等 user `go`/调整 |
| 4. Design confirmation | user | **B approval-gate** | AskUserQuestion |
| 5. Implementation | developer | C | 自动进 |
| 6. Adversarial testing | tester | C | 自动进 |
| 7. Review | reviewer | C（完成后进 stage 9）| 自动进 |
| 8. DB review | dba | C | 自动进 |
| **9. Closeout** *(new)* | (user) | **A producer-pause** | 等 user `commit` / `调整` / `ship` |

Stage 9 Closeout 是新增 stage：reviewer/dba 完成后，orchestrator 汇总所有 findings + 影响文件 + 建议动作，然后停下等用户决定下一步（commit / 开 PR / 进一步修改），**不再自动调用 git**（保持 `feedback_no_auto_push` / `feedback_no_auto_pr` 纪律）。

### 2.3 producer-pause 输出格式（契约）

产出阶段 end 时 orchestrator 输出统一格式：

```
✅ <role> 完成。
产出：
- <path1> — <desc>
- <path2> — <desc>
请阅读后告诉我：`go` / `调范围: ...` / 问题
```

之后**不调用任何工具**，等下一轮用户输入。如用户提 FAQ：
- analyst FAQ → append 到 `analyze/[slug].md` 的 `## FAQ` 区
- architect FAQ → 对话中直接答；涉及设计调整则更新 `design-docs/[slug].md`
- reviewer FAQ → 对话中直接答；涉及 finding 澄清则更新 `reviews/[date]-[slug].md`

### 2.4 verification-chain 的 Critical 中断

C 类自动前进不是"静默推进"。以下情况仍立即中断：
- developer 报告 lint/test 失败 → orchestrator 停下报告，不自动分派 tester
- tester 产出 `<escalation>` 业务 bug → orchestrator 停下走 escalation 流程（现行 Step 5 规则保留）
- reviewer 产出 Critical 级 finding → 停下走 escalation
- **critical_modules 机械触发仍归 C 类**：tester 按 CLAUDE.md `critical_modules` 必然被分派，但这是"verification chain 里必然的一步"，不需要用户确认"是否派 tester"；orchestrator 在 handoff 行里报告"critical_modules 命中 [...] → dispatching tester"

### 2.5 用户主动驱动的实现

producer-pause 的"等用户 go"不是新 UI 机制，是**缺省行为**：orchestrator 输出完成报告后不再调用任何工具即可。下一轮用户的自由文本输入驱动 orchestrator：
- `go` / `继续` / `下一步` / `ok` → 进入下一 stage
- `问：...` / 追问 → 答问题，不进 stage
- `调范围: ...` / `改: ...` → 重新分派同一 role（同一 slug，追加 scope）
- `停` / `中止` → 结束 workflow，Phase Matrix 留在当前状态

---

## 3. 技术实现

### 3.1 `commands/workflow.md` §Step 6 规则 1 重写

**旧文本**（现 workflow.md:248）：

> 1. **Phase gates**: after each phase completes, report outcome + artifacts + updated Phase Matrix to the user, then **wait for user confirmation** before advancing to the next phase. Exception: routine transitions within the same role ... MAY auto-advance ... Cross-role transitions ... always require confirmation unless CLAUDE.md `critical_modules` rule dictates the trigger ...

**新文本**（重写为显式三段式）：

> 1. **Phase gating taxonomy (DEC-006)**: every phase transition falls into one of three categories; gating behavior is determined by category.
>
>    - **A. producer-pause** — phase ends with user-consumable artifacts (analyst / architect Draft / reviewer findings). Orchestrator emits a 3-line summary (`✅ <role> 完成 / 产出清单 / 请 go | 调整 | 问题`) and **stops, invoking no tools**, waiting for the user's next message. User drives advancement via free-text: `go`/`继续` advances, `问: …` stays in FAQ, `调: …` re-dispatches the same role with expanded scope, `停` aborts.
>    - **B. approval-gate** — hard directional lock (design-confirm is currently the only one). Orchestrator MUST invoke `AskUserQuestion` with options following the Option Schema (Accept / Modify / Reject etc.).
>    - **C. verification-chain** — internal machine/AI handoff with no user decision point (context-detect → analyst, design-confirm 通过 → developer, developer → tester, tester → reviewer, reviewer → closeout, dba → closeout). Orchestrator auto-advances, emitting a 1-line handoff notice (e.g., `🔄 developer 完成 → dispatching tester (critical_modules hit: [...])`). `critical_modules`-driven mandatory tester/reviewer dispatches remain in C (mechanical, no prompt needed). Critical findings, escalations, or lint/test failures still interrupt per Step 5 and Step 6 rules 5–6. Before emitting the C-class handoff notice, orchestrator MUST scan subagent final message for `<escalation>` and route through Step 5 if present.
>
>    Phase Matrix mapping: see §2.2 of `design-docs/phase-transition-rhythm.md` for the full stage→category table. Stage 9 Closeout (post-review user commit/PR decision) is the second producer-pause and the workflow terminus.

### 3.2 Phase Matrix 扩展（Stage 9 Closeout）

`commands/workflow.md` §Phase Matrix table 追加一行：

```
| 9. Closeout | (user) | ⏳ / 🔄 / ✅ | aggregate findings summary; user-driven commit/PR decision |
```

Legend 无需新增符号。

### 3.3 CLAUDE.md `conditional trigger rules` 同步

项目 `CLAUDE.md` §条件触发规则 现有 8 条。无需新增条款——DEC-006 的规则已在 workflow.md 内；但 critical_modules 列表里 `workflow command Phase Matrix + 并行判定树` 条目的描述需要扩展为 `... + phase gating taxonomy (DEC-006)`。

### 3.4 其他受影响文件

| 文件 | 改动 |
|---|---|
| `commands/workflow.md` | §Step 6 规则 1 重写（§3.1 新文本）+ Phase Matrix 加 Stage 9 Closeout |
| `docs/decision-log.md` | 追加 DEC-006 |
| `CLAUDE.md`（roundtable 自身）| §critical_modules 条目 6 描述扩展加 "+ phase gating taxonomy (DEC-006)" |
| `docs/claude-md-template.md` | 同步更新 roundtable 自身 CLAUDE.md 模板里对应条目，保持 template 权威 |
| `README.md`（roundtable 自身）| 可选：用户向文档若提到"每 phase 停下确认"，更新为"产出阶段停下等 go / approval gate 强弹窗 / verification chain 自动" |

不动的文件：
- `commands/bugfix.md`（bugfix 流程独立，不受三分类影响——bugfix 只有 developer + 可选 tester，不跨 producer/approval/verification 概念）
- `agents/*.md`（agent 契约不变）
- `skills/*.md`（skill 契约不变）
- 其他 DEC（DEC-001 ~ DEC-005 全部保留 Accepted，不走 Superseded）

---

## 4. 关键决策与权衡

### DEC-006 决策要点（正文见 decision-log.md）

**决定**：新增 DEC-006 记录 phase gating 三段式分类，Accepted 状态。

**备选**：
- 合入 DEC-001 D5：D5 现为 Scope=user，与 gating 无关；硬塞会模糊 D5 语义
- 合入 DEC-002（Escalation Protocol）：DEC-002 谈的是 subagent → orchestrator 的 escalation，本 DEC 谈的是 orchestrator → user 的 gating，主体不同
- Supersede 既有 DEC：三段式分类是"显式化现行规则的两条 Exception 条款 + issue #10 新补的 producer-pause 语义"，不推翻任何既有决策，不走 Superseded

**理由**：新增 DEC 符合 append-only 纪律；保留既有 DEC 语义边界清晰；未来若需调整单独演进 DEC-006 即可。

### 三段式 vs 现行 Exception 条款嵌套

| 维度 (0-10) | 三段式重写 ★ | Exception 嵌套扩展 |
|---|---|---|
| 阅读性 | **9**（一图一表即全貌） | 5（嵌套条件，条款变长） |
| 扩展性 | **8**（新 phase 归一类即可） | 4（每加一类 Exception 要决策边界） |
| 心智一致性 | **9**（与 CrewAI/LangGraph 主流对齐）| 6（"默认 gate + 例外自动" 反向于主流）|
| 实施代价 | 7（需新 DEC + workflow.md 大改）| **8**（改 1 条 Exception 最小）|
| 回归风险 | 7（新分类由 architect 维护）| 6（嵌套越深越易误读）|
| **合计** | **40** | 29 |

### reviewer 归类（Q3 裁决）

**决定**：reviewer 完成 → closeout 归 **C verification-chain**；Stage 9 Closeout 才是 producer-pause。

**理由**：
- reviewer 本质是 audit，其 artifact（reviews/[date]-[slug].md）是 Critical finding 触发时才落盘，非每次必产出——不符合"产出阶段 end"（必有 user-consumable artifact）的特征
- 用户真正要做的决策是"是否 commit"，这个决策属于 Closeout stage 而非 Review stage
- 若把 reviewer 归 A，用户在"review 完成"和"closeout commit"要停两次；归 C 后只停一次（closeout），节奏更清

### design-confirm UI 形式（Q4 裁决）

**决定**：design-confirm 保留 `AskUserQuestion` 弹窗形式，不转文本驱动。

**理由**：
- design-confirm 是全流程唯一方向性 hard gate，决策结构化程度最高（Accept / Modify which part / Reject / etc.）—— 天然适合 option 化
- 对标 terraform apply / apt install：destructive-equivalent 操作强制确认是行业共识
- 与 A 类 producer-pause 的"自由对话 go" 区分开，用户一眼能辨别"现在是硬关卡"
- 保留 `feedback_askuserquestion_options` 的 option schema 约束不变

### critical_modules 机械触发归属（Q5 裁决）

**决定**：归 **C verification-chain** 子项，不独立分类。

**理由**：
- critical_modules 触发 tester/reviewer 是 CLAUDE.md 声明的内部纪律，用户事先已在 CLAUDE.md 授权，运行期无决策点
- handoff 时 orchestrator 在 1 行通知里注明 `(critical_modules hit: [...])` 即足够透明
- 若独立分类会让分类表膨胀、边界模糊

### Closeout stage 新增（Q6 裁决）

**决定**：新增 Stage 9 Closeout 作为 A 类 producer-pause。

**理由**：
- issue #10 草案表格里已出现"reviewer 完成 → closeout"，Phase Matrix 需要对应 stage
- Closeout 是"所有 verification 已完 + 等用户决定 commit/PR/amend"的显式状态，与 `feedback_no_auto_push` / `feedback_no_auto_pr` 纪律一致
- 新 stage 仅在 Phase Matrix table 加一行，无编码成本

---

## 5. 讨论 FAQ

- **Q**: auto-advance 的 1 行 handoff 通知会不会被用户漏看？  
  **A**: 由 TodoWrite 的 task 状态变化 + orchestrator 在 Phase Matrix report 里显式标 🔄→✅ 双重提示；用户可随时 `/roundtable:workflow status` 类查询（虽然目前无此子命令，属潜在增强）。

- **Q**: producer-pause 下用户没回话卡多久？  
  **A**: 无限——orchestrator 不调用工具就不消耗 context。Claude Code session 本身允许长暂停。

- **Q**: 新 stage 9 Closeout 会不会让小任务（bugfix）变啰嗦？  
  **A**: bugfix 走 `/roundtable:bugfix` 命令，不走 `/roundtable:workflow`；bugfix 流程独立，不受本 DEC 影响。medium 以上 workflow 任务增加一次 producer-pause 在 closeout，成本约为 1 message，相对 review 阶段的信息量可忽略。

---

## 6. 变更记录

- 2026-04-19 创建
- 2026-04-19 修 C-01 初稿误写的 "Step 6.5/6.6" anchor（workflow.md 实际结构为 Step 6 + Step 6b，对应 lint/test 与 escalation 规则的正确指针是 Step 5 + Step 6 rules 5–6）+ 补 W-10 "C handoff 前 scan `<escalation>`" + 修 C-02 (Step 7 批处理与 C 自动前进的桥接条款) + W-08 (§Step 3 artifact chain 加 closeout 行)

---

## 7. 待确认项

- 是否同步更新 `docs/claude-md-template.md` 的 `condition trigger rules` 示例，向外部用户项目传导"三段式"心智？（Developer phase 可决定）
- README.md 是否新增一句话概括 phase gating taxonomy？（可选，与 issue #9 合并做会更省劲）
