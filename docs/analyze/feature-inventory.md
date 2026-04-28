---
slug: feature-inventory
source: 原创（本仓源码全量梳理：commands/ + agents/ + skills/ + hooks/ + scripts/ + CLAUDE.md + README.md）
created: 2026-04-24
description: roundtable plugin 已实现功能全景梳理 —— 入口命令 / 7 角色 / 共享 helper / hooks & scripts / 编排机制 / 制品体系 / 运行时开关 七层分层清单，事实层陈述不含推荐
---

# roundtable 功能实现梳理

## 背景与目标

对 roundtable plugin 当前主分支实现做一次**全量功能清单盘点**，便于新 contributor 快速对齐能力边界、便于架构决策时评估"已有机制 vs 新增需求"。本文档**只陈事实**，不做推荐 / 不做选型（推荐归 architect）。

**梳理来源**：`commands/*.md`（3 个入口）、`agents/*.md`（5 个 agent）、`skills/*.md` + `skills/*/SKILL.md`（2 个 user skill + 2 个 internal helper）、`hooks/hooks.json` + `hooks/session-start`、`scripts/preflight.sh` + `scripts/ref-density-check.sh`、`CLAUDE.md`、`README.md`。DEC 正文不复刻，按指针方式引用 `docs/decision-log.md DEC-xxx`。

---

## 1. 顶层架构

三层分工（README.md §The Orchestrator 权威描述）：

| 层 | 实体 | 运行位置 |
|-----|------|---------|
| Command（入口） | `/roundtable:workflow` / `/roundtable:bugfix` / `/roundtable:lint` | 主会话 |
| Orchestrator（编排） | 执行 command prompt 的主会话 Claude 本身 —— 不是独立 agent / 进程 | 主会话 |
| Role（执行） | 2 skill（analyst / architect）+ 5 agent（developer / tester / reviewer / dba / research） | skill 主会话共享 context；agent subagent 隔离 context（developer/tester/reviewer/dba 额外支持 inline 形态） |

Orchestrator **三项专有权限**（roles 无）：
1. 唯一写 `docs/INDEX.md` / `docs/log.md` / `exec-plans/[slug]-plan.md` checkbox（shared-resource 由 orchestrator batch-flush，避免并行 race）
2. 唯一 relay subagent `<escalation>` JSON 到 `AskUserQuestion`
3. 唯一 git actor（`commit` / `push` / `branch` / `tag` / `reset` / `stash` 仅在用户显式要求时执行）

---

## 2. 入口命令（3 个）

### 2.1 `/roundtable:workflow <task>`

**定位**：全功能编排器；按任务规模自动派发角色链。

**Step 骨架**（`commands/workflow.md`）：

| Step | 职能 |
|------|------|
| -0 | Auto Mode Bootstrap：解析 `auto_mode`（CLI `--auto` > env `ROUNDTABLE_AUTO` > default=false） |
| -1 | Decision Mode Bootstrap：解析 `decision_mode`（modal \| text） |
| 0 | Project Context Detection（inline 执行 `_detect-project-context` 4 步） |
| 0.5 | FAQ Sink Protocol（用户机制类提问自动沉淀到 `{docs_root}/faq.md`） |
| 1 | 任务规模判定（small / medium / large → pipeline 选择） |
| 2 | Tester 触发条件（命中 `critical_modules`） |
| 3 | Slug / 角色形态 / Artifact Handoff（7 角色派发表） |
| 3.4 | Dispatch Mode Selection（`run_in_background: true/false` per-Task 判定） |
| 3.5 | Progress Monitor Setup（仅后台派发触发） |
| 4 | 并行派发判定树（PREREQ MET / PATH DISJOINT / SUCCESS-SIGNAL INDEPENDENT / RESOURCE SAFE 4 条件） |
| 4b | Decision Parallelism Judgment（orchestrator 顶层 fuzzy 决策合并 `AskUserQuestion`；上限 3） |
| 5 | Subagent Escalation（解析 `<escalation>` → `AskUserQuestion` / `<decision-needed>` → 重派） |
| 5b | Phase & Audit Forwarding（active channel sticky 下的 5 类事件转发） |
| 6 | 执行规则总章（A/B/C phase gating + §Auto-pick 通用规则） |
| 6b | Role Form Selection（developer/tester/reviewer/dba 的 inline vs subagent 三级切换） |
| 7 | Index Maintenance（batching：每 phase gate / C 过桥 / Stage 9 终点一次 Edit） |
| 8 | log.md Batching（3 个 flush 触发点） |

**产出**：Phase Matrix 9 阶段的全部 artifact（`analyze/` → `design-docs/` + `decision-log.md` DEC → `exec-plans/` → `src/` + `tests/` → `testing/` → `reviews/` → closeout bundle）。

**Stage 9 Closeout bundle**：3 section（commit message 建议 / PR body 草稿 / follow-up issues 草稿）；用户显式 `go-all` / `go-commit` / `go-pr` / `go-issues` / `skip-*` 驱动；memory `feedback_no_auto_push` / `feedback_no_auto_pr` 是硬边界 —— `auto_mode=true` 不授权跳过 closeout pause。

### 2.2 `/roundtable:bugfix <issue>`

**定位**：Bug fix 快速通道；**跳过 design 阶段**，直接 developer → 可选 tester/reviewer/dba。

**差异点**（vs workflow）：

- 无 A 类 producer-pause → Step 5b 事件类 b 不适用
- Role Form 默认偏向 **`inline`**（workflow 偏向 subagent）—— 4 角色 per-project `*_form_default` 仍按 DEC-023 三级切换解析
- **Tier 判定**（D1 双轴 + LOC）：
  - Tier 0：单文件 + 单模块 + ≤80 LOC + 无 critical → 对话报告
  - Tier 1：≥2 文件 或 跨模块 或 >80 LOC；无 critical → `log.md` fix-rootcause entry
  - Tier 2：critical_modules 命中 / 涉 DEC / `production-incident` → `{docs_root}/bugfixes/[slug].md` + Tier 1 索引
