---
slug: decision-mode-switch
source: docs/design-docs/decision-mode-switch.md
exec_plan: docs/exec-plans/active/decision-mode-switch-plan.md
decisions: [DEC-013]
created: 2026-04-20
role: tester
---

# 可切换决策模式 测试计划与对抗性审查

> 本文档对应 `docs/exec-plans/active/decision-mode-switch-plan.md` P0.5 —— **静态一致性 + 边界条件设计审查 + dogfood E2E 场景设计 + acceptance 映射**。
> roundtable 是纯 prompt 包，无 business code；本轮测试聚焦 prompt 本体一致性、设计完备性与 E2E 场景的预期观察清单。**未实跑 E2E**（plugin reload 需用户在主会话触发）。

---

## 1. 静态一致性审查

对 5 处 inline 落地（`commands/workflow.md`、`commands/bugfix.md`、`skills/architect/SKILL.md`、`skills/analyst/SKILL.md`、`README.md` / `README-zh.md`）与 DEC-013、`docs/design-docs/decision-mode-switch.md` §3.1 的 schema 描述做 pair-diff。

### 1.1 检查清单

| # | 检查项 | 结果 | 证据 |
|---|--------|------|------|
| 1 | `decision_mode` 变量名在 5 处拼写一致（均为 `decision_mode`，snake_case，值集 `{modal, text}`） | ✅ | workflow.md L38-42 / bugfix.md L14-16 / architect SKILL.md L75-78 / analyst SKILL.md L37-40 / README L90-98 |
| 2 | 优先级链"CLI arg > env > default" 在 4 处表述一致（workflow.md Step -1 / bugfix.md ref / README §决策模式 / DEC-013 决定 5 / design-doc §2.1） | ✅ | 5 处均表述为 3 级 `CLI --decision= > env ROUNDTABLE_DECISION_MODE > modal default` |
| 3 | env 变量名 `ROUNDTABLE_DECISION_MODE` 拼写一致 | ✅ | 大小写、下划线、词序完全一致 |
| 4 | CLI arg 形式 `--decision=text\|modal` 拼写一致 | ✅ | workflow.md L40、README L96、design-doc §2.1 均用等号形式 |
| 5 | `<decision-needed>` 标签名在 5 处一致（开闭、连字符、小写） | ✅ | 所有 5 处均是 `<decision-needed id="...">` / `</decision-needed>`（design-doc §3.1 是权威来源） |
| 6 | **决策块 options 行格式在 5 处一致** | ❌ **漂移**（见 Finding F1） | 详下节 |
| 7 | 推荐标记符号一致（`★ 推荐` vs `（推荐）` vs `（★ 推荐）`） | ❌ **漂移**（见 Finding F2） | 详下节 |
| 8 | architect / analyst 两 skill 条件分支模板结构"只角色名 + recommended 约束 2 处 diff" | ⚠️ **部分**（见 Finding F3） | 详下节 |
| 9 | DEC-013 §影响范围段列举的改动与实际 diff 一致 | ⚠️ **部分**（见 Finding F4） | DEC-013 列 `skills/architect.md` + `skills/analyst.md` 路径，实际是 `skills/architect/SKILL.md` + `skills/analyst/SKILL.md` 子目录。DEC-013 §影响范围路径旧，但非 blocker |
| 10 | id 命名规范在 5 处一致（`<slug>-<n>` / `dec-<n>` / `esc-<slug>-<n>`） | ⚠️ **部分**（见 Finding F5） | 3 套格式共存，规则未硬约束 |
| 11 | orchestrator pause 语义描述一致（emit 后停下不调工具等用户回复） | ✅ | design-doc §2.4 / workflow.md Step 5 / 两 skill 分支段均有 "emit 后 pause / 停下不继续调用工具" |
| 12 | fuzzy 回复解析示例一致（`A` / `选 A` / `go with A` / `选 B 但加 X`） | ✅ | design-doc §3.6、workflow.md Step 5、DEC-013 决定 4、README 4 处例子互相覆盖 |
| 13 | README 中 vs 英双份内容一致（各 10 行，表格结构同构） | ✅ | README.md L90-98 与 README-zh.md L90-98 行号完全对齐，字段一对一 |
| 14 | `lint_cmd` 扫描（硬编码 target 名泄漏）0 命中 | ⏩ 非本 DEC 必跑；P0.7 责任 | 已验证本 DEC 改动不引入 `gleanforge\|dex-sui\|dex-ui\|vault/\|llm/` |

