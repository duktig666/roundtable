# roundtable 决策日志

> 记录 roundtable 项目所有关键设计和技术决策。
> 新条目追加在顶部（最新在前）。
> 本文件是项目知识的权威来源。

## 条目格式

```markdown
### DEC-[编号] [标题]
- **日期**: YYYY-MM-DD
- **状态**: Proposed | Accepted | Superseded by DEC-xxx | Rejected
- **上下文**: 为什么需要做这个决策
- **决定**: 最终选择
- **备选**: 考虑过但未采用的方案
- **理由**: 为什么这么选（关键权衡）
- **相关文档**: design-docs/xxx.md 等
- **影响范围**: 哪些部分受影响
```

## 状态说明

| 状态 | 含义 |
|------|------|
| Proposed | 已提出，待确认 |
| Accepted | 已确认采纳，正在执行或已落地 |
| Superseded by DEC-xxx | 被新决策取代（保留原文不删，标注取代者） |
| Rejected | 讨论后否决 |

## 铁律

1. **不删除旧条目**：被取代的条目标记为 Superseded，不删除
2. **冲突报 diff**：新决策与旧决策冲突时，必须在新条目中引用旧条目编号
3. **编号递增**：DEC 编号只增不减，不复用

---

### DEC-005 developer 双形态（inline | subagent）正交补强 DEC-001 D8
- **日期**: 2026-04-19
- **状态**: Accepted
- **上下文**: issue #7 问题 B —— P4 dogfood 实录证实 developer 在小任务（单文件改 / bug 热修）场景下用 subagent 形态让用户失去掌控感；但 tester/reviewer/dba 的大 context 对抗/审查任务 inline 执行会爆主会话。DEC-001 D8 "role→form 单射" 在 developer 这一行产生张力
- **决定**:
  1. **developer 支持双形态**：`inline`（主会话内联执行 `agents/developer.md`，AskUserQuestion 直接可用）和 `subagent`（DEC-001 D8 原默认，Task 派发 + Escalation）
  2. **默认仍 subagent**：保持 D8 原映射为默认；inline 是非默认可选档
  3. **tester / reviewer / dba 不扩展**：仍仅 subagent（大 context 无例外）
  4. **切换触发三级**：
     - per-session：用户 prompt 里声明 `@roundtable:developer inline`
     - per-project：target CLAUDE.md `# 多角色工作流配置` 可选 `developer_form_default: inline`
     - per-dispatch：`/roundtable:workflow` 在 developer 阶段前 AskUserQuestion，小任务标志触发 inline=recommended
  5. **正交补强 DEC-001 D8**（不 Superseded D8）—— D8 的 role→form 基础映射继续有效；本 DEC 新增规则："developer 角色除 subagent 外另支持 inline；其他三角色 D8 边界不变"。与 DEC-003 对 D8 的处理模式一致
  6. **能力差异表**：在 design-doc §3.4.3 明示 AskUserQuestion / Escalation / 并行派发 / context 污染等维度在双形态下的行为差异
  7. **Resource Access 保持不变**：无论 inline / subagent，developer 读写范围（src/* + tests/* + exec-plan checkbox 报告）完全一致；仅交互通道不同
- **备选**:
  - **全四角色双形态**（developer/tester/reviewer/dba 都支持 inline）：维护成本 4×；reviewer / tester inline 实测易撑爆主会话（80k+ /dispatch），拒绝
  - **auto 档**（按任务规模自动选）：触发规则解释成本高；analyst §失败模式证实 6 个月后易成摆设，拒绝
  - **Supersede DEC-001 D8**（全量重写角色形态分配）：改动远大于实际语义变化（tester/reviewer/dba 三行并无实质变化）；与 DEC-003 "保留 D8" 的和谐模式不一致，拒绝
  - **Partial Supersede D8**（仅 developer 那一行状态改 "Partially Superseded by DEC-005"）：需引入"Partially Superseded"状态机，decision-log 铁律复杂化，拒绝
- **理由**: (1) developer 是 P4 实录里 dispatch 次数最多的角色（4/9 次），小任务场景最频繁，UX 收益最高；(2) 保持 tester/reviewer/dba subagent 纪律规避 1M context 风险；(3) 正交补强而非 Supersede 保证 D8 原文不改、decision-log 单调递增；(4) 三级切换触发覆盖 per-session/project/dispatch 的决策层次；(5) 能力差异表让用户在 AskUserQuestion 弹窗里能理解 inline/subagent 的实际代价
- **相关文档**: docs/design-docs/subagent-progress-and-execution-model.md（D2 双形态设计 + §3.4）、本条 + DEC-001 D8 共同定义 developer 形态语义、DEC-004（协同的 progress protocol，subagent 档才启用）
- **影响范围**: `agents/developer.md`（新增 §Execution Form 双形态声明）；`commands/workflow.md`（Step 6 增加 developer 形态切换判定 + inline 执行路径）；`commands/bugfix.md`（同上，bugfix 流程也要识别 inline）；`docs/claude-md-template.md`（§多角色工作流配置 增加可选 `developer_form_default` 示例）；`docs/decision-log.md` 本条；`docs/log.md` 新增 `decide | DEC-005` 条目。运行时行为：小任务 / bug 热修用户可一键切 inline 全程可见；默认行为零变化

### DEC-004 subagent progress event protocol（P1 push 模型）
- **日期**: 2026-04-19
- **状态**: Accepted
- **上下文**: issue #7 问题 A —— P4 dogfood 实录证实 subagent 长任务（3-10+ 分钟）期间主会话无反馈，用户失去对流程的掌控感。Claude Code 原生 `/agents` Running tab、transcript JSONL、Ctrl+B 提供**用户侧**观察通道，但 orchestrator LLM 对 subagent 内部**系统性**不可见（官方 "intermediate tool calls … only its final message returns to the parent"）
- **决定**:
  1. **push 模型**（非 pull）：subagent 在 phase 边界主动 append JSON event 到共享文件；orchestrator `Monitor` tail。对比 pull 模型（周期 Read transcript）的关键收益：事件驱动（无空 poll）、官方架构对齐（Claude Code Agent 工具 description 明确建议"do NOT poll"）、与 DEC-002 Escalation JSON 同一范式
  2. **事件颗粒度**：phase checkpoint 级（exec-plan P0.n 维度），3 种 event 类型 `phase_start` / `phase_complete` / `phase_blocked`；一次 dispatch 预期 3-10 条 event
  3. **JSON schema**：单行 JSONL，必选字段 `ts` / `role` / `dispatch_id` / `slug` / `phase` / `event` / `summary`（≤120 char 一句话），可选 `detail`（files_changed / tests_passed 等）
  4. **发射机制**：subagent prompt 本体新增 `## Progress Reporting` section 约定 `Bash echo '{json}' >> {{progress_path}}`；不用 PostToolUse hook（plugin 跨平台分发脚本复杂 + 颗粒度不匹配）
  5. **监听机制**：orchestrator 在 Task 派发前 Bash 生成 `dispatch_id` + `progress_path = /tmp/roundtable-progress/{session_id}-{dispatch_id}.jsonl` + 启动 `Monitor "tail -F ${PATH} | jq --unbuffered -c ..."`；Task 完成后 Monitor 自然结束
  6. **触发规则**：所有 subagent dispatch 默认开启（不做 critical_modules 二级过滤）；用户可设 `ROUNDTABLE_PROGRESS_DISABLE=1` 关掉
  7. **协议层级**：plugin 元协议（与 DEC-002 Escalation 同层）；不入 target CLAUDE.md（保持 DEC-001 D2 "零 userConfig" 边界）
  8. **与 DEC-002 / DEC-003 正交**：progress 用临时文件路径；escalation 用 Task final message；research-result 用 research agent final message。三通道独立、不相互触发
  9. **漏发降级**：subagent 漏 emit 时降级为"静默"（= 当前现状），不恶化
- **备选**:
  - **P6 orchestrator pull**（零改 subagent，周期 Read transcript）：违反官方"do NOT poll"倾向；5 分钟 cache TTL 让周期 ≥5 分钟时每轮 cache miss；token 成本倍增；拒绝
  - **P3 banner only**（启动时 echo 观察通道提示，不 relay）：用户需手动切 `/agents` 视图，不满足 "实时感知流程位置" 的 user north-star；拒绝
  - **P4 heartbeat text tag**（subagent prompt 约定打 `<heartbeat>` tag）：LLM 生成文本 tag 颗粒度不稳定（易漏打、格式漂移）；结构化 JSON 更可靠；拒绝
  - **P5 独立 reporter agent**：引入新 agent 形态与 DEC-003 research 角色形态重复；2× subagent 并行开销；拒绝
  - **每工具调用颗粒度**：单 dispatch 20-50 event 密度过高；主会话 notification 风暴；拒绝
  - **CLAUDE.md 声明 schema**：违反 DEC-001 D2 "CLAUDE.md 只放业务规则" 边界；plugin 元协议与业务规则混杂；拒绝
  - **PostToolUse hook 自动 emit**：hook 脚本 plugin 跨平台分发复杂（shebang / 权限位）；hook 每 tool call 触发颗粒度不对；拒绝
- **理由**: (1) 事件驱动 push 比 pull 高效且对齐官方架构；(2) phase checkpoint 颗粒度与 DEC-002 exec-plan P0.n 结构天然对齐；(3) plugin 元协议定位让用户 CLAUDE.md 零改动；(4) JSON schema 结构化与 DEC-002 Escalation 范式一致；(5) 漏发降级兜底保证不变更糟；(6) `/tmp` 临时文件路径简化生命周期管理（不用 gc）
- **相关文档**: docs/design-docs/subagent-progress-and-execution-model.md（设计主文档 §3.1-3.7）、DEC-005（developer 双形态；inline 档不 emit progress，只 subagent 档 emit）、DEC-002（Escalation 同层协议）
- **影响范围**: `agents/developer.md` / `agents/tester.md` / `agents/reviewer.md` / `agents/dba.md` / `agents/research.md` 均新增 `## Progress Reporting` section；`commands/workflow.md` / `commands/bugfix.md` 新增 Task 派发前的 Monitor 启动模板；`docs/design-docs/subagent-progress-and-execution-model.md`（新建）；`docs/exec-plans/active/subagent-progress-and-execution-model-plan.md`（新建）；`docs/decision-log.md` 本条；`docs/INDEX.md` 新增 design-docs / exec-plans 引用；`docs/log.md` 新增 `design | subagent-progress-and-execution-model` + `decide | DEC-004` 条目。运行时行为：所有 subagent dispatch 自动带 progress 可见性；用户可 env var 关掉

---

### DEC-003 architect skill → parallel research subagent dispatch 能力
- **日期**: 2026-04-19
- **状态**: Accepted
- **上下文**: P4 自消耗（gleanforge dogfood，2026-04-18）§3 friction #8 —— architect 决策 3+ 备选方案时 `WebFetch` 串行，慢 + 主会话 context 被累积 fetch 撑爆 + 或被迫 truncate 研究广度。DEC-002 将此列为 deferred，留 [issue #2](https://github.com/duktig666/roundtable/issues/2) 追踪。本轮（2026-04-19）完成调研（`docs/analyze/parallel-research.md` 对标 CrewAI / LangGraph / Claude Code sub-agents）+ architect 决策 7 条。
- **决定**:
  1. **新增 `agents/research.md`**（独立 role）—— 短生命周期 research worker，architect dispatches via `Task`，**不由用户触发**（description 明写 "NOT user-triggered")
  2. **正交补充 DEC-001 D8**（不 Superseded D8）—— D8 的 role→form 单射继续有效；DEC-003 新增规则："skill（限 architect）可向特定 agent（限 research）派 `Task`，仅限短生命周期 fact-level 调研"
  3. **Tool set**：`Read`, `Grep`, `Glob`, `WebFetch`, `WebSearch`（**禁** `Bash` / `Write` / `Edit` / git / `AskUserQuestion`）
  4. **扇出硬上限**：每次 architect 决策 ≤ 4 个并行 research subagent；5+ 候选先用 `AskUserQuestion` 粗筛
  5. **返回 schema**：结构化 `<research-result>` JSON block，字段 `option_label` / `scope` / `key_facts[{fact, source}]` / `tradeoffs[]` / `unknowns[]` / `recommend_for: null` —— `recommend_for` 硬导 `null`，执行"research 不做推荐"纪律
  6. **Scope 模糊处理**：`<research-abort>` feedback，architect 修正 scope 重派最多 1 轮；不新增 escalation type，避免 reentrant（research → orchestrator → architect skill 是 orchestrator 的 skill）
  7. **1/N 失败处理**：partial success 可接受；失败 option 在 architect 合成后的 `AskUserQuestion` 里标 ☠️，用户可选排除或接受不完整信息拍板
- **备选**:
  - **analyst dual-mode（skill + subagent）**：破坏 D8 的 role→form 单射；一个 role 文件两套 Resource Access 难维护；auto-delegation description 歧义
  - **架构师 inline Task 模板（零新文件）**：每次派发 architect 要重述 tool set + schema；prompt 模板复制易漂移；无独立 role 审计
  - **新增 `scope-clarification` escalation type**：增加路由复杂度；scope 决策本属 architect，不应经用户；与 abort-re-dispatch 比无实质收益
  - **Strict all-or-nothing 失败处理**：token 浪费 4×（全重派）；上游持续故障（如某源 persistent down）导致雪球阻塞
  - **扇出上限 ≤ 6 或无上限**：5+ 候选往往是决策粒度过粗的信号；与 `AskUserQuestion` 的 `maxItems: 4` 不对齐
  - **返回 prose 而非 JSON**：N 份 prose 合成需 architect 文本解析，易丢事实；与 DEC-002 已确立的 `<escalation>` JSON 范式不一致
- **理由**: (1) 独立 agent 保持 D8 的 role→form 单射；(2) 结构化 JSON schema 让 N 份调研合成可确定性映射到 AskUserQuestion 字段（复用 DEC-002 的 agent→orchestrator JSON 交互范式）；(3) 扇出 ≤ 4 与 AskUserQuestion maxItems 对齐，逼迫 architect 先粗筛而非粗放扇出；(4) partial success 务实 —— 用户最终拍板能力 > 完整性要求；(5) abort 而非 escalation 避免 "research → orchestrator → architect skill" 的 reentrant；(6) `recommend_for: null` 硬导执行 "research 事实层、architect 决策层" 的纪律分离
- **相关文档**: [docs/analyze/parallel-research.md](analyze/parallel-research.md)（对标调研 + 12 事实层开放问题）、[docs/design-docs/parallel-research.md](design-docs/parallel-research.md)（完整设计含流程 / schema / 并行安全论证）、`skills/architect.md` §阶段 1.5 "Research Fan-out"（触发 / 派发 / 合成 / 失败处理规则）、`agents/research.md`（新 role 完整定义 + Return Schema + Abort Criteria）、[issue #2](https://github.com/duktig666/roundtable/issues/2)
- **影响范围**: 新增 `agents/research.md` 文件；`skills/architect.md` §阶段 1 加入 3.5 子步骤；`docs/decision-log.md` 本条目；`docs/INDEX.md` 新增 `### agents` subsection + 引用 research.md；`docs/log.md` 新增 `design | parallel-research` 条目。运行时行为变化：architect 在决策候选 ≥ 2 且需外部研究时可选择并行 research，显著减少主会话 token 占用和决策时间。与 DEC-001 D8 正交；与 DEC-002 共享 JSON 交互范式（`<escalation>` ↔ `<research-result>` / `<research-abort>`）无冲突。

---

### DEC-002 基于 P4 自消耗反馈的三项增量改进（shared resource protocol / escalation / workflow matrix）
- **日期**: 2026-04-19
- **状态**: Accepted
- **上下文**: P4 自消耗闭环在 gleanforge 项目完成（见 `docs/testing/p4-self-consumption.md`），识别出三类主要摩擦 —— (a) 共享资源协议隐式（exec-plan checkbox / log.md / decision-log / testing 写权限靠 orchestrator 逐次 prompt 注入，并行派发时易 race）；(b) subagent 通信封闭性（tester / developer 遇到用户决策点只能文字建议，orchestrator 手动 relay 成 AskUserQuestion）；(c) workflow command 缺少阶段可视化（orchestrator 状态靠对话追踪，用户难以判断当前位置）。同时副带两个已知 plugin 层 bug：prompt 文件中英混杂（违反自家「跨阶段约束：prompt 英文为主」）、AskUserQuestion 弹窗给裸选项（用户难决策）
- **决定**:
  1. **每个 role 文件加 Resource Access 矩阵**（`Read` / `Write` / `Report to orchestrator` / `Forbidden`）—— 权限声明从隐式 prompt 注入升级为 role prompt 本体的一等公民 section，对 7 个 role 文件生效（3 skills + 4 agents）
  2. **agent 层加 Escalation Protocol + skill 层加 AskUserQuestion Option Schema**：
     - agents (developer / tester / reviewer / dba) 在最终报告追加结构化 `<escalation>` JSON 块（`type` / `question` / `context` / `options[label, rationale, tradeoff, recommended]` / `remaining_work`），orchestrator 自动解析并转 `AskUserQuestion` 再派发
     - skills (architect / analyst) 强制 `AskUserQuestion` 每个 option 必含 `label` / `rationale` / `tradeoff` / `recommended`（analyst 禁 `recommended`，保持事实层；architect 最多 1 个标 `recommended`）
  3. **commands/workflow.md 重写为阶段矩阵编排器**：
     - 引入 Phase Matrix（8 阶段 × `⏳ / 🔄 / ✅ / ⏩` 状态 × artifacts 列），每次阶段转场向用户汇报并更新
     - 新增 Step 4 并行派发判定树（4 条硬条件：PREREQ MET / PATH DISJOINT / SUCCESS-SIGNAL INDEPENDENT / RESOURCE SAFE；默认串行，满足四条且加速 >30% 才并行）
     - exec-plan checkbox 写入由 orchestrator **串行化**（即使并行派发 developer，orchestrator 代写 checkbox 避免 race）
     - 跨角色转场（developer → tester 等）必须用户确认；同角色顺承（P0.4 → P0.5）在无 Critical 发现时可自动推进
  4. **`_detect-project-context` 切换为"Read 内联执行"**：不再用 `Skill` 工具激活（下划线前缀 skill 在部分 Claude Code 版本激活失败），改为调用方 `Read` 该 markdown 文件后按 4 步内联执行；5 个调用方（workflow / bugfix / lint / architect / analyst）同步改
  5. **prompt 文件本体统一英文**：workflow.md / bugfix.md / lint.md 中英混杂的步骤描述改为英文，保留关键 domain 注释中文
  6. **版本号不 bump**：本轮累计为 alpha 迭代改进，`plugin.json` / `marketplace.json` 保持 `0.1.0-alpha.1`；CHANGELOG 走 `[Unreleased]` section
- **备选**:
  - **推翻双形态架构**（全 agent 或全 skill）：解决 subagent AskUserQuestion 禁用，但失去 architect 交互体验或污染主会话 context —— 见 DEC-001 已拒绝
  - **依赖 Claude Code 未来原生支持 Task 工具进度事件**：等待期内 P4 摩擦持续；本轮先做可控的增量
  - **每条改动各自独立 DEC（DEC-002/003/004/005）**：粒度过细，单轮改动语义 coherent，一条 DEC 足够
  - **仅改文档不改 prompt**：prompt 约束是 plugin 运行时行为的唯一载体，仅改文档不解决 race / relay 摩擦
  - **bump version 到 0.2.0-alpha.1**：本轮只增补结构化约束，无破坏性变更，不到 minor bump 门槛
- **理由**: (1) 报告已证实三条 top 都是增量演进，不推翻架构；(2) Resource Access 权限矩阵变隐式为显式，消除 per-dispatch prompt 负担；(3) Escalation + Option Schema 让"subagent 封闭 + AskUserQuestion 裸选项"两类摩擦在同一协议层解决；(4) Phase Matrix 让 orchestrator 状态对用户透明，配合并行判定树给出可证伪的加速决策；(5) inline _detect 是对 "Skill 激活失败" 的稳健规避，配合 session 记忆复用语义不变；(6) 不 bump 版本避免误导使用者以为 minor 行为变更
- **相关文档**: docs/testing/p4-self-consumption.md（详细观察报告）、docs/design-docs/roundtable.md（原设计），本次改动具体落点见 feature branch 的 commit 1 / 2 / 3（git log 查）
- **影响范围**: 所有 skill / agent / command prompt 文件（7 + 3 = 10 个），decision-log 本条目；运行时行为变化表现在并行策略更明确、escalation 不再 relay、phase 可视化、_detect 激活方式改变；现有测试 / 用户接入流程无破坏

---

### DEC-001 多角色 AI 工作流打包为 Claude Code plugin（roundtable）
- **日期**: 2026-04-17
- **状态**: Accepted
- **上下文**: 用 Claude Code 做中大型项目开发时，单一对话容易失控；已有的单 agent 模式不足以支撑纪律化流程。需要一套"多角色协同 + plan-then-execute + 交互式决策"的通用工作流，能适配不同技术栈的项目，业务规则由各项目自描述
- **决定**:
  1. **分发机制**：打包为 Claude Code plugin，仓库 `github.com/duktig666/roundtable`，Apache-2.0 许可；用户通过 `/plugin marketplace add duktig666/roundtable` + `/plugin install roundtable@roundtable --scope user` 一行命令全局安装
  2. **角色形态混合**（D8）：architect / analyst 为 **skill**（主会话运行，保留 AskUserQuestion 决策弹窗）；developer / tester / reviewer / dba 为 **agent**（subagent 隔离上下文避免主会话污染）；命令保持 command
  3. **配置模型 B-0 零 userConfig**（D2）：plugin.json **不含 userConfig 字段**，安装零弹窗；所有配置走两条通道 —— (a) 运行时自动检测（扫 target_project 根的 Cargo.toml / package.json 等识别 primary_lang / lint_cmd / test_cmd；扫 `docs/` 或 `documentation/` 识别 docs_root）；(b) 每个项目的 CLAUDE.md「# 多角色工作流配置」section 声明业务规则（critical_modules / 设计参考 / 触发规则 / 工具链覆盖）。CLAUDE.md 声明值覆盖自动检测
  4. **Scope = user**（D5）：plugin 装在 `~/.claude/plugins/`，一次装所有项目通用；不依赖 project scope 的 `.claude/settings.json`
  5. **目标项目识别（D9）**：适配"从 workspace 根目录启动 Claude Code"场景。Skill / Agent 启动时按优先级识别 target_project —— session 记忆 → `git rev-parse --show-toplevel` → 任务描述正则匹配 CWD 下含 `.git/` 的一级子目录 → AskUserQuestion 弹窗兜底。识别结果 session 内记忆，用户可显式切换
  6. **实施策略（D6）**：POC 增量 —— P1 先通用化 architect skill + /workflow command + D9 识别机制，P2 批量改剩余角色，P4 真实项目自消耗验证
  7. **文档归属（D1）**：roundtable/docs/design-docs/roundtable.md 为唯一权威设计文档
- **备选**:
  - 全 agent 形态（一致性好，但 AskUserQuestion 在 subagent 系统级禁用，失去 architect 核心交互体验）
  - 全 skill 形态（AskUserQuestion 可用，但 developer / tester 读写大量代码会撑爆主会话 context）
  - 多 userConfig 字段（如 docs_root / lint_cmd / test_cmd / primary_lang / critical_modules_hint / design_ref_hint）：多项目场景下单一值天然冲突；lint/test/lang 本可自动检测；hint 字段与 CLAUDE.md 重合。评估为过度设计
  - project scope 安装：workspace 根启动时根目录非 git，project scope 无落脚点
  - 强制从子项目启动 Claude Code：违背常见场景
  - plugin 内置 profile 系统（rust-backend / ts-frontend 等硬预设）：抽象过早，同语言不同项目 critical_modules 差异大
- **理由**: (1) 零 userConfig 是最优的"一行命令装上即用"体验；(2) CLAUDE.md 作为单一配置源，天然 per-project，git 版本控；(3) 运行时自动检测对工具链精准度够（读项目根文件比用户手填还准）；(4) D9 识别机制填补 workspace 根启动场景的空白；(5) skill / agent 混合在同一 plugin 无冲突（已核实官方文档）
- **相关文档**: docs/design-docs/roundtable.md（完整设计 + D1-D9 量化评分）、docs/exec-plans/active/roundtable-plan.md（P0-P6 实施路线）
- **影响范围**: 本项目全部 skill / agent / command 定义；项目 manifest（plugin.json）
