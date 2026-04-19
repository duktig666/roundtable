---
slug: phase-transition-rhythm
source: 原创（含外部参考）
created: 2026-04-19
---

# workflow phase transition 节奏重构 分析报告

> 主题 slug: `phase-transition-rhythm`

## 背景与目标

Issue #10 观察到 P4 自消耗后重跑过程中 `commands/workflow.md` 现行规则的 UX 体感问题：

- **现行规则**（`commands/workflow.md:248`）："Phase gates: after each phase completes ... **wait for user confirmation** before advancing ..."——每次 cross-role transition 都要求用户确认（通常落实成 AskUserQuestion 弹窗 4 option）
- **观察到的失败模式**：选项疲劳、用户未读完产出文档就被迫点"推荐"、FAQ 空间被弹窗切断、与 `feedback_no_auto_push` / `feedback_no_auto_pr` 心智不一致

Issue 提出把 phase transition 按语义分三类：**产出阶段 end** / **approval gate** / **verification chain**，只在真正决策点保留 AskUserQuestion，产出阶段结束改为"用户主动 `go`"的对话式驱动。

本报告只陈事实、列开放问题，不做推荐（recommendation 属 architect 职责）。

---

## 追问框架（必答 2 + 按需 4）

**必答**

- **失败模式**：见 §失败模式事实（两种反向失败模式 + 一种混合失败模式）
- **6 个月后评价**：见 §6 个月后风险（扩展性、心智一致性、回归风险）

**按需**（本调研部分适用）

- 痛点：明确（用户已在 issue 正文描述，本报告 §背景 复述）
- 使用者与 journey：现有 roundtable 用户，通过 `/roundtable:workflow <task>` 进入；journey 沿 Phase Matrix 逐 stage 推进
- 最简方案：见 §调研发现 §1（现行 Step 6 规则 1 已含 Exception 条款，最简实施可能是条款扩展而非全面重写）
- 竞品对比：**适用，重点调研项** —— 见 §调研发现 §2

---

## 调研发现

### 1. roundtable 现状（事实层）

- `commands/workflow.md:248` 现行规则已含两处分层：
  1. "Exception: routine transitions within the same role ... MAY auto-advance"（同角色内多 sub-phase 自动前进）
  2. "Cross-role transitions ... always require confirmation unless CLAUDE.md critical_modules rule dictates the trigger"（跨角色默认停，但 critical_modules 机械触发时"用户仍看到 handoff 报告"）
- 产出角色（analyst / architect / reviewer）与 verification 角色（tester / dba）的边界在现行规则中**未显式命名**；它们统一归入"cross-role transitions"并默认走 confirmation
- `AskUserQuestion` 在现行规则中的地位：由各 skill/agent 的 Option Schema 约束（`feedback_askuserquestion_options` 要求每 option 带 rationale/tradeoff/recommended），但 phase-gate confirmation 本身是否必须走 AskUserQuestion、还是可以改为"等待用户文字输入"，现行规则**未明确**——实务上做成了 AskUserQuestion 弹窗
- DEC 层面：DEC-001 D5 是 "Scope = user"（见 `docs/decision-log.md:152`），issue 正文引用 D5 为"显式决策点 + 人工审批"**不匹配**（事实：现有 DEC-001 中对应该纪律的条款更接近 D2 "零 userConfig + 运行时自动检测" 下的 CLAUDE.md 业务规则机制，以及 DEC-002 Escalation Protocol）

### 2. 外部 CLI / orchestrator 的 stage transition UX 事实

> 来源：各工具官方文档 + 通用社区共识；本报告不新做 WebFetch 抓取，引用为既有知识。

#### 2.1 git（显式用户驱动）
- **产出阶段**：`git add` / `git commit` 每一步由用户显式触发；commit 完成后 git **静默停下**，不追问"是否 push"
- **approval gate**：无内建；destructive 命令（`git push --force` / `git reset --hard` / `git clean -f`）依赖**标志位显式授权**而非交互式 prompt
- **verification chain**：`pre-commit` / `pre-push` hook 自动运行，fail 即中止，不追问用户
- **体感**：每条命令只做命名的那一步；"下一步"完全由用户下一条命令决定

#### 2.2 terraform / ansible（典型 plan-apply 三段式）
- **产出阶段**：`terraform plan` 输出文件，退出码 0；不自动 apply
- **approval gate**：`terraform apply` 交互式 yes/no；`-auto-approve` 标志可跳过
- **verification chain**：apply 过程中各资源创建顺序由依赖图决定，中间不追问
- **体感**：producer → approval → execute 三段式在 IaC 领域是标准

#### 2.3 apt / yum / npm / pip（destructive 操作的选择性 prompt）
- 只在 **destructive** 操作前 prompt（install / remove / upgrade）；`-y` 跳过
- 只读操作（search / show / list）**无 prompt**
- **体感**：信息性产出（search）静默返回，破坏性动作强制确认——两类天然区分

