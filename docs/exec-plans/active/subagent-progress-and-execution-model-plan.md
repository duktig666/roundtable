---
slug: subagent-progress-and-execution-model
source: design-docs/subagent-progress-and-execution-model.md
created: 2026-04-19
status: Active
decisions: [DEC-004, DEC-005]
issue: https://github.com/duktig666/roundtable/issues/7
---

# subagent 进度可见性 + 执行模型可选配 执行计划

> 本计划展开自 `design-docs/subagent-progress-and-execution-model.md`。

## 总览

| Phase | 标题 | 预估 | 前置 | 关键风险 |
|-------|------|------|------|---------|
| P0.1 | agents/developer.md 加双形态 + progress | 8 min | — | 双形态语义误解 / D8 冲突 |
| P0.2 | agents/tester.md 加 progress | 4 min | — | 与 critical_modules 触发规则重叠 |
| P0.3 | agents/reviewer.md 加 progress | 4 min | — | 与 review 分级弄混 |
| P0.4 | agents/dba.md 加 progress | 4 min | — | — |
| P0.5 | agents/research.md 加 progress | 4 min | — | DEC-003 `<research-result>` 不受影响 |
| P0.6 | commands/workflow.md 加 Monitor 启动 + form 切换 | 10 min | — | Phase Matrix / 并行判定树回归 |
| P0.7 | commands/bugfix.md 加 form 识别 + Monitor | 6 min | — | 同 P0.6 |
| P0.8 | docs/claude-md-template.md 加 developer_form_default 可选 | 3 min | — | 不得违反 D5 |
| P0.9 | CLAUDE.md (plugin 自身) critical_modules 同步 | 2 min | P0.1-P0.7 | 漏列 |
| P0.10 | lint + self-dogfood smoke | 5 min | P0.1-P0.9 | Monitor 调用失败 |

**并行建议（orchestrator 决策）**：P0.1 ~ P0.8 文件路径两两 disjoint，可按 DEC-002 §4 四条件树并行派发（每批次 ≤4 subagent，与 DEC-003 硬上限对齐）。建议分两批：

- Batch 1（4 并行）：P0.1 / P0.2 / P0.3 / P0.4
- Batch 2（4 并行）：P0.5 / P0.6 / P0.7 / P0.8
- Batch 3（串行）：P0.9 → P0.10

---

## P0.1 agents/developer.md 加双形态 + progress reporting

### 目标

给 `agents/developer.md` 新增两个 section：`## Execution Form`（DEC-005 双形态）+ `## Progress Reporting`（DEC-004 emit 约定）。

### 任务清单

- [x] 在 `agents/developer.md` 顶部（frontmatter 之后、原有正文之前或合适位置）新增 `## Execution Form` section，内容含：
  - 双形态声明表（subagent=default，inline 可选）
  - 交互通道差异（AskUserQuestion vs Escalation）
  - inline 档不 emit progress（主会话直接可见）
- [x] 新增 `## Progress Reporting` section，内容含：
  - Injection 变量：`{{progress_path}}`, `{{dispatch_id}}`, `{{slug}}`, `{{role}}`
  - 三种 event 类型 (`phase_start` / `phase_complete` / `phase_blocked`) 的 emit 模板（Bash echo + JSON 单行）
  - 颗粒度要求（phase 级；不在每工具调用后 emit）
  - 漏 emit 的降级语义（静默，非错误）
- [x] frontmatter 保持不变（name / description / tools 不动）

### 成功信号

- `agents/developer.md` 有 2 个新 section
- grep `## Execution Form` / `## Progress Reporting` 在该文件各出现 1 次
- 仓库根 lint_cmd 依然 0 命中

### 风险与预案

