---
slug: orchestrator-compliance-gap
source: 原创（GitHub issue #111）
created: 2026-04-23
---

# Orchestrator Handoff Forwarding 合规缺口分析报告

> 对应 issue: duktig666/roundtable#111
> 调研范围：`commands/workflow.md` §Step 5b / §Step 6.1 / §Step 7 / §Step 8；`skills/analyst/SKILL.md` / `skills/architect/SKILL.md` / `agents/*.md` final message YAML 契约；2026-04-22 + 2026-04-23 两次 TG dogfood miss 现场
> 调研方法：本仓 git/文件现状量化 + CLAUDE Code 内部行为观察推论（非实机实验）+ `obra/superpowers` 参考项目事实对照
> 事实 vs 推论：全程区分；orchestrator 内部 tick / attention 层面观察均明示"推论、无一手实验数据"

## 背景与目标

### 背景

2026-04-23 session 跑 `/roundtable:workflow #110`（TG 驱动，active channel sticky）时出现协议违规：`Skill(roundtable:analyst)` 返回后 orchestrator 仅在终端打了自然语言 summary 假装"已完成"，未 fire `commands/workflow.md` §Step 5b 事件类 b/c（role completion digest + A 类 producer-pause 3 行 summary）转发 TG、未 emit A 类 producer-pause 菜单（`go / 问 / 调 / 停`）、未更新 Phase Matrix、未 pause。同类现象 2026-04-22 session 首次被 memory `feedback_tg_workflow_updates_to_tg` 捕获记录 —— 非首次。

### 目标

- 事实层确认 bug 复现路径（触发条件 / 应 fire 清单 / 实际观察）
- 列出 2 次 miss 的证据链以佐证"非首次"
- 拆耦 Finding 1（orchestrator 漏 forwarding）与 Finding 2（YAML 契约终端可见）的因果关系 —— 论证性讨论（无法实机做 A/B 实验）
- 针对 3 层 root cause hypothesis（density / enforcement / cognitive load）各列事实依据
- 列缓解方向 a/b/c/d 的可行性事实（不推荐、不打分）
- 为 architect 后续做 hypothesis × mitigation × DEC 产出开 design-docs 留事实基底

### 非目标

- 不做方案选型（a/b/c/d 采哪条 / 3 hypothesis 哪条是 dominant / 是否需改契约渠道）—— 归 architect
- 不改 `commands/workflow.md` / skill / agent prompt 本体
- 不做 workflow.md 系统性精简（属 rule density 层的独立 P2 umbrella，out of scope per issue body）
- 不加 runtime compliance lint harness（独立实施 issue）

## 追问框架（必答 2 + 按需 4）

### 必答 2

**Q1 失败模式：方案最可能在哪里失败？**

本调研"失败模式" ≠ mitigation 失败模式（后者归 architect），而是**调研本身可能误指根因**的模式：
- **Finding 1+2 因果推论的单样本风险**：当前仅 2 次直接观测（2026-04-22 + 2026-04-23），样本量不足以排除 LLM 运行时随机性（两次均发生在 Opus 4.7 / context 重载 / sticky TG / skill 返回场景，无多模型对照）。结论层面 Finding 2 是否真"加重"Finding 1 的 cognitive load 无法实证，本报告仅做论证性陈述
- **"非首次"证据链依赖 memory + 用户描述**：2026-04-22 原始会话 transcript 未归档；仅 memory file `feedback_tg_workflow_updates_to_tg` 的 Why 字段作二手引用。若 memory 描述漂移或回忆失真，"非首次"的"同类性"可能被高估或低估
- **superpowers 参考失准**：issue body 把 `<SUBAGENT-STOP>` 列为缓解方向 a 的设计参照；本报告调研发现该标记实为 **skill 自跳过** 用途（subagent context 下跳过 `using-superpowers` skill 本体），**非** orchestrator handoff signaling sentinel。原参照前提被证伪
- **3 hypothesis 可能并非"不互斥"而是共线**：report 将 density / enforcement / cognitive load 作 3 独立 layer 陈述，但若它们在实际 runtime 同方向叠加（rule density 高 → cognitive load 重 → 无 enforcement 兜底），则缓解 1 个等于缓解 3 个，"不互斥"可能为 framing error

**Q2 6 个月后评价：回头看会不会变成债务？**

