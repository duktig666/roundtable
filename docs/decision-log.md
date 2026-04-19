# roundtable 决策日志

> 记录 roundtable 项目所有关键设计和技术决策。
> 新条目追加在顶部（最新在前）。
> 本文件是项目知识的权威来源。

## 条目格式

```markdown
### DEC-[编号] [标题]
- **日期**: YYYY-MM-DD
- **状态**: Proposed | Accepted | Superseded by DEC-xxx | Rejected
- **上下文**: 为什么需要做这个决策
- **决定**: 最终选择
- **备选**: 考虑过但未采用的方案
- **理由**: 为什么这么选（关键权衡）
- **相关文档**: design-docs/xxx.md 等
- **影响范围**: 哪些部分受影响
```

## 状态说明

| 状态 | 含义 |
|------|------|
| Proposed | 已提出，待确认 |
| Accepted | 已确认采纳，正在执行或已落地 |
| Superseded by DEC-xxx | 被新决策取代（保留原文不删，标注取代者） |
| Rejected | 讨论后否决 |

## 铁律

1. **不删除旧条目**：被取代的条目标记为 Superseded，不删除
2. **冲突报 diff**：新决策与旧决策冲突时，必须在新条目中引用旧条目编号
3. **编号递增**：DEC 编号只增不减，不复用

---

### DEC-009 轻量化重构：4 shared helper + log.md closeout batching + README/CLAUDE.md 结构重塑
- **日期**: 2026-04-19
- **状态**: 部分 Superseded by DEC-010（决定 1 "4 shared helper 抽取" Superseded —— 运行期 token 账误判；决定 2 log.md batching / 决定 3-6 结构性规则 / 决定 8-10 DEC 修正条款仍 Accepted）
- **上下文**: issue #9 —— P0-P4 + 7 个增量 DEC（DEC-002 ~ DEC-008）累积使 `skills/ + agents/ + commands/` 行数从 archive 雏形 826 → 2708（3.16×）。analyst 量化识别 3 大重复热区：`## Resource Access` 7×、`## Escalation Protocol` JSON schema 4×、`## Progress Reporting` 5×（含 workflow.md Step 3.5 的 120 行本体）。每次 `/roundtable:workflow` 都消费这些重复 prompt，token 成本高且维护一处规则需改 N 处。log.md 每 agent 自带 append 模板又进一步推高 agent 体量；README 的 §致谢 藏着"对标/借鉴"信息未结构化。
- **决定**:
  1. **4 个新 shared helper**（`_` 前缀沿用 `_detect-project-context.md` / `_progress-content-policy.md` 的 plugin-内部 include-only 范式）：
     - `skills/_resource-access.md` —— 抽 7 角色的 RA 表头 + 末尾 git 段；role-specific rows 保留在原文件
     - `skills/_escalation-protocol.md` —— 抽 4 agent 的 JSON schema body + 通用规则 + Escalation vs Abort 段；typical triggers 保留
     - `skills/_progress-reporting.md` —— 抽 5 agent 的注入变量 / emit 模板 / Granularity / Fallback / Content Policy ref / 与 Escalation 正交段；role-specific phase tag 表 + Ordering discipline + Content Policy example 保留
     - `commands/_progress-monitor-setup.md` —— 抽 workflow.md Step 3.5.2~3.5.6；workflow.md 保留 §3.5.0 gate (DEC-008) + §3.5.1 env opt-out + 1 行 ref
  2. **log.md 改 Full closeout batching**（呼应 issue #9 §B）：
     - 5 agent "完成后" 段删除 append 模板；改在 final message/in-session output 的 `log_entries:` YAML block 上报
     - orchestrator 新增 Step 8（与 Step 7 INDEX Maintenance 同构，shared-resource 转发）—— Stage 9 Closeout 之前终点 flush；A 类 producer-pause 转场前 best-effort pause-point flush；C 类 verification-chain 过桥规则沿用 Step 7 同款
     - 跨 session 中断（用户未说"停"直接退出）未落盘窗口退化被接受，缓解依靠 pause-point flush
     - `docs/log.md` 头部"合并原则"文案同步更新反映 orchestrator 端合并
  3. **README.md 结构**：
     - §设计原则 5 条扩至 7 条，融入 issue #9 §D 的 5 点 a-e（去重；a+b+原 plan-then-execute 合成 #2，d 已覆盖于现 #4，c 上升为新 #5，e 上升为新 #6，多项目 #5 顺延 #7）
     - **删除** §致谢 / §贡献 / §许可证 三章（LICENSE / CONTRIBUTING.md 独立文件即可；致谢语义吸收到设计原则）
     - **不新增** §对标参考 / §设计思想 独立章节（用户决策比 issue #9 原方案更激进）
  4. **CLAUDE.md §设计参考 全删**（5 URL + 引言；lineage 信息 D1-D9 评分表存档够用）
  5. **critical_modules 扩写**：第 1 条 "Skill / agent / command prompt 文件本体" 明确含 `skills/_*.md` + `commands/_*.md` 共享 helper；`docs/claude-md-template.md` 同步
  6. **helper 引用模式沿用既定范式**：调用方 `Read` 后 inline 执行；不引入 markdown link auto-expand / yaml include / symbol ref 新机制
  7. **DEC-002 / DEC-004 / DEC-007 原文不打补丁**：DEC 是决策记录非索引；helper 新位置由 design-doc / INDEX.md 维护
  8. **正式 Supersede DEC-002 决定 5**（prompt 文件本体统一英文）—— 2026-04-19 已通过 `feedback_roundtable_prompt_language` 反转为"Plugin prompt 文件本体以中文为主，关键专有名词保留英文"（CLAUDE.md §通用规则已反映），但 `decision-log.md` 未走 Superseded 流程，违反铁律 #2 "冲突报 diff"。本决定正式补记：DEC-002 决定 5 Superseded by DEC-009 决定 8；DEC-002 状态行追加 "（决定 5 Superseded by DEC-009 决定 8）"标注
  9. **修 `commands/bugfix.md` 规则 2 对称性 bug**（DEC-005 实施 follow-through）—— bugfix.md 当前仅 honor `developer_form_default: subagent` 声明、`inline` 声明落空进入 AskUserQuestion（见 `docs/testing/subagent-progress-and-execution-model.md` case 3.6 WARN + `docs/reviews/2026-04-19-subagent-progress-and-execution-model.md` case 3.6）。本决定把规则 2 改为对称 honor：`if target_project CLAUDE.md declares developer_form_default (either inline or subagent), honor the declaration — this overrides the bugfix inline-bias default.`
  10. **DEC 影响范围段长度纪律**（新 append-only 约束，从 DEC-010 开始适用）—— 新增 DEC 的 "影响范围" 段 ≤10 行；超过部分提取到关联 `design-docs/[slug].md ## 影响文件清单` 章节外链。rationale：architect 每轮读 decision-log，长影响范围段放大上下文消费；决策本体（决定 / 备选 / 理由）是读的高价值区，影响范围 / 文件清单是实施细节可外放。本纪律**不回溯** DEC-001 ~ DEC-008，保 append-only
