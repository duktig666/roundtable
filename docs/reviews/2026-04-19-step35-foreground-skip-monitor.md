---
slug: step35-foreground-skip-monitor
reviewer: roundtable:reviewer (final review, issue #15 DEC-008 landing)
date: 2026-04-19
verdict: Approve
critical_modules_hit:
  - workflow command Phase Matrix + 并行判定树 + phase gating taxonomy (DEC-006)
  - Progress event JSON schema (DEC-004)
  - Escalation Protocol / decision-log append-only 铁律
scope:
  - commands/workflow.md §3.5.0
  - commands/bugfix.md §Step 0.5 delta 0
  - docs/decision-log.md (DEC-008 + DEC-004 status line)
  - docs/design-docs/subagent-progress-and-execution-model.md (frontmatter + §3.8 + §6)
  - docs/log.md combined entry
  - docs/INDEX.md testing entry
  - docs/testing/step35-foreground-skip-monitor.md
---

# DEC-008 落地终审：Step 3.5 前台派发免 Monitor

## 0. 审查结论

**Approve**。tester 前轮标记的 2 Critical + 3 Warning + 1 Suggestion 均已根因修复并在本轮复验通过；5 份 agent prompt Fallback 条款未被触碰且语义兼容；lint_cmd 0 命中；decision-log append-only 铁律遵守；与 DEC-004 / DEC-005 / DEC-007 的正交/supersede 关系在 DEC-008 条目与 design-doc §3.8 双向自洽。

## 1. tester 修复复验

| Ref | 原严重度 | 修复点 | 复验结果 |
|-----|---------|--------|---------|
| T12 | Critical | design-doc §3.8 引用从"§3.6 漏发降级"改为"§3.2 末句 漏 echo 时降级为静默" | design-docs/subagent-progress-and-execution-model.md:275 "按 §3.2 末句 ... 静默"；§3.2（line 136-158）末段确含 "subagent 遗漏 echo 时降级为'静默'" 条款，引用落点正确 |
| T13 | Critical | §3.7 标题丢失 → 恢复 `### 3.7 对并行派发判定树（DEC-002 §4）的影响`，§3.8 置于其后 | Grep 显示 `### 3.7` 在 line 255，`### 3.8` 在 line 264，顺序正确；`commands/workflow.md` §3.5.6 / `exec-plans/active/subagent-progress-and-execution-model-plan.md` 对 DEC-004 §3.7 的外部引用不再悬空 |
| T04 | Warning | §3.5.0 加 "evaluate this gate independently for each `Task` call" | workflow.md:143 "Evaluate this gate independently for each `Task` call — in a mixed parallel batch ... 1 foreground + 2 background ... produces exactly 2 progress_paths / 2 Monitor instances, not 3"，并给出混合批实例，措辞精准 |
| T09 | Warning | DEC-004 状态行从 "§3.6 触发规则" 改为 "决定第 6 项「触发规则」" | decision-log.md:138 已落地；歧义解除 |
| T14 | Warning | bugfix delta 0 显式枚举 skip 4 件事 | bugfix.md:34 "(a) do NOT generate DISPATCH_ID / PROGRESS_PATH, (b) do NOT run mkdir -p / touch, (c) do NOT launch Monitor, (d) do NOT inject the 4 progress variables"，与 workflow.md §3.5.0 的显式列举对称 |
| T15 | Suggestion | "(the default)" → "(currently the Claude Code default)" | workflow.md:146、bugfix.md:34 两处均已更新；与未来 Claude Code 默认行为可能翻转解耦 |

## 2. 本轮独立审查

### 2.1 DEC-008 条目质量
- 格式：日期/状态/上下文/决定(7)/备选(5)/理由(6)/相关文档/影响范围 齐全，匹配 DEC-007 先例。
- "决定" 7 条与 "备选" 5 条对 1:1 拒绝理由；"理由" 6 条覆盖 gate 位置 / skip 正确性 / 不改 agent / 与 DEC-005 同源 / 与 DEC-007 正交 / append-only 纪律，逻辑闭环。
- "影响范围" 明列 "不改 5 份 agent prompt 本体 / 不改 DEC-004 event schema / 不改 Monitor 工具 / 不改 target CLAUDE.md"，边界清晰且与实际 diff 完全对齐。

### 2.2 append-only 铁律
- DEC-004 原文保留（decision-log.md:136-160 仍为原 9 条决定），仅状态行在括号内追加 Superseded 注记。
- DEC-008 编号递增（DEC-007 → DEC-008），与 DEC-008 "备选" 段对 in-place patch 方案的否决理由一致。
- 铁律 1 / 2 / 3 全部遵守。

### 2.3 design-doc §3.8 完整性
- frontmatter `decisions: [DEC-004, DEC-005, DEC-008]` 新增 DEC-008。
- §3.8 4 段结构（motivation 表 / 决定 / 并行派发 / 实现位置 + 与 DEC-007/DEC-005 正交关系）与 DEC-008 条目一一映射。
- §6 变更记录第 2 条覆盖 DEC-008 落地动因 + 4 处 diff 范围。
- §3.7 标题存在（line 255），孤儿段问题已消除。

### 2.4 workflow.md Step 3.5 级联语义
- §3.5.0 → §3.5.1（env opt-out）→ §3.5.2 Bash → §3.5.3 Monitor → §3.5.4 注入 → §3.5.5 生命周期 → §3.5.6 并行安全。gate 先于 env 判定，级联顺序正确。
- 并行混合批实例（1 前台 + 2 后台 = 2 Monitor）与 DEC-002 §4 并行派发四条件兼容：PATH DISJOINT / SUCCESS-SIGNAL INDEPENDENT 对 skip 的前台 Task 天然不适用（无 progress_path 可冲突），对 2 个后台 Task 仍按 §3.5.6 逻辑保 disjoint。

### 2.5 bugfix.md delta 0 对齐
- 与 workflow.md §3.5.0 语义等价；四件 skip 枚举对称；"Evaluate independently for each Task call in a parallel batch" 亦显式出现；"Identical semantics to `commands/workflow.md` §3.5.0" 末句保留权威引用。

### 2.6 5 agent prompt Fallback 条款未动且兼容
Grep 验证：
- `agents/developer.md:186` — "empty, unset, or the file is not writable, silently skip all emits"
- `agents/tester.md:151` — "empty, unset, or the injection is missing entirely, silently skip all emit calls"
- `agents/reviewer.md:99` + `:156` — "missing or empty ... skip all emits silently"（含独立 `### Fallback on miss` 子节）
- `agents/dba.md:129` — "absent or empty ... silently skip emission"
- `agents/research.md:176` — "empty, unset, or the injection is missing entirely, silently skip all emit calls"

5 份 agent prompt 在 DEC-004 落地时已就位 Fallback，DEC-008 "空 progress_path 静默" 降级路径无须任何改动即生效。DEC-008 影响范围声明 "不改 5 份 agent prompt 本体" 与实际完全一致。

### 2.7 lint_cmd 扫描
`grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/` → 0 命中（exit 1）。满足 CLAUDE.md 条件触发规则 "prompt 本体修改 → lint 0 命中才可合并"。

### 2.8 DEC-007 / DEC-008 正交性验证
- DEC-007 修**源端内容质量**（5 份 agent prompt §Content Policy 子节 + orchestrator awk 折叠）—— 层次：content。
- DEC-008 修**触发条件**（commands 层 gate）—— 层次：trigger。
- 两者路径无交集：DEC-007 的 Content Policy 条款被 DEC-008 skip 掉整个 Step 3.5 的场景里根本不会被执行到（前台派发无 emit）；DEC-008 放行的后台派发场景里 DEC-007 的 dedup + 代理节拍条款正常生效。两条补丁可独立合并，先后顺序不影响最终语义。
- design-doc §3.8 末段 "与 DEC-007 的正交性" + DEC-008 决定 6 的描述自洽。

### 2.9 INDEX.md 维护
- `### testing` 新增 step35-foreground-skip-monitor.md 条目（INDEX.md:72），描述"18 cases：2 Critical / 3 Warning / 1 Suggestion → post-fix 全绿"准确概括测试文档内容。
- 未在 `### reviews` 提前占位（符合 Step 7 批处理，本审查完成后由 orchestrator 统一补入）。

## 3. 发现

### Critical
无。

### Warning
无。

### Suggestion
无新增。tester T15 的"(the default)"措辞漂移已修复；本轮未发现其他 Suggestion 级问题。

### Positive
- **append-only 纪律教科书级落地**：DEC-004 部分 Superseded 采用"状态行括号注记 + 原文逐字保留 + 新 DEC 显式引用"三件套，是未来类似 partial-supersede 场景的参考范式。
- **正交性双向自证**：DEC-008 条目 "理由" 5 与 design-doc §3.8 末段从 DEC-008 侧和 design-doc 侧各自独立陈述正交性，形成 cross-check，降低单侧漂移风险。
- **skip 语义 fail-safe 设计**：§3.5.0 显式列举 skip 4 件事（§3.5.2 Bash / §3.5.3 Monitor / §3.5.4 注入 / 不生成 path），消除 "skip Monitor 但仍生成 progress_path 致 silent buildup" 的隐形 bug（T18 关注点）。
- **inline developer ↔ 前台 Task 两条 skip 路径边界清晰**：§3.5.0 末段 Note "inline developer never enters this Step ... §3.5.0 applies strictly to Task-dispatched subagents" 精准划清"源头分流"与"内部 gate"两层语义。

## 4. 决策一致性检查

| DEC | 关系 | 核对结论 |
|-----|------|---------|
| DEC-001 D2 | 零 userConfig 边界 | ✅ DEC-008 不引入 CLAUDE.md 新 key，纯 plugin 元协议改动 |
| DEC-002 | Escalation Protocol | ✅ 未触碰；前台派发下 subagent 仍可在 final message 产出 `<escalation>` |
| DEC-003 | research fan-out | ✅ research agent §Progress Reporting Fallback 兼容 DEC-008 skip |
| DEC-004 | progress event protocol | ✅ 仅决定第 6 项「触发规则」Superseded；event schema / §3.1 motivation（后台场景下仍成立）/ §3.7 并行安全 全部继承 |
| DEC-005 | developer 双形态 | ✅ DEC-008 把 §6b.3 inline skip 逻辑同源推广到前台 Task，两条 skip 路径不重叠 |
| DEC-006 | phase gating | ✅ C-class verification-chain 下子 agent 派发不受 DEC-008 影响（DEC-008 仅调整 Monitor 触发条件，不改 phase 转场语义） |
| DEC-007 | progress content policy | ✅ 正交（content vs trigger 两层），互不触发，可独立合并 |

## 5. 总结
- **可合并**：是。
- **主要关注点**：tester 在 #15 落地过程中抓出的 T12 / T13 两枚 Critical 是 design-doc 编辑回归；修复已根因闭环，未在 DEC 条目或 commands 层留下任何遗漏副作用。本轮审查建议 orchestrator 在 issue #15 closeout 时把"§3.8 类 'patch 段' 插入需附带 §N.old heading 保留检查清单"作为 onboarding/contributing 的 soft guideline 备忘（非本 DEC 范畴，future issue）。
