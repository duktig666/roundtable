---
slug: prompt-reference-density-audit
source: 原创（本地量化 + superpowers/gstack WebFetch 竞品采样）
created: 2026-04-23
---

# Runtime Prompt 引用密度回归审计

## 背景与目标

roundtable 的 runtime-loaded prompt 本体（`skills/*.md` / `agents/*.md` / `commands/*.md`）每次 `/roundtable:workflow` / `/roundtable:bugfix` 派发必然加载到 orchestrator context，per-message token 成本 = 文件字节数 × 调用频率。

`decision-log.md` DEC 条目是 roundtable 独有的"轻量架构决策记录"产物。问题在于：**runtime prompt 本体里累积了大量 `（DEC-xxx）` / `（DEC-xxx §y.z）` 行内括注**——对 LLM 执行无增益（LLM 不读 decision-log），只对 maintainer 溯源有 meta 价值。

issue #22（2026-04-20 闭环）已做过一轮精简并建立方法论（baseline → architect 三选项 → cut）。**#100（2026-04-22 merged）补上 CLAUDE.md §条件触发规则的预防条款**（禁"仅 maintainer 可溯源"类行内 ref），但**未做存量清理**。

本审计为 issue #99 承接 #22 方法论，做**存量量化 + 成因归类 + 竞品参照**，给 architect 阶段三选项决策提供 data-driven 输入。

## 追问框架

### 必答 2

**1. 失败模式（方案最可能在哪里失败？）**

三处脆弱点：

- **白名单边界主观化**："消歧必要" / "首处锚点" / "跨文档跳转" 的判断在 PR review 时存在解读空间；下一轮作者仍可能以"这是消歧所需"为由保留行内 ref
- **回归阈值噪声**：CLAUDE.md 现行 "单文件 +20% 或合计回到 28 以上" 阈值在小文件 base 时敏感度高（3→5 即 +67%），可能触发无意义 audit
- **过度清理误删锚点**：激进方案全删后，6 个月后的 maintainer 看到 "Phase Matrix re-emit 义务" 规则时，没有 `（DEC-024）` 指针就很难回溯原始 rationale（decision-log 自身的价值受损）

**2. 6 个月后评价（是否变成债务？）**

分两种结局：

- **若只做一次性清理（无 enforcement）**：6 个月后第三轮回弹——**这已是第二轮回归**，#22（2026-04-20） → 仅 2 天后（2026-04-22）已 83/41/5/12，说明"人工纪律 + 偶发 audit" 模式不 sustainable
- **若加 CI/lint 自动 gate**：可持续，但需防 false positive 淹没开发体验；threshold 调校本身成债务
- **彻底方案（未在现行讨论范围）**：prompt 本体完全剥离 DEC ref，只在 `docs/design-docs/`、`docs/reviews/` 里出现——与 superpowers 实际做法对齐（见 §竞品）

### 按需 4（部分适用 —— internal refactor，痛点 / 最简方案 / 竞品对比 triggered）

**痛点**：per-message token 成本 + maintainer churn（每加一条规则都要带 DEC 锚点的无意识习惯）

**最简方案**：激进方案（全删行内括注）最简，但与"锚点溯源价值"取舍需架构师决策

**竞品对比**：见 §竞品参照（superpowers / gstack）

使用者与 journey（跳过——本 refactor 对象是 plugin 维护者，非最终用户）。

## 调研发现

### 1. 量化 Baseline（2026-04-23 快照 vs #22 快照）

**总体命中**：

| 类型 | #22 旧快照（2026-04-20） | #100 merge 后（2026-04-22） | 当前（2026-04-23） | Post-#22 增量 |
|------|-------------------------|---------------------------|-------------------|--------------|
| `DEC-xxx` | 28 | 83 | **83** | +196% |
| `§x.y` | 12 | 41 | **41** | +242% |
| `issue #nn` | 0 | 5 | **5** | +5 |
| `详见/详情见/参见` | 3 | 12 | **12** | +9 |

