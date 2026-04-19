---
slug: subagent-progress-and-execution-model
source: 原创 + 外部文档引用（Claude Code 官方、Agent SDK、CrewAI / AutoGen / LangGraph）
created: 2026-04-19
issue: https://github.com/duktig666/roundtable/issues/7
decisions: [DEC-001, DEC-002, DEC-003]
---

# subagent 执行进度可见性 + 主会话/子会话执行模型可选配 分析报告

> 主题 slug: `subagent-progress-and-execution-model`

## 背景与目标

GitHub issue [duktig666/roundtable#7](https://github.com/duktig666/roundtable/issues/7) 来自 2026-04-18 gleanforge 项目的 P4 dogfood 实录（`docs/testing/p4-self-consumption.md` §3、§4.2）。暴露的两类痛点：

- **A — UX 层（进度可见性）**：developer / tester 子 agent 常跑 3–10+ 分钟，期间主会话无增量反馈。用户无法判断子 agent 读到哪一步、是否卡死、还要多久。P4 报告第 53 行所述"subagent 没有 AskUserQuestion"属于同族问题的一个子面，DEC-002 已用 Escalation 协议解决；但"长任务无声"的一般化问题未解决。
- **B — 架构层（执行模型选择）**：DEC-001 D8 把 developer / tester / reviewer / dba 四角色**锁定**为 subagent 形态。这一决策在 P4 被证明"架构上正确"但"UX 上僵硬"：小任务或用户想紧跟过程时，inline（主会话）执行更合适；大任务或高 context 污染风险时，subagent 仍然更合适；中间地带需要选择能力。

本报告只整理事实和外部参照，不做选型；架构推荐由 architect 阶段承接。

**用户显式 north-star（2026-04-19 会话原话）**：
> "重点还是用户感知进度对整个流程的掌控"

事实含义（非选型）：①主会话用户必须实时感知流程位置（不是事后看 transcript 找）；②用户要有**掌控感**（能判断子 agent 活着 / 卡住 / 快完了，能在关键点介入）；③进度透传的存在本身优于颗粒度的完美 —— "不透传"是当前的痛点。architect 阶段的路径选型应把这条列为硬约束。

## 追问框架（必答 2 + 按需 4）

**必答**

- **失败模式**：最可能的失败是"设计一个看似完美的透传协议但用户仍看不见"。失败具体形态有两种 — (a) 透传协议只在 subagent 完成时一次性 dump（=没用），(b) 透传协议太激进，让主会话 context 被 subagent 日志污染（= 违背 D8 初衷）。第二类失败更隐蔽：一旦 subagent 进度被 relay 到主会话即作为 assistant 文本留痕，就把当初把 developer / tester 做成 subagent 的理由（context 隔离）瓦解了。
- **6 个月后评价**：若引入"inline / subagent / auto"三档执行模型，6 个月后大概率形成两类分化 —— 重度用户只用 subagent（保持隔离纪律），轻度用户只用 inline（舒适 UX）；"auto" 档可能沦为摆设，因为 auto 触发规则解释成本高。参考：CrewAI `hierarchical` vs `sequential` 两档设计六个月后被证明足够；AutoGen v0.4 的多模式反而有一定学习曲线[^autogen-v04]。

**按需**

- **痛点（适用）**：用户要解决的是"漫长无声的等待"，不是"看所有细节"。真正需要的是：①子 agent 活着；②到了哪个子步骤；③卡住的话哪里卡住。不是"每次文件读都 relay"。
- **使用者与 journey（适用）**：
  - 重度 dogfood 用户（plugin 作者本人）：全流程要能 one-click 走完，中途只在 AskUserQuestion / Escalation 时介入；想紧跟时主动切视图，不是被动刷屏。
  - 常规项目用户（gleanforge 式）：倾向 inline 执行小任务（developer 就改 1 个文件），倾向 subagent 执行大任务（tester 跑 17 个 test suite）；需要"我这回能自己决定哪一档"。
  - 企业用户（尚未 onboard）：可能需要 CI / observability 集成，纯对话级的进度反馈不够，需要结构化事件流。
- **最简方案（适用）**：不改 D8、不动执行模型；只加"子 agent 启动时固定打印 agent-id + transcript 路径"的一行约定。用户自己用 `/agents` Running tab 或 `tail -f` 看。实现成本接近零，但不解决"主会话自身感知不到"。
- **竞品对比（适用）**：见下方 §调研发现。

## 调研发现

### 1. Claude Code 原生能力（官方文档 2026-04）

#### 1.1 subagent 执行语义（事实）

- "Each subagent runs in its own context window with a custom system prompt, specific tool access, and independent permissions. … works independently and returns results."[^ccsa-overview]
- "When the main agent delegates a task to a subagent, the subagent runs independently, does its work, and returns only its final output to the parent."（同上）
- SDK 层明确措辞：**"Intermediate tool calls and results stay inside the subagent; only its final message returns to the parent."**[^sdk-subagent]

**含义**：主会话 Claude（= orchestrator LLM）对 subagent 内部过程**系统性不可见**。这不是 UI bug，是架构边界。Ctrl+O 在 P4 被证实看不到 subagent 内部，与该语义一致。

#### 1.2 用户可见的 subagent 观察通道（事实）

Claude Code CLI 提供了**用户侧**（非 LLM 侧）的多条观察通道：

| 通道 | 位置 / 触发 | 能看到什么 | 用户操作 |
|------|------------|-----------|---------|
| `/agents` Running tab | slash 命令 | "shows live subagents and lets you open or stop them"[^ccsa-agents-cmd] | 手动切进去 |
| `Ctrl+B` | 键盘快捷键 | 把前台 subagent 切到后台；Running tab 里继续看[^ccsa-bg] | 单键切换 |
| Transcript 文件 | `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl` | 完整的 subagent 对话 + 工具调用 JSONL[^ccsa-transcript] | `tail -f` / 外部工具 |
| 子 agent 名 @提示 | typeahead | "Named background subagents currently running in the session also appear in the typeahead, showing their status next to the name"[^ccsa-typeahead] | 查看状态 |

**关键**：主会话 orchestrator 要自己感知这些通道，需要**主动读取**（例如用 `Monitor` 工具 tail transcript 文件）；这些通道不会自己流进 orchestrator 的对话窗口。

#### 1.3 `Monitor` 工具能力边界（事实）

- 引入于 Claude Code v2.1.98（2026-04-09）。"spawns a background process and streams its stdout output into the conversation in real time, without blocking the main thread"[^monitor-mindstudio]。
- 工作机制："Your script's stdout is the event stream. Each line becomes a notification."[^monitor-tool-desc]
- 批处理："Stdout lines within 200ms are batched into a single notification"（同上）。
- **未提及 subagent**：Claude Code Monitor 文档本体未提到 subagent 场景。但 transcript 是 JSONL 文件；`tail -f` + `jq filter` → `Monitor` 是可行的组合路径（需在工程侧验证）。

**含义**：Claude Code 已经提供 transcript 文件 + Monitor 工具这一对"原材料"，但官方没示范它们的组合用法。roundtable 如果走这条路，要自己把"启动 subagent → 抓 agentId → Monitor tail transcript + 过滤 → 主会话感知"的链路做出来。

#### 1.4 Hook 作为进度信号源（事实）

subagent frontmatter 支持 `PreToolUse` / `PostToolUse` / `Stop`（自动转 `SubagentStop`）等 hook 事件[^ccsa-hooks]。Hook 命令的输出通过 settings.json 可路由。这意味着 subagent 每次工具调用都有一个**可插入的钩子点**，可以 append 一行到某个 log 文件，再被 Monitor 拾取。

#### 1.5 SDK 层 vs CLI 层的不对称（关键事实）

Claude Agent SDK 的 `query()` yield 的消息流中：

- Messages from within a subagent's context include a `parent_tool_use_id` field.[^sdk-detect]
- "To detect when a subagent is invoked, check for `tool_use` blocks where `name` is `"Agent"`."（同上）

**事实含义**：SDK 宿主（= 调用 SDK 的外部程序）**能**看到 subagent 的逐消息流；而 CLI 里的 orchestrator LLM（= 主会话里的 Claude 本体）**看不到**。这是"宿主进程可见 ≠ LLM 可见"的架构不对称。

Issue #7 提的"用户在主会话看到实时进度"有两种合理解读：
- (i) CLI 宿主把 subagent 状态在用户屏幕上展示（已通过 `/agents` Running tab 部分满足）
- (ii) orchestrator LLM 把感知到的进度 relay 到对话 —— 只能靠 orchestrator 主动读入信号源（Monitor / transcript / 结构化 ping）

这两种解读对应的工程路径完全不同；是 architect 阶段的关键分叉。

### 2. 竞品对标

#### 2.1 CrewAI（Sequential / Hierarchical Process）

- 提供两种 Process：`sequential`（线性）与 `hierarchical`（manager agent 分派）[^crewai-process]。
- **Progress 机制**：`step_callback`（任务内每步触发）与 `task_callback`（任务完成触发）在 Agent / Crew 级可配置[^crewai-callback]。"CrewAI supports a step_callback on each agent, which you can wire to track progress and get visibility into each agent's work by defining a function that receives step output data."[^crewai-callback-quote]
- **执行模型**：所有 Agent 默认都在同一进程；不存在"subagent 隔离"概念 —— 所有 Agent 共享 context。hierarchical 模式下 manager 只是一个特殊 Agent；task 依然在主进程串执行。
- **事实**：CrewAI 不需要"inline vs subagent"选项，因为其架构不做 subagent context 隔离；"进度可见性"是默认能力（所有消息串行流出），不是要"透传"的问题。

**对 roundtable 的可借鉴点**：`step_callback` 思路 ↔ 给 developer / tester 加"阶段 checkpoint 回调"（每完成一个子步骤输出一行到日志）。

**不可照搬点**：CrewAI 没有 Claude Code 这种强 context 隔离；直接照抄"所有进度 relay 到主会话"会破坏 D8。

#### 2.2 AutoGen（v0.4 GroupChat）

- **Progress 机制**：`run()`（阻塞）与 `run_stream()`（async generator）两种执行入口。"run_stream() is an async generator that yields responses after each Agent completes its turn. This is not token-level streaming; each chunk is the full response from one Agent."[^autogen-stream]
- **观察能力**：v0.4 引入 OpenTelemetry 兼容的 message tracing / 内置指标[^autogen-v04]。
- **执行模型**：AutoGen 的 Agent 都在同一进程，没有 Claude Code subagent 的 context 隔离。subagent orchestration 在 v0.4 有原生支持[^autogen-v04]，但"subagent"语义也指 agent team 内的子 agent，不是 context 隔离。

**对 roundtable 的可借鉴点**："each chunk is the full response from one Agent"的颗粒度 —— 不是 token 流，是**角色级消息流**。roundtable 可以按这个颗粒度定义"agent → orchestrator"的进度事件（每个子阶段完成吐一条，而不是每次工具调用都吐）。

**不可照搬点**：v0.4 已并入 Microsoft Agent Framework[^autogen-v04]；AutoGen 本身不再是独立稳定对标。

#### 2.3 LangGraph（Streaming + Subgraph）

- **Streaming 模式**：`values` / `updates` / `messages` / `custom` / `checkpoints` / `tasks` / `debug` 共 7 种[^langgraph-streaming]。
- **Subgraph**：`.stream(subgraphs=True)` 可把 subgraph 的事件带命名空间流回父图[^langgraph-subgraph]：stream chunk 带 `ns`（namespace 元组）表明来源。
- **Events API**：`astream_events()` 覆盖 graph run 全生命周期[^langgraph-events]。
- **执行模型**：LangGraph 的 subgraph 与主 graph**共享运行时**；不存在独立 process / context 隔离。开发者通过 stream 过滤决定哪些层级的事件要向上冒泡。

**对 roundtable 的可借鉴点**：
- "namespace 元组"概念 ↔ roundtable 可以给每个事件加 `{role, agent_id, phase}` 三元组，主会话过滤。
- 多 stream_mode 并存的设计：`updates` 用作"阶段变化"、`custom` 用作"业务事件"。

**不可照搬点**：LangGraph 的 subgraph 没有 Claude Code 的 JSONL 硬边界；"订阅 sub-stream"在 Claude Code 里要通过 Monitor + transcript 间接实现。

#### 2.4 OpenAI Swarm（handoff）

（在 roundtable CLAUDE.md §设计参考里列出；事实仅用于背景）

- Swarm 以轻量 handoff 为核心；不做 subagent context 隔离；进度就是主对话流的一部分。
- 不提供本议题的新增参照；不展开。

### 3. P4 已解决 vs 待解决对比

P4 的三条 top 摩擦在 DEC-002 已经解决两条（共享资源协议、workflow Phase Matrix）；第二条（subagent AskUserQuestion 封闭）用 Escalation 协议解决。但 Issue #7 提的是 P4 报告**未被计入 top 3** 的一个观察点 —— 即 §3.🟠 agent 能力层的"漫长无提示等待"：

| P4 摩擦 | 当前状态 |
|--------|---------|
| 并行调度策略未形成显式 skill | ✅ DEC-002 §workflow 矩阵 + 并行判定树已覆盖 |
| exec-plan checkbox 谁回写契约不清 | ✅ DEC-002 §共享资源协议已覆盖 |
| `_detect-project-context` inline 化 | ✅ DEC-002 已定 inline |
| subagent 没有 AskUserQuestion | ✅ DEC-002 Escalation Protocol |
| agent 间共享依赖/约束 | ⚠️ 部分覆盖（CLAUDE.md + 上下文注入），长任务 UX 未解 |
| **"长任务无进度"漫长等待** | ❌ **未解决（= Issue #7 问题 A）** |
| "不 git commit"默认行为 | ⚠️ 部分文档覆盖 |
| `log.md` 与 `vault/log.md` 区分 | ⚠️ 部分文档覆盖 |
| architect 派 parallel research | ✅ DEC-003 已解决 |

### 4. 架构层（问题 B）—— 现状约束盘点

DEC-001 D8 / DEC-003 当前锁定的 role→form 映射：

| Role | Form | 理由（见 DEC-001 / DEC-003） |
|------|------|-----------------------------|
| analyst | skill | 主会话 AskUserQuestion 可用，调研轻 context |
| architect | skill | 决策需 AskUserQuestion |
| developer | agent | context 隔离避免主会话污染 |
| tester | agent | 同上 + 对抗性测试可能长 |
| reviewer | agent | 同上 |
| dba | agent | 同上 |
| research（新） | agent | DEC-003 专用短生命周期 subagent |

DEC-003 的正交扩展（architect skill 可派 research agent）提供了"skill 派 subagent 做短任务"先例；但方向相反（主会话派子会话），没解决"子会话让主会话看到过程"。

Issue #7 问题 B 提出"inline / subagent / auto"三档切换 —— 技术上有几类实现路径（下 §对比分析罗列），全部**潜在触碰 DEC-001 D8**。

## 对比分析（技术路径，不做选型）

### 路径 P1：增量透传（不动 D8）

维持四角色 subagent 形态。给 developer / tester / reviewer / dba 加**结构化进度事件**协议：

- subagent 在固定子阶段边界 append 一行 JSON 到共享 progress log（例如 `docs/.progress/{session}.jsonl` 或通过 `PostToolUse` hook 写入）
- orchestrator 用 `Monitor` 工具 tail 这份 log，每行即一条 notification
- 主会话只看到阶段级事件（"开始 P0.2"、"写完 foo.ts"、"lint 通过"），不看工具调用细节

**现有基建**：subagent hook 机制、Monitor 工具、transcript JSONL、Escalation 协议。
**改造面**：新增 progress event schema、hook 脚本或 subagent prompt 约定、orchestrator 在 workflow command 里注入 Monitor 启动指令。
**客观代价**：每个 subagent dispatch 多一组启动/停止 Monitor 的 overhead；需要同时 co-evolve developer/tester/reviewer/dba 四个 agent 的 prompt；事件 schema 演进成本。

### 路径 P2：执行模型三档（改 D8）

把 developer / tester / reviewer / dba 四角色的 form 从"agent 单射"改为"支持 subagent / inline / auto 三态"。

**现有基建**：skill 形态已在 architect/analyst 证明可行；DEC-003 已有"skill 派 agent"先例；D8 的 role→form 单射是设计决定，非技术强制。
**改造面**：每个角色需要**双形态**文件（或同文件双段落），Resource Access / Escalation 两套行为；`/roundtable:workflow` 选形态的决策点；`critical_modules` 触发 tester 时还要选形态；AskUserQuestion 在 inline 可用、agent 仍用 Escalation。
**客观代价**：维护成本翻倍（同一角色双语义）；auto 档的触发规则需明文（按文件数、按预估时间、按 context 预算），定义不好会成摆设（见失败模式）。DEC-001 D8 的原文"备选：全 skill 形态"已拒绝过"developer/tester 读写大量代码撑爆主会话 context"——三档模型是对此拒绝的部分撤回。

### 路径 P3：保持 D8 + 独立观察端（不改 D8、不加透传）

不动角色 form，不加透传协议。只把"用户已有的观察通道"（`/agents` Running tab、transcript `tail -f`、Ctrl+B）在 `/roundtable:workflow` 启动时在输出里**一次性 announce**，让用户主动切视图。

**现有基建**：`/agents` / Ctrl+B / transcript 路径全部原生。
**改造面**：workflow command 启动 banner + 在派发 subagent 时 echo agent name；`docs/onboarding.md` 加一段"如何在 developer 跑的时候跟进度"。
**客观代价**：把"主会话 relay 进度"转成"用户自己切视图"；不解决 orchestrator LLM 感知问题（Orchestrator 依然漫长无反馈，只是用户本人多了一个 out-of-band 观察手段）。

### 路径 P4：subagent 内 per-phase 心跳 + 外部轻监控

不改 form / 不加结构化事件。让每个 subagent 在 prompt 顶部约定"完成每个主要子步骤后在响应里打一行 `<heartbeat phase="P0.2" step="reading src/foo.ts" />`"，然后 orchestrator 约定"派发前开一个 Monitor tail 主 session transcript + grep heartbeat 标签"。

**现有基建**：Monitor + jsonl transcript 已满足。
**改造面**：subagent prompt 里的 heartbeat 约定；workflow command 里的 Monitor 启动/停止模板。
**客观代价**：依赖 subagent"守纪律打 heartbeat"；如果 subagent 遗漏，回到静默状态；事件颗粒度非结构化（文本 tag）比 P1 松。

### 路径 P6：主会话主动轮询（pull 模式）

不改 subagent 形态。subagent 以 `background: true` 或 Ctrl+B 转后台后，**主会话** orchestrator 每 N 分钟主动 Read subagent transcript JSONL 最新尾部 → 对比上次位置 → 把新事件 relay 给用户。

**现有基建**：
- 后台 subagent 原生支持（frontmatter `background: true` / Ctrl+B / typeahead 状态）
- transcript JSONL 路径公开可读
- 主会话 Read / Bash / ScheduleWakeup 原生可用

**改造面**：
- `/roundtable:workflow` 默认 dispatch 改后台（或按 form 分档）
- 主会话约定轮询模板：每 N 分钟做一次 `ls -t {transcript-dir} | head -1` + `tail -50 | jq` → relay
- 定义 relay 颗粒度：全事件 / 仅工具调用 / 仅 phase 标签
- 处理结束信号：subagent 完成时不轮询空转

**客观代价**（关键事实）：
- **官方架构倾向 push**：Agent 工具本体提示 "When an agent runs in the background, you will be automatically notified when it completes — **do NOT sleep, poll, or proactively check on its progress**"[^agent-poll-warning]。非硬禁，但明确倾向。
- **前台 dispatch 不可轮询**：当前 DEC-002 dispatch 默认前台阻塞，全盘改后台即变更 dispatch 语义。若只在部分场景后台化，需显式声明切换规则。
- **每次 poll 成本**：prompt cache TTL 5 分钟。周期 ≥ 5 分钟则每轮 cache miss；周期 < 5 分钟则 token 成本倍增。
- **相比 P1 push 模型**：P6 零改 subagent prompt 纪律、不依赖 hook 脚本；但每次 poll 是 orchestrator 一轮工具调用，push 是 stdout line 级 notification（更轻）。

**与 P1 的关键差异**：P1 需要 subagent 侧"守纪律打事件"；P6 完全单方面由 orchestrator 拉取。两种纪律分布不同 —— P1 风险在"subagent 漏打"，P6 风险在"orchestrator 不稳定的轮询节奏 + token 浪费"。

### 路径 P5：独立 reporter agent（不改四角色，新增 1 个观察者）

新增 `@roundtable:reporter` 轻量 subagent，在 developer/tester 派发时**并行**启动；reporter 的任务就是 `tail -f` workee 的 transcript JSONL（位置可从 orchestrator prompt 注入）并每 N 秒 emit 一个结构化摘要到标准文件；orchestrator Monitor 这个摘要文件。

**现有基建**：DEC-003 证明 skill/command 可并行派 agent；transcript 文件公开。
**改造面**：新增 `agents/reporter.md`；workflow command 在派 developer/tester 时自动伴随派 reporter；两个 subagent 的 lifecycle 协同。
**客观代价**：2× subagent 并行开销；reporter 自身的纪律（摘要不过度、不乱解读工程事件）；作为附加角色与 DEC-003 research 产生形态重复（两种短生命 observer 角色）。

### 汇总矩阵（事实列，不含"推荐"列）

| 路径 | 触碰 D8 | 改 subagent 文件数 | 新文件 | 用户感知主会话进度 | orchestrator LLM 可感知 |
|------|--------|-------------------|--------|------------------|----------------------|
| P1 | 否 | 4（dev/tester/reviewer/dba）+ command | 可能 1（progress schema doc） | 是（每阶段一行） | 是（Monitor 注入） |
| P2 | **是，需 Superseded/补强** | 4（双形态） | 可能 1-2 | inline: 全看见；subagent: 同现状；auto: 依赖触发规则 | inline 档直接可感；subagent 档不变 |
| P3 | 否 | 0-1（仅 command 加 banner） | 0 | 用户手动切视图 | 不感知 |
| P4 | 否 | 4（加 heartbeat 约定） | 0 | 是（heartbeat tag） | 是（Monitor tail + grep） |
| P5 | 否 | 0（四角色不改） | 1（reporter.md） | 是（reporter 摘要） | 是（Monitor reporter 输出） |
| P6 | 否 | 0（四角色不改，但 dispatch 改后台） | 0 | 是（orchestrator 周期 relay） | 是（周期 Read transcript） |

## 开放问题清单（事实层 — 供 architect 承接）

1. **Issue #7 "问题 A"与"问题 B"的关系不明**：可独立处理（只做 A 或只做 B），也可合并处理（B 的 inline 档天然解决 A，剩余 subagent 档仍需 A）。`file:` issue #7 正文把二者并列但未限定"必须一起交付"。该范围界定属于 architect 决策。
2. **`critical_modules` 触发 tester 的 form 归属**：CLAUDE.md 的 `critical_modules` 条件触发规则当前默认"触发 tester subagent"。若引入 inline 档，是否 critical_modules 仍必须 subagent？事实 —— 现文档未声明任何"form 侧"约束。`file: /data/rsw/roundtable/CLAUDE.md §条件触发规则`。
3. **DEC-001 D8 备选拒绝理由是否仍成立**：D8 原文拒绝"全 skill 形态"的理由是"developer/tester 读写大量代码撑爆主会话 context"。事实是 P4 中 developer 一次 dispatch 的 token 体积在 10k-40k 范围（见 `docs/testing/p4-self-consumption.md` §1 数据），与当前 1M context 上限的关系 architect 需评估。`file: /data/rsw/roundtable/docs/decision-log.md:106`。
4. **progress event schema 的颗粒度**：CrewAI `step_callback`（每步）vs AutoGen `run_stream`（每 agent 回合）两种颗粒度事实存在；roundtable 选哪种需决策。若选"每工具调用"则过密；若选"每 phase checkpoint"则需 phase 在 exec-plan 中已显式列出（DEC-002 §exec-plan 约定已提供）。
5. **Monitor tail 与 transcript 位置依赖**：transcript 路径 `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl` 是官方文档目前文案；`sessionId` / `agentId` 如何在 dispatch 时拿到是 orchestrator 侧的技术细节（SDK 层通过 `parent_tool_use_id` 可拿；CLI LLM 侧无直接 API）。事实 —— 本仓库无已经跑通的 Monitor+transcript 样例。`file: /data/rsw/roundtable/docs/` 全部未提到 Monitor 工具。
6. **Plugin 层 vs 项目层约定**：progress 协议应定义在 plugin 自身（`skills/` / `agents/` 本体）还是项目 CLAUDE.md？事实 —— DEC-001 D2 (零 userConfig) 让所有业务规则走 CLAUDE.md；但"progress schema"属于 plugin 元协议，与业务规则不同层。
7. **与 DEC-003 research 形态的界定**：DEC-003 已开了"skill 派 agent"口子并限定为"短生命 fact-level 调研"。若 P1/P5 引入"观察者 agent"，与 DEC-003 research 如何共存？事实 —— DEC-003 仅针对 architect → research，未覆盖 orchestrator → observer。
8. **用户偏好 form 的决策点位置**：issue #7 提及三种用户侧指定方式（配置 / 每次选择 / CLAUDE.md 声明）。事实 —— DEC-001 D2 决定"零 userConfig"；"每次选择"走 AskUserQuestion（可能对小任务 UX 反而更累）；"CLAUDE.md 声明"与 D2 一致。选哪种属架构决策。

## 参考资料（Sources）

Claude Code 官方

- [Create custom subagents — Claude Code Docs](https://code.claude.com/docs/en/subagents)
- [Subagents in the SDK — Claude API Docs](https://code.claude.com/docs/en/agent-sdk/subagents)
- [Monitor tool: real-time background process streaming in Claude Code — AI Codex](https://www.aicodex.to/articles/monitor-tool-def)
- [Claude Code Monitor Tool — claudefa.st](https://claudefa.st/blog/guide/mechanics/monitor)
- [What Is the Claude Code Monitor Tool? — MindStudio](https://www.mindstudio.ai/blog/claude-code-monitor-tool-background-processes)
- [claude-code-system-prompts — Monitor tool description](https://github.com/Piebald-AI/claude-code-system-prompts/blob/main/system-prompts/tool-description-background-monitor-streaming-events.md)

CrewAI

- [Tasks — CrewAI](https://docs.crewai.com/en/concepts/tasks)
- [Hierarchical Process in CrewAI](https://docs.crewai.com/how-to/Hierarchical/)
- [CrewAI step_callback observability issue](https://community.crewai.com/t/observability-issue-using-step-callback/2049)

AutoGen

- [AutoGen v0.4 announcement — Microsoft Research](https://www.microsoft.com/en-us/research/blog/autogen-v0-4-reimagining-the-foundation-of-agentic-ai-for-scale-extensibility-and-robustness/)
- [AutoGen GroupChat streaming discussion](https://github.com/microsoft/autogen/discussions/6411)

LangGraph

- [Streaming — LangChain Docs](https://docs.langchain.com/oss/python/langgraph/streaming)
- [Streaming and Events — DeepWiki](https://deepwiki.com/langchain-ai/langgraph/7.4-streaming-and-events)

本仓库内部

- `docs/testing/p4-self-consumption.md` — gleanforge P4 dogfood 首次完整观察
- `docs/decision-log.md` DEC-001 / DEC-002 / DEC-003
- `docs/design-docs/roundtable.md` — D8 量化评分
- `CLAUDE.md §多角色工作流配置` — critical_modules / 条件触发规则

## FAQ

（暂无；待 architect / 用户提问再补）

## 脚注

[^ccsa-overview]: https://code.claude.com/docs/en/subagents — "Each subagent runs in its own context window with a custom system prompt, specific tool access, and independent permissions."
[^sdk-subagent]: https://code.claude.com/docs/en/agent-sdk/subagents — "Each subagent runs in its own fresh conversation. Intermediate tool calls and results stay inside the subagent; only its final message returns to the parent."
[^ccsa-agents-cmd]: https://code.claude.com/docs/en/subagents — "The `/agents` command opens a tabbed interface for managing subagents. The **Running** tab shows live subagents and lets you open or stop them."
[^ccsa-bg]: https://code.claude.com/docs/en/subagents §Run subagents in foreground or background — "Press **Ctrl+B** to background a running task"
[^ccsa-transcript]: https://code.claude.com/docs/en/subagents — "find IDs in the transcript files at `~/.claude/projects/{project}/{sessionId}/subagents/`. Each transcript is stored as `agent-{agentId}.jsonl`."
[^ccsa-typeahead]: https://code.claude.com/docs/en/subagents — "Named background subagents currently running in the session also appear in the typeahead, showing their status next to the name."
[^monitor-mindstudio]: https://www.mindstudio.ai/blog/claude-code-monitor-tool-background-processes — "spawns a background process and streams its stdout output into the conversation in real time"
[^monitor-tool-desc]: https://github.com/Piebald-AI/claude-code-system-prompts/blob/main/system-prompts/tool-description-background-monitor-streaming-events.md — "Your script's stdout is the event stream. Each line becomes a notification."
[^ccsa-hooks]: https://code.claude.com/docs/en/subagents §Define hooks for subagents — PreToolUse / PostToolUse / Stop（auto-converted to SubagentStop）
[^sdk-detect]: https://code.claude.com/docs/en/agent-sdk/subagents §Detecting subagent invocation — "Messages from within a subagent's context include a `parent_tool_use_id` field."
[^crewai-process]: https://docs.crewai.com/how-to/Hierarchical/
[^crewai-callback]: https://community.crewai.com/t/how-does-the-task-callback-parameter-work/389
[^crewai-callback-quote]: https://dev.to/clevagent/how-to-monitor-crewai-agents-in-production-k6i — CrewAI step_callback 用于进度追踪的描述
[^autogen-stream]: https://github.com/microsoft/autogen/discussions/6411 — "run_stream() is an async generator that yields responses after each Agent completes its turn."
[^autogen-v04]: https://www.microsoft.com/en-us/research/blog/autogen-v0-4-reimagining-the-foundation-of-agentic-ai-for-scale-extensibility-and-robustness/
[^langgraph-streaming]: https://docs.langchain.com/oss/python/langgraph/streaming
[^langgraph-subgraph]: https://github.com/langchain-ai/langgraph/issues/5932 — subgraphs=True 的 stream 含 namespace
[^langgraph-events]: https://deepwiki.com/langchain-ai/langgraph/7.4-streaming-and-events
[^agent-poll-warning]: Claude Code Agent 工具本体 description（plugin 系统注入）："When an agent runs in the background, you will be automatically notified when it completes — do NOT sleep, poll, or proactively check on its progress."

---

created:
  - path: docs/analyze/subagent-progress-and-execution-model.md
    description: subagent 进度可见性 + 执行模型选择 5 路径对比调研（issue #7）；汇总 Claude Code/SDK 原生能力 + CrewAI/AutoGen/LangGraph 对标；含 8 条开放问题交 architect