- **不修或仅文档化**：bug pattern "skill 返回后 orchestrator attention 漂向 YAML → 漏 forwarding"若不落实 enforceable 机制，会随 workflow.md 继续膨胀而高频化（2026-04-17 至 2026-04-23 6 天内 DEC-025 到 DEC-029 共 +5 DEC 对应 workflow.md 条款膨胀）；TG-driven 操作 UX 持续"远端看不到进度"是明确债务
- **选 Finding 2 缓解方向 a（HTML comment 包裹）而 Finding 1 未独立修**：仅掩盖 YAML 可见性，未改 "skill→orchestrator handoff 缺 enforcement" 这一根因；6 个月后会出现"视觉干净但仍漏 forwarding"的假修复
- **选方向 c（YAML 改独立契约渠道）**：结构性最干净，但引入新 shared-resource（`/tmp/roundtable-contracts/`）增加运维面；与 DEC-004 progress_path 机制风格一致，有前例可参照
- **同时加 lint_cmd_orchestrator_compliance（独立 issue）**：runtime 层 enforcement，与文档化规则互补；6 个月后复盘会变成"规则 + 强制校验"双层，与 DEC-029 ref density 强 enforcement 同构心智

### 按需 4

**本调研不适用"痛点 / 使用者 journey / 最简方案 / 竞品对比"完整套用**：
- **痛点** 已在 issue body 明示（TG 远端看不到 phase 推进 / 协议违规 / 非首次），不另走 journey 映射
- **使用者** 当前明确 = 本仓 maintainer + Claude orchestrator 自身；外部用户路径未开
- **最简方案** 归 architect 选型（a/b/c/d + 3 hypothesis 对应缓解）
- **竞品对比** 仅涉 superpowers `<SUBAGENT-STOP>` 参照，下文维度 4 单独处理

仅沿用"竞品对比"部分：对照 superpowers 是否有同类 skill→orchestrator handoff sentinel 以校正 issue body 的参照前提（见维度 4）。

## 调研发现

### 维度 1：Bug 现象确认（Finding 1 应 fire 清单 vs 实际观察）

**触发条件**（issue body 描述；本报告不修改）：
- `decision_mode = text` / active channel = TG（sticky 语义，per §Step 5b）
- 被派发 skill 为 `analyst` 或 `architect`（skill form，**非** agent form；skill 由 runtime 直接调度，返回后直回主会话 orchestrator tick）
- orchestrator workload 重（skill 产出需综合 + 多 §Step 规则同时 fire）

**预期 fire 清单**（`commands/workflow.md` 规定；skill 返回后 orchestrator tick 重启需依序执行）：

| # | 协议规则 | workflow.md 出处 | 事件类 |
|---|---------|---------------|--------|
| 1 | Step 8 log.md flush（triggerpoint 2：A 类转场前 pause-point flush） | L502 | — |
| 2 | Step 7 INDEX.md sync（若 `created[]` 有新路径） | L454-L466 | — |
| 3 | role completion digest ≤200 Unicode codepoints（独立 TG reply） | L316 事件类 c | **c** |
| 4 | A 类 producer-pause 3 行 summary + Phase Matrix 尾段 | L314 事件类 b | **b** |
| 5 | A 类 menu 终端 emit（`go / 问 / 调 / 停`） | L342-L357 | — |
| 6 | pause，不调用任何工具等用户下一条 | L343 "停下不调用任何工具" | — |

**实际观察**（2026-04-23 session / issue body 字面描述）：
- 终端 stdout 打了自然语言 summary 替代协议产物（"假装已完成"）
- TG 零 reply（事件类 b + c 双双 miss）
- Phase Matrix snapshot 未更新
- A 类 menu 未 emit
- orchestrator 未 pause 而是继续"往后走"

**Delta**：6 条应 fire 动作中，Step 7/8（file batching 层）是否触发无外部可见证据（文件层缺 analyst 预期新增 file，但此或因 skill 侧 `created:` 未上报、或 orchestrator flush 未执行，双因不可分）。事件类 b/c/menu/pause 4 项均直接 miss。

**推论**：miss 集中发生在"需主动 fire 到外部通道（TG reply / 协议 emit / pause 态）"的动作，**未** miss 的动作（若有）集中在"orchestrator 可纯内部推进"的层面。这与"LLM attention 在 skill 返回瞬间偏向 YAML 解析任务、忽略外部 fire-and-wait 动作"的假设方向一致（推论，非实证）。

### 维度 2：非首次证据链

| 日期 | 来源 | 触发路径 | Miss 类 | 归档状态 |
|------|------|---------|---------|---------|
| 2026-04-22 | memory `feedback_tg_workflow_updates_to_tg` Why 字段 | `/roundtable:workflow #84` via TG active channel | Phase Matrix 仅终端 / auto-pick 审计仅终端 / Stage 转场 summary 仅终端 | memory file 归档；原会话 transcript 未保 |
| 2026-04-23 | issue #111 body + 本 session | `/roundtable:workflow #110` via TG active channel（analyst skill pipeline） | 事件类 b/c + A 类 menu + pause 均 miss | issue #111 归档；本报告展开；TG reply #869 是 recover emit 样本（issue body 所指） |

