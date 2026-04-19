---
slug: subagent-progress-and-execution-model
source: analyze/subagent-progress-and-execution-model.md
created: 2026-04-19
updated: 2026-04-19
status: Accepted
decisions: [DEC-004, DEC-005, DEC-008]
supersedes: []
orthogonal_to: [DEC-001 D8, DEC-002, DEC-003]
issue: https://github.com/duktig666/roundtable/issues/7
---

# subagent 进度可见性 + 执行模型可选配 设计文档

> slug: `subagent-progress-and-execution-model` | 状态: Accepted | 参考: analyst 报告同名、DEC-001 D8、DEC-002 Escalation、DEC-003 research fan-out

---

## 0. 决策总览

| # | 决策点 | 选择 | 对应 DEC |
|---|--------|------|---------|
| D1 | issue #7 范围 | 问题 A（进度透传）+ 问题 B（执行模型）一并处理 | DEC-004 + DEC-005 |
| D2 | B 骨架：四角色 form 范式 | 按角色分档：**developer 双形态**（inline \| subagent），tester/reviewer/dba 仅 subagent | DEC-005 |
| D3 | A 路径：subagent 进度机制 | **P1 push** — subagent 侧 phase checkpoint 时 append JSON event 到共享 progress log；orchestrator Monitor tail | DEC-004 |
| D4 | 事件颗粒度 | **phase checkpoint**（exec-plan P0.n 级，一次 dispatch 约 3-10 event） | DEC-004 |
| D5 | 协议层级 | **plugin 元协议**（在 skills/agents/commands 本体声明；不入 CLAUDE.md） | DEC-004 |
| D6 | 触发规则 | **全部 subagent dispatch 默认开启** progress 监听 | DEC-004 |
| D7 | DEC-001 D8 演进 | **正交补强**（不 Supersede；新 DEC + D8 共存；参照 DEC-003 先例） | DEC-005 |

用户 north-star（2026-04-19 session）："重点还是用户感知进度对整个流程的掌控"。本设计以 **"用户掌控感"** 为硬约束：主会话用户必须实时看到 phase 级进度，能判断子 agent 活着/卡住/快完了，能在关键点介入。

---

## 1. 背景与目标

### 1.1 背景

见 `docs/analyze/subagent-progress-and-execution-model.md`。核心事实：

- DEC-001 D8 锁定 developer/tester/reviewer/dba 为 subagent；subagent 上下文系统性隔离，orchestrator LLM 在前台 Task 调用时对 subagent 内部不可见。
- P4 dogfood 实录（`docs/testing/p4-self-consumption.md`）证实：9 次 subagent 派发中多次出现 3–10+ 分钟无声等待；用户失去掌控感是 plugin UX 最显著痛点之一。
- Claude Code 原生已提供 `Monitor` 工具（v2.1.98 起）+ subagent transcript JSONL + 后台 subagent，但未在官方文档中展示"orchestrator 感知 subagent 进度"的组合范式。

### 1.2 目标

1. **用户在主会话实时看到 subagent 所处 phase**（3–10 条/dispatch 级事件）
2. **小任务可选 inline 执行**（developer 主动切档即可全程可见、零 subagent 边界）
3. **兼容现有 DEC-001 / 002 / 003 纪律**（不破 Resource Access / Escalation / 并行派发四条件树）
4. **对目标项目零侵入**（不改 target CLAUDE.md；progress schema 定义在 plugin 内）

### 1.3 非目标

- ❌ auto 档（issue #7 提议的 "auto 按任务规模自动选"）—— 基于 analyst §失败模式，auto 触发规则解释成本高，6 个月后易沦为摆设
- ❌ tester / reviewer / dba 双形态 —— 这三角色大 context（对抗测试 17 suites / 全仓审查 / 跨库 schema），inline 即大规模主会话污染
- ❌ progress event 每工具调用颗粒度（用户不需要看每次 Read）
- ❌ orchestrator 反向 SendMessage 询问 subagent（experimental 特性 + 违反官方 "don't poll" 倾向；P6 作为后备路径暂不纳入）