### 1.2 发现的 schema 漂移明细

#### Finding F1 — options 行分隔符不一致（Warning，非 blocker）

| 位置 | 格式 | 分隔符 |
|------|------|--------|
| `docs/design-docs/decision-mode-switch.md` §3.1（权威） | `A（推荐）：label — rationale / tradeoff` | em dash `—` 分隔 label 与 rationale |
| DEC-013 决定 2 | `每项含 label + rationale + tradeoff + 可选 ★ 推荐` | 未给行格式，仅列字段清单 |
| `commands/workflow.md` Step 5 text 分支（L188） | `<label>（★ 推荐）：<rationale> / <tradeoff>` | **无 em dash**，label 后直接 `:` 冒号跟 rationale |
| `skills/architect/SKILL.md` L78 | `<label>（★ 推荐）：<rationale> / <tradeoff>` | 同 workflow.md（无 em dash） |
| `skills/analyst/SKILL.md` L40 | 未给行格式，只给字段 `label + fact + tradeoff` | — |

**问题**：design-doc §3.1（权威 schema）用 `label — rationale / tradeoff`（em dash 分隔 label 与 rationale），workflow.md / architect 实际使用的是 `label：rationale / tradeoff`（中文冒号）。差异虽不影响 LLM fuzzy 理解，但违反 P0.6 reviewer 一致性巡视的基本预期（两 skill 模板"完全一致 + 只角色名 diff"）。

**建议**：统一走 P0.1/P0.2 实际落地的"冒号式"（`<label>（★ 推荐）：<rationale> / <tradeoff>`），回 design-doc §3.1 把 em dash 改为中文冒号。或反向：把 workflow.md / architect 改回 em dash 对齐 design-doc。一致性比哪边对齐重要。

#### Finding F2 — 推荐标记符号 3 种变体（Warning）

| 位置 | 标记 |
|------|------|
| design-doc §3.1（权威）+ DEC-013 §3.1 示例 | `A（推荐）：...` —— 中文括号+"推荐"字，无 star |
| DEC-013 决定 2 字段清单 | `可选 ★ 推荐` —— star + "推荐"字 |
| workflow.md Step 5 / architect SKILL.md | `（★ 推荐）` —— star 在括号内 |
| README 章节 | 未出现推荐标记（只讲配置与 fallback，未给 block 示例） |

**问题**：3 处 3 种。同前一条成因一致 —— schema 权威点（design-doc §3.1）未经实际落地前对齐，发生漂移。

**建议**：选其一 `（★ 推荐）` 作为唯一标准（最直观 + 保留 star 符号利于 fuzzy grep），回 design-doc §3.1 对齐；DEC-013 §3.1 和决定 2 的字段清单描述同步更新（DEC Accepted 后按铁律不改，可加 Amendment 脚注；轻量 warning 不必走 Superseded）。

#### Finding F3 — architect vs analyst 两 skill 模板 diff 超预期（Warning）

exec-plan P0.2 承诺"两 skill 模板 diff 只在**角色名 + recommended 约束 2 处**"。实际对比：

