---
slug: bugfix-rootcause-layered
source: docs/design-docs/bugfix-rootcause-layered.md
created: 2026-04-20
status: Draft
decisions: [DEC-014]
related_issue: "#37"
description: 对抗性审查 DEC-014 bugfix 根因分层落盘在 4 文件（commands/bugfix.md / commands/workflow.md / docs/log.md / docs/claude-md-template.md）的落地；对 Tier 决策树完备性 / 灰区门 UX / YAML schema 反向兼容 / 白名单 3 处同步 / postmortem 硬约束 / 底座文件不受影响 / INDEX 分类可发现性 / DEC-008 正交性 / DEC-010 token 纪律 / critical_modules 触发面 10 组风险做静态对抗
---

# DEC-014 bugfix 根因分层落盘测试计划（prompt 层静态对抗）

## 0. 测试范围与形式

- **范围**：DEC-014 落地的 4 个 prompt 本体 diff + 1 份 design-doc + 1 份 decision-log 条目。
- **形式**：静态对抗（读源 + grep / 逻辑推演），不写可执行测试代码（dogfood 运行时验证由 issue #37 自身闭环承担）。
- **不做**：执行 E2E bugfix dogfood；改 developer 已落地的 prompt 文本；新增独立 executable 测试框架。
- **覆盖目标**：用户指定 10 条对抗性审查重点 + critical_modules（CLAUDE.md §1 条第 1/6/8 项命中）必要项。

## 1. 当前覆盖现状

**已有测试**（DEC-008 / DEC-010 / DEC-013 系列）：
- `docs/testing/lightweight-review.md` — DEC-009/010 白名单 + batching 契约
- `docs/testing/decision-mode-switch.md` — DEC-013 `<decision-needed>` canonical schema 与 fuzzy 解析
- `docs/testing/subagent-progress-and-execution-model.md` — DEC-004/005 Monitor + form switching

**DEC-014 面的 gap**：
- 三档 tier 判定决策树的边界条件未测
- `fix-rootcause` 前缀白名单 3 处同步未对比
- postmortem 硬约束在 orchestrator closeout 侧的可执行性未验
- 扩展 YAML 字段（`root_cause` / `fix_summary` / `reproduction`）对旧 entry 的向后兼容未验
- `bugfixes/` 在 INDEX.md orphan 扫描与 Step 7 identify category 的 end-to-end 可发现性未验

## 2. 静态对抗结论（overall）

| # | 审查项 | 结论 | 严重度 | 备注 |
|---|--------|------|--------|------|
| 1 | Tier 判定决策树完备性 | **PASS-with-Warnings** | W1/W2 | 边界用例 2 处模糊 |
| 2 | 灰区 decision-needed 门 + 简单 bug 捷径 | **PASS-with-Warning** | W3 | 50 字阈值 i18n 歧义 |
| 3 | YAML schema 反向兼容 | **PASS** | — | 可选字段 + 首条非空，旧 entry 零影响 |
| 4 | 前缀白名单 3 处扩完整性 | **PASS** | — | 3/3 同步；design-doc 源镜像未改（历史只读，合规） |
| 5 | Postmortem 硬约束可执行性 | **FAIL** | **C1** | Closeout gate 缺执行锚 |
| 6 | `_detect-project-context.md` 不受影响 | **PASS** | — | grep 0 命中；未枚举子目录 |
| 7 | `docs/INDEX.md` 分类 auto-create | **PASS-with-Warning** | W4 | INDEX.md 缺 `### bugfixes` section 头 |
| 8 | DEC-008 正交性 | **PASS** | — | flush 触发点 / 合并规则 / Read+Edit 步骤零改 |
| 9 | DEC-010 token 纪律 | **PASS** | — | 实测 +57 行（bugfix.md 28 + workflow.md 11 + log.md 17 + template.md 1）；未超 "≤60" 预算 |
| 10 | critical_modules 命中触发面 | **PASS** | — | §1 项第 1/6/8 命中机械可识别 |