---

## 2. 业务逻辑

### 2.1 整体信息流

```
+------------+          +---------------------+
| orchestrator (主会话) |   Monitor tail      |
|  /roundtable:workflow |<-- notification per -|
+------------+          +----------------+
      |                                  ^
      | Task dispatch (注入 progress_path)|
      v                                  |
  +----------+   phase_start/_complete   |
  | subagent |  echo '{json}' >>         |
  | (前台)   |-----> /tmp/roundtable-----+
  +----------+       progress/<id>.jsonl
```

### 2.2 两种执行档的决策流

```
task 来了
  |
  +-- developer 且 task 规模小 (同一模块 ≤ 3 文件 / 预估 < 2 分钟)  ─→ inline（新，developer 专属）
  |     主会话直接按 developer.md 执行，AskUserQuestion 可用
  |
  +-- 其他所有情形 ─→ subagent（原样，DEC-001 D8 默认）
        Task 派发 + progress monitor 自动伴随
```

切档机制见 §3.4。

### 2.3 Progress event 生命周期

1. orchestrator 在 Task 派发**前**：
   - 生成 `dispatch_id`（8 位 hex）
   - 计算 `progress_path = /tmp/roundtable-progress/{session_id}-{dispatch_id}.jsonl`（`session_id` 从 CWD 的 session 记忆拿，见 §3.5）
   - `mkdir -p` 目录（如不存在）
   - 启动 Monitor：`tail -F {progress_path} 2>/dev/null | jq -R --unbuffered -c 'fromjson? | select(.event) | ...'`（`-R` + `fromjson?` 让单行损坏不崩整个 pipe；详见 §3.3）
2. Task 派发时注入 prompt 片段：`progress_path`、`dispatch_id`、完整 emit 模板
3. subagent 执行：
   - 每次进入新 phase：`echo '{...phase_start...}' >> {progress_path}`
   - 每次完成一个 phase：`echo '{...phase_complete...}' >> {progress_path}`
   - 遇到 blocker（需要 escalation 之前）：`echo '{...phase_blocked...}' >> {progress_path}`
4. Monitor 每次从 stdout 读一行 → 唤醒 orchestrator notification
5. orchestrator 把 event 格式化后 relay 给用户（"developer [P0.2] 开始 - 写 src/foo.ts"）
6. Task 返回 → orchestrator 停 Monitor（通过 MonitorStop 或允许自然结束）

---

## 3. 技术实现

### 3.1 Progress event schema

所有 event 单行 JSON（JSONL 格式）：

| 字段 | 类型 | 必选 | 说明 |
|------|------|------|------|
| `ts` | ISO-8601 string | 是 | UTC 时间戳，精度到秒 |
| `role` | string | 是 | 发出者角色：`developer` / `tester` / `reviewer` / `dba` / `research` |
| `dispatch_id` | string | 是 | orchestrator 分配的 8 位 hex；同一 dispatch 所有 event 共享 |
| `slug` | string | 是 | 任务 slug（与 exec-plan / design-doc 对齐） |
| `phase` | string | 是 | 当前 phase 标签（exec-plan P0.n 级；若 exec-plan 无分层则用 subagent 自定义 phase 名） |
| `event` | enum | 是 | `phase_start` / `phase_complete` / `phase_blocked` |
| `summary` | string | 是 | 一句话摘要，≤ 120 chars；用户可读（中英不强制，面向用户） |
| `detail` | object | 否 | 可选补充字段，如 `files_changed: [...]`、`tests_passed: N` |

示例（单行 JSONL）：

