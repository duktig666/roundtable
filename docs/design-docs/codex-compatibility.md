---
slug: codex-compatibility
created: 2026-05-21
status: draft
source: analyze/codex-compatibility.md
---

# roundtable 实现 Codex 兼容 — 系统设计

## Problem & Constraints

### 问题

roundtable 当前 v0.0.6 是 Claude Code 专属 plugin。`/roundtable:workflow`、`/roundtable:bugfix`、`/roundtable:lint` 三条流程及 4 个 subagent（developer/tester/reviewer/dba）+ 2 个 skill（analyst/architect）依赖 Claude Code 特有机制：

- `.claude-plugin/{plugin.json, marketplace.json}` 清单格式
- `commands/*.md` slash command
- `Skill` / `Agent` / `AskUserQuestion` / `TodoWrite` 工具名
- subagent frontmatter `tools:` 字段做工具集硬约束
- `hooks/hooks.json` 含 `${CLAUDE_PLUGIN_ROOT}` 环境变量
- `mcp__plugin_telegram_telegram__*` MCP 命名约定

目标 runtime：让 roundtable 在 **Codex CLI + Codex App** 也能跑通完整 workflow。

### 约束

1. **不破坏 Claude Code 用户路径**：现有 marketplace、安装命令、`/roundtable:workflow <task>` 显式触发体验保留
2. **不分双仓**：roundtable 单仓同时服务两 runtime（避免 drift）
3. **不做过度设计**：本次仅 Codex，Cursor/Gemini/Copilot 留 follow-up
4. **方法论核心不变**：Phase Matrix / 两段式 architect / [NEED-DECISION] 中继 / Reviewer severity 分类 / DBA 检查清单 等纯方法论原样保留
5. **subagent 上下文隔离能力不丢**：reviewer/dba 的 read-only 硬约束在 Claude 下保留 frontmatter，Codex 下靠 prose
6. **TG MCP 仅 Claude 侧**：Codex 不依赖 TG MCP，channel-aware 自动降级到终端
7. **Codex App sandbox 兼容**：closeout 阶段在 detached HEAD 下不调 `gh pr create` / `git push`

## Approach

选定方案 **A — 同仓多 manifest**（DEC-0001）：

在现有 `/data/rsw/roundtable/` 仓内加 Codex 适配层。仓库根目录同时含 `.claude-plugin/`（Claude 用）和 `.codex-plugin/`（Codex 用），核心内容（agents/、skills/、纯方法论文档）跨 runtime 共享，runtime 差异通过：

- 各自 manifest 独立维护
- skill 目录下 `references/codex-tools.md` 提供工具名映射表
- `hooks/session-start` 脚本输出协议已多 runtime 自适应（基本无需改）
- `commands/*` 迁移到 `skills/*`（Codex 下 prompts deprecated，Claude 下 skill 显式触发依然可用）

参 obra/superpowers 实证路径（v5.0.3 → v5.0.6 → v5.1.0 约 2 个月），但 roundtable 范围更小（仅 Codex，不做 Cursor/Gemini/Copilot/OpenCode），成本预估 1-2 周。

## Key Decisions

记录 10 个 Open Questions 拍板结果。每条决策含 Why + How to apply。

### DEC-0001 — 整体方案：同仓多 manifest

**决策**：选方案 A（参 §Approach）。

**Why**：业内已实证（superpowers）；成本最低（1-2 周）；Claude 用户路径完全不变；新加 runtime 时只需补一组 `.<runtime>-plugin/` + `references/` 文件，扩展性最好；不引入 core/+adapters/ 抽象层带来的边界飘移风险。

**How to apply**：所有改造点都在 roundtable 单仓内完成，不另开仓库。

### DEC-0002 — commands/* 全迁到 skills/，删 commands/

**决策**：把 `commands/{workflow,bugfix,lint}.md` 迁到 `skills/{workflow,bugfix,lint}/SKILL.md`，删 `commands/` 目录。

**Why**：

- Codex 官方 doc 明确「Custom prompts are deprecated. Use skills for reusable instructions」
- 单一来源避免双份维护
- Claude Code skill 也支持显式调用（`/roundtable:workflow` 在 Claude Code 现行版本下能解析为 skill 触发），用户体验不退化

**How to apply**：

