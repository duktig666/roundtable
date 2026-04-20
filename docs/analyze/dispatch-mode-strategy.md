---
slug: dispatch-mode-strategy
source: 原创（issue #19）
created: 2026-04-20
---

# 前台/后台派发选择策略 调研报告

## 背景与目标

**背景**：DEC-008（issue #15）引入 Step 3.5.0 gate —— `run_in_background: true` 才启 Monitor，前台派发 skip。但**上游决策缺失**：orchestrator 如何选择 `run_in_background` 的值？

当前 `commands/workflow.md` / `commands/bugfix.md` 所有 Task 派发点**不声明**该参数、**不提供**选择规则。dogfood 观察到 developer subagent 派发同时可见 Monitor 通知 + 主会话缩进工具流 —— 说明 gate 判据与实际可见性在某些派发形态下不一致（或 orchestrator 将字段设为 `true` 但实际行为却像前台）。

**目标**：给 architect 提供事实层交接，覆盖当前实现分布、Claude Code Task 工具语义、3 个方向（规则补齐 / 删 Monitor 全前台 / 强制全后台）的各场景代价。

## 追问框架

### 失败模式

方案最可能失败的点：
- **选项 1（规则补齐）**：LLM 按决策树选 dispatch mode 的一致性在真实会话里漂移（同类任务一次选 fg、一次选 bg）。一旦 orchestrator 误判，即重现 issue #19 的"Monitor + 缩进流双份信号"或"后台派发失可见性"
- **选项 2（删 Monitor / 全前台）**：reviewer + tester + dba 并行场景被阉割成串行，wall time 翻 3×；长任务（80k token reviewer）缩进流刷屏淹没主会话
- **选项 3（全后台强制）**：前台已就绪的缩进可见性被主动丢弃；所有小任务都多付一次 Bash + jq + Monitor 启动开销；违反 Claude Code Task 工具"foreground is default"的心智

### 6 个月后评价

- **选项 1** 风险：决策树过度工程，被"什么任务该 bg"的解释性争论消耗后续 DEC
- **选项 2** 风险：回滚复杂（DEC-004/007/008 的代码和文档投入已落地，revert 需 Superseded 3 个 DEC + 改 5 个 agent prompt + 改 2 commands + 改 design-doc）
- **选项 3** 风险：与 DEC-008 的"前台免 Monitor"心智反向，6 个月后 maintainer 可能再发一个 issue 回到现状

### 按需 4 问：不适用

本调研是**内部 workflow orchestrator 派发策略重构**，非新功能 / 非面向用户产品。痛点 / journey / 最简方案 / 竞品对比已在 DEC-004（P1-P6 对比 6 路径）+ DEC-008（前台 gate 动机）+ issue #19 正文覆盖。

## 调研发现

### F1. workflow.md / bugfix.md 的 `run_in_background` 声明分布

扫 `commands/workflow.md` + `commands/bugfix.md`（共 414 + 108 行），`run_in_background` 关键词**仅出现在 DEC-008 gate 条件描述里**，**无任何派发点显式声明**：

| 文件 | 行 | 上下文 |
|------|---|--------|
| `commands/workflow.md` | 92 / 98 / 99 | Step 3.5 gate 说明（"`true` → 进入 §3.5.1`；缺省 / `false` → skip"） |
| `commands/bugfix.md` | 24 | Step 0.5 gate 说明（"仅 `run_in_background: true` 且 env 未 opt-out 触发"） |

**派发点状态**：
- workflow.md 中 Task 派发通过 Step 3 artifact chain 描述（L67-86）与 Step 6b developer form（L207-224）间接触发，**无显式 `Task(run_in_background: ...)` 示例**
- bugfix.md 中 派发契约 Step 3 L62-67 列 4 个注入变量，**同样无 `run_in_background` 项**

结论：**orchestrator 派发时的 `run_in_background` 值完全由 LLM 自由决定，无 prompt 层约束**。这是 issue #19 的直接根因。

### F2. 5 agent prompt 的 dispatch hint 扫描

`agents/developer.md` / `agents/tester.md` / `agents/reviewer.md` / `agents/dba.md` / `agents/research.md` —— grep `run_in_background|前台|后台|foreground|background` **0 命中**（过滤 DEC-008 gate 相关则降到 0）。agent 本体不感知派发形态（符合 DEC-008 设计 ——"agent 不知派发形态，orchestrator 层 gate 是唯一可执行点"，见 DEC-008 理由 (1)）。

### F3. DEC-004 原始 assumption vs DEC-008 patch