1 Critical（C1）+ 4 Warning（W1-W4）。C1 需 developer 补 orchestrator 端可执行锚点。其余 Warning 建议 follow-up 不阻塞合并。

## 3. 详细对抗记录

### 3.1 【项 1】Tier 判定决策树完备性（PASS-with-Warnings）

**源**：`commands/bugfix.md` L49-60（Tier 判定决策树 + 灰区问询门）+ design-doc §2/§3.1。

**验证路径**（6 个边界用例）：

| Case | 输入 | 规则落点 | 预期 | 实际 prompt 行为 | 结论 |
|------|------|---------|------|----------------|------|
| T1 | 单文件 + 单模块 + critical_modules 命中 | L54 硬自动 | Tier 2 | "硬自动 Tier 2 无问询" | PASS |
| T2 | 3 文件 + 2 模块 + 无 critical | L55-58 灰区 recommended ★ Tier 1 | Tier 1 | 启发式 "≥2 文件 或 跨模块 → Tier 1 ★" | PASS |
| T3 | 单文件 + 单模块 + 无 critical + summary=30 字 | L54 捷径 | Tier 0 | "summary ≤50 字 且 单文件 → 直接 Tier 0" | PASS |
| T4 | 单文件 + 单模块 + 无 critical + summary=55 字 | 不捷径 → 灰区 | Tier 0 ★ | 启发式命中 Tier 0 ★ | PASS |
| **T5** | **改动量大（500 行）但单文件** | 模糊 | ? | **prompt 未对 LOC 维度表态** | **W1** |
| **T6** | **涉多模块但未命中 critical 但涉 DEC** | L53 "涉 DEC" 条 vs L55 灰区 ≥2 模块 | Tier 2 | "涉 DEC → 硬自动 Tier 2" vs "灰区 Tier 1 ★"；**两条都匹配**，规则顺序语义上 L54 "硬自动 Tier 2" 节里第 3 条 "or 涉 DEC" 被 **"按序判定"** 覆盖（先判硬自动再判捷径再判灰区）—— **但 bugfix.md 落地文本只写了 "critical_modules 命中 **或** 涉 DEC **或** 生产事故 label"**，design-doc 与落地一致，OK | PASS |
| **T7** | **"生产事故 label"** | L53 "生产事故 label" | Tier 2 | **"生产事故 label" 语义未定义 —— 哪里打标签？CLAUDE.md？issue label？prompt 里用户声明？** | **W2** |
| T8 | critical 命中 + 用户 prompt 显式声明 Tier 0 | 优先级冲突 | ? | prompt 明确 "L54 硬自动无问询"，但未声明用户 override 是否允许 | **W2 合并** |

**结论**：硬自动 / 捷径 / 灰区三档机械判定对"文件数 / 模块数 / critical 命中"三轴清晰；对 LOC 量（T5） / 生产事故 label 语义（T7） / 用户 override（T8）未覆盖。

- **W1（Warning）**：Tier 判定未把"LOC / 改动量"纳入轴；单文件 500 行改动 fall through 到捷径 Tier 0，但实际可能值得 Tier 1 entry。建议 follow-up 在灰区启发式加一行 "LOC > 200 → Tier 1 ★"。
- **W2（Warning）**：
  - "生产事故 label" 未定义来源。建议 bugfix.md L53 补 `（来源：GitHub issue label `severity:production` / 用户任务描述含 "生产事故/线上"）`。
  - 用户 prompt 显式声明 Tier（如 `--tier=0`）是否允许 override critical 硬自动？design-doc §2 "Tier 2 上升条件优先级" 说 "任一命中直接 Tier 2 不降级"，但没说用户可否显式降。建议补一句 "用户显式 Tier 声明不可 override critical 硬自动" 或反之。

### 3.2 【项 2】灰区 decision-needed 门 + 简单 bug 捷径（PASS-with-Warning）

**源**：`commands/bugfix.md` L54-58。

- L54 "summary ≤50 字 且 单文件 → 直接 Tier 0"。
- L56 灰区走 `<decision-needed>`（text）或 `AskUserQuestion`（modal），沿用 `commands/workflow.md` §Step 5 渲染路径（DEC-013）。