- 新增 `skills/workflow/SKILL.md`（迁自 commands/workflow.md，frontmatter 改为 skill 格式 `name: workflow / description: ...`）
- 新增 `skills/bugfix/SKILL.md`（迁自 commands/bugfix.md）
- 新增 `skills/lint/SKILL.md`（迁自 commands/lint.md）
- 删除 `commands/` 目录
- `.claude-plugin/plugin.json` 删除 commands 引用（如有）
- `.codex-plugin/plugin.json` 写 `"skills": "./skills/"`
- README / CHANGELOG / CONTRIBUTING 更新触发方式描述

### DEC-0003 — subagent tools frontmatter：保留给 Claude，Codex 下靠 prose

**决策**：`agents/{developer,tester,reviewer,dba}.md` 的 frontmatter `tools:` 字段照旧保留。Codex 下该字段被忽略，靠 prose 写明约束。

**Why**：

- Claude 下 reviewer/dba `tools: Read, Grep, Glob, Bash`（无 Write/Edit）是**硬护栏**，roundtable 核心安全约束之一
- Codex 工具粒度不同（apply_patch + shell 替代 Read/Write/Edit/Grep/Glob），frontmatter 字段无法字面映射
- 抽象出 `permissions: read-only` 等新字段是过度设计（Claude / Codex 都不原生认识，反而要每 runtime 翻译）

**How to apply**：

- 4 个 agent 文件 frontmatter `tools:` 字段保持不动
- 每个 agent 正文 prose 加强约束语：
  - reviewer.md：「Forbidden: any write operation. In Codex runtime where the `tools:` frontmatter is not enforced, you MUST NOT call `apply_patch` or any shell command that mutates files. Read-only only.」
  - dba.md：「Forbidden: any SQL write (INSERT/UPDATE/DELETE/ALTER/DROP/TRUNCATE) and any file mutation. In Codex runtime, you MUST NOT call `apply_patch` or mutating shell.」

### DEC-0004 — AGENTS.md：文本指针 `CLAUDE.md`

**决策**：新增 `AGENTS.md`，内容仅一行字面字符串 `CLAUDE.md`（参 superpowers 同款做法）。

**Why**：

- 跟 superpowers 实证路径保持一致
- 维护成本零（不需要同步两份内容）
- Codex 读到 AGENTS.md 后会作为项目记忆字面注入；CLAUDE.md 主要 Claude 用，Codex 用户拿到 skill 主体内容已足够（workflow / bugfix / lint skill 自带流程指引）
- 不引入 build/sync 脚本复杂度

**How to apply**：

- 创建 `/data/rsw/roundtable/AGENTS.md`，内容单行 `CLAUDE.md`
- 不动 CLAUDE.md（继续作为 Claude Code 项目记忆 source of truth）
- CONTRIBUTING.md 加注：「AGENTS.md 是 Codex 用的文本指针，无需同步 CLAUDE.md 内容」

### DEC-0005 — 分发：不开新仓，单仓直装

**决策**：Codex 用户直接从 `github.com/duktig666/roundtable` 装（`codex plugin add github.com/duktig666/roundtable`）。不开 mirror 仓，不提 PR 到 `prime-radiant-inc/openai-codex-plugins`。

**Why**：

- DEC-0001 已选同仓多 manifest，根目录有 `.codex-plugin/plugin.json` 即可被 Codex 直接装
- 节省维护额外仓 + sync 脚本的成本
- 未来想推 marketplace 时随时可加（参 DEC-0006 follow-up 节）

**How to apply**：

- README 加 Codex 安装章节，示例 `codex plugin add github.com/duktig666/roundtable`
- 不创建 mirror 仓
- Claude 用户安装路径不变（`/plugin marketplace add duktig666/roundtable`）

### DEC-0006 — sync 脚本：不做

**决策**：本次不写 `scripts/sync-to-codex-plugin.sh`。

**Why**：

- DEC-0005 单仓直装，无目标仓需要同步
- 节省 rsync EXCLUDES 维护 + bootstrap 逻辑 + tests/codex-plugin-sync/ 测试套件成本
- 未来若想推 prime-radiant marketplace 再补

**How to apply**：

- 不创建 scripts/sync-to-codex-plugin.sh
- 不创建 tests/codex-plugin-sync/
- design-doc Out of Scope 节明示「sync 脚本 + prime-radiant PR 是 v0.0.8+ follow-up」

### DEC-0007 — Codex App finishing：workflow Step 5 closeout 加环境检测 + Path A handoff

