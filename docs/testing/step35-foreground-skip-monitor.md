---
slug: step35-foreground-skip-monitor
source: design-docs/subagent-progress-and-execution-model.md §3.8, decision-log.md DEC-008
created: 2026-04-19
tester: roundtable:tester (adversarial)
scope: commands/workflow.md §3.5.0, commands/bugfix.md §Step 0.5 delta 0, design-doc §3.8, DEC-008 + DEC-004 status line
critical_modules_hit:
  - workflow command Phase Matrix + 并行判定树 + phase gating taxonomy (DEC-006)
  - Progress event JSON schema (DEC-004)
---

# Step 3.5 前台派发免 Monitor（DEC-008）对抗性测试

> 本测试文档针对 DEC-008 落地的 4 处 diff：
> 1. `commands/workflow.md` §3.5.0 新增 gate
> 2. `commands/bugfix.md` §Step 0.5 新增 delta 0
> 3. `docs/decision-log.md` DEC-008 条目 + DEC-004 状态行补注
> 4. `docs/design-docs/subagent-progress-and-execution-model.md` §3.8 + frontmatter + §6 changelog
>
> 测试策略：静态审读为主（本变更无运行态）+ 场景矩阵推演。

---

## 0. 测试计划（plan-first，critical_modules 命中）

### 攻击面分类

| # | 场景 | 关注维度 |
|---|------|---------|
| T01 | 纯后台单派发 | gate 正确放行 → Monitor 正常 |
| T02 | 纯前台单派发 | gate 正确 skip；4 变量不注入；agent Fallback 生效 |
| T03 | `run_in_background: false` 显式 | 与缺省等价 gate-skip |
| T04 | 混合并行（1 前台 + 2 后台） | gate 逐派发独立判定，不整批 skip |
| T05 | gate + env opt-out 级联 | §3.5.0 先行 → §3.5.1；双激活不重复 skip |
| T06 | inline developer + 同会话后台 tester | 两条 skip 路径不冲突 |
| T07 | `run_in_background: true` 但 `ROUNDTABLE_PROGRESS_DISABLE=1` | §3.5.0 放行 → §3.5.1 拦截 |
| T08 | 5 个 agent prompt Fallback 兼容性 | 空 progress_path 不崩 |
| T09 | DEC-004 部分 Supersede 语义 | 仅 §3.6 触发规则 scope；其余条款仍 Accepted |
| T10 | 决策日志铁律 | DEC-008 未删 DEC-004 原文；编号递增 |
| T11 | DEC-008 内部一致性 | 上下文/决定/理由/影响范围 不互相矛盾 |
| T12 | design-doc §3.8 引用准确性 | 对 DEC-004 §3.1 / §3.6 / DEC-005 §6b.3 / DEC-007 的交叉引用 |
| T13 | 节号破碎 | §3.8 插入是否破坏原 §3.7 及其后引用 |
| T14 | bugfix.md delta 0 与 workflow.md §3.5.0 语义对齐 | "Identical to commands/workflow.md §3.5.0" 的真值 |
| T15 | Claude Code Task 默认行为漂移 | 未来若 Task 默认变更，gate 是否仍稳定 |
| T16 | lint_cmd 硬编码扫描 | 0 命中 |
| T17 | §3.5.0 Note：inline vs Task-foreground 边界 | 两条 skip 路径不重叠不矛盾 |
| T18 | Monitor 预备 Bash snippet 未跑 | 前台派发 `DISPATCH_ID` / `PROGRESS_PATH` 完全不产生 |

---

## 1. 执行与发现

### T01 — 后台单派发放行（Positive）

输入：orchestrator 以 `Task {..., run_in_background: true}` 派发 reviewer。
期望：§3.5.0 放行 → §3.5.1 放行（env 未设）→ §3.5.2 生成 ID/path → §3.5.3 Monitor 启 → §3.5.4 4 变量注入。
结果：**Positive** — §3.5.0 明确 "Run the rest of this Step" 对 `run_in_background: true` 分支。

---

### T02 — 前台单派发 skip（Positive）

输入：`Task {..., run_in_background: false}` 或 run_in_background 缺省派发 tester。
期望：§3.5.0 skip；不产生 progress_path；agent 侧 Fallback 静默。
结果：**Positive**。