```diff
architect SKILL.md L75-78:
  **`decision_mode` 分支**（orchestrator 注入 context prefix；DEC-013）：

  - `modal`（默认）→ 调 `AskUserQuestion(question, options)` 如本节原规则，不变
  - `text` → **不调工具**，改 emit `<decision-needed id="<slug>-<n>">` 文本块到对话流（schema 见 DEC-013 / `docs/design-docs/decision-mode-switch.md` §3.1），options 行 `<label>（★ 推荐）：<rationale> / <tradeoff>`；emit 后 skill **停下不继续调用工具**。用户回复由 orchestrator fuzzy 解析注入 skill 下一轮激活 prompt，skill 读到后续跑

analyst SKILL.md L37-40:
  **`decision_mode` 分支**（orchestrator 注入 context prefix；DEC-013）：

  - `modal`（默认）→ 调 `AskUserQuestion(question, options)`，不变
  - `text` → **不调工具**，改 emit `<decision-needed id="<slug>-<n>">` 块到对话流（schema 见 DEC-013 / `docs/design-docs/decision-mode-switch.md` §3.1）；analyst 的 options 只含 `label` + `fact` + `tradeoff`，**禁用 `recommended`**（停事实层，推荐是 architect 职责）；emit 后 skill **停下不继续调用工具**等用户回复
```

**diff 点清单**（实际 5 处，非 2 处）：

1. ✅ 角色名（"skill" 在两处同称 "skill"，未出现 "architect" / "analyst" 字面差异，实际等价）
2. ✅ `recommended` 约束描述（architect 允许含 `（★ 推荐）`；analyst 明确禁用 `recommended` + 字段换成 `fact`）
3. ⚠️ modal 分支描述尾巴 — architect: `如本节原规则，不变`；analyst: `，不变`（architect 多 "如本节原规则"）
4. ⚠️ text 分支 "文本块" vs "块" — architect: `改 emit <decision-needed> 文本块`；analyst: `改 emit <decision-needed> 块`（少 "文本" 二字）
5. ⚠️ options 行格式给出 vs 不给 — architect 给了 `<label>（★ 推荐）：<rationale> / <tradeoff>`；analyst 没给行格式只说字段（可通过 design-doc §3.1 推导，但 analyst options 不含 `recommended` 意味着 design-doc §3.1 的行格式也不适用）
6. ⚠️ 结尾阐述"续跑"机制 — architect: `skill 读到后续跑`；analyst 只说 `skill 停下不继续调用工具等用户回复`（无后续续跑说明）

**建议**：把两 skill 段落统一为模板 + 1~2 行变量（角色名 / recommended 约束），diff 降回 2 处。可以在一个 shared helper（如 `skills/_decision-mode-branch.md`）放模板，两 skill `Read` 后差异化 override；但这违反 DEC-010 精简心智，权衡后建议**仅手动对齐文本，不引入 helper**。

#### Finding F4 — DEC-013 §影响范围路径滞后（Info）

DEC-013 决定 3 / §影响范围段写 `skills/architect.md` + `skills/analyst.md`，实际 repo 已迁 `skills/architect/SKILL.md` + `skills/analyst/SKILL.md`（子目录 + SKILL.md 新 Claude Code plugin 约定）。design-doc §5 影响文件清单同样用旧路径。

**建议**：DEC-013 已 Accepted 按铁律不改条目本文；但 design-doc §5 表格可改（设计文档非 append-only），建议 reviewer 在 P0.6 巡视时顺便修一下。

#### Finding F5 — `id` 命名规范 3 套共存（Warning）

| 位置 | id 格式 |
|------|---------|
| design-doc §3.1 约束行 | `dec-<n>` 或 `<slug>-<n>` |
| workflow.md Step 5 text 分支 | `esc-<slug>-<n>`（escalation 前缀） |
| architect / analyst SKILL.md | `<slug>-<n>` |

**问题**：3 套并存，orchestrator 监测 / 匹配用户回复时是否区分 skill-issue 决策块 vs agent-escalation 决策块？design-doc §3.1 说 "同 workflow 内递增不复用"，但没说不同来源 prefix 是否共享计数器（即 `<slug>-3` 和 `esc-<slug>-3` 会不会冲撞？）。