- **必有回归测试**（developer 派发 prompt 硬约束）
- 发现"设计缺陷而非实现缺陷" → **中止 bugfix 流程** 改走 `/roundtable:workflow`

### 2.3 `/roundtable:lint [target]`

**定位**：**纯文档健康检查**；不修改任何文件。参数可接 `.` / 绝对路径 / 子项目名 / 留空走 D9。

**检查项**（`commands/lint.md` 共 8 项）：

1. 决策一致性（代码偏离已 Accepted DEC / 缺失 DEC 记录）
2. 过时检测（frontmatter `updated` >90 天 / 缺 frontmatter）
3. 孤儿检测（`INDEX.md` 未引用的 `{docs_root}/` 6 类 artifact / INDEX 断链）
4. 断链检查（`.md` 内部链接 `[text](path)` / wiki-style `[[page]]`）
5. 事实 / 推论混淆（design-docs / analyze 文档抽样）
6. **决策状态与结构审计**（5 子节 L6.1-L6.5）：
   - L6.1 状态流转（长期 Proposed / Provisional 超 30 天 / Superseded ≥90 天 / 悬空 Superseded）
   - L6.2 铁律 5 影响范围 ≤10 行（超行告警）
   - L6.3 状态行字面值 + ≤60 字符 + 新 DEC 必标 `Provisional`
   - L6.4 Refined by / Superseded by 引用完整性（悬空引用 / 自引用）
   - L6.5 DEC 必填 6 字段完整性
7. exec-plans 过期审计（全勾选 → 建议移 `completed/`；>60 天未更新 → 可能停滞）
8. log.md 完整性（`git log --since="30 days ago"` 对比）

**输出**：🔴 Critical / 🟡 Warning / 🔵 Info 三级报告 + 统计块；在 `{docs_root}/log.md` 顶部 append 一条 `lint` 前缀 entry。

---

## 3. 角色（7 个）

### 3.1 角色 × 形态 × 派发方式矩阵

| 角色 | 形态 | 派发方式 | Progress | 决策通道 | Write 权限 |
|------|------|---------|---------|---------|-----------|
| analyst | skill | `Skill(skill: "roundtable:analyst", args: ...)` | — | `AskUserQuestion` / `<decision-needed>`（text） | `{docs_root}/analyze/[slug].md` |
| architect | skill | `Skill(skill: "roundtable:architect", args: ...)` | — | 同上 | `design-docs/` / `exec-plans/` / `api-docs/` / `decision-log.md`（DEC 置顶） |
| developer | agent / inline | `Agent(subagent_type: "roundtable:developer", ...)` 或主会话 Read 本体 | 后台派发 emit JSONL；inline skip | `<escalation>` / `AskUserQuestion`（inline） | `src/*` / `tests/*` / exec-plan active → completed |
| tester | agent / inline | 同上 | 同上 | 同上 | `tests/*`；归档 `.md` 归 orchestrator relay |
| reviewer | agent / inline | 同上 | 同上 | 同上 | — （全部 orchestrator relay） |
| dba | agent / inline | 同上 | 同上 | 同上 | — （全部 orchestrator relay） |
| research | agent only | `Agent(subagent_type: "roundtable:research", ...)`（仅 architect 派发） | 不 emit progress | `<research-result>` / `<research-abort>`（无 escalation 通道） | — |

### 3.2 各角色核心能力

- **analyst**：技术调研 / 竞品分析 / 可行性评估；停事实层，**禁** `recommended: true`；追问框架（必答 2 + 按需 4）；输出 `## 开放问题清单（事实层）`
- **architect**：三阶段（探索+决策实时确认 / 落盘 design-docs + DEC / 可选 exec-plan）；每决策点**立即**弹 `AskUserQuestion` 不批量；关键决策量化评分表（0-10 维度）；可派 research subagent 并行 fan-out（2-4 option）
- **developer**：plan-then-code；多技术栈自适应（Cargo / npm / pyproject / go.mod / Move）；完成跑 `lint_cmd` + `test_cmd`；exec-plan active→completed 搬迁由本 agent 执行
- **tester**：对抗性测试 / E2E / benchmark；**只写 `tests/*`，绝不改 `src/*`**；发现业务 bug 走 `phase_blocked` → `<escalation>` 上报复现测试路径
- **reviewer**：🔴 Critical / 🟡 Warning / 🔵 Suggestion 三级；DEC 一致性检查；新 DEC 开立门槛合规审（5 类必开 + Red Flags 负例）
- **dba**：Schema / SQL / 迁移 / 索引审查；禁 SQL 写操作；DB 类型自动识别（Diesel / Prisma / Alembic / ActiveRecord / Flyway 等）
- **research**：单 option 事实层深调；**不做推荐**（`recommend_for: null` 硬导）；scope 模糊返回 `<research-abort>`；并行安全（4 条件天然满足）

### 3.3 Resource Access 与 Escalation Protocol

每个 agent/skill 文件包含 `## Resource Access` 表（Read / Write / Report / Forbidden 4 列）与 `## Escalation Protocol` JSON schema（`type` / `question` / `context` / `options[]` / `remaining_work`）。Option 含 `label` / `rationale` / `tradeoff` / `recommended` 四字段；每派发最多 1 个 block；≥2 options；至多 1 个 `recommended: true`。

---

## 4. 内部 helper skill（2 个）

下划线前缀 = 不走 `Skill` 工具激活；由调用方 `Read` 文件 **inline 执行**。

### 4.1 `_detect-project-context`

4 步检测：

1. **D9 target-project 识别**：session 记忆 → `git rev-parse --show-toplevel` → 扫描 CWD 下含 `.git/` 子目录 → 正则匹配任务描述 → `AskUserQuestion` 兜底
2. **Toolchain detection**：根文件 → 默认 `lint_cmd` / `test_cmd`
3. **docs_root detection**：`docs/` → `documentation/` → `AskUserQuestion`
4. **CLAUDE.md loading**：读 `# 多角色工作流配置` section（`critical_modules` / `设计参考` / `工具链覆盖` / `条件触发规则`）