**决策**：在 `skills/workflow/SKILL.md` Step 5 closeout 节加只读 git 环境检测和 Path A handoff 模式（参 superpowers `finishing-a-development-branch` Step 1.5）。

**Why**：

- Codex App workspace-write sandbox 禁 `git checkout -b` / `git push` / `gh pr create`
- closeout 是自然位置（orchestrator 职责，不该让 developer subagent 越界做）
- 不另切独立 skill（roundtable closeout 当前只十几行，单独 skill 过设计）

**How to apply**：

- `skills/workflow/SKILL.md` Step 5 closeout 前加 Step 0 环境探测：
  ```bash
  GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
  GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
  BRANCH=$(git branch --show-current)
  ```
- 决策矩阵：
  - `GIT_DIR != GIT_COMMON` 且 `BRANCH` 空 → **Path A**：跳过 `go-commit/go-pr/go-all` 选项，输出 handoff payload（commit SHA + 建议 branch name + 建议 PR title body），提示用户走 Codex App 原生「Create branch」/「Hand off to local」按钮
  - 其他情形 → 标准 4-option closeout（不变）
- handoff payload 模板示例写进 SKILL.md 正文

### DEC-0008 — TG MCP：Claude 用 TG，Codex 自动降级终端

**决策**：roundtable 现有 channel-aware 逻辑保持不变（检测 `plugin:telegram:telegram` MCP 是否加载，加载用 TG reply，否则用 AskUserQuestion / 终端）。Codex 下不强求装 TG MCP，自动走终端分支。

**Why**：

- channel-aware 检测本身就是「load 用 TG，没 load 不用」语义，跨 runtime 自然降级
- TG 是用户个人工作流（botB 与 user 私聊），Codex 用户多数无此需求
- 避免 hardcode 不同 runtime 的 TG MCP 工具名（Codex MCP 命名约定未官方文档化）

**How to apply**：

- 现有 `skills/workflow/SKILL.md`（迁自 commands/workflow.md）的 channel-aware 段落不动
- 现有 CLAUDE.md 决策协议段不动
- `skills/workflow/references/codex-tools.md` 加 TG MCP 章节，写明：
  > "Codex 下 TG 是可选。若需要，可 `codex mcp add telegram -- <command>` 自配 TG MCP server；channel-aware 检测会自动启用 TG 分支。Codex MCP 工具命名约定见 `codex /mcp` 输出。"
- README 安装节注明：Claude 用户的 TG MCP 配置不需要迁移到 Codex；roundtable 在 Codex 下默认终端模式运行

### DEC-0009 — multi_agent feature：README 软提示，相信默认值

**决策**：不强制 prereq，README 写软提示「如果 subagent 派发失败，检查 `[features].multi_agent = true`」。

**Why**：

- Codex 官方 `config-reference` 列 `[features].multi_agent` 默认 `true`
- 强制 prereq 增加用户摩擦
- hook 脚本检测 TOML 配置过重（bash 解析 TOML 麻烦，跨 runtime hook 复杂度增加）
- 失败时给 troubleshooting 路径足够

**How to apply**：

- README Codex 安装节加 Troubleshooting：
  > "如果 subagent 派发失败（例如 spawn_agent 报 unknown tool），检查 `~/.codex/config.toml` 是否含 `[features] multi_agent = true`。Codex 当前版本默认开启此特性，多数用户无需手动配置。"
- `skills/workflow/references/codex-tools.md` 写明同款诊断步骤
- 不动 hooks/session-start

### DEC-0010 — 范围：仅 Codex，其他 runtime follow-up

**决策**：本次仅做 Codex CLI + Codex App。Cursor / Gemini CLI / Copilot CLI / OpenCode 留 follow-up。

**Why**：

- scope 聚焦，1-2 周内能交付
- 测试矩阵小（2 个 Codex 入口 × 3 个 skill workflow = 6 个组合）
- 用户群明确（user 自身考虑 Codex 用，其他 runtime 尚无明确需求）
- 未来加 runtime 时复用同套 references/ 模式即可

**How to apply**：

- 仅新增 `.codex-plugin/` + `AGENTS.md` + skill 内 `references/codex-tools.md`
- 不创建 `.cursor-plugin/` / `.opencode/` / `gemini-extension.json` / `GEMINI.md`
- design-doc Out of Scope 节明示

## Architecture

### 目标文件结构（改造后）