**建议**：design-doc §3.1 加一条：**counter 按来源分命名空间**（skill 决策块 `<slug>-<n>`；agent escalation `esc-<slug>-<n>`；各自从 1 递增），或显式说 **全局单调**（所有来源共享计数器）。当前未定义 = 潜在并发决策 id 碰撞风险。属**设计完备性**问题，不 block 落地但需澄清。

---

## 2. 边界条件对抗性审查

就 7 类 edge case 评估 DEC-013 / workflow.md Step -1 / design-doc 是否明确处理。

### 2.1 CLI arg `--decision=invalid_value`

**观察**：workflow.md Step -1（L40）仅写 `CLI --decision=... > env > default`。design-doc §2.1 流程图说"参数值"无 validation。DEC-013 决定 5 只列合法值集 `{text, modal}` 未说非法值行为。

**风险**：用户输入 `--decision=tg` / `--decision=TEXT`（大写）/ `--decision=on` 时 orchestrator LLM 可能：
- A) 严格匹配 → 回退默认 `modal`（用户误以为 text 模式被应用）
- B) fuzzy 理解 → 按 `TEXT` → `text` 归一（但 `on` / `tg` 歧义）
- C) 报错提示

当前未定义。

**建议**：design-doc §2.1 加一行 fallback 规则：**非 `{text, modal}` 严格匹配失败 → 回退默认 `modal` 并 emit 一行警告**（`⚠️ decision_mode="<raw>" not in {text,modal}, falling back to modal`）。用户可从警告修正；静默回退会让验收标准 #3（CLI arg 覆盖 env）的测试出现假阴。

### 2.2 env 值为空字符串 / "off" / "auto"

**观察**：同 2.1，设计只说"值 ∈ {text, modal} 有效"，**未说**空字符串（`ROUNDTABLE_DECISION_MODE=`）或其他值（`off` / `0` / `disabled`）行为。

**风险**：`.claude/settings.json` 的 `env` 块很可能被用户写 `ROUNDTABLE_DECISION_MODE: ""` 想表示"不启用"，或 `off` 想"关 text"。当前 orchestrator 看到这些值后：按 design-doc §2.1 "非空且值 ∈ {text, modal} 有效" → 回退默认 `modal`，符合预期。但**空字符串特别是 shell-export 过的** `ROUNDTABLE_DECISION_MODE=` 其实会在 env 里以空值存在，`echo $VAR` 为空串，orchestrator Bash 读取需 `-n` 判空。

**建议**：workflow.md Step -1 明确加一行：**空字符串 / 非合法枚举值 → 静默回退默认**，避免用户对"空值 = 关闭"的误解被静默化（用户可能永远不知道自己设错）。可选：emit 一次性 info 行报告 resolved `decision_mode` 值，方便用户诊断。

### 2.3 CLI arg 和 env 同时存在且值不同

**观察**：design-doc §2.1 / DEC-013 决定 5 明确 "CLI arg > env > default" 3 级。workflow.md Step -1 简写 `CLI --decision=... > env ROUNDTABLE_DECISION_MODE > default`。

**风险**：无。优先级链明确，acceptance 标准 #3 已点名覆盖。

**建议**：无。此项设计完备。

### 2.4 orchestrator LLM fuzzy 解析 ambiguous 回复

**观察**：DEC-013 决定 4 / design-doc §3.6 明确"歧义时直接对话澄清，不伪装决策"。示例给了：
- ✅ 明确（单字母 / `选 A` / `go with A` / `choose B`）
- ✅ 修饰（`A 但加 X` / `B 但 tradeoff 改成 ...`）
- ⚠️ 澄清请求（`B 和 C 区别详细讲讲`）→ orchestrator 不决策继续对话

