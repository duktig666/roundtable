---
slug: decision-mode-switch
source: 原创（issue #31 设计草案）
created: 2026-04-20
status: Accepted
decisions: [DEC-013]
---

# 可切换决策模式（modal | text） 设计文档

## 1. 背景与目标

### 背景

roundtable 的 `analyst` / `architect` skill 以及 `developer` / `tester` / `reviewer` / `dba` agent 依赖 `AskUserQuestion` 原生工具收集用户决策。该工具只在当前 Claude Code CLI 主会话内以模态弹窗形式出现 —— **任何非 Claude Code 原生 UI 的前端**（Telegram plugin / 远程 agent session / CI 调度 / 日志回放）都无法截获和响应弹窗，导致 workflow 永久阻塞。

此外部分本地用户反馈模态弹窗不便**复制、审计、重放**，希望走对话内文本决策块以利于：
- 把决策文本块直接粘贴到设计文档 / issue 注释留档
- CI 自动化可 parse 决策块条件喂回选项
- 中断恢复场景可回看整个对话流理解决策上下文

### 目标

让 orchestrator 在派发前解析"决策模式"（`modal` | `text`），并按 mode 选择决策交互通道：
- `modal`（默认，现行）：`AskUserQuestion` 原生弹窗 —— 行为与当前版本完全一致，零破坏
- `text`（新增）：agent / skill 在对话流 emit `<decision-needed>` 文本块，orchestrator 监测到后 pause 等用户自由文本回复

### 非目标

- 不改 DEC-002 `<escalation>` JSON schema（agent → orchestrator 机器通道保留）
- 不改 DEC-003 `<research-result>` JSON schema（research agent 返回保留）
- 不改 DEC-006 phase gating taxonomy（producer-pause / approval-gate / verification-chain 三段式）
- 不改 Phase Matrix / Step 4 并行判定树 / critical_modules 机械触发规则
- 不引入 target CLAUDE.md 新配置项（对齐 DEC-011 / DEC-012 边界 —— dispatch mode 属 orchestrator 内部策略）
- 不改 5 个 agent prompt 本体（D1 = A 最小改动决定）
- 不负责下游"谁接收文本块"（展现与接收解耦 —— 见 §3.5）

## 2. 业务逻辑

### 2.1 决策模式解析主流程

```
orchestrator 启动（/roundtable:workflow 或 /roundtable:bugfix）
  │
  ├─ 1. CLI arg 含 --decision=<value>？
  │     → value ∈ {text, modal} → decision_mode = value
  │     → value 是其他任意字符串（invalid / off / auto / 空）→ 打印 warning 回退到下一步
  │
  ├─ 2. 读进程 env ROUNDTABLE_DECISION_MODE
  │     → 值 ∈ {text, modal} → decision_mode = env 值
  │     → 空 / unset / 其他任意字符串 → 回退到下一步（无 warning）
  │
  └─ 3. decision_mode = modal（plugin 默认）

得到 decision_mode 后：
  - 注入每个 Task 派发的 prompt prefix（`decision_mode: text|modal`）
  - 注入每次 skill 激活的 context prefix
  - orchestrator 自身按 decision_mode 选择 Escalation JSON 的渲染路径
```

**非法值语义**（tester E1/E2）：CLI arg 显式非法（用户打错）→ 一行 warning 提示 `invalid --decision=<value>, falling back to env/default`，然后回退；env 非法则静默回退（env 是持久配置，noise 低）。任一路径**不阻塞** workflow，永远有 `modal` 兜底。

### 2.1a 展现与接收 timeout（tester E5）

text 模式 pause **无 orchestrator 侧 timeout** —— plugin 层不替代各前端的等待行为，原因：
- CLI 主会话：无限等用户输入是 Claude Code 原生行为
- TG 驱动：用户可能过几小时再回复，timeout 反而误中止
- CI 场景：建议 CI 脚本侧包一层 timeout（文档已在 README 标注），不进 plugin 逻辑

非目标：为 CI 单独加 plugin 级 timeout —— 若 CI 场景实测有阻塞痛点，未来走新 DEC 补 `ROUNDTABLE_DECISION_TIMEOUT` env（当前 YAGNI）。

