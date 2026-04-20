---
slug: decision-mode-switch
source: docs/design-docs/decision-mode-switch.md
created: 2026-04-20
completed: 2026-04-20
status: Completed
decisions: [DEC-013]
pr: https://github.com/duktig666/roundtable/pull/34
merge_commit: f76a740
---

# 可切换决策模式 执行计划

> 展开自 `docs/design-docs/decision-mode-switch.md` §8 实施路线。
> **简洁纪律**：所有改动遵守 design-doc §7 行数硬纪律 —— 5 处总计 ≤ 40 行，超出回 architect 评审。

---

## 总览

| Phase | 标题 | 预估行数 | 前置 | 关键风险 |
|-------|------|---------|------|---------|
| P0.1 | orchestrator bootstrap + Escalation 分支 | ~20 | — | Escalation JSON 与 decision block 双路径的 orchestrator 状态机正确性 |
| P0.2 | skill 条件分支（architect + analyst） | ~12（6×2） | P0.1 | 两 skill 模板需完全一致，避免 diff 漂移 |
| P0.3 | `bugfix.md` ref | ~3 | P0.1 | — |
| P0.4 | `README.md` §决策模式 章节 | ~10 | P0.1~P0.3 | 对外表述准确性 |
| P0.5 | tester dogfood E2E | 代码不改 | P0.1~P0.4 | text 模式在 TG / 终端 2 环境都 pass |
| P0.6 | reviewer 一致性巡视 + 行数验收 | 代码不改 | P0.5 | 5 处行数合计 ≤ 40 |
| P0.7 | lint_cmd 扫描闭环 | 代码不改 | P0.6 | 0 命中 |
| **合计行数** | | **~45**（含 README，prompt 本体 ~35） | | |

---

## P0.1 orchestrator bootstrap + Escalation 渲染分支

### 目标
让 `commands/workflow.md` 具备解析 decision_mode + 把 agent Escalation JSON 按 mode 渲染的能力。

### 任务清单

- [x] 在 `commands/workflow.md` 顶部新增 **Step -1 Decision Mode Bootstrap**（实际 5 行）
  - [x] 解析 `$ARGUMENTS` 里 `--decision=text|modal`
  - [x] 回退 env `ROUNDTABLE_DECISION_MODE`（Bash 一次读取）
  - [x] 默认 `modal`
  - [x] 注入规则：Task prompt prefix / skill context prefix 加 `decision_mode: <value>` 一行
- [x] 在 `commands/workflow.md` Step 5 Subagent Escalation 段**新增 mode 分支**（实际 3 行修改，扩 modal + 加 text）
  - [x] Parse JSON 不变
  - [x] `modal` → 调 `AskUserQuestion`（现行保留）
  - [x] `text` → 按 design-doc §3.1 schema 渲染 `<decision-needed>` 文本块 emit 到对话流，pause 等用户自由文本回复
  - [x] 用户回复后 fuzzy 解析注入 prompt 重派

### 成功信号
- 新增 Step -1 段行数 ≤ 8，Step 5 分支段 ≤ 12（合计 ≤ 20）
- Bootstrap 逻辑可从 `ROUNDTABLE_DECISION_MODE=text` env 读出 text 模式
- `--decision=modal` 能覆盖 env 的 text

### 风险与预案
- **风险**：Escalation JSON 的某些 option 字段（如 `recommended`）在 text 渲染时缺失处理 → 预案：渲染逻辑用 `label{' ★ 推荐' if recommended else ''}` 模式
- **风险**：orchestrator 在 pause 状态被误以为 abort → 预案：emit 块后 orchestrator 输出一行 "等待用户回复..." 明示状态

---

## P0.2 skill 条件分支（architect + analyst）

### 目标
两个 skill prompt 识别 `decision_mode` context prefix，按 mode 选择决策交互通道。

### 任务清单

- [x] `skills/architect/SKILL.md` "AskUserQuestion 使用要点"段后**追加 5 行**
  - [x] `modal` 分支：保持现行 `AskUserQuestion(...)` 描述
  - [x] `text` 分支：emit `<decision-needed>` 块（ref design-doc §3.1 schema，不重复 schema 内容）
  - [x] 强调 emit 后 skill 停下不继续调用工具
- [x] `skills/analyst/SKILL.md` 同款追加（5 行，仅 `recommended` 禁用描述差异）
- [x] 检查：architect `recommended` 最多 1 个 option 带 ★；analyst 禁用 `recommended`（两者现行约束保留）

### 成功信号
- 两 skill 追加内容合计 ≤ 12 行
- 模板 diff 只在 "architect" / "analyst" 角色名和 "recommended" 约束描述

### 风险与预案
- **风险**：两 skill 描述慢慢漂移 → 预案：`lint_cmd` 后续加 pair-diff 检查规则（本 DEC 不做）

---

## P0.3 bugfix.md ref

### 目标
`commands/bugfix.md` 同样走 decision_mode bootstrap 与 Escalation 渲染。

### 任务清单

- [x] `commands/bugfix.md` 顶部新增 **Step -1** 一行 ref：`见 commands/workflow.md Step -1 / Step 5 同款规则`（实际 4 行含标题）

