---
slug: parallel-research
source: 原创 + 外部：CrewAI docs / Claude Code sub-agents docs / LangGraph training-data 知识
created: 2026-04-19
---

# Parallel Research Subagent Dispatch 调研报告

> 主题 slug: `parallel-research`
>
> 对应 [issue #2](https://github.com/duktig666/roundtable/issues/2)：architect skill 派发 parallel analyst subagent 做专题调研的能力。
>
> 本报告对标 3 个 role-dispatch 同构系统（CrewAI / LangGraph / Anthropic Agent SDK），**只陈事实 + 观察**，不做方案选型，不打分，不给推荐。方案 / DEC / exec-plan 归 architect。

## 背景与目标

- **问题来源**：[gleanforge P4 自消耗报告](../testing/p4-self-consumption.md) §3 friction #8 —— architect 决策 3+ 备选方案时 `WebFetch` 串行瓶颈；要么 context 被 accumulated fetch 撑爆，要么被迫 truncate 研究广度
- **现状**（DEC-001 D8）：architect 是 **skill 形态**、运行在主会话、工具含 `Task`。但 D8 的设计意图是"skill 保留 AskUserQuestion、agent 隔离 context"，未规定 skill 可以派 Task 做 fan-out research
- **目标**：架构决定 `architect → parallel research subagent` 的能力边界、通信协议、与 DEC-001 D8 的兼容方式
- **本轮范围**：只做 analyst 调研 + architect 设计决策 + DEC-003（按需 exec-plan）。不写代码，不跑测试

## 追问框架（必答 2 + 按需 4）

**必答**

- **失败模式**（方案最可能在哪里失败？）：
  1. **研究 subagent 失控扇出**：架构师临时决策需要 3+ 选项时，若扇出无上限，可能产生 5-10 个并行 subagent，token 消耗与外部 API 限流都撑爆
  2. **结果合成质量退化**：子 agent 返回的是 raw research，architect 合成质量取决于返回格式与 architect 的阅读 budget；无结构化 schema 时合成易丢细节
  3. **与 AskUserQuestion 交互错位**：architect 收到 research 后弹窗决策，但如果 research 本身需要 architect 澄清（比如调研范围模糊），目前 subagent 无法反问 architect（subagent 无 AskUserQuestion；escalation 到 orchestrator 层，但 architect *是* orchestrator 的 skill）—— 有 reentrant 问题
  4. **DEC-001 D8 漂移**：skill 派 Task 不是 D8 原意，如果不明确 Superseded / 补充关系，未来维护者会混淆
  5. **研究 subagent 变成隐形决策者**：analyst 纪律要求"事实层，不做推荐"；若 research subagent 返回"我推荐 X"， 等同于 architect 委托决策外包 —— 与 DEC-001 的决策弹窗纪律冲突

- **6 个月后评价**（回头看会不会成为债务？）：
  - **会成为债务**的情形：研究 subagent 做成"mini architect"（能给推荐、能复杂决策），最终膨胀到与 analyst 功能重叠；或无超时 / 无并发上限，运行时伤及用户预算
  - **不会成为债务**的情形：严格受限 tool set（只 Read + WebFetch + WebSearch）、严格事实层输出、扇出硬上限（如 ≤4）、结构化返回 schema（architect 按 schema 合成）；和 analyst skill 形成显性互补（research 是 **子 task**，analyst 是 **user-triggered 独立角色**），不共享身份

**按需**

- **痛点**（本调研不完全适用：用户已通过 P4 报告明示，不需要再澄清）：architect 决策需要并行外部 research，现有串行 `WebFetch` 慢且 context 重
- **使用者与 journey**：architect skill，在"探索阶段（三阶段流第一阶段）"识别出 3+ 备选方案且每个需要 ≥1 次外部 fetch；当前做法是连续串行 `WebFetch` + 自己归纳；未来期望一次性派 N 个 research subagent + 结构化汇总 + 一次 AskUserQuestion
- **最简方案**（事实层，不作推荐）：
  - 不新增 role：在 `architect.md` 三阶段流程里加一段"research fan-out"指引，使用已有 `Task` 工具派发 **通用 agent**（不带 skill prompt，只 inline 声明 tool set 和返回 schema）
  - 优点：零新文件 / 零新 Resource Access / 零新 Escalation 变体
  - 缺点：architect prompt 变长；每次派发 architect 要在 Task prompt 里重述"你是 research 工人、返回格式 X"—— 模板代码重复；没有独立的 role 约束可审查
- **竞品对比**：见 §调研发现 + §对比分析

## 调研发现

### 1. CrewAI（role-based 多 agent 编排框架）

([CrewAI Processes docs](https://docs.crewai.com/concepts/processes))

**调度模型**：
- Crew-level **Process** orchestrates task execution —— 不是 Agent 自己派 subagent
- 两种 process：
  - **Sequential**：task 按预定义顺序执行，前 task 的 output 作为后 task 的 context
  - **Hierarchical**：a *manager agent* 分配任务给其他 agent、review output、判断完成
- Task 之间通过 **`context` parameter** 声明数据依赖

**对 roundtable 可借鉴点**：
- "manager agent 分配 + review" 模型 —— 与 roundtable orchestrator（主会话）角色相似
- Task dependency 声明为数据流（`context` 参数）而非调用图 —— 减少隐式耦合
- 但 CrewAI **不是 skill 派 Task 的模型** —— 它是 Process 统一调度；架构师不主动派 subagent

**不适用于 roundtable 的地方**：
- roundtable 的 architect skill 运行在主会话，是 *决策节点*；CrewAI manager agent 更接近 orchestrator 而非 architect
- CrewAI 未明确 agent 嵌套派发限制（事实：文档无相关说明）

### 2. LangGraph（graph-structured agent workflows）

（训练数据知识；WebFetch 因站点 redirect 循环未取到，事实层可信度标注为"基于 public docs 与常见使用的训练知识"）

**调度模型**：
- 图上的 **node** 通过 conditional edges 做 **static fan-out**：从一个 node 通过多条 edge 走到 N 个并行 nodes
- **Send primitive** 做 **dynamic fan-out**：运行时决定 fan 出 N 个（N 由 state 决定），每个 Send 携带子 state
- 合并通过 **reducer functions**：state 字段声明 reducer（如 `add`），并行分支返回时自动 merge 到 state
- **subgraph** 可嵌入为 node：整个 subgraph 作为一个 node 参与外层 graph 的并行分支

**对 roundtable 可借鉴点**：
- `Send` 语义（dynamic fan-out + 携带 sub-state）—— 与 architect 希望 fan 出 N research subagent、每个带不同 query 的模式同构
- reducer 模型（并行分支合并到 shared state）—— 对应 architect 的"把 N 个 research 结果合成为 option comparison table"
- subgraph 隔离 + 合并 —— 与 subagent context 隔离 + 回传给 main session 一致

**不适用的地方**：
- LangGraph 是 **state-machine first** 架构；roundtable 没有显式 state machine（orchestrator 是 Claude 对话）
- Send/reducer 是代码 API；roundtable 全 prompt 驱动，没有代码侧 reducer 可调用

### 3. Anthropic Claude Code Sub-agents（本生态栖身之处）

([Claude Code sub-agents docs](https://code.claude.com/docs/en/sub-agents)，2026-04 fetched)

**关键事实**：
- Sub-agents 解决"side task 会淹没主会话 context"的问题：子任务在独立 context 里做，返回 summary
- 每个 sub-agent：独立 context window + 自定义 system prompt + tool access + independent permissions
- Claude 看到匹配 sub-agent description 的任务时自动 delegate
- **关键 Note**（文档原文）："If you need multiple agents working in parallel and communicating with each other, see **agent teams** instead. Subagents work within a single session; agent teams coordinate across separate sessions."

**对 roundtable 的直接事实影响**：
- **roundtable 现有架构（Task 派 subagent）属于 "subagents" 范式**（单 session 内隔离 context），不是"agent teams"
- Anthropic 对 "parallel + inter-agent 通信" 的官方建议路径是 **agent teams（跨 session）**，这与 roundtable 的 Task-based subagent 有**模型分歧**
- 但 roundtable 目前的 tester / developer 等也是 Task-based subagent 形态（与 architect 派 research 同构）—— Anthropic docs 未显性禁止 Task 并行派发多个，实际 Claude Code 支持"多 Task calls in one message" 的并行

**可借鉴 / 需留意**：
- sub-agent description 字段决定 auto-delegation —— roundtable 现有 agent md 已有 `description` frontmatter
- tool access per-agent 已是支持的一等公民 —— 适合 "research subagent 只给 Read + WebFetch + WebSearch"
- AskUserQuestion **在 Task sandbox 被禁用**（已知事实，与 roundtable `## Escalation Protocol` 前提一致）
- Sub-agents 在 system docs 中是 "when matching description" 自动 delegate；roundtable 的 `Task` 派发更显式（orchestrator 主动写 prompt + 指定 agent）—— 两者兼容

### 4. 横向观察：skill ≠ subagent dispatcher（在当前 Claude Code 模型里）

- Anthropic docs 将 skill 定位为"loaded instructions for main session"；Task tool 挂在工具列表中，理论上 skill prompt 里可调用
- 事实：roundtable 的 architect.md frontmatter 未显式声明 `tools: Task`；但 skills 默认继承主会话工具集（含 Task）
- 这意味着 "architect skill 派 Task" **技术上可行**，不需要 Anthropic 层面新能力；是 roundtable 自己是否允许的**政策问题**

## 对比分析

只陈述各路径的现有基建、改造面、客观代价。不推荐。

### 三系统 vs roundtable 的异同

| 维度 | CrewAI | LangGraph | Claude Code (roundtable 栖身) | roundtable 现状 |
|------|--------|-----------|---------------------------|----------------|
| 调度主体 | Process（crew 级） | Graph executor（代码） | orchestrator（主会话 Claude） | workflow command + orchestrator |
| role 之间派发 | manager agent → agent（hierarchical） | node → node（edge） | main session → sub-agent（Task） | orchestrator → skill / agent |
| skill / agent 自己派 sub | ❌ 未说明 | N/A（无 skill 概念） | ✅ 技术可行 | ❌ 未明文允许 |
| 并行 fan-out | Process 级（未说明并行扇出） | Send primitive / conditional edges | 多 Task calls in one message | orchestrator 层已有（workflow §4 判定树） |
| 结果合并 | Task.context 数据依赖 | reducer function | subagent final message（一次性） | orchestrator 人工合并 |
| 嵌套派发 | 文档未明限制 | subgraph as node | 未显性禁止 | ❌ 未明文允许 |
| 决策对用户 | manager agent 内部完成 | 无（graph 是确定图） | AskUserQuestion 仅主会话 | `AskUserQuestion` 仅 skill |

### 三条可落地路径的客观代价

| 路径 | 新文件数 | Resource Access 变动 | Escalation 变动 | DEC-001 D8 影响 |
|------|---------|---------------------|-----------------|----------------|
| **a. 新增 `agents/research.md`**（独立 role，architect 派发） | +1 文件 | architect 的 Write 列新增 "Task dispatch to research agent"；research agent 独立矩阵（Read + WebFetch/WebSearch，Write 仅报告） | 复用现有 escalation schema，`type: "research-request"` 变体或共用 `decision-request` | 需补充：D8 原文加 "skill 可向特定 agent 派 Task，但仅限 research 类型"，或起 DEC-003 明写 |
| **b. 扩展 `agents/analyst.md` 为 dual-mode**（analyst 既可作为主会话 skill，也可作为 subagent research worker） | 0（改现有） | analyst 的 Resource Access 分两档：skill-mode 与 subagent-mode | 共用现有 skill 的 Option Schema + agent 的 Escalation | D8 被扩：一个 role 跨两种形态（破坏 D8 的"skill / agent 互斥"清晰边界） |
| **c. 不新增 role，architect prompt 内联 Task 调度模板** | 0 | architect 的 Write 列加 "ad-hoc Task dispatch for research"；无独立 agent 定义 | 无新变体 | D8 实质不变；代价是 architect prompt 变长且模板靠复制 |

## 开放问题清单（事实层，交 architect 决策）

- **Q1. 新 role 归属**：独立 `agents/research.md` / analyst dual-mode / 零新文件 inline —— 三条路径的代价见上表。事实支撑：上表；各自改造面已量化
- **Q2. research subagent 的工具边界**：事实 —— CrewAI / Claude Code 均支持 per-agent tool access；roundtable 已有 per-agent `tools:` frontmatter。research 的候选 tool set：`Read` / `Grep` / `Glob` / `WebFetch` / `WebSearch` / `Bash`（只读）
- **Q3. 扇出上限**：事实 —— LangGraph Send 无硬上限（由 state 决定）；CrewAI 未说明；Claude Code 多 Task 并行也无硬上限，只受 token budget 约束。roundtable 层需自定
- **Q4. 返回 schema**：事实 —— 三系统都依赖 role 输出格式自律。roundtable 的 `<escalation>` 已有结构化 JSON 先例；research 返回可用类似 JSON 块（`findings` / `sources` / `tradeoff` / `unknowns`）
- **Q5. 合成主体**：事实 —— CrewAI 用 manager agent 合成；LangGraph 用 reducer；Claude Code sub-agents 返回 summary 给主会话由主会话合成。roundtable 合成方可以是 architect 自己
- **Q6. Escalation 变体**：事实 —— research subagent 若在调研中需要 architect 澄清（范围模糊），有 reentrant 风险（architect 是 orchestrator 的 skill）；当前 escalation 协议"subagent → orchestrator → AskUserQuestion"可用但多转一跳
- **Q7. 与 DEC-001 D8 兼容**：事实 —— D8 原文强调 "skill 在主会话 + agent 在 subagent" 互斥形态；新增 "skill 可派 Task" 超出原 D8 scope，要么补 DEC-003 新增规则、要么 Superseded D8
- **Q8. 与 workflow.md §4 并行判定树的关系**：事实 —— §4 定义 orchestrator 层并行 subagent 的 4 条硬条件（PREREQ / PATH DISJOINT / SUCCESS-SIGNAL / RESOURCE SAFE）；research 并行是否共用这四条？如共用，"PATH DISJOINT" 对 read-only research 自动满足
- **Q9. 研究 subagent 失败 / 超时处理**：事实 —— 三系统都要求调度方对 subagent 结果做校验；roundtable 目前 orchestrator 会对 developer 结果跑 lint+test 校验，research 无对应校验机制
- **Q10. session 记忆共享**：事实 —— Claude Code sub-agents 是**独立 context**，不共享主会话记忆；如果 research subagent 需要 CLAUDE.md 上下文（如 critical_modules 影响调研方向），需要 architect 派发时显式注入
- **Q11. `description` 字段驱动 auto-delegation**：事实 —— Claude Code 依 description 自动匹配。如果新增 research agent，description 要区别于 analyst skill（否则 Claude 可能错选）
- **Q12. 与 analyst skill 的职责边界**：事实 —— analyst skill 的范围描述是"technical investigation / competitive analysis"；与 research subagent 的目标高度重叠。区分点需要 architect 明确（如 "analyst = user-triggered 独立调研；research = architect 内部子任务"）

## FAQ

（尚无追问）

---

**调研结果交接**：本报告为 architect 阶段输入。architect 将据此在 `docs/design-docs/parallel-research.md` 做选型决策（Q1-Q12 是事实交接，不是决策清单）并按需落 DEC-003 + exec-plan。

## 变更记录

- 2026-04-19 创建：对标 CrewAI / LangGraph / Claude Code sub-agents 三系统，12 个事实层开放问题交 architect。WebFetch 到 CrewAI 和 Claude Code sub-agents 官方 docs；LangGraph 因站点 redirect 循环未取到，依赖训练数据知识（已在文中标注）