**共性**：
- 两次均 TG active channel sticky session
- 两次均"orchestrator 内部 bookkeeping 误判为 done"（memory 原文："以为内部 bookkeeping"）
- 两次均涉 skill form（analyst；2026-04-22 未明示但 `#84` decision-log-sustainability 走 architect skill 主路径，同类 skill-form handoff）
- 2026-04-22 memory 记录后，2026-04-23 仍复发 —— prose 层面记录规则但 runtime 未收敛

**事实**：2 次观测之间 commands/workflow.md 经 DEC-013/016/018/020/022/024/027/028/029 共 9 次 Accepted DEC 修订，条款密度净增（DEC-029 前 workflow.md DEC ref 42 → rebaseline 后 13，条文本身净增部分不可逆累积）。

**推论**：pattern 高频度 ≥ 1 次 / 6 天（2026-04-22→04-23 为 1 天内二连发），与 session 复杂度正相关（两次均跑完整 workflow pipeline）。实际出现频率可能更高但被静默 recover（用户在场时才显现为"用户提醒后 orchestrator 补发"）。

### 维度 3：Finding 1+2 拆耦论证（无法实机做 A/B 实验）

**Finding 1**：orchestrator 漏 forwarding（协议 / 外部 fire 层缺失）
**Finding 2**：skill/agent final message 末尾 YAML 契约终端可见（cosmetic + 可能 shift orchestrator attention）

**拆耦关键问题**：Finding 2 是否是 Finding 1 的 contributing factor？若是则缓解方向 a/b/c 任一能部分改善 Finding 1；若非则 Finding 2 仅 cosmetic，Finding 1 需独立机制修。

**论证层证据**（无实机 A/B 实验；仅文件状态推论）：

- **支持"Finding 2 加重 Finding 1"**：
  - **Position**：skill final message 流是 `<prose summary> + <tool-result blocks, if any> + <log_entries: YAML> + <created: YAML> + EOF`；YAML 在消息最末（`skills/analyst/SKILL.md` L170-L174 / `skills/architect/SKILL.md` L221-L223 final 输出规范）。orchestrator tick 最后读取 YAML → 解析 → 准备 Step 7/8 batch flush。此刻 working memory 上最"近"的任务是"解析 YAML + 决定 flush"，**不是**"我是否该 fire 事件类 b/c forwarding"
  - **Attention shift 机制推论**：LLM context-local attention 对消息尾部加权更高（无 Anthropic 实证数据，业界经验）；YAML 的结构化语法（`key:`、`-` list、嵌套缩进）触发"解析模式"比上文自然语言 prose 强。orchestrator 退出解析模式后，需主动"记得"回到 `commands/workflow.md` §Step 6.1 的 A 类菜单模板，而 workflow.md 552 行的规则在 context 更上游
  - **Frequency correlation**：2 次 miss 均发生在 skill form (final message 末尾含 YAML)，未观察到 agent form 下同类 miss（虽 agent form 未独立大量触发，样本不足；Task-form agent final message 末尾亦含 `<escalation>`/YAML，结构同 skill，但因 subagent form 主会话已观察子调用轨迹，orchestrator 不会"以为还在主 tick"）

- **反对"Finding 2 加重 Finding 1"**（即：Finding 2 仅 cosmetic）：
  - **Orchestrator 有足够 context 理解**：workflow.md §Step 5b/6.1 在 orchestrator 被激活时已完整加载；LLM 能识别 YAML 是机读契约、不等同任务完结
  - **Finding 1 可能由纯 rule density 驱动**：即使 YAML 移除 / 前置 / 迁移独立文件，60+ 条件路径的"应 fire 清单"本身超出 working-memory 可靠检索范围；attention shift 即便无 YAML 也可发生
  - **反向证据缺失**：若曾在无 YAML 末尾的 skill pipeline 中发生过同类 miss，可证伪"YAML 是因"；当前 skill/agent pipeline 100% 末尾含 YAML（见 `skills/analyst/SKILL.md` L170-L174 / `skills/architect/SKILL.md` L221-L223 / `agents/developer.md` / `agents/reviewer.md` / `agents/tester.md` / `agents/dba.md` 均规定 final message 末尾 `log_entries:` YAML），**不存在对照组**

- **拆耦结论**：
  - 现有证据**不能**证明 Finding 2 是 Finding 1 的**充分条件**（rule density 本身足以致 miss）
  - 现有证据**倾向**支持 Finding 2 是**加重因素**（attention-shift 论证方向 + frequency 均落在 YAML 存在的路径）
  - 要实证拆耦需：(i) 构造"无 YAML 末尾 / 其他条件相同"的 skill 变体跑 N 次观察 miss 率，(ii) 构造"有 YAML 但包裹 HTML comment / 前置 frontmatter"两种变体做 A/B。属 architect 决策后实施层的实验，不在本调研 scope