- **风险**：双形态段让读者误以为 form 是 CLAUDE.md 决定 → **预案**：§Execution Form 首段明写 "form is chosen by the orchestrator per dispatch, see commands/workflow.md Step 6"
- **风险**：Progress Reporting 与已有 Escalation Protocol 段混淆 → **预案**：在 §Progress Reporting 结尾写一句 "progress 与 escalation 正交：progress 是进度透传，escalation 是决策请求，两通道独立"

---

## P0.2 agents/tester.md 加 progress reporting

### 目标

仅追加 `## Progress Reporting` section（tester 保持 subagent 单形态 per DEC-005）。

### 任务清单

- [x] 新增 `## Progress Reporting` section（内容结构同 P0.1，`role` 字段 = `tester`）
- [x] 不动 tester 现有的 critical_modules 触发纪律 / test plan 模板 / Escalation Protocol
- [x] 在 Progress Reporting 里 phase 命名建议可提"当 exec-plan 无 P0.n 结构时用 `test-plan` / `writing-tests` / `adversarial-run` 等自定义 phase 名"

### 成功信号

- `agents/tester.md` 新增 1 个 section
- grep `## Progress Reporting` 出现 1 次
- tester 的 "对抗性测试禁触 src" 纪律保留（grep 原文档关键句仍在）

### 风险与预案

- **风险**：tester 在"写 reproduction test → escalation"场景下应先 emit phase_blocked 再抛 escalation，顺序误解 → **预案**：在 Progress Reporting section 给一行明文 "emit `phase_blocked` before writing `<escalation>` to the final message"

---

## P0.3 agents/reviewer.md 加 progress reporting

### 目标

仅追加 `## Progress Reporting` section。

### 任务清单

- [x] 新增 `## Progress Reporting` section（`role` = `reviewer`）
- [x] phase 命名建议：`discovering` / `analyzing` / `classifying` / `writing-review`
- [x] 不改 Critical/Warning/Suggestion 分级纪律

### 成功信号

- `agents/reviewer.md` 新增 1 个 section
- grep `## Progress Reporting` 出现 1 次
- 分级纪律原文保留

### 风险与预案

- **风险**：reviewer 找到 Critical 时 progress emit 与 review report 冲突 → **预案**：明写 "Critical 发现：先 emit `phase_blocked` summary=具体发现主语，再按原有流程写 review report"

---

## P0.4 agents/dba.md 加 progress reporting

### 目标

仅追加 `## Progress Reporting` section。

### 任务清单

- [x] 新增 `## Progress Reporting` section（`role` = `dba`）
- [x] phase 命名建议：`schema-read` / `migration-analysis` / `index-check` / `writing-review`

### 成功信号

- `agents/dba.md` 新增 1 个 section
- 其他文档无连带改动

### 风险与预案

- 无重大风险

---

## P0.5 agents/research.md 加 progress reporting

### 目标

仅追加 `## Progress Reporting` section（与 DEC-003 `<research-result>` 正交）。

### 任务清单

- [x] 新增 `## Progress Reporting` section（`role` = `research`）
- [x] phase 建议：`scope-received` / `sources-fetched` / `synthesis`
- [x] 在 section 末尾写一行 "progress emit 与 `<research-result>` / `<research-abort>` final message 正交，两通道独立"

### 成功信号

- `agents/research.md` 新增 1 个 section
- DEC-003 `<research-result>` JSON schema 引用保留

### 风险与预案

- **风险**：research 并行 4 个 subagent 同时 emit progress → **预案**：progress_path 按 dispatch_id 命名，天然隔离（DEC-004 §3.7）

---

## P0.6 commands/workflow.md 加 Monitor 启动 + form 切换

### 目标

`/roundtable:workflow` 在每次派发 subagent 前自动启 Monitor；在 developer 阶段判定是否切 inline。

### 任务清单

- [x] Step 3 "Slug + Artifact Handoff" 之后、或合适位置加新 Step "Progress Monitor Setup"：
  - 生成 dispatch_id、progress_path
  - mkdir -p 临时目录
  - 启 Monitor `tail -F ... | jq ...`（含 --unbuffered）
  - 识别 `ROUNDTABLE_PROGRESS_DISABLE=1` env 跳过
  - 在 Task prompt 里注入 `progress_path` / `dispatch_id` / `slug` / `role`