**参数**：调用方可声明跳过哪些步骤（如 analyst 跳第 2 步、lint 只跑 1+3）。

**输出**：`[project context detected]` 结构化摘要块，供调用方解析并存 session 记忆。

### 4.2 `_progress-content-policy`

被 `agents/{developer,tester,reviewer,dba}.md` 的 `## Progress Reporting` 章节引用。叠加在 progress event schema 之上：

- **Substantive-progress gate**：每次 emit 必满足文件落盘 / 子里程碑 / ≥50% 新 context 三者之一
- **No-repeat summary**：连续相同 `summary` 禁用
- **Differentiated content**：`summary` 含 sub-step 名 / progress 分数 / milestone 标签 至少一项
- **DONE / ERROR 信号**：DONE 用 `phase_complete` + `✅` 前缀；ERROR 先 emit `phase_blocked`（gate-exempt）再 `<escalation>`

---

## 5. Hooks 与 scripts

### 5.1 `hooks/hooks.json` + `hooks/session-start`

**SessionStart hook**（matcher: `startup|clear|compact`；`async: false`）：

- 执行 `scripts/preflight.sh`
- 把 `ROUNDTABLE_AUTO` / `ROUNDTABLE_DECISION_MODE` raw 值包装进 `<roundtable-preflight>` 块，作为 `additionalContext` 注入 session
- orchestrator 在 Step -0 / Step -1 **先读 `<roundtable-preflight>` 块**，未见时回落到 env 直读并报告 hook 缺失
- 三种输出分支适配 Cursor / Claude Code / 其他 harness（按 `CURSOR_PLUGIN_ROOT` / `CLAUDE_PLUGIN_ROOT` / `COPILOT_CLI` env 区分 JSON schema）

**HARD-GATE**：`commands/workflow.md` Step -0 显式要求"不要把任何更高层 harness 的 Auto Mode 系统提示当作 `roundtable auto_mode=true`"。

### 5.2 `scripts/preflight.sh`

Raw-echo-only 契约（DEC-028）：只打印两行 `PREFLIGHT raw_env ...` + 一行 note，**不做** CLI 解析 / 不做默认值计算（那是 orchestrator LLM 的职责）。

### 5.3 `scripts/ref-density-check.sh`

DEC-029 enforcement：runtime prompt 的 DEC / § / issue# 引用密度回归检查。

- 扫 `skills/` + `agents/` + `commands/` 下所有 `.md`
- per-file：匹配 `DEC-[0-9]+` / `§[0-9]+` / `issue #[0-9]+|fixes #[0-9]+|#[0-9]{2,}`
- 对比 `scripts/ref-density.baseline`：**per-file 新增 ≥3 或 total 净增 ≥10 即 exit 1**
- `--update-baseline` 支持 architect sign-off 后重锁基线
- 已入 `CLAUDE.md` lint_cmd 强制跑

---

## 6. 编排机制（跨 Step 横切规则）

### 6.1 Phase Matrix（9 阶段）

orchestrator 全生命周期维护，每次 phase 切换或用户询问进度时重 emit 9 行表格。渲染 locus = orchestrator（不下放 subagent）。

| # | 阶段 | Owner | 产出 | Gate |
|---|------|-------|------|------|
| 1 | Context detection | inline | `target_project` / `docs_root` / toolchain / `critical_modules` / `design_ref` | C |
| 2 | Research（可选） | analyst | `analyze/[slug].md` | A |
| 3 | Design | architect | `design-docs/[slug].md` + DEC + 可选 exec-plan / api-docs | A |
| 4 | Design confirmation | 用户 | Accept / Modify / Reject | B |
| 5 | Implementation | developer | `src/` + `tests/` + exec-plan checkbox | C |
| 6 | Adversarial testing | tester | 测试代码 + `testing/[slug].md` | C |
| 7 | Review | reviewer | 对话或 `reviews/[YYYY-MM-DD]-[slug].md` | C |
| 8 | DB review | dba | 对话或 `reviews/[YYYY-MM-DD]-db-[slug].md` | C |
| 9 | Closeout | 用户 | commit msg / PR body / follow-up issues bundle | A |

**状态图例**：⏳ 待办 · 🔄 进行中 · ✅ 完成 · ⏩ skipped · — 不适用

### 6.2 Gate 分类 A/B/C（DEC-006）

| Gate | 语义 | 触发点 | 行为 |
|------|------|--------|------|
| A | producer-pause | Stage 2 / 3 / 9 | 3 行 summary + 菜单穷举（`go` / `问:` / `调:` / `停`）+ 停止调用任何工具 |
| B | approval-gate | Stage 4 唯一 | `AskUserQuestion`（Accept / Modify / Reject）每选项带 `rationale` + `tradeoff` + 可选 `recommended` |
| C | verification-chain | Stage 1 / 5-8 | 内部自动推进；emit `🔄 X done → dispatching Y` 一行；critical_modules hit / `<escalation>` / lint+test 失败打断 |

**A 类菜单穷举原则**：所有可能动作列全；"跳过某产出" = deliberate choice 必须显式说理落盘；禁 silent default。

**architect Stage 3 末菜单变体**：`go` 必拆 `go-with-plan`（★ 推荐）/ `go-without-plan: <理由>`；后者理由落盘到 `log.md` `decide` 前缀条目。

**Stage 9 Closeout bundle 协议**：见 §2.1 末段。

### 6.3 Dispatch Mode Selection（Step 3.4）

每次 `Task` 派发前评估 `run_in_background`：

1. 用户声明（`@role bg|fg` 等）→ 遵从
2. 并行度：本 message 内 Task 调用数；单发 → `false`，并行批 ≥2 → 全部 `true`
3. 模糊 → `AskUserQuestion` fg / bg

### 6.4 Progress Monitor（Step 3.5）

仅 `run_in_background: true` 派发触发：