### 维度 4：superpowers `<SUBAGENT-STOP>` 参照校正

**issue body 前提**：issue body 把 `<SUBAGENT-STOP>` 列为"缓解方向 a 的设计参照 —— HTML comment sentinel 隐藏 YAML 视觉 / 仍机读"。

**实际事实**（来源：`https://github.com/obra/superpowers/blob/main/skills/using-superpowers/SKILL.md` + `docs/analyze/decision-log-sustainability.md` 已有 FAQ A6 调研）：

- `<SUBAGENT-STOP>` 实际语义 = "If you were dispatched as a subagent to execute a specific task, **skip this skill**" —— skill **自跳过** 标记（subagent context 下不加载 `using-superpowers` skill 本体）
- `<EXTREMELY-IMPORTANT>` 等同类标记 = skill 在不同 agent context 下的**选择性执行控制**
- superpowers **未提供** 任何 skill → orchestrator handoff sentinel / final-message 机读契约隐藏机制
- superpowers **未提供** ADR / decision-log 等价物；其"决策稳定性"靠 policy gate（不轻易接新贡献）+ 多平台同步约束，不走 sentinel / enforcement 路径
- superpowers 针对子 agent handoff 的**实际**策略是"让 subagent 直接跳过 meta-skill + hooks/session-start 注入"（来源：issue #237 指出 subagent session 未收 using-superpowers 注入，说明 superpowers 本身**也有** subagent handoff 漏 context 的 bug）

**推论**：issue #111 body 的"参照 superpowers `<SUBAGENT-STOP>`"前提被事实修正。`<SUBAGENT-STOP>` 不能直接服务于 Finding 2 缓解 a。缓解方向 a 的"HTML comment 包裹 YAML"仍可行，但**无**参照前例，属 roundtable 原创。

**可借鉴项**（superpowers 提供）：
- **SessionStart hook 注入模式**：roundtable 已在 DEC-028 采用同构（`hooks/session-start` + `scripts/preflight.sh`）；本次 bug 的 `<roundtable-preflight>` 块正是此模式的产物
- **Policy gate 心智**：superpowers 以"不接新贡献"守 skill 稳定，roundtable 若采等价路径可收敛 rule density（issue body out-of-scope，单独 umbrella）

**不可借鉴项**（显式列出避免后续误采）：
- `<SUBAGENT-STOP>` 直接用于 YAML 包裹 —— 语义完全不同，无法原样搬
- superpowers 的 MIT LICENSE / 多平台同步 / tests/ 目录 —— 与本 issue 无关

### 维度 5：Root cause hypothesis A（rule density）事实依据

**假设**：`commands/workflow.md` 条款密度高到超出 LLM working-memory 可靠检索范围，单次 skill handoff 要命中 6+ 规则属 best-effort 非 guaranteed。

**文件状态量化**（`wc -l` + `grep` 2026-04-23）：

| 文件 | 行数 | 估算 tokens¹ | 条件路径片段 |
|------|------|------------|--------------|
| `commands/workflow.md` | 552 | ~17681 | §Step -0/-1/0/0.5/1/2/3/3.4/3.5/4/4b/5/5b/6(A/B/C)/6b/7/8 共 20+ Step；事件类 a/b/b-9/c/d/e；`decision_mode modal\|text`；`auto_mode on\|off`；sticky channel y/n；size S/M/L |
| 其他 7 prompt 文件 | 1117 | ~30128 | 各角色规则 |
| **合计** | **1669** | **~47809** | 单 orchestrator tick 需并发检索 |

¹ tokens 估算沿用 `docs/analyze/prompt-language-policy.md` 维度 1 系数（中文字符 × 1.5 + ASCII 字符 / 4 × 1.3），偏差 ±15%。

**单次 skill handoff 应并发检索规则数**：
- §Step 5b 事件类 c 识别（digest ≤200 codepoints） → 1
- §Step 5b 事件类 b 识别（3 行 summary + Matrix 尾段 + 格式硬绑定 markdownv2） → 1
- §Step 6.1 A 类 menu 模板（`✅ / 产出 / go\|调\|问\|停` + architect / Stage 9 变体） → 1
- §Step 6.1 "pause 不调用任何工具" 行为锁 → 1
- §Step 7 phase-gate batching（决定是否现在 flush INDEX） → 1
- §Step 8 flush trigger point 2（A 类转场前 best-effort flush） → 1
- Phase Matrix re-emit 9 行全量（事件类 b 尾段 `*Phase*: \`1✅ · …\`` 单行快照） → 1
- sticky channel 判定（是否 fire TG reply） → 1
- （若 auto_mode=true）§Auto-pick 路径识别 → 0 此例