- **备选**:
  - **Moderate 2 helper**（仅抽 escalation + progress-reporting）：评分 32 vs Aggressive 33；未来改 Resource Access 仍改 5 处
  - **Conservative 1 helper**（仅抽 progress-reporting）：评分 30；不达 issue §A 20% 下沿
  - **Skip helper 抽取只删冗余文本**：评分 33（并列）但 issue §A 完全不达
  - **log.md 保留现状**：issue §B 验收不达，agent prompt 少省 ~180 行
  - **log.md Hybrid（抽 helper 不改行为）**：保留跨 session 可靠性但不达 issue §B atomicity 诉求
  - **README 新增 §设计思想 + §对标参考 独立章节（issue 原文）**：章节数 4→6 轻微膨胀；用户倾向压缩
  - **CLAUDE.md 保留 5 URL + 1 行 pointer（issue §C 原文）**：比现状省 12 行但仍每轮消费；用户直接删
  - **helper 部分纳入 critical_modules（仅 schema 类）**：分纳标准漂移风险，未来新 helper 判定要逐个审议
  - **helper 全不纳入 critical_modules**：单 agent 触发覆盖但另 4 agent 失视检查
- **理由**: (1) 3+1 helper 抽取直击 3 大重复热区（DEC-002/004/007 累积源），issue §A 20-25% 目标达成；(2) log.md closeout 与 Step 7 INDEX batching 同构心智统一；(3) pause-point flush 接受 97%+ 常见场景的 atomicity 收益并承认残余 abort 退化；(4) README 删 3 章节 + 合并设计思想 = 用户主张"文档不臃肿、贡献者 install 前 pin down"；(5) critical_modules 全纳入保证 helper 改动触发完整工作流验证；(6) 沿用既定 `_` 前缀 include 范式避免发明第三种引用机制；(7) 不改 DEC-004 event schema、不扩枚举、不改 Monitor 工具、不改 target CLAUDE.md 业务规则边界
- **相关文档**: docs/analyze/lightweight-review.md（量化审计 + 7 事实层开放问题）、docs/design-docs/lightweight-review.md（完整设计 + 4 决策量化评分）、docs/exec-plans/active/lightweight-review-plan.md（P0.1-P0.6 实施路线）、DEC-002（shared resource protocol 同构来源）、DEC-004（Progress Reporting 抽取源头）、DEC-007（Content Policy helper 范式参考）、DEC-008（Step 3.5 gate 保留不动）、issue #9
- **影响范围**: 新建 `skills/_resource-access.md` + `skills/_escalation-protocol.md` + `skills/_progress-reporting.md` + `commands/_progress-monitor-setup.md` 4 helper；改写 `agents/developer.md` / `agents/tester.md` / `agents/reviewer.md` / `agents/dba.md` / `agents/research.md` / `skills/architect.md` / `skills/analyst.md` 的 `## Resource Access` + `## Escalation Protocol` + `## Progress Reporting` + `## 完成后` 段；改写 `commands/workflow.md` §Step 3.5 + 新增 §Step 8 log batching；改写 `commands/bugfix.md` 同步 log batching；改写 `README.md` 结构（§设计原则 扩 + 删 §致谢/§贡献/§许可证）；改写 `CLAUDE.md` 删 §设计参考 + 扩 §critical_modules 首条；改写 `docs/claude-md-template.md` 同步；改写 `docs/log.md` 头部"合并原则"文案；改写 `docs/INDEX.md` 新增 skills/ + commands/ helper 清单。**不改** DEC-001 D1-D9、DEC-002/003/004/005/006/007/008 Accepted 条款。**不改** DEC-004 event schema、不扩 event 枚举、不改 Monitor 工具、不改 target 项目的 CLAUDE.md 业务规则边界。运行时行为变化：token 占用降低 ~22-25%；log.md 写入由 agent 自写转为 orchestrator 批处理；跨 session 中断时最后一段 C 类链的 log_entries 可能丢失（退化声明）

---

### DEC-010 矫正 DEC-009 决定 1：revert helper 抽取 + 激进 inline 精简（运行期 token 真减）
- **日期**: 2026-04-19
- **状态**: Accepted
- **上下文**: DEC-009 Accepted 后 closeout 阶段用户反馈"越加越多"。复盘发现 analyst/architect 估算 token 节省时只算"agent 单文件前后行数差"（-346），未算**每次 subagent 派发还要 Read N 个 helper**（~+300/派发）。真实账：单次典型 workflow（orchestrator + 3 subagent）token 负载 DEC-009 前 ~1540 行 → DEC-009 后 ~1800 行（**反增 17%**）。tree 总行 2708 → 2791（+83）。issue #9 原初目标 "Token 成本：每次会话加载长 prompt 耗 context" 未达成，反向
- **决定**:
  1. **Supersede DEC-009 决定 1**（4 shared helper 抽取 + 5 agent retrofit 到 ref 模式）—— 仅决定 1 被 supersede，DEC-009 其他 9 条决定保留
  2. **删除 4 新 helper**：`skills/_resource-access.md` / `skills/_escalation-protocol.md` / `skills/_progress-reporting.md` / `commands/_progress-monitor-setup.md`（`skills/_detect-project-context.md` + `skills/_progress-content-policy.md` 保留 —— 属 DEC-002 / DEC-007 范畴且它们的 helper 化有净收益）
  3. **激进 inline 精简**：5 agent + 2 skill + 2 command + workflow.md 全部重新 inline 但**每段压缩 40-60%**，删除：重复的"Subagent AskUserQuestion 禁用"解释 / 冗长 Fallback 散文 / Content Policy 示例多份 / DEC refs 尾引 / CLAUDE.md 通用规则的重复声明 / 冗长 AskUserQuestion / design-docs / exec-plan 模板 / 审查维度 bullets / 测试关注点 / phase tag 描述等
  4. **目标体量**：tree 2791 → ~1900（**净省 ~900 行，32%**）；单次典型 workflow 负载 ~1800 → ~1100（**省 ~700 行，39%**）
  5. **保留 DEC-009 其他收益**：log.md closeout batching（决定 2）/ README 合并（决定 3）/ CLAUDE.md 删 §设计参考（决定 4）/ critical_modules 扩写（决定 5 —— 含文本调整，因 _*.md helper 从 4 个减到 2 个）/ 既定 `_` 前缀范式（决定 6）/ DEC-002 决定 5 Superseded（决定 8）/ bugfix.md 规则 2 对称修（决定 9）/ 新 DEC 影响范围 ≤10 行纪律（决定 10）
  6. **SSOT 维护性损失的 mitigation**：4 重复模式（Resource Access / Escalation JSON / Progress emit / Monitor setup）未来改动仍需改多处，但：(a) 变动频率低（近半年只有 DEC-007 / DEC-008 触及）；(b) `lint_cmd` 可扩展扫描检测模式漂移；(c) decision-log 本身就是"权威规则"单点，多处落地只是 copy
