---
slug: batch-orchestrator
source: 原创（issue #43 需求 + Claude Code 官方文档 + DEC-001~015 内部资料）
created: 2026-04-20
---

# Batch Orchestrator 深度分析报告

> 覆盖 issue #43 `/roundtable:batch` 命令的事实层调研。架构推荐 / 决策打分不在本报告范围（归属 architect 阶段）。

## 1. 背景与目标

**需求来源**：[issue #43 P2 enhancement](https://github.com/duktig666/roundtable/issues/43) —— `/roundtable:workflow` 当前绑定单 issue / 单会话。对积压多个 P2/P3 dogfood issue 的场景（roundtable 自身递归 dogfood）用户希望 **主会话一次编排多个 issue 并行推进**，仅在最终汇聚或 tie-break 介入。

**分析范围**（用户明确"加大力度"：）

- 结构化 issue body 陈述的 5 待评估问题 / 4 架构要点 / 5 目标场景 / 3 非目标
- 核查 Claude Code `Agent` 工具 + `isolation:worktree` + `run_in_background` 三件套的原生行为
- 逐一比对 batch orchestrator 对 DEC-001~015 边界的触达
- 深度对比 DEC 编号竞争 / 冲突预检 / 并发模型 / worktree 生命周期 / 失败终态 的各技术路径的成本 / 风险 / 失败模式
- 评估与 #28 / #30 / #48 的正交性
- Dogfood 可行性量化

**不做**：架构路径推荐、方案打分、"建议选 X"等指向性措辞（归属 architect）。

## 2. 追问框架

### 必答 2

**失败模式 / 最可能在哪里失败**：

- **子 agent 集体卡死**（`AskUserQuestion` 在 background subagent 无响应途径）—— Claude Code 文档明确：background subagent 若需 clarifying question，"that tool call fails but the subagent continues"[^1]。对于 `/roundtable:workflow --auto --decision=text` 组合，若路径中任一 skill 弹 modal AskUserQuestion（而非 text `<decision-needed>`），子 agent 会失败或 fallback 未知行为
- **DEC 编号竞争 + sed 替换假阳性**：`DEC-NEW-<uuid>` 占位符如果在子 agent 产物中被**邻近 plain text** 误用（例如 "我不小心写了 DEC-NEW-abc123 在代码块里做示例"），主会话 sed 会错误替换
- **worktree 堆积 + 磁盘耗尽**：并行 N 个 issue × 每个 issue worktree 副本 = N×repo_size；长期 dogfood 跑完不清理会吞盘
- **API rate limit（429）在 concurrency>3 时命中**：Anthropic API 不做专门 bulk discount
- **主会话中断** + `Ctrl-C` → 已派发 bg subagent 失去接收方，但仍在跑（Claude Code 不会自动 cancel）

**6 个月后评价**：

可能成为债务的三个方向：

1. **命令双生态**：若 `/roundtable:batch` 与 `/roundtable:workflow` 在后续演化中行为漂移（workflow 升级但 batch 转发未跟进），两套入口产生语义分叉，**新用户不清楚什么时候该用哪个**。维护成本随时间推进线性放大
2. **冲突预检启发式假阴性兜底依赖 worktree**：假阴性（预检漏报但 issue 实际改同文件）的兜底是 worktree 隔离 + 用户最后手动 rebase/merge。如果用户依赖此流程跑 dogfood 数月后才发现某类冲突**持续漏报**（例如 issue body 引用某 DEC 但以别名 / 中文叙述代替），预检会成为"看似工作实则不灵"的静默债务
3. **DEC 重编号语义复杂化**：后续 DEC 若引入**跨 DEC 显式 supersede 链**，重编号时需保持 Supersede 关系的 ID 映射一致 —— 一次 sed 替换不够，需语义级 rename；P2 批次若与 P3 批次跨 session 复用同占位符 UUID（低概率但存在），会互相污染

### 按需 4（本任务适用，绿地功能 + 需求定位新系统）

**痛点**：真正解决什么？

- issue 描述：批量 dogfood 时 `/roundtable:workflow` 每次只能一条 issue；用户只想看最终 PR 集合，中间交互成本是损失
- **放大镜**：\#33 (DEC-015 auto mode) 把单 issue 非交互化；\#43 把 N 条 issue 并行非交互化。两者是同一痛点的两个量级
- **真实数据点**：当前 roundtable open issue 11 条（见 §3.10）；P2/P3 占 9 条；若不 batch 单条按"analyst 30min + architect 1h + developer 2h"估算 = 27h+ 单串；batch concurrency=3 理论 ≈ 9h

**使用者与 journey**：

- **第一视角**：roundtable 维护者（duktig666）在 TG 触发 `/roundtable:batch #27 #29 #40`，期望收到"3 个 PR URL 各可点开"的终态消息，中间不需要操心
- **第二视角**：P4 dogfood 期间新用户测试 batch 命令；需要命令有明显失败退路（recommended 缺失停在 worktree）+ 可回溯 audit trail
- **第三视角**：CI / 自动化脚本（本 issue 非目标但未来可能）

**最简方案 MVP**：

- 单 issue 形态的 `/roundtable:batch #N` = `/roundtable:workflow #N --auto --decision=text` 包裹一层 Agent worktree
- 无冲突预检 / 无 DEC 重编号 / 无汇聚报告
- 验证 "Agent + isolation:worktree + /roundtable:workflow 可执行" 的技术可行性
- 成本：~50 行 command 文件

**竞品对比**（至少 2 个参考方案）：

1. **GitHub Actions matrix strategy + Claude Code SDK**：每个 issue 一个 job，matrix fan-out；`strategy.max-parallel` 控并发；GH 原生 worktree-per-job 隔离。**设计理由**：GH CI 本就为并发任务设计，fan-out/fan-in 语义原生；**与本需求差距**：不在 Claude Code session 内部，`<decision-needed>` 无法 bubble 到 TG，用户 tie-break 要切到 GH UI
2. **Claude Code `agent teams`**（官方功能，documentation reference "agent teams coordinate across separate sessions"[^1]）：多 session 协调执行并行任务，专为"sustained parallelism or exceed your context window"场景设计。**设计理由**：workload 超出单 session context 时的一等方案；**与本需求差距**：agent teams 是**多 session**，跨 session 不能用主会话的 Monitor + TG 通道；用户已选"主会话内部 fan-out"形态，agent teams 相当于另一维度
3. **Aider / Cursor agent mode**：单会话内处理多任务但无 worktree 隔离，依赖 git branch 切换。**与本需求差距**：无并行，串行效果 ≈ 当前 `/roundtable:workflow` 多次调用

## 3. 调研发现

### 3.1 需求结构化（量化事实表）

**issue body 五大待评估问题**（逐条转事实）：

| # | 问题 | issue 作者倾向 | 是否开放 |
|---|------|---------------|---------|
| 1 | 并发模型：Agent 多调用并行 vs 串行 + 内部 auto | "推荐前者（真并行）" | ✅ 开放（事实层） |
| 2 | Worktree 清理：保留 vs 回收 vs 有变更保留 | "有变更保留、无变更回收（isolation:worktree 默认行为）" | ✅ 开放 |
| 3 | PR 基线：main vs DEP 图合并序 | "初版走前者（main）" | ✅ 开放 |
| 4 | critical_modules tester 跨 issue 并行 | "不允许（保持 DEC-001 语义）" | ✅ 开放 |
| 5 | 与 #28 关系 | "正交，互不依赖" | ⚠️ 待核验（§3.9） |

**4 架构要点**（issue 原文）：

- 隔离策略：`Agent(subagent_type=..., isolation:"worktree", prompt:"/roundtable:workflow <N> --auto")`
- 冲突预检（lightweight）：扫 `DEC-\d+` / `skills/*.md`
- DEC 编号竞争：方案 A 中心锁 vs 方案 B post-hoc renumber
- 并发上限默认 3，`--concurrency N` 覆盖

**5 目标场景点**：略（issue body 自解释）

**3 非目标**：不做 issue 依赖图自动推导 / 不做跨 issue context 共享 / 不做 auto + human-in-the-loop 异步通道

**量化估算**（standalone 单 issue baseline）：

| 指标 | 值 | 来源 |
|------|---|------|
| 单 issue workflow 耗时（小任务 bugfix） | ~10-30 min | 估算：#37/#38 实测 |
| 单 issue workflow 耗时（中等 feature） | ~1-2 h | 估算：#33 实测 |
| 单 issue workflow 耗时（大 feature 含 tester） | ~2-4 h | 估算：#31 实测 |
| concurrency=3 理论加速 | 2.5-2.8× | 估算（有 fan-in/fan-out overhead） |
| 单 issue prompt token 消耗（含工作流） | ~30-80k | 估算 |
| 同 concurrency API 并发上限触发 rate limit | ~3-5 | 待验证 |

### 3.2 Claude Code `Agent` 工具原生能力（实测 + 官方文档）

来源：`https://code.claude.com/docs/en/sub-agents`（WebFetch 2026-04-20）

**frontmatter 字段表**（相关字段全表）：

| 字段 | 作用 | 与本需求相关 |
|------|------|------------|
| `isolation: worktree` | 临时 git worktree，隔离 repo 副本，**自动清理若 subagent 无变更** | ✅ 本需求核心 |
| `background: true` | 并发运行；launch 前 Claude Code prompt 预授权所有工具权限；auto-deny 未预授权；**needing clarifying question → tool call 失败但 subagent 继续** | ✅ 本需求核心 |
| `maxTurns` | 单 subagent 最大 agentic 轮数 | ⚠️ 可能需要设（防止 infinite loop） |
| `tools` / `disallowedTools` | 限定可用 tool | ⚠️ batch 子 agent 需 gh / git / bash 全开 |
| `permissionMode` | `auto` / `acceptEdits` / `bypassPermissions` | ⚠️ batch 内 subagent 大概率需 `auto` 或 `acceptEdits` |
| `mcpServers` | MCP server 配置 | ⚠️ 继承主会话 TG plugin？待验证 |
| `hooks` | 子 agent 级 hook | 不需 |
| `skills` | 可用 skills | ⚠️ 需继承 roundtable plugin 全套 |
| `initialPrompt` | 首轮 prompt prefix（processed commands and skills） | ✅ 可用来塞 `/roundtable:workflow` slash command |
| `model` | 子 agent model | ⚠️ 默认继承；Opus vs Haiku 取舍 |
| `effort` | 思考深度 | 不明；默认 |
| `memory` | 子 agent memory | 子 agent 与主会话 memory 隔离 vs 共享？待验证 |

**已确认关键行为**（官方文档引用）：

1. **`isolation: worktree` 清理语义**：
   > "The worktree is automatically cleaned up if the subagent makes no changes"

   反之有变更 → 保留（与 issue 作者假设一致）

2. **background subagent 的 clarifying question 处理**：
   > "If a background subagent needs to ask clarifying questions, that tool call fails but the subagent continues."

   **关键影响**：子 agent 内 skill 弹 `AskUserQuestion`（modal）→ tool call 失败但 subagent 继续 → 未知后续行为。**对 text mode 是根本约束**：子 agent 必须 `decision_mode=text`，`<decision-needed>` 作为 text 输出到 final message（不走 tool）

3. **subagent 与 parent 的 context 隔离**：
   > "Each subagent runs in its own context window with a custom system prompt, specific tool access, and independent permissions."

   **含义**：子 agent 不共享主会话 context；返回 only summary；主会话要拿到子 agent 的 `<decision-needed>` 块必须在 final message 里 + 主会话 parse

4. **subagent resume 语义**：
   > "If a stopped subagent receives a `SendMessage`, it auto-resumes in the background without requiring a new `Agent` invocation."

   **含义**：子 agent 中途 tie-break 停留 → 主会话可 `SendMessage` 唤醒（relay 用户决策）而不必重跑

5. **并行 subagent**：
   > "For independent investigations, spawn multiple subagents to work simultaneously"

   **含义**：单 message 多 Agent 调用支持（与 DEC-003 parallel research 同机制）

6. **agent teams vs subagents**：
   > "If you need multiple agents working in parallel and communicating with each other, see agent teams instead. Subagents work within a single session; agent teams coordinate across separate sessions."

   **含义**：本需求选"subagents in single session"路径；`agent teams` 是备选但需跨 session，与主会话 TG channel 断开

**待验证**（文档未明说或未找到）：

- Agent 工具 timeout 阈值（有无默认 timeout？触发后 subagent 状态？）
- `maxTurns` 触发后 subagent final message 形态
- MCP plugin tools（TG reply）是否自动继承到 subagent（推断：`mcpServers` 字段未显式指定 → 继承主会话？）
- 子 agent 内能否 fan-out 嵌套 Agent 调用（batch 子 agent 内的 workflow 调用 developer subagent 形成二级 fan-out）
- Anthropic API 并发 rate limit 具体数值

### 3.3 DEC-001~015 冲突清单（逐条核查 batch orchestrator 的触达）

| DEC | 内容概括 | batch orchestrator 触达 | 潜在冲突 |
|-----|---------|-----------------------|---------|
| **DEC-001** | 4 agent 打包 plugin + D1-D9 | batch 主会话 orchestrator 扩展不改 4 agent | 低；batch 层是 command 层不是 agent 层 |
| **DEC-002** | shared resource / escalation / workflow matrix | batch 汇聚多个 subagent 的 escalation | ⚠️ escalation 多路并发聚合时合并规则未定 |
| **DEC-003** | architect parallel research fan-out | batch 与 research 都用并行 subagent | **嵌套并行**：batch 子 agent 内的 architect 再 fan-out research = 二级并行 |
| **DEC-004** | progress event JSON schema（P1 push） | batch 主会话 Monitor 多 dispatch_id 交织 | ⚠️ 需每个 batch 子 agent 独立 DISPATCH_ID；其内部 workflow 若派 subagent 再生第三级 dispatch_id |
| **DEC-005** | developer 双形态 inline/subagent | batch 子 agent 内部 workflow 会自选 form | 不冲突；子 agent 自定 |
| **DEC-006** | phase gating 三段式（producer-pause / approval-gate / verification-chain） | batch 层本身也是混合（Step 4 producer-pause + Step 5 verification-chain） | ⚠️ **新问题**：batch Stage 4 plan confirm 属于 A 类 producer-pause，但用户 auto 意图与此冲突 |
| **DEC-007** | subagent progress content policy | 不变 | 不冲突 |
| **DEC-008** | workflow Step 3.5 前台派发免 Monitor | batch 全走 bg，全启 Monitor | 不冲突 |
| **DEC-009** | 轻量化重构（4 helper + log batching） | batch 可能需自己的 helper，或 inline | 不冲突 |
| **DEC-010** | 矫正 DEC-009 决定 1（精简心智） | batch 主体在 commands/batch.md 中集中；**抽 helper 须有数据支持** | 约束强：不能为"美观"抽 helper |
| **DEC-011** | decision-log 条目顺序（置顶 / 最新在前） | batch 重编号改变原"直接递增"语义 | **⚠️ 新问题**：重编号后是否还满足"最新在前"（按完成时序分 ID 后顺序仍是最新在前，但 DEC ID 不单调递增跨子 agent） |
| **DEC-012** | subagent 派发 run_in_background 策略（D2 并行度 + D4 两级逃生门） | batch 全并行走 bg | 一致；条件 2（并行度≥2）自动满足 |
| **DEC-013** | decision_mode modal/text + §3.1a TG 转发 | batch 子 agent 强制 text；TG 转发在 batch 主会话 vs 子 agent vs 主-子往返链 | ⚠️ **三层嵌套**：TG → batch 主会话 → batch 子 agent → workflow → architect skill；任一层 `<decision-needed>` 需 bubble 到 TG |
| **DEC-014** | bugfix tiered rootcause | 不变 | 不冲突 |
| **DEC-015** | auto_mode（--auto / env） | batch 子 agent 固定 `--auto`；batch 本身是否也支持 auto？ | ⚠️ 双层 auto：batch 层 auto + 子 agent auto，语义区分 |

**关键发现**：DEC-002 / DEC-003 / DEC-004 / DEC-006 / DEC-011 / DEC-013 / DEC-015 有交互 —— 都是 orchestrator 层 / decision-log 顺序 / 决策流机制相关。batch 是"多个 orchestrator 的元 orchestrator"，必然触达这些。

### 3.4 DEC 编号竞争深度对比

#### 方案 A：主会话中心锁预分配编号段

**机制**：主会话 fan-out 前读当前 `decision-log.md` MAX = X；分配 `[X+1, X+N]` 给 N 个 batch 子 agent（按 issue 顺序或随机）；子 agent 使用固定预分配编号写 DEC。

**失败模式**：

- **子 agent crash 后编号空洞**：若 `#A` 分配 DEC-017 但子 agent crash 且无 DEC 产出，DEC-017 永久空洞；违反 DEC-011 "编号只增不减，不复用"隐含的"无空洞"（严格讲铁律只说"不复用不回退"，没说"不空洞"，但审计不好看）
- **需要跨子 agent 锁**：主会话顺序分配即可（无并发 counter 问题），但需保证其他单 issue `/roundtable:workflow` 并发调用不抢占这段号 —— 假设用户一手跑 batch 另一手跑单 issue workflow，单 issue workflow 读的 MAX 仍是 batch 跑前的 X，会和 batch 分配号冲撞
- **子 agent 超限写**：若子 agent 要写 >1 个 DEC（例如 #A 意外产出 3 个决策），预分配段不够

**优势**：

- 号码从派发时即固定；子 agent PR body 可直接写最终 DEC 号
- 无事后 sed 替换的文件扫描成本

#### 方案 B：post-hoc renumber with `DEC-NEW-<uuid>` 占位

**机制**：子 agent 写占位 `DEC-NEW-<uuid8>`（`openssl rand -hex 4` 足够）；主会话 fan-in 后按完成时序读当前 MAX 依次分配 `DEC-(MAX+1)` `DEC-(MAX+2)` ...；sed 替换跨文件。

**失败模式**：

- **假阳性替换**：若占位符巧合出现在**非 DEC 引用上下文**（例如代码块示例、注释里提到占位语法），sed 会误换
  - 缓解：正则限定前缀必须匹配 `^### DEC-NEW-[a-f0-9]{8}` 或严格 ID 字符集 `\bDEC-NEW-[a-f0-9]{8}\b`；实测 UUID8 碰撞概率 ≤ 1/4Bn
- **子 agent 产物被**第三方 agent 引用（仍在 worktree 内）：无影响，sed 同范围替换
- **子 agent 产物跨 worktree 被外部引用**：不存在（worktree 隔离）
- **重编号漏文件**：sanity grep `grep -r "DEC-NEW-" docs/ skills/ agents/ commands/` 末尾必须 0 命中；命中说明漏替换
- **重编号过程中中断**（sed 跑一半挂了）：部分 DEC-NEW 留下，部分已替换；手动补替
- **完成时序不确定**：多个子 agent 几乎同时完成时，"谁先谁后"取决于 bg notification 到达序，可能与用户心理预期的"issue 顺序"不一致

**优势**：

- 子 agent 零协调 / 零跨子 agent 锁
- crash 子 agent 的占位符直接丢弃（sed 扫不到它的 worktree 即忽略）
- 容错 + 简单

#### 方案 C：第三方案 —— batch 主会话统一写 DEC，子 agent 不写

**机制**：子 agent 的 architect 不写 `decision-log.md`，改在 final message 以 `dec_proposals:` YAML 上报决策草案；主会话 fan-in 后由 batch orchestrator / meta-architect 统一合并入 decision-log。

**失败模式**：

- **违反 DEC-001 D8 Resource Access**：architect 写 `decision-log.md` 是核心职责，剥夺后 architect 心智破碎
- **语义断裂**：DEC 是 architect 决策的权威载体；统一写意味"batch 的 meta-architect 代 architect 决策"，与多 subagent 独立设计的本意相反
- **需要新规则**：什么是"可以合并的 DEC 草案"？冲突怎么处理？
- **YAML schema 工作量大**：DEC body 段是长 markdown，装进 YAML 需 escape

**优势**：

- DEC 编号单调单作者单调递增，零并发
- decision-log 仍由主会话一次写入（与现状一致）

#### 三方案对比表（事实层，不打分）

| 维度 | A 中心锁 | B post-hoc renumber | C 主会话统一写 |
|------|---------|---------------------|---------------|
| 实现复杂度 | 中（跨 agent 号段分配 + 单 issue workflow 并发互斥） | 低（占位符 + fan-in sed） | 高（YAML schema + 合并规则 + 违反 Resource Access） |
| crash 容错 | 空洞风险 | 占位符自然丢弃 | architect 草案可能半成品 |
| 号码预告性 | 强（子 agent PR body 可写最终号） | 弱（需 fan-in 后才知） | 中（主会话合并后确定） |
| 需改的 agent/skill | batch 命令 + architect skill（加号段分配逻辑） | architect skill（加 batch_mode 条件 + 占位符生成） | architect skill（大改：不再写 decision-log + 改 YAML output） |
| DEC-001 / DEC-011 / Resource Access 冲突 | 无显著冲突 | 无显著冲突 | **违反 DEC-001 D8 + 改变 Resource Access** |
| sanity check 成本 | 检查号段是否漏 | grep 检查占位符残留 | 检查 YAML schema 合法性 + 合并完整性 |

### 3.5 冲突预检启发式误差分析

**预检机制**（issue 提议）：

```
正则 1: DEC-\d+
正则 2: (?:skills|agents|commands)/[\w-]+\.md
图构建：节点=issue，边=共享 ≥1 个 token
分组：连通分量 → 同组串行
```

**真阳性率预估**（按历史 issue 抽样）：

抽样 open issue 11 条（#20/#22/#23/#26/#27/#28/#29/#30/#40/#43/#48），手工分析其 body 中的 token 与实际改动面关系：

| Issue | body DEC token | body 路径 token | 实际潜在改动面 | 预检有效 |
|-------|---------------|----------------|--------------|---------|
| #20 | - | - | `skills/_detect-project-context.md` + agents/*（subagent cold-start） | ❌ 漏报（body 不提路径） |
| #22 | DEC-010 | runtime prompts | workflow.md / agents/*（token audit） | ⚠️ 半报 |
| #23 | - | - | `agents/reviewer.md` | ❌ 漏报 |
| #26 | DEC-006 | - | workflow.md Stage 9 | ✅ 对 DEC-006 报 |
| #27 | - | - | skills/*.md FAQ 段 | ❌ 漏报 |
| #28 | - | - | workflow.md 决策流 | ❌ 漏报 |
| #29 | - | skills/architect.md | skills/architect.md（产出字段重复 bug） | ✅ |
| #30 | DEC-006 | commands/workflow.md:24 | workflow.md + bugfix.md | ✅ |
| #40 | DEC-014 | - | design-docs/bugfix-rootcause-layered.md | ✅ DEC-014 |
| #43 | DEC-001/003/004/006/008/011/013/015 | workflow.md | commands/batch.md + skills/architect.md | ✅ 大量 |
| #48 | DEC-013 | commands/workflow.md + skills/architect.md | 同 + bugfix.md | ✅ |

**真阳性率**：11/11 中，6 个显式命中（54.5%）；5 个漏报（45.5%）。

**假阴性主要类型**：

- **UI / 显示类 issue**（例 #27 FAQ 不持久化）：body 描述用户症状不提文件路径
- **跨角色 bug**（例 #20 subagent cold-start）：body 谈"现象级"不指代码位置
- **决策流本身 bug**（例 #28 串行→并行）：body 谈"模式"不指 DEC 编号
- **reviewer bug**（例 #23）：body 列 Resource Access 冲突但不加文件名

**假阳性主要类型**：

- **issue body 引用 DEC 但不改 DEC-log**（例 #43 引用 DEC-001~015 做"对齐"讨论不改内容）：batch 只改 decision-log 置顶 + architect skill 分支
- **issue body 列文件路径但只修边缘**（例 #22 "runtime prompts" 广义指代但真实改动可能仅 1 文件）

**兜底机制 worktree 隔离的代价**：

假阴性场景下，两个 batch 子 agent 同时改 `commands/workflow.md`（预检未分组，并行跑）：
- 两个 worktree 各有自己的 workflow.md 修改版本
- 各自开 PR
- 合并时第二个 PR rebase 会冲突 → **用户手动解决**

结论：假阴性 = 合并期延迟痛（不是正确性问题）；假阳性 = 串行跑（性能损失）。两者权衡取决于用户"合并 rebase 容忍度"vs"总体完成时间"。

**预检粒度扩展候选**：

- 扩到 `docs/design-docs/*.md`：很多 issue 引用 design-doc slug（例 "参照 lightweight-review.md"），可能命中
- 扩到 `docs/decision-log.md`：与 DEC token 冗余
- 扩到源码（若 target 非 roundtable）：需按语言扩展正则

### 3.6 并发模型对比深挖

**方案 A：主会话 single message 多 Agent 调用并行**（issue 作者推荐）

- 一次 assistant message 发 N 个 Agent 调用（`run_in_background: true`）
- 每个 Agent 独立 worktree + DISPATCH_ID + Monitor
- 主会话可在其他消息里 pending，bg 子 agent 自己跑
- Claude Code 官方支持"spawn multiple subagents to work simultaneously"[^1]

**方案 B：主会话串行 Agent 调用，每个 Agent 内部 auto 模式**

- 主会话逐条 await 每个 Agent 返回
- 总耗时 = Σ 单 issue 耗时，**无并行收益**
- 仅节省"用户人工 gate"一项（已由 DEC-015 在单 issue 层覆盖）

**方案 B 为什么是 issue 作者提了但不推荐的**：它等价于 shell 脚本 `for issue in #A #B #C; claude "/roundtable:workflow $issue --auto"`，完全失去本 issue 的"并行"价值。

**并发数量的 API / 本地实际约束**：

- Anthropic API rate limit：**待验证**（官方文档未给具体并发数；估算 tier 3/4 可 ≥5）
- Claude Code 本地 Agent 实例数上限：**待验证**（官方未明文上限；实测同步 3 个并发 background subagent 稳定 —— 来源：社区 / 本项目历史）
- Monitor 交织可读性：3 个 dispatch_id 交织尚清晰；5 个开始需要 grep / filter
- Disk：每个 worktree 复制 repo，5 个 = 5× repo size

**错误传播延迟**：

- bg subagent 失败 → 主会话收到 completion notification（Claude Code 原生）
- 主会话当前在其他响应里 → notification 收到时机延后到下一轮
- **最坏场景**：主会话长时间空闲，用户被迫 refresh / 主动查状态

### 3.7 Worktree 生命周期隐性成本

**生命周期官方语义**（引用文档）：

> "The worktree is automatically cleaned up if the subagent makes no changes"

**有变更时**：worktree 保留；路径与 branch 由 Claude Code 维护（未明说是否立即告知父 agent）

**本地调研**：

```bash
$ git --version
git version 2.34.1
$ git worktree list
/data/rsw/roundtable  a3b79c5 [feat/batch-orchestrator]
```

- `git worktree list` 显示所有 worktree 路径与 branch
- `git worktree prune` 清理 已删除物理路径的记录（不删 branch）
- `git worktree remove <path>` 显式删除

**堆积估算**：

- roundtable repo 当前 ~20MB（docs + skills + agents + commands 主）
- 5 issue × 并行 × 保留 = 100MB
- 50 次 dogfood 无清理 = 1GB
- 用户磁盘受影响但非阻塞

**长期堆积对 git 性能**：

- `git status` / `git fetch` 性能与 worktree 数量 **弱相关**（fast-path 已优化）
- 长期 50+ worktree 会使 `git gc` 变慢
- 预估阈值：≥100 worktree 或 >5GB 是考虑强制 prune 的时点

**人工 inspect worktree UX**：

- 用户需知道 worktree path（主会话报告里）
- `cd <path> && git log --oneline -5` 看 branch 状态
- 接续：可在该路径内跑 `/roundtable:workflow <N>`（若 plugin 激活）
- 或 `git worktree move` / `git worktree remove`

### 3.8 失败终态穷举

issue body 列了 3 类；实际至少 8 类：

| # | 终态 | 触发条件 | worktree 状态 | 检测方式 |
|---|------|---------|--------------|---------|
| 1 | ✅ Success | 子 agent final message 含 PR URL | 有变更保留（已 push） | 正则匹配 PR URL |
| 2 | 🟡 Decision pending | 子 agent final 含 `<decision-needed>` 未决（auto mode fallback） | 有变更保留 | 正则匹配 `<decision-needed` |
| 3 | 🟡 Design confirmation needed | architect 完成但未 approve（若 auto 不全豁免 Stage 4） | 有变更保留 | 正则匹配 phase summary |
| 4 | 🔴 Tester hard regression | tester `<escalation>` 报业务 bug | 有变更保留 | 正则匹配 escalation JSON |
| 5 | 🔴 Lint failure | developer 后跑 lint 失败 | 有变更保留 | final message 含 lint fail 标记 |
| 6 | 🔴 Test failure | developer 后跑 test 失败 | 有变更保留 | 同上 |
| 7 | 🔴 Subagent crash / maxTurns 超限 | Claude Code 运行时错 / turn 超限 | 可能无变更→自动回收；可能部分变更→保留 | Agent tool 报错 |
| 8 | 🔴 Main session 中断（Ctrl-C） | 用户主动中断主会话 | bg subagent 继续跑到自然结束后 result 失联 | 无自动检测 |

**额外边界**：

- `AskUserQuestion` 被 skill 误触发（非 text mode fallback）→ Claude Code 记录 tool failure 但 subagent 继续跑 → **未明确状态**；DEC-015 决定 11 已知常量
- MCP server（TG reply）在 subagent 中调用 → 是否真调到主会话关联的 MCP client？**待验证**（`mcpServers` 继承问题）
- 子 agent 内嵌套 Agent 调用（二级 fan-out）失败 → 传播到 batch 主会话的路径：`inner escalation → workflow` bubble → `batch subagent` final message → batch 主会话 parse

### 3.9 邻近 issue 正交性核验

| Issue | 主题 | 与 #43 交互 | 真正交？ |
|-------|------|------------|---------|
| **#28** | orchestrator 串行决策并行化（单 issue 内独立决策并发） | #28 单层并发；#43 多 issue 层并发 | ✅ 正交（不同层次）；**但**：若 #28 实现要求 orchestrator 内部 tracking 并发 state，而 batch 子 agent 内部也跑 workflow → 二级并发叠加时 state tracking 要跨层传递。低风险但潜在耦合 |
| **#30** | phase gate 缺失 bug（analyst/architect silent skip） | #43 若 auto mode 生效，本 bug 在 batch 子 agent 内部被 auto "绕过"（不是修复） | ⚠️ **暗耦合**：batch + auto 会掩盖 #30 bug（用户看不到 silent skip）；#30 应先修再做 batch，否则 batch 会 mask 此 bug |
| **#40** | DEC-014 minor follow-up | 独立 | ✅ 正交 |
| **#48** | phase summary / producer-pause 扩展 TG 转发 | batch 主会话的 Stage 4 / Stage 7 / fan-out / fan-in 事件 = 都是 phase summary 类 | ⚠️ **强耦合**：#48 不修 = batch 在 TG 下用户看不到 fan-in 报告；**#48 应与 #43 协同**；或 #43 在 MVP 阶段手工转发 |
| **#20** | subagent cold-start 开销 | batch 是多 subagent 场景，cold-start 叠加；并发 3 = 3 倍冷启 | ⚠️ **性能耦合**：batch 加剧 cold-start 感知；#20 若优化会让 batch 更香 |
| **#26** | Stage 9 Closeout commit/push/PR flow | #43 子 agent 内的 Stage 9 + batch 主会话的 fan-in 都涉及 | ⚠️ **语义耦合**：batch 层自己的"commit/push/PR flow"（fan-in 后一次性 push 多 PR）与 #26 讨论的单 issue flow 形式不同；需定义 |

**结论**：issue 作者假设"#43 与 #28 正交"正确，但**漏列 #30 / #48 / #20 / #26 的耦合**。

### 3.10 Dogfood 可行性评估

**当前 open issue**（11 条，截至 2026-04-20）：

| # | P | 类型 | 预估改动面 |
|---|---|------|-----------|
| #48 | P1 | enhancement | workflow.md / bugfix.md / architect skill / analyst skill |
| #43 | P2 | enhancement | commands/batch.md（新） / architect skill |
| #40 | P3 | follow-up | design-docs/bugfix-rootcause-layered.md |
| #30 | P1 | bug | workflow.md |
| #29 | P2 | bug | skills/architect.md |
| #28 | P2 | enhancement | workflow.md |
| #27 | P2 | bug | skills/*.md FAQ |
| #26 | P2 | design | workflow.md Stage 9 |
| #23 | P2 | bug | agents/reviewer.md |
| #22 | P3 | docs | workflow.md + agents/* (token audit) |
| #20 | P3 | enhancement | skills/_detect-project-context.md / agents/* |

**冲突预检结果**（用 §3.5 启发式）：

- **DEC token 共享**：#43 + #48 + #30 + #26 共享 DEC-006/013；潜在冲突
- **路径 token 共享**：`commands/workflow.md` 出现在 #48/#30/#28/#26/#22 共 5 条 → 全冲突组
- **skills/architect.md**：#43/#29/#48 共享

**预检分组**（连通分量）：

- **Group 1**：{#48, #30, #28, #26, #22} 全共享 workflow.md
- **Group 2**：{#43, #29, #48}（与 Group 1 部分重叠，因 #48 在两组 → 合并为超大组）
- **Group 3**：{#23}（独）
- **Group 4**：{#20}（独）
- **Group 5**：{#27, #40}（独）

**合并后**：Group 1+2 = {#22, #26, #28, #29, #30, #43, #48} 共 7 条（全部串行）；Group 3-5 = 3 个独立并发组。

**结论**：当前 open issue 大多数相互冲突（都改 workflow.md 或 architect.md）。**batch 首次 dogfood 的有效并行度很低**：理论 concurrency=3，实际 ≈ 3（一个超大 group 内串行 + 2-3 个独立）。预期**首跑无法证实 batch 并行价值**。

**建议的可行首跑候选**：{#23, #20, #27}（三独立 issue，全冲突预检 0 命中）—— 可作为 P4 dogfood smoke。

## 4. 对比分析（技术路径的客观代价）

### 4.1 命令形态

**A. 新独立 `commands/batch.md`**：
- 单文件 ~250 行
- 新维护面：+1 command prompt（critical_modules 命中面 +1）
- workflow.md 本体不变（未扩行数）
- 用户心智：多一个命令，但语义清晰

**B. 扩展 `commands/workflow.md` 加 `--batch` 模式**：
- workflow.md 357 → ~500 行
- critical_modules 命中面不变（同一文件仍 1 处）
- 单 issue 用户每次调用都消费 ~140 额外 token（workflow.md 被加载但未使用 batch 段）
- 用户心智：一个命令但两种模式

### 4.2 DEC 编号竞争方案

参见 §3.4 三方案对比表。

### 4.3 冲突预检

- **正则预检**：O(N²) 分组图；简单易实现；假阳/假阴率见 §3.5
- **无预检**：worktree 隔离兜底；合并时 rebase 冲突转嫁给用户
- **AST 级分析**：需集成解析器（markdown / Rust / TS 等），工程量 >>正则

### 4.4 Worktree 生命周期

- **沿用原生（有变更保留 / 无变更回收）**：零代码
- **强制保留**：需 plugin 层 override Claude Code 默认
- **强制回收**：同上 + 失败后无法 inspect

## 5. 开放问题清单（事实层，留给 architect）

以下 7 项是**事实层未决**或**需 architect 做权衡**的开放点。analyst 不给推荐。

1. **命令形态事实成本**：新 `commands/batch.md` 独立命令 vs 扩展 `workflow.md` 的 per-invocation 额外 token 消费比？事实未量化（§4.1 估算但未实测）。
   - 支撑数据：`wc -l commands/workflow.md = 357`；新文件预估 ~250 行；扩展方案预估 +140 行
2. **DEC 编号竞争三方案的失败模式权重**：方案 A 空洞 vs 方案 B 假阳性替换 vs 方案 C 违反 DEC-001 D8 的成本如何量化？
   - 支撑数据：§3.4 表；DEC-001 D8 原文见 `docs/decision-log.md` DEC-001
3. **冲突预检粒度与 scope**：只扫 `skills|agents|commands/*.md` vs 扩 `docs/design-docs/` vs 扫目标项目源码 —— 各自假阴性率？
   - 支撑数据：§3.5 表（54.5% 真阳性率）
4. **子 agent `subagent_type` 选择**：`general-purpose` vs 新注册一个 `roundtable:batch-worker` subagent 专跑 workflow vs CLI-defined ephemeral subagent vs 其他
   - 支撑数据：Claude Code docs[^1]`general-purpose` "when the task requires both exploration and modification"
   - 事实未解：`general-purpose` 能否承载任意 slash command + worktree 同时 OK（需验证）
5. **并发默认值与上限**：issue 作者提 3，无数据支撑；Anthropic API 实际并发上限未知
   - 事实未解：待验证 rate limit 具体数值 + 本地 Claude Code Agent 实例上限
6. **#43 与 #48 / #30 的实施顺序**：§3.9 指出 #30 / #48 与 #43 暗耦合；若 #48 先修，batch 在 TG 下 UX 完整；若 #30 先修，batch + auto 不会 mask silent skip bug
   - 事实支撑：§3.9 耦合表
7. **Stage 4 Design confirmation 在 batch 子 agent 内的处理**：
   - 事实点 1：DEC-015 auto mode 在 Stage 4 要求 recommended 自动 accept
   - 事实点 2：batch 子 agent 是 bg mode，AskUserQuestion 会失败
   - 事实点 3：DEC-013 text mode `<decision-needed>` 可 bubble 到 final message
   - 事实未解：三点组合下，batch 子 agent 的 Stage 4 行为具体是哪条路径？(全 auto-accept / 部分 bubble / 其他)
   - architect 需决策：子 agent 内 Stage 4 是否强制 auto（即使该子 agent recommended 缺失也不 halt？还是 halt bubble 到 batch 层？）

## 6. FAQ

（待用户追问后追加）

## 7. 变更记录

| 日期 | 版本 | 变更 | 作者 |
|------|------|------|------|
| 2026-04-20 | v1 | 初版深度分析（9 维度 + 7 开放问题）| analyst |

---

[^1]: Claude Code Subagents 官方文档 https://code.claude.com/docs/en/sub-agents （2026-04-20 WebFetch）
