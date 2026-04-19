---
slug: lightweight-review
source: 原创（issue #9 + 与 .claude-prototype-archive 对比）
created: 2026-04-19
description: roundtable plugin 全面瘦身审计 —— prompt 体量 inventory、archive 对照、4 大目标可行性评估、给 architect 的事实层开放问题
---

# roundtable 轻量化审计报告

> 主题 slug: `lightweight-review`
> 关联：[issue #9](https://github.com/duktig666/roundtable/issues/9) / `.claude-prototype-archive`（最初设计快照） / DEC-001 ~ DEC-008

## 背景与目标

issue #9 提出四件事：
- **A** prompt 文件瘦身 20-30%（抽取重复模板、删冗余、压缩示例）
- **B** `log.md` 写入改批处理（agent → orchestrator closeout flush，对齐 INDEX.md Step 7 模式）
- **C** `roundtable/CLAUDE.md` 的 5 条"设计参考" URL 迁出到 README
- **D** README 增 "## 设计思想" 章节（5 点：a~e 见 issue 正文）

任务非目标：不改 DEC-001 D1-D9 / DEC-002 / DEC-003 Accepted 条款；不破坏 `lint_cmd` 0 命中；不删功能（前后等价）。

## 追问框架（必答 2 + 按需 4）

**必答**

- **失败模式**：本次瘦身最可能在哪里失败？
  - 抽取共享 helper 后某 agent 的特定 ordering discipline（如 reviewer 的 Critical-finding ordering、tester 的 bug-found 顺序）丢失或被弱化，导致 dogfood 行为回归
  - "log.md closeout 批处理" 改造后，subagent **跨 session 中断**场景（用户 ctrl+C 退出会话）log 条目永远不落盘，违反 `log.md` "设计层文档时间索引" 定位
  - 共享 helper 的内部链接（`skills/_*.md`）在 plugin 安装为 user scope 后绝对路径解析失败，agent 找不到引用文件，prompt 实际上变得**比之前还长**（因为 fallback inline 描述）
  - 瘦身后某 agent 仍命中 critical_modules，必须走 tester+reviewer 全流程，迭代验证开销 ≥ 节约的 token

- **6 个月后评价**：会不会变成债务？
  - 若 helper 文件数量超过 5 个（当前 2 个：`_detect-project-context` / `_progress-content-policy`），新 agent 贡献者首次阅读门槛反而升高（要追 N 层 include），与"可读性"目标背道而驰
  - 若 README "设计思想" 章节与 `docs/design-docs/roundtable.md` D1-D9 表述漂移（同一思想在两处用不同措辞），未来某次 DEC 更新时容易只改一处，对外 ICP（external impression / cohesion principle）受损
  - log.md 批处理后若 closeout flush 漏写（orchestrator bug），整轮 workflow 的"何时何人动了哪份文档"信息永久丢失（不可重建），比当前"每个 agent 自写"反而更脆弱

**按需**：本调研适用于内部架构重构，绿地 4 问（痛点 / 使用者 / 最简方案 / 竞品对比）非主导，但**竞品对比**仍提供了关键约束 —— 见 §对比分析。

## 调研发现

### 1. 体量 inventory（事实层）

| 文件类别 | 当前 | Archive 对应 | 增量 | 增量主因 |
|---|---|---|---|---|
| `skills/architect.md` | 284 | `agents/architect.md` 136 | +148 | DEC-002 Resource Access (10 行) + DEC-003 Research Fan-out 阶段 1.5 (~50 行) + AskUserQuestion Option Schema (~30 行) + 三阶段流程细节扩展 |
| `skills/analyst.md` | 205 | `agents/analyst.md` 132 | +73 | DEC-002 Resource Access + AskUserQuestion Option Schema + slug "追问 vs 新主题"判定 |
| `skills/_detect-project-context.md` | 129 | — | +129 | DEC-002 §4 抽取（替代 Skill 激活失败的 fallback） |
| `skills/_progress-content-policy.md` | 68 | — | +68 | DEC-007（共享 helper） |
| `agents/developer.md` | 315 | 123 | +192 | Execution Form (DEC-005, ~30) + Resource Access (~10) + Escalation Protocol (~40) + Progress Reporting (~80) + Content Policy + Fallback (~25) |
| `agents/tester.md` | 284 | 53 | +231 | 同上 + tester 专属 ordering discipline / phase tag / 测试计划模板 |
| `agents/reviewer.md` | 261 | 93 | +168 | 同上 + Critical-finding ordering discipline + 落盘规则 |
| `agents/dba.md` | 233 | 86 | +147 | 同上 + Schema/migration/index 专属指南 |
| `agents/research.md` | 226 | — | +226 | DEC-003 完整新角色（Return Schema + Abort Criteria + Fallback） |
| `commands/workflow.md` | 437 | 75 | +362 | DEC-002 Phase Matrix + 并行判定树 + DEC-004 Step 3.5 progress monitor (~120) + DEC-005 Step 6b dev form (~80) + DEC-006 phase gating taxonomy (~60) + DEC-008 §3.5.0 gate (~30) + Step 7 INDEX maintenance (~50) |
| `commands/bugfix.md` | 138 | 55 | +83 | DEC-002 + DEC-008 §0.5 gate |
| `commands/lint.md` | 128 | 73 | +55 | INDEX 孤儿/断链/6 类清单 |
| **TOTAL** | **2708** | **826** | **+1882** | DEC-001 D1-D9 之外 7 个增量 DEC 累积 |

**结论**：archive 是 P0 雏形（仅 D1-D9 + 6 个简化 agent + 3 个简化 command）；现状每一行扩展几乎都能在 DEC-002 ~ DEC-008 找到出处。问题**不是"做错了"**，是**未做后处理压缩**——8 个 DEC 各自加了一段，没人回头抽公共。

### 2. 重复模板事实统计（issue #9 §A.1 的量化基础）

| 重复模式 | 出现次数 | 单次行数 | 累计行数 | 抽取后可降至 |
|---|---|---|---|---|
| `## Resource Access` 4 行表头 + N 行 matrix（外加"除非...授权否则禁用 git"段） | 7（5 agent + 2 skill） | ~10–15 行（表头+尾段固定，rows 因角色变） | ~70–100 | **3 行**（表头 + ref + role-specific rows 自留） |
| `## Escalation Protocol` JSON schema body（包括"Subagent 无法调用..." 引言、JSON 块、"规则" 3 条） | 4（developer/tester/reviewer/dba） | ~30 | **120** | 一条 ref 到共享 helper（每 agent ~5 行 = 20 行）→ **省 ~100** |
| `## Progress Reporting` （注入变量段、emit 模板、Phase tag 命名、Granularity、Fallback、与 Escalation 正交段） | 5（developer/tester/reviewer/dba/research[研究为半量]） | ~60–80 | ~300–400 | 共享 helper 加角色专属 phase tag 列表（每 agent ~15 行 = 75 行）→ **省 ~250** |
| `### Content Policy` 子节（已 ref `_progress-content-policy.md`，但仍重复 5 行 bullet） | 4 | ~12 | 48 | 仅保留 ref + 角色 example（每 agent ~5 行 = 20 行）→ **省 ~28** |
| log.md append 模板片段（`## <prefix> \| [slug] \| [日期]` + 3 行 bullets） | 6 角色（analyst/architect/developer/tester/reviewer/dba） | ~6 | 36 | 若改 closeout 批处理，**全删**→ 省 36 + 解释段 ~40 = **省 ~76** |
| "必需的上下文注入" 引言段（"调度方派发本 agent 时...必须..."）| 5 agent | ~6 | 30 | helper 化 → 省 ~20 |
| "命名约定" / "工作流程" / "约束" 等小节里"代码英文、注释中文、不...git 操作"重复 | ~6 文件 | ~3 | 18 | CLAUDE.md 通用规则已声明，全删 → 省 18 |

**保守估计**：抽取 + 去冗后总省 ≈ **480–600 行**，约 **18–22%**。命中 issue #9 目标 20-30% 区间下沿，如配合 commands/workflow.md Step 3.5 抽到 `_progress-monitor-setup.md` helper（~80 行可压到 5 行 ref），可上探 **25–28%**。

### 3. log.md 批处理改造的事实约束（issue #9 §B）

当前实际写入时机（grep 结果）：
- `analyst.md:199` —— 报告写完后 append 1 条 `analyze | ...`
- `architect.md`（未细读但模式同）—— 落盘 design-doc / DEC / exec-plan 后 append（含"合并原则"批 1 条）
- `developer.md:301` —— **仅** exec-plan 移到 completed/ 时 append；其余代码变更不写 log（已对齐 git log 边界）
- `tester.md:277` —— 仅产出 testing/ 文档时 append（中大任务）
- `reviewer.md:255` —— 仅落盘 review 时 append
- `dba.md`（未读全文，预计同 reviewer 模式）

事实：**developer 已是"按事件触发"而非"每 phase"**；analyst / architect / tester / reviewer / dba 各自在产出文档**那一刻**写。一轮 workflow 实际写入次数 ≈ 落盘文档数（典型 3-5 次），**不是** issue 描述的"3-5 次/轮"危机。

issue #9 §B 的真实价值**不在频次**，而在 **atomicity**：
- 当前 architect 同轮产出 design + DEC + exec-plan 已用"合并原则"合到 1 条；analyst → architect → developer → tester → reviewer 跨阶段是 N 条
- abort 场景（用户在 architect 后说"停"）→ analyst 的 log 已落、architect 的 log 已落、artifact 在但实现未推进，跨会话语义略残
- 改 closeout 批处理后：每 agent prompt 砍掉 "完成后" log append 段（每个 ~6 行 × 5 = 30 行），orchestrator 在 Stage 9 一次写多条；agent prompt 体量直接受益

**事实层 trade-off**（不做选型）：
- 保留现状：abort 场景 log 部分落盘 vs orchestrator bug 时**不**会全丢
- 改批处理：agent prompt 砍 30 行 + atomicity 提升 vs orchestrator 漏 flush 时整轮 log 全丢、跨 session 中断时未落盘条目永久丢失
- 折中（issue 本身写到的 §B.3）：用户阶段中间暂停 → orchestrator 先 flush 已完成阶段（"pause-point flush"）—— 这条折中在 issue 里已成型，是事实层定义而非待选

### 4. CLAUDE.md "## 设计参考" 的事实定位（issue #9 §C）

当前 5 条 URL（CrewAI / AutoGen / Anthropic Agent SDK / LangGraph / OpenAI Swarm）的语义性质：
- **lineage 陈述**（"我们对标 / 借鉴的是"），**不是决策契约**
- 每次 `/roundtable:workflow` 加载 CLAUDE.md 都消费这 5 行（约 12 行含描述）
- 同样信息在 `docs/design-docs/roundtable.md` D1-D9 决策评分里出现过
- README.md `## 致谢` 仅提到 gstack + Karpathy，未提对标框架

issue 提出的迁移方案（CLAUDE.md 留 1 行 pointer + README 新增 `## 对标参考`）—— 事实层成立条件：
- README 的 `## 对标参考` 章节定位明确（**对标**而非**致谢**），不与现有 `## 致谢` 段意冲突
- CLAUDE.md 新 1 行 pointer 用相对路径 `[README.md §对标参考](README.md#对标参考)`，roundtable plugin 安装到 `~/.claude/plugins/` 后链接相对解析仍可用（GitHub 渲染 + 本地 IDE 都跟）

### 5. README "## 设计思想" 章节的事实约束（issue #9 §D）

issue 给的 5 点 a~e 与现有 README 章节对照：
- `a` "对应正常开发工作流，agent 自动组织流程" —— 已隐含在 `## 为什么叫 roundtable` 散文，但未结构化
- `b` "每个阶段自动输入和输出文档，简化文档管理" —— 部分见 `## 设计原则 #2 plan-then-execute`
- `c` "参考 llm-wiki 思想：decision-log + log.md + INDEX.md" —— 仅在 `## 致谢` 一笔带过 Karpathy
- `d` "analyst / architect 由 agent → skill" —— 已在 `## 设计原则 #4` 明示
- `e` "analyst 借鉴 gstack 的六问检验" —— 已在 `## 致谢` 一笔带过

事实：**5 点中 c / e 在现状只藏在致谢，a / b 散文化未结构化**。新增 `## 设计思想` 章节的真实价值是**让贡献者在 install 前就能 pin down 心智模型**，避免提"已被 D1-D9 评估过否决"的方案（README 现有"贡献"段已警告但 D1-D9 内容在 design-doc 里）。

## 对比分析（archive vs 现状的"必要 / 过度"分类）

| DEC | 增量行数（估） | 必要性判定（事实） | 是否可瘦身 |
|---|---|---|---|
| **D1-D9（archive 已含核心，现状文档化扩展）** | baseline 826 | role / form / D9 / docs 布局 / userConfig 零弹窗，是 plugin 立项基础 | 不可触（issue 非目标） |
| **DEC-002 Resource Access matrix** | +70~100 | 解决"权限隐式靠 prompt 注入 → 并行派发 race"实际摩擦（P4 dogfood 证实）；7 角色重复表头是抽取热区 | **可抽取**（共享表头 + role-specific rows） |
| **DEC-002 Escalation Protocol** | +120~140 | 解决"subagent AskUserQuestion 禁用 → 文字 relay"摩擦；JSON schema body 5 处重复 | **可抽取**（共享 schema + role-specific 触发点） |
| **DEC-002 Phase Matrix + 并行判定树** | +100 | 让 orchestrator 状态对用户透明 + 加速决策可证伪；只在 workflow.md 单点出现，无重复 | 不抽（无重复处） |
| **DEC-003 research agent + Fan-out** | +226（research.md）+50（architect.md §阶段 1.5） | DEC-001 D8 单射的正交补强；研究广度爆炸的实际解药 | **少量瘦身**（架构 §阶段 1.5 表述可简） |
| **DEC-004 Progress Reporting** | +400~500（5 agent × 80） | dogfood 实证 subagent 长任务用户失控感的修复；事件驱动 push 与 jq pipeline 联动 | **大幅可抽取**（5 处重复 → 共享 `_progress-reporting.md` helper + 角色 phase tag 表，省 ~250） |
| **DEC-005 developer 双形态** | +30（developer.md §Execution Form）+80（workflow.md Step 6b） | P4 实证 4/9 dispatch 是 developer，UX 收益最高；唯一双形态 role | 不抽（单 role 单 entry，无重复） |
| **DEC-006 Phase gating taxonomy** | +60 + workflow.md Step 6 重写 | 选项疲劳的修复；与 AI agent 框架主流心智对齐 | 不抽（单点新增） |
| **DEC-007 Content Policy** | +68（_progress-content-policy.md）+ 4 角色 ~12 行 ref | dogfood 实证 dev agent 同 phase 重复 emit 刷屏；helper 已抽，但每角色 12 行 bullet 仍冗 | **少量瘦身**（每角色降到 1 ref + 1 example，共省 ~28） |
| **DEC-008 §3.5.0 gate** | +30 | 修正 DEC-004 §3.6 前台/后台触发漏洞 | 不抽（单点） |

**总结**：8 个 DEC 中 **DEC-002 / DEC-004 / DEC-007** 是抽取热区，三个加起来覆盖 issue #9 §A 目标 80%。其余 DEC 是单点新增、不可抽。

## 开放问题清单（事实层 → 给 architect 承接）

1. **共享 helper 引用方式**（事实）：现状 `skills/_detect-project-context.md` 和 `skills/_progress-content-policy.md` 都是"调用方 `Read` 后 inline 执行"模式（DEC-002 §4 + DEC-007 §决定 1）。新抽取的 `_resource-access.md` / `_escalation-protocol.md` / `_progress-reporting.md` 沿用同模式 vs 用 markdown link reference 由 LLM 自展开 —— 哪种**对 prompt 加载流量真实节省**未量化（前者每次 dispatch 仍要 Read，相当于把 token 从 agent prompt 移到运行时 Bash 调用；后者依赖 LLM 跟链接，存在漂移风险）。
2. **log.md 批处理 abort 语义**（事实）：当前 issue #9 §B.3 提"用户在阶段中间暂停 orchestrator 先 flush" —— 但跨 session 中断（用户直接退出 Claude Code、未说"停"）orchestrator 没机会 flush。事实上，与"每 agent 落盘即写"对比，跨 session 中断场景**新方案严格更弱**。是否接受这一退化？
3. **README 设计思想章节与 design-docs/roundtable.md D1-D9 的关系**（事实）：新章节是 D1-D9 的**摘要**（同源不同表述）vs **补充**（D1-D9 不涉及的 a/b/c/d/e 5 点心智）。issue 给的 5 点（a~e）实际有 c/e 已在 README `## 致谢`、d 在 `## 设计原则 #4`、a/b 隐含在散文 —— 是合并到现有章节、还是新独立章节？两种选择都成立。
4. **CLAUDE.md `## 对标参考` 的"对标"vs"致谢"边界**（事实）：CrewAI / AutoGen / LangGraph / OpenAI Swarm 是"对标"（架构借鉴 + 决策评分对照）；gstack 六问 / Karpathy LLM Wiki 是"致谢"（思想借鉴）。issue 提"5 条 URL 全迁到 README §对标参考"，但 OpenAI Swarm "启发显式决策点思路"语义其实更接近 gstack/Karpathy。归类边界由 architect 定。
5. **lint_cmd 0 命中假设的脆弱性**（事实）：现状 lint_cmd 是 `grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/`，硬编码白名单。新抽取的 helper 文件路径若用绝对路径（如 `~/.claude/plugins/roundtable/skills/_xxx.md`）会被 lint 命中？— 实测前无法判定，需要 architect / developer 验证。
6. **新 helper 文件命名约定**（事实）：现状 `_` 前缀表"plugin 内部 include-only 文件，非独立可激活 skill"（DEC-007 §决定 1）。新建 `_escalation-protocol.md` / `_progress-reporting.md` 沿用此约定时，是否需要在 `skills/` 顶部 README / INDEX 显式列出"内部 include-only"清单避免误激活？现状无该清单。
7. **抽取后 critical_modules 触发链**（事实）：现状 critical_modules 列出 "Skill / agent / command prompt 文件本体"。抽取后 `_resource-access.md` / `_escalation-protocol.md` / `_progress-reporting.md` 是否应纳入 critical_modules？三者改动会传播到所有调用 agent，比单 agent prompt 更"critical"，但 5 文件 fan-out 目前无明确策略。

## FAQ
（待 architect / 用户追问后追加）