- **备选**:
  - **方向 A 保 helper + 激进双端精简**：helper 447→200 + agent 更薄；tree 省 ~400，workflow 负载省 ~350。保留 SSOT 但收益只有 B 的一半；拒绝
  - **方向 C 只维护性修正不瘦身**：接受 +83 行结果，重启 issue #9 讨论；user 明确拒绝
  - **Full Supersede DEC-009**：决定 2/3/4/5/8/9/10 都是真收益无须撤；成本大无必要；拒绝
  - **部分保留 helper**（保 _escalation + _progress-reporting 删 _resource-access + _progress-monitor-setup）：分纳标准难定；拒绝
- **理由**: (1) 用户 north star 是 token 成本，不是 SSOT；方向 B 直接命中；(2) 4 个重复模式本质稳定（JSON schema / emit 格式 / RA matrix）漂移风险不高；(3) 沿用 decision-log Superseded 正流程不删旧条目；(4) 决定 2/3/4/5/8/9/10 独立成立可保留；(5) critical_modules 条款微调（helper 清单从 4 个减到 2 个）为少数顺势改动
- **相关文档**: docs/design-docs/lightweight-review.md（§9 新增反思 + §10 DEC-010 转折），docs/exec-plans/completed/lightweight-review-plan.md（P0.1-P0.7 归档保留）+ 新建 `docs/exec-plans/active/lightweight-review-revert-plan.md`（P1.1-P1.3 revert 路线），DEC-009（被部分 supersede 的上游），issue #9
- **影响范围**: 删 4 helper 文件；重写 5 agent + 2 skill + 2 command + workflow.md 的相关 section inline；CLAUDE.md critical_modules 第 1 条 `_*.md helper` 清单调整（4 个→ 保留 2 个原有）；docs/claude-md-template.md 同步；docs/INDEX.md helper 清单从 6 → 2；docs/log.md / decision-log.md 新条目；不改 DEC-001 / DEC-002 / DEC-003 / DEC-004 event schema / DEC-005 / DEC-006 / DEC-007 / DEC-008。运行时：每次 workflow token 负载 ~39% 下降；tree 总行数 ~32% 下降

---

### DEC-008 workflow Step 3.5 前台派发免 Monitor（修正 DEC-004 触发规则 assumption）
- **日期**: 2026-04-19
- **状态**: Accepted
- **上下文**: issue #15 —— DEC-007 (#14) 会话中发现 DEC-004 §3.6 触发规则 "所有 subagent dispatch 默认开启" 隐含未言明 assumption：所有 Task 派发都是后台派发。dogfood 实录证明：前台 Task（默认 `run_in_background` 缺省 / `false`）主会话阻塞等结果且**子 agent 的 Bash/Read/Edit/Write 工具调用以缩进形式实时显示**在主会话输出里，主会话已天然观察到内部进度；只有后台 Task（`run_in_background: true`）主会话不阻塞且完全看不到 subagent 内部，Monitor 才是唯一进度通道。Step 3.5 当前无差别要求所有派发启 Monitor，对前台派发等于主会话同时收两份信号（Monitor 通知 + 缩进工具流），纯开销且潜在分散注意力
- **决定**:
  1. **触发条件收紧**：Step 3.5（progress monitor 启动 + 4 变量注入）从"所有 Task 派发"收紧为"`run_in_background: true` 的 Task 派发"；前台派发完全 skip 整段
  2. **gate 位置**：`commands/workflow.md` Step 3.5 顶部新增 §3.5.0 "Foreground vs background gate"，先于现有 §3.5.1 env opt-out（gate 失败即 skip 后续所有子步骤；与 env opt-out 同语义层）
  3. **bugfix 同步**：`commands/bugfix.md` §Step 0.5 加一句 gate 说明（template 引用 workflow.md，无需复制完整模板）
  4. **不改 5 份 agent prompt 本体**：5 个 subagent 的 §Progress Reporting Fallback 条款（"空 progress_path 静默 skip"）由 DEC-004 落地时已就位，天然兼容本变更
  5. **DEC-004 标 Superseded by DEC-008**（仅 §3.6 触发规则维度；其余条款仍 Accepted）；保留原文不删，对齐 decision-log 铁律
  6. **与 DEC-007 正交**：DEC-007 修源端 summary 内容质量（agent prompt §Content Policy）+ orchestrator awk 折叠；DEC-008 修触发条件（commands 层）。两个补丁不重叠、不互依、可分别合并；从两个层次（content vs gate）补 DEC-004 的不同 assumption 漏洞
  7. **与 DEC-005 同源**：DEC-005 §6b.3 已声明 inline developer 不跑 Step 3.5（"主会话直接观察"），DEC-008 把这条 inline-only 逻辑推广到所有"主会话可观察"的派发 — inline developer 是真子集，前台 Task 是另一子集
- **备选**:
  - **保留无差别开启 Monitor**：DEC-004 原状；前台派发的双份信号开销持续，违背"用户掌控感"north-star 的"信号不冗余"细则
  - **新增 env var `ROUNDTABLE_PROGRESS_FOREGROUND_DISABLE`**：与现有 `ROUNDTABLE_PROGRESS_DISABLE` 语义重复且解释成本翻倍；前台/后台是 dispatch 形态属性而非用户偏好，不该走 env
  - **改 5 份 agent prompt 加形态自检**：agent 不知派发形态（subagent prompt 不感知 parent 调用参数），无法在源端 gate；orchestrator 层 gate 是唯一可执行点
  - **Patch DEC-004 §3.6 in place（不开新 DEC）**：违反 decision-log 铁律 "不删除旧条目 / 编号递增"；触发规则变更属于实质性 supersede 范畴
  - **新增 done event type 区分形态**：与本 DEC 目标无关；DEC-007 已确立 "不扩 DEC-004 event 枚举" 纪律