```json
{"ts":"2026-04-19T12:34:56Z","role":"developer","dispatch_id":"a1b2c3d4","slug":"subagent-progress-and-execution-model","phase":"P0.2","event":"phase_start","summary":"开始实现 progress emit 在 developer.md"}
{"ts":"2026-04-19T12:36:01Z","role":"developer","dispatch_id":"a1b2c3d4","slug":"subagent-progress-and-execution-model","phase":"P0.2","event":"phase_complete","summary":"developer.md 写入 progress emit 模板","detail":{"files_changed":["agents/developer.md"]}}
```

### 3.2 Progress event 发射约定（subagent 侧）

四个 subagent（developer/tester/reviewer/dba）+ research 的 prompt 文件本体新增 `## Progress Reporting` section，内容骨架：

```
## Progress Reporting

When you begin, the orchestrator injects {{progress_path}}, {{dispatch_id}}, and {{slug}} into your prompt. At each phase boundary, emit a progress event before continuing:

- On entering a phase: Bash `echo '{"ts":"<now-iso>","role":"<role>","dispatch_id":"{{dispatch_id}}","slug":"{{slug}}","phase":"<tag>","event":"phase_start","summary":"<≤120 char 1-sentence what you are about to do>"}' >> {{progress_path}}`
- On completing a phase: same but event=phase_complete; optionally add detail: {files_changed:[...], tests_passed:N}
- On being blocked (before emitting <escalation>): event=phase_blocked, summary states why

Emit ONE line per event. Never batch. Never suppress.
Phase tag is the closest exec-plan P0.n label, or a subagent-chosen name if no exec-plan exists.
```

**选择人工 echo 而非 PostToolUse hook 的理由**：

1. hook 脚本需 plugin 分发可执行文件，plugin 跨平台（Linux/macOS）要管 shebang、权限位，分发复杂度高
2. hook 在每个 tool call 后触发，颗粒度过密（D4 决策排除）；筛选到 "phase boundary" 又要脚本逻辑
3. 人工 echo 是 subagent prompt 纪律的自然延伸，与 `<escalation>` JSON 一致的"结构化输出"范式
4. subagent 遗漏 echo 时降级为"静默"，与当前现状一致（没让事情变更差）

### 3.3 Orchestrator Monitor 启动模板

`commands/workflow.md` + `commands/bugfix.md` 在 Task 派发前注入：

```bash
# 生成 dispatch_id（主会话 orchestrator Bash 调用）
DISPATCH_ID=$(openssl rand -hex 4)
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%s)}"  # fallback to unix ts if env not set
PROGRESS_PATH="/tmp/roundtable-progress/${SESSION_ID}-${DISPATCH_ID}.jsonl"
mkdir -p "$(dirname "$PROGRESS_PATH")"
touch "$PROGRESS_PATH"

# 启动 Monitor — tail -F 容忍文件未初始化；jq -R + fromjson? 让单行损坏不崩 pipe；select(.event) 过滤 schema-incomplete
# 注意 --unbuffered 防止 pipe buffering 延迟
Monitor script: "tail -F ${PROGRESS_PATH} 2>/dev/null | jq -R --unbuffered -c 'fromjson? | select(.event) | \"[\" + .phase + \"] \" + .role + \" \" + .event + \" — \" + .summary'"
```

orchestrator 收到 notification 后直接转发给用户，例如：

```
[P0.2] developer phase_start — 开始实现 progress emit 在 developer.md
```

### 3.4 developer 双形态切换规则（problem B）

#### 3.4.1 默认行为

- 用户未显式声明时：**subagent**（DEC-001 D8 默认行为不变）
- tester / reviewer / dba **永远** subagent（本 DEC 不扩展这三角色）

#### 3.4.2 切换触发（inline 档开启条件）

以下任一条件满足时，`/roundtable:workflow` 或 `/roundtable:bugfix` 以 inline 形态执行 developer：

1. **用户显式声明**（per-session 粒度）：在任务描述里包含 `@roundtable:developer inline` 或在前置消息说 "developer 用 inline"
2. **CLAUDE.md 显式声明**（per-project 粒度）：target CLAUDE.md `# 多角色工作流配置` 新增可选 key
   ```markdown
   developer_form_default: inline  # 可选，省略则 = subagent
   ```
   `/roundtable:workflow` 读 CLAUDE.md 时识别此 key
