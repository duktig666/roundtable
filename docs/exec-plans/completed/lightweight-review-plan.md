---
slug: lightweight-review
source: design-docs/lightweight-review.md
created: 2026-04-19
status: Active
decisions: [DEC-009]
description: issue #9 轻量化重构执行计划（P0.1-P0.6，6 phase）
---

# 轻量化重构 执行计划

> 展开自 `design-docs/lightweight-review.md`（DEC-009 Proposed）

## 总览

| Phase | 标题 | 预估 | 前置 | 关键风险 |
|---|---|---|---|---|
| P0.1 | 4 shared helper 新建 | 2h | Design 确认 | helper 内容漏抽 → agent 抽取时无法 refer |
| P0.2 | 5 agent + 2 skill retrofit | 3h | P0.1 | role-specific ordering discipline 丢失回归 |
| P0.3 | workflow.md Step 3.5 抽取 + 新增 Step 8 log batching | 2h | P0.1 | batching flush 触发点实现漏；jq pipeline 改错 |
| P0.4 | README + CLAUDE.md + claude-md-template.md + log.md 重塑 | 1h | — | §设计原则 合并措辞偏离原 issue §D 5 点 |
| P0.5 | lint_cmd + 回归验证（自消耗 dogfood） | 1h | P0.1-P0.4 | helper 绝对路径被 grep 白名单误命中（罕见） |
| P0.7 | DEC 修正（DEC-002 决定 5 补记 Superseded + bugfix.md 规则 2 对称性 fix） | 0.5h | P0.4 | DEC-002 状态行措辞是否影响现有 DEC 消费者 |
| P0.6 | exec-plan 归档 + DEC-009 状态 Proposed → Accepted | 0.5h | P0.1-P0.5 + P0.7 + tester + reviewer 通过 | — |

## 跨阶段约束

- **helper 引用统一格式**：所有 retrofit 后的 agent/skill 用 `详见 skills/_xxx.md，本角色特化...` 模式；严格复用 `_detect-project-context.md` / `_progress-content-policy.md` 既定措辞
- **agent 本体保留的 role-specific 内容**（P0.2 不得删）：
  - developer: Execution Form 段（DEC-005 双形态）、Escalation typical triggers、Progress Reporting phase tag（P0.n 优先）
  - tester: Ordering discipline（bug-found 先 emit）、phase tag 列表（scope-review/writing-test-plan/writing-tests/adversarial-run/bug-found）、测试计划模板
  - reviewer: Critical-finding ordering、phase tag（discovering/analyzing/classifying/writing-review）、Critical/Warning/Suggestion 审查维度
  - dba: schema-read/migration-analysis/index-check/writing-review phase tag、典型 escalation 触发点
  - research: Abort Criteria（保留，与 Escalation 不对称）、Return Schema、不 emit progress 的说明
  - analyst / architect: 保留 AskUserQuestion Option Schema（本就 skill 层专属，不抽）
- **DEC-004 event schema / DEC-007 Content Policy 规则不变**：helper 只是位置重组
- **lint_cmd 约束**：`grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/` 保持 0 命中
- **log.md 批处理 pause-point flush** 必须在每个 A 类 producer-pause 转场前执行（workflow.md Step 8 明文）
- **critical_modules 扩写** CLAUDE.md + claude-md-template.md 同步，一轮改完

## P0.1 新建 4 shared helper

### 目标
抽取 DEC-002 / DEC-004 / DEC-007 在各 agent 的重复块为 4 个独立 `_*.md` 文件。

### 任务清单
- [ ] 新建 `skills/_resource-access.md`：frontmatter + 引言 + 通用表头 + 末尾 git 段 + role-specific rows 示例
- [ ] 新建 `skills/_escalation-protocol.md`：引言 + JSON schema body + 通用规则（2+ options / ≤1 recommended / 每派发最多 1 block）+ Escalation vs Abort 段
- [ ] 新建 `skills/_progress-reporting.md`：注入变量段 + 3 种 event emit 模板 + Granularity 段 + Content Policy ref + Fallback + 与 Escalation 正交段
- [ ] 新建 `commands/_progress-monitor-setup.md`：Bash 准备段 + Monitor jq pipeline（含 `-R fromjson?` 容错说明）+ 4 变量注入表 + 生命周期 + 并行安全性

