---
slug: orchestrator-preflight-hardening
source: 原创（issue #89）
created: 2026-04-22
---

# Orchestrator Pre-flight Hardening 分析报告

## 背景与目标

issue #89 提出在 `commands/workflow.md` 的 §Step -0 / §Step -1（参数 bootstrap）与 §Step 3（artifact handoff）注入**强制经验化**（empirical）痕迹——把当前完全依赖 orchestrator LLM "读 spec + 应用" 的隐式流程，下沉为**必跑的 Bash echo + 显式角色映射表**，消除 #84 session 暴露的两类 cold-start 误判：(i) `auto_mode` 源被误当成 Claude Code harness Auto Mode；(ii) `analyst` 被当作 subagent 错派。

L1（memory 层）已完成；本报告仅服务于 L2 `commands/workflow.md` 结构化改动的事实层调研。

## 追问框架

**必答 2 问**

1. **失败模式最可能在哪里？**
   - (a) Bash echo 写成但 orchestrator 在后续 Task prompt prefix 注入时仍按旧 LLM 推断填 `auto_mode`，bash 输出与 prompt prefix 两路不一致 → 用户看到 echo 对但下游行为错（"echo-prefix 脱钩"）。
   - (b) Bash echo 结果未按 memory `feedback_tg_workflow_updates_to_tg.md` 转发到 TG，远端用户仍看不到校验行 → 形同未加。
   - (c) 7 角色映射表嵌入 §Step 3 起首，但 §Step 6 rule 4（`workflow.md:382-384` 现址）保留同构文字 → 产生 §22 "行内 DEC/issue 引用纪律" 禁止的**散点重复**；后续单边改一侧会 drift。
   - (d) Bash 块在 Step -0 位置被 orchestrator 跳过执行（Step -0/-1 位于 Step 0 之前，检测 4 步尚未跑 → 如果 Bash 块依赖 `$CLAUDE_PLUGIN_ROOT` 等变量，时序上要验证这些变量此时已由 Claude Code runtime 注入）。
2. **6 个月后回看是否变成债务？**
   - 若 L2 改动只是在 prompt 本体添加 echo 片段与表格，无单一权威节纪律，后续 DEC 容易反复在 Step -0 / Step 3 / Step 6 rule 4 同步修改；与 `feedback_roundtable_token_economy.md` 的 "单一权威节 / ≤30 行/DEC / 表格优于 bullet" 纪律冲突。反之若把 7 角色映射表**从 §Step 6 rule 4 原地移到 §Step 3 起首**（搬家而非复制），债务可控。

**按需 4 问**：本任务属内部 prompt 强化（非绿地新需求），痛点 / journey / 最简方案 / 竞品对比按需跳过说明：

- 痛点（已知）：issue #89 正文 "同根分析" 段已定义。
- 使用者与 journey：orchestrator LLM 自身 + 用户（尤其 TG 远端）。
- 最简方案：L2 两处改动本身就是最简；L3 (SessionStart hook) 显式排除（issue 非范围）。
- 竞品对比：不适用（plugin 内部强化，无可比的外部方案）。

## 调研发现

### 事实 F1：§Step -0 / §Step -1 现状为 prose 规则，无可执行校验

- `commands/workflow.md:40-54` 两节纯 prose：声明优先级（CLI > env > default）、注入规则（Task prompt prefix + skill context prefix 加一行）、适用/不适用场景。
- 无 Bash 块。orchestrator 只能靠 LLM 读懂后在后续派发时"手工"填 prefix 行。
- Step 0 `inline 执行 4 步检测`（`workflow.md:58`）有**明确的 "inline 执行" 动词 + Read 文件路径**，执行强度高于 Step -0/-1。

### 事实 F2：`auto_mode` 解析优先级与 env 列表完整定义在 workflow.md:42

> CLI `--auto` > env `ROUNDTABLE_AUTO ∈ {1, true, on, yes}`（其他值 / 空串 / 未设 → 视为 false）> default。`--no-auto` 显式关闭（覆盖 env 开启）。

`decision_mode` 优先级定义在 workflow.md:50：CLI `--decision=...` > env `ROUNDTABLE_DECISION_MODE` > default(`modal`)。

env 变量名已在 memory `feedback_roundtable_auto_mode_source.md:19` 明确要求 `echo "ROUNDTABLE_AUTO=${ROUNDTABLE_AUTO:-<unset>}"` 作为 Step -0 的显式校验。