**合计**：≥8 条并发检索。与 Opus 4.7 实际可靠并发检索能力（无公开量化）相比存在不确定性。

**DEC 膨胀速度**：`docs/decision-log.md` 现有 30+ DEC 条目；DEC-028/029 2 周内新增，各含 workflow.md 条款（preflight hook / ref density enforcement）。ref density 已由 DEC-029 + `scripts/ref-density-check.sh` 收敛（workflow.md DEC ref 42 → 13 rebaseline），但**条款本体**未反向精简，条款密度总体仍上行。

**推论**：hypothesis A 有定量支持（行数 / token / 并发检索数）；precise causality 需 controlled experiment 才能证。本 hypothesis 在 issue body 明示"workflow.md 精简重构 out-of-scope"前提下，仅作事实陈述。

### 维度 6：Root cause hypothesis B（no runtime enforcement）事实依据

**假设**：所有协议规则是 prose 文本，无 runtime 校验机制。skill / agent 侧 `critical_modules` 触发强制派发（有 enforcement）；orchestrator 侧"应 fire 事件类 b/c"**无**对应校验器。

**现有 lint 覆盖**（`CLAUDE.md` §工具链）：
- `lint_cmd_hardcode`：`grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/` —— 扫 target-project 硬编码；与 orchestrator compliance 无关
- `lint_cmd_density`：`scripts/ref-density-check.sh` —— 扫 DEC/§/issue# 引用密度；与 orchestrator compliance 无关
- `test_cmd`：dogfood `/roundtable:workflow` 跑一轮 E2E —— 属人工眼判，无机器 assertion

**缺失的 enforcement 面**：
- 无 `lint_cmd_orchestrator_compliance`（issue body 明示缺失）
- 无 "TG reply 是否真 fire / 事件类 b/c/d/e 是否按 transition 触发" 的 runtime assertion
- 无 "skill 返回后 A 类 menu 是否 emit" 的 tool-call 审计

**对照 DEC-029 ref density 路径**：DEC-029 采 prose 规则 + `scripts/ref-density-check.sh` 强制 exit 1 双层，跑 lint 即 pass/fail；把"规则"转为"可机器 assert 的契约"。同构到本 issue：orchestrator compliance 若采 runtime enforcement，需 emit-log（JSONL 记录每次 fire/skip）+ post-session lint script 扫一条 session 中"应 fire 但未 fire"的 transition。

**推论**：hypothesis B 有事实支持（现有 lint 面确实未覆盖 orchestrator 外部 fire 动作）。但 runtime enforcement 引入的实施成本（emit log 记录 / 校验脚本 / session transcript 可访问性）属独立 issue，out-of-scope。

### 维度 7：Root cause hypothesis C（handoff cognitive load）事实依据

**假设**：skill 返回瞬间 orchestrator tick 要并发多件事（见维度 5 的 8+ 条），Finding 2 的 YAML 契约加重这个 cognitive load —— attention 被 YAML 解析拉走，Step 5b/6.1 forwarding 被压后遗忘。

**关键观察点**：
- **Ordering**：skill final message 字面顺序 = `prose summary → [产出 prose 段] → log_entries: YAML → created: YAML → EOF`。orchestrator 最后读到的是 YAML 解析任务
- **Working-memory 衰减**：从消息末尾回溯到 `commands/workflow.md` §Step 5b/6.1 的距离（token 数）不可见，但 session context 含 workflow.md 552 行 + skill 回传内容 + 历史对话，§Step 5b 规则本体在消息流上是 "远上游"
- **Non-empty tool-call**：orchestrator 执行 forwarding 需调 `mcp__plugin_telegram_telegram__reply` + 可能 Edit（log.md / INDEX.md）—— 工具调用需先决定 chat_id / 格式 / 内容。决定这些需再次遍历 workflow.md 规则。cost 不小

**对照 agent-form handoff**（Task-dispatched subagent）：
- subagent 返回是 `Task` 工具结果块，main session orchestrator 看到的是 agent transcript 加载 + final_message。final message 末尾**也**有 `log_entries:` YAML（`agents/developer.md` L37 / `agents/reviewer.md` L36 / `agents/tester.md` L38 / `agents/dba.md`）
- 但 main session 主导 orchestrator 的 attention 锚点是 Task tool call 的 return block，**不**是 final_message 末尾 YAML。orchestrator 预期在 Task 返回后继续"上一个 tick"任务，Step 5b/c 路径已 primed
- 对照：skill 返回（Skill tool return）直接回到 main session 当前 tick，YAML 在 tick 结尾直接"夹"在下一个 assistant 动作之前。attention locality 差异显著（推论，无实证）