> **settings.json env 块**：Claude Code 原生支持 `.claude/settings.json` / `.claude/settings.local.json` / `~/.claude/settings.json` 的 `env` 字段，按 local > project > user 顺序合并到进程环境变量。plugin 层只需读合并后的 shell env，**不自行分辨三层文件**。这是 3 级优先级链（CLI arg > env > default）的文档化依据，对应 issue 原文 6 级的精简（第 2~5 级被 Claude Code 原生机制吸收）。

### 2.2 modal 模式行为（现行，不变）

| 环节 | 行为 |
|------|------|
| skill 决策点（architect / analyst） | `AskUserQuestion(question, options)` 原生弹窗 |
| agent `<escalation>` 上报 | orchestrator 解析 JSON → 转 `AskUserQuestion` 弹窗 |
| 用户响应 | 点选 option |

### 2.3 text 模式行为（新增）

| 环节 | 行为 |
|------|------|
| skill 决策点（architect / analyst） | skill prompt 条件分支：emit `<decision-needed>` 文本块 |
| agent `<escalation>` 上报 | **agent prompt 不变**；orchestrator 解析 JSON 后 render 为 `<decision-needed>` 文本块输出到对话流 |
| 用户响应 | 自由文本回复（`A` / `选 A` / `go with A` / `选 B 但加 X` 均可） |
| orchestrator 解析回复 | LLM fuzzy 理解；歧义时直接对话澄清 |

### 2.4 pause 与恢复语义

text 模式下 orchestrator 在 emit `<decision-needed>` 块后进入 **pause** 状态（不调用任何工具），等待用户下一条消息。这与 DEC-006 A 类 producer-pause 的"停下等用户自由文本输入"心智同源，复用既有交互范式。

收到用户回复后：
1. orchestrator LLM 推断选中哪个 option（或用户提出的修改）
2. 把决策事实注入下一步 subagent prompt / skill context
3. 续跑 workflow

## 3. 技术实现

### 3.1 决策块协议（text 模式，canonical schema）

**精简 YAML 风格**，外层用 `<decision-needed>` 开闭标签界定，orchestrator 用正则扫描：

```
<decision-needed id="decision-mode-switch-1">
question: 一句话描述决策点
options:
  A（★ 推荐）：<label> — <rationale> / <tradeoff>
  B：<label> — <rationale> / <tradeoff>
  C：<label> — <rationale> / <tradeoff>
</decision-needed>
```

**必选字段**：
- `id`：本 workflow 内唯一
- `question`：一句话，≤80 字
- `options`：≥2 个，每个含 label + rationale + tradeoff + 可选 `★ 推荐`

**行格式（5 处 prompt 本体 canonical，与上方代码框一致）**：`<letter>（★ 推荐）：<label> — <rationale> / <tradeoff>` 或 `<letter>：<label> — <rationale> / <tradeoff>`（无推荐时）。字段顺序：letter（A/B/C）→ 可选 `（★ 推荐）` → 中文冒号 `：` → label 文本 → em-dash `—` → rationale → 斜杠 `/` → tradeoff。推荐标记**恰好** `★ 推荐` 或 `（★ 推荐）`（带括号），不用裸 `推荐`、不用 `(推荐)`、不用其他变体（tester F2）。analyst skill 用 `fact` 替 `rationale`，**禁** `★ 推荐`（事实层职责，见 §2.3）。

**约束**：
- 单次 emit 1 个块（多决策拆多块多轮；见 §3.1.1）
- 推荐选项唯一（≤1 个 `★ 推荐`），skill 无偏好时全部不标；analyst skill **禁用** `★ 推荐`（事实层职责，见 `skills/analyst/SKILL.md`）
- `id` 格式规则见 §3.1.2

### 3.1a Active channel forwarding（orchestrator 转发义务，issue #38）