**对抗**：

- **W3（Warning）**：**"50 字"阈值在 LLM 自评稳定性差 + i18n 歧义**。
  - 中文 50 字 ≈ 英文 100 字符（ratio 2:1）。若用户用英文描述 "Fix off-by-one in pagination boundary"（49 字符含空格 = 49 "字"英文词，汉字定义下可能按 49 或按 5 words），prompt 未声明单位（字符 / 字 / token / 词）。
  - LLM 自评 "summary 长度" 缺乏 grounding，多次相同输入可能跨 50 阈值浮动。
  - 建议：改成 "≤200 字符（含中英文字符）" 客观可计量；或改成语义判据 "根因 1 句可说清" 放弃精确阈值。
- **PASS 项**：灰区门复用 DEC-013 `<decision-needed>` 既有 schema 与 fuzzy 解析；text / modal 分支走向清晰。

### 3.3 【项 3】YAML schema 反向兼容（PASS）

**源**：`commands/workflow.md` §Step 8 L302-309（扩展渲染规则）+ L316（前缀白名单）+ design-doc §4.2-4.3。

**验证**：

| Case | 场景 | 预期 | 落地 prompt 行为 | 结论 |
|------|------|------|----------------|------|
| Y1 | 旧 `fix` entry（不含 root_cause） flush | 按 4 行基础模板渲染 | workflow.md L296-300 模板未变 | PASS |
| Y2 | 新 `fix-rootcause` entry 缺 `reproduction` | "字段缺省则整行省略"（L306） | prompt 明确声明 | PASS |
| Y3 | 新 `fix-rootcause` 同轮 2 entry（developer + reviewer）各带不同 root_cause | 取首条非空（L309） | prompt 明确 | PASS |
| Y4 | 新 entry `files:` 不含 postmortem 路径（Tier 1 场景） | 不渲染 "关联 postmortem" 行 | L307 "files: 含 postmortem 路径时" 反向等价 "否则不渲染" | PASS |
| Y5 | 旧 `fix` 前缀 + 新 `fix-rootcause` 前缀同轮并存（developer 双报） | 两独立条目 | Step 8 L298-300 合并规则 "同 agent 同轮多 entry 合并" —— **但是 prefix 不同** 不合并 | PASS |

**结论**：PASS。可选字段 + 首条非空 + prefix 独立 3 层保障向后兼容。

### 3.4 【项 4】前缀白名单 3 处扩完整性（PASS）

**源对比**：

| 文件 | 行 | 白名单 |
|------|----|------|
| `commands/workflow.md` L316 | `analyze \| design \| decide \| exec-plan \| review \| test-plan \| lint \| fix \| fix-rootcause` | 9 项 ✅ |
| `commands/bugfix.md` L127 | "沿用 workflow §Step 8 白名单，新增 `fix-rootcause`" | ref + delta ✅ |
| `docs/log.md` L162-171 | 前缀规范表 9 行（含 `fix-rootcause` L171） | 9 项 ✅ |

**未改镜像（合规）**：

- `docs/design-docs/lightweight-review.md` L52 仍为 8 项 `fix` 结尾 —— 历史 design-doc，DEC-009 已 partial Superseded by DEC-010，不改动镜像属合规（decision-log 3 铁律 1：不删旧条目）。
- `docs/design-docs/bugfix-rootcause-layered.md` §4.1 L68 展示的旧白名单是**对比参照**，下一行 L71 是 9 项新白名单。OK。

**结论**：3/3 权威源同步，镜像合规。PASS。

### 3.5 【项 5】Postmortem 硬约束可执行性（**FAIL — C1**）

**源**：`commands/bugfix.md` L93-95（步骤 4 postmortem 硬约束）+ design-doc §5.3。

**规则**：
> "Closeout 前 orchestrator 检查 Tier 2 bug 是否缺 postmortem；缺失则 block closeout。"

**对抗**：