- **DEC-004 决定 6 原文**（`docs/decision-log.md` L210）："所有 subagent dispatch 默认开启（不做 critical_modules 二级过滤）；用户可设 `ROUNDTABLE_PROGRESS_DISABLE=1` 关掉"
- **隐含 assumption**（design-doc §3.8 L266 明言）：所有 Task 派发都是**后台派发**（`run_in_background: true`），主会话对 subagent 内部不可见
- **DEC-008 patch**：触发条件从"所有 Task" 收紧为 "`run_in_background: true` 的 Task"。gate 前移解决"前台派发双份信号"问题 —— **但并未规定派发本身应选哪个 mode**

### F4. Claude Code Task 工具的文档语义

源：`Task` 工具 description（Claude Code 官方）。关键条款：

> **Foreground vs background**: Use foreground (default) when you need the agent's results before you can proceed — e.g., research agents whose findings inform your next steps. Use background when you have genuinely independent work to do in parallel.

> When an agent runs in the background, you will be automatically notified when it completes — do NOT sleep, poll, or proactively check on its progress. Continue with other work or respond to the user instead.

**官方默认 = foreground**。官方 background 使用场景 = "genuinely independent work in parallel"。

### F5. 前台派发的 dogfood 观察（3 来源交叉验证）

1. **design-doc §3.8 L270**：前台 Task 子 agent 的 Bash/Read/Edit/Write 工具调用以**缩进形式实时显示**在主会话输出里
2. **用户 memory `feedback_foreground_agent_no_monitor`**：前台 Task 子 agent 缩进输出已实时显示，Monitor 仅 `run_in_background: true` 时需要
3. **本会话 issue #18 reviewer 派发实录**：前台 subagent 派发期间主会话阻塞等 Task 返回，无 Monitor 启动，final message 带完整 review summary 直接可读

**一致结论**：前台 Task = 主会话阻塞 + 子 agent 工具调用缩进流实时可见 + Task 返回 final message。

### F6. 后台派发的能力与代价

来自 DEC-004 + design-doc §3.1-3.3：
- 不阻塞主会话 → 可在同一 assistant message 并行 issue N 个 Task
- subagent 内部**完全不可见** → Monitor 是唯一 phase 级进度通道
- 需 Bash（生成 `progress_path`）+ Monitor（`tail -F | jq | awk`）+ 4 变量注入 —— 每派发 ~6 次工具调用 overhead
- progress schema + agent prompt `## Progress Reporting` section（每 agent ~20 行）+ Content Policy helper（DEC-007）

## 对比分析（3 选项的事实层）

### 选项 1：补齐规则（保留 DEC-004/008 + 决策树）

**现有基建**（零改动）：Step 3.5 完整，Monitor + jq + Content Policy helper 全在

**需改造**：
- `commands/workflow.md` / `commands/bugfix.md` 新增"`run_in_background` 选择规则"章节
- 可选：5 agent prompt 各声明"本角色默认派发 mode"（critical_modules 命中 4/5，改动面大）

**不改**：DEC-004/007/008，design-doc，helper

**已有规则候选**（D1-D4 见下 §判据候选评估）

### 选项 2：默认全前台 + 删 Monitor

**现有基建**：前台派发的缩进工具流已天然可见（F5）

**需改造**：
- **删**：`commands/workflow.md` Step 3.5（全节 ~65 行）、Step 4 并行派发判定树可能需降级（并行失效）
- **删**：5 agent prompt `## Progress Reporting` section（估 5 × 20 = 100 行）
- **删**：`skills/_progress-content-policy.md`（DEC-007 产出）
- **Supersede**：DEC-004（全量）、DEC-007（全量）、DEC-008（自然过时）
- **改**：`docs/design-docs/subagent-progress-and-execution-model.md` §3.1-3.8（约 180 行）
- **改**：`docs/decision-log.md` 3 条 Superseded 标注

**能力代价**：
- **并行派发**：Step 4 判定树的 4 条件前台场景下无意义（前台阻塞 → 无法并行）。reviewer + tester + dba 串行，wall time 翻 3×
- **长任务 UX**：reviewer 扫全仓（80k token、3-10 min）或 tester 跑 17 suites，缩进工具流可能数百行淹没主会话
- **subagent context 隔离**：保留（Task 本质是 subagent，不依赖 mode），但主会话消费的 tool-stream token 增加

**代价量级**：DEC-004/007/008 实施投入合计约 600+ 行代码 + 文档；revert 工作量 ≈ 1 个 architect + developer + tester + reviewer 轮次

### 选项 3：默认全后台 + Monitor 强制

**现有基建**：DEC-004 全链路无改动

