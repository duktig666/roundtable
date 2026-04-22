---
slug: decision-log-sustainability
source: 原创（issue #84 umbrella + docs/decision-log.md 实测 + ADR 外部实践调研 + prior lightweight-review.md）
created: 2026-04-22
description: 事实层拆解 decision-log.md 可持续性 4 子议题 —— 门槛 / 元规则 / token / 归档；给 architect 承接
---

# decision-log 可持续性分析报告

> 关联 issue：[#84](https://github.com/duktig666/roundtable/issues/84)（umbrella；合并原 #85 token / #86 归档 + 新增子议题 1 门槛）
> 关联 DEC 与文件：`docs/decision-log.md` / `docs/INDEX.md` / `skills/architect/SKILL.md` / `agents/reviewer.md` / `commands/workflow.md` / `commands/lint.md`
> 前置分析：[lightweight-review.md](./lightweight-review.md)（issue #9 体量 inventory）

## 背景与目标

issue #84 在 4 月 22 日合并原 #85 (token) + #86 (归档) 并新增"子议题 1 DEC 开立门槛"作为链条起点，呈现为 umbrella。root cause 主张：**"DEC 开立门槛过低导致条目膨胀 → 全读机制下 token 爆炸 → 需要索引 → 需要归档"四症状同根**，链条第一环是门槛。

analyst 目标：**验证** issue 正文的事实主张（不原文照抄），对 5 类 claim（条目数 / token 机制 / 分类 / 外部 ADR / 依赖图）独立核查；给 architect 承接 4 子议题的事实层素材。

## 追问框架

### 必答 2 问

**失败模式（本次调整最可能在哪失败）**
- 子议题 1 "收紧门槛" 依赖 architect skill 本体阶段 2 新增一句"自问 5 类"——架构决策路径的 judgment call 极易被 LLM 主观解读成"按旧习惯就开 DEC"，collapse 到原状
- 子议题 2 新增 `Provisional` 状态的自动转正触发条件（"≥7 日 OR 首次 dogfood run 通过"）在没有自动化 lint 时容易永远 Provisional；当前 `commands/lint.md` 只扫 "长期 Proposed 超 30 天"，不扫 Provisional
- 子议题 3 方案 B 的 `docs/INDEX.md` DEC 索引段需要手工维护（没有 DEC 级 append-only 契约写入 architect SKILL.md 时），会和 decision-log.md 漂移
- 子议题 4 归档 stub 格式要求"主文件留 ≤5 行 stub + 跨文件跳转链接"，但主文件的跨季度 DEC 编号连续性会被破坏（读者看到 DEC-009 stub 需跳 archive/decision-log-2026-Q2.md，而 DEC-008 在主文件）

**6 个月后评价（是否会成债务）**
- 若子议题 1+2 落地后实际新 DEC 节奏降至预期 ~40%（issue 估算），decision-log.md 增量从 "5 DEC/1 天" 降到 "2 DEC/1 天"，半年后 ~20+120 = 140 DEC 仍远低于门槛不改的 200+
- 若方案 B 落地但 architect SKILL.md "全读" 改 "按索引 + 相关 DEC" 的契约描述措辞不精确，subagent 在 cold-start 时仍会 fallback 全读（观察 issue #20 subagent 冷启调研中已有类似 fallback 行为）
- 归档 stub 的永久锁死（铁律 7 草案"禁改 Accepted 正文 / 删备选 / 压理由"）与 子议题 1 "门槛收紧"同时生效时，新手贡献者读不到早期 decision 的"备选"段反而抬高 onboarding 难度（因为早期 DEC 决策路径对理解现状最关键）

### 按需 4 问

- **痛点**：当前 1 轮 workflow 的 architect + reviewer 各读全 575 行 decision-log.md（实测，见 §3 token 力学），按 Claude 英文 ~1.3 token/word 折算 8763 words × 2 ≈ 22.8k tokens 纯读取开销；按 3 月 100+ DEC 外推线性升至 ~115k tokens
- **使用者与 journey**：architect 写新 DEC 时对照已有（写设计阶段的 correctness gate） / reviewer 对照 DEC 验证实现（Step 7 Review 阶段的 compliance gate） / 新贡献者 onboarding（非强制场景，但事实上决定 DEC 文档的 UX 上限）
- **最简方案**：纯收紧子议题 1（门槛），暂不动 2/3/4，观察 30 天 DEC 节奏 —— 若新 DEC 从现 ~5/天 降到 ~2/天，token 压力天然缓解 40%，可能直接 obsolete 子议题 3 一半需求
- **竞品对比**：Nygard 原版 ADR / MADR / Y-Statements / adr-tools（见 §4）

## 调研发现

### 1. 事实基线（实测数字 vs issue 主张）

| 项 | issue #84 主张 | 实测 | 是否一致 |
|---|---|---|---|
| decision-log.md 行数 | 575 | 575（`wc -l`）| ✅ |
| decision-log.md 字数 | 未言 | 8763 words | 补充 |
| DEC 条目 level-3 header 数 | 20 | 21（`grep -cE "^### DEC-[0-9]+"`）| ⚠️ 21 含 DEC-017 两次（原 DEC-017 + "DEC-017 Amendment"），**unique DEC = 20** 与 issue 一致 |
| INDEX.md DEC 索引 | "只有 1 行" | 实测 DEC 级索引不存在；关联 DEC 散在 `analyze/` `design-docs/` 描述里（约 6 处 DEC-xxx 提及）；**无结构化 DEC 索引表** | ✅ 本质一致 |
| 近两日 DEC 节奏 | 5 DEC/1 天 | `git log --since="2026-04-01" -- docs/decision-log.md` = 25 次 commit（含修订 + 新增）；DEC-013~021 共 9 条跨 4-20/4-21 两日落盘 | ✅ 节奏定性一致 |

**补充事实**：
- `git diff docs/decision-log.md` 显示本地已预写铁律 4/5/6 + `Refined by` 状态（+15 行，未 commit）—— issue #84 "本地已打底" 确认
- DEC-019 与 DEC-017 Amendment 并存呈现"落盘当天补丁"三套并存形式（DEC-017 Amendment 小节 / DEC-019 主条目 Refines / DEC-013 post-fix 段）—— 子议题 2 "铁律 4 统一 post-fix inline" 主张的实证基础

### 2. 20 DEC 分类实证（验证 issue 主张的"8/20 升级细节"）

| DEC | 日期 | 状态 | 标题主旨 | 实质类型 | 该开 DEC? | 若不该，替代落点 |
|---|---|---|---|---|---|---|
| DEC-001 | 2026-04-18 | Accepted | plugin 打包 D1-D9 | 跨模块接口 + 分发架构 | ✅ | — |
| DEC-002 | 2026-04-18 | Accepted（部分 Superseded）| shared resource / escalation / workflow matrix | 跨模块接口 + schema 选型 | ✅ | — |
| DEC-003 | 2026-04-19 | Accepted | architect → parallel research | 跨模块接口（新 agent 派发契约）| ✅ | — |
| DEC-004 | 2026-04-19 | Accepted（决定 6 Superseded）| subagent progress event protocol | schema 选型（JSON 事件契约）| ✅ | — |
| DEC-005 | 2026-04-19 | Accepted | developer 双形态 | 新依赖（inline 执行形态引入）| ✅ | — |
| DEC-006 | 2026-04-19 | Accepted | workflow phase gating 三段式 | 方向性选型（A/B/C taxonomy）| ✅ | — |
| DEC-007 | 2026-04-19 | Accepted | progress content policy | 细化 DEC-004 | ⚠️ 实为 DEC-004 细化；现行分开存放 | inline append 父 DEC（若按子议题 2 铁律 4）|
| DEC-008 | 2026-04-19 | Accepted | Step 3.5 前台免 Monitor | 修正 DEC-004 触发规则 | ✅（反转条款）| — |
| DEC-009 | 2026-04-19 | 部分 Superseded | 轻量化重构 | 10 条混合（抽取 / batching / 影响范围 10 行 等结构性规则）| ⚠️ 本条多决定混放，内部张力（决定 1 被 DEC-010 Supersede，决定 10 是"影响范围 ≤10 行"元规则）| 拆分为元规则 DEC（子议题 2 铁律 5 原型）+ 实现 DEC |
| DEC-010 | 2026-04-19 | Accepted | revert helper + inline 精简 | 跨模块接口（反转 DEC-009 决定 1）| ✅ | — |
| DEC-011 | 2026-04-19 | Accepted | DEC 顺序约定传导目标项目 | 跨模块接口（SKILL.md 契约 + template）| ✅ | — |
| DEC-012 | 2026-04-19 | Accepted | subagent run_in_background 策略 | 方向性选型 | ✅ | — |
| DEC-013 | 2026-04-20 | Accepted | decision_mode modal/text | 新依赖（远程前端支持）| ✅ | — |
| DEC-014 | 2026-04-20 | Accepted | bugfix 根因分层落盘 | 新依赖（bugfixes/ 目录 + 3-tier）| ✅ | — |
| DEC-015 | 2026-04-20 | Accepted | auto-execute mode | 新依赖（预授权）| ✅ | — |
| DEC-016 | 2026-04-20 | Accepted | decision parallelism | 跨模块接口（Step 4b 新章）| ✅ | — |
| DEC-017 | 2026-04-21 | Accepted | reviewer/tester relay 反转 | 跨模块接口（Write 契约）| ✅ | — |
| DEC-017 Amendment | 2026-04-21 | Accepted（Refines DEC-017）| review → db-review 前缀 | 实现细节（字符串重命名）| ❌ | commit message + inline post-fix |
| DEC-018 | 2026-04-21 | Accepted | TG 转发字节等价 → 语义等价 | UX 偏好（markdownv2 渲染风格）| ⚠️ 方向性但不涉 DEC-001 D1-D9 / schema | feedback memory 或 inline post-fix 父 DEC-013（§3.1a 条款所在）|
| DEC-019 | 2026-04-21 | Accepted | Step 7 Relay Write 契约收紧 | 修正 DEC-017 + 新增三条细化 | ⚠️ 落盘当日 post-fix 性质，≤10 行 | inline post-fix DEC-017 末尾 |
| DEC-020 | 2026-04-21 | Accepted | auto-halt text fallback 渲染 | 细化 DEC-016 + DEC-013 | ⚠️ post-fix 性质 | inline post-fix DEC-016 末尾 |

**汇总**：
- **应开（真架构决策）**：DEC-001/002/003/004/005/006/008/010/011/012/013/014/015/016/017 = **15 条**
- **应走其他路径（post-fix 或 feedback memory 或 commit message）**：DEC-007（细化 DEC-004）/ DEC-017 Amendment / DEC-018 / DEC-019 / DEC-020 = **5 条**
- **张力**：DEC-009 是 10 条决定的混合体（"元规则 ≤10 行"与"helper 抽取"同档），子议题 2 铁律 5 实际上是从 DEC-009 决定 10 抽取的元规则
- issue #84 主张 "8/20 升级细节" —— 实测 **5/20 应走其他路径**，比 issue 保守 3 条（DEC-013 post-fix 段本属父 DEC 内细化、DEC-007 是 DEC-004 细化；实际"不该开"个数低于 issue 声称但**方向**一致）

### 3. token 力学（架构师 skill + reviewer agent 的读取契约实测）

| 强制度 | 调用点 | 原文 | 覆盖范围 |
|---|---|---|---|
| **强制** | `skills/architect/SKILL.md:L12` | "若 `{docs_root}/decision-log.md` 存在，读**全部 DEC 条目**。新设计**不得与 Accepted DEC 矛盾**；若矛盾必须显式引用旧 DEC 编号走 Superseded 流程" | 全 575 行 |
| **近强制** | `agents/reviewer.md:L91` | "按 slug 查 `design-docs/[slug].md` + `exec-plans/active/[slug]-plan.md` + `decision-log.md`（**全文**，对照相关 DEC）" | 全 575 行 |
| 按需 | developer / tester / dba / research | Resource Access Read 列声明，**无强制读条款** | 任意（通常不读）|
| 不读 | analyst | Read 列未列 decision-log.md | — |

**每 workflow 消费估算**（按 1 workflow = 1 architect skill + 1 reviewer agent + 若命中 critical_modules 则 + 1 tester agent；tester 本身 Read 列含 decision-log 但无强制条款，取按需偏不读）：

- architect 全读 1 次：8763 words × 1.3 = **11.4k tokens**
- reviewer 全读 1 次：8763 × 1.3 = **11.4k tokens**
- 合计：**22.8k tokens / workflow**（纯 decision-log 读取，未含实际分析 token）
- issue #84 估算 "30k / workflow" —— 实测 22.8k，issue 高估 32%（或含了其他 workflow.md / CLAUDE.md 的读取）

**按 DEC 段消费率**（issue 估算）：决定 + 影响范围 100% / 相关文档 70% / 上下文 20% / 理由 25% / 备选 10%。本分析**不独立验证百分比**（需 LLM 消费日志），但 Nygard 原文"大文档无人读"的定性 finding 支持 issue 方向。

**方案 B（索引按需读）可达成量**：
- INDEX.md DEC 索引段（DEC# + 标题 + 状态 + 相关 slug / 20 条 × 1 行 ≈ 30 行）≈ 1k tokens
- architect 写新 DEC 时按需读 3-5 相关 DEC 条目平均每条 ~25 行 ≈ 4-6k tokens
- **每 workflow**：1k（index） + 5k（按需）≈ **6k** vs 现 22.8k → ~**74% 减免**，与 issue 估算 67% 接近（issue 保守）

### 4. 外部 ADR 实践对照

| 实践 | 门槛声明 | 状态 lifecycle | 条目长度 | 归档 | 对 roundtable 适用性 |
|---|---|---|---|---|---|
| **Nygard 原版（2011）** | "affect structure / non-functional / dependencies / interfaces / construction techniques"（架构显著性）| Proposed / Accepted / **Deprecated** / Superseded（引后继）| "一到两页"（强调 "large documents are never kept up to date"）| 不特别指明（append-only） | 门槛描述与子议题 1 "5 类必开" 同向；Deprecated 状态在 roundtable 缺失（当前只有 Superseded / Rejected） |
| **MADR (Markdown ADR v4)** | 继承 Nygard"architecturally significant" + 7 维度（business value/risk / stakeholder / quality / deps / cross-cutting / first-of-a-kind / past troublemaker）| Proposed/Rejected/Accepted/**Deprecated**/… / Superseded-by（"..."留扩展位）| minimal variant（无 optional 节）| Superseded 走 status 字段链后继 | 7 维度可作为子议题 1 "5 类必开" 的交叉检验 |
| **Y-Statements (Zdun et al.)** | 结合"architectural significance"; 格式压缩 | 同上 | **极短**（6 段单句）："In context of U, facing C we decided for O and neglected A, to achieve Q, accepting D" | 不涉 | roundtable DEC 格式 ≈ MADR 简版；Y-Statement 的 "neglected" 段就是 roundtable 的 "备选" 段，issue 估算该段 10% 消费率与 Y-Statements 作者建议的"长句可拆 2-3 句"自洽 |
| **adr-tools (ThoughtWorks)** | 未限定门槛 | Proposed/Accepted/Deprecated/Superseded（CLI 命令 `supersede`）| 自由 | 不强制归档；supersede 由工具加链接 | roundtable 手工维护 Superseded 链（DEC-004 决定 6 Superseded by DEC-008），未工具化；子议题 4 "归档 stub 格式" 未见于主流 ADR 实践 |

**关键对照**：
- 4 实践 **无一** 采用"Provisional"冷却窗口状态 —— issue 子议题 2 新增 Provisional 是 roundtable 对"落盘当日补丁"（DEC-017 Amendment / DEC-019）痛点的原创应对，外部参考有限
- 4 实践 **无一** 限定条目长度上限（仅 Nygard "一到两页" 建议）—— issue 子议题 2 铁律 5 "影响范围 ≤10 行" 是 roundtable 自 DEC-009 决定 10 确立的内部纪律，不抄自外部
- "门槛" 在 Nygard / MADR 都是**定性描述**（architecturally significant），issue 子议题 1 把它落成 **5 类枚举** 是定性→定量的强化

### 5. commit + prompt DEC 引用分布

**commit message 中 DEC 引用 Top 10**（来源 `git log --all --grep="DEC-" | grep -oE "DEC-[0-9]+"`）：

| DEC | 次数 |
|---|---|
| DEC-013 | 6 |
| DEC-014 | 4 |
| DEC-015 | 4 |
| DEC-020/021/022/023/024 | 2 each |
| DEC-006~012 | 2 each |
| DEC-002/003/004/005/016 | 1 each |
| DEC-001 | **0** |

**prompt body 中 DEC 引用 Top 10**（来源 `grep -rnE "DEC-[0-9]+" skills/ agents/ commands/`）：

| DEC | 次数 |
|---|---|
| DEC-013 | 12 |
| DEC-017 | 9 |
| DEC-006 | 7 |
| DEC-004 | 7 |
| DEC-018 | 5 |
| DEC-014 | 4 |
| DEC-002/003 | 3 each |
| DEC-005/007/020 | 2 each |
| DEC-009/015/019 | 1 each |
| **DEC-001/008/010/011/012/016** | **0 each** |

**两维度交叉**：
- **热 DEC**（commit ≥2 AND prompt ≥3）：DEC-002 / DEC-004 / DEC-006 / DEC-013 / DEC-014 / DEC-017 / DEC-018 → 7 条，与子议题 4 "冷门归档候选" 互补（这些归档风险高）
- **冷 DEC**（prompt = 0）：DEC-001/008/010/011/012/016 → 6 条。其中 DEC-001 是 D1-D9 plugin 打包总纲（CLAUDE.md critical_modules 引用），不能归档；DEC-008/010/011/012/016 未被 prompt 本体引用但都是 Accepted 状态，子议题 4 归档候选讨论需先确认这不代表它们"不重要"（可能是规则已下沉到 workflow.md 条文）

### 6. 子议题依赖图再审

issue #84 主张线性 1 → 2 → 3 → 4。事实层观察：

- **1 与 2 深度融合**：子议题 1 的"clarification 走 post-fix 父 DEC" = 子议题 2 铁律 4 "clarification 统一 post-fix inline"。这两条是**同一规则的两次表述**（一次在门槛分类表的"不该开 → 正确落点"列，一次作为独立铁律）—— architect 做 design 时需显式合并为单规则，否则 decision-log.md 会出现"既在门槛章又在铁律章"的双声源
- **3 的 B.1 可并行**：方案 B.1（INDEX.md 新增 DEC 索引段）是纯文档基础设施，与 1/2 的元规则改动**不相互阻塞**；B.2/B.3（architect SKILL.md + reviewer.md 改读取契约）触发 critical_modules，必须**在 1+2 收敛后**做（否则读取契约改造遇到仍在膨胀的 decision-log 会 regression）
- **4 确实最后**：归档触发条件（"Superseded ≥90 天 AND 后继 ≥30 天无新 Refined/Superseded AND 无他处引用"）要求 1+2 的"状态定义"先稳定
- **新识别依赖**：子议题 2 新增 `Provisional` 状态 → lint 规则需更新（`commands/lint.md` 现扫 "Proposed > 30 天"，需追加 "Provisional > 30 天 + Superseded > 90 天"），此为**横切子议题 2 ↔ commands/lint.md** 的次级依赖，issue 未显式列出但在 "相关" 段提及

## 对比分析

（本节遵守 analyst 边界：只陈 fact / 改造面 / 代价，不做推荐）

### 子议题 1 门槛收紧路径对比

| 路径 | 事实基础 | 改造面 | 代价 |
|---|---|---|---|
| A：issue 当前版（5 类必开 + 4 类"不该开" 路由表） | MADR 7 维度定性参考 | decision-log.md 元规则章 + architect SKILL.md §阶段 2 加"自问 5 类"句 | ~20 行文本；不触 critical_modules prompt 本体（architect SKILL.md 属 critical_modules，**触发 tester/reviewer**）|
| B：纯定性（学 Nygard "architecturally significant" 一句话）| Nygard 原版简单 | decision-log.md 元规则章简笔 | ~5 行；依赖 architect judgment，LLM 主观解读空间大 |
| C：不改，保持现状 | — | 无 | 条目继续膨胀（线性外推 3 月 +60 DEC）|

### 子议题 2 元规则扩展路径对比

| 路径 | 事实基础 | 改造面 | 代价 |
|---|---|---|---|
| A：issue 当前版（Provisional + Refined by 一等 + 铁律 4/5/6）| 本地已预写 15 行；无外部 ADR 先例 | decision-log.md 元规则章 + DEC-025 追认 Provisional 自己 dogfood | ~30 行 + 1 新 DEC；不触 critical_modules |
| B：仅 Refined by + 铁律 4（最小集）| Refined by 当前已以括注混写存在（DEC-017 Amendment / DEC-018/019/020）| decision-log.md 元规则章 | ~10 行；不引入 Provisional 冷却窗口（风险：落盘当日补丁失效模式仍存）|
| C：纯铁律 5（影响范围 ≤10 行）单做 | 自 DEC-009 决定 10 立 | decision-log.md 元规则章 | ~3 行；最保守；不解 post-fix 散布问题 |

### 子议题 3 token 优化路径对比

| 路径 | 事实基础 | 改造面 | 代价 |
|---|---|---|---|
| B.1：INDEX.md 新增 DEC 索引段（按需读）| 当前 INDEX.md 无 DEC 索引；20 DEC × 1 行 ≈ 30 行可览 | docs/INDEX.md | ~30 行；纯文档；不触 critical_modules |
| B.2+B.3：architect SKILL.md + reviewer.md 改"全文" → "索引 + 按需" | SKILL.md:L12 / reviewer.md:L91 明确声明全读 | skills/architect/SKILL.md + agents/reviewer.md | **命中 critical_modules** —— 必须走 tester + reviewer ；文字 ~10 行但风险高 |
| A（分层存储备选 + 理由外放 design-docs）| roundtable 已有 design-docs/ 目录；20 DEC 外放后主文件 ~280 行 | decision-log.md + 批量新建 design-docs/[dec-slug].md（20 个）| 大工程（~20 文件 × 150 字 = 3000+ 字新增 design-docs）；历史 DEC 不回溯则需 cutoff 日期 |
| 不做 | — | 无 | 条目膨胀前线性涨 token；按 100+ DEC 外推 ~57k/workflow |

### 子议题 4 归档策略路径对比

| 路径 | 事实基础 | 改造面 | 代价 |
|---|---|---|---|
| issue 当前版（4 触发条件 AND / 按季度 archive/ / stub 5 行）| 无外部 ADR 先例直接对应 | docs/decision-log.md + 新建 docs/archive/ | 不在 MVP scope（当前 20 DEC 远未触发 90 + 30 天条件）|
| 仅立"归档占位规则"不真归档 | — | 元规则章 + 铁律 7 草案 | 低；仅为未来预留；子议题 1+2 见效后本议题可能永不触发 |
| 不立规则 | — | 无 | 超 100 DEC 后返工成本上升 |

## 开放问题清单（事实层）

1. **问题**：`docs/INDEX.md` 新增 DEC 索引段的**所有权**归 orchestrator（Step 7 shared resource 转发）还是归 architect（本身产出 DEC 的角色）。事实：当前 Step 7 明确 `INDEX.md` 属 orchestrator 批量维护（`commands/workflow.md:L524-546`）；但 DEC 是 architect 权威产出，索引条目与 DEC 本文生死绑定
2. **问题**：`Provisional` 状态的自动转正信号源：是 `commands/lint.md` 周期扫描（当前扫 "长期 Proposed" 已有基础），还是 workflow 每次启动 pre-check？事实：`commands/lint.md` 当前周期驱动不明，没有 cron/git hook 自动跑
3. **问题**：铁律 6 "默认不改清单" 的清单稳定性 —— 清单本身是否应该作为 DEC-025 的"相关文档"列出？事实：当前"不改清单"列了 8 类目（D1-D9 / 5 agent / 2 skill / workflow 各章 / critical_modules / target CLAUDE.md / 3 schema），每类有源头 DEC，但清单本身无 DEC 承载，变成"元元规则"
4. **问题**：DEC-017 Amendment 若按子议题 2 铁律 4 改为 inline post-fix DEC-017，其 DEC-019 / DEC-018 / DEC-020 的引用链需同步改写（"Refines DEC-017 Amendment §Y" → "见 DEC-017 post-fix 2026-04-21"）。事实：当前 DEC-020 状态行是 `Accepted（Refines DEC-016 §3.3）`，DEC-019 正文多处引 DEC-017 D6
5. **问题**：方案 B.2+B.3 改 architect SKILL.md "全读" → "读索引 + 按需 Read 相关 DEC" 时，architect 如何得知"相关"？事实：当前 design-doc frontmatter **无** `decisions:` 字段（抽样 `docs/design-docs/phase-transition-rhythm.md` / `parallel-decisions.md` 只有 `slug:`）—— 需要先补字段或让 architect 按 slug 全盘扫
6. **问题**：归档 stub 格式的跨文件 anchor（`../archive/decision-log-2026-Q2.md#dec-009`）在 GitHub 网页渲染下的可用性；事实：GitHub 支持相对链接到 md 文件的 heading anchor（基于 kebab-slug），但 level-3 header `### DEC-009 [标题]` 的 slug 包含中文可能 anchor 失效（见 `anchors` GitHub spec）
7. **问题**：子议题 1+2 如果合并为单 DEC（因规则高度耦合），DEC 编号是否跨越（如 DEC-025 含门槛 + 元规则 + Provisional + 3 铁律）会超 10 行影响范围硬约束？事实：预估若合并，影响范围覆盖 decision-log.md 元规则章 + architect SKILL.md + commands/lint.md ≈ 4-6 行，可行；若不合并则需 DEC-025 + DEC-026 两条落盘

## FAQ

### Q: analyst 为什么不推荐"5 类必开"的具体语义边界（如"跨模块接口"vs"实现细节"）？

A：语义边界是 architect 职责，涉及 judgment call。analyst 只陈"20 DEC 里哪些实测走了该走的路径"（表 §2），让 architect 基于该事实确定门槛措辞。

### Q: issue #84 说 "~67% token 减免"，本报告算出 "~74%"，差异来源？

A：issue 估算分母用"15k tokens（architect 全读）"本文用"11.4k（8763 words × 1.3）"，issue 可能把 workflow.md / CLAUDE.md 的联带读取也算进 decision-log 账上。本文只算纯 decision-log 读取。两者方向一致，具体百分比以实装后 LLM 消费日志为准。

### Q: `Provisional` 状态如果永远不转正，会有什么后果？

A：事实层 —— 当前无自动化强制。后果：条目停留 Provisional 状态，下游 architect / reviewer 读到时不知该按 Accepted 处理还是 Proposed。`commands/lint.md` 若扩"Provisional > 30 天告警"是人工 fallback，依赖 lint 被跑。

### Q: 20 DEC 分类 "5/20 应走其他路径"，比 issue "8/20" 少 3 条，哪些没判为"应走其他路径"？

A：本报告判 DEC-013 完整条目应开（issue 列 DEC-013 post-fix ×3 段为"post-fix 路径正确"即肯定其 post-fix 段，**但 DEC-013 本身作为 decision_mode 方向性选型**是应开的，post-fix 细化另说），以及 DEC-007 定性细化判为"应走其他路径"。issue 的 8 条数字可能将 DEC-013 多次 post-fix append 各算 1 条，计数口径差异而非方向差异。

### Q: 子议题 1 收紧门槛后，DEC-017 Amendment / DEC-018/019/020 是否应逆向降级为 inline post-fix？

A：issue 明确"不回溯：DEC-001~020 不因新门槛被降级"。事实层 —— 降级会破坏已 git commit 的引用链（DEC-019 多处引 DEC-017 D6）。

### Q: obra/superpowers 对 decision-log 可持续性 4 子议题有哪些可借鉴 pattern？

A：事实层调研（来源：superpowers repo / RELEASE-NOTES.md / using-superpowers SKILL.md / hooks.json；交叉 roundtable 本仓 issue #80 背景）。

**A1. 是否有 ADR / decision-log 概念**（对应子议题 1 门槛 / 子议题 2 元规则）：

| 维度 | superpowers 实际 | roundtable 对比 |
|---|---|---|
| 决策记录形式 | **无显式 ADR / decision-log** | `docs/decision-log.md` 20 DEC append-only |
| 变更追踪 | `RELEASE-NOTES.md` 按 semver 聚合 + Keep-A-Changelog 分类（Added / Changed / Breaking / Removed / Bug Fixes）| DEC 级 + log.md 时间索引双轨 |
| 变更上下文 | 每条 entry 附 rationale、PR/issue 链接、performance 数据、跨版本 cross-ref（`#910` / `PR #753` / `PRI-823`）| DEC 条目含"上下文/备选/理由"段 |
| 版本粒度 | 版本号粒度（v5.0.7 等）| DEC 编号粒度（DEC-xxx）|

**观察**：superpowers 的**"无 ADR"**本身是一种治理选择 —— 用 RELEASE-NOTES + git history 承担 DEC 的"何时何人为何改"职能。这不直接对应子议题 1 的"门槛"问题，但提供了"**是否需要 DEC 这一层**" 的外部对照点：subject 粒度的决策可由 commit message + release notes 覆盖。

**A2. skill 组织 / 动态加载**（对应子议题 3 token 优化）：

| 维度 | superpowers 机制 | 对子议题 3 的映射 |
|---|---|---|
| 加载策略声明 | Gemini CLI 分支："loads skill metadata at session start and activates the full content on demand"（**metadata first / body on demand**）| 对应方案 B "INDEX + 按需读" 同向 |
| Claude Code 分支 | Skill 工具调用即加载全文；"Never use the Read tool on skill files"（强制通过 tool 入口）| 与 roundtable architect SKILL.md:L12 "读全部 DEC" 类似强制 |
| 触发模型 | "skills trigger automatically based on context"（上下文驱动）| DEC 触发无自动机制，靠 prompt 硬编码"必读" |
| 跨 agent 传导 | `hooks.json` `SessionStart` matcher=`startup\|clear\|compact` + `${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd session-start` 注入 `using-superpowers` skill | roundtable 无等价（issue #80 调研目标之一）|

**观察**：superpowers 有两种加载范式并存 —— eager（Claude Code）与 lazy（Gemini）。lazy 范式与子议题 3 方案 B"索引按需读"心智一致。但需注意 superpowers 加载的是 **skill body（指令）**，roundtable 加载的是 **DEC body（决策记录）**，前者是 prescriptive 后者是 descriptive，lazy 加载安全度不同。

**A3. "Red Flags" 表与门槛心智**（对应子议题 1 门槛收紧）：

using-superpowers SKILL.md 含 **Red Flags 表** 列举"这些想法意味着 STOP"的反模式（如"This is just a simple question" → Questions are tasks; "The skill is overkill" → Simple tasks become complex; use the skill）。模式本质：**把"什么时候不该跳过 skill"显式化为反模式清单**。

| superpowers Red Flags 形态 | 对子议题 1 潜在映射 |
|---|---|
| "跳过 skill 的常见理由化" 被 list 成 anti-pattern | "开新 DEC 的常见理由化" 可同构 list 成 anti-pattern（如"这只是个小命名 → 其实就该走 commit msg"/"它影响了 3 个文件所以很重要 → 其实是实现细节"）|

**观察**：Red Flags 是"**显式列负例**"的防守型门槛，与 issue 子议题 1 "5 类必开（正例）"互补。roundtable 如要强化门槛，**正例列表 + 负例列表** 是两个正交的配置点。

**A4. skill 契约管理 / 稳定性策略**（对应子议题 1 + 子议题 4 归档）：

| superpowers 策略 | 机制 | 对比 roundtable |
|---|---|---|
| **"we don't generally accept contributions of new skills"** | policy 层稳定性 | roundtable 无显式 contribution policy；DEC 开立无 gatekeeper |
| Skills 跨 4 平台同步（Claude / Cursor / Codex / Gemini）| "any updates to skills must work across all coding agents we support" | roundtable 单平台（Claude Code），契约复杂度低 |
| skill 归档 / 废弃机制 | **无显式机制**（依赖 git 历史）| 子议题 4 归档 stub 机制是 roundtable 原创 |

**观察**：superpowers 的"稳定性"靠**policy gate**（不轻易接受新贡献）+ **多平台同步约束**（隐式提高变更代价）两层守护，而非 archival / stub 机制。roundtable 是 plugin 单平台，没有多平台同步的天然刹车，所以子议题 1 的"门槛收紧"在 roundtable 更必要。

**A5. dogfood loop**（对应子议题 1 失败模式 "门槛收紧后回归"）：

| superpowers 机制 | 说明 |
|---|---|
| `writing-skills` skill | meta-skill：教用户/agent 如何写新 skill；follows same skill-invocation pattern |
| "brainstorm → design → plan → execute → review → test → complete" 工作流 | 过程纪律内嵌入 skill 链 |
| 明确无 dogfood loop 宣言 | "Knowing the concept ≠ using the skill. Invoke it." —— 避免 agent 凭记忆跳过 skill |

**观察**：superpowers 用 **"强制 invoke 而非凭记忆"** 来防止纪律衰减。roundtable 子议题 1 的失败模式"门槛收紧后被 LLM 按旧习惯 collapse 回开 DEC" 同构 —— 可能需要等价的**每次 design 阶段强制过一遍门槛检查**的机制（如在 architect skill 里嵌一个 "opening bar checklist" 的自问 prompt），而不是仅在 decision-log.md 顶部立规则后寄望被读到。

**A6. 不可借鉴项**（显式列出以免 architect 误采）：

- superpowers **MIT LICENSE / 多平台支持 / `tests/` 目录**：与 decision-log 可持续性无直接关系（属 issue #80 独立议题域）
- `<SUBAGENT-STOP>` / `<EXTREMELY-IMPORTANT>` 标记：用于 skill 在不同 agent context 下的选择性执行，与 DEC 本体无关
- `commands/brainstorm` / `execute-plan` / `write-plan`：命令入口模式，与 decision-log 维护无关

**A7. 对 4 子议题的事实层小结**：

| 子议题 | superpowers 是否提供直接借鉴 | 可借鉴形态 |
|---|---|---|
| 1. 开立门槛 | 间接 | Red Flags 负例列表（补正例 "5 类必开"）+ "强制每次过门槛" 的 invoke-don't-remember pattern |
| 2. 元规则 | 弱 | Keep-A-Changelog 分类（Added / Changed / Breaking / Removed / Bug Fixes）可对应铁律 4 "clarification 分类"; "无 Provisional 先例"已在主表 §4 体现 |
| 3. token 优化 | 强 | Gemini CLI "metadata + on-demand body" 范式对子议题 3 方案 B 同向；`SessionStart` hook 注入 `using-<something>` 的注入点可作为 decision-log 索引的潜在 delivery channel（需评估是否与 issue #80 合并） |
| 4. 归档 | 无（反例）| superpowers 不归档靠 policy 稳定 + git 历史；roundtable 若复制此策略可能让子议题 4 变不必要，但前提是**子议题 1 门槛真能止血** |

**A8. 来源**（事实可追溯）：
- `https://github.com/obra/superpowers` 仓 README / 结构
- `https://raw.githubusercontent.com/obra/superpowers/main/RELEASE-NOTES.md`
- `https://raw.githubusercontent.com/obra/superpowers/main/skills/using-superpowers/SKILL.md`
- `https://raw.githubusercontent.com/obra/superpowers/main/hooks/hooks.json`
- roundtable 本仓 issue [#80](https://github.com/duktig666/roundtable/issues/80)（prior superpowers 调研启动，10 调研维度；本 FAQ 限于 decision-log 可持续性交叉视角，与 #80 全面调研不重叠）

## 相关

- issue #84 正文（umbrella）
- [lightweight-review.md](./lightweight-review.md)（prior DEC 体量 inventory）
- `docs/decision-log.md` L1-77（当前元规则区）
- `skills/architect/SKILL.md:L12` / `agents/reviewer.md:L91`（token 契约锚点）
- `commands/lint.md`（Proposed 超时扫描当前实现）
- `commands/workflow.md:L524-546`（Step 7 INDEX.md 维护责任边界）

## 外部来源

- [Documenting Architecture Decisions (Nygard, 2011)](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [ADR GitHub Homepage (adr.github.io)](https://adr.github.io/)
- [Y-Statements (Zdun et al., via ZIO Blog)](https://medium.com/olzzio/y-statements-10eb07b5a177)
- [MADR Template Primer (O. Zimmermann, 2022)](https://ozimmer.ch/practices/2022/11/22/MADRTemplatePrimer.html)

---

created:
  - path: docs/analyze/decision-log-sustainability.md
    description: issue #84 decision-log sustainability 4 子议题事实层分析（20 DEC 分类 / token 力学实测 / 外部 ADR 对照 / 依赖图再审 / 7 事实层开放问题交 architect）

log_entries:
  - prefix: analyze
    slug: decision-log-sustainability
    files: [docs/analyze/decision-log-sustainability.md]
    note: umbrella #84 事实基线 / 20 DEC 实证分类 / token 22.8k-per-workflow / 外部 ADR 4 实践对照 / 子议题 1+2 规则融合观察 / 7 事实层开放问题 / FAQ 扩 superpowers 借鉴（ADR 无 / Gemini metadata-lazy 对应子议题 3 B / Red Flags 反模式补子议题 1 门槛 / 无 Provisional 先例 / skill policy-gate vs 归档）