**推论**：hypothesis C 有方向性证据（消息 ordering + tool return 位置差异）；precise causality 需构造 skill vs agent 对照实验才能证。skill form（analyst/architect）的 miss 频率应 > agent form —— 本 issue 2 次 miss 都在 skill form 是一致观察，但样本量 n=2 不足以统计显著。

### 维度 8：缓解方向 a/b/c/d 可行性事实（不推荐不打分）

> 以下仅陈各方向的现有基建 / 改造面 / 客观代价；选择 / 排序 / 推荐归 architect。

#### 方向 a：YAML 包裹专用 sentinel（如 HTML comment）

**现有基建**：
- markdown 渲染支持 HTML comment `<!-- ... -->`（终端 `cat` / pager 可见，markdown viewer 隐藏）
- Claude Code 终端呈现 skill final_message 为 code-fence markdown —— HTML comment 在终端**仍可见**（仅 markdown viewer 处理）；"隐藏终端视觉"预期不成立
- skill/agent prompt 本体当前规定 YAML 格式（`skills/analyst/SKILL.md` L170-L174 规定 `log_entries:` + `created:` YAML）

**改造面**：
- 改 4 个 agent 文件（`developer.md` / `tester.md` / `reviewer.md` / `dba.md`）+ 2 个 skill 文件（`analyst/SKILL.md` / `architect/SKILL.md`）的 final message 规范
- 改 `commands/workflow.md` §Step 7/8 解析逻辑（若 YAML 外包 sentinel，parser 需识别 sentinel 而非直接 regex `log_entries:`）
- critical_modules 命中（skill/agent/command prompt bodies）—— 必走 tester + reviewer

**客观代价**：
- 终端仍可见 HTML comment 语法（"隐藏视觉"目标仅 markdown viewer 层满足）
- 不改变 LLM 对 YAML 的 attention shift —— HTML comment **不**让 LLM 忽略内容（comment 仍进 context / token，仍被 LLM 读）
- 无法预测缓解 Finding 1 到何程度 —— 若 attention shift 由 YAML 语法触发而非视觉可见性触发，则 HTML comment 包裹**无效**

**与 superpowers `<SUBAGENT-STOP>` 关系**：见维度 4；**非**参照。本方向属 roundtable 原创。

#### 方向 b：YAML 前置到 final message 头（与 frontmatter 并列）

**现有基建**：
- 现有 skill/agent final_message 无 frontmatter（`skills/analyst/SKILL.md` L111-L142 "输出格式"仅规定 analyze 报告**文件**的 frontmatter，不是消息）
- workflow.md §Step 7/8 解析 YAML 的锚点不依赖位置（regex `log_entries:` / `created:`，正文任意位置可匹配）

**改造面**：
- skill/agent prompt 本体规则改"final message 首行 `---` frontmatter，next 数行 YAML，`---` 闭合，随后 prose"
- orchestrator 解析顺序改"先 YAML → 再 prose"（攻击 attention shift 方向：第一时间解析 batch，后读 prose 决定 forwarding 内容）
- critical_modules 命中

**客观代价**：
- 违反"消息首段 = 用户可消费摘要"惯例 —— 终端用户看到的第一眼是 YAML 契约而非自然语言 summary（UX 逆向）
- TG reply forwarding 若取 final_message 首段 → 抓到 YAML 头（**非**可消费内容）
- 无法预测 attention shift 方向改变：先读 YAML 完成解析后 attention 可能**仍**停在"已解析、下一步是 flush"，不一定回到 forwarding 路径

#### 方向 c：YAML 迁独立契约渠道（`/tmp/roundtable-contracts/<dispatch-id>.yaml`）

**现有基建**：
- DEC-004 已建立 progress_path / JSONL 独立契约渠道模式（`/tmp/roundtable-progress/<session>-<dispatch>.jsonl`）—— 有前例
- `scripts/preflight.sh` + `hooks/session-start` 已建立 session 级 shared-resource 管理（DEC-028）
- workflow.md §Step 3.5 已定义变量注入机制（`progress_path` / `dispatch_id` / `slug` / `role`）

**改造面**：
- skill / agent prompt 本体改"不在 final message emit YAML；改写入 `{{contract_path}}` 文件"
- workflow.md §Step 0 注入新变量 `contract_path`；§Step 7/8 从 file 读 YAML 而非从 message 正文 regex
- Skill tool 形态下 skill 能否直接 Write file？`analyst/SKILL.md` Resource Access 已允许 Write `{docs_root}/analyze/[slug].md`；加 `/tmp/roundtable-contracts/...` 需扩 Resource Access
- critical_modules 命中；可能改 Resource Access matrix（也属 critical_modules）—— 双重触发
- 需新 env var / ROUNDTABLE_CONTRACTS_DIR opt-out 机制