3. **/roundtable:workflow 启动弹窗**（per-dispatch 粒度）：workflow command Step 3 在 developer 阶段前插一次 AskUserQuestion：
   - 小任务标志（单文件改、简单 bug 修）→ 选项含 inline=recommended
   - 其他情形 → 选项含 subagent=recommended
   - 用户可覆盖推荐

发起 inline 档时，orchestrator **内联执行 developer.md 的 prompt**（与 architect / analyst 同机制 — 直接 Read 文件 + 在主会话执行流程），AskUserQuestion 在 inline 下可用。

#### 3.4.3 inline vs subagent 的能力差异

| 能力 | inline | subagent |
|------|--------|---------|
| 主会话实时可见 | ✅ 完全透明 | ⚠️ 靠 progress event |
| AskUserQuestion | ✅ 可用 | ❌ 用 `<escalation>` |
| Context 隔离 | ❌ 污染主会话 | ✅ 隔离 |
| 并行派发多个 developer | ❌（主会话单线程） | ✅ DEC-002 支持 |
| Resource Access 约束 | 同 subagent 版本 | 同 subagent 版本 |
| Escalation 协议 | 不需要（直接 AskUserQuestion） | 需要 |

**适用建议（developer.md 会声明）**：

- 选 **inline**：单文件小改、bug 热修、用户想紧跟过程、任务能在 < 2 分钟 / < 20k token 完成
- 选 **subagent**：多文件 refactor、新模块实现、批量 test 生成、需要并行 developer

#### 3.4.4 developer.md prompt 双形态声明

`agents/developer.md`（当前 subagent frontmatter）保留不变，**新增 hybrid 段**：

```markdown
## Execution Form (subagent vs inline)

This role supports two execution forms. The orchestrator selects one per dispatch; you behave identically except for the interactive-decision fallback.

| Situation | Form | Interactive decisions via |
|-----------|------|---------------------------|
| Task dispatched via `Task` tool (default) | subagent | `<escalation>` JSON block |
| Task dispatched by inline-executing this file in the main session | inline | `AskUserQuestion` directly |

In inline form, do NOT emit progress events (the main session observes you directly). In subagent form, follow §Progress Reporting.
```

### 3.5 session_id 获取与 transcript 联动（实现细节）

- `CLAUDE_SESSION_ID` env var 由 Claude Code 注入（若未注入则回落 unix ts；不影响功能）
- Progress path 与 subagent transcript（`~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`）**解耦**：progress 是 plugin 自控的事件面，transcript 是 Claude Code 托管的完整对话面。用户若想看工具调用细节仍可 `/agents` Running tab；progress 只服务 orchestrator → 用户的 phase 级 relay。
- 清理：`/tmp/roundtable-progress/` 下文件随 OS tmp 清理策略处理；plugin 不主动 gc（避免引入状态）

### 3.6 与 DEC-002 / DEC-003 的接口

| 协议 | 用途 | 颗粒度 | 方向 |
|------|------|-------|------|
| `<progress>` JSON line（本 DEC-004） | 进度 | phase 级 | subagent → orchestrator (pub/sub via log file) |
| `<escalation>` JSON block（DEC-002） | 用户决策请求 | 决策点 | subagent → orchestrator (final message) |
| `<research-result>` JSON block（DEC-003） | 事实回执 | dispatch-level | research agent → architect skill (final message) |

三者**正交**、**不相互触发**、**路径独立**：progress 用临时文件 + Monitor，escalation / research-result 用 Task final message。subagent 同一 dispatch 可同时产生 progress events（多次）+ 1 个 final message（可能含 escalation）。

### 3.7 对并行派发判定树（DEC-002 §4）的影响