- **C1（Critical）**：**规则描述缺执行锚点 —— orchestrator 在哪一步执行这个检查？**
  - `commands/bugfix.md` §步骤 5 之前只说 "lint + test 通过后... developer 必须产出 postmortem"，未定义 orchestrator 在 "步骤 4 → 步骤 5" 或 "Closeout → commit" 的哪个转场点做 tier==2 的缺失扫描。
  - `commands/workflow.md` §Step 6 规则 5 "developer 完成后跑 lint_cmd + test_cmd" 未提 postmortem 检查。
  - `commands/workflow.md` §Step 8 flush 触发点 1 "Stage 9 Closeout 之前" 是 log entries flush，不是 postmortem 存在性检查。
  - **症结**：没有任何 prompt 指令让 orchestrator LLM 机械执行 "if tier==2 and not exists({docs_root}/bugfixes/[slug].md) → block closeout emit warning"。subagent 返回后 orchestrator 靠什么记住 tier 状态？bugfix.md §步骤 3 只说 "派发 developer prompt 追加 tier 注入"，tier 在**发出时**有，但 developer 返回后 orchestrator 是否保留 tier 在 session state？没有显式契约。
  - **影响**：Tier 2 bug 可以 silently 跳过 postmortem 而 orchestrator 无感知 → "block closeout" 成空文。
  - **建议修复**（供 developer 决策，不内部修）：
    1. bugfix.md §步骤 4 末尾加一行执行指令：`orchestrator 在派发 developer 前记录 tier；developer 返回后若 tier==2 则在进入步骤 5 前 Read 检查 {docs_root}/bugfixes/[slug].md 存在性，缺失则 emit warning + 回派 developer 补写`；
    2. 或把检查绑定到 Step 8 Stage 9 flush 前："flush 前若本轮有 tier==2 dispatch 但 bugfixes/[slug].md 不存在 → block flush 向用户报告"。

> **Escalation 触发**：已写 phase_blocked 并在 final message emit `<escalation>`。见 §5。

### 3.6 【项 6】`_detect-project-context.md` 不受影响（PASS）

**源**：`skills/_detect-project-context.md`（全文 130 行已读）。

**验证**：

- grep "bugfixes" `skills/_detect-project-context.md` → **0 命中**。
- skill 只检测 `docs/` / `documentation/` 两级 docs_root（L71-75），**不枚举子目录**。
- 符合 issue #37 验收标准 5 "`_detect-project-context.md` 不动"。

**结论**：PASS。

### 3.7 【项 7】`docs/INDEX.md` 分类 auto-create（PASS-with-Warning）

**源**：`commands/workflow.md` §Step 7 L254 （"identify category" 列表含 `bugfixes/`）。

**验证路径**：

- Step 7 步骤 3 "按类别识别并 append 到对应 `### <category>` subsection（不存在则创建）"。L263。
- 目前 `docs/INDEX.md` 无 `### bugfixes` section（L41-96 遍历确认只有 analyze / design-docs / exec-plans / testing / reviews 5 section）。
- 首次 Tier 2 落盘时 orchestrator 按 Step 7 L263 "不存在则创建" 应自动建一个 `### bugfixes` section。

- **W4（Warning）**：首次落盘前 `docs/INDEX.md` 是"未来 auto-create"状态，用户新手接入读 INDEX 发现不到 `bugfixes/` 分类存在。建议 follow-up 在 INDEX.md §31-40 的 "按工作流阶段分类" table 里**预先**加一行 `| `bugfixes/` | developer | Tier 2 postmortem（DEC-014），文件名 `[slug].md` |`（1 行，不破坏 L41-96 structure）。非阻塞。

- **PASS 项**：workflow.md L254 分类枚举与 Step 7 "不存在则创建" 条款覆盖一致，机械 orchestrator 可执行。

### 3.8 【项 8】DEC-008 正交性（PASS）

**源**：`commands/workflow.md` §Step 8 L281-320。

**验证**：