**客观代价**：
- 新 shared-resource 方向：multi-session race、tmpfiles GC、path 冲突
- skill/agent final message 仍有 `prose summary`（用户可消费产物）—— Finding 2 的"YAML 是 clutter"层面完全解决；Finding 1 的 attention shift **可能**解决（消息末尾无 YAML）
- 风格与 DEC-004 一致，相比方向 a/b 有架构统一性优势（但"优势"是 architect 判断，不在本报告范围 —— 仅陈"有前例"事实）
- 实施成本最重（改 6 prompt 文件 + workflow.md §Step 3.5/7/8 + Resource Access + 新 shared-resource 协议）

#### 方向 d：保持现状 + Finding 1 独立修（不动 YAML）

**现有基建**：
- YAML 契约当前工作（Step 7/8 flush 成功率无量化数据，但非全 miss）
- Finding 1 可由 rule density 单一致（hypothesis A），与 Finding 2 无因果
- DEC-029 已证 rule density 收敛可行（workflow.md DEC ref 42→13 rebaseline）

**改造面**：
- 不改 YAML 契约
- 加 runtime enforcement（lint_cmd_orchestrator_compliance / emit log + post-session assert） —— 属 hypothesis B 响应，独立 issue
- 或改 workflow.md §Step 5b/6.1 行文 layout（把"应 fire"列成 checklist 形态 + §Step 6.1 菜单模板前置） —— 属 hypothesis A 响应

**客观代价**：
- 若 Finding 2 确实是 contributing factor（维度 3 倾向支持），方向 d 治标不治本
- 对 TG 远端 UX 改善依赖 enforcement 实施速度 + 规则 layout 是否收敛；短期仍有 miss 风险
- 承认"YAML 终端可见是 cosmetic，不解决"—— 需在 design-doc 显式论证 accepted

### 维度 9：3 hypothesis × 4 mitigation 交叉映射（事实层观察）

> 此节为事实陈述 hypothesis 与 mitigation 的覆盖关系，**不**做推荐。

| Hypothesis | 方向 a（HTML sentinel） | 方向 b（前置 frontmatter） | 方向 c（独立契约渠道） | 方向 d（保持现状） |
|-----------|-----------------------|-------------------------|-------------------|------------------|
| A rule density | ☐ 不响应 | ☐ 不响应 | ☐ 不响应 | ☐ 不响应（需独立 P2） |
| B no enforcement | ☐ 不响应 | ☐ 不响应 | ☐ 不响应（契约改位置非 enforcement） | ◐ 部分响应（d 搭配 runtime lint 可响应） |
| C cognitive load | ◐ 弱响应（仅视觉隐藏，LLM 仍读） | ◐ 弱响应（attention 前置不等同移除） | ◎ 强响应（消息末尾无 YAML） | ☐ 不响应 |

**观察**：
- 方向 c 对 hypothesis C 响应最强（消息末尾结构变），但不响应 hypothesis A/B
- 方向 d 对 hypothesis A/B 需额外搭配（runtime enforcement + rule layout 改），单独 d 不构成完整 mitigation
- 方向 a/b 对 hypothesis C 响应弱（不改 YAML 存在，仅改位置或视觉）
- **无任一单一方向能同时响应 3 hypothesis** —— 若 3 hypothesis 并存，完整 mitigation 需组合（a 或 b 或 c 选一 + d 搭配 runtime lint + 独立 P2 收敛 rule density）

### 维度 10：实施成本 per-file delta 估算

**改动面量化**（若选方向 c，最重路径）：

| 文件 | 当前规则 | 改动方向 | 估算行数 delta |
|------|---------|---------|--------------|
| `skills/analyst/SKILL.md` | L170-L174 final message YAML 规范 | 改为"YAML 写 contract_path" | ±10 |
| `skills/architect/SKILL.md` | L221-L223 final message YAML 规范 | 同上 | ±10 |
| `agents/developer.md` | L37 `log_entries:` 契约 | 同上 | ±5 |
| `agents/tester.md` | L38 同 | 同上 | ±5 |
| `agents/reviewer.md` | L36 同 | 同上 | ±5 |
| `agents/dba.md` | 类似位置 | 同上 | ±5 |
| `commands/workflow.md` §Step 3.5.3 | 4 变量注入表 | 加 `contract_path` | ±3 |
| `commands/workflow.md` §Step 7 | 从 final_message `created:` 读 | 改从文件读 | ±15 |
| `commands/workflow.md` §Step 8 | 从 final_message `log_entries:` 读 | 改从文件读 | ±15 |
| `scripts/` + `hooks/` | ROUNDTABLE_CONTRACTS_DIR env / tmpfiles / GC | 新 script 或扩 preflight.sh | ±30 |
| 新 DEC | 契约渠道决策 + critical_modules 状态 | decision-log.md | +30 |
| design-doc | 本 issue 产出 | design-docs/orchestrator-compliance-gap.md | +150~300 |
| exec-plan | 若 go-with-plan | exec-plans/active/...md | +50~80 |
| **合计（方向 c 路径）** | | | **~280-400 行** |