progress 机制**不破坏**并行派发四条件：

1. PREREQ MET — progress 只追加文件，不依赖任何前置
2. PATH DISJOINT — 每个 dispatch 用独立 progress_path（按 dispatch_id 命名），天然 disjoint
3. SUCCESS-SIGNAL INDEPENDENT — Monitor notification 按 dispatch_id 路由
4. RESOURCE SAFE — `/tmp/roundtable-progress/` 无锁文件；多 Monitor 并发 tail 不同文件 OS 级支持

### 3.8 Foreground vs background dispatch gate（DEC-008 patch）

DEC-004 决定第 6 项「触发规则」原文 "所有 subagent dispatch 默认开启" 隐含一个未言明的 assumption：所有 `Task` 派发都是后台派发（`run_in_background: true`），主会话对 subagent 内部不可见。issue #15 dogfood 实录证明该 assumption 不成立：

| 派发形态 | 主会话观测能力 | Monitor 必要性 |
|---------|---------------|---------------|
| **前台 Task**（currently the Claude Code default；`run_in_background` 缺省 / `false`） | 主会话阻塞等结果；子 agent 的 Bash/Read/Edit/Write 工具调用以**缩进形式实时显示**在主会话输出里 | ❌ 冗余 — Monitor 通知 + 缩进工具流，主会话收两份信号 |
| **后台 Task**（`run_in_background: true`） | 主会话不阻塞，**完全看不到** subagent 内部工具调用 | ✅ 必须 — 唯一的 phase 级进度通道 |

DEC-004 §3.1 motivation —— "orchestrator LLM 对 subagent 内部**系统性**不可见" —— 仅对后台派发严格成立；前台派发的不可见是 LLM 注意力问题（缩进流过长易失焦），不是 systemic blindness。

**DEC-008 决定**：Step 3.5（progress monitor 启动 + 4 变量注入）的触发条件从"所有 Task 派发"收紧为"`run_in_background: true` 的 Task 派发"。前台派发完全 skip 该 Step（无 `progress_path`、无 Monitor、无 4 变量注入）。subagent 收到空 `progress_path` 时按 §3.2 末句 "漏 echo 时降级为静默" 条款（结构化骨架 + FAQ Q2）静默 — 该 fallback 在 DEC-004 落地时已就位，本 DEC 不需要改 5 份 agent prompt 本体。

**并行派发语义**：`run_in_background` 是 per-`Task`-call 参数。orchestrator 在同一 assistant message 中 issue 多个 `Task` 调用时（DEC-002 §4 并行派发），**逐个 Task 调用独立评估 §3.5.0 gate**。混合批（如 1 前台 + 2 后台）产生 2 个 Monitor / 2 个 `progress_path`，不是 3 个。

**实现位置**：
- `commands/workflow.md` Step 3.5 顶部新增 §3.5.0 "Foreground vs background gate"，先于 §3.5.1 env opt-out 检查（gate 失败直接 skip 整段；§3.5.1 仅在 gate 通过后运行）
- `commands/bugfix.md` Step 0.5 同步加 delta 0（显式枚举 skip 的 4 件事：不生成 progress_path / 不启动 Monitor / 不注入 4 变量 / subagent Fallback 静默）

**与 DEC-007 的正交性**：DEC-007 修源端 summary 内容质量（agent prompt §Content Policy）+ orchestrator awk 折叠；DEC-008 修触发条件（commands 层）。两个补丁不重叠、不互依、可分别合并；它们是从两个层次（content vs gate）补 DEC-004 的不同 assumption 漏洞。

**与 DEC-005 的关系**：DEC-005 §6b.3 已声明 inline developer 不跑 Step 3.5（"主会话直接观察 developer 流程；progress 中继冗余"）。DEC-008 把这条 inline-only 的逻辑推广到所有"主会话可观察"的派发 — inline developer（不走 `Task`）和前台 `Task` 是两条独立 skip 路径，互不重叠：inline 完全不派发 Task，§3.5.0 甚至不会被评估到。两条 skip 的理由同源："主会话已能观察 → Monitor 冗余"。