- `ROUNDTABLE_PROGRESS_DISABLE=1` → 全 skip
- 每派发生成独立 `DISPATCH_ID` + `PROGRESS_PATH`（`/tmp/roundtable-progress/${SESSION_ID}-${DISPATCH_ID}.jsonl`）
- `Monitor` 启动 `tail -F | jq --unbuffered | awk`（大写 F 保文件消失不退出；`fromjson?` 容错；尾部 awk 折叠**连续**重复行）
- 注入派发 prompt 4 变量：`progress_path` / `dispatch_id` / `slug` / `role`
- 前台派发 / inline 形态 / env opt-out → 整段 skip，subagent 静默 fallback

### 6.5 并行派发判定（Step 4）

4 条件**全部**满足才可并行（任一失败 → 串行）：

1. PREREQ MET
2. PATH DISJOINT
3. SUCCESS-SIGNAL INDEPENDENT
4. RESOURCE SAFE

**默认串行**；仅 4 条全满足 **且** 加速 >30% 才升并行。exec-plan checkbox 写入始终串行（orchestrator 代写防 race）。

### 6.6 决策并行（Step 4b）

适用范围 = **orchestrator 顶层 fuzzy 决策**（Size / Dispatch mode / Developer form 三点）。4 条件：

1. INPUT INDEPENDENT
2. OPTION SPACE DISJOINT
3. RESPONSE PARSABLE SEPARATELY
4. NO HIDDEN ORDER LOCK

**上限 `max_concurrent_decisions = 3`**；溢出时前 3 合并，第 4+ 串行续跑。跨问聚合回复（`都选推荐` / `all A`）与歧义重问上限（3 轮）有完整 fallback 规则（DEC-021）。Text mode 下批量渲染多 `<decision-needed id="batch-<slug>-<n>">` 块同 response emit。

### 6.7 Subagent Escalation（Step 5）

- 解析 agent final message 的 `<escalation>` JSON block
- `auto_mode=true` 先走 §Auto-pick（命中 `recommended` → auto-pick；否则 auto-halt fallback）
- `decision_mode=modal` → `AskUserQuestion`；`text` → emit `<decision-needed id="esc-<slug>-<n>">` 块
- 用户答案（或 auto-pick 决策）注入 prompt 重派**同一个** agent，scope 限 `remaining_work`

### 6.8 Phase & Audit Forwarding（Step 5b，TG/远程前端转发）

**Sticky 触发**：session inbound 含 `<channel source="<plugin>:<name>" chat_id="..." ...>` 标签 OR 该 channel reply 工具本 session 内曾调用过（永久 sticky，不按轮次衰减）。

**5 类转发事件**：

| 类 | 事件 | 格式 |
|---|------|------|
| a | Step -0/-1 pre-flight + Step 0 context 结果 + Step 1 size 判定 | `markdownv2` 结构化（粗体 + 反引号 + bullet） |
| b | A 类 producer-pause 3 行 summary + 尾段 `*Phase*` 单行进度条 | `markdownv2`；Stage 9 Closeout bundle 特例走 ``` 围栏，可拆 2-3 reply |
| c | Role completion digest（≤200 Unicode codepoints） | `markdownv2` |
| d | C 类 `🔄 X → Y` handoff + 尾段进度条 | `markdownv2` |
| e | auto_mode 4 audit 事件（`🟢 auto-go` / `🟢 auto-accept` / `🟢 auto-pick` / `🔴 auto-halt`） | 单行 markdownv2 或批量 ``` 围栏 |

**不转发**：普通对话 / FAQ / 调试输出 / 用户无决策价值的内部状态。

**Ordering**：c 独立；d+e 同 tick 合并；a+Step 1 合并。

### 6.9 Role Form Selection（Step 6b）

developer / tester / reviewer / dba **均**支持 `subagent`（默认）和 `inline`（DEC-005 + DEC-023）。research 仍 subagent-only。

**三级切换**（按序第一匹配胜出）：

1. Per-session 用户 prompt（`@role inline` / `<role> 用 inline`）
2. Per-project CLAUDE.md 的 `<role>_form_default: inline | subagent`（4 可选键）
3. Per-dispatch `AskUserQuestion`（小任务启发式：单文件 / hotfix / <2min wall time / <20k token / 单模块内 → inline recommended）

**Form → 派发路径**：
- `inline` → orchestrator `Read` `agents/<role>.md` 在主会话执行；`AskUserQuestion` 直接可用；skip Step 3.5 Progress
- `subagent` → `Task` 派发 + Progress Monitor

`auto_mode=true` 下走 §Auto-pick 通用规则。

### 6.10 §Auto-pick 通用规则（`auto_mode=true`）

| 触发点 | 事件 | 条件 |
|--------|------|------|
| A 类 producer-pause（Stage 2/3/9） | `🟢 auto-go <role> ✅` | 无条件 |
| B 类 approval-gate（Stage 4） | `🟢 auto-accept <role> design (recommended: ...)` | options 含 `recommended: true` |
| Step 5 / Step 1 / Step 6b 内部决策点 | `🟢 auto-pick <context>` | 同上 |
| Step 4b 批量 orchestrator 决策 | `🟢 auto-pick batch <batch_id>: [...]` | **所有** question 全含 `recommended`（全或全无） |
| 任一决策点无 `recommended` | `🔴 auto-halt: no recommended option at <decision_id>` | fallback 走 `decision_mode` 原渲染 |

**Stage 9 Closeout 例外**：memory `feedback_no_auto_push` / `feedback_no_auto_pr` 硬边界优先于 §Auto-pick；auto_mode 只 auto 生成 bundle，不 auto 执行 git/gh。

C 类不受 auto_mode 影响；critical_modules / tester hard regression / lint+test 失败打断保持。

### 6.11 Index / log 批处理（Step 7 / Step 8）

**shared-resource 转发原则**：agent/skill **不直接写** `INDEX.md` / `log.md`；在 final message 上报 `created:` YAML（INDEX.md 源）+ `log_entries:` YAML（log.md 源），orchestrator 聚合并 flush。