**背景**：DEC-013 决定 8 "展现与接收解耦" 本意让外层 wrapper 自处理前端转发。实测发现 orchestrator LLM 收到 "emit `<decision-needed>` 块到对话流" 默认走终端文本输出，不知道当前 session 的 **active inbound channel** 是 MCP plugin（TG / Slack / CI）时必须同步调 reply 工具才能让远程用户看到决策块，导致 TG 驱动 workflow 首个决策点即死锁（issue #38）。

**规则**（canonical，appended 2026-04-20）：

> 若当前 session inbound prompt 含 `<channel source="<plugin>:<name>" chat_id="..." ...>` 标签，或该 channel 的 reply 工具在本 session 内曾调用过（**sticky 语义**，不按轮次窗口衰减），每次 emit `<decision-needed>` 块**必须**同步调该 channel reply 工具把**字节等价**的同一块体转发过去（同 `id` / `question` / `options`，纯文本即可，不重排、不重生成 `id`、不缩略）。终端 stdout emit 保留（orchestrator fuzzy parse 与日志回放依赖）。检测不到远程 channel（纯终端 session）→ 不调 reply，行为与现状一致。

**宁可过度转发不可遗漏** —— sticky 语义选择 tiebreak 原则：session 内一旦认定有远程 channel，后续所有 `<decision-needed>` emit 都转发；不做轮次窗口衰减（N 轮重计）以避免长会话 stale-channel 假阴性死锁。

**仅在 emit `<decision-needed>` 时触发**（普通对话 / phase A producer-pause summary / FAQ 不在本规则范围，另议；对齐 DEC-013 决定 8 "plugin 不硬编码任何前端转发" 精神：转发义务是 orchestrator 内部动作，不是前端硬编码）。

**落点**（append-only clarification，不新开 DEC）：
- 3 处 prompt 本体 inline 加 ~3 行：`commands/workflow.md` Step 5 Escalation `text` 分支 / `skills/architect/SKILL.md` `decision_mode` 分支 text 段 / `skills/analyst/SKILL.md` `decision_mode` 分支 text 段
- 1 处 ref 继承：`commands/bugfix.md` 通过 Step -1 引用 `commands/workflow.md` 自动继承（不独改）
- 1 处规范落点：本 design-doc §3.1a

**检测启发式**（orchestrator LLM judgement，不强制硬算法）：
1. 最近一轮 inbound prompt 出现 `<channel source="...">` 开标签 → 命中
2. 本 session 内曾调用过该 channel 的 reply / edit_message 工具 → 命中（sticky，不按轮次衰减）
3. 两条都不成立 → 纯终端 session

**非目标**：
- 不改 DEC-013 决定 8 "展现与接收解耦" 边界（转发是 orchestrator 内部动作）
- 不改 4 agent prompt（developer/tester/reviewer/dba）
- 不抬 target CLAUDE.md 业务规则
- **本规则只解决 `<decision-needed>` 死锁**；phase A producer-pause summary / 普通对话 / FAQ 的转发策略 out of scope，由 orchestrator 按 channel sticky 语义自行判断，后续 issue 跟进

### 3.1.1 多决策块 emit 纪律（tester E7）

- **串行 emit** —— 一次 skill/orchestrator 激活最多 emit 1 个 `<decision-needed>` 块；若同轮有多个决策点，skill 内部 queue，依次在收到用户回复后 emit 下一个
- **不并发** —— 并行 agent 回传多个 `<escalation>` 时，orchestrator 按返回顺序**串行渲染**为 `<decision-needed>` 块，不在同一条消息同时 emit 多个（避免 `id` 引用歧义）
- **用户回复完成才解锁下一块** —— pause 状态下 orchestrator 只识别上一块 `id` 对应的回复，新回复来前不渲染下一个

### 3.1.2 `id` 命名空间（tester F5）

| 源 | 格式 | 示例 |
|----|------|------|
| skill 主动决策（architect / analyst） | `<slug>-<n>` | `decision-mode-switch-1` / `decision-mode-switch-2` |
| orchestrator 从 agent Escalation JSON 渲染 | `esc-<slug>-<n>` | `esc-decision-mode-switch-1` |