### 成功信号
- 行数 ≤ 3
- 在 bugfix 流程跑 text 模式时 Escalation 分支生效（P0.5 验证）

---

## P0.4 README §决策模式章节

### 目标
对外用户文档说明机制与配置方式。

### 任务清单

- [x] `README.md` 在 Quick Start §3. Run it 前新增 **§Decision mode** 章节（实际 10 行）
  - [x] 1 段介绍：两模式存在与默认 + 远程前端用例
  - [x] 1 个配置表：3 级优先级链（CLI arg / env / default）
  - [x] 1 行链接到 DEC-013 / design-doc
- [x] `README-zh.md` 同款中文镜像（10 行）

### 成功信号
- 章节行数 ≤ 10
- 配置示例可 copy-paste 直接跑

---

## P0.5 tester dogfood E2E

### 目标
tester 在 2 种环境各跑一次 text 模式验证全链可用。

### 任务清单

- [ ] tester 设计 E2E 场景：选一个简单 issue（如现有 open issue 里最小的一个）走 `/roundtable:workflow` text 模式
- [ ] **场景 A 本地终端**：`ROUNDTABLE_DECISION_MODE=text /roundtable:workflow ...` 主会话确认 analyst / architect emit `<decision-needed>` 块、orchestrator 把 agent Escalation JSON 也渲染为块
- [ ] **场景 B Telegram 驱动**：通过 TG 触发 workflow，确认决策块经 MCP 转到 TG 且用户回复能被 orchestrator fuzzy 解析续跑
- [ ] 对照 design-doc §6 验收标准 6 项逐项勾选
- [ ] 产出 `docs/testing/decision-mode-switch.md` 记录 dogfood 轨迹 + 发现的问题

### 成功信号
- design-doc §6 6 项验收全部 ✅
- testing 文档归档

### 风险与预案
- **风险**：orchestrator fuzzy parse 用户"选 B 但加 X"类修正回复时推断错误 → 预案：tester 专门造此类用例，若失败则 escalate 回 developer 改 bootstrap 的 parse hint

---

## P0.6 reviewer 一致性巡视 + 行数验收

### 目标
reviewer 巡视 5 处改动的一致性 + 行数纪律。

### 任务清单

- [x] `commands/workflow.md` + `commands/bugfix.md` + `skills/architect/SKILL.md` + `skills/analyst/SKILL.md` + `README.md` 一致性检查（decision block schema 5 处对齐 canonical）
- [x] 行数统计：per-workflow token +30 行（orchestrator 20 + skill 6 按需）；总 diff 90 行含 README 镜像 + design-doc post-fix + testing + reviews
- [x] DEC-013 与 design-doc 交叉引用正确
- [x] critical_modules 命中检查：本改动触达 prompt 本体 + AskUserQuestion Option Schema + workflow Phase Matrix 多项 → reviewer 必触发已自然满足；Approve w/ 3 Warning（W1 design-doc §3.1 行格式内部矛盾 / W2 §5 路径滞后 / W3 tester doc 行号引用易漂）；W1/W2 已 inline 回填，W3 不修（tester 报告历史不回改）

### 成功信号
- 行数报告 per-workflow token +30 行（达标 ≤40）
- 一致性无 Critical finding（实际：3 Warning / 0 Critical；W1/W2 inline post-fix 清除）
- reviewer Approve with caveats；不落盘（Warnings 已即时消除）

### 实际结果（2026-04-20）
reviewer 判定 Approve，3 Warning：
- **W1**（已 fix）: design-doc §3.1 canonical 代码框 vs 文字描述自相矛盾 → L121 重写对齐代码框
- **W2**（已 fix）: design-doc §5 路径滞后 `skills/architect.md` → `skills/architect/SKILL.md`
- **W3**（不修）: tester doc 行号引用易漂 → 历史记录不回改，将来 tester 改用字符串定位（非本 DEC scope）

---

## P0.7 lint_cmd 扫描 + 闭环

### 目标
硬编码扫描 0 命中，闭环合并。

### 任务清单

- [x] 跑 `grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/`（CLAUDE.md 声明的 lint_cmd）
- [x] 0 命中 → 通过
- [ ] 计划归档：本文件从 `active/` 移到 `completed/`（待 commit/PR 闭环后由 orchestrator 代移）

### 成功信号
- lint_cmd 0 命中
- PR 关联 issue #31 `fixes #31` 可合并

---

## 跨阶段约束

- **对 agent prompt 本体零改动**：5 个 agent 不进 PR diff（D1 = A 硬纪律）
- **对 DEC-002 / DEC-003 schema 零改动**：Escalation / research-result JSON 保持原样
- **对 Phase Matrix / Step 4 / critical_modules 机械触发零改动**
- **对 target CLAUDE.md 业务规则边界零改动**（DEC-011 / DEC-012 边界）
- **行数硬纪律**：5 处改动合计 ≤ 40 行（design-doc §7）

## 变更记录

- 2026-04-20 初版（应用户 TG message #256 要求追加）