---

## 4. 关键决策与权衡

### 4.1 Push vs Pull（决策 D3）

| 维度（0-10） | P1 push ★ | P6 pull | 混合 | P4 heartbeat tag |
|------------|-----------|---------|------|-----------------|
| 事件驱动高效性 | **9**（Monitor event-driven） | 5（poll 固定周期） | 7 | 8（text tag grep） |
| subagent 改动面 | 5（需加 §Progress Reporting） | **9**（零改） | 5 | 6（加 tag 约定） |
| 主会话 token 成本 | **8**（按需 notification） | 3（每 N 分钟 Bash+Read） | 4 | 7（tail+grep） |
| 官方架构对齐 | **9**（Monitor 原生） | 4（违反"don't poll"倾向） | 6 | 7 |
| 颗粒度稳定性 | **8**（JSON 结构化） | 7（JSONL 靠 subagent 自觉） | 7 | 4（LLM 文本漂移） |
| 与 DEC-002 Escalation 范式一致 | **9**（同为 JSON 结构化） | 5 | 6 | 5 |
| **合计** | **48** | 33 | 35 | 37 |

P1 全维度胜出；P6 作为 future fallback 不进本 DEC。

### 4.2 developer 双形态 vs 保留 D8（决策 D2）

| 维度（0-10） | 双形态 ★ | 保持单形态 + out-of-band 观察 | 全四角色双形态 |
|------------|---------|-------------------------|----------------|
| 用户掌控感提升（小任务）| **9** | 5 | **9** |
| 维护成本 | **7**（只 developer 双） | **9**（零改） | 3（四角色双） |
| context 风险 | **8**（tester/reviewer/dba 仍隔离） | **9**（全隔离） | 4（reviewer inline 易爆） |
| 与 DEC-003 正交补强先例对齐 | **9** | — | 7 |
| 用户实际使用频率对齐 P4 数据 | **9**（developer 小任务最频繁） | 6 | 5 |
| **合计** | **42** | 29 | 28 |

### 4.3 Plugin 元协议 vs CLAUDE.md 声明（决策 D5）

plugin 元协议（Accepted）与 CLAUDE.md 声明的关键差别：

- **DEC-001 D2** 明确 CLAUDE.md 只放**业务规则**（critical_modules / 设计参考 / 触发规则 / 工具链覆盖）；progress 是 plugin 运转的**元协议**（和 DEC-002 Escalation 同层）
- target 项目零改动（用户项目不需要新增 section）
- plugin 版本升级自带协议演进，不留遗留 CLAUDE.md 条目

**例外**：`developer_form_default` 是 per-project **业务偏好**（不是 plugin 元协议），这一 key 在 CLAUDE.md 的声明不违反 D5 的边界。

---

## 5. 讨论 FAQ

### Q1: inline developer 和 skill developer 有什么区别？为什么不直接把 developer 改成 skill？

**A**: "inline 执行"是 orchestrator 读 `agents/developer.md` 并在主会话按它的指令操作，文件形态保持 agent（有 frontmatter `name: developer` / tools / resource access）。这与把 developer 改成 `skills/developer.md` 的根本差别：skill 是 Claude Code 原生的"主会话指令文件"，必须走 `Skill` 工具激活；而 agent 的 inline 执行是 roundtable plugin 自己的约定（orchestrator 读文件并执行），不依赖 Claude Code 的 skill 激活路径。选择后者避免触发"Skill 激活失败"的历史 bug（见 `_detect-project-context.md` activation note），也避免 skill 目录的命名空间污染。

### Q2: progress emit 漏了怎么办？subagent 忘记在 phase 边界 echo 一条呢？