- **理由**: (1) gate 在 orchestrator 层是唯一可执行点（agent 不感知 parent 派发参数）；(2) skip 前台派发完全消除双份信号开销且不损失任何观测能力（缩进工具流已经透传）；(3) 不改 agent prompt 本体减少 critical_modules（5 份 agent prompt）改动面，复用 DEC-004 已就位的 fallback 条款；(4) 与 DEC-005 inline developer 的 skip 逻辑同源，心智一致；(5) 与 DEC-007 正交可分别合并，降低集成风险；(6) 走 Superseded 流程而非 in-place patch 保持 decision-log append-only 纪律
- **相关文档**: docs/design-docs/subagent-progress-and-execution-model.md §3.8（patch 章节）+ §6 变更记录条目、DEC-004（被本 DEC 部分 supersede 的上游协议）、DEC-007（同期 DEC-004 follow-up，正交合并）、DEC-005（inline developer 同源 skip 逻辑）
- **影响范围**: `commands/workflow.md` §Step 3.5 新增 §3.5.0 gate；`commands/bugfix.md` §Step 0.5 加 gate 说明；`docs/design-docs/subagent-progress-and-execution-model.md` 新增 §3.8 + frontmatter `decisions` 加 DEC-008 + 变更记录条目；`docs/decision-log.md` 本条 + DEC-004 状态行追加 "（§3.6 触发规则 Superseded by DEC-008）"；`docs/log.md` 新增合并条目。**不改** 5 份 agent prompt 本体；**不改** DEC-004 event schema；**不改** Monitor 工具；**不改** target CLAUDE.md

---

### DEC-007 subagent progress content policy（#7 dogfood 刷屏 follow-up）
- **日期**: 2026-04-19
- **状态**: Accepted
- **上下文**: issue #14 —— DEC-004 落地后 2026-04-19 roundtable 自消耗 dogfood 观察到 developer agent 在同一 phase 内持续 emit 相同 summary（"dev round2 progress" x5+），Monitor 每行触发通知导致主会话刷屏。根因：DEC-004 只规定 event schema / phase 颗粒度，未规定 summary 内容质量。Monitor 本身事件驱动无去重；源端 4 个 subagent prompt（developer / tester / reviewer / dba）的 Progress Reporting section 缺失节拍 / 去重 / 差异化内容 / 终止-失败语义分离的约束
- **决定**:
  1. **共享 policy helper**：新建 `skills/_progress-content-policy.md`（下划线前缀 = plugin 内部 include-only 文件，非独立可激活 skill，对齐 `skills/_detect-project-context.md` 范式）；4 个 subagent 的 Progress Reporting section 加 `### Content Policy` 子节，一行引用 + 本角色特化示例
  2. **代理节拍（substantive-progress gate）**：两次 emit 之间 agent 必须完成以下之一——(a) 一次实质文件写/编辑、(b) 一个已完成子里程碑、(c) ≥50% 新 token context。替代不可执行的"最小 30s 间隔"
  3. **连续 summary 去重**：相邻两次 emit 的 `summary` 字段禁止完全相同；若无新信息宁可不发
  4. **差异化内容**：每条 emit summary 必含以下至少一项——具体子步骤名 / 进度分数（`2/5`）/ 里程碑标签
  5. **终止-失败信号复用**：DONE = 本 dispatch 最后一次 `phase_complete`（建议 summary 前缀 `✅`）；ERROR = `phase_blocked` + `<escalation>`（沿用 DEC-002）。**不扩 DEC-004 event 枚举**，orchestrator 凭 Task 返回即判定 dispatch 结束
  6. **orchestrator 端兼底 dedup**：`commands/workflow.md` Step 3.5.3 jq pipeline 追加 awk 的连续相同行折叠（`... x3`），非全局 uniq—仅在 agent 源端失守时提供保护
- **备选**:
  - **内联 4 份拷贝到各 agent**：否决，critical_modules 命中 prompt 本体，4 份拷贝未来改一条规则需改 4 处，漂移风险放大
  - **追加 DEC-004 §3.8**：否决，DEC 记决策不记规范；policy 是操作性规则，放 DEC 违背 DEC-001 定位边界
  - **新增 done / error event type**：否决，DEC-004 event 枚举 3 种正为稳定性设；扩枚举需改 Accepted DEC 走 Superseded 流程，成本高；Task 返回+phase_blocked 组合已充分覆盖语义
  - **硬编码 event 计数上限（max 10/dispatch）**：否决，长任务 exec-plan 多阶段可能自然超限，硬上限反而压制有效信号
  - **仅源端规范不加 Monitor 兼底**：否决，agent prompt 漂移不可避免，一层 awk collapse 代价低收益高
  - **jq stateful foreach dedup**：否决，jq 内 stateful filter 调试冗长，已有 DEC-004 jq `fromjson?` 容错一次踩坑（见 testing/subagent-progress-and-execution-model.md case 1.2b），不再加复杂度
  - **awk 全局 uniq（`!seen[$0]++`）**：否决，非连续重复（相同 case 被其他事件打断后再现）通常有效，不应过滤
- **理由**: (1) 共享 helper 对齐 `_detect-project-context.md` 范式，critical_modules 单源；(2) 代理门阁替时间间隔让 LLM 可自查，确定性条件；(3) 复用 DEC-004 event 枚举避免 Superseded 连锁；(4) 源端规范 + 一层 awk 兼底双保险，匹配 roundtable "显式决策点 + 纪律性兜底" 心智
- **相关文档**: docs/design-docs/progress-content-policy.md（主设计文档）、docs/exec-plans/active/progress-content-policy-plan.md（执行计划）、DEC-004（被补丁的上游事件协议）、DEC-002（Escalation 协议，ERROR 信号复用）、DEC-005（developer 双形态，inline 仍不 emit）
- **影响范围**: 新建 `skills/_progress-content-policy.md`；编辑 `agents/developer.md` / `agents/tester.md` / `agents/reviewer.md` / `agents/dba.md` 的 Progress Reporting section（追加 Content Policy 子节）；编辑 `commands/workflow.md` Step 3.5.3（jq pipeline 加 awk collapse）；新增 DEC-007 本条；`docs/log.md` 新增一条 `design | progress-content-policy` + `decide | DEC-007` + `plan | progress-content-policy` 合并条目；`docs/INDEX.md` 追加 design-docs / exec-plans 引用。**不改** DEC-004 event schema；**不改** Monitor 工具；**不改** target CLAUDE.md

---