- Flush 触发点（3 种 L283-286）**零改动**。
- 合并规则 L298-309 **追加**了 `fix-rootcause` 扩展字段合并（首条非空），**不改** 既有 `files:` union / `note:` 首条规则。
- Read + Edit 步骤 L293-299 **零改动**。
- YAML 契约 L312-320 扩 1 前缀 + 3 可选字段，既有 entry schema 兼容。

**结论**：DEC-014 DEC-008 正交补齐，无 Supersede。PASS。

### 3.9 【项 9】DEC-010 token 纪律（PASS）

**新增行数实测**（读源行数 diff）：

| 文件 | 新增行 |
|------|-------|
| `commands/bugfix.md` | +28 |
| `commands/workflow.md` | +11（L302-309 渲染扩 + L254 补 `bugfixes/` + L316 白名单） |
| `docs/log.md` | +17（L171 前缀表 + L182-195 扩展字段示例） |
| `docs/claude-md-template.md` | +1（L50） |
| **合计 prompt 本体** | **+57 行** |

- design-doc §5.1 宣称 ~30 行；实际 57 行略超预算。但较 DEC-013 45 行 / DEC-009 4 helper 抽取方案 ~120 行属合理区间。
- per-workflow runtime token 增量：bugfix 场景 +28 行 workflow.md 的大多数不触发（仅步骤 2/3/4 触及 ~15 行）+ workflow.md 渲染分支仅 flush 时触发。
- 对比 DEC-010 "激进 inline 精简" 心智：+57 行是 **incremental extension**（新 feature 落地），非 **helper 复用**（DEC-009 被 supersede 原因），不违反 DEC-010 精神。
- **PASS**。

### 3.10 【项 10】critical_modules 命中触发面（PASS）

**源**：`CLAUDE.md` §critical_modules 条目 1 / 6 / 8。

- 条目 1 "Skill / agent / command prompt 文件本体"：`commands/bugfix.md` + `commands/workflow.md` 直接命中。机械可识别。
- 条目 6 "workflow command Phase Matrix + 并行判定树 + phase gating taxonomy"：Step 8 flush 契约扩展命中（phase gating 子项）。
- 条目 8 "Developer execution-form switching rules"：DEC-014 **未触**（bugfix.md Step 6b 等路径未动）—— 验证不漏不误。

**结论**：触发面精确，本轮 critical_modules 命中应触发 tester + reviewer（本测试计划本身即履行 tester 部分）。PASS。

## 4. 发现的潜在问题汇总（交 developer / orchestrator）

| ID | 严重度 | 问题 | 建议位置 |
|----|-------|------|---------|
| C1 | Critical | Postmortem 硬约束缺 orchestrator 执行锚点 | `commands/bugfix.md` §步骤 4 末尾加执行指令 或 Step 8 flush 前绑定检查 |
| W1 | Warning | Tier 判定未纳入 LOC 维度（单文件 500 行） | follow-up：灰区启发式加 "LOC > 200 → Tier 1 ★" |
| W2 | Warning | "生产事故 label" 来源未定义 + 用户 override critical 未表态 | `commands/bugfix.md` L53 补来源；design-doc §2 补 override 说明 |
| W3 | Warning | "50 字" 阈值 i18n 歧义 + LLM 自评稳定性差 | 改 "≤200 字符" 或 "根因 1 句可说清" |
| W4 | Warning | `docs/INDEX.md` 未预建 bugfixes 分类（首次 auto-create 不友好） | follow-up：INDEX.md §31-40 table 加 1 行 |

## 5. Escalation（C1）

见 final message 的 `<escalation>` block。C1 是 prompt 层设计缺陷（不是 src bug），但仍按 "发现设计级 bug" 协议 emit `<escalation>` 供 orchestrator 裁决（修 prompt / 接受现状 + follow-up issue / 其他）。未在 tests/ 写复现测试（本测试非可执行框架）。

## 6. Acceptance 映射（issue #37）