**Step 7 INDEX.md flush 触发**：
- phase gate（A 类 transition）
- C→C 过桥（单次 Read + Edit）
- Stage 9 终点

**Step 8 log.md flush 触发**（3 种）：
- Stage 9 Closeout 之前（终点 flush）
- 每次 A 类转场之前（pause-point flush，降跨 session 中断风险）
- 每次 C 类 verification-chain 交接之前

**合并规则**：同 agent 同轮多 entry 合并一条；`files:` union；`note:` 取首条；`prefix` 白名单（`analyze` / `design` / `decide` / `exec-plan` / `review` / `test-plan` / `lint` / `fix` / `fix-rootcause` / `db-review` / `faq-sink`）。

### 6.12 Orchestrator Relay Write（Step 7 子规则，DEC-017）

reviewer / tester / dba **不 Write 归档 `.md`**；orchestrator 按触发条件**代写**。

**触发条件**（任一成立即 relay）：
- reviewer / dba subagent 派发命中 `critical_modules`
- subagent final message 含 🔴 Critical finding（`## Critical` section 非空，排除占位 / emoji `🔴` + `critical` 共现）
- 用户 prompt 明示要求归档（白名单：`归档` / `落盘` / `sink` / `archive`）
- tester 触发：`critical_modules 命中 OR (size ∈ {medium, large} AND 需产出测试计划)`

**Relay contract**：正文剥 `<escalation>` + 可选 frontmatter → 作 body；orchestrator 补 frontmatter（slug / source / created / reviewer|tester 字段）；path 按角色规则；自造 `created:` + `log_entries:` YAML。**Write 失败 fail-fast**：无自动重试，final summary 顶部 `⚠️ relay Write failed: ...`，fallback 附正文原文 + 人工路径提示 + Step 8 追加 `fix` 前缀审计条目。

### 6.13 FAQ Sink（Step 0.5）

用户**直接提问**（非 `<escalation>` / 非 A 类 `问:` / 非 skill 调研）命中 roundtable 专有术语 → orchestrator 回答后**自动追加** Q&A 到 `{docs_root}/faq.md`。

- **白名单启发式**：`orchestrator` / `phase matrix` / `DEC-\d+` / `auto_mode` / `decision_mode` / `escalation` / `producer-pause` / `approval-gate` / `verification-chain` / `critical_modules` / `Resource Access` / `roundtable` / step 编号等
- **中文通用词**（`机制` / `流程` / `阶段` / `决策` / `工作流`）必须与专有术语**同句**共现
- 显式 `加入 FAQ` / `别沉淀` 可强制覆盖；**冲突解析**：`skip` 胜出
- **Jaccard 去重**（token bag-of-words，阈值 ≥ 0.7 判重复）
- A 类 menu `问:` 前缀 → 走 slug 级 FAQ（analyst report 内）；本 step 走 **global** `{docs_root}/faq.md`，两者互补

---

## 7. 制品体系

### 7.1 Artifact 链（user-facing 产出，DEC-001 §D1-D9）

```
analyst   → analyze/[slug].md
architect → design-docs/[slug].md + decision-log.md DEC（置顶/最新在前）
            可选 exec-plans/active/[slug]-plan.md、api-docs/[slug].md
developer → src/ + tests/；完成时 exec-plan active/ → completed/
tester    → tests/*（代码）；中/大任务 testing/[slug].md（orchestrator relay）
reviewer  → 对话；critical_modules / 🔴 Critical / 用户要求归档时 reviews/[YYYY-MM-DD]-[slug].md（relay）
dba       → 对话；大表 schema / 新分区 / 🔴 Critical / 用户要求归档时 reviews/[YYYY-MM-DD]-db-[slug].md（relay）
bugfix    → Tier 2 时 bugfixes/[slug].md postmortem
closeout  → 汇总 findings + commit msg / PR body / follow-up issues bundle
```

### 7.2 Wiki 层文档（orchestrator 代维护）

| 文件 | 职能 | 写入方 |
|------|------|--------|
| `{docs_root}/INDEX.md` | 6 类 artifact 导航（`### <category>` subsection） | orchestrator Step 7 批量 flush |
| `{docs_root}/log.md` | 时间索引所有文档变更条目 | orchestrator Step 8 批量 flush |
| `{docs_root}/decision-log.md` | DEC 权威源（置顶 / 最新在前 / 不删 Superseded） | architect 直写 |
| `{docs_root}/faq.md` | roundtable 机制类 Q&A 沉淀 | orchestrator Step 0.5 自动 sink |

**Minimal header 初始化**：`decision-log.md` 不存在或为空时 architect 先写 "# <项目名> 决策日志 + 引言 + `---`"，再插入首条 DEC。

### 7.3 DEC 结构规范

- **开立门槛 5 类必开**（architect Stage 2 Step 8 自问）：跨模块接口 / 改 DEC-001 D1-D9 / 新依赖 / 推翻或细化 Accepted DEC / 技术选型 or 数据模型
- **Red Flags 负例**：0 命中 5 类时的反模式清单
- **6 必填字段**：日期 / 状态 / 上下文 / 决定 / 相关文档 / 影响范围（`备选` / `理由` 可选）
- **状态字面值**：`Proposed` / `Provisional`（DEC-025 冷却窗）/ `Accepted` / `Superseded by DEC-xxx` / `Rejected`（可并列 `Refined by DEC-xxx`）
- **铁律 5**：影响范围 ≤10 行，超行移 design-doc `## 影响文件清单`
- **不回溯**：已 Accepted DEC 不改，走 Superseded 新 DEC + 旧 DEC 改 `Superseded by DEC-xxx`

---

## 8. 运行时开关

### 8.1 orchestrator 行为开关