```
roundtable/
├── .claude-plugin/                     # 保留（Claude Code 入口）
│   ├── plugin.json                     # 已有，删除 commands 引用（如有）
│   └── marketplace.json                # 已有
├── .codex-plugin/                      # 新增
│   └── plugin.json                     # Codex manifest（含 interface 块）
├── AGENTS.md                           # 新增（文本指针：单行 "CLAUDE.md"）
├── CLAUDE.md                           # 已有，不动
├── CHANGELOG.md                        # 更新 v0.0.7 entry
├── CONTRIBUTING.md                     # 更新（加 Codex 测试清单 + AGENTS.md 说明）
├── README.md / README-zh.md            # 更新（加 Codex 安装章节）
├── LICENSE
├── agents/                             # 保留
│   ├── developer.md                    # frontmatter tools 不变；正文加 Codex prose 约束
│   ├── tester.md                       # 同上
│   ├── reviewer.md                     # 同上 + 强化 read-only prose
│   └── dba.md                          # 同上 + 强化 SQL 禁写 prose
├── skills/
│   ├── analyst/
│   │   ├── SKILL.md                    # 已有
│   │   └── references/                 # 新增
│   │       └── codex-tools.md          # 新增（工具映射表）
│   ├── architect/
│   │   ├── SKILL.md                    # 已有
│   │   └── references/                 # 新增
│   │       └── codex-tools.md          # 新增
│   ├── workflow/                       # 新增（迁自 commands/workflow.md）
│   │   ├── SKILL.md                    # 含 Step 0 环境探测 + Step 5 Path A handoff
│   │   └── references/
│   │       └── codex-tools.md          # 含 TG MCP 章节 + multi_agent troubleshooting
│   ├── bugfix/                         # 新增（迁自 commands/bugfix.md）
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── codex-tools.md
│   └── lint/                           # 新增（迁自 commands/lint.md）
│       ├── SKILL.md
│       └── references/
│           └── codex-tools.md
├── commands/                           # 删除
├── hooks/                              # 保留
│   ├── hooks.json                      # Claude Code schema 不动
│   └── session-start                   # bash 脚本，确认现有多 runtime 输出协议兼容 Codex（基本无需改）
└── docs/                               # 保留（不进 Codex 视图，但单仓不排除）
    ├── analyze/codex-compatibility.md   # 已有
    ├── design-docs/codex-compatibility.md  # 本文档
    ├── exec-plans/active/codex-compatibility.md  # 待 phase 4 产出
    ├── roundtable.md / usage.md / case-study-rewrite.md / pre.md
    └── INDEX.md（由 lint skill 重建）
```

### 跨 runtime 行为对照表

| 维度 | Claude Code | Codex CLI / App |
|---|---|---|
| Plugin manifest | `.claude-plugin/plugin.json` | `.codex-plugin/plugin.json`（含 interface 块）|
| 项目记忆 | CLAUDE.md | AGENTS.md（内容："CLAUDE.md" 字面）|
| 触发 workflow | `/roundtable:workflow <task>` slash | `/skills` 列表或描述意图自动调 workflow skill |
| 触发 bugfix | `/roundtable:bugfix <task>` | 同上，调 bugfix skill |
| 触发 lint | `/roundtable:lint` | 同上 |
| analyst / architect 调用 | `Skill(skill: "roundtable:analyst")` | skill 自然加载，直接跟指令 |
| Subagent 派发 | `Agent(subagent_type: "roundtable:developer")` | `spawn_agent(task_name=..., message=...)` + `wait_agent` + `close_agent` |
| 决策提问 | `AskUserQuestion` | `request_user_input`（schema 几乎 1:1）|
| Todo 跟踪 | `TodoWrite` | `update_plan`（schema 简化）|
| Subagent tools 隔离 | frontmatter `tools:` 字段硬约束 | prose 约束（reviewer/dba prose 加强禁写语）|
| 文件读写 | Read / Write / Edit / Grep / Glob / Bash | apply_patch + shell |
| TG MCP 广播 | `mcp__plugin_telegram_telegram__reply` | 默认不用；channel-aware 检测到无 TG MCP → 走终端分支 |
| Closeout（commit/PR）| 全套 4-option menu（go-commit / go-pr / go-all / stop）| 同上 + Codex App detached HEAD 下走 Path A handoff payload |
| SessionStart hook | hooks/hooks.json + `${CLAUDE_PLUGIN_ROOT}` | `.codex-plugin/plugin.json` `hooks` 字段指向 hooks/session-start；Codex 注入 `CLAUDE_PLUGIN_ROOT` legacy 兼容名，脚本现有逻辑可复用 |
| multi_agent feature | N/A | `~/.codex/config.toml` `[features] multi_agent = true`（默认 true）|