**改动面量化**（若选方向 d，最轻路径）：

| 文件 | 改动 | 估算行数 delta |
|------|------|--------------|
| `commands/workflow.md` §Step 5b/6.1 | layout 调整（checklist 化 / 模板前置） | ±20 |
| 新 DEC | 明示 "YAML 保持 final message，accepted cosmetic trade-off" + 搭配 runtime enforcement 路径 | +25 |
| design-doc | 本 issue 产出 | design-docs/orchestrator-compliance-gap.md | +100~200 |
| 独立 issue（runtime enforcement） | follow-up | — |
| **合计（方向 d 路径）** | | **~45-65 行 + 1 follow-up issue** |

**观察**：方向 c 与方向 d 的实施成本差 ~5-8 倍（不含独立 P2 + runtime enforcement follow-up）。

## 对比分析

（本调研不做方向选型；对比详见维度 8/9/10 客观事实表格）

## 开放问题清单（事实层）

- Finding 2 → Finding 1 的因果贡献强度：**事实**：当前 2 次 miss 均发生在 YAML-tail 路径，无对照组数据；精确因果需 A/B 实验。**来源**：维度 3 / 维度 7
- `<SUBAGENT-STOP>` 原设计语义 = skill 自跳过，**非** orchestrator handoff sentinel：**事实**：`https://github.com/obra/superpowers/blob/main/skills/using-superpowers/SKILL.md`。**来源**：维度 4；issue #111 body 参照前提需修正
- skill form vs agent form 的 handoff attention 是否有差异：**事实**：2 次 miss 均 skill form；样本 n=2 不足以统计显著。**来源**：维度 7；agent-form 的对照观测缺失
- runtime enforcement 的具体实施载体：**事实**：DEC-029 已证 lint_cmd 扩展可承接 scripts/ enforcement；orchestrator compliance 的校验数据源（session transcript / emit log / TG reply log）归属未定。**来源**：维度 6
- workflow.md §Step 5b/6.1 是否可以 layout 层改"checklist 化"降 cognitive load：**事实**：当前两个 Step 的规则是 prose + 表格，应 fire 动作散落 L305-L384；若提取 "skill → orchestrator handoff checklist" 单节可降检索成本。**来源**：维度 5
- Resource Access matrix 扩展 `/tmp/roundtable-contracts/` 写入权限是否触发 critical_modules 二次级联：**事实**：`Resource Access matrix` 本身在 critical_modules 列表；改它同时命中 tester + reviewer 双派发。**来源**：维度 8 方向 c
- Finding 1 是否在 non-TG session（纯终端）同样发生：**事实**：当前 2 次 miss 均 TG session；纯终端 session 的事件类 b/c forwarding 本就不触发（sticky 语义），但 A 类 menu emit / Phase Matrix 更新 / pause 协议在纯终端也应 fire。无纯终端 miss 观测数据。**来源**：维度 1；补观测需 dogfood 纯终端 session

## FAQ

（待用户追问或 architect 追问时扩）

---

created:
  - path: docs/analyze/orchestrator-compliance-gap.md
    description: Issue #111 orchestrator skill→orchestrator handoff forwarding 合规缺口调研；Finding 1+2 拆耦论证 + 3 hypothesis 事实依据 + 4 mitigation 方向可行性 + superpowers 参照校正

log_entries:
  - prefix: analyze
    slug: orchestrator-compliance-gap
    files: [docs/analyze/orchestrator-compliance-gap.md]
    note: issue #111 — orchestrator handoff forwarding 合规缺口调研。Finding 1 6 条应 fire 清单 vs 实际观察 4 miss；非首次证据链 2026-04-22 memory + 2026-04-23 本会话；Finding 1+2 拆耦论证（YAML 倾向支持是 contributing factor 但无 A/B 实证）；3 hypothesis 各独立佐证（A 条款密度 workflow.md 552 行 ≥8 并发检索 / B 现有 lint 面无 orchestrator compliance / C attention shift 论证 + skill vs agent form 对照缺失）；superpowers <SUBAGENT-STOP> 事实校正（skill 自跳过非 handoff sentinel，issue body 参照前提被修正）；4 mitigation 方向 × 3 hypothesis 交叉映射（无单方向全响应）；实施成本 per-file delta 方向 c ~280-400 行 vs 方向 d ~45-65 行；7 事实层开放问题。不做选型推荐（留给 architect）