#### 2.4 kubectl（工具本身不 prompt，上层组合 plan-apply）
- `kubectl apply -f`：默认直接执行，无 prompt
- `--dry-run=client/server`：产出即将发生的动作，不落地
- 社区插件 `kubectl-konfirm` 补 approval gate
- **体感**：核心工具不强制 approval gate，由使用者组合

#### 2.5 Make / Bazel（纯机器决策，无 approval）
- 依赖图 auto-traverse，recipe 静默执行
- 错误即中止，不追问
- **体感**：与 roundtable "AI orchestrator" 场景相距较远；仅作为"verification chain = 自动"的极端参考

#### 2.6 CrewAI（roundtable design_ref）
- 默认 `sequential` / `hierarchical` process：task 完成自动进下一个
- Human-in-loop 通过 `human_input: True` 在 task 定义里**显式声明**才触发
- **体感**：默认完全自动，human gate 是 opt-in，每处显式

#### 2.7 Microsoft AutoGen（roundtable design_ref）
- `UserProxyAgent.human_input_mode` 三档：`ALWAYS` / `TERMINATE` / `NEVER`
- GroupChat speaker selection 可包含 human agent
- **体感**：Human 参与度是全局模式开关，不是 per-phase 分类

#### 2.8 LangGraph（roundtable design_ref）
- `interrupt` 节点显式暂停等 human 输入；非 interrupt 节点默认边不停
- State checkpoint + resume 模式
- **体感**：中断是节点级 opt-in 声明——这与 issue 的分类思路（"产出阶段 end" 归一类 opt-in "等 user go"）最接近

#### 2.9 Anthropic Claude Code（roundtable 栖身平台）
- Plan mode：`ExitPlanMode` 是显式 approval gate
- 常规 edit：auto mode 下无 prompt；非 auto mode 下工具权限弹窗
- **体感**：approval gate 与常规执行在工具层就被区分了

### 3. 事实归纳

- **"产出 vs approval vs verification" 三分类**在工业界**有先例**但**命名不统一**：
  - plan-apply 三段式（terraform/ansible）= issue 的 "产出 + approval + execute"
  - destructive-only prompt（apt/npm）= 按动作语义分类而非按 phase
  - opt-in interrupt 节点（LangGraph）= issue 提议的"产出阶段结束停下等 go"
- **默认自动 + 显式 gate 声明**（CrewAI / LangGraph / AutoGen）是 AI agent 框架的主流，而非"默认 gate + 例外自动"
- **current roundtable 规则**反向：默认 cross-role gate，同角色内多 sub-phase 是例外；issue 的提议把 default 翻转为"verification chain 自动 + 产出阶段停下等 user"——**方向与 agent 框架主流对齐**

### 4. Issue 提议的分类映射（事实层核对）

| Issue 分类 | Issue 建议行为 | 最近的外部先例 | roundtable 当前归属 |
|---|---|---|---|
| context-detect → analyst | 自动 | CrewAI sequential | 已基本自动（Step 0 inline） |
| analyst → architect | 用户主动 `go` | LangGraph interrupt 节点 | 现为 cross-role gate，走 confirmation |
| architect → design-confirm | 必须 AskUserQuestion | terraform apply 交互式 | 现已是 design-confirm phase |
| design-confirm 通过 → developer | 自动 | terraform apply 通过后执行 | 现为 cross-role gate |
| developer → tester | 自动 | CI pipeline | 现为 cross-role gate（critical_modules 机械触发时仍停） |
| tester → reviewer | 自动 | CI pipeline | 现为 cross-role gate |
| reviewer 完成 → closeout | 用户主动 `commit` | git commit 由用户手发 | 现为 cross-role gate |

---

## 失败模式事实

1. **现行"默认 gate"的失败模式**（issue 观察到）：
   - 选项疲劳 → 用户默认点"推荐" → 决策虚化，等于名义上有 gate 实际自动
   - 产出文档未读完即被迫决策 → 决策质量下降
   - 弹窗切断对话 → FAQ 追问不自然
   
2. **反向"全自动 + 只保留 design-confirm"的失败模式**（假设 issue 建议实施后可能出现）：
   - 用户对 verification chain 的进度感知弱：developer → tester → reviewer 若全自动，中间 Critical 发现可能被后续步骤覆盖或延迟感知
   - reviewer 完成到 closeout 若全靠用户主动，用户忘记发 `commit` → task 长期挂起（现行实现里 orchestrator 明确停下等用户，不会孤儿化）
   
3. **分类边界混淆的失败模式**（混合风险）：
   - reviewer 在 issue 里归"产出阶段 end"（等用户 commit），但 reviewer 本质是 verification chain 末端——归类事实歧义
   - 同类 transition 在不同 task size 下行为不一致（如 small task reviewer 跳过 vs large task reviewer 必走）时，规则是否需要按 size 分层——issue 未覆盖
   - critical_modules 机械触发与"用户主动"两种驱动模式并存时，用户需要额外心智记住"哪些是机械的"