### DEC-006 workflow phase gating taxonomy（producer-pause / approval-gate / verification-chain 三段式）
- **日期**: 2026-04-19
- **状态**: Accepted
- **上下文**: issue #10 —— P4 自消耗后重跑观察到 `commands/workflow.md` 现行 Step 6 规则 1 "每次 cross-role transition 停下 confirmation" 产生选项疲劳、产出文档未读完即决策、FAQ 空间被弹窗切断；与 `feedback_no_auto_push` / `feedback_no_auto_pr` 的"不可逆动作等用户主动"心智不一致；对标 CrewAI / AutoGen / LangGraph 等 AI agent 框架主流"默认自动 + 显式 gate 声明"反向
- **决定**:
  1. **显式三段式分类**：每个 phase transition 归入 A producer-pause / B approval-gate / C verification-chain 之一；gating 行为由类别决定
     - A producer-pause：phase 产出 user-consumable artifact，orchestrator 停下等用户文本输入（`go` / `问:` / `调:` / `停`），不调用任何工具
     - B approval-gate：硬方向性锁定，MUST `AskUserQuestion`，按 `feedback_askuserquestion_options` Option Schema
     - C verification-chain：机器/AI 内部纪律衔接，orchestrator 自动前进，1 行 handoff 通知；Critical finding / escalation / lint+test 失败仍中断
  2. **分类映射**：analyst / architect Draft / Stage 9 Closeout → A；design-confirm → B（唯一硬 gate）；context-detect / developer / tester / reviewer / dba 以及之间的 handoff → C
  3. **新增 Stage 9 Closeout**：reviewer/dba 完成后汇总 findings 等用户决定 commit/PR/amend，保持与 `feedback_no_auto_push` / `feedback_no_auto_pr` 同构
  4. **critical_modules 机械触发归 C**：CLAUDE.md 事先声明即运行期授权，handoff 1 行通知 `(critical_modules hit: [...])` 即透明
  5. **reviewer 完成归 C**：reviewer 是 verification，不是 producer（产出 artifact 仅 Critical 时落盘）；用户"是否 commit"决策放到 Stage 9 Closeout 一次停
  6. **design-confirm 保 AskUserQuestion 弹窗**：directional lock + Accept/Modify/Reject 结构化选项天然 option 化，对标 terraform apply / apt install
- **备选**:
  - 合入 DEC-001 D5：D5 现为 Scope=user，与 gating 无关；合入会模糊 D5 语义
  - 合入 DEC-002 Escalation Protocol：DEC-002 是 subagent → orchestrator 的 escalation，本 DEC 是 orchestrator → user 的 gating，主体不同
  - 仅扩展现行 Step 6 规则 1 的 Exception 条款：条款嵌套变深、阅读性差、与 AI agent 框架主流反向（评分 29 vs 三段式 40）
  - 完全翻转默认为全自动 + 只保留 design-confirm：失去 producer-pause 的 FAQ/调范围自然 pause 点，与 issue #10 原意不完全一致
- **理由**: (1) 显式三段式与 AI agent 框架主流心智对齐，用户心智一致性最高；(2) producer-pause 的"自由文本驱动 go/问/调/停"复用现有对话机制，零新 UI；(3) B 类只在真正 directional lock 处保留弹窗，避免选项疲劳；(4) C 类自动前进 + Critical 中断 + handoff 通知三件套保证"自动不静默"；(5) Stage 9 Closeout 与 feedback_no_auto_push/pr 同构，复用已有用户心智；(6) 新增 DEC 而非 Supersede 任何既有 DEC，append-only 纪律得以保持；(7) 不改 AskUserQuestion Option Schema、不改 Phase Matrix 状态机、不改 subagent 执行模型，变更面最小
- **相关文档**: docs/design-docs/phase-transition-rhythm.md（完整设计）、docs/analyze/phase-transition-rhythm.md（对标研究 + 6 事实层开放问题 + Path A/B/C/D 对比）、issue #10
- **影响范围**: `commands/workflow.md` §Step 6 规则 1 重写 + Phase Matrix 新增 Stage 9；`CLAUDE.md` §critical_modules 条目 6 描述扩展；`docs/claude-md-template.md` 同步；可选 README.md 一句话提及。不影响 `commands/bugfix.md`、`agents/*`、`skills/*`、DEC-001 ~ DEC-005

---