（#100 的 scope = CLAUDE.md 规则新增 + VCS 中立措辞，prompt 本体未动 → merge 前后 83/41 不变）

**Per-file 热点**（DEC / §x.y / issue# / 详见 四列）：

| 文件 | 行数 | DEC | § | issue# | 详见 |
|------|------|-----|---|--------|------|
| `commands/workflow.md` | 552 | **34** | **22** | 3 | 7 |
| `commands/bugfix.md` | 145 | 8 | 5 | 0 | 1 |
| `agents/tester.md` | 142 | 7 | 0 | 0 | 0 |
| `skills/_progress-content-policy.md` | 68 | 6 | 9 | 0 | 0 |
| `skills/architect/SKILL.md` | 240 | 6 | 2 | 1 | 3 |
| `agents/dba.md` | 155 | 6 | 0 | 0 | 0 |
| `agents/reviewer.md` | 140 | 6 | 0 | 0 | 0 |
| `skills/analyst/SKILL.md` | 174 | 4 | 2 | 1 | 0 |
| `commands/lint.md` | 170 | 4 | 0 | 0 | 1 |
| `agents/research.md` | 118 | 2 | 1 | 0 | 0 |
| `skills/_detect-project-context.md` | 129 | 0 | 0 | 0 | 0 |
| `agents/developer.md` | 121 | 0 | 0 | 0 | 0 |

**关键观察**：`commands/workflow.md` 独占 **DEC 41% / § 54% / issue# 60% / 详见 58%**——是唯一真正的热点，其他文件都属轻度。

### 2. 回归成因归因（commit-level）

Post-#22 merge（51f6377，2026-04-20）至今的 `runtime prompt` DEC-ref 净变动：

| commit | 主题 | 净 DEC ref Δ |
|--------|------|-------------|
| 51f6377 | **#22 原 prune** | **−22** |
| 0ed7934 | Step 4b batch fuzzy decision | +2 |
| 882c8b7 | reviewer/tester/dba relay reversal（DEC-017） | +8 |
| a28f673 | DEC-013 §3.1a forwarding 扩展 | +3 |
| ca10332 | DEC-020 auto-halt text mode | +4 |
| 7a45361 | DEC-022 event class a 格式 | +2 |
| 0dbfba2 | **DEC-023 三角色 execution-form 扩展** | **+18** |
| ade669e | **DEC-024 Phase Matrix re-emit** | +8 |
| dc4c546 | DEC-025/026 sustainability umbrella | +6 |
| 8193434 | DEC-028 SessionStart hook | +1 |
| 75a9475 | #100 CLAUDE.md rule | ±0（prompt 未动） |

Post-#22 累计净增 **+54** DEC ref（实际现状 83 与 #22 post-prune 估算 ~29 差值吻合）。

**前 3 名贡献者**：DEC-023（+18）、DEC-024（+8）、DEC-017（+8），合计占 +54 的 **63%**。

### 3. 行内 ref 形态分类（以 `commands/workflow.md` 为样本）

**title 标签 ref**（`## Step X: Y（DEC-xxx）` 风格）：

| 文件 | 行 | 内容 |
|------|----|------|
| `commands/lint.md` | 65 | `### 6. 决策状态与结构审计（DEC-025 扩）` |
| `agents/dba.md` | 146 | `## 输出落盘（orchestrator relay 主路径；DEC-017）` |
| `agents/reviewer.md` | 128 | `## 输出落盘（orchestrator relay 主路径；DEC-017）` |
| `commands/bugfix.md` | 57 | `### Tier 判定（D1 双轴 + LOC；DEC-014）` |
| `commands/bugfix.md` | 100 | `### Postmortem 硬约束（Tier 2，含 orchestrator 执行锚点；DEC-014 C1）` |

**共 5 处**（全部 post-#22 新增；#22 原清理把 title-tag 层清干净了，回归又累积 5 处）。