### 调用流程（以 /roundtable:workflow 为例，跨 runtime）

```
User input
   │
   ▼
┌────────────────────────────────────────┐
│  Claude Code: /roundtable:workflow ... │
│  Codex: 描述意图 / /skills 选 workflow  │
└────────────────────────────────────────┘
   │
   ▼
skills/workflow/SKILL.md（同一份内容）
   │
   ▼
Step 1: 读 SessionStart hook 注入的 docs_root
Step 2: Phase Matrix
Step 3: 决定 skip-list
   │
   ▼
Phase 1: Skill(roundtable:analyst)            ←─ Claude
         或 skill 自然调用 analyst            ←─ Codex
   │
   ▼
Phase 2/4: Skill(roundtable:architect)         ←─ Claude
           或 skill 自然调用 architect         ←─ Codex
   │
   ▼
Phase 3/5: User gate（accept/modify/reject）
   │
   ▼
Phase 6-9: Agent(subagent_type: ...)           ←─ Claude（4 个角色）
           或 spawn_agent + wait_agent          ←─ Codex（同 4 个角色，prose 约束）
   │
   ▼
Step 5: Closeout
        - 环境探测（GIT_DIR / GIT_COMMON / BRANCH）
        - Path A（Codex App detached HEAD）→ handoff payload
        - 其他 → 4-option menu
```

## Risks & Mitigations

### R1 — Claude Code skill 显式触发语法变化

**风险**：DEC-0002 把 `commands/*` 迁到 `skills/*`。Claude Code 用户原本 `/roundtable:workflow <task>` 显式触发，迁移后语法可能变（现行 Claude Code 是否支持 `/<plugin>:<skill>` 调用 skill？需验证）。

**缓解**：

- developer 实施时第一步验证 `/roundtable:workflow` 在 Claude Code 下仍能解析为 skill 调用
- 若不兼容，临时回退方案：`commands/*` 保留为薄壳，正文一行 `Skill(skill: "roundtable:workflow", args: $ARGUMENTS)`
- 验收清单加：「Claude Code 下 `/roundtable:workflow <任务>` 能成功启动 workflow」

### R2 — Codex MCP 工具命名实测后才能确定

**风险**：DEC-0008 channel-aware 自动降级解决了 Claude 侧，但 Codex 用户若装 TG MCP，工具名仍未知。

**缓解**：

- references/codex-tools.md 留 TG MCP 章节占位，写明「Codex 下 TG 是可选；工具名见 `codex /mcp` 输出」
- 本次范围内不解决 Codex 下 TG 集成（DEC-0008 已声明 Codex 不强求 TG）
- 标 Open Question 留 follow-up：若未来 Codex 用户需要 TG，再补章节

### R3 — multi_agent 默认值版本飘移

**风险**：DEC-0009 信任默认值 `true`，但不同 Codex build 默认可能不同。用户首次 spawn_agent 失败体验差。

**缓解**：

- README + references/codex-tools.md 写明 troubleshooting 步骤
- 错误信息引导用户改 config.toml
- 监测 GitHub Issues，若实际报告频次高再升级为 prereq

### R4 — Codex 子 agent 共享 filesystem，与 Claude Agent 行为相同但需验证

**风险**：Claude `Agent` 工具开 subagent 时 context 隔离 + filesystem 共享。Codex `spawn_agent` 同样设计，但 Codex App sandbox 下 subagent 是否能正常读写 `<docs_root>/exec-plans/active/<slug>.md` 等 roundtable 工作文件需实测。

**缓解**：

- developer phase 加 e2e 测试：Codex CLI 下派 developer subagent 完成一个 toy 任务（read exec-plan、改 src/、勾 checkbox），验证文件能正常读写
- Codex App sandbox 下补类似测试

### R5 — Codex hook 加载需要 `plugin_hooks` feature

**风险**：`.codex-plugin/plugin.json` 的 `hooks` 字段要 `[features].plugin_hooks = true` 才启用。该 feature 默认值未明（analyst §C.5）。