- [x] Step 6 或新 Step "Developer Form Selection" 加决策流：
  - 读 target CLAUDE.md `developer_form_default`
  - 读任务描述是否含 `@roundtable:developer inline`
  - 否则按"任务小标志"触发 AskUserQuestion 让用户选（Option Schema 含 rationale/tradeoff/recommended）
  - inline 档：orchestrator 主会话内联执行 `agents/developer.md` prompt
  - subagent 档：Task 派发（带 progress injection）
- [x] Phase Matrix 补 "Progress notification" 列（可视化给用户看）

### 成功信号

- `commands/workflow.md` 新增 2 个新 Step（或等价 inline 段）
- grep `Monitor` / `dispatch_id` / `progress_path` 在该文件出现
- 与 DEC-002 §4 并行判定树不冲突（progress 是 per-dispatch 独立，天然并行安全）

### 风险与预案

- **风险**：Monitor 启动 Bash 模板在 `CLAUDE_SESSION_ID` 未设时不够稳健 → **预案**：fallback 到 `$(date +%s)-$$`（pid 混入）降低撞车概率
- **风险**：Phase Matrix 已复杂，再加一列让用户看不清 → **预案**：progress 在 Phase Matrix 下方作为独立的实时输出行，不占矩阵列

---

## P0.7 commands/bugfix.md 加 form 识别 + Monitor

### 目标

`/roundtable:bugfix` 流程同步支持 progress + form 切换（bugfix 默认就偏小任务，inline 可能是常见选择）。

### 任务清单

- [x] 模仿 P0.6 的 Progress Monitor Setup 段（不用完全复制，用引用 `commands/workflow.md` 相应 step 即可）
- [x] Developer Form Selection 默认值在 bugfix 流程里改为 "inline 友好"（小任务通常）
- [x] 保留 bugfix 原有"跳过 architect 设计 / 必须加 regression test"纪律

### 成功信号

- `commands/bugfix.md` 含 Monitor 启动模板或引用
- bugfix 原有纪律原文保留

### 风险与预案

- 无重大风险；bugfix 命令相对简单

---

## P0.8 docs/claude-md-template.md 加 developer_form_default 可选

### 目标

给用户在自己项目 CLAUDE.md 声明"我的 developer 默认用哪档"的 opt-in 示例（per DEC-005 §4）。

### 任务清单

- [x] 在 `# 多角色工作流配置` section 的合适子节（可能是 "工具链覆盖" 之后、或单独子节 "角色偏好"）加可选示例：
  ```markdown
  ## 角色偏好（可选）

  - **developer_form_default**: `inline` —— 本项目 developer 默认用 inline 档（小项目 / 紧跟过程场景推荐）。省略此键则 = subagent。
  ```
- [x] 在 FAQ 或相邻段落说明这是"per-project 偏好"，不违反 DEC-001 D2（D2 禁止 plugin 元协议入 CLAUDE.md；form 偏好属于业务偏好）

### 成功信号

- `docs/claude-md-template.md` 新增 angle / example
- 不影响已有 critical_modules / 设计参考 / 触发规则 sections

### 风险与预案

- **风险**：用户误以为 tester/reviewer/dba 也能 override → **预案**：在示例注释里明写"仅 developer 支持此键；其他三角色永远 subagent（DEC-005）"

---

## P0.9 CLAUDE.md (plugin 自身) critical_modules 同步

### 目标

把 DEC-004 的 progress schema 和 DEC-005 的 form 切换加入 plugin 自身 CLAUDE.md 的 `critical_modules` 列表（因为它们是 plugin 元协议，改动会传播）。

### 任务清单