| 开关 | 值 | 默认 | 优先级 | 职能 |
|------|----|------|-------|------|
| `auto_mode` | true \| false | false | CLI `--auto` / `--no-auto` > env `ROUNDTABLE_AUTO ∈ {1,true,on,yes}` > default | A/B/内部决策点走 §Auto-pick；C 类不受影响；Stage 9 git/gh 仍需显式 `go` |
| `decision_mode` | modal \| text | modal | CLI `--decision=...` > env `ROUNDTABLE_DECISION_MODE` > default | 选 Step 5 escalation 渲染路径（`AskUserQuestion` vs `<decision-needed>` 块） |
| `ROUNDTABLE_PROGRESS_DISABLE` | 1 | unset | env | 值为 `1` → skip Step 3.5 整段（不生成 progress_path / 不启 Monitor / 不注入 4 变量） |

**HARD-GATE**：auto_mode / decision_mode 仅从 `<roundtable-preflight>` 块（SessionStart hook 注入）或 env 直读；**不**从 Claude Code Auto Mode 系统提示推断。

### 8.2 CLAUDE.md 配置入口（target 项目）

`# 多角色工作流配置` section 声明：

- `critical_modules`（必填）：tester / reviewer 触发阈
- `设计参考`（可选）：architect 设计时横向参考仓库
- 工具链覆盖（可选）：`lint_cmd_hardcode` / `lint_cmd_density` / `lint_cmd` / `test_cmd`（三 lint 字段任一存在即合法，调用方遍历跑独立判 exit code）
- `条件触发规则`（可选）：所有角色硬约束（如"涉金额禁浮点"）
- `<role>_form_default: inline | subagent`（4 可选键）：per-project Role Form baseline（DEC-023）

---

## 9. 交叉能力矩阵

### 9.1 Role × Progress × Forwarding × Relay

| 角色 | Progress emit | Forwarding 事件类 | Orchestrator relay |
|------|--------------|-----------------|-------------------|
| analyst | — | a / b / c / e | 不 relay（直写 `analyze/`） |
| architect | — | a / b / c / e | 不 relay（直写 `design-docs/` / DEC） |
| developer | subagent 后台 emit；inline skip | c / d / e | 不 relay（直写 `src/` / `tests/`） |
| tester | 同上 | c / d / e | relay `testing/[slug].md`（中/大 + critical 触发） |
| reviewer | 同上 | c / d / e | relay `reviews/[YYYY-MM-DD]-[slug].md`（critical_modules / 🔴 / 明示触发） |
| dba | 同上 | c / d / e | relay `reviews/[YYYY-MM-DD]-db-[slug].md`（同上 + 大表 / 新分区） |
| research | 不 emit | — | 不 relay（返回 `<research-result>` 合成进 architect design-doc） |

### 9.2 Phase × Gate × Flush

| Phase | Gate | Step 7 INDEX flush | Step 8 log flush |
|-------|------|-------------------|-----------------|
| 1 Context | C | C 过桥 | C 过桥 |
| 2 Research | A | A transition | A pause-point |
| 3 Design | A | A transition | A pause-point |
| 4 Confirm | B | — | — |
| 5 Implement | C | C 过桥 | C 过桥 |
| 6 Adversarial | C | C 过桥 | C 过桥 |
| 7 Review | C | C 过桥 | C 过桥 |
| 8 DB | C | C 过桥 | C 过桥 |
| 9 Closeout | A | 终点 flush | 终点 flush |

### 9.3 Mode × 决策渲染路径

| auto_mode | decision_mode | 行为 |
|-----------|--------------|------|
| false | modal | `AskUserQuestion` 弹窗（默认） |
| false | text | emit `<decision-needed id=...>` 块；用户自由文本回复；orchestrator fuzzy 解析 |
| true | modal | §Auto-pick 命中 recommended 自动推进；skill 阶段 `AskUserQuestion` 不受 orchestrator 控（runtime 执行） |
| true | text | 同上 + text fallback 渲染（DEC-020 audit-first + N blocks） |

---

## 10. 设计参考（README 声明）

roundtable 自身设计横向参考：

- **superpowers** — `https://github.com/obra/superpowers`
- **gstack** — `https://github.com/garrytan/gstack`

roundtable 自开发走 roundtable 工作流（**递归 dogfood**）；`moongpt-harness` 为分发仓 / `roundtable` 为源码仓。

---

## 11. 开放问题清单（事实层）

以下事实层未确定项供 architect 承接（不含方案选型推荐）：

1. **`ref-density-check.sh` 未扫 `docs/analyze/` 本身**：本文档位于 `docs/analyze/`，DEC 引用密度不计入 CLAUDE.md lint_cmd_density。事实：扫描根 `ROOTS=(skills agents commands)`；含义层面本文档引用 20+ DEC 编号 / § 路径，与 DEC-029 白名单三类是否契合未做评估。
2. **`hooks/session-start` 三种输出分支**：JSON schema 分 Cursor / Claude Code / generic 三套 —— `CURSOR_PLUGIN_ROOT` / `CLAUDE_PLUGIN_ROOT` && !`COPILOT_CLI` / else；是否覆盖了 Windsurf / Copilot CLI 等其他 harness 未在文件内说明。
3. **`_detect-project-context` 执行路径**：调用方通过 `Read` 文件 inline 执行而非 `Skill` 工具激活；下划线前缀约定在某些 Claude Code 版本对 `Skill` 激活失败已观察（见文件内 Activation note），但未声明具体版本号 / 规避策略。
4. **Progress Monitor lifecycle**：Task 返回后 `tail -F` 空闲，默认任其自然过期；progress 文件依赖 OS tmpfiles 清理，plugin 不 gc —— 跨 session / 长运行环境的累积容量未声明上限。
5. **Step 4b `max_concurrent_decisions = 3`**：硬编码常量；文件内注"先保守，需要时改到 4 或 5"但无触发评估的准则（e.g. 实测多少轮后评估）。
6. **architect Stage 3 `go` fuzzy 降级 size=小 → `AskUserQuestion` 二选**：与"size=中/大 保守默认 `go-with-plan`"非对称；降级到 `AskUserQuestion` 是否受 `auto_mode` 影响未在条文内显式交代。
7. **FAQ Sink `{docs_root}/faq.md` minimal header 初始化**：`<project>` 字面值 = `basename(target_project)`；target_project 为工作空间根（无 basename 义）时的行为未声明。
8. **Stage 9 Closeout bundle 的 follow-up issues 提取源**：从 tester / reviewer / dba final message 提取 non-blocking Warning+Suggestion；subagent 以 relay 主路径交付归档 `.md` 时，final message 本身是否保留该内容（vs 只在 relay .md 中）未在 bundle 协议内澄清。