### 成功信号
- 4 个新文件通过 `head -10` 全部带 `_` 前缀 frontmatter
- `lint_cmd` 0 命中
- 4 文件总行数 ~250（与 5 agent × ~60 抽取量对齐）

### 风险与预案
- helper 内容漏抽 → P0.2 retrofit 时发现缺块，按需补回 helper，不扩 agent 本体
- helper 格式漂移 → 参照 `_detect-project-context.md` 既有样板

## P0.2 retrofit 5 agent + 2 skill

### 目标
按 DEC-009 §2.1 表格把 `## Resource Access` / `## Escalation Protocol` / `## Progress Reporting` 改写为 ref + role-specific 残余；`## 完成后` 的 log.md append 模板删除。

### 任务清单
- [ ] `agents/developer.md`：3 段 retrofit + log.md append 段删（保留 exec-plan 移到 completed/ 的行为描述但不写模板）
- [ ] `agents/tester.md`：同上 + 保留 Ordering discipline
- [ ] `agents/reviewer.md`：同上 + 保留 Critical-finding ordering
- [ ] `agents/dba.md`：同上
- [ ] `agents/research.md`：Resource Access ref；研究专属 Abort Criteria 保留（不纳入 _escalation-protocol.md）；Progress Reporting 段删除（research 不 emit）
- [ ] `skills/analyst.md`：Resource Access ref；AskUserQuestion Option Schema 保留；log append 段删
- [ ] `skills/architect.md`：同上；Research Fan-out 段保留；log append 段删

### 成功信号
- 7 文件总行数对比 P0.1 前下降 ≥ 350 行（占原 agent/skill ~1800 行的 ≥ 19%）
- `lint_cmd` 0 命中
- grep `'## Escalation Protocol$'` agents/ 命中 4（每 agent 仍有 section，只是内容瘦身）

### 风险与预案
- role-specific 内容误删 → 回查跨阶段约束清单逐项核对
- 文件行数减少不达预期 → 检查是否漏抽"必需的上下文注入"等二级重复段

## P0.3 workflow.md Step 3.5 抽取 + 新增 Step 8

### 目标
- workflow.md Step 3.5 压到 ~50 行（§3.5.0 gate + §3.5.1 env + 1 行 ref）
- workflow.md 新增 Step 8 log batching（与 Step 7 INDEX 同结构）
- bugfix.md 同步（Step 0.5 ref + 小型 log flush 条款）

### 任务清单
- [ ] 把 Step 3.5.2~3.5.6 完整内容搬到 `commands/_progress-monitor-setup.md`
- [ ] 改写 workflow.md Step 3.5：保留 §3.5.0 前台/后台 gate、§3.5.1 env opt-out、§3.5.2 "执行"ref
- [ ] 新增 workflow.md Step 8 log.md Batching（含 Collect / Merge / Edit 三小节 + 3 flush 触发点）
- [ ] bugfix.md Step 0.5 改 ref；bugfix 流程加一行 "Step 8 同 workflow.md" 引用

### 成功信号
- workflow.md 行数 437 → ≤ 360（省 ~80）
- bugfix.md 行数 138 → ≤ 130
- `/roundtable:workflow` 在本项目（dogfood）跑通 Step 3.5 路径 0 错

### 风险与预案
- jq pipeline 改错 → 复制既有字符串不改
- Step 8 flush 触发点漏一个 → 对照 DEC-009 §2.2.2 3 触发点逐一 verify

## P0.4 README / CLAUDE.md / claude-md-template.md / log.md 重塑

### 目标
README §设计原则 扩至 7 条并融入 issue §D；删 §致谢/§贡献/§许可证；CLAUDE.md §设计参考 全删 + §critical_modules 首条扩写；claude-md-template.md 同步；log.md 头部"合并原则" 更新。