- [x] 编辑 `/data/rsw/roundtable/CLAUDE.md` §critical_modules 列表，新增两行：
  - `Progress event JSON schema (DEC-004)`: 所有 subagent 的进度 emit 依赖此 schema，schema 偏差让 orchestrator Monitor / jq 解析失败
  - `Developer execution-form switching rules (DEC-005)`: 切换规则错会导致 inline/subagent 选择错位，UX 与 context 风险均受影响
- [x] 确认"条件触发规则" section 仍覆盖新增的修改点（修改 agents/*.md → 触发 lint_cmd 不变；新增若需硬编码扫描项再补）

### 成功信号

- `CLAUDE.md` §critical_modules 至少新增 2 条
- 现有 critical_modules 不被破坏

### 风险与预案

- **风险**：critical_modules 列太长，tester 每次都全触 → **预案**：critical_modules 本就是 OR 逻辑，新增 2 条不改变判定成本，风险可控

---

## P0.10 lint + self-dogfood smoke

### 目标

保证 lint 0 命中；manual dogfood 验证 Monitor+JSON emit 链路在一个最小场景工作。

### 任务清单

- [x] 跑 lint_cmd：`grep -rnE "gleanforge|dex-sui|dex-ui|DEC-00[3-9]|\bvault/|\bllm/" skills/ agents/ commands/`
  - 注意：由于新增 DEC-004 / DEC-005，regex 的 `DEC-00[3-9]` 需更新为 `DEC-00[6-9]` 或扩展为 `DEC-0[1-9][0-9]`。或重写规则 —— 本步骤顺便修 lint 命令
- [x] 手动 smoke：在 `/data/rsw/roundtable` 本地做一个最小 subagent dispatch 验证
  - 准备一个 dummy dispatch（Task 调用 `general-purpose` subagent 模拟流程）
  - subagent prompt 里手动 echo 2-3 条 progress event
  - 主会话观察 Monitor 是否接到 notification
  - 若失败，记录失败原因到 testing 阶段报告

### 成功信号

- lint_cmd 0 命中（修好 DEC regex 后）
- 手动 smoke 至少看到 1 条 Monitor notification 出现在主会话

### 风险与预案

- **风险**：`CLAUDE_SESSION_ID` env 未注入或 `/tmp` 权限 → **预案**：tester 阶段 adversarial 测试这两条路径
- **风险**：lint regex 更新漏 match 旧引用 → **预案**：改 regex 前先全库 grep 看所有 `DEC-00X` 引用清单，确保 whitelist 化

---

## 变更记录

- 2026-04-19 创建 —— 展开 design-docs/subagent-progress-and-execution-model.md 的 10 个 phase，P0.1-P0.8 可两批并行（4+4），P0.9-P0.10 串行收尾
- 2026-04-19 P0.1-P0.10 全部完成（主路径 ~10 min）：
  - P0.1-P0.5 五个 agent 各加 `## Progress Reporting`；P0.1 developer 额外加 `## Execution Form` 双形态
  - P0.6 commands/workflow.md 加 Step 3.5 Progress Monitor Setup + Step 6b Developer Form Selection + Phase Matrix 实时 progress 输出约定
  - P0.7 commands/bugfix.md 加 Step 0.5 Monitor reference + bugfix 专属 Developer Form Selection（inline 友好默认）
  - P0.8 docs/claude-md-template.md 加「角色偏好（可选）」developer_form_default + 2 条 FAQ
  - P0.9 plugin CLAUDE.md critical_modules 新增 DEC-004 progress schema + DEC-005 form switching rules 两条
  - P0.10 lint_cmd regex 修正（drop 伪"DEC-00[3-9]"误报分支，改为纯 target-project 名 / 外部路径扫描），0 命中；smoke 测 `/tmp/roundtable-progress/{session}-{dispatch}.jsonl` 3 event 全过 jq 过滤，输出格式 `[<phase>] <role> <event> — <summary>` 与设计文档 §3.3 一致