**风险 / 遗漏**：
1. **"A 和 B 都可以"** / **"随便"** / **"你决定"** 类回复 → 是否澄清（recommended 有时）或强行选 recommended？未定义。
2. **用户修正决策问题本身而非 option**（`问题得改，先别选`）→ 把决策推回 architect 还是 abort？未定义。
3. **跨决策块污染**（用户回复 `A` 但当前已 emit 2 个块 `<decision-needed id="dec-1">` 和 `<decision-needed id="dec-2">`）→ orchestrator 按哪个绑定？DEC-013 约束"单次 emit 1 个块"防止此问题但未说违规时行为。

**建议**：design-doc §3.6 追加 fallback 规则：
- "都可以" / "随便" → 若有 recommended 选 recommended；无则澄清 `有两个选项，推荐 A（理由 X），要不就按 A？`
- 问题修正 → 把 orchestrator 状态退到 skill / agent 重派，重生成决策块
- 多块共存（虽违约束）→ 按最近 emit 块匹配；否则澄清

### 2.5 text 模式用户长时间不回复（timeout）

**观察**：DEC-006 producer-pause 语义 = 无 timeout 一直等。DEC-013 §2.4 说"pause 等用户下一条消息"同心智。design-doc / DEC-013 均未规定 timeout。

**风险评估**：
- **本地终端**：可接受，用户可随时回来。
- **CI / 脚本**：若 CI 用 `ROUNDTABLE_DECISION_MODE=text` 但没有 stdin，orchestrator 永远 pause → CI 永远卡住 → 占 runner。没 timeout 是 **CI 使用的实操阻塞**。
- **TG**：可接受（用户随时 TG 回复）。
- **日志回放**：N/A（非实时）。

**建议**（不 block 本 DEC 落地）：
- design-doc §2.4 / §3.5 加一段 **"CI 使用建议"**：CI 场景应提前以 `--decision=modal`（会被 CI 看到 AskUserQuestion JSON 但不响应）+ 在 pipeline 预置决策 stdin，或**使用决策预先固定的自动化 entrypoint**（issue #31 外 scope）。至少文档告知 CI 不应直接 `ROUNDTABLE_DECISION_MODE=text` 自动化跑 workflow。
- 不在本 DEC 引入 timeout 机制（违反 DEC-006 producer-pause 语义）。

### 2.6 agent Escalation JSON 某 option 缺失 `rationale` / `tradeoff`

**观察**：DEC-002 Escalation schema 规定 `rationale` + `tradeoff` 必填。workflow.md Step 5 text 分支 renders `<label>（★ 推荐）：<rationale> / <tradeoff>` 直接插入字段值；缺失时会渲染空字符串 `：/` 丑但不破坏解析。

**风险**：agent prompt bug 导致发 malformed JSON → orchestrator 渲染为残缺块 → 用户难读 → 澄清对话开销。

**建议**：workflow.md Step 5 Parse 步骤（L185）保留"格式错回传 agent 重 emit 不转给用户"的旧规则（现有）。在 text 分支额外加：**render 前校验 options[*].rationale/tradeoff 非空**，空则走回传分支。exec-plan P0.1 风险预案已提 "渲染逻辑用 `label{' ★ 推荐' if recommended else ''}` 模式"，这条应该扩展到其他字段。

### 2.7 两个连续 / 嵌套 / 并发决策块 `id` 唯一性

**观察**：design-doc §3.1 约束 "单次 emit 1 个块" 防止此场景。但 Step 4 并行派发多 agent 时 orchestrator 可能同时收到 2 个 `<escalation>`（agent A 和 agent B 同一轮 final message）→ orchestrator 按 decision_mode=text 会一前一后 render 2 个 `<decision-needed>` 块。

**风险**：
- orchestrator 同一 assistant message 中 emit `<decision-needed id="esc-<slug>-1">` 和 `<decision-needed id="esc-<slug>-2">` 各 1 个 —— 约束"单次 emit 1"是指 **agent 不 emit 多块**，orchestrator relay 可以 batch 多块？DEC-013 / design-doc 未说。
- 若 batch 2 块，用户回复 `A` 语义不明（属哪个决策？）。