**A**: 降级为当前状态（用户看不到进度），不会变更差。reviewer agent 在下轮审查可以用 "progress emit discipline" 作为 Warning 项抓。未来可加 lint 规则扫描 subagent 产出里是否包含 progress emit 的 Bash 调用。

### Q3: 为什么不直接让 subagent 在 Write 工具后自动 echo 一条？

**A**: Write/Edit 颗粒度过密（决策 D4 排除）。而且 Write 不等于 phase boundary（一个 phase 可能连写 3 个文件）。人工 echo 的颗粒度由 subagent 主观选择，对齐 exec-plan P0.n 结构。

### Q4: /tmp 被清理了怎么办？

**A**: /tmp 默认保留到 reboot 或 tmpfiles.d 清理策略（多数发行版 > 10 天）。一次 workflow 生命周期（几小时到 1 天）不会被清理。如果遇到 tmp 被重启清理，下次 dispatch 会重新 mkdir + touch，无状态依赖。

### Q5: 用户能关掉 progress 吗？（不想看进度 relay）

**A**: 可。orchestrator 识别 env var `ROUNDTABLE_PROGRESS_DISABLE=1` 时跳过 Monitor 启动 + 不在 dispatch prompt 注入 progress_path。subagent 收到空 progress_path 时按 "no emit" 行为静默。该 env var 由用户在 shell 层设置，不入 CLAUDE.md（保持 D5 边界）。

### Q6: DEC-001 D8 的"全 skill 形态"拒绝理由"developer/tester 读写大量代码撑爆主会话 context"是否仍成立？

**A**: 1M token 上限下，P4 数据（10-40k/dispatch）远未触顶。但**多次累积**会触顶：一轮 workflow 9 次 dispatch × 30k = 270k，加上 analyst/architect 产出后主会话已用 150k+，approaching 一半。tester/reviewer/dba 一次 dispatch 可能 80k+（全仓扫描）。本 DEC 只放 developer inline 是基于"单轮 inline < 20k"的约束 —— developer.md 会声明"inline 档预估 token > 30k 时 subagent 更好"。

---

## 6. 变更记录

- 2026-04-19 创建 — 解 issue #7；落 DEC-004（progress event protocol）+ DEC-005（developer 双形态正交补强 D8）
- 2026-04-19 新增 §3.8 Foreground vs background gate — 解 issue #15；落 DEC-008（Supersedes DEC-004 决定第 6 项「触发规则」）。前台派发（`run_in_background` 缺省 / `false`）skip Step 3.5 整段，避免主会话同时收 Monitor 通知 + 子 agent 缩进工具流的双份信号。同步补丁 commands/workflow.md §3.5 + commands/bugfix.md §Step 0.5；不改 5 份 agent prompt 本体（§3.2 末句漏发降级条款已兼容）
- 2026-04-19 §3.3 Monitor 模板鲁棒性修正 — tester 发现单行非 JSON 击穿 jq pipe 导致后续 event 全丢（docs/testing/subagent-progress-and-execution-model.md Case 1.2/1.2b Critical）。把 `jq --unbuffered -c 'select(.event) | ...'` 改为 `jq -R --unbuffered -c 'fromjson? | select(.event) | ...'`：`-R` 读 raw string，`fromjson?` 带问号的 try-parse 在遇到坏行时 silently no-op。同步更新 commands/workflow.md §3.5.3 + commands/bugfix.md §Step 0.5。Smoke 复验：3 合规 + 2 坏行输入 → 3 合规全过，exit 0

## 7. 待确认项

- §3.4.3 表格里"Resource Access 约束 同 subagent 版本" —— reviewer 在 developer.md 落盘审查时需确认 inline 档是否因为在主会话运行导致 `Forbidden` 行变化（理论上不应该，但值得 explicit 审查）
- §3.5 `CLAUDE_SESSION_ID` env 回落 unix ts 方案：在 Monitor 长跑（>1 天）场景下，unix ts 以秒计唯一性够；但多机并发 dispatch 可能撞车 —— 待 developer 实现时验证
