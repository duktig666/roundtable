---
slug: lightweight-review
source: design-docs/lightweight-review.md
created: 2026-04-19
reviewer: reviewer subagent (critical_modules 多项触发 → 必落盘)
decisions: [DEC-009]
description: issue #9 DEC-009 轻量化重构终审 —— 4 shared helper 抽取 + log.md closeout batching + README/CLAUDE.md 结构重塑
---

# DEC-009 轻量化重构 终审 Review

> 对应设计：[lightweight-review.md](../design-docs/lightweight-review.md) / 执行计划：[lightweight-review-plan.md](../exec-plans/active/lightweight-review-plan.md) / 决策：[DEC-009 Proposed](../decision-log.md#dec-009)
>
> **判定结论**：**Approve-with-caveats** —— 0 Critical / 3 Warning / 4 Suggestion / 5 Positive。DEC-001 D1-D9 + DEC-002 ~ DEC-008 Accepted 条款完整保留；decision-log 3 条铁律全遵守；DEC-004 event JSON schema 未动（只搬运 emit 模板）；4 helper fan-out 引用一致；lint 0 命中。3 Warning 为文档层面不一致，**非阻塞**；可在 P0.7 收尾时 batch 修，或作为后续 minor patch。

---

## Critical

**无。**

> DEC-001 D1-D9（零 userConfig / role→form 单射 / skill+agent 混合 / Scope=user / D9 识别机制 等）、DEC-002（Resource Access + Escalation + Phase Matrix + 并行判定树，决定 1-4/6；决定 5 已被 DEC-009 决定 8 正式 Superseded，走了铁律 #2 "冲突报 diff" 流程）、DEC-003 research、DEC-004 event schema（§3.1 `ts`/`role`/`dispatch_id`/`slug`/`phase`/`event`/`summary` 必填 + `detail` 可选 —— helper 原样 quote，零字段偏移）、DEC-005 developer 双形态三级触发器、DEC-006 producer-pause / approval-gate / verification-chain 三段式 + Stage 9 Closeout、DEC-007 content policy 代理节拍 / 去重 / 差异化 / 终止-失败分离、DEC-008 §3.5.0 前台 / 后台 gate + 混合批例外 —— **全部实质保持**。**零实质条款变更未走 Superseded 流程**；DEC-009 本身走的是增量正交补强 + 1 处正式 Superseded（DEC-002 决定 5），完全合规 decision-log 铁律。

## Warning

### W-01: 设计文档 §5.1 + §5.3 + §8 的"DEC-009 决定编号"与 decision-log.md 实际编号错位

- `docs/design-docs/lightweight-review.md:212-214` §5.1 表格第 3 列处置标注 **DEC-009 决定 7 / 8 / 9**（分别对应 DEC-002 Superseded / bugfix.md fix / DEC 影响范围纪律）。
- `docs/design-docs/lightweight-review.md:229` §5.3 "新增 3 条（见 `decision-log.md` DEC-009 决定 7-9）"。
- `docs/design-docs/lightweight-review.md:240` §7 "DEC-009 决定 9 的'新增 DEC 影响范围 ≤10 行' 纪律..."。
- `docs/design-docs/lightweight-review.md:245` §8 变更记录 "新增 §5 + DEC-009 决定 7/8/9 + exec-plan P0.7"。

但 `docs/decision-log.md:61-63` 中 DEC-009 的**决定 8 / 9 / 10** 才对应同一 3 条（DEC-002 Superseded / bugfix.md fix / DEC 影响范围 ≤10 行 纪律）：

```
  8. 正式 Supersede DEC-002 决定 5
  9. 修 commands/bugfix.md 规则 2 对称性 bug
  10. DEC 影响范围段长度纪律
```

`commands/bugfix.md:62` 引用的是 **"DEC-009 决定 9"**（= decision-log.md 真实的决定 9 = bugfix.md fix），**该处正确**；同样 `docs/testing/subagent-progress-and-execution-model.md:95,172` 和 `docs/reviews/2026-04-19-subagent-progress-and-execution-model.md:51` 用 "Resolved by DEC-009 决定 9"，也对应 decision-log.md 真实的决定 9 —— 这些引用点指向 decision-log.md 的权威编号，**不受本 warning 影响**。而 `docs/log.md:25` 已用正确措辞"DEC-009 增决定 8/9/10" —— log.md 与 decision-log.md 一致。

**根因**：architect 在起草 design-doc §5.1 时按"DEC-009 前已有 6 条决定 → 新增 3 条编号为 7/8/9"推演，但实际落盘 decision-log.md 时 DEC-009 决定段扩到 10 条（原 7 条 + 新 3 条），导致 design-doc §5 的 3 条处置标注相对 decision-log.md 真实 # 都错位了 1。

**影响**：reviewer / tester / developer 读设计文档查"DEC-009 决定 7"时会跳到 decision-log.md 的决定 7（= "DEC-002 / DEC-004 / DEC-007 原文不打补丁"），**拿错语义**。属于 user-facing 文档一致性 bug。

**修复建议**：

- `docs/design-docs/lightweight-review.md` §5.1 表格第 5 列：决定 7 → 决定 8，决定 8 → 决定 9，决定 9 → 决定 10。
- §5.3 "决定 7-9" → "决定 8-10"。
- §7 "DEC-009 决定 9" → "DEC-009 决定 10"。
- §8 "决定 7/8/9" → "决定 8/9/10"。

单文件 4 处 Edit，无连锁。P0.7 收尾顺手修即可；非阻塞。

### W-02: DEC-002 status 行 Superseded 标注样式与 DEC-004 status 行样式不一致

- `docs/decision-log.md:233`（DEC-002）:
  `Accepted（决定 5 "prompt 文件本体统一英文" Superseded by DEC-009 决定 8 —— 2026-04-19 通过 ... ...）`
- `docs/decision-log.md:180`（DEC-004）:
  `Accepted（决定第 6 项「触发规则」Superseded by DEC-008 — 改为 ...）`

两条都对"部分 decision 被 Supersede" 采用了正确的"保留 Accepted 状态 + 括注标记"模式，但措辞样式有 3 点不一致：

1. 编号措辞：`决定 5 "..."` vs `决定第 6 项「...」`
2. 引号风格：英文双引号 `""` vs 中文方角引号 `「」`
3. 连接符：中文全角 em-dash `——` vs ASCII em-dash `—`

**影响**：样式不统一，不影响解析 / 语义；但未来若再出现第三条"Partial Superseded"，没有约定范式可照抄，每次需要 architect 临场裁决。

**修复建议**（任选其一；或 P0.7 收尾时 batch 统一）：

- (A) 把 DEC-002 状态行统一到 DEC-004 样式：`Accepted（决定第 5 项「prompt 文件本体统一英文」Superseded by DEC-009 决定 8 —— ...）`
- (B) 把 DEC-004 状态行统一到 DEC-002 样式。
- (C) 在 `docs/decision-log.md` 头部 "状态说明" 表下追加一句 "Partial-Superseded 标注范式：`Accepted（决定 N "..." Superseded by DEC-xxx 决定 M —— <reason>；其余决定仍 Accepted）`" 作为未来参照。

优先 (A) 或 (C)。非阻塞。

### W-03: bugfix.md 规则 2 措辞中英混合，与同段其他规则风格不一致

- `commands/bugfix.md:62` 规则 2 末尾含一段英文：

  > `... honor the declaration —— 这覆盖 bugfix 默认偏向 inline 的倾向。对称地处理两个值是 DEC-009 决定 9 对 DEC-005 §3.4.2 per-project 三级切换的 follow-through 修正 ...`

- 对比规则 1（`commands/bugfix.md:61`）和规则 3（`commands/bugfix.md:63`）都是纯中文描述 + 少量英文专名。

**根因**：DEC-009 决定 9 的原文用英文 fragment "`if target_project CLAUDE.md declares developer_form_default (either inline or subagent), honor the declaration — this overrides the bugfix inline-bias default.`" 作为"修正契约"。developer 在落地时选择了保留关键短语 "honor the declaration" 英文，中文解释包围，形成中英混杂。

**与 DEC-002 决定 5（已 Superseded）的关系**：DEC-002 原决定 5 是"prompt 文件本体统一英文"；DEC-009 决定 8 正式 Superseded 为"中文为主，关键专有名词保留英文"。本段英文片段 "honor the declaration" 是否算"关键专有名词"？属解释性短语而非 Claude Code / plugin 术语，严格按新约定应中文化。

**影响**：轻微 —— 阅读时中英切换。DEC-009 新约定的 spirit 是"英文仅保留 Claude Code / plugin 术语（工具名 / 字段名 / DEC-xxx / env var / `Task` / `Monitor` / `AskUserQuestion`）"，"honor the declaration" 不属此列。

**修复建议**：

```
2. **Target CLAUDE.md 偏好**：若 `target_project` CLAUDE.md 的「# 多角色工作流配置」里声明了 `developer_form_default`（`inline` 或 `subagent` 任一值），都必须生效 —— 这覆盖 bugfix 默认偏向 inline 的倾向。对称处理两个值是 DEC-009 决定 9 对 DEC-005 §3.4.2 per-project 三级切换的 follow-through 修正（见 `docs/testing/subagent-progress-and-execution-model.md` case 3.6 与 `docs/reviews/2026-04-19-subagent-progress-and-execution-model.md` W-R2）。
```

非阻塞；合并前或 P0.7 顺手修。

---

## Suggestion

### S-01: `docs/decision-log.md` 头部"条目格式"模板可加注 "影响范围 ≤ 10 行" 纪律

DEC-009 决定 10 新增"新增 DEC 影响范围 ≤ 10 行"append-only 纪律。但 `docs/decision-log.md:7-19` 的 "条目格式" 骨架只声明 `影响范围: 哪些部分受影响`，没有行数上限提示。未来 architect 添加 DEC-010+ 时易违反。

**建议**（改动微小）：在 `条目格式` 代码块的 `影响范围` 行加注：

```markdown
- **影响范围**: 哪些部分受影响（≤ 10 行；详细文件清单外放到关联 `design-docs/[slug].md ## 影响文件清单` — DEC-009 决定 10）
```

### S-02: 4 helper 行数较预估略超（447 vs 预估 250-320）

`skills/_resource-access.md` 58 + `skills/_escalation-protocol.md` 108 + `skills/_progress-reporting.md` 153 + `commands/_progress-monitor-setup.md` 128 = **447 行**，对比设计文档 §4.1 / §4.2 预估（每 agent 净省 35 行 × 4 agent = 140 行 + Step 3.5 省 85 = 225 左右）与 analyst 报告里 "4 helper ~250 行" 粗估偏长。

主要膨胀点：
- `_progress-reporting.md` 153 行 —— 含 `Granularity` / `Phase tag 命名` / "Developer 额外注意" 多段解释，可压缩
- `_progress-monitor-setup.md` 128 行 —— §Monitor-launch 的 awk 段详细解释占 10 行；`混合批示例` 与 workflow.md §3.5.0 的混合批说明略重复

**影响**：不达 issue §A "22-25%" 下沿风险 —— 仅靠 helper 抽取节省 ~(7 agent × 净省) - 4 helper = 略低于 issue 预期。但叠加 log.md append 模板删除（每 agent ~40 行 × 5 = 200 行）、README 删 3 节、CLAUDE.md §设计参考 删、workflow.md Step 3.5 压缩，**整体 22-25% 目标仍可达**（待 P0.5 dogfood 实际量化）。

**建议**：P0.5 dogfood 跑完后若实际减量 < 20%，二轮压 `_progress-reporting.md` 的"Granularity" / "Phase tag 命名"两段与 `_progress-monitor-setup.md` 的"混合批示例"段；否则接受现状。非阻塞。

### S-03: `docs/INDEX.md` helper 清单排序建议

`docs/INDEX.md:59-66` 新增的 "Plugin 内部 include-only helper" 清单 6 条按新增顺序列（detect / content-policy / resource-access / escalation / progress-reporting / monitor-setup），但混合了 `skills/` 和 `commands/` 两类路径。建议分组：

```markdown
**Plugin 内部 include-only helper**（下划线前缀约定；非独立可激活 skill；不在用户向 skill 清单露出）：

- `skills/_detect-project-context.md` — ...
- `skills/_progress-content-policy.md` — ...
- `skills/_resource-access.md` — ...
- `skills/_escalation-protocol.md` — ...
- `skills/_progress-reporting.md` — ...
- `commands/_progress-monitor-setup.md` — ... *(command-layer helper)*
```

路径按前缀 `skills/` → `commands/` 分组（skills 内部可按抽取时间或拉链顺序），让"子分类"一目了然。非阻塞。

### S-04: CHANGELOG.md 建议追加一条 DEC-009 "prompt restructure" 条目

`CHANGELOG.md` `[Unreleased]` section 已有 "P4 dogfood improvements" + "INDEX auto-maintenance" 等 2026-04-19 条目，但**未追加 DEC-009 条目**。本次是实质性文档 / prompt 结构重塑（4 helper + log batching + README/CLAUDE.md 瘦身），属于 `### Changed` 或 `### Added` 类别。

建议在 P0.6 DEC-009 Accepted 同时追加：

```markdown
### Added (lightweight refactor, 2026-04-19 — DEC-009)

- 4 shared helpers extracted from 7 roles / 2 commands: `skills/_resource-access.md` / `skills/_escalation-protocol.md` / `skills/_progress-reporting.md` / `commands/_progress-monitor-setup.md` (plugin-internal include-only pattern, aligned with `_detect-project-context.md` / `_progress-content-policy.md`)
- `commands/workflow.md` Step 8 "log.md Batching" — agents no longer append to log.md directly; orchestrator batches via `log_entries:` YAML block at A-pause / C-handoff / Stage 9 Closeout

### Changed (lightweight refactor, 2026-04-19 — DEC-009)

- README.md: §设计原则 expanded 5 → 7 items (integrates issue #9 §D 5 points); removed §致谢 / §贡献 / §许可证 (LICENSE / CONTRIBUTING.md standalone)
- CLAUDE.md: §设计参考 removed (lineage stays in `docs/design-docs/roundtable.md` D1-D9 scoring table)
- `commands/bugfix.md` 规则 2 now symmetrically honors `developer_form_default` for both `inline` and `subagent` values (DEC-005 follow-through per DEC-009 决定 9)
- `docs/decision-log.md`: DEC-002 决定 5 "prompt 文件本体统一英文" formally Superseded by DEC-009 决定 8 (post-hoc record of the 2026-04-19 memory-feedback reversal; honors decision-log 铁律 #2)
```

非阻塞；可放 P0.6 归档时统一操作。

---

## 决策一致性

| DEC | 审查点 | 结果 |
|-----|--------|------|
| **DEC-001 D1-D9** | 零 userConfig / role→form / skill+agent / Scope=user / D9 识别 / POC 增量策略 / 文档归属 | ✅ **全保持**。DEC-009 未触及 D1-D9 任一条；helper 抽取是正交优化（prompt 内部重排），不影响 role → form / plugin 架构 |
| **DEC-002** 决定 1（Resource Access 矩阵） | 7 角色完整 matrix 仍在本体；helper 只抽表头和 git 默认策略 | ✅ grep 验证 7 文件都有 `详见 skills/_resource-access.md` ref + 各自 role-specific 4 行 matrix（Read / Write / Report / Forbidden 全齐） |
| **DEC-002** 决定 2（Escalation + Option Schema） | 4 agent Escalation Protocol 仍在；skills/ Option Schema 完整 | ✅ grep 验证 4 agent 有 `详见 skills/_escalation-protocol.md` + role-specific typical triggers；analyst / architect 的 Option Schema section 原文保留 |
| **DEC-002** 决定 3（workflow Phase Matrix + 并行判定树 + exec-plan checkbox 串行化） | Phase Matrix 9 阶段、§4 并行判定树 4 条硬条件、Step 7 INDEX batching | ✅ `commands/workflow.md:20-38` Phase Matrix 9 阶段齐全；§4:160-173 4 条件判定树原样；Step 7 INDEX batching 不变 |
| **DEC-002** 决定 4（`_detect-project-context` inline Read） | 5 调用方 inline Read + 4 步执行 | ✅ grep 验证 workflow / bugfix / lint / architect / analyst 5 调用方都显式 "Read `skills/_detect-project-context.md`" + "inline 执行 4 步" |
| **DEC-002** 决定 5（prompt 统一英文） | 正式 Superseded by DEC-009 决定 8 | ✅ **决策日志铁律 #2 "冲突报 diff" 已补记**。DEC-002 status 行追加 "（决定 5 ... Superseded by DEC-009 决定 8 ——…）"。DEC-009 决定 8 明文 Superseded 声明 |
| **DEC-002** 决定 6（不 bump 版本） | `plugin.json` / `marketplace.json` 保持 | ✅ 未变（DEC-009 改 prompt 文档，不改 plugin metadata） |
| **DEC-003** research agent | 独立 agent、扇出 ≤ 4、`<research-result>` JSON、abort 非 escalation | ✅ `agents/research.md` 保留 Abort Criteria（**不**被 `_escalation-protocol.md` 污染）；`_escalation-protocol.md:12` 显式声明 "本 helper **不**适用于 `agents/research.md`"；Return Schema / parallel-safety 章节原样 |
| **DEC-004** event JSON schema + P1 push 模型 | 7 必填字段 + 3 event 枚举（`phase_start` / `phase_complete` / `phase_blocked`）+ `tail -F | jq --unbuffered -c` + `fromjson?` 容错 | ✅ **schema 零改**。`_progress-reporting.md:46` 7 字段齐全；`_progress-monitor-setup.md:54` jq pipeline 原样（含 `-R` / `fromjson?` / awk collapse）；不扩枚举（`phase_blocked` + `<escalation>` 组合仍复用，不新增 `done` / `error` event type） |
| **DEC-004** 决定 6（触发规则 Superseded by DEC-008） | `run_in_background: true` 派发才开启 | ✅ DEC-002 决定状态保持 Superseded 标注；`commands/workflow.md:139-148` §3.5.0 gate 完整保留；`_progress-monitor-setup.md:14` "Scope 前提"明确声明 "仅对满足 `run_in_background: true` 且未 opt-out 的 `Task` 派发执行" |
| **DEC-005** developer 双形态 | per-session / per-project / per-dispatch 三级触发器 + Resource Access 跨形态一致 + tester/reviewer/dba/research 仍 subagent-only | ✅ `agents/developer.md:10-28` Execution Form section 完整；§6b.2 三级触发原样；决定 9（bugfix.md 对称性）已在 `commands/bugfix.md:62` 落实（`inline` 和 `subagent` 都被 honor） |
| **DEC-006** 三段式 + Stage 9 Closeout | A/B/C 类别映射 + `<escalation>` scan 前置 + Step 7 C-桥接条款 | ✅ `commands/workflow.md:197-228` 三段式 + Phase Matrix mapping 表完整；Step 8 新增（log batching）同构 Step 7 + 沿用 "C-桥接条款" 心智 |
| **DEC-007** content policy | 代理节拍 / 去重 / 差异化 / 终止-失败分离 + 源端 + orchestrator 兼底 | ✅ `_progress-reporting.md:88-99` "Content Policy" 段引用 `skills/_progress-content-policy.md` + 示例保留在各 agent 本体；orchestrator 端 awk collapse 仍在 `_progress-monitor-setup.md:63` |
| **DEC-008** §3.5.0 前台/后台 gate | gate 位置 / 逐调用评估 / 混合批例外 / fallback 静默 skip | ✅ `commands/workflow.md:139-148` §3.5.0 gate 完整；`commands/bugfix.md:34` §Step 0.5 同语义简化；`_progress-monitor-setup.md:14` Scope 前提一致 |
| **DEC-009** 本身 | 10 条决定 + Proposed 状态 | ✅ 状态 Proposed（合规 —— 本审查通过后 P0.6 改 Accepted）；10 条决定齐全（1 helper/2 log batching/3-4 README/CLAUDE.md/5 critical_modules/6 引用模式/7 DEC 不打补丁/8 Supersede DEC-002 决定 5/9 bugfix.md 对称/10 DEC 影响范围纪律） |

**Decision-log 3 条铁律审查**：

1. **不删除旧条目** ✅ —— DEC-001 ~ DEC-008 原文全部保留（line count check：decision-log.md 282 行，编辑前 249 行前后对齐）
2. **冲突报 diff** ✅ —— DEC-002 决定 5 vs CLAUDE.md §通用规则"中文为主"的反转，通过 DEC-009 决定 8 补记 Superseded 链条，diff 完整（"2026-04-19 通过 `feedback_roundtable_prompt_language` 反转为..."）
3. **编号递增** ✅ —— DEC-001 ~ DEC-009，无空号无复用

**critical_modules 扩写 fan-out 风险评估（Critical 维度 §6）**：

CLAUDE.md `## critical_modules` 第 1 条扩写"含 `skills/_*.md` 与 `commands/_*.md` 共享 helper"是**预期行为**，不是 bug：

- **设计意图**：helper 改动 fan-out 到 5 agent + 2 skill，比单 agent prompt 改动更 critical（一处 bug 复制 N 处）。DEC-009 决定 5 明文选择"helper 全部纳入 critical_modules"而非"部分纳入 / 全不纳入"（后两者在备选里被列出并否决）。
- **工作流代价**：每次 helper 改动触发完整 tester + reviewer 流程。helper 改动频率远低于 agent 本体（本轮是第一次抽 helper，未来修订频率低 —— 日常 prompt 调整不改 helper，改 role-specific 部分）。
- **缓解**：`/roundtable:lint` 作为定期健康检查兜底（与 Step 7 INDEX 孤儿扫描同层）。helper 内部小修订（如修 typo、补说明）可通过 `critical_modules` 精确声明中的"helper ≠ 每字都触发 tester+reviewer" 收敛 —— 但本 DEC 未提供此精度，也是 **acceptable trade-off**（保守触发，宁可多跑 tester 也不漏）。

**结论**：该条扩写与 issue #9 原诉求（"轻量化 = 减 token 不减纪律"）一致。**不是 Critical**。

---

## Positive 亮点

1. **Escalation vs Abort 通道正交性双向护栏**。`_escalation-protocol.md:12` 开头即声明 "本 helper **不**适用于 `agents/research.md`"；`agents/research.md:49,89-91` 的 Abort Criteria 段也显式写 "**不要 emit `<escalation>`**。（Subagent 对 architect 没有直接通道...）"。两端互相指向 / 互相排除，避免 helper 抽取过程中把 research 的 abort 误判为 escalation。DEC-002 / DEC-003 正交性得到**源头级**硬保证。

2. **Progress Reporting 对 research 形态的 carve-out 书写得极其干净**。`_progress-reporting.md:12` Research 适用性段：`research 派发即便注入 {{progress_path}} 也不应 emit；其状态在 final message 的 <research-result> / <research-abort> JSON block 中一次性交付` —— 把 DEC-004 的 push 模型与 DEC-003 的 JSON block 单次交付明确区分，避免 helper 回写时错派 research 跟着 emit。`agents/research.md:117-119` 对应段落完全对称。

3. **Step 8 log.md Batching 与 Step 7 INDEX Maintenance 的同构设计**。`commands/workflow.md:319-399` Step 7 和 Step 8 结构对称（Collect / Merge / Read+Edit / Report 四段），flush 触发点共享同一 3 层心智（A-pause / C-handoff / Stage 9 Closeout）。对 orchestrator 实现的心智负担 = 0（两个 Step 只需复用同一 shared-resource 模式），对 tester / dogfood 验证负担 = 0（可复用 Step 7 的 18 cases 类型）。

4. **跨 session abort 退化声明的透明度**。`commands/workflow.md:399` 明确声明 "最近一段未经 pause-point flush 的 C 链 log_entries 永久丢失。缓解靠触发点 2 在每个 A 类边界清空 queue，实际丢失窗口仅限 3 agent 左右（dev→tester→reviewer 那段 C 链）"。`docs/design-docs/lightweight-review.md:76` §2.2.3 同样显式声明。不隐藏 trade-off、不模糊描述，符合 roundtable "显式决策点 + 纪律性兜底" 北极星。

5. **lint_cmd 0 命中 + helper 引用措辞精确对齐**。grep `skills/ agents/ commands/` 后 `gleanforge|dex-sui|dex-ui|\bvault/|\bllm/` 全 0 命中（已独立验证）；helper 引用统一为 "`详见 skills/_xxx.md（...）`" 格式 —— 7 个 `_resource-access.md` ref 措辞 100% 一致（`（通用骨架 + git 默认策略）`），4 个 `_escalation-protocol.md` ref 措辞 100% 一致（`（JSON schema + 通用规则 + Escalation vs Abort）`），4 个 `_progress-reporting.md` ref 措辞 100% 一致（`（注入变量 + emit 模板 + Granularity + Fallback + 与 Escalation 正交）`）。未来 grep / 替换维护成本最小。

---

## 总结

- **判定结论**：**Approve-with-caveats**。
  - 0 Critical：DEC-001 D1-D9 + DEC-002 ~ DEC-008 Accepted 条款全部保留；decision-log 3 条铁律遵守；DEC-004 event schema 不动；Resource Access / Escalation / Progress / Monitor Setup 4 helper 引用 fan-out 100% 一致；lint 0 命中。
  - 3 Warning：均为**文档层面的一致性问题**（design-doc §5 编号错位 / DEC-002 Superseded 标注样式与 DEC-004 不统一 / bugfix.md 规则 2 中英混合），**非阻塞实质功能**，可在 P0.7 DEC 修正阶段顺手 batch 修。
  - 4 Suggestion：均为可选增强（decision-log 条目格式模板注 ≤10 行 / helper 行数二轮压缩 / INDEX.md helper 清单分组 / CHANGELOG.md 追加 DEC-009 条目）。

- **是否通过**：P0.6 可在**完成 W-01/W-02/W-03 后**将 DEC-009 状态改 Accepted，移动 exec-plan 到 `completed/`，发 PR 合并。若 W-01 修过，后续贡献者读 design-doc §5 + decision-log 对齐无歧义。W-02 / W-03 可推迟到 minor patch。

- **主要关注点**（用 1-3 句话）：
  1. DEC-009 改动**纯属 prompt 文档层重组**（helper 抽取 + log batching 协议搬运），所有 Accepted DEC 的**实质条款零变更**；这是一次干净的正交优化。
  2. 唯一 Supersede（DEC-002 决定 5）走了 decision-log 铁律 #2 "冲突报 diff" 流程，append-only 纪律维持。
  3. 3 条 Warning 都是 "design-doc 起草阶段的编号推演与 decision-log.md 最终落盘有 1 位偏移" 类型的轻微一致性问题，**不阻塞合并**；P0.7 收尾时 4 处 Edit 即可修完。

- **log.md entries（由 orchestrator flush）**：

```yaml
log_entries:
  - prefix: review
    slug: lightweight-review
    files:
      - docs/reviews/2026-04-19-lightweight-review.md
    note: "DEC-009 终审 Approve-with-caveats；0 Critical / 3 Warning / 4 Suggestion / 5 Positive；DEC-001 D1-D9 + DEC-002~008 Accepted 条款全保；decision-log 3 铁律遵守；DEC-004 schema 零改；lint 0 命中；W-01 design-doc §5 决定编号错位（7/8/9 → 8/9/10）建议 P0.7 顺手修"
```