### 任务清单
- [ ] README.md：改写 §设计原则（7 条，融入 a/b/c/d/e）；删除 §致谢 / §贡献 / §许可证 三节
- [ ] CLAUDE.md：删 §设计参考 整段；§critical_modules 第 1 条扩写含 `_*.md` helper
- [ ] docs/claude-md-template.md：§critical_modules 示例同步
- [ ] docs/log.md：头部"合并原则" 改为 "orchestrator 按 Step 8 同 agent 同轮合并；agent 不直接写 log"；前缀规范表不变
- [ ] docs/INDEX.md：新增 skills/ 与 commands/ 的 `_*.md` helper 清单（避免误激活）

### 成功信号
- README.md 总行数不增（删 3 节 + 扩 2 原则 ≈ 持平）
- CLAUDE.md 总行数减少 ~12（5 URL + 引言）
- `lint_cmd` 0 命中

## P0.5 lint + 回归 dogfood 验证

### 目标
确认 helper 抽取未破坏 lint / 未遗失功能行为。

### 任务清单
- [ ] 跑 `grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/` 验证 0 命中
- [ ] dogfood：在 roundtable 自身（或 gleanforge）跑一轮 `/roundtable:workflow` 任意小任务，观察：
  - [ ] developer/tester/reviewer 能正确 Read helper 并按内容执行
  - [ ] Escalation block 仍被 orchestrator 解析成功（relay 到 AskUserQuestion）
  - [ ] Progress Monitor 仍 emit + tail 正确
  - [ ] Stage 9 Closeout flush 后 log.md 有合并条目（agent 未自写）
  - [ ] pause-point flush 在 architect → design-confirm 转场时生效

### 成功信号
- 0 lint 命中 + 上述 5 个 dogfood 检查点全绿
- 无 role-specific 行为回归（tester 仍先 emit bug-found 再 escalate / reviewer 仍先 emit Critical 再写报告）

### 风险与预案
- helper Read 失败（路径问题）→ fallback 到 agent 本体原有 section 重新 inline 这个 helper 的内容（临时）+ 排查路径
- flush 漏 → 补 Step 8 flush 触发点审计 + 补丁

## P0.7 DEC 修正

### 目标
补上 DEC 审计发现的 bronze 规则违反 + 实施 follow-through 遗漏。

### 任务清单
- [ ] `docs/decision-log.md` DEC-002 状态行追加 "（决定 5 Superseded by DEC-009 决定 8）" —— **已在 architect 阶段完成**，P0.7 确认一遍
- [ ] `commands/bugfix.md` 规则 2 改写为对称 honor：`if target_project CLAUDE.md declares developer_form_default (either inline or subagent), honor the declaration — this overrides the bugfix inline-bias default.`
- [ ] `docs/testing/subagent-progress-and-execution-model.md` case 3.6 从 WARN 改为 Resolved（或在报告尾部 append "Resolved by DEC-009 决定 9"）
- [ ] `docs/reviews/2026-04-19-subagent-progress-and-execution-model.md` 同步补 "Resolved by DEC-009" footnote

### 成功信号
- grep `developer_form_default: inline\|developer_form_default: subagent` bugfix.md 命中≥ 2（对称表述）
- DEC-002 状态行含 Superseded 标注
- `lint_cmd` 0 命中

### 风险与预案
- bugfix.md 改写引起格式漂移 → 对照 workflow.md §6b.2 一致性

## P0.6 归档 + DEC-009 Accepted

### 任务清单
- [ ] 跑 tester + reviewer 正常工作流（critical_modules 命中）
- [ ] reviewer 通过后把 DEC-009 状态 Proposed → Accepted
- [ ] 把本 exec-plan `exec-plans/active/lightweight-review-plan.md` 移到 `completed/`
- [ ] 在 log.md orchestrator 批 flush 写入 `exec-plan | lightweight-review completed | 2026-04-XX`

## 变更记录

- 2026-04-19 创建