| # | Acceptance | 本测试覆盖情况 |
|---|-----------|--------------|
| 1 | Tier 三档机械判定 | 项 1 T1-T8 8 用例，PASS-with-W1/W2 |
| 2 | `fix-rootcause` 前缀 + 扩展字段 + 合并规则 | 项 3 Y1-Y5 + 项 4 白名单 3 处，PASS |
| 3 | Postmortem 模板 + 硬约束 | 项 5 FAIL C1（硬约束执行锚点） |
| 4 | 不改 5 agent prompt + `_detect-project-context.md` | 项 6 grep 0 命中 PASS |
| 5 | DEC-008 / DEC-010 / DEC-013 正交 | 项 8 + 项 9 PASS |
| 6 | critical_modules 必触发 tester / reviewer | 项 10 + 本测试即触发体现 PASS |
| 7 | docs 布局 `bugfixes/` 自动归类 | 项 7 PASS-with-W4 |

1 Critical / 4 Warning；Critical 非 lint-level 阻塞但涉及用户体验保证，建议 developer 修后再 reviewer 终审。

## 7. 变更记录

| 日期 | 改动 | 操作者 |
|------|------|--------|
| 2026-04-20 | 初版对抗性审查（10 risk items，1 Critical + 4 Warning，涉 issue #37 DEC-014 prompt 层落地） | tester |
| 2026-04-20 | post-fix round 2 回归（C1 + W1-W4 全 PASS；新发现 W5 YAML 契约文档冗余度 nit，非阻塞） | tester |

---

## post-fix 回归验证（round 2）

**范围**：仅 C1 + W1/W2/W3/W4 回归，不重跑首轮已 PASS 的 5 项（项 4 白名单同步 / 项 6 `_detect-project-context.md` 不受影响 / 项 8 DEC-008 正交 / 项 9 DEC-010 token 账 / 项 10 critical_modules 触发面）。lint 复跑 0 命中。

### R1. C1 Postmortem 硬约束 orchestrator 执行锚点 — **PASS**

**源**：`commands/bugfix.md` L90-95（步骤 4 新增"Postmortem 硬约束（Tier 2，含 orchestrator 执行锚点；DEC-014 C1）"）。

4 条锚点逐项核查：

| 锚点 | 可机械执行？ | 触发时点 | 与既有契约协调 |
|------|------------|---------|--------------|
| 1. 派发前写 `{slug}.tier` 入 session 记忆 | ✓ 明确"在派发 developer 前" | pre-dispatch | 与步骤 3 §派发契约 "tier: 0/1/2 注入 developer" 同步；session 记忆保留为 orchestrator 后续检查用 |
| 2. return 后 `tier==2 && !exists({docs_root}/bugfixes/[slug].md)` → mini-loop 回派 | ✓ 判据完整（tier 从锚点 1 读；exists 可 Read / Glob 探测） | post-return, pre-step-5 | mini-loop 回派契约显式（"否则进入步骤 5"），LLM 不会 fall through |
| 3. closeout gate 前最终校验 block | ✓ "本 session 任何 `tier==2 && 缺 postmortem` 立即 block closeout 报告用户" | Stage 9 Closeout gate 前 | 与 `commands/workflow.md` §Step 8 Flush 触发点 1 "Stage 9 Closeout 之前" 同位但功能正交（log flush vs postmortem 存在性），序不冲突：可并列或先 Step 8 后 postmortem 校验，两序均合规 |
| 4. 回派只读 design-doc §5.2 模板 | ✓ scope 明确"不改其他产出" | mini-loop 回派时 | 避免回派 developer 越权 touch fix code |

**首轮 C1 症结已闭环**：
- 首轮痛点 "orchestrator 在哪一步执行检查？" → 锚点 2 + 3 双点覆盖（步骤内回路 + closeout 兜底）
- 首轮痛点 "developer 返回后 orchestrator 如何保留 tier 状态？" → 锚点 1 明示 session 记忆写入契约
- 首轮建议修复 1 + 2 被**同时**采纳（非二选一），双保险强于单独任一

**DEC-006 Stage 9 Closeout 协调**：锚点 3 与 DEC-006 Closeout gate 属同阶段 ≠ 同行为（log flush / postmortem check 正交），不冲突；两者都是 orchestrator 在 Stage 9 before-transition 做的 batched 检查，语义叠加合理。