### DEC-005 developer 双形态（inline | subagent）正交补强 DEC-001 D8
- **日期**: 2026-04-19
- **状态**: Accepted
- **上下文**: issue #7 问题 B —— P4 dogfood 实录证实 developer 在小任务（单文件改 / bug 热修）场景下用 subagent 形态让用户失去掌控感；但 tester/reviewer/dba 的大 context 对抗/审查任务 inline 执行会爆主会话。DEC-001 D8 "role→form 单射" 在 developer 这一行产生张力
- **决定**:
  1. **developer 支持双形态**：`inline`（主会话内联执行 `agents/developer.md`，AskUserQuestion 直接可用）和 `subagent`（DEC-001 D8 原默认，Task 派发 + Escalation）
  2. **默认仍 subagent**：保持 D8 原映射为默认；inline 是非默认可选档
  3. **tester / reviewer / dba 不扩展**：仍仅 subagent（大 context 无例外）
  4. **切换触发三级**：
     - per-session：用户 prompt 里声明 `@roundtable:developer inline`
     - per-project：target CLAUDE.md `# 多角色工作流配置` 可选 `developer_form_default: inline`
     - per-dispatch：`/roundtable:workflow` 在 developer 阶段前 AskUserQuestion，小任务标志触发 inline=recommended
  5. **正交补强 DEC-001 D8**（不 Superseded D8）—— D8 的 role→form 基础映射继续有效；本 DEC 新增规则："developer 角色除 subagent 外另支持 inline；其他三角色 D8 边界不变"。与 DEC-003 对 D8 的处理模式一致
  6. **能力差异表**：在 design-doc §3.4.3 明示 AskUserQuestion / Escalation / 并行派发 / context 污染等维度在双形态下的行为差异
  7. **Resource Access 保持不变**：无论 inline / subagent，developer 读写范围（src/* + tests/* + exec-plan checkbox 报告）完全一致；仅交互通道不同
- **备选**:
  - **全四角色双形态**（developer/tester/reviewer/dba 都支持 inline）：维护成本 4×；reviewer / tester inline 实测易撑爆主会话（80k+ /dispatch），拒绝
  - **auto 档**（按任务规模自动选）：触发规则解释成本高；analyst §失败模式证实 6 个月后易成摆设，拒绝
  - **Supersede DEC-001 D8**（全量重写角色形态分配）：改动远大于实际语义变化（tester/reviewer/dba 三行并无实质变化）；与 DEC-003 "保留 D8" 的和谐模式不一致，拒绝
  - **Partial Supersede D8**（仅 developer 那一行状态改 "Partially Superseded by DEC-005"）：需引入"Partially Superseded"状态机，decision-log 铁律复杂化，拒绝
- **理由**: (1) developer 是 P4 实录里 dispatch 次数最多的角色（4/9 次），小任务场景最频繁，UX 收益最高；(2) 保持 tester/reviewer/dba subagent 纪律规避 1M context 风险；(3) 正交补强而非 Supersede 保证 D8 原文不改、decision-log 单调递增；(4) 三级切换触发覆盖 per-session/project/dispatch 的决策层次；(5) 能力差异表让用户在 AskUserQuestion 弹窗里能理解 inline/subagent 的实际代价
- **相关文档**: docs/design-docs/subagent-progress-and-execution-model.md（D2 双形态设计 + §3.4）、本条 + DEC-001 D8 共同定义 developer 形态语义、DEC-004（协同的 progress protocol，subagent 档才启用）
- **影响范围**: `agents/developer.md`（新增 §Execution Form 双形态声明）；`commands/workflow.md`（Step 6 增加 developer 形态切换判定 + inline 执行路径）；`commands/bugfix.md`（同上，bugfix 流程也要识别 inline）；`docs/claude-md-template.md`（§多角色工作流配置 增加可选 `developer_form_default` 示例）；`docs/decision-log.md` 本条；`docs/log.md` 新增 `decide | DEC-005` 条目。运行时行为：小任务 / bug 热修用户可一键切 inline 全程可见；默认行为零变化

### DEC-004 subagent progress event protocol（P1 push 模型）
- **日期**: 2026-04-19
- **状态**: Accepted（决定第 6 项「触发规则」Superseded by DEC-008 — 改为 `run_in_background: true` 派发才开启；其余条款仍 Accepted）
- **上下文**: issue #7 问题 A —— P4 dogfood 实录证实 subagent 长任务（3-10+ 分钟）期间主会话无反馈，用户失去对流程的掌控感。Claude Code 原生 `/agents` Running tab、transcript JSONL、Ctrl+B 提供**用户侧**观察通道，但 orchestrator LLM 对 subagent 内部**系统性**不可见（官方 "intermediate tool calls … only its final message returns to the parent"）
- **决定**:
  1. **push 模型**（非 pull）：subagent 在 phase 边界主动 append JSON event 到共享文件；orchestrator `Monitor` tail。对比 pull 模型（周期 Read transcript）的关键收益：事件驱动（无空 poll）、官方架构对齐（Claude Code Agent 工具 description 明确建议"do NOT poll"）、与 DEC-002 Escalation JSON 同一范式
  2. **事件颗粒度**：phase checkpoint 级（exec-plan P0.n 维度），3 种 event 类型 `phase_start` / `phase_complete` / `phase_blocked`；一次 dispatch 预期 3-10 条 event
  3. **JSON schema**：单行 JSONL，必选字段 `ts` / `role` / `dispatch_id` / `slug` / `phase` / `event` / `summary`（≤120 char 一句话），可选 `detail`（files_changed / tests_passed 等）
  4. **发射机制**：subagent prompt 本体新增 `## Progress Reporting` section 约定 `Bash echo '{json}' >> {{progress_path}}`；不用 PostToolUse hook（plugin 跨平台分发脚本复杂 + 颗粒度不匹配）
  5. **监听机制**：orchestrator 在 Task 派发前 Bash 生成 `dispatch_id` + `progress_path = /tmp/roundtable-progress/{session_id}-{dispatch_id}.jsonl` + 启动 `Monitor "tail -F ${PATH} | jq --unbuffered -c ..."`；Task 完成后 Monitor 自然结束
  6. **触发规则**：所有 subagent dispatch 默认开启（不做 critical_modules 二级过滤）；用户可设 `ROUNDTABLE_PROGRESS_DISABLE=1` 关掉
  7. **协议层级**：plugin 元协议（与 DEC-002 Escalation 同层）；不入 target CLAUDE.md（保持 DEC-001 D2 "零 userConfig" 边界）
  8. **与 DEC-002 / DEC-003 正交**：progress 用临时文件路径；escalation 用 Task final message；research-result 用 research agent final message。三通道独立、不相互触发
  9. **漏发降级**：subagent 漏 emit 时降级为"静默"（= 当前现状），不恶化
- **备选**:
  - **P6 orchestrator pull**（零改 subagent，周期 Read transcript）：违反官方"do NOT poll"倾向；5 分钟 cache TTL 让周期 ≥5 分钟时每轮 cache miss；token 成本倍增；拒绝
  - **P3 banner only**（启动时 echo 观察通道提示，不 relay）：用户需手动切 `/agents` 视图，不满足 "实时感知流程位置" 的 user north-star；拒绝
  - **P4 heartbeat text tag**（subagent prompt 约定打 `<heartbeat>` tag）：LLM 生成文本 tag 颗粒度不稳定（易漏打、格式漂移）；结构化 JSON 更可靠；拒绝
  - **P5 独立 reporter agent**：引入新 agent 形态与 DEC-003 research 角色形态重复；2× subagent 并行开销；拒绝
  - **每工具调用颗粒度**：单 dispatch 20-50 event 密度过高；主会话 notification 风暴；拒绝
  - **CLAUDE.md 声明 schema**：违反 DEC-001 D2 "CLAUDE.md 只放业务规则" 边界；plugin 元协议与业务规则混杂；拒绝
  - **PostToolUse hook 自动 emit**：hook 脚本 plugin 跨平台分发复杂（shebang / 权限位）；hook 每 tool call 触发颗粒度不对；拒绝
- **理由**: (1) 事件驱动 push 比 pull 高效且对齐官方架构；(2) phase checkpoint 颗粒度与 DEC-002 exec-plan P0.n 结构天然对齐；(3) plugin 元协议定位让用户 CLAUDE.md 零改动；(4) JSON schema 结构化与 DEC-002 Escalation 范式一致；(5) 漏发降级兜底保证不变更糟；(6) `/tmp` 临时文件路径简化生命周期管理（不用 gc）
- **相关文档**: docs/design-docs/subagent-progress-and-execution-model.md（设计主文档 §3.1-3.7）、DEC-005（developer 双形态；inline 档不 emit progress，只 subagent 档 emit）、DEC-002（Escalation 同层协议）
- **影响范围**: `agents/developer.md` / `agents/tester.md` / `agents/reviewer.md` / `agents/dba.md` / `agents/research.md` 均新增 `## Progress Reporting` section；`commands/workflow.md` / `commands/bugfix.md` 新增 Task 派发前的 Monitor 启动模板；`docs/design-docs/subagent-progress-and-execution-model.md`（新建）；`docs/exec-plans/active/subagent-progress-and-execution-model-plan.md`（新建）；`docs/decision-log.md` 本条；`docs/INDEX.md` 新增 design-docs / exec-plans 引用；`docs/log.md` 新增 `design | subagent-progress-and-execution-model` + `decide | DEC-004` 条目。运行时行为：所有 subagent dispatch 自动带 progress 可见性；用户可 env var 关掉

---

### DEC-003 architect skill → parallel research subagent dispatch 能力
- **日期**: 2026-04-19
- **状态**: Accepted
- **上下文**: P4 自消耗（gleanforge dogfood，2026-04-18）§3 friction #8 —— architect 决策 3+ 备选方案时 `WebFetch` 串行，慢 + 主会话 context 被累积 fetch 撑爆 + 或被迫 truncate 研究广度。DEC-002 将此列为 deferred，留 [issue #2](https://github.com/duktig666/roundtable/issues/2) 追踪。本轮（2026-04-19）完成调研（`docs/analyze/parallel-research.md` 对标 CrewAI / LangGraph / Claude Code sub-agents）+ architect 决策 7 条。
- **决定**:
  1. **新增 `agents/research.md`**（独立 role）—— 短生命周期 research worker，architect dispatches via `Task`，**不由用户触发**（description 明写 "NOT user-triggered")
  2. **正交补充 DEC-001 D8**（不 Superseded D8）—— D8 的 role→form 单射继续有效；DEC-003 新增规则："skill（限 architect）可向特定 agent（限 research）派 `Task`，仅限短生命周期 fact-level 调研"
  3. **Tool set**：`Read`, `Grep`, `Glob`, `WebFetch`, `WebSearch`（**禁** `Bash` / `Write` / `Edit` / git / `AskUserQuestion`）
  4. **扇出硬上限**：每次 architect 决策 ≤ 4 个并行 research subagent；5+ 候选先用 `AskUserQuestion` 粗筛
  5. **返回 schema**：结构化 `<research-result>` JSON block，字段 `option_label` / `scope` / `key_facts[{fact, source}]` / `tradeoffs[]` / `unknowns[]` / `recommend_for: null` —— `recommend_for` 硬导 `null`，执行"research 不做推荐"纪律
  6. **Scope 模糊处理**：`<research-abort>` feedback，architect 修正 scope 重派最多 1 轮；不新增 escalation type，避免 reentrant（research → orchestrator → architect skill 是 orchestrator 的 skill）
  7. **1/N 失败处理**：partial success 可接受；失败 option 在 architect 合成后的 `AskUserQuestion` 里标 ☠️，用户可选排除或接受不完整信息拍板
- **备选**:
  - **analyst dual-mode（skill + subagent）**：破坏 D8 的 role→form 单射；一个 role 文件两套 Resource Access 难维护；auto-delegation description 歧义
  - **架构师 inline Task 模板（零新文件）**：每次派发 architect 要重述 tool set + schema；prompt 模板复制易漂移；无独立 role 审计
  - **新增 `scope-clarification` escalation type**：增加路由复杂度；scope 决策本属 architect，不应经用户；与 abort-re-dispatch 比无实质收益
  - **Strict all-or-nothing 失败处理**：token 浪费 4×（全重派）；上游持续故障（如某源 persistent down）导致雪球阻塞
  - **扇出上限 ≤ 6 或无上限**：5+ 候选往往是决策粒度过粗的信号；与 `AskUserQuestion` 的 `maxItems: 4` 不对齐
  - **返回 prose 而非 JSON**：N 份 prose 合成需 architect 文本解析，易丢事实；与 DEC-002 已确立的 `<escalation>` JSON 范式不一致
- **理由**: (1) 独立 agent 保持 D8 的 role→form 单射；(2) 结构化 JSON schema 让 N 份调研合成可确定性映射到 AskUserQuestion 字段（复用 DEC-002 的 agent→orchestrator JSON 交互范式）；(3) 扇出 ≤ 4 与 AskUserQuestion maxItems 对齐，逼迫 architect 先粗筛而非粗放扇出；(4) partial success 务实 —— 用户最终拍板能力 > 完整性要求；(5) abort 而非 escalation 避免 "research → orchestrator → architect skill" 的 reentrant；(6) `recommend_for: null` 硬导执行 "research 事实层、architect 决策层" 的纪律分离
- **相关文档**: [docs/analyze/parallel-research.md](analyze/parallel-research.md)（对标调研 + 12 事实层开放问题）、[docs/design-docs/parallel-research.md](design-docs/parallel-research.md)（完整设计含流程 / schema / 并行安全论证）、`skills/architect.md` §阶段 1.5 "Research Fan-out"（触发 / 派发 / 合成 / 失败处理规则）、`agents/research.md`（新 role 完整定义 + Return Schema + Abort Criteria）、[issue #2](https://github.com/duktig666/roundtable/issues/2)
- **影响范围**: 新增 `agents/research.md` 文件；`skills/architect.md` §阶段 1 加入 3.5 子步骤；`docs/decision-log.md` 本条目；`docs/INDEX.md` 新增 `### agents` subsection + 引用 research.md；`docs/log.md` 新增 `design | parallel-research` 条目。运行时行为变化：architect 在决策候选 ≥ 2 且需外部研究时可选择并行 research，显著减少主会话 token 占用和决策时间。与 DEC-001 D8 正交；与 DEC-002 共享 JSON 交互范式（`<escalation>` ↔ `<research-result>` / `<research-abort>`）无冲突。

---

### DEC-002 基于 P4 自消耗反馈的三项增量改进（shared resource protocol / escalation / workflow matrix）
- **日期**: 2026-04-19
- **状态**: Accepted（决定 5 "prompt 文件本体统一英文" Superseded by DEC-009 决定 8 —— 2026-04-19 通过 `feedback_roundtable_prompt_language` 反转为"中文为主"，CLAUDE.md 已同步；其余决定仍 Accepted）
- **上下文**: P4 自消耗闭环在 gleanforge 项目完成（见 `docs/testing/p4-self-consumption.md`），识别出三类主要摩擦 —— (a) 共享资源协议隐式（exec-plan checkbox / log.md / decision-log / testing 写权限靠 orchestrator 逐次 prompt 注入，并行派发时易 race）；(b) subagent 通信封闭性（tester / developer 遇到用户决策点只能文字建议，orchestrator 手动 relay 成 AskUserQuestion）；(c) workflow command 缺少阶段可视化（orchestrator 状态靠对话追踪，用户难以判断当前位置）。同时副带两个已知 plugin 层 bug：prompt 文件中英混杂（违反自家「跨阶段约束：prompt 英文为主」）、AskUserQuestion 弹窗给裸选项（用户难决策）
- **决定**:
  1. **每个 role 文件加 Resource Access 矩阵**（`Read` / `Write` / `Report to orchestrator` / `Forbidden`）—— 权限声明从隐式 prompt 注入升级为 role prompt 本体的一等公民 section，对 7 个 role 文件生效（3 skills + 4 agents）
  2. **agent 层加 Escalation Protocol + skill 层加 AskUserQuestion Option Schema**：
     - agents (developer / tester / reviewer / dba) 在最终报告追加结构化 `<escalation>` JSON 块（`type` / `question` / `context` / `options[label, rationale, tradeoff, recommended]` / `remaining_work`），orchestrator 自动解析并转 `AskUserQuestion` 再派发
     - skills (architect / analyst) 强制 `AskUserQuestion` 每个 option 必含 `label` / `rationale` / `tradeoff` / `recommended`（analyst 禁 `recommended`，保持事实层；architect 最多 1 个标 `recommended`）
  3. **commands/workflow.md 重写为阶段矩阵编排器**：
     - 引入 Phase Matrix（8 阶段 × `⏳ / 🔄 / ✅ / ⏩` 状态 × artifacts 列），每次阶段转场向用户汇报并更新
     - 新增 Step 4 并行派发判定树（4 条硬条件：PREREQ MET / PATH DISJOINT / SUCCESS-SIGNAL INDEPENDENT / RESOURCE SAFE；默认串行，满足四条且加速 >30% 才并行）
     - exec-plan checkbox 写入由 orchestrator **串行化**（即使并行派发 developer，orchestrator 代写 checkbox 避免 race）
     - 跨角色转场（developer → tester 等）必须用户确认；同角色顺承（P0.4 → P0.5）在无 Critical 发现时可自动推进
  4. **`_detect-project-context` 切换为"Read 内联执行"**：不再用 `Skill` 工具激活（下划线前缀 skill 在部分 Claude Code 版本激活失败），改为调用方 `Read` 该 markdown 文件后按 4 步内联执行；5 个调用方（workflow / bugfix / lint / architect / analyst）同步改
  5. **prompt 文件本体统一英文**：workflow.md / bugfix.md / lint.md 中英混杂的步骤描述改为英文，保留关键 domain 注释中文
  6. **版本号不 bump**：本轮累计为 alpha 迭代改进，`plugin.json` / `marketplace.json` 保持 `0.1.0-alpha.1`；CHANGELOG 走 `[Unreleased]` section
- **备选**:
  - **推翻双形态架构**（全 agent 或全 skill）：解决 subagent AskUserQuestion 禁用，但失去 architect 交互体验或污染主会话 context —— 见 DEC-001 已拒绝
  - **依赖 Claude Code 未来原生支持 Task 工具进度事件**：等待期内 P4 摩擦持续；本轮先做可控的增量
  - **每条改动各自独立 DEC（DEC-002/003/004/005）**：粒度过细，单轮改动语义 coherent，一条 DEC 足够
  - **仅改文档不改 prompt**：prompt 约束是 plugin 运行时行为的唯一载体，仅改文档不解决 race / relay 摩擦
  - **bump version 到 0.2.0-alpha.1**：本轮只增补结构化约束，无破坏性变更，不到 minor bump 门槛
- **理由**: (1) 报告已证实三条 top 都是增量演进，不推翻架构；(2) Resource Access 权限矩阵变隐式为显式，消除 per-dispatch prompt 负担；(3) Escalation + Option Schema 让"subagent 封闭 + AskUserQuestion 裸选项"两类摩擦在同一协议层解决；(4) Phase Matrix 让 orchestrator 状态对用户透明，配合并行判定树给出可证伪的加速决策；(5) inline _detect 是对 "Skill 激活失败" 的稳健规避，配合 session 记忆复用语义不变；(6) 不 bump 版本避免误导使用者以为 minor 行为变更
- **相关文档**: docs/testing/p4-self-consumption.md（详细观察报告）、docs/design-docs/roundtable.md（原设计），本次改动具体落点见 feature branch 的 commit 1 / 2 / 3（git log 查）
- **影响范围**: 所有 skill / agent / command prompt 文件（7 + 3 = 10 个），decision-log 本条目；运行时行为变化表现在并行策略更明确、escalation 不再 relay、phase 可视化、_detect 激活方式改变；现有测试 / 用户接入流程无破坏

---

### DEC-001 多角色 AI 工作流打包为 Claude Code plugin（roundtable）
- **日期**: 2026-04-17
- **状态**: Accepted
- **上下文**: 用 Claude Code 做中大型项目开发时，单一对话容易失控；已有的单 agent 模式不足以支撑纪律化流程。需要一套"多角色协同 + plan-then-execute + 交互式决策"的通用工作流，能适配不同技术栈的项目，业务规则由各项目自描述
- **决定**:
  1. **分发机制**：打包为 Claude Code plugin，仓库 `github.com/duktig666/roundtable`，Apache-2.0 许可；用户通过 `/plugin marketplace add duktig666/roundtable` + `/plugin install roundtable@roundtable --scope user` 一行命令全局安装
  2. **角色形态混合**（D8）：architect / analyst 为 **skill**（主会话运行，保留 AskUserQuestion 决策弹窗）；developer / tester / reviewer / dba 为 **agent**（subagent 隔离上下文避免主会话污染）；命令保持 command
  3. **配置模型 B-0 零 userConfig**（D2）：plugin.json **不含 userConfig 字段**，安装零弹窗；所有配置走两条通道 —— (a) 运行时自动检测（扫 target_project 根的 Cargo.toml / package.json 等识别 primary_lang / lint_cmd / test_cmd；扫 `docs/` 或 `documentation/` 识别 docs_root）；(b) 每个项目的 CLAUDE.md「# 多角色工作流配置」section 声明业务规则（critical_modules / 设计参考 / 触发规则 / 工具链覆盖）。CLAUDE.md 声明值覆盖自动检测
  4. **Scope = user**（D5）：plugin 装在 `~/.claude/plugins/`，一次装所有项目通用；不依赖 project scope 的 `.claude/settings.json`
  5. **目标项目识别（D9）**：适配"从 workspace 根目录启动 Claude Code"场景。Skill / Agent 启动时按优先级识别 target_project —— session 记忆 → `git rev-parse --show-toplevel` → 任务描述正则匹配 CWD 下含 `.git/` 的一级子目录 → AskUserQuestion 弹窗兜底。识别结果 session 内记忆，用户可显式切换
  6. **实施策略（D6）**：POC 增量 —— P1 先通用化 architect skill + /workflow command + D9 识别机制，P2 批量改剩余角色，P4 真实项目自消耗验证
  7. **文档归属（D1）**：roundtable/docs/design-docs/roundtable.md 为唯一权威设计文档
- **备选**:
  - 全 agent 形态（一致性好，但 AskUserQuestion 在 subagent 系统级禁用，失去 architect 核心交互体验）
  - 全 skill 形态（AskUserQuestion 可用，但 developer / tester 读写大量代码会撑爆主会话 context）
  - 多 userConfig 字段（如 docs_root / lint_cmd / test_cmd / primary_lang / critical_modules_hint / design_ref_hint）：多项目场景下单一值天然冲突；lint/test/lang 本可自动检测；hint 字段与 CLAUDE.md 重合。评估为过度设计
  - project scope 安装：workspace 根启动时根目录非 git，project scope 无落脚点
  - 强制从子项目启动 Claude Code：违背常见场景
  - plugin 内置 profile 系统（rust-backend / ts-frontend 等硬预设）：抽象过早，同语言不同项目 critical_modules 差异大
- **理由**: (1) 零 userConfig 是最优的"一行命令装上即用"体验；(2) CLAUDE.md 作为单一配置源，天然 per-project，git 版本控；(3) 运行时自动检测对工具链精准度够（读项目根文件比用户手填还准）；(4) D9 识别机制填补 workspace 根启动场景的空白；(5) skill / agent 混合在同一 plugin 无冲突（已核实官方文档）
- **相关文档**: docs/design-docs/roundtable.md（完整设计 + D1-D9 量化评分）、docs/exec-plans/active/roundtable-plan.md（P0-P6 实施路线）
- **影响范围**: 本项目全部 skill / agent / command 定义；项目 manifest（plugin.json）