**行内括注 ref**（`规则（DEC-xxx）` 风格）：

| 模式 | 出现次数（workflow.md） |
|------|-----------------------|
| `（DEC-024）` 纯括注 | 7 |
| `（DEC-024，<qualifier>）` | 3 |
| `（DEC-013 §3.1.1 ...）` | 3 |
| `（DEC-018 ...）` | 3 |
| `（DEC-006 §A ...）` | 2 |
| `（DEC-003 ...）` | 2 |
| `（DEC-005 ... + DEC-023 ...）` | 1 |
| `（DEC-021 Refines DEC-016 §3.2）` | 1 |
| …（其余单次） | ~13 |

**DEC-024 pattern 尤其典型**：同一规则（"Phase Matrix 尾段随附 TG 快照"）在 §Step 5b（lines 314/317/318 事件类 b/d/e 3 行）+ §Step 6.1（lines 384/386/388 A/B/C 3 条）+ §起点（lines 545/547）各重述一次，**每次都带 `（DEC-024）` 锚点**——10 处该 DEC 提及，其中只有 line 20 的 intro 是真正"独一无二的 anchor 源"，其余 9 处是"meta 溯源重复"。

### 4. 详见 / issue# 白名单候选分析

**`详见` 12 处分类**：

| 类型 | 条数 | 典型 |
|------|------|------|
| 跨文档跳转（legit whitelist） | 10 | `详见 docs/design-docs/orchestrator-bootstrap-hardening.md` / `详见 docs/testing/subagent-progress-and-execution-model.md Case 1.2` / `详见 docs/design-docs/lightweight-review.md §2.2.3` |
| 内部指针（疑似噪声） | 2 | `commands/lint.md:168` 的 "详见对话输出" / `commands/workflow.md:334` 的 "详见 `<docs_root>/...` 单行引用"（规则示例） |

**`issue #nn` 5 处分类**：

| 文件 | 行 | 内容 | 分类 |
|------|----|------|------|
| `skills/analyst/SKILL.md` | 168 | `DEC-006 §A 菜单穷举 / issue #30 Q&A 循环` | 行内括注溯源 |
| `skills/architect/SKILL.md` | 64 | `### 阶段 3：exec-plan（默认...；issue #30）` | **title 标签** |
| `commands/workflow.md` | 73 | `## Step 0.5: FAQ Sink Protocol（issue #27；...）` | **title 标签** |
| `commands/workflow.md` | 364 | `**Stage 9 Closeout 变体**（A 类终点，无 producer skill；issue #26 + #30）：` | title 标签（bold heading） |
| `commands/workflow.md` | 491 | `prefix: review （或 ...，issue #67 DEC-017 修订）` | 行内括注 |

3/5 属 title 层溯源；2/5 行内。

### 5. 竞品参照

#### 5.1 superpowers（obra/superpowers）

抽样 5 个 skill（`brainstorming` / `dispatching-parallel-agents` / `executing-plans` / `subagent-driven-development` / `test-driven-development`）SKILL.md：

- **DEC-xxx 命中：0 / 5**
- **§x.y 命中：0 / 5**
- 无独立 `decision-log.md` artifact；rationale 以 prose 嵌入 skill 内部（如 `subagent-driven-development` 的 "**Why subagents:**" / "**Core principle:**" 段）
- 跨 skill ref 用 `superpowers:<skill-name>` 具名而非决策 ID
- 流程用 Graphviz DOT 图可视化而非 "§Step X.Y" 编号

**推论**：superpowers 彻底回避 "prompt 本体 ref decision-log" 的架构选择。rationale 就地嵌入 prose，LLM 与 maintainer 共享同一信息层（省去"LLM 读不到 DEC 原文" 的割裂）。

#### 5.2 gstack（garrytan/gstack）

顶层单 `SKILL.md` + `agents/` 目录；frontmatter 带 `preamble-tier` / `triggers` / `allowed-tools` 结构化字段。skill body 主要是 tool 调用样板 + 可运行 bash，**无 decision-log 层概念**。