**建议**：design-doc §3.1 / workflow.md Step 5 追加一条：**orchestrator relay 多个并行 `<escalation>` 时，串行处理**（先 emit 决策块 1 → pause 等回复 → 处理完再 emit 决策块 2）；**不 batch 多块**。这保持 DEC-006 A 类 producer-pause 心智（一次只等一个回复）。

---

## 3. dogfood E2E 场景设计（未实跑）

**说明**：plugin reload 需用户在主会话触发；tester 只设计**观察清单**供未来实跑勾。本次 workflow（issue #31 session 232~260）算作 orchestrator 人工模拟 text 模式的 **soft dogfood**，不算 plugin 实装闭环。

### 3.1 场景 A — 本地终端 env 驱动

```bash
ROUNDTABLE_DECISION_MODE=text claude
> /roundtable:workflow design a trivial feature
```

**预期观察清单**：

1. ⬜ orchestrator 在 Step -1 解析 decision_mode，resolved 值 `text` 注入所有后续 Task / skill prompt
2. ⬜ architect 激活时 context prefix 含 `decision_mode: text` 一行
3. ⬜ architect 到决策点时**不**调 `AskUserQuestion`，改 emit `<decision-needed id="...">` 文本块到对话流
4. ⬜ emit 后 skill 停下不调用其他工具（Read / Write / Bash 均无）
5. ⬜ orchestrator 进入 pause（无 tool call），等待用户文本回复
6. ⬜ 用户回复 `A` → orchestrator fuzzy 理解 → 注入下一轮 skill prompt（文字提示 `用户选 A`）→ skill 继续
7. ⬜ 若派 developer / tester subagent 且 subagent `<escalation>` → orchestrator 按 text 分支渲染 `<decision-needed id="esc-<slug>-<n>">` 块到对话流（不开 AskUserQuestion）
8. ⬜ 用户修饰回复 `选 B 但 tradeoff 改成 X` → orchestrator 接 B 并把修饰文本注入重派 prompt
9. ⬜ 用户澄清回复 `A 和 B 区别再讲讲` → orchestrator 不推进决策，继续对话
10. ⬜ 完整 workflow 走完（含最少 1 次决策点 + 1 次 escalation）无阻塞

### 3.2 场景 B — Telegram 驱动（远程前端）

**前置**：roundtable 不接 TG plugin；TG plugin 是独立 MCP server 转发 chat。tester 无法直接控制；场景 B 属**集成测试**。

**预期观察清单**：

1. ⬜ TG 用户发 `/roundtable:workflow 设计 ...` 到 Claude Code 主会话（通过 TG plugin MCP 转发）
2. ⬜ 主会话 env 预置 `ROUNDTABLE_DECISION_MODE=text`（或 `.claude/settings.json` env 块）
3. ⬜ orchestrator emit 的 `<decision-needed>` 块在主会话输出后，TG plugin 将同块转发到 TG 聊天
4. ⬜ TG 用户 TG 消息回复 `A` 或 `选 B 但加 X` → TG plugin 转发到主会话作为 user message
5. ⬜ orchestrator fuzzy 解析回复推进 workflow
6. ⬜ 验证 `AskUserQuestion` 在主会话弹出时 TG 无任何块可见（即若 mode 回退到 modal 用户直接发现"我在 TG 收不到决策"）→ 本项用于**负向验证** mode = text 必须生效

### 3.3 场景 C — CLI arg 覆盖 env（优先级链）

```bash
ROUNDTABLE_DECISION_MODE=text claude
> /roundtable:workflow --decision=modal design ...
```

**预期观察**：