`<n>` 在同一 workflow session 内 monotonically 递增不复用；两个 namespace 独立计数（skill `-n` 与 `esc-` `-n` 互不影响）。`<slug>` 取本次 workflow 的 slug（orchestrator 已注入上下文）。

### 3.2 `commands/workflow.md` 改动

**顶部新增 bootstrap 段**（置于 Step 0 之前）：

```markdown
## Step -1: Decision Mode Bootstrap

解析 decision_mode（modal | text），注入所有 subagent / skill 派发：

1. CLI arg 扫描：`$ARGUMENTS` 含 `--decision=text` 或 `--decision=modal` → 取值
2. env 回退：Bash `echo $ROUNDTABLE_DECISION_MODE`；值 ∈ {text, modal} 有效
3. 默认：modal

注入规则：
- 每次 `Task` 派发 prompt prefix 加一行：`decision_mode: <value>`
- 每次 skill 激活 context prefix 加一行：`decision_mode: <value>`
- orchestrator 自身按 decision_mode 选择 Escalation 渲染路径（见 Step 5 补充）
```

**Step 5 Subagent Escalation 段内新增分支**：

```markdown
agent final report 出现 `<escalation>` block 时 orchestrator：

1. Parse JSON（`type` / `question` / `context` / `options` / `remaining_work`）
2. **按 decision_mode 分支**：
   - `modal` → 调 `AskUserQuestion` 原生弹窗（现行）
   - `text` → 渲染为 `<decision-needed>` 文本块输出到对话流：
     ```
     <decision-needed id="esc-<timestamp>">
     question: <question 字段>
     options:
       <for each option>：<label> — <rationale> / <tradeoff>
     </decision-needed>
     ```
     随后 pause 等用户自由文本回复
3. 用户回复后：fuzzy 解析选中 option 注入 prompt 重派**同一个** agent scope 限 `remaining_work`
```

### 3.3 `commands/bugfix.md` 改动

顶部 ref 一行：

```markdown
## Step -1: Decision Mode Bootstrap

见 `commands/workflow.md` Step -1 同款规则。bugfix 流程同样按 decision_mode 选择 Escalation 渲染路径。
```

### 3.4 `skills/architect.md` / `skills/analyst.md` 改动

在"关键决策点 AskUserQuestion 使用要点"段加条件分支：

```markdown
**decision_mode 分支**（orchestrator 注入的 context prefix 标注）：

- `modal`（默认）：调 `AskUserQuestion(question, options)` 原生弹窗（现行，不变）
- `text`：emit `<decision-needed>` 文本块到对话流，格式见 DEC-013：

  ```
  <decision-needed id="<slug>-<n>">
  question: <一句话>
  options:
    A（推荐）：<label> — <rationale> / <tradeoff>
    B：...
  </decision-needed>
  ```

  emit 后停下等用户自由文本回复；**不**继续调用任何工具。收到回复后 orchestrator 会把决策事实注入 skill 下一轮激活 prompt，skill 读到后续跑。
```

### 3.5 展现与接收解耦

text 模式**只规定**"决策以文本块形式 emit 到对话流"，**不负责谁接收**。下游由环境决定：

| 环境 | 接收路径 |
|------|---------|
| Telegram plugin 会话 | 块自然经 MCP 转到 TG；用户 TG 回复 |
| VS Code / 终端主会话 | 用户在 chat 里直接回复 |
| CI / 脚本化调度 | 自动化可 parse 决策块条件喂回选项 |
| 日志回放 | 决策块保留在对话记录里，可离线 review |

**plugin 不硬编码任何前端转发逻辑** —— 这是 Claude Code MCP 架构的天然边界：plugin 输出到 chat，MCP server（如 TG plugin）负责把 chat 内容转给远程前端。

### 3.6 用户回复解析（orchestrator LLM fuzzy）

orchestrator 本身是 LLM，直接读用户自由文本回复推断选中 option，不引入硬规则 parser。

**识别模式**（不穷举，示例）：
- 单字母：`A` / `选 A` / `选第一个`
- 带修饰：`A 但加 X` / `B 但 tradeoff 改为 ...` / `选 A 不过问题改成 Y`
- 中英混合：`go with C` / `choose B` / `选 C`
- 澄清请求：`B 和 C 区别详细讲讲` / `选 A 之前再问一下 ...` → orchestrator 不决策，继续对话