### 6. 精简策略空间（三方案估算）

| 方案 | 描述 | DEC 删除量（估） | Token 节省（估）| 回归风险 |
|------|------|-----------------|----------------|---------|
| **A. 激进** | 删全部 title 标签 + 删全部行内括注（仅保 Accepted DEC 原文段落、`file:line`、跨文档 `详见` 跳转、`docs/design-docs/` 路径引用） | −70/83（-84%） | ~−12% | 中：maintainer 回溯需跳 `docs/decision-log.md` 翻号；超越 superpowers 模式（无 decision-log ref） |
| **B. 中道** | 删全部 title 标签 + 行内只留"消歧必要"（同 DEC 重复 ≥2 处时首处保留锚点，后续删）；`commands/workflow.md` 的 DEC-024 10 处收敛到 2 处（intro + 1 规则代表） | −50/83（-60%） | ~−8% | 低-中：主观判断空间 |
| **C. 保守** | 只动 `commands/workflow.md` 热点（42 命中）+ 明显冗余（同 DEC 重复 ≥3 次的处）+ 5 处 title 标签；其他文件不动 | −22/83（-26%） | ~−4% | 低 |

**估算口径**：token 节省按 `wc -c` 差值 / 总字节（workflow.md 50356 bytes 为最大贡献）粗算；不含 TG forwarding / phase matrix re-emit 等运行时开销。

**#22 原要求**：`≥60% DEC ref 下降 + ≥8% workflow 派发 token 下降` → **方案 B 恰好贴线，A 超额，C 欠达标**。

### 7. 回归监控 threshold 现行规则分析

CLAUDE.md §条件触发规则 第 10 条（2026-04-22 加入）：

> 回归监控 `grep -cE "DEC-[0-9]+|§[0-9]" <file>` per-file baseline，单文件回升 >20% 或 `skills/+agents/+commands/` 合计 ≥ #22 旧快照（28）→ 开 follow-up audit issue 走 #22 方法论

**客观评估**（不做推荐）：

- **规则表述**：per-file 阈值 + 合计硬线，双闸设计
- **敏感度**：per-file +20% 在小文件 base 时（`agents/research.md` 2 DEC → 3 DEC 即 +50%）误报概率高
- **合计硬线 28**：现状 83 已远超；触发已满足但本 audit 即是响应——规则已生效一次
- **缺 enforcement**：规则是"人工跑 grep 并开 issue" 的 discipline，非 CI gate
- **替代机制**（客观枚举）：
  - (α) CI/lint hook：在 PR 阶段跑 `grep -cE` diff 对比 base branch，超阈自动 comment / block merge
  - (β) PR template checklist：强制作者勾选 "新增 `（DEC-xxx）` 是否为跨文档跳转 / file:line / Accepted DEC 原文 之一"
  - (γ) CLAUDE.md rule + manual audit（现行）
  - (δ) 彻底重构模式：runtime prompt 本体禁一切 DEC ref，decision-log 只在 docs/ 出现（superpowers 式）

## 对比分析

### A. 激进 vs B. 中道 vs C. 保守 vs D. 彻底重构（新增对比轴）

| 维度 | A | B | C | D（彻底重构） |
|------|---|---|---|---------------|
| 删除比例 | -84% | -60% | -26% | -100% |
| Token 节省（估） | -12% | -8% | -4% | -12% |
| Maintainer 溯源成本 | 中（需翻 decision-log） | 低-中 | 低 | 中-高（docs/ 重构才能 grep 到 rule 源） |
| 一次性工作量 | 中（~2-3 小时） | 中（~2-3 小时） | 小（~1 小时） | 大（同时要把 rule → prose 改写） |
| 预防回归（6 mo.） | 依赖 CLAUDE.md rule + lint | 依赖 rule + lint | 依赖 rule | 结构性杜绝（DEC ref 不在 prompt 出现 = 物理隔离） |
| 与 superpowers 对齐度 | 部分 | 部分 | 低 | 完全 |
| 架构变更幅度 | 小（仅文本） | 小 | 极小 | 中（重构 rule 写法） |
| decision-log 价值受损 | 中（ref 入口变窄） | 低 | 无 | 中（runtime prompt 不再 ref，但 design-docs 仍 ref） |