### 事实 F3：7 角色形态当前散布在 §Step 6 rule 4 与 memory

- `workflow.md:382-384`（§Step 6 "执行规则" 第 4 条）当前文本：
  > **4. 角色形态**：
  > - `architect` / `analyst` = **skill**（主会话；`AskUserQuestion` 可用）
  > - `developer` / `tester` / `reviewer` / `dba` = **agent**（subagent；`AskUserQuestion` 不可用）
- 现状**不含 `research`**；issue #89 正文与 memory `feedback_skill_vs_agent_dispatch.md` 都把 research 明确列入 agent 侧（architect 派发）。
- memory 映射表已含 7 行（含 research），且含 developer DEC-005 inline/subagent 双形态例外。

### 事实 F4：Step 6b (Role Form Selection) 覆盖 developer/tester/reviewer/dba 的 inline ↔ subagent 切换（DEC-005 + DEC-023）

- `workflow.md:415-436` 已规定四角色的三级切换（per-session / per-project / per-dispatch）。
- research 显式排除（`workflow.md:436`）：`*_form_default` 不覆盖 research。
- analyst/architect 无 inline/subagent 双形态——永远 skill（memory `feedback_skill_vs_agent_dispatch.md:24-25`）。

### 事实 F5：Step 5b 事件类 a 是 "Step 0 context + Step 1 size/pipeline" 的转发事件

- `workflow.md:297`：事件类 a = "Step 0 context detection 结果 + Step 1 size/pipeline 判定"，`markdownv2` 结构化（粗体标题 + 反引号字段值 + bullet 清单，DEC-022）。
- 事件类 a 来源 = orchestrator Step 0/1；issue 提到 "Step 5b 事件类 a 围栏转发 pre-flight echo" —— 事实上**事件类 a 当前 scope 不含 Step -0/-1**，pre-flight echo 若转发需扩 a 的定义或新增事件类。
- memory `feedback_tg_workflow_updates_to_tg.md:18` 判断标准："若只在终端输出，用户下一句是否会问'进度如何' → 是则必 TG"；pre-flight echo 显然命中（用户用 TG 下第一感要看 auto_mode 值）。

### 事实 F6：Bash 块在 workflow.md 已有先例（§3.5.1），可直接复用样式