**微 gap（不升级）**：锚点 3 "block closeout 报告用户" 未声明"报告"是 `<decision-needed>`（text mode，让用户选继续 block / override）还是 `AskUserQuestion`（modal mode）。workflow.md §Step -1 / Step 5 按 `decision_mode` 分支渲染即可兼容，但未显式引用。下轮微调时可补一句 "按 decision_mode 渲染"。

**结论**：C1 **PASS**（首轮 Critical 已根治）。

### R2. W1 Tier LOC 维度 — **PASS**

**源**：`commands/bugfix.md` L51-57 Tier 表 + 捷径条款。

- Tier 0: "单文件 + 单模块 + **≤80 LOC** + 无 critical"
- Tier 1: "≥2 文件 或 跨模块 或 **单文件 >80 LOC**；无 critical"
- 捷径: "summary ≤3 句 且 单文件 且 **≤80 LOC** → 直接 Tier 0"

"80 LOC" 分档 3 处一致；boundary 用闭区间 `≤80` / 开区间 `>80`，无二义重叠。

**nit（不升级）**：LOC 计量口径未显式声明（added LOC / modified total / net diff / git diff --stat 的 insertions+deletions）。LLM 实务中默认 "diff 行数" 但不同项目 convention 可能不同。建议下轮微调时在表注加一句 "LOC 指 `git diff --stat` 的 insertions+deletions 合计"。非阻塞。

**结论**：W1 **PASS**（首轮"未纳入 LOC" 已显式分档解决）。

### R3. W2 production-incident label + critical override — **PASS**

**源**：`commands/bugfix.md` L55 + L57。

- Label source 明确："issue 带 `**production-incident** label 或 body 声明`" —— label 名固定为 `production-incident`，声明路径 2 种（GitHub issue label / issue body 语义声明）机械可识别。
- Critical override 流程："用户显式'降级到 Tier 1'可 override critical（orchestrator **emit 一次警示确认**）" —— 触发点（override 语义被检测到）+ 执行动作（emit 警示确认）明确。

**nit（不升级）**：警示确认 UI 未声明是 `<decision-needed>` / `AskUserQuestion` / 纯 text emit。按 DEC-013 decision_mode 两分支自适应即可，实务不阻塞；建议下轮可补一句 "按 decision_mode 渲染" 与锚点 3 统一。

**结论**：W2 **PASS**（label source + override 路径均明确）。

### R4. W3 "≤3 句" 捷径 — **PASS**

**源**：`commands/bugfix.md` L57 "summary ≤3 句 且 单文件 且 ≤80 LOC → 直接 Tier 0 无问询"。

- i18n：中文 `。` 与英文 `.` 均是 sentence terminator，LLM 机械分句稳定，不存在原 "50 字"的 "字符 / 字 / word / token" 语义漂移。
- 边界：`！` / `？` / `；` / `!` / `?` 按实务 LLM 习惯计句 boundary；不声明细节可接受（vs 首轮 "50 字" 的客观计量歧义，容忍度高得多）。
- 联动性：叠加"单文件 + ≤80 LOC" 两硬约束，捷径误触发面显著收敛。

**结论**：W3 **PASS**（i18n 歧义消除）。

### R5. W4 INDEX bugfixes 占位 — **PASS**

**源**：`docs/INDEX.md` L98-100：

```
### bugfixes

（Tier 2 postmortem 暂无条目；DEC-014）
```

- **风格一致性**：对比既有 `### analyze` / `### design-docs` / `### testing` / `### reviews` 4 个平铺 section，`### bugfixes` 使用平铺 heading + 单行占位说明，符合既有"section 不空则列 bullet / 空则一行占位"的隐式风格。
- `### exec-plans` 有 active/completed 两级 subheading，bugfixes 无此需要（Tier 2 落盘后直接 `- [slug.md](bugfixes/slug.md) — desc` 一行即可）。
- **可发现性**：新手读 INDEX "按工作流阶段分类" table（L32-39）应新增一行 `| bugfixes/ | developer | Tier 2 postmortem ... |` 使 table + section 双入口对齐。**当前 table L32-39 未更新**，属微 gap。