**歧义处理**（tester E4 澄清）：orchestrator 不确定时按顺序：
1. **首次歧义** → 直接对话澄清（如 "你是想选 A 还是 B？" / "你是想要 A 但修改 X 什么具体内容？"），**不**伪装决策、**不**自动选默认
2. **多块共存时歧义** → orchestrator 必须显式引用决策 `id`（如 "你刚才说的 A 是指 `decision-mode-switch-2` 那个决策吗？"），避免 id 错位
3. **用户明确不决策**（"都行" / "你看着办" / "没想法"）→ orchestrator 回问是否授权 architect 拍板；**绝不**替用户静默决策（违反 DEC-002 "绝不替用户决策"纪律）
4. **修改型回复**（"选 A 但 tradeoff 加一条 X"）→ orchestrator 把修改注入 prompt 连同 option 选择一起重派 subagent，在重派 prompt 里复述理解让用户 last chance 纠偏

## 4. 关键决策与权衡

> 完整决策见 DEC-013。此处为量化评分。

### 4.1 整体改动形状（D1）

| 维度 (0-10) | A 最小改动 ★ | B 统一改动 | C 分层改动 |
|------------|------------|-----------|-----------|
| critical_modules 命中面 | **9** | 3 | 7 |
| 现有 DEC 保留度 | **10** | 5 | 9 |
| 实施工作量 | **9** | 4 | 7 |
| 文档负担 | 8 | 6 | **9** |
| 未来演化灵活性 | 7 | 8 | **9** |
| **合计** | **43** | 26 | 41 |

### 4.2 集中落点（D5）

| 维度 (0-10) | A 独立 skill | B 各本体 inline | C shared helper | D 全散 inline ★ |
|------------|------------|--------------|---------------|--------------|
| tree 总行数 | 6 | 6 | 6 | **8** |
| per-workflow token | 5 | 7 | 4 | **9** |
| DEC-010 对齐 | 4 | 6 | 4 | **10** |
| 未来演化一致性 | **9** | 4 | 8 | 6 |
| 实施工作量 | 5 | 6 | 6 | **8** |
| **合计** | 29 | 29 | 28 | **41** |

### 4.3 优先级链层级（D6）

| 维度 (0-10) | A 3 级 ★ | B 6 级 | C 4 级（加 CLAUDE.md） |
|------------|---------|-------|-------------------|
| 文档清晰度 | **9** | 6 | 7 |
| 实施复杂度 | **9** | 5 | 6 |
| Claude Code 原生对齐 | **10** | 8 | 8 |
| DEC-011 / DEC-012 边界一致 | **10** | 10 | 3 |
| 用户配置灵活度 | 8 | 9 | **9** |
| **合计** | **46** | 38 | 33 |

## 5. 影响文件清单

| 文件 | 动作 | 增/改行数 |
|------|------|----------|
| `commands/workflow.md` | 新增 Step -1 Bootstrap + Step 5 Escalation 渲染分支 | ~8 行 |
| `commands/bugfix.md` | ref workflow.md Step -1 | ~4 行 |
| `skills/architect/SKILL.md` | AskUserQuestion 段加 decision_mode 分支 | ~5 行 |
| `skills/analyst/SKILL.md` | 同 architect，analyst 特化 `fact` 替 `rationale` + 禁 `★ 推荐` | ~5 行 |
| `README.md` + `README-zh.md` | 新增 §决策模式章节（英中镜像） | ~10 行 × 2 |
| `docs/design-docs/decision-mode-switch.md` | 新建（本文档） | - |
| `docs/decision-log.md` | 追加 DEC-013（置顶） | ~30 行 |
| `docs/exec-plans/active/decision-mode-switch-plan.md` | 新建（应用户 #256 要求） | - |
| `docs/testing/decision-mode-switch.md` | 新建（tester 产出） | - |
| `docs/INDEX.md` | 新增 design-doc + exec-plan 条目 | ~2 行 |
| `docs/log.md` | orchestrator flush 条目 | 自动 |