**需改造**：
- `commands/workflow.md` Step 3.5.0 gate **删除**（不再条件触发）
- `commands/bugfix.md` Step 0.5 gate 删除
- `docs/design-docs/subagent-progress-and-execution-model.md` §3.8 **Superseded**
- **Supersede**：DEC-008（全量 revert）
- **保留**：DEC-004/007

**能力代价**：
- 前台派发的缩进流可见性**主动丢弃**（Monitor summary 是 phase 级，比 tool 级信息密度低）
- 所有小任务（bugfix 单 developer 派发）多付 Bash + Monitor 启动开销（~6 次工具调用）
- 违反 Claude Code Task 工具 "foreground is default" 官方心智 —— plugin 层覆盖原厂默认

### 选项间共有事实

- 3 选项**都不影响** subagent context 隔离能力（Task 本质，与 mode 无关）
- 3 选项**都不改** agent Resource Access / Escalation Protocol / AskUserQuestion Option Schema
- 3 选项**都在** critical_modules hit 范围（改 commands prompt 本体 / Phase Matrix / Progress schema 之一）

## 场景评估（对 3 选项同权）

### S1. 小任务（bugfix hotfix / doc 补丁 / < 20k token / < 2min，单派发）

- **选项 1 决策树**：若判据命中 fg → 等同现状前台；若漏判为 bg → 重现 issue #19 双份信号
- **选项 2 全前台**：天然合适
- **选项 3 全后台**：多付 Monitor 启动开销，收益 = phase 级 summary 替代缩进流

### S2. 单长任务（reviewer 80k token 扫全仓 / tester 17 suites，单派发）

- **选项 1**：若判据引入"按预估耗时" → bg，Monitor 给干净 summary
- **选项 2**：缩进流可能数百行淹没主会话（但用户记忆 `feedback_foreground_agent_no_monitor` 表明当前 dogfood 可接受）
- **选项 3**：等同现状 bg

### S3. 并行多角色（reviewer + tester + dba 同期，估 20-30 min wall time）

- **选项 1**：若判据引入"并行批 → bg" → 等同现状
- **选项 2**：**不可行** —— 前台阻塞 → 无并行；wall time 翻 3×
- **选项 3**：等同现状 bg

### S4. developer subagent 形态（已由 DEC-005 支持 inline 逃生门）

- 3 选项**对 developer 影响最小** —— inline path 不走 Task，不进入 mode 讨论
- subagent path 命中规则：选项 1 看判据、选项 2 → fg、选项 3 → bg

### S5. bugfix 流程（fan-out 窄，单 developer + 可选 reviewer/dba/tester 两阶段）

- 3 选项都可串行，**没有并行刚需**
- bugfix.md Step 3 已提"偏向 inline"（DEC-005 边界），subagent path 同 S1/S2

## 判据候选评估（仅选项 1 需要）

维度：按角色 / 按并行度 / 按预估耗时 / 按用户显式偏好。表格陈述可执行性（fact），不打分：

| 判据 | 决策颗粒 | 可执行性（fact） | 客观代价 / 排除项 |
|------|---------|-----------------|-------------------|
| **D1 按角色** | 每角色一个默认值（e.g. reviewer/tester/dba/research → bg；developer subagent → bg；fg = exceptional） | agent prompt 或 commands table 硬编码；LLM 查表不判断 | 灵活性低，S1 场景的小 reviewer 也走 bg；critical_modules 命中 5 agent，改动面大 |
| **D2 按并行度** | 并行批（≥2 Task 同 message）→ bg；单派发 → fg | orchestrator 在 issue Task 前已知是否并行，判据确定 | 单派发长任务（S2）错判成 fg，缩进流刷屏；需与 D1/D3 组合 |
| **D3 按预估耗时** | LLM 估算 wall-time，> 2min → bg | 需 orchestrator 对子任务耗时有先验（e.g. "reviewer 扫全仓 > 2min" → bg），易漂移 | LLM 估算漂移；跨角色难校准；PR #19 issue 正文的 6 分钟 developer subagent 实录是典型反例 |
| **D4 按用户显式偏好** | 三级：per-session `@roundtable:tester bg`/`fg` → per-project CLAUDE.md `dispatch_mode_default: fg / bg` → per-dispatch AskUserQuestion | 复用 DEC-005 三级切换心智，orchestrator 已熟悉 | 每次派发可能有 AskUserQuestion 干扰；per-project key 与 `developer_form_default` 语义重叠 |

**组合候选**：
- **D1+D2 组合**：并行批 → bg（覆盖 S3）；单派发 → 查 D1 角色默认（覆盖 S1/S2）—— 规则扁平，零用户干预
- **D1+D4 组合**：D1 作 baseline，D4 per-session 覆盖（覆盖 S1/S2 + 用户逃生门）
- **D2 only**：单派发无差别 fg（含 S2 长任务），并行 → bg —— 最简，但 S2 UX 差