## 开放问题清单（事实层）

- **白名单定义边界**：CLAUDE.md 现行白名单列了"跨文档跳转 / file:line / Accepted DEC 原文段落"，但**未定义 "Accepted DEC 原文段落"** —— 是只指 `docs/decision-log.md` 原文，还是也允许在 `skills/*.md` 内 inline 复刻 DEC 全文段落？（`docs/architect/SKILL.md` 现含多段 DEC 背景阐述，需架构师判定归类）
- **消歧必要判定**：方案 B 的"同 DEC 重复 ≥2 处时首处保留锚点"是否需定义"首处"（文档顺序 / 语义最强 / 最新 / 最权威）？`commands/workflow.md` 的 DEC-024 intro 在 line 20，但 §Step 6.1 A/B/C 的规则条款才是真正"必须遵守" 的锚点位置
- **DEC-023 高贡献原因**：DEC-023（+18 DEC ref，单 commit 贡献最大）扩展了三角色 inline/subagent 切换规则，其 §Step 6b 的 18 处 DEC-017/005/023 ref 是否可以收敛到 §Step 6b 首段 1 处锚点（事实层疑问，架构师判）
- **回归监控 α/β/γ/δ 四路径比较**：CI/lint hook（α）需要 `.github/workflows/` 新增；PR template（β）需要 `.github/pull_request_template.md`；现行 CLAUDE.md rule（γ）已落地；彻底重构（δ）需要单独 design-doc。此四路径不互斥，但选型有顺序/组合空间
- **Threshold per-file +20% 合理性**：小文件 base 下敏感度高，架构师需判 threshold 是否改绝对量（如 "单文件新增 ≥3" 且 "合计净增 ≥10"）或改 SMA 滑动（近 3 次 commit 均值 +30%）
- **issue #99 的三选项对应关系**：#99 issue body 的 A/B/C 三选项对应本报告的 A/B/C；**方案 D（彻底重构）是否纳入 architect AskUserQuestion**（事实层：若纳入则有 4 选项，超出 AskUserQuestion 4-maxOptions 上限前还有余量；但 #22 原范式是 3 选项，是否扩展需决策）

## FAQ

（本报告新建，尚无追问；后续追问以 `### Q: <摘要>` 格式追加）

---

```yaml
created:
  - path: docs/analyze/prompt-reference-density-audit.md
    description: Runtime prompt 引用密度回归审计——baseline 量化、commit 归因、superpowers/gstack 竞品参照、4 方案空间估算
```

```yaml
log_entries:
  - prefix: analyze
    slug: prompt-reference-density-audit
    files: [docs/analyze/prompt-reference-density-audit.md]
    note: "#99 承接 #22 方法论；采 2026-04-23 baseline（DEC 83/§ 41/issue# 5/详见 12）+ post-#22 commit 净增归因（+54，DEC-023/024/017 前三占 63%）+ superpowers (0 DEC ref in 5 skills) / gstack 竞品参照；列 A/B/C/D 四方案估算（含彻底重构选项）+ 6 事实层开放问题；不做选型推荐（留给 architect）"
```

---

✅ analyst 完成。
产出：
- `docs/analyze/prompt-reference-density-audit.md` — 审计报告（baseline / 成因 / 竞品 / 四方案估算 / 事实层开放问题）

请阅读后告诉我：
- `go`（进入 architect 阶段）
- `问: <具体疑问>`（回答后回到本菜单，可多轮）
- `调: <扩展或收窄 scope>`
- `停`
