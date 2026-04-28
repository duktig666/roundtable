# Roundtable 全面重构 — 极简轻量化

> 仓库内执行计划文件。完整方案来源：本地 plan `/root/.claude/plans/tranquil-humming-graham.md`。

## Context

Roundtable 是基于 Claude Code 插件系统的多角色工作流（analyst → architect → developer → tester → reviewer → dba）。当前实现已积累严重 token 浪费与跨文件重复样板：

- agents 5 个 + skills 2 个 + commands 3 个 = **2200+ 行 prompt**
- decision-log.md 882 行、log.md 766 行、workflow.md 567 行
- 每个 agent 都重复 Execution Form / Resource Access / Escalation / Progress 4 套表
- 双模式 (subagent/inline) + 双决策模式 (modal/text) + 双 FAQ 路径，复杂度叠加
- design-doc / decision-log / log / faq / INDEX 五重文档机制相互引用

**目标**：抛掉历史包袱，按"最少代码解决问题"基线重写。token 用量预期下降 60% 以上，prompt 全英文，用户产出文档保持中文。

## 关键决策

| # | 项 | 决策 |
|---|---|---|
| 1 | 角色载体 | analyst / architect = **skill**（主会话，可 AskUserQuestion）；developer / tester / reviewer / dba = **subagent**（独立上下文）|
| 2 | decision-log.md | **完全删除**。架构决策直接写在对应 exec-plan 的"关键决策"小节里，跟随 exec-plan 一起归档；无独立日志、无跨文件引用 |
| 3 | log.md / faq.md / INDEX.md | log 删 / faq 删 / INDEX 保留但**只在 lint 时重建** |
| 4 | AskUserQuestion | 保留，简化（TG 渲染由 channel hook 自己处理，skill 不再写 markdownv2 分支） |
| 5 | doc_root 注入 | **改用 SessionStart hook 一次性注入**（标准 JSON `additionalContext` 协议，用户不可见）；删除 `_detect-project-context.md` |
| 6 | gstack 六问 | 保留 2 必须 + 4 按需，内联到 analyst SKILL ≤10 行 |
| 7 | workflow / bugfix | 保留双 command（不合并） |
| 8 | Phase Matrix | 保留，精简到 ≤30 行表格，内嵌 workflow.md |
| 9 | 语言 | prompt（agents/skills/commands/hooks）全英文；用户产出（analyze / exec-plans / testing / reviews）中文 |
| 10 | progress / escalation | **全部删除**。subagent 完成后返回 markdown 文本；如需决策直接在返回文本写 `[NEED-DECISION] <topic>: <options>`，主会话 grep 关键字后唤起 AskUserQuestion。无 Monitor，无 JSON schema |
| 11 | design-docs 机制 | **整个删除**。architect 直接产出 exec-plan（一文件含问题陈述 + 方案 + 步骤 + 风险），无独立 design-doc |
| 12 | research agent | **删除**。architect 调研直接调用 general-purpose Agent 并行 |
| 13 | agent/skill 模板 | 不指定 `model:`，继承会话模型 |

## 最终目录结构

```
roundtable/
├── .claude-plugin/
│   ├── plugin.json                    # 升 v0.1.0
│   └── marketplace.json
├── agents/                            # 4 个，每个 ~40 行
│   ├── developer.md
│   ├── tester.md
│   ├── reviewer.md
│   └── dba.md
├── skills/                            # 2 个 skill，每个 ~80 行
│   ├── analyst/SKILL.md
│   └── architect/SKILL.md
├── commands/                          # 3 个
│   ├── workflow.md                    # ~120 行（含 Phase Matrix）
│   ├── bugfix.md                      # ~50 行
│   └── lint.md                        # ~60 行（重建 INDEX.md）
├── hooks/
│   ├── hooks.json
│   └── session-start                  # bash：注入 docs_root + project_id
├── docs/                              # 用户产出（中文）
│   ├── INDEX.md                       # lint 自动生成
│   ├── onboarding.md                  # 5 分钟上手
│   ├── analyze/<slug>.md              # analyst 产出
│   ├── exec-plans/active/<slug>.md    # architect 产出 + developer 勾选
│   ├── exec-plans/completed/          # 完工归档
│   ├── testing/<slug>.md              # tester 产出
│   ├── reviews/<YYYY-MM-DD>-<slug>.md # reviewer / dba 产出
│   └── bugfixes/<slug>.md             # tier 2 postmortem（仅严重 bug）
├── CLAUDE.md                          # 项目内规则（slim）
├── README.md / README-zh.md
├── CHANGELOG.md / CONTRIBUTING.md / LICENSE
```

**删除清单：**
- `agents/research.md`
- `skills/_detect-project-context.md`
- `skills/_progress-content-policy.md`
- `docs/decision-log.md`、`docs/log.md`、`docs/log.md.progress`、`docs/faq.md`
- `docs/legacy-multi-role-workflow.md`、`docs/migration-from-local.md`、`docs/claude-md-template.md`
- `docs/design-docs/`（整个目录，26 个文件）
- `docs/progress/`（整个目录）
- `scripts/ref-density-check.sh`、`scripts/ref-density.baseline`