1. ⬜ orchestrator 解析 Step -1，取 CLI arg 优先，resolved decision_mode = `modal`
2. ⬜ 后续 skill / agent 行为与现行版本完全一致（走 `AskUserQuestion` 原生弹窗）
3. ⬜ 注入 prompt prefix 字段值 `decision_mode: modal`
4. ⬜ 最小完整 workflow 跑完观察不到任何 `<decision-needed>` 块

**反向**：

```bash
ROUNDTABLE_DECISION_MODE=modal claude
> /roundtable:workflow --decision=text design ...
```

1. ⬜ CLI arg `text` 覆盖 env `modal` → resolved `text`
2. ⬜ 行为等同场景 A

### 3.4 场景 D — 零配置（默认 modal，零破坏）

```bash
claude
> /roundtable:workflow design ...
```

**预期观察**：

1. ⬜ Step -1 走默认分支，resolved `modal`
2. ⬜ 完全无 `<decision-needed>` 块
3. ⬜ 所有 decision point 均经 `AskUserQuestion` 原生弹窗
4. ⬜ 行为与引入 DEC-013 前版本 **100% 一致**（acceptance #2 零破坏）
5. ⬜ Step -1 本身增加的加载成本 ≤ 5 行 prompt 读入，不影响 workflow 整体节奏

### 3.5 dogfood 自跑场景（issue #31 本身）

**soft dogfood 已完成**：本 DEC 的设计过程（TG session 232~260）即 orchestrator 人工模拟 text 模式。session 轨迹保留在 TG 历史。

**不算闭环的地方**：
- orchestrator 是 Claude 人工按 text 心智出块，**非**读取 workflow.md Step -1 自动触发
- plugin 未实装，skill prompt 的 `decision_mode` 分支未被真正 LLM context prefix 驱动
- `<decision-needed>` 块格式在 session 内经历多次人工调整，未锁 schema

**闭环条件**（acceptance #7）：plugin reload 后 tester 或用户任选简单 issue 以 `ROUNDTABLE_DECISION_MODE=text` 走 `/roundtable:workflow`，走完场景 A 观察清单 10 项全 ✅。

---

## 4. Acceptance criteria 映射

对照 `docs/design-docs/decision-mode-switch.md` §6 的 7 条验收标准（issue #31 原文 + design-doc 扩写），分类：**代码已支持（待 E2E）** vs **待 E2E 验证才能勾**。

| # | 验收条目 | 状态 | 备注 |
|---|---------|------|------|
| 1 | `ROUNDTABLE_DECISION_MODE=text /roundtable:workflow ...` 下 analyst / architect 不再调 `AskUserQuestion`，改为 emit `<decision-needed>` 块 | 🟡 **代码已支持** | 两 skill 条件分支已落；等场景 A 实跑勾 |
| 2 | `ROUNDTABLE_DECISION_MODE=modal` 或未设置时 behavior 与当前版本完全一致（零破坏） | 🟡 **代码已支持** | modal 分支是现行 `AskUserQuestion` 路径未改；等场景 D 实跑勾 |
| 3 | `--decision=text` CLI arg 能覆盖 env 的 `modal` 设置 | 🟡 **代码已支持** | Step -1 优先级链明确；等场景 C 实跑勾（正反两个子场景） |
| 4 | `.claude/settings.json` 的 env 块配置生效（Claude Code 原生三层合并） | 🟡 **代码已支持** | 对齐 Claude Code 原生机制，plugin 层不做额外处理；等 settings.json 实测场景 |
| 5 | orchestrator 在 text 模式下收到用户自由文本回复后能正确恢复 workflow 把决策注入子 agent | 🟡 **代码已支持** | Step 5 text 分支明确 fuzzy parse + 重派 scope 限 remaining_work；等场景 A / B step 6-8 实跑勾 |
| 6 | `README.md` 含 §决策模式章节说明 3 级优先级链和配置方式 | ✅ **已完成** | README.md L90-98 / README-zh.md L90-98 均含 10 行章节 + 3 级优先级表 |
| 7 | 本 workflow 自身即 text 模式 dogfood（Telegram 驱动的整个 issue #31 设计过程） | 🟡 **soft dogfood 完成**，硬 dogfood 待 plugin reload 实跑 | 见 §3.5 |