---

## 12. 迭代演进（issues / PRs 审计）

从 v0.0.1 初版（PR #1 / #3 / #4）到当前主分支（HEAD 06fddcd，v0.0.4 release + DEC-030 P1 后续）共合并 **60 个 PR**，关闭 **60+ 个 issue**。本节按主题汇总在初版之上新增/修复的能力，**只陈事实**，推荐归 architect。

### 12.1 Release 时间线

| Release | 日期 | 主要封装内容 | 关键 PR |
|---------|------|------------|--------|
| v0.0.1 | 2026-04-18 | 7 角色骨架 + INDEX.md 批量维护 + Apache-2.0 LICENSE 替换 | #1 / #3 / #4 |
| v0.0.3 | 2026-04-20 | DEC-003 → DEC-012 编排主干成型（phase gating / dispatch mode / progress / dual-form / lint orphan / 决策日志顺序）| #6 / #11 / #12 / #13 / #16 / #17 / #21 / #24 |
| v0.0.4-rc1 | 2026-04-20 | DEC-013 switchable decision mode（modal \| text）+ §3.1a TG 转发 | #34 / #44 |
| v0.0.4-rc2 | 2026-04-20 | DEC-014 bugfix 分层 + DEC-015 `--auto` + DEC-013 §3.1a 扩 5 类事件 + 多项 bug | #39 / #45 / #47 / #50 / #51-55 |
| v0.0.4-rc3 | 2026-04-21 | DEC-016 Step 4b 决策并行化 + prompt ref label prune | #56 / #58 |
| v0.0.4-rc4 | 2026-04-21 | DEC-017 reviewer/tester/dba write contract 反转 + DEC-018 relay tightening + Step 5b 格式修 + absolute path 清扫 | #64 / #69-#78 / #81 / #82 |
| v0.0.4-rc5 | 2026-04-23 | DEC-028 SessionStart hook + scripts/ 外置化 | #105 |
| v0.0.4 | 2026-04-23 | DEC-029 runtime prompt ref density 基线+回归脚本 | #109 |
| post-v0.0.4 | 2026-04-24 | DEC-023 execution form 扩 tester/reviewer/dba；DEC-024 Phase Matrix 渲染纠偏；DEC-025/026 决策日志可持续性；DEC-030 skill→orchestrator handoff 合规 | #83 / #87 / #90 / #98 / #112 / #116 |

### 12.2 按主题汇总（主题 × DEC × issue/PR 指针）

| # | 主题 | 初版状态 | 迭代新增 | 支撑 DEC | 主要 issue/PR |
|---|------|---------|---------|---------|--------------|
| T1 | 并行派发语义 | 无；串行单发 | research subagent 并行 fan-out + Step 4 四条件判定 | DEC-003 | #2 / #6 |
| T2 | Progress 事件 | 无 | JSONL schema + Monitor tail-F + 前台 skip + dedup + milestone | DEC-004 / DEC-008 | #7 / #11 / #14 / #15 / #16 |
| T3 | Role form 多态 | subagent-only | developer → +inline；后扩至 tester/reviewer/dba 三级切换 | DEC-005 / DEC-023 | #11 / #20 / #83 |
| T4 | Phase gating | 无分类 | A/B/C 三级分类 + producer-pause 菜单穷举 + approval-gate 定义 | DEC-006 | #10 / #13 / #30 / #51 |
| T5 | prompt 精简 | 全中文 / 冗长 | 骨架英文化 + 指针式引用 + label prune | DEC-009 / DEC-010 | #8 / #9 / #17 / #56 |
| T6 | lint 能力 | orphan 仅 design-docs | 扩 6 类 artifact + DEC 结构审计（L6.1-L6.5）+ exec-plan 过期 + log.md 完整性 | — | #5 / #12 |
| T7 | 决策日志 | 无顺序约定 | 置顶 + 最新在前；architect 直写目标项目；不删 Superseded | DEC-011 | #18 / #21 |
| T8 | Dispatch mode | 单一 | `run_in_background` per-Task 判定 + 3.5 Monitor 条件启动 | DEC-012 | #19 / #24 |
| T9 | Decision mode | modal-only | `modal \| text` 二选；text 渲染 `<decision-needed>` 块；CLI/env 覆盖；TG 转发 | DEC-013 | #31 / #34 / #38 / #44 |
| T10 | Bugfix 分层 | 对话报告 | Tier 0/1/2（对话 / log.md / postmortem）+ D1 双轴 + 必带回归测试 | DEC-014 | #37 / #39 / #40 / #74 / #113 / #116 |
| T11 | Auto mode | 不存在 | `--auto` + ROUNDTABLE_AUTO；§Auto-pick 通用规则；4 类 audit 事件；`no_auto_push/pr` 硬边界 | DEC-015 | #33 / #45 / #47 |
| T12 | 决策并行 | 串行 | Step 4b batch fuzzy AskUserQuestion；`max_concurrent_decisions=3`；text 批量 `<decision-needed id="batch-...">` | DEC-016 | #28 / #58 / #60 / #61 / #62 / #76 / #78 / #82 |
| T13 | Write contract | reviewer/tester/dba 直写 | 反转 → orchestrator relay 主路径；relay trigger 白名单 + frontmatter 剥离 + fail-fast 降级 | DEC-017 / DEC-018 | #23 / #53 / #59 / #64 / #65 / #66 / #67 / #69 / #72 / #73 |
| T14 | TG/远程转发 | 仅偶发 reply | §3.1a 扩 5 类事件（a/b/c/d/e）+ sticky channel + markdownv2 hybrid + auto audit | DEC-013 §3.1a / DEC-022 / DEC-024 | #38 / #44 / #48 / #50 / #63 / #71 / #77 / #79 / #81 / #87 |
| T15 | Stage 9 Closeout | 对话 summary | bundle 三段（commit / PR / follow-up）+ go-* 驱动 + `feedback_no_auto_*` 硬边界 | — | #26 / #55 |
| T16 | FAQ Sink | 无 | Step 0.5 自动追加到 `faq.md`；白名单启发式 + Jaccard 去重 + `skip` 胜出 | — | #27 / #54 |
| T17 | AskUserQuestion schema | 错配 | Option 必带 rationale/tradeoff/recommended；每派发 1 block；≥2 options | — | #25 / #36 |
| T18 | 决策日志可持续性 | 无 meta | DEC 开立门槛 5 类 + Red Flags 负例 + Provisional 冷却窗 + 铁律 5 影响范围 ≤10 行 | DEC-025 / DEC-026 | #84 / #90 / #91 / #92 / #93 / #94 / #95 / #96 |
| T19 | 引导硬化 | 无 hook | SessionStart hook + preflight.sh raw-echo 契约 + `<roundtable-preflight>` 注入 | DEC-028 | #104 / #105 |
| T20 | prompt ref 密度 | 无检查 | baseline + `scripts/ref-density-check.sh` 回归 + CLAUDE.md lint_cmd_density 强制跑 | DEC-029 | #22 / #99 / #109 / #108 / #115 |
| T21 | Skill→handoff 合规 | 同 Skill 主会话透明走 | Step 5c handoff checklist + skill final-message YAML contract + Tier 2 postmortem 纠偏 | DEC-030 | #111 / #112 / #113 / #114 / #116 |
| T22 | Artifact 治理杂项 | — | 绝对路径清扫；dba log prefix `review` → `db-review`；CLAUDE.md slim + VCS 中立 | — | #68 / #70 / #67 / #69 / #100 |
| T23 | Issue 治理规范 | 无 | P0-P3 标签 + 英文标题 + priority → 依赖 ordering | — | #41 / #42 |