**不改**：5 agent prompt（`agents/developer.md` / `tester.md` / `reviewer.md` / `dba.md` / `research.md`）；DEC-002 / DEC-003 / DEC-004 / DEC-005 / DEC-006 / DEC-007 / DEC-008 / DEC-011 / DEC-012 任何 Accepted 条款；Phase Matrix / Step 4 并行判定树 / critical_modules 机械触发；target CLAUDE.md 业务规则边界。

## 6. 验收标准

对齐 issue #31 验收清单：

- [ ] `ROUNDTABLE_DECISION_MODE=text /roundtable:workflow ...` 下 analyst / architect 不再调 `AskUserQuestion`，改为 emit `<decision-needed>` 块
- [ ] `ROUNDTABLE_DECISION_MODE=modal` 或未设置时 behavior 与当前版本完全一致（零破坏）
- [ ] `--decision=text` CLI arg 能覆盖 env 的 `modal` 设置
- [ ] `.claude/settings.json` 的 env 块配置生效（Claude Code 原生三层合并 local > project > user）
- [ ] orchestrator 在 text 模式下收到用户自由文本回复后能正确恢复 workflow 把决策注入子 agent
- [ ] `README.md` 含 §决策模式章节说明 3 级优先级链和配置方式
- [ ] 本 workflow 自身即 text 模式 dogfood（Telegram 驱动的整个 issue #31 设计过程 —— 见 session 240~252 决策轨迹）

## 7. 实施原则：简洁优先（token 节约）

**每处改动行数硬纪律**：对照 §5 影响文件清单的预估行数，实际落盘不超 ×1.2；超出必须回到 architect 评审。

**具体规则**：
- 散文尽量压成表格 / 列表（`commands/workflow.md` bootstrap 段和 Escalation 分支段都用 bullet + 代码框，不长段落）
- 示例只给 1 个最小完整样例（不列 3 种变体）
- 不重复 rationale —— rationale 只在 DEC-013 / design-doc 一次，prompt 本体只放"做什么"不放"为什么"
- 条件分支用 if/else 伪码或 2 行表格，不用 3 段散文描述
- `skills/architect.md` + `skills/analyst.md` 的分支段共享模板 —— 两个 skill 写法完全一致（便于未来同步），diff 只在角色名
- README §决策模式章节 ≤10 行 —— 1 段介绍 + 1 个配置表 + 1 行链接 design-doc，不展开原理

**验收**（见 exec-plan P0.6）：
- 5 处改动实际总行数 ≤ 40（预估 35 × 1.2 = 42 上限）
- 单次 `/roundtable:workflow` 新增 per-workflow token 加载 ≤ 40 行（orchestrator 20 + skill 6 按需）
- `cargo xclippy` 类比 → `lint_cmd` 硬编码扫描 0 命中（`grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/`）

## 8. 实施路线（详见 exec-plan）

完整分阶段任务清单见 `docs/exec-plans/active/decision-mode-switch-plan.md`。摘要：

- **P0.1** orchestrator bootstrap + Escalation 渲染分支
- **P0.2** skill 条件分支（architect + analyst）
- **P0.3** bugfix.md ref
- **P0.4** README §决策模式 章节
- **P0.5** tester dogfood E2E（text 模式跑简单 issue 全链）
- **P0.6** reviewer 一致性巡视 + 行数纪律验收
- **P0.7** lint_cmd 扫描 + 闭环

## 9. 待确认项

无。Phase 1 决策点 D1~D7 全部收敛，见 session 232~252 Telegram 决策轨迹（本 workflow dogfood）。

## 10. 变更记录

- 2026-04-20 初版（architect skill + Telegram text 模式 dogfood 产出）
- 2026-04-20 追加 §7 实施原则：简洁优先 + §8 实施路线（应用户要求 message #256 —— 补 exec-plan + token 节约纪律）
- 2026-04-20 追加 §3.1a Active channel forwarding（issue #38 —— TG/CI 远程前端转发义务 append-only clarification；3 处 prompt 本体 inline 修复；不新开 DEC）