## 开放问题清单（事实层）

- **P1. 选项 2 的"删 Monitor"对并行派发（S3）代价是否可接受？**（事实：当前 Step 4 判定树只在后台派发下有意义；前台无法并行；user memory 未表态对并行刚需的偏好）——`commands/workflow.md` L146-157 Step 4，`docs/decision-log.md` DEC-002
- **P2. 选项 3 的"全后台强制"违反 Claude Code `Task` 工具官方默认（fg）的心智**：plugin 层是否应覆盖宿主默认？——`Task` 工具 description "Foreground is default"
- **P3. 选项 1 判据组合选择（D1+D2 vs D1+D4 vs D2 only vs 其他）**：取决于用户对"orchestrator 决策确定性 vs 用户干预频率"的偏好——本 analyst 调研范围不给推荐
- **P4. per-role 默认值（若选 D1）是否需要进入 target CLAUDE.md 业务规则层？**（事实：DEC-001 D2 "零 userConfig"边界；DEC-005 已开 `developer_form_default` 先例；但 plugin 元协议与业务规则边界在 DEC-005 FAQ Q2 有论证）——`docs/claude-md-template.md:62-70`，`docs/decision-log.md` DEC-005
- **P5. DEC-008 要不要 Supersede？**（事实：选项 2 → DEC-008 自然过时；选项 3 → 显式 revert；选项 1 → DEC-008 保留不变）——与 P3 耦合
- **P6. 若选项 2，Step 4 并行派发判定树的命运**：删除（前台无并行语义）/ 保留作架构锚点 / 改写成"何时升级为后台并行"—— `commands/workflow.md` L146-157
- **P7. DEC-005 已为 developer 开 inline 逃生门；reviewer / tester / dba 是否也该有同样的 per-dispatch 决策点（issue #20 的核心）？**（事实：issue #20 与 #19 耦合 —— 若 #19 选方向 2，#20 的 inline 讨论范围缩小到 "全前台 subagent 的缩进流刷屏缓解"；若 #19 选方向 1/3，#20 独立决策）
- **P8. dogfood 记录里"developer subagent 派发同时可见 Monitor + 缩进流"到底是哪个配置的 bug？**（issue #19 "深层问题"提出但本调研未能复现；事实：`commands/workflow.md` Step 3.5.0 gate 若正确执行则不会双份信号；疑为 orchestrator 误把 `run_in_background: true` 设在应 fg 的派发上）——需 architect 拍板是否先修这个特定 bug 再做结构性决策

## FAQ

### Q1: orchestrator 是什么？和 #19 的 `run_in_background` 选择是谁的决策？

Orchestrator = 执行 `/roundtable:workflow` / `/roundtable:bugfix` 的**主会话 Claude**（不是独立进程或 agent，是主会话本身跑 `commands/workflow.md` 的编排逻辑）。

**职责**：只做编排，不做实质设计/编码/审查（`commands/workflow.md` L306）。具体包括 Step 0 context、Step 1 规模判定、Phase Matrix 维护、pipeline 激活、Step 3.5 Monitor setup、Step 5 Escalation relay、Step 6 phase gating（A/B/C）、Step 7 INDEX 维护、Step 8 log.md flush。

**对 3 类角色的派发机制**：

| 角色形态 | 派发方式 | 执行位置 |
|---------|---------|---------|
| skill（analyst / architect） | `Skill` 工具 | 主会话（共享 context） |
| subagent（tester / reviewer / dba / research） | `Task` 工具 | 独立 subagent context |
| inline developer（DEC-005） | `Read agents/developer.md` + 主会话照做 | 主会话 |

**关键特权**（角色没有的权限）：
- 唯一 Writer：`docs/INDEX.md` / `docs/log.md` / exec-plan checkbox（DEC-002 shared-resource 转发避免 race）
- 唯一 `AskUserQuestion` relayer（subagent `<escalation>` block 必须过 orchestrator）
- 唯一 git 执行者（且仅用户显式要求）

**与 #19 的关系**：DEC-004 / DEC-008 争议的 "`run_in_background` 如何选" 就是 orchestrator 在 issue `Task` 工具调用前的 LLM 级决策 —— 当前 `commands/workflow.md` 无规则约束，orchestrator 靠自由心证。issue #19 本质是"给 orchestrator 补一条派发模式选择的 prompt 层约束"，让 LLM 决策有可预测边界。

## 变更记录

- 2026-04-20：初稿（issue #19）