验证点：
- `agents/tester.md:151` Fallback 明文 "If `{{progress_path}}` is empty, unset, or the injection is missing entirely, silently skip all emit calls"
- `agents/developer.md:186`、`agents/reviewer.md:156`、`agents/dba.md:129`、`agents/research.md:176` 均有等价条款。

---

### T03 — 显式 `run_in_background: false`（Positive）

§3.5.0 条款文本："`run_in_background` omitted / `false`（foreground dispatch, the default）— ... Skip this entire Step"。**显式 false 与缺省并列处理**，gate 语义正确。

---

### T04 — 混合并行派发（Warning）

输入：orchestrator 在一条 assistant message 里发 3 个 Task：A 前台、B 后台、C 后台。
期望：§3.5.0 逐派发判定 → 仅 B、C 走 Monitor setup；A skip。

**发现 (Warning)**：§3.5.0 文本用 "the upcoming `Task` call's `run_in_background` parameter"（单数），未显式说明并行场景下 orchestrator 必须**逐个 Task call 独立执行 §3.5**。当前措辞在严格读字面时也能推导（"before running any sub-step"）但 LLM 容易在并行场景里把 3 个 Task 的判定合并评估（"至少一个后台 → 跑 Step"）导致给前台 A 也生成 progress_path。

建议：§3.5.0 末尾加一句 "In a parallel dispatch batch, evaluate this gate **independently for each `Task` call**; mixed-mode batches are expected."

---

### T05 — gate + env opt-out 级联（Positive）

顺序：§3.5.0（foreground → skip）→ 若非 foreground 再 §3.5.1（env → skip）。
两条 skip 同语义层、都终结 Step；不重复 skip，不互相取消。
`commands/workflow.md` §3.5.0 Rationale 段与 §3.5.1 头句明确 "先于 §3.5.1" / "If it equals `1`, skip this entire Step"，文本无歧义。

---

### T06 — inline developer + 同会话后台 tester（Positive）

DEC-005 §6b.3: "Do NOT run Step 3.5" for inline developer（无 Task 派发）。
DEC-008 §3.5.0 Note: "applies strictly to `Task`-dispatched subagents"。

两条 skip 路径**正交**：inline developer 在 orchestrator 内联执行，根本不触发 Step 3.5 流程入口；§3.5.0 处理的是已经进入 Step 3.5 但派发形态是前台 Task 的情形。同会话可共存，互不冲突。

---

### T07 — `run_in_background: true` + ROUNDTABLE_PROGRESS_DISABLE=1（Positive）

链条：§3.5.0 放行（is background）→ §3.5.1 拦截（env=1）→ skip。用户侧 env 仍是顶层一刀切 opt-out；gate 叠加正确。

---

### T08 — 5 agent prompt 空 progress_path Fallback（Positive）

grep 证据见 T02。`agents/reviewer.md:156` 用 "Fallback on miss" 表述略有差异但语义等价。**无需修改 5 个 agent prompt**，DEC-008 影响范围声明与实际一致。

---

### T09 — DEC-004 部分 Supersede（Warning）

decision-log.md line 138:
`**状态**: Accepted（§3.6 触发规则 Superseded by DEC-008 — 改为 run_in_background: true 派发才开启；其余条款仍 Accepted）`

**发现 (Warning)**：`§3.6 触发规则` 的 scope 标注含糊。DEC-004 条目本体**未使用 section 号**，是以 "决定" 后的数字列表 1-9 组织的（其中第 6 项 "触发规则"）。用 "§3.6" 既可能误读为引用 design-doc §3.6（实际是"与 DEC-002/DEC-003 的接口"，完全无关），也可能误读为 DEC-004 决定列表的第 6 项。

建议：改为更无歧义的表述之一：
- `**状态**: Accepted（决定第 6 项「触发规则」Superseded by DEC-008；其余条款仍 Accepted）`
- 或直接：`**状态**: Accepted（触发规则 Superseded by DEC-008；其余条款仍 Accepted）`

铁律 "不删除旧条目" 已遵守。

---

### T10 — decision-log 铁律（Positive）

- DEC-008 条目采用规定格式（日期/状态/上下文/决定/备选/理由/相关文档/影响范围）。
- DEC-004 原文保留，仅追加状态注解。
- 编号递增（DEC-007 → DEC-008）。
- 冲突已在 DEC-008 "备选" 段显式引用 DEC-004 并给出 Supersede 理由。
- 铁律 1 / 2 / 3 全部遵守。