历史文件用 `git mv` 归档到 `docs/_archive/`，不物理删除（保留 git history 可追溯）。

## 核心组件规格

### 1. SessionStart hook

**`hooks/session-start`**（bash，~40 行）：
1. 优先读 `ROUNDTABLE_DOCS_ROOT` 环境变量；命中则直接 emit
2. 否则向上找最近的 `docs/` 或 `documentation/` 目录
3. 找不到则标记 `status: needs-init`，让 command 启动时 AskUserQuestion 询问
4. 必须用标准 SessionStart hook JSON 协议（不能 raw stdout）：

   ```bash
   cat <<JSON
   {
     "hookSpecificOutput": {
       "hookEventName": "SessionStart",
       "additionalContext": "Roundtable context:\ndocs_root: /abs/path/to/docs\nproject_id: <slug>\nstatus: ok"
     }
   }
   JSON
   ```

   Claude Code 把 `additionalContext` 注入会话作为系统上下文（**用户不可见**）。skill / command 通过自然语言读取 docs_root / project_id。**不使用 HTML 风格标签**。

**`hooks/hooks.json`**：仅 `SessionStart` 一个 hook，触发 `startup|clear|compact`，async=false。

### 2. Agents 通用模板（~40 行/文件，全英文）

```markdown
---
name: <role>
description: <one sentence — when orchestrator should dispatch this agent>
tools: Read, Write, Edit, Bash, Grep, Glob, Agent  # dba/reviewer 去 Write/Edit
---

# <Role>

<2-3 sentence role definition>

## Inputs
- exec-plan path (passed by orchestrator)
- docs_root (from session start context)

## Outputs
- <role-specific output path>
- final return text to orchestrator

## How to work
1. Read exec-plan
2. <role-specific 2-3 steps>
3. Update exec-plan checkboxes if applicable
4. Return short markdown summary

## When you need a decision
Print exactly one line in your return text:
`[NEED-DECISION] <topic> | options: A) <…> B) <…> C) <…>`
Do not block — orchestrator parses this and asks the user.

## Forbidden
- Modifying CLAUDE.md or files outside docs_root + project src
- Writing the exec-plan body (architect's job; only tick checkboxes)
```

Role-specific 部分各自 ≤15 行。

**取消项**：Execution Form 切换、Resource Access 矩阵、Escalation JSON schema、Progress Reporting policy 全部不要。

### 3. Skills（analyst / architect，~80 行/文件，全英文）

**`skills/analyst/SKILL.md`**：
- frontmatter: `name`, `description` — 不指定 model
- inputs: user request, docs_root（from session start context）
- output: `docs/analyze/<slug>.md`（中文）
- workflow:
  1. read context, identify task type
  2. apply 六问框架（mandatory 2: failure mode / 6-month tech-debt; conditional 4: pain point / users & journey / minimum viable / ≥2 competitor refs — explicit "skip: <reason>" if not applicable）
  3. for unresolved decisions, call AskUserQuestion (batch independent decisions)
  4. write report; append FAQ section at file end if user follows up
- 内联 六问 ≤10 行
- 不写 TG 分支（channel hook 处理）

**`skills/architect/SKILL.md`**：
- frontmatter — 不指定 model
- inputs: analyst report (optional) + user goal
- output: `docs/exec-plans/active/<slug>.md`（中文，含：问题陈述 / 方案 / 步骤清单 / 风险 / 关键决策）
- workflow:
  1. parallel research via general-purpose Agent (max 3, only if technical uncertainty)
  2. design → AskUserQuestion (batch) → user FAQ → user confirm
  3. write exec-plan with checkbox steps
  4. user confirm before handoff to developer

**通用极简原则**：
- 不再写 AskUserQuestion 完整 schema 文档
- 不再写 active channel forwarding（channel hook 处理）
- 不再写 decision_mode / auto_mode / DEC-013 / DEC-023 等内部代号

### 4. Commands

**`commands/workflow.md`**（~120 行，全英文）：