- `workflow.md:194-200` §3.5.1 定义 Progress Monitor 的 Bash 块：```bash 围栏 + 多行 echo + 变量赋值。前例 + 说明性 prose（`touch` race 防护）。
- 可作为 §Step -0/-1 Bash 块的**格式模板**（同 plugin 保持一致性）。

### 事实 F7：memory 中 auto_mode 的 echo 建议句式已给定

- `feedback_roundtable_auto_mode_source.md:19`：
  > Step -0 执行时必须显式 `echo "ROUNDTABLE_AUTO=${ROUNDTABLE_AUTO:-<unset>}"` 验证
- 只覆盖 env，**未**覆盖 CLI flag 与 resolved 输出；实现时需扩展（见 §开放问题）。

### 事实 F8：critical_modules 命中路径

- CLAUDE.md §critical_modules 表第 6 行：`workflow Phase Matrix + Step 4 Task 并行判定 + Step 4b 决策并行（DEC-016）+ phase gating（DEC-006）` 命中。
- CLAUDE.md §条件触发规则：`修 skill/agent/command prompt 本体 → 跑 lint_cmd，0 命中才合并`；`新增/改 Phase Matrix stages → 同步更新 § Step 3 artifact chain`（本 issue **不改** Phase Matrix stages，仅改 §Step 3 起首嵌入，此条触发面待 architect 判定）。
- 行内 DEC/issue 引用纪律 (#22) 适用：若 L2 改动引入 `（DEC-005）` 括注式引用，需走白名单判断。

## 对比分析

### (a) Bash pre-flight echo 的"应该 surface 什么"

现有约束与候选范围：

| 维度 | 事实 | 候选 |
|------|------|------|
| Raw inputs 可见性 | env 由 shell `${VAR:-<unset>}` 可直读；CLI flag 由 Claude Code runtime 传给 command，**shell 看不到** | env 可 echo；CLI flag 需 orchestrator LLM 依据 `$ARGUMENTS` / 当前调用参数自行判读后填入 echo 文本 |
| Resolved 输出 | `auto_mode` / `decision_mode` 二值；source 注记 4 路（CLI / env / default / `--no-auto` 显式关）| 单行 `auto_mode=<v> (source=<...>)` + 同构 decision_mode 行 |
| 对 Claude Code Auto Mode 系统提示的显式 disclaimer | memory `feedback_roundtable_auto_mode_source.md` 是判据 | echo 文本内加一行 `(Claude Code Auto Mode != roundtable auto_mode)` 注释，或 prose 段另写 |
| 终端 vs TG 双通道 | memory `feedback_tg_workflow_updates_to_tg.md`：若仅终端则 TG 用户看不见 | 终端 `echo` + 后续按 Step 5b 事件类 a 转发（需扩 a 的 scope 或新增事件） |
| 执行位置 | §Step -0 / §Step -1 prose 目前在 Step 0 之前 | Bash 块落 Step -0 还是合并一个 "§Step -0.5 Pre-flight echo" 单独节？ |
| 输出 prefix sentinel | §3.5.1 前例用裸 `echo DISPATCH_ID=...` 无 sentinel | 可用 `PREFLIGHT:` sentinel 便于日志 grep / §3.4 fuzzy parse 复用 |

客观代价差异：

- **放 §Step -0 原节末尾** vs **新建 §Step -0.5**：前者零新节（token 省），后者单一权威节（§Step -0 prose 规则与 §Step -0.5 可执行校验分层）；§Step 0 有"inline 执行 4 步"先例倾向前者，但 §3.5.1 的 Bash 块实际是独立子节（`3.5.1 Opt-out + Bash 准备`）倾向后者。
- **echo 覆盖 env only** vs **echo 覆盖 env + CLI**：前者实现简单、echo 文本确定；后者需 orchestrator 每次 parse `$ARGUMENTS` 填 CLI 值，echo 文本含 LLM 插值，脱钩风险变大（见失败模式 (a)）。
- **转发 TG**：若扩事件类 a 的 scope 覆盖 pre-flight echo，`Step 5b` 表第 297 行文字需改 → critical_modules 命中、触发 tester 强制。若不转发，则违反 `feedback_tg_workflow_updates_to_tg.md` 纪律。

### (b) 7 角色映射表的"放哪"

两个候选位置：

| 候选 | 现场 | 改动面 | 单一权威节 | 信息密度 |
|------|------|-------|-----------|---------|
| **C1：嵌入 §Step 3 起首** | §Step 3 当前是 "Slug 与 Artifact Handoff" 段，首句 "选 kebab-case slug 贯穿全阶段" + Artifact 链代码块 | §Step 3 首段加 1 张表 + 1 段说明；同时**移除** §Step 6 rule 4 同构 2 行 bullet | 可达成（单一权威）：§Step 6 rule 4 改成 "见 §Step 3 §形态映射"，省 2 行 bullet | 与 artifact 链紧邻，语义稍远（artifact 链是"产出物"，形态映射是"派发调用形式"） |
| **C2：新建 §Step 2.5 "Dispatch Form Reference"** | Step 2 (Tester 触发, `:132-134`) 后、Step 3 前插入 | 新节；不挪 §Step 6 rule 4 亦可（但仍需让 §Step 6 rule 4 点指针过来避免 drift） | 单一权威达成：§Step 6 rule 4 改指针；§Step 6b 已有的"research 排除"补一行指针即可 | Step 2.5 纯为"调用工具映射"服务，语义内聚高 |

结构约束：

- 现有节号序列含 `Step 0.5`、`Step 3.4`、`Step 3.5`、`Step 4b`、`Step 5b`、`Step 6b`，引入 `Step 2.5` 与既有命名惯例**兼容**。
- `commands/workflow.md` 已 540 行；C1 增量 ~5-8 行（新表 + 挪除 2 bullet），C2 增量 ~10-15 行（新节标题 + 首段 + 表 + 指针）。
- 与 DEC-005（developer 双形态）/ DEC-023（tester/reviewer/dba 双形态）/ DEC-003（research 非用户 trigger）的交叉引用——两候选都需在表里标注或脚注。
- `feedback_roundtable_token_economy.md` 纪律倾向 C1（增量小 + 表格 + 单一权威）；但 C2 的**关注点分离**在 LLM 读时可能更显眼（表单独成节，首段扫描命中率高）。

### (c) 架构师应知的风险 / 回归

| 维度 | 观察 | 风险等级（事实） |
|------|------|-----------------|
| Shell call 语义 | §Step 0 inline 执行 `_detect-project-context.md` 已涉及 Bash（第 2 步工具链探测扫文件）；§Step -0 新 Bash 块是增量调用非首次 | 低：前例存在 |
| 变量时序 | `${ROUNDTABLE_AUTO:-<unset>}` 直接 shell 解析，不依赖 Step 0 session 记忆 | 低：时序独立 |
| CLI flag echo 可行性 | orchestrator shell 无 `$1 $2` 等位置参，`$ARGUMENTS` 语义是 command template 展开后的剩余串；`--auto` / `--decision=text` 能否从 shell 侧 echo 需**实测** | 中：实现时验证 |
| 单一权威节 drift | 现有 §Step 6 rule 4 / memory / 新 §Step 3 或 §Step 2.5 三点同构 → 后续改一需同步三 | 中：纪律问题，可控 |
| §Step 5b 事件类 a scope 扩张 | 若 pre-flight echo 必转发，a 定义需改 → 命中 CLAUDE.md critical_modules 第 6 行 → tester 强制回归测试 | 高：已在 issue #89 labels 中预判 |
| #22 行内引用纪律 | 新表若用 `（DEC-005）` 括注式 → 违纪；需用白名单形式 "详见 docs/design-docs/...-plan.md" 或 "见 §Step 6b" 内部跳转 | 中：architect 决策时需遵守 |
| `analyst` 阶段被误 skip | 本 issue L2 不涉 analyst skip 路径；`feedback_analyst_not_auto_skip_umbrella.md` 已是 L1 memory 固化 | 低：非本 issue 覆盖面 |

## 开放问题清单（事实层）

- **OQ1（Bash 覆盖 CLI flag 的可行性）**：orchestrator 在 `/roundtable:workflow` command 执行环境中，shell `$*` / `$ARGUMENTS` 能否直读 `--auto` / `--decision=text` token？事实：现有 workflow.md 无任何 Bash 块引用 `$ARGUMENTS`，需 architect 在设计时实测决定 echo 文本是否含 CLI 源。
- **OQ2（pre-flight echo 转发路径）**：§Step 5b 事件类 a 当前 scope = "Step 0 context + Step 1 size/pipeline"，不含 Step -0/-1 pre-flight。是(i) 扩 a 的 scope / (ii) 新事件类 / (iii) pre-flight 合并进事件类 a 的同一条 reply —— 归属方案事实上未定。
- **OQ3（映射表是否含 `research`）**：现 §Step 6 rule 4 不含 research，memory 含。若 §Step 3（或 §Step 2.5）新表含 research，§Step 6 rule 4 若改指针同时要确保不漏 research（与 §Step 6b `workflow.md:436` 的 research 排除规则协同）。
- **OQ4（表格格式）**：memory `feedback_skill_vs_agent_dispatch.md` 表 3 列（角色 / 形态 / 调用方式），§Step 6 rule 4 现状用 bullet。architect 需决定 L2 落地用哪种列组合（是否加 "DEC 依据" 列 / "inline 例外" 列）——影响行数与可读性。
- **OQ5（Bash 块是否需 PREFLIGHT sentinel）**：§3.5.1 前例无 sentinel；若加便于日志 grep 但增量行数 +1。
- **OQ6（`--no-auto` 显式关 echo 分支）**：`workflow.md:42` 定义 `--no-auto` 覆盖 env 开启；echo 文本是否需独立分支显示该场景，或只输出 resolved 值 + source 注记合并。
- **OQ7（§Step 6 rule 4 搬家 vs 保留指针）**：若采 C1（§Step 3 首段嵌表），§Step 6 rule 4 的 2 行 bullet 是**删** vs **改为 1 行指针**？前者更精简，后者更抗 drift。事实：两者都满足单一权威节原则。

## FAQ

（无；首轮报告）

---

log_entries:
  - prefix: analyze
    slug: orchestrator-preflight-hardening
    files:
      - docs/analyze/orchestrator-preflight-hardening.md
    note: "issue #89 L2 preflight hardening feasibility; Bash echo scope + 7-role dispatch table placement tradeoffs surfaced"