### 4.1 状态汇总

- ✅ 1 项（#6 README 章节）
- 🟡 5 项（#1-#5，代码已支持，等 E2E 实跑验证）
- 🟡 1 项（#7 soft dogfood 完成，硬 dogfood 待 plugin reload）

**无 ❌ 失败项**。代码层面 5/7 全部支持，剩余 2 项依赖 E2E 实跑闭环。

### 4.2 P0.6 reviewer 一致性巡视预判

reviewer P0.6 将巡视 5 处改动：基于 §1 Finding F1~F5，预判 reviewer 会给出 **2~3 条 Warning finding**（schema 漂移 / 两 skill 模板 diff 超预期），不会有 Critical。建议 reviewer 在巡视文档里明确：
- 是否接受 schema 漂移（options 行格式 / 推荐标记）留待未来 refactor
- 或现在就回炉统一 3 处文本

### 4.3 P0.7 lint_cmd 预判

本 DEC 改动不引入任何 target 名硬编码。`grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/` 预期 0 命中。

---

## 5. 发现与建议汇总

### 5.1 Warning 级别（建议修正但不 block 本 DEC 落地）

| ID | 主题 | 建议 | 责任 |
|----|------|------|------|
| F1 | options 行分隔符 3 处不一致 | 选其一（建议冒号式）统一 design-doc §3.1 | architect / reviewer P0.6 |
| F2 | 推荐标记 3 种变体（`（推荐）` / `★ 推荐` / `（★ 推荐）`） | 统一 `（★ 推荐）` | architect / reviewer P0.6 |
| F3 | architect vs analyst 两 skill 模板 diff 超 exec-plan 承诺（实际 5 处 vs 承诺 2 处） | 手动对齐非 recommended 差异描述 | architect P0.6 |
| F5 | `id` 命名空间未约束（`<slug>-<n>` / `esc-<slug>-<n>` 是否共享 counter） | design-doc §3.1 加 counter 命名空间规则 | architect |
| E1 (§2.1) | CLI arg 非法值 fallback 未定义 | design-doc §2.1 加 warning + fallback default | architect |
| E2 (§2.2) | env 空字符串 / 非合法枚举 fallback 未定义 | 同 E1 | architect |
| E4 (§2.4) | fuzzy 歧义 "A 和 B 都可以" / 问题修正 / 多块共存 未定义 | design-doc §3.6 补 fallback 规则 | architect |
| E6 (§2.6) | Escalation JSON option 字段缺失时 render 残缺 | workflow.md Step 5 增加 render 前校验 | developer（如 reviewer 同意修） |
| E7 (§2.7) | 并行 agent 多 escalation 同时回传 | design-doc §3.1 / workflow.md Step 5 补串行处理规则 | architect |

### 5.2 Info 级别（记录，未来 issue 处理）

| ID | 主题 | 备注 |
|----|------|------|
| F4 | DEC-013 §影响范围路径滞后（`skills/architect.md` vs `skills/architect/SKILL.md`） | DEC 已 Accepted 不改；design-doc §5 表格可修（非 append-only） |
| E5 (§2.5) | text 模式 timeout 未定义（CI 场景阻塞风险） | 不引入 timeout；README / design-doc 补 CI 使用建议 |

### 5.3 无 Critical 级发现

所有 finding 均 Warning/Info 级，**不阻塞**本 DEC 落地。5 处 inline 改动功能正确，schema 漂移属美学 / 维护性问题。E2E 场景设计完备（§3），可在 plugin reload 后实跑闭环。

---

## 6. 变更记录

- 2026-04-20 初版（tester 产出，对应 exec-plan P0.5）