---

### T11 — DEC-008 内部一致性（Positive）

交叉比对：
- 上下文 → 问题是"前台派发 Monitor 冗余"（一致）
- 决定 1/2/3 → gate 位置（一致）、bugfix 同步（一致）、不改 agent prompt（一致）
- 决定 5 → DEC-004 标 Superseded by DEC-008（与 decision-log line 138 实际落地一致）
- 决定 6/7 → 与 DEC-007 正交、与 DEC-005 同源（design-doc §3.8 末尾两段呼应一致）
- 理由 6 条与"决定"7 条在"走 Superseded 流程"上一致

---

### T12 — design-doc §3.8 引用准确性（Critical）

**发现 (Critical)**：§3.8 line 266:
> subagent 收到空 `progress_path` 时按 §3.6 漏发降级条款静默

但 design-doc §3.6 实际标题是 "与 DEC-002 / DEC-003 的接口"，**内容完全不涉及"漏发降级"**。真正的 "漏发降级 / 遗漏 echo 时降级为静默" 条款在 **§3.2** 末段（`subagent-progress-and-execution-model.md:157`）"subagent 遗漏 echo 时降级为'静默'"。

类似问题：§6 changelog line 357:
> 落 DEC-008（Supersedes DEC-004 §3.6 触发规则）

此处 "DEC-004 §3.6" 指什么同样含糊（参见 T09）。且把 design-doc §3.6 和 DEC-004 条目混用 "§3.6" 会让后续读者 / agent 解读时错位。

修复建议：
- §3.8 line 266 改为 "按 §3.2 末段漏发降级条款" 或 "按各 agent `## Progress Reporting` Fallback 条款"。
- §6 changelog line 357 改为 "Supersedes DEC-004 触发规则（决定列表第 6 项）"。

---

### T13 — 节号破碎（Critical）

设计文档**原 §3.7 "parallel-dispatch safety" 块在 DEC-008 编辑后丢失了标题**。

证据：
- `subagent-progress-and-execution-model.md:278-283` 存在一段 "progress 机制**不破坏**并行派发四条件" 的内容（4 条 PREREQ MET / PATH DISJOINT / SUCCESS-SIGNAL INDEPENDENT / RESOURCE SAFE），**但无任何 `### 3.7` 标题**，位于 §3.8 之后完全裸奔。
- 外部多处仍在引用 "DEC-004 §3.7"：
  - `commands/workflow.md:216` `Per DEC-004 §3.7 and DEC-002 §4 parallel dispatch rules, ...`
  - `docs/exec-plans/active/subagent-progress-and-execution-model-plan.md:158` `progress_path 按 dispatch_id 命名，天然隔离（DEC-004 §3.7）`

编辑似乎原本想在 §3.6 后插入 §3.8（以区分"新增"），但未保留 §3.7 的 heading。结果：
1. 原 §3.7 内容变成**孤儿段**（无标题、无锚、无 anchor-like 引用点）。
2. 节号从 §3.6 → §3.8 跳跃，违反 design-doc 节号连续性。
3. `commands/workflow.md` §3.5.6 和 `exec-plans/active/...-plan.md` 对 "§3.7" 的引用**实际悬空**（读者翻到 design-doc 发现没有 §3.7）。

**修复建议**：把孤儿段恢复为 `### 3.7 并行派发安全性`（或等价标题），或交换 §3.8 和 §3.7 顺序使 §3.7 仍在 §3.8 之前。后者与外部引用的位置期待更一致。

---

### T14 — bugfix.md delta 0 与 workflow.md §3.5.0 对齐（Warning）

`commands/bugfix.md:34`:
> **Foreground vs background gate (DEC-008)**: ... Identical to `commands/workflow.md` §3.5.0.

**发现 (Warning)**：bugfix delta 0 文本**缺少** workflow.md §3.5.0 的两个关键细节：
1. 没有 "gate 失败后不注入 4 变量" 的显式列举（workflow.md §3.5.0 明写 "do NOT generate progress_path, do NOT run the Bash preparation, do NOT launch Monitor, do NOT inject the 4 progress variables"）。bugfix 版本仅笼统说 "Foreground ... skip Monitor setup entirely"。
2. 没有 "§3.5.0 vs inline developer §6b.3 是两条 skip 路径" 的 Note（workflow.md §3.5.0 结尾那段）。