**nit（不升级）**：L32-39 table 未同步加 `bugfixes/` 行（表中仍 6 行：analyze / design-docs / exec-plans/active/ / exec-plans/completed/ / testing / reviews）。"### bugfixes" section 已建但 table 未指向。用户从 table 导航时发现不到。建议下轮微调时在 L39 后 append 一行 `| bugfixes/ | developer | Tier 2 postmortem（DEC-014），文件名 `[slug].md` |`。非阻塞（section 已存在 + INDEX 下半部有 section 可达）。

**结论**：W4 **PASS**（section 占位已建，风格对齐；table 导航未同步是 follow-up nit）。

### R6. YAML schema 回归（`analysis` 合并字段）— **PASS-with-nit (W5)**

**源**：
- `docs/log.md` L192-204 `fix-rootcause` 扩展示例
- `commands/workflow.md` §Step 8 L302-303 渲染规则

**log.md 合并示例**：

```yaml
log_entries:
  - prefix: fix-rootcause
    slug: some-bug
    files: [src/foo.rs, tests/foo_test.rs]
    note: <一句话>
    analysis: |
      根因: <2-5 句>
      修复: <1-3 句>
      复现: <步骤；有回归测试则省略>
```

- 3 字段合并为 1 `analysis: |` 多行字段，语义分段用"根因: / 修复: / 复现:" 中文小标，LLM 易生成；YAML `|` literal block 保留缩进渲染规则清晰。
- 反向兼容：旧 `fix` entry（如 L22-25 / L57-60 实际历史 entry）无 `analysis` 字段，按基础 4 行模板（log.md L186-190）渲染不受影响。

**workflow.md 2 行压缩规则**（L302-303）：
> `fix-rootcause` 扩展（DEC-014）：`analysis:` 原样缩进渲染为 `- 分析:` 多行块；`tier==2` 时追加 `- 关联 postmortem: {docs_root}/bugfixes/[slug].md` 行。
> 合并取首条非空 `analysis`（不拼接）。

2 行表达 3 事实（原样缩进渲染 / tier==2 追加 postmortem 行 / 首条非空合并）清晰无歧义。**PASS**.

**W5（新发现，Warning 级，非阻塞）**：`workflow.md` §Step 8 YAML 契约 L308-314 只列 `prefix / slug / files / note` 4 字段，**未显式声明 `analysis:` 是 `fix-rootcause` 前缀下的可选第 5 字段**。subagent LLM 读 workflow.md §Step 8 YAML 契约生成 log_entries 时会漏 `analysis`；要求 LLM 交叉参考 log.md §条目格式的示例才能补齐。文档冗余度不足但非 block —— log.md 示例 + workflow.md 渲染规则互补覆盖。建议下轮在 L314 后追加一行 `# fix-rootcause 下可选: analysis: | ...（多行 YAML literal block）`。

### post-fix 总结

| 项 | 首轮状态 | round 2 结论 |
|----|--------|------------|
| C1 Postmortem 硬约束 | Critical FAIL | **PASS** |
| W1 Tier LOC 维度 | Warning | **PASS**（nit: LOC 计量口径可显式声明） |
| W2 production-incident + override | Warning | **PASS**（nit: 警示确认 UI 按 decision_mode 可补） |
| W3 ≤3 句捷径 | Warning | **PASS** |
| W4 INDEX bugfixes | Warning | **PASS**（nit: L32-39 table 可同步补 bugfixes/ 行） |
| W5 workflow.md YAML 契约遗漏 analysis 字段 | — | **NEW Warning**（非阻塞） |

**Regressions**：无。
**新 Critical**：无。
**lint**：`grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/` 0 命中。

**建议合并/放行**：C1 + W1/W2/W3/W4 全 PASS；W5 + 3 条 nit 属文档冗余度改进建议，不阻塞 DEC-014 落地合并。后续 follow-up 可合并到下一次触碰 bugfix.md / workflow.md / INDEX.md 的改动里顺便处理。