**缓解**：

- README troubleshooting 节加：「如果 SessionStart 注入的 Roundtable context 缺失，检查 `[features].plugin_hooks = true`」
- references/codex-tools.md 同款诊断步骤

### R6 — SessionStart hook stdout schema 跨 runtime 一致性未实测

**风险**：roundtable 现 `hooks/session-start:42-59` 输出 `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":...}}`，与 Codex hook stdout schema（analyst §C.5）字段名一致，理论上 Codex 直接吃。但未实测。

**缓解**：

- developer 实施时第一步本地起 Codex + 装 roundtable，验证 SessionStart 注入的 Roundtable context 能被 skill 读取
- 若不兼容，hooks/session-start 加 Codex 专用分支输出 schema

### R7 — Claude 用户从 `commands/*` 迁到 `skills/*` 后历史 muscle memory

**风险**：现 Claude 用户已习惯 `/roundtable:workflow <task>`，迁移后即使语法兼容，文档/教程需大量更新。

**缓解**：

- README / README-zh / usage.md 重写触发说明
- CHANGELOG v0.0.7 entry 明示 BREAKING CHANGE（如有）+ migration note
- 迁移期保留 1 个版本兼容（如果 `commands/*` 留薄壳的话，参 R1 缓解）

## Acceptance Criteria

design-doc → exec-plan → developer/tester/reviewer 完成后，需验收：

1. **Claude Code 路径**：
   - 现有 user 在 Claude Code 下安装 roundtable，能用 `/roundtable:workflow <task>`（或语法变体）启动完整流程
   - 4 个 subagent + 2 个 skill 派发正常
   - reviewer/dba frontmatter `tools:` 仍生效（无 Write/Edit）
   - TG MCP 加载时 phase 广播 + decision prompt 走 TG reply

2. **Codex CLI 路径**：
   - `codex plugin add github.com/duktig666/roundtable` 装上
   - `/skills` 列表能看到 workflow / bugfix / lint / analyst / architect
   - 描述意图启动 workflow，能跑通 analyst → architect → developer → tester → reviewer 全链路
   - subagent 用 spawn_agent/wait_agent/close_agent
   - 决策点用 request_user_input 弹选项
   - 文件读写用 apply_patch + shell
   - SessionStart hook 注入 Roundtable context 能被 skill 读到
   - TG 广播自动降级到终端模式

3. **Codex App 路径**：
   - 在 Codex App 装上 plugin（参 plugin install UI）
   - 在 App-managed worktree（detached HEAD）下启动 workflow
   - phase 6 developer subagent 能在 sandbox 内 commit
   - phase 5 closeout 检测到 detached HEAD → 输出 handoff payload 而非 4-option menu

4. **跨 runtime 共通**：
   - `/roundtable:lint`（或等价 skill 调用）能重建 docs/INDEX.md
   - bugfix 流程在两 runtime 都能跑通
   - reviewer / dba 不能动 src（Claude 靠 frontmatter，Codex 靠 prose）

## Out of Scope（本次不做，留 follow-up）

1. **Cursor / Gemini CLI / Copilot CLI / OpenCode 适配**（DEC-0010）：本次仅 Codex，其他 runtime 走同套 `references/<platform>-tools.md` 模式可后续加
2. **scripts/sync-to-codex-plugin.sh 自动同步**（DEC-0006）：单仓直装暂不需要；未来推 prime-radiant marketplace 时再补
3. **`prime-radiant-inc/openai-codex-plugins` PR**（DEC-0005）：单仓直装足够，marketplace 曝光暂不追
4. **AGENTS.md 全量同步 CLAUDE.md 内容**（DEC-0004）：本次只做文本指针；未来若发现 Codex 用户体验显著降级再升级
5. **multi_agent / plugin_hooks feature 自动检测**（DEC-0009 + R5）：本次仅 README 软提示；未来若 issue 频发再考虑 hook 自动诊断
6. **Codex 下 TG MCP 集成**（DEC-0008 + R2）：本次仅 Claude 走 TG，Codex 终端降级；未来 Codex 用户有 TG 需求再补章节
7. **Codex 工具粒度差异的进一步抽象**（如 Read/Write/Edit → apply_patch 的语义映射文档）：本次靠 references/codex-tools.md 表格简单映射；深入抽象未来需要时再做

---

**Status**: draft - 等用户 confirm 后进入 exec-plan 阶段