## 6 个月后风险

- **扩展性风险**：若未来新增 phase（如 deployment、security-review 二次轮询），三分类是否可扩容？还是每加一类都要 ad-hoc 决策？
- **心智一致性风险**：新规则与 `feedback_no_auto_push` / `feedback_no_auto_pr` 的"不可逆动作等用户主动"是同构的，但与 critical_modules 机械触发 tester 的自动性不同构——两种驱动同时存在会否让用户心智负担上升
- **回归风险**：若后续有人新增 phase 时不理解分类规则，可能把新 phase 误归"产出阶段"→退化成"每加一阶段都停"或误归"verification chain"→退化成"全自动"
- **DEC 归属风险**：如果本 issue 在 DEC 层没有明确归属（见开放问题 1），6 个月后这个规则可能会与某个未来新 DEC（如"workflow gating policy v2"）冲突或被暗中绕过

---

## 对比分析

本节只陈述各路径的事实代价，不得出现推荐措辞。

### 路径 A：最简——在现行 Step 6 规则 1 的 Exception 条款基础上扩展
- 事实基建：现规则已含"same-role auto-advance"和"critical_modules 机械触发"两个例外
- 改造面：在 Exception 条款里新增"产出阶段结束（analyst/architect/reviewer）改为等用户 `go`"
- 客观代价：规则阅读性下降（Exception 嵌套变深）；DEC 层面新增/不新增需架构师判断

### 路径 B：重写 Step 6 规则 1 为显式三分类
- 事实基建：issue 正文已给出分类草案表
- 改造面：替换现有规则 1 为新三段式规则；同步 `docs/design-docs/roundtable.md` 的 phase gate 描述
- 客观代价：DEC-001 D5 引用修正（issue 正文引用不精确，架构师需要正本清源）；可能需要新增 DEC-006 记录本次规则重构

### 路径 C：保留现行规则 + 增加 "user active continuation" 可选模式（opt-in）
- 事实基建：CLAUDE.md 支持 per-project 业务规则声明（如 `developer_form_default`）
- 改造面：新增 CLAUDE.md 可选 key（如 `phase_gating_policy: active | confirm`）；workflow.md 依 key 分支
- 客观代价：引入新配置维度，用户认知成本上升；两套规则并存的长期维护成本

### 路径 D：完全翻转默认——全自动 + 只保留 design-confirm 作为 hard gate
- 事实基建：CrewAI / LangGraph 等 AI agent 框架主流
- 改造面：删除现行 cross-role gate 默认；仅 design-confirm 保留；产出阶段 end 的"等 user go"改为 orchestrator 主动进入下一 phase
- 客观代价：与 issue 原意不完全一致（issue 仍希望产出阶段 end 停下）；失去 FAQ / 调范围的天然 pause 点

---

## 开放问题清单（事实层）

- **问题 1（DEC 归属）**：issue 正文引用"DEC-001 D5"作为"显式决策点 + 人工审批"核心纪律，事实上 `docs/decision-log.md:152` 的 DEC-001 D5 是 "Scope = user"。approval gate 纪律在现有 DEC 中更接近 DEC-002（Escalation Protocol + AskUserQuestion Option Schema）或 DEC-001 D2（CLAUDE.md 业务规则机制）。架构师需决定：本次重构条款落在哪条既有 DEC 名下，还是独立 DEC-006
- **问题 2（与现行 Exception 整合）**：`commands/workflow.md:248` 现已有两条例外条款（same-role auto-advance、critical_modules 机械触发）。issue 提出的新分类与这两条例外的边界需要架构师决策——是整合为统一分类表、还是保留 3 层（默认 + Exception1 + Exception2）
- **问题 3（reviewer 的归类歧义）**：issue 把 reviewer 完成归"产出阶段 end"（等 user commit），但 reviewer 本质是 verification chain。事实层两种归类都有支撑——architect 决策时需明示选择理由
- **问题 4（design-confirm UI 形式）**：issue 说 design-confirm 保留 AskUserQuestion 形式，但如果全局转向"用户主动 `go` / 回复文本驱动"，design-confirm 为什么例外？事实层有两种可能：(a) destructive 前 hard gate 传统强（terraform/apt 类）；(b) 对话式 "confirm/modify/reject" 文本输入也能达到同等纪律。architect 需选一
- **问题 5（critical_modules 机械触发的定位）**：现行规则里 critical_modules 可机械触发 tester（即使 cross-role 也不停），新规则里这属于 verification chain 自动吗？还是保留为独立类？事实层需明示
- **问题 6（closeout 阶段是否新增）**：issue 表格里出现"reviewer 完成 → closeout"但现行 Phase Matrix 没有 closeout 阶段。是新增 stage 还是 reviewer 完成即 workflow 终点？事实层缺失

---

## FAQ（分析过程中的问答记录）

（无——本次分析以 issue 正文为完整输入，未展开追问）