### 12.3 修复类 vs 增强类分布（已合并 PR 口径）

| 类别 | 计数 | 代表 PR |
|------|-----|--------|
| 新增能力（`feat:` 前缀） | ~25 | #11 #13 #24 #34 #47 #50 #54 #55 #58 #64 #78 #83 #105 #109 #112 #116 |
| Bug 修复（`fix:` 前缀） | ~15 | #12 #21 #36 #44 #51 #52 #53 #70 #81 #87 #98 #115 |
| 文档/设计（`docs:` / `design:` 前缀） | ~15 | #6 #39 #42 #45 #56 #75 #76 #82 #100 #110 |
| Chore / release | ~5 | #35 #57 #101 #106 等 |

### 12.4 初版（v0.0.1）基线 → 当前主干增量

| 维度 | v0.0.1 | 当前主干 |
|------|-------|---------|
| 入口命令 | `workflow` 单命令 | `workflow` / `bugfix` / `lint` 三命令 |
| 角色数 | 7（部分仅对话） | 7，其中 5 agent + 2 skill，4 agent 支持 inline/subagent 双形态 |
| Gate 分类 | 无 | A（producer-pause）/ B（approval）/ C（verification）三级 |
| 决策通道 | `AskUserQuestion` 单一 | modal + text 二选 + TG forwarding + `<decision-needed>` 块 + 批量并行 |
| Progress | 无 | JSONL + Monitor + dedup + milestone + 前台 skip |
| Auto mode | 无 | `--auto` + §Auto-pick 4 触发点 + 4 类 audit 事件 + 硬边界 |
| Bugfix 流程 | 等同 workflow | Tier 0/1/2 分层 + 必带回归测试 + 设计缺陷自动中止 |
| Write 权限 | 各 agent 直写 | reviewer/tester/dba 反转为 orchestrator relay + fail-fast 降级 |
| lint | orphan 单项 | 8 检查项（含 DEC L6.1-L6.5 状态审计） |
| 引导 | 纯 prompt | SessionStart hook + preflight + `<roundtable-preflight>` |
| DEC 治理 | 无门槛 | 开立门槛 5 类 + Red Flags + Provisional 冷却 + 影响范围 ≤10 行铁律 + ref 密度回归 |
| FAQ | 无 | Step 0.5 全局 `faq.md` + slug-level analyst FAQ 互补 |
| Closeout | 口头 | 三段 bundle（commit / PR / follow-up issues）+ go-* 驱动 |

### 12.5 已关闭未合并 / deferred 项

| Issue | 状态 | 原因 |
|-------|-----|------|
| #89 | deferred | orchestrator pre-flight hardening 部分能力由 #104/#105（DEC-028）收敛；剩余分支未紧迫 |
| #88 | deferred | Phase Matrix TG 单行围栏渲染优化，#87 DEC-024 落定后非阻塞 |
| #85 / #86 | 关闭合入 #84 umbrella | 决策日志 token 优化与归档策略合并到 DEC-025/026 |
| #14 | 关闭（合入 #11 后续） | progress dedup 由 `_progress-content-policy` 覆盖 |
| #32 | 关闭合入 #51 | architect 跳 exec-plan bug 与 phase-end approval gate 缺失同属一修 |

### 12.6 未解决 / 主分支后续轨迹（截至 HEAD）

- 用户 2026-04-24 宣布大型重构启动，#94 / #107 / #114 / #117 全部关闭清 backlog（见 memory `project_roundtable_refactor_pending`）
- DEC-013 E2E 四场景（A-D）acceptance 条件待 plugin reload 后本地实跑闭环（memory `project_dec013_e2e_pending`）
- DEC-028 条件 2/3 需 `/clear` 后查 session context 是否含 `<roundtable-preflight>` 块（memory `project_dec028_pending_verification`）

---

## FAQ

本文档暂无历史追问；后续补充时追加到本节 `### Q: <摘要>` 条目，不新建不覆盖。