```markdown
---
description: Run multi-role workflow
argument-hint: [task description or issue #]
---

# /roundtable:workflow

Read docs_root + project_id from session start additionalContext. If status=needs-init, AskUserQuestion to set docs_root.

## Phase Matrix

| # | Role             | Output                                  | Optional? |
|---|------------------|-----------------------------------------|-----------|
| 1 | analyst (skill)  | docs/analyze/<slug>.md                  | yes (small task) |
| 2 | architect (skill)| docs/exec-plans/active/<slug>.md       | no |
| 3 | user             | confirm exec-plan                       | no |
| 4 | developer        | src/, tests/, exec-plan checkboxes      | no |
| 5 | tester           | docs/testing/<slug>.md                  | yes |
| 6 | reviewer         | docs/reviews/<date>-<slug>.md           | yes |
| 7 | dba              | docs/reviews/<date>-db-<slug>.md        | yes (DB only) |
| 8 | user             | closeout, commit / PR                   | no |

## How orchestrator runs

1. Determine task slug + skip-list (small task may skip 1, 5, 6).
2. Run phases sequentially. Skill phases (1-2) execute in main session.
3. Subagent phases (4-7): dispatch via Agent tool, pass exec-plan path + docs_root.
4. After each subagent returns, scan return text for `[NEED-DECISION]` lines. If found, AskUserQuestion the user, append answer to exec-plan, re-dispatch if needed.
5. After phases 2 and 3, terminal pause for user confirmation (3-line summary + Accept/Modify/Reject).
6. After phase 7, prompt user to commit/PR (per repo's CLAUDE.md auto-driving rules).

## Forbidden
- Skipping user confirmation on phase 3
- Auto-running git push / merge
```

**`commands/bugfix.md`**（~50 行）：跳过 phase 1-3，直接 developer subagent，必须写回归测试。Tier 2 严重 bug 写 `docs/bugfixes/<slug>.md`。

**`commands/lint.md`**（~60 行）：
- 读 docs_root，扫描 docs/<sub>/*.md
- 重建 `docs/INDEX.md`（grep filename + first heading + 分类目录）
- 检查 exec-plan 之间的相互链接是否有效
- 检查 active exec-plan 是否长期未更新（>30 天提示归档）
- 输出问题清单到终端，不自动修复

### 5. 架构决策记录（不再有独立 decision-log.md）

架构决策直接写在对应 exec-plan 文件的 "关键决策" 小节里，跟随 exec-plan 一起从 active/ 移到 completed/ 归档。无跨文件引用、无 DEC-id、无 Superseded 状态机。后续任务如需翻历史决策，grep `exec-plans/` 即可。

### 6. CLAUDE.md slim（roundtable 自身）

slim 到 ~50 行：
- 项目简介（plugin、4 agents + 2 skills + 3 commands）
- 语言策略（prompt 英文 / docs 中文 / 用户回答中文）
- 编码原则继承自父 CLAUDE.md
- 工具链：lint_cmd = `/roundtable:lint`；test_cmd = dogfood `/roundtable:workflow`
- 删除：critical_modules 表、conditional triggers 表、所有 DEC-xxx 隐式引用

## 步骤清单

- [x] Step 0: 方案落地仓库 + main 切换 + 新分支
- [ ] Step 1: Hook 改造（写新 session-start，删 `_detect-project-context.md`，验证 additionalContext 注入）
- [ ] Step 2: Agents 重写（4 文件英文化、极简化、删 escalation JSON、删 research agent）
- [ ] Step 3: Skills 重写（analyst / architect 去掉 TG 渲染分支与决策模式代号）
- [ ] Step 4: Commands 重写（workflow / bugfix / lint，Phase Matrix 精简，lint 接管 INDEX 重建）
- [ ] Step 5: Docs 清理 + CLAUDE.md slim（git mv 归档到 _archive/，跑 lint 重建 INDEX）
- [ ] Step 6: dogfood 验证 + PR

## 风险与回退

- **风险 1**：删除大量历史文件后链接失效 → `git mv` 归档到 `docs/_archive/`，保留 git history 可追溯
- **风险 2**：subagent 不再用 Monitor，长任务无中间反馈 → 接受，用户可中断；如反馈迫切再加回（门槛：先实战证明缺失）
- **回退**：所有改动在 `refactor/minimal-rewrite` 分支，必要时 `git revert` 整个 commit 序列；不污染 main

## TG 同步规则

- 触发节点：每 step 完成 / 重大异常 / 需要决策
- 不同步：常规进度（"开始读 X 文件"）、内部权衡
- 格式：每条 ≤2 行，重大决策附 plan 路径
- chat_id: 6183186721 (DM)

## Verification

每步重写后：
1. `claude --plugin-dir /data/rsw/roundtable` 启动验证 plugin 加载无错误
2. 在测试项目跑 `/roundtable:workflow "add a /health endpoint"`：
   - 验证 SessionStart hook 通过 `additionalContext` 注入 docs_root
   - 验证 analyst skill 调用 AskUserQuestion 正常
   - 验证 architect skill 产出 exec-plan 写到 `docs/exec-plans/active/`
   - 验证 developer subagent 能读取 exec-plan 并勾选 checkbox
   - 验证 `[NEED-DECISION]` 关键字被主会话识别
3. 跑 `/roundtable:bugfix "issue #123"` 验证跳过 1-3 阶段
4. 跑 `/roundtable:lint` 验证 INDEX.md 重建 + 孤儿引用检查
5. token 用量对比：重构前 vs 重构后跑同一任务，应至少下降 60%