由于 bugfix 的 "Identical to ... §3.5.0" 宣示权威，读者可能跳回 workflow.md 查细节，功能上不破。但对纯执行 bugfix 命令的 LLM，缺失的细节可能导致它只 skip Monitor 却仍生成 progress_path 并注入进 Task prompt —— subagent 然后会尝试 emit 但文件不被 tail（silent data loss，非 fail-loud）。

建议：bugfix delta 0 显式列出"skip Monitor + skip progress_path 生成 + skip 4 变量注入"三件一起，或加一句 "All four sub-steps of §3.5 are skipped, including the 4-variable injection"。

---

### T15 — Claude Code Task 默认行为漂移（Suggestion）

当前：`run_in_background` 默认 false / 缺省 = 前台。
假设未来 Claude Code 升级改为默认后台：gate 仍以 "true → 后台派发 Monitor" 为单源真值，**不会因默认行为翻转而误导**。但 §3.5.0 文字 "(foreground dispatch, the default)" 会变成过期陈述。

建议：`(foreground dispatch, currently the Claude Code default)` 或直接删 "the default" 补注，使条款与默认值解耦。

---

### T16 — lint_cmd 硬编码扫描（Positive）

执行 `grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/`：**0 命中**。

---

### T17 — §3.5.0 Note：inline vs Task-foreground 边界（Positive）

§3.5.0 结尾：
> Note: the Developer inline form (§6b.3) is a separate skip path — it never enters this Step because no `Task` call is issued. §3.5.0 applies strictly to `Task`-dispatched subagents.

措辞精准。inline developer 是"根本不跑 Step 3.5"（源头分流），§3.5.0 是"跑 Step 3.5 但判定后 skip"（内部 gate）。两条路径不重叠，联合覆盖"主会话能观察到"的所有情形。

---

### T18 — 前台派发下 Monitor 预备 Bash 未跑（Positive）

§3.5.0 明确 "do NOT run the Bash preparation in §3.5.2"。此细节关键：若 gate 仅 skip Monitor 启动但仍跑 §3.5.2 生成 `PROGRESS_PATH`，subagent 后续 emit 会写入文件但无 Monitor 读取（silent buildup 占 /tmp 空间，长期跑会累计垃圾文件）。明文列举 §3.5.2 在 skip 范围内，避免此隐患。

---

## 2. 发现汇总

| 严重度 | 测试 | 描述 | 建议 |
|-------|------|------|------|
| Critical | T12 | design-doc §3.8 line 266 引用 "§3.6 漏发降级条款" 但 §3.6 内容不含降级；实际在 §3.2 | 改引 §3.2 或各 agent §Progress Reporting Fallback |
| Critical | T13 | §3.7 "parallel-dispatch safety" 段在 DEC-008 编辑后失去标题，沦为孤儿段；外部 2 处 `§3.7` 引用悬空 | 恢复 `### 3.7` 标题，或调换 §3.7 / §3.8 顺序 |
| Warning | T04 | 并行派发场景下 §3.5.0 未显式说明逐 Task 独立评估 | §3.5.0 末尾加一句并行判定说明 |
| Warning | T09 | DEC-004 状态行 `§3.6 触发规则` 的 scope 标注含糊（DEC-004 本体无 §） | 改为 "决定第 6 项" 或 "触发规则" |
| Warning | T14 | bugfix.md delta 0 缺少 workflow.md §3.5.0 的 "4 变量不注入" 显式条款 | 显式列 skip 三件：Monitor + progress_path 生成 + 4 变量注入 |
| Suggestion | T15 | §3.5.0 含 "the default" 陈述，依赖 Claude Code 当前默认行为 | 改为 "currently the Claude Code default" 以解耦未来变更 |
| Positive | T01/02/03/05/06/07/08/10/11/16/17/18 | 核心 gate 语义正确、铁律遵守、lint 0 命中、Fallback 兼容 | — |

---

## 3. 潜在业务 bug（反馈给调度方）

无（本变更纯文档/编排层，无业务代码修改）。Critical 级发现为**设计文档自洽性 bug**（非业务 bug），不走 developer bugfix 流程；建议 architect/作者直接修文档。

## 4. 变更记录

- 2026-04-19 创建 —— DEC-008 落地对抗性审查；发现 2 Critical / 3 Warning / 1 Suggestion。
