---
slug: codex-compatibility
created: 2026-05-21
source: design-docs/codex-compatibility.md
status: active
---

# roundtable Codex 兼容 — 执行计划

## Steps

### P0 — Pre-flight 验证（R1/R6 风险消除）

- [⏩] **P0.1** 验证 Claude Code 下 `/<plugin>:<skill>` 触发语法（R1 关键）— deferred to tester phase（本会话无法重启 Claude）；采用 safe default（commands/* 保留薄壳）
  - 操作：在当前 Claude Code session（已装 roundtable v0.0.6）下，临时把 `commands/workflow.md` 重命名为 `skills/workflow-test/SKILL.md`（frontmatter 改 `name: workflow-test`），重启 session，确认 `/roundtable:workflow-test` 或 skill 显式调用 syntax 能正确触发
  - 验收：明确「Claude Code skill 显式触发是否支持 `/<plugin>:<skill>` 语法」结论
  - 失败回退：若不支持，commands/* 保留为薄壳（一行 `Skill(skill: "roundtable:workflow", args: $ARGUMENTS)`），DEC-0002 修订记入 Change Log
  - 输出：在本 exec-plan Change Log 写明结论

- [⏩] **P0.2** 验证 Codex 下 `hooks/session-start` stdout schema 兼容性（R6）— deferred to tester phase（本会话无 Codex 安装）
  - 操作：本地装 Codex（若未装）；写一个最小 `.codex-plugin/plugin.json` 引用 `hooks/session-start`；在 Codex session 启动时观察 Roundtable context block 是否被注入主提示
  - 验收：「Codex 能读到 docs_root / project_id / status 字段」
  - 失败回退：hooks/session-start 加 Codex 专用输出分支
  - 输出：在 Change Log 写实测结果

- [⏩] **P0.3** 验证 Codex subagent 文件 IO 行为（R4）— deferred to tester phase（本会话无 Codex 安装）
  - 操作：装最小 Codex plugin + spawn_agent 调一个 toy subagent，让它读 docs/某文件、写 docs/某测试文件、勾选 checkbox
  - 验收：「Codex spawn_agent 子上下文能正常读写 docs/ 下文件」
  - 失败回退：若有 sandbox 限制，发现后调整 P5 / P7 测试范围
  - 输出：Change Log 写明 spawn_agent filesystem 共享实测结果

### P1 — Codex 基础设施

- [x] **P1.1** 创建 `.codex-plugin/plugin.json`
  - 字段：name="roundtable"; version="0.0.7"; description; author; homepage; repository; license; keywords; `"skills": "./skills/"`; `"hooks"` 字段指向 hooks/session-start（4 种形态择优，建议 inline obj 形态）；完整 `interface` 块（displayName="Roundtable" / shortDescription / longDescription / developerName="duktig666" / category="Coding" / capabilities=["Interactive","Read","Write"] / defaultPrompt=["Run the multi-role workflow on this task","Apply a quick bug fix workflow","Lint documentation index"] / brandColor / composerIcon / logo / screenshots）
  - 验收：JSON valid；Codex 能读且不报 manifest 错
  - 提示：assets/ 目录下补 logo + composerIcon 资源（可临时占位，发版前完善）

- [x] **P1.2** 创建 `AGENTS.md`（仓库根目录）
  - 内容：单行 `CLAUDE.md`
  - 验收：文件存在，内容仅一行

- [⏩] **P1.3** 确认 hooks/session-start 在 Codex 下输出 schema 兼容（P0.2 已验证）— P0.2 deferred；现有脚本 stdout 已是 `additionalContext` 字段，与 design-doc §C.5 对齐，留待 tester phase 实测
  - 若 P0.2 失败：加 Codex 专用 stdout 分支（探测 PLUGIN_ROOT 但无 CLAUDE_PLUGIN_ROOT 时输出 Codex schema）
  - 若 P0.2 通过：本步骤 ⏩ skipped

### P2 — commands/* 迁 skills/*

- [x] **P2.1** 创建 `skills/workflow/SKILL.md`
  - 内容：迁自 `commands/workflow.md`，frontmatter 改为 skill 格式（`name: workflow` / `description: Run the multi-role workflow...`）
  - 正文保持 Phase Matrix + Step 1-5 不变
  - 验收：SKILL.md 包含原 commands/workflow.md 全部 phase 逻辑；frontmatter valid

- [x] **P2.2** 创建 `skills/workflow/references/codex-tools.md`
  - 内容：工具映射表（Skill/Agent/AskUserQuestion/TodoWrite/Read/Write/Edit/Bash/Grep/Glob → Codex 等价）；TG MCP 章节（Codex 下可选 + 终端降级说明）；multi_agent feature troubleshooting；spawn_agent 用法示例
  - 验收：文件存在，按 superpowers `references/codex-tools.md` 模板写

- [x] **P2.3** 创建 `skills/bugfix/SKILL.md` + `references/codex-tools.md`
  - 迁自 commands/bugfix.md；references/ 内容简化版（仅相关工具）
  - 验收：文件存在；frontmatter valid

- [x] **P2.4** 创建 `skills/lint/SKILL.md` + `references/codex-tools.md`
  - 迁自 commands/lint.md
  - 验收：同上

- [x] **P2.5** 删除 `commands/` 目录 — **采用 safe default**：保留 commands/{workflow,bugfix,lint}.md 为薄壳（一行 `Skill(...)`），DEC-0002 in-flight 修订
  - 操作：`rm -rf commands/`
  - 视 P0.1 结论：若 Claude `/<plugin>:<skill>` syntax 不兼容 commands→skill 直接迁移，本步骤改为「保留 commands/* 为薄壳，正文一行 `Skill(skill: "roundtable:<name>", args: $ARGUMENTS)`」

- [x] **P2.6** 更新 `.claude-plugin/plugin.json`
  - 若有 commands 引用，删除（commands/* 默认按目录约定加载，可能不需要 manifest 显式声明）
  - 加 skills 配置（如有显式字段需要）
  - 验收：JSON valid；`/plugin install` 仍能装上

### P3 — agent prose 加强（DEC-0003）

- [x] **P3.1** `agents/reviewer.md` 正文加 Codex 禁写 prose
  - 在「## Forbidden」节加：
    ```
    In Codex runtime where the `tools:` frontmatter is not enforced, you MUST NOT call `apply_patch` or any shell command that mutates files. Read-only only. The orchestrator will reject any review report that includes file mutations.
    ```
  - 验收：reviewer.md 修改完，frontmatter `tools:` 字段未动

- [x] **P3.2** `agents/dba.md` 正文加 SQL 禁写 + 文件禁写 prose
  - 类似 reviewer，额外强调 SQL writes (INSERT/UPDATE/DELETE/ALTER/DROP/TRUNCATE) MUST NOT execute via shell or any MCP
  - 验收：dba.md 修改完

- [x] **P3.3** `agents/developer.md` + `agents/tester.md` 正文加 Codex 工具映射说明（可选）
  - 加一小节：「Codex runtime note: Read 对应 shell `cat`/`rg`，Write/Edit 对应 `apply_patch`，Bash 对应 shell。工具粒度差异，但语义一致。」
  - 验收：两 agent 文件更新

### P4 — analyst / architect skill 加 references/

- [x] **P4.1** 创建 `skills/analyst/references/codex-tools.md`
  - 内容：analyst 用到的工具映射（AskUserQuestion → request_user_input；Read/Bash/WebFetch/WebSearch 在 Codex 下等价）；TG channel-aware 段落映射
  - 验收：文件存在

- [x] **P4.2** 创建 `skills/architect/references/codex-tools.md`
  - 内容：architect 用到的工具映射（Skill / Agent / AskUserQuestion → spawn_agent / wait_agent / request_user_input）；channel-aware 决策协议在 Codex 下的等价
  - 验收：文件存在

### P5 — workflow skill 加 Codex App finishing（DEC-0007）

- [x] **P5.1** `skills/workflow/SKILL.md` Step 5 closeout 前加 Step 0 环境探测
  - 在 Step 5 节前插入：
    ```bash
    GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
    GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
    BRANCH=$(git branch --show-current)
    ```
  - 决策矩阵：
    - `GIT_DIR != GIT_COMMON` 且 `BRANCH` 空 → **Path A**（Codex App detached HEAD）
    - 其他 → 标准 4-option closeout
  - 验收：SKILL.md 含环境探测段 + 决策矩阵描述

- [x] **P5.2** 加 Path A handoff payload 模板
  - 内容：commit SHA + 建议 branch name（基于 slug）+ 建议 PR title body（基于本次任务）+ 提示用户走 Codex App 「Create branch」/「Hand off to local」按钮
  - 验收：Path A 模板含 4 个字段；workflow.md 末尾有完整模板示例

### P6 — 文档更新

- [x] **P6.1** `README.md` + `README-zh.md` 加 Codex 安装章节
  - Codex 安装节：`codex plugin add github.com/duktig666/roundtable`
  - Troubleshooting 节：multi_agent + plugin_hooks feature 检查 + TG MCP 可选说明
  - 整体调整：触发方式描述（`/roundtable:workflow` Claude；skill 自然加载 Codex）
  - 验收：两 README 都加 Codex 章节；marketplace 安装说明保留

- [x] **P6.2** `CONTRIBUTING.md` 加 Codex 本地测试清单
  - 新增章节「Codex 本地测试」：装 Codex CLI / 装 plugin / 跑 /skills / 跑 workflow / spawn_agent 验证
  - AGENTS.md 说明：「Codex 用文本指针，无需同步 CLAUDE.md 内容」
  - 验收：CONTRIBUTING.md 含两节新增

- [x] **P6.3** `CHANGELOG.md` 加 v0.0.7 entry
  - 内容：Codex CLI + Codex App 兼容；commands/* → skills/* 迁移；AGENTS.md 新增；workflow Step 0 环境探测；reviewer/dba prose 加强；安装方式更新
  - BREAKING CHANGE（如 commands/* 完全删除）：写明 migration note
  - 验收：CHANGELOG.md 含 v0.0.7 节

### P7 — 跨 runtime 端到端验证（tester phase）

留给 phase 7 tester 完成。tester 报告写到 `docs/testing/codex-compatibility.md`。
测试矩阵：

- T1 Claude Code 完整链路：`/roundtable:workflow <toy-task>` → 5 phase 跑通 → 4 subagent 派通 → TG 广播正常 → closeout 4-option menu
- T2 Codex CLI 完整链路：`codex plugin add github.com/duktig666/roundtable` → `/skills` 列表 → 描述意图启动 workflow → 5 phase 跑通 → spawn_agent 派通 → request_user_input 弹选项 → TG 自动降级终端 → closeout 4-option menu
- T3 Codex App 完整链路：App 装 plugin → App-managed worktree（detached HEAD）下跑 workflow → phase 6 commit → phase 5 closeout 检测 detached HEAD → 输出 handoff payload
- T4 bugfix skill 在两 runtime 跑通
- T5 lint skill 在两 runtime 重建 INDEX.md
- T6 reviewer / dba 不能动 src：Claude 靠 frontmatter（用错工具时被拒）；Codex 靠 prose（手工 audit reviewer 返回内容确认无 apply_patch 调用）

## Verification

### Lint / Format
- JSON valid: `python3 -c "import json; json.load(open('.codex-plugin/plugin.json'))"`
- JSON valid: `python3 -c "import json; json.load(open('.claude-plugin/plugin.json'))"`
- JSON valid: `python3 -c "import json; json.load(open('.claude-plugin/marketplace.json'))"`
- hooks/session-start 还能跑：`bash hooks/session-start <<< '{"hook_event_name":"SessionStart"}'`

### 行为验证
- Claude Code 下 `/plugin install` 装上 roundtable（marketplace 路径或本地 --plugin-dir）
- Codex 下 `codex plugin add github.com/duktig666/roundtable` 装上
- 两 runtime 下 `/skills`（Codex）/ skill list（Claude）能看到：analyst / architect / workflow / bugfix / lint
- 两 runtime 下能用各自方式触发 workflow，跑通 phase 1-5
- developer/tester/reviewer/dba subagent 在两 runtime 下都能派出

### 文档健康
- `/roundtable:lint`（或 lint skill）能重建 docs/INDEX.md，无 broken link

### Acceptance Criteria（参 design-doc §Acceptance Criteria）
逐条对照验收，写入 testing 报告。

## Risks & Mitigations

参 design-doc §Risks & Mitigations（R1-R7）。本 exec-plan 已在 P0 阶段前置消除 R1/R4/R6；R2/R3/R5/R7 留 README troubleshooting + follow-up。

## Change Log

- 2026-05-21: P0.1/P0.2/P0.3 deferred — 本会话无法重启 Claude/安装 Codex；采用 safe default per orchestrator brief (commands/* 保留薄壳一行 `Skill(...)`)；真验证 tester phase 做
- 2026-05-21: P1.1 done — `.codex-plugin/plugin.json` v0.0.7 with inline hooks obj + full interface block (displayName / category Coding / capabilities / defaultPrompt / brandColor / composer + logo placeholder); JSON valid
- 2026-05-21: P1.2 done — `AGENTS.md` single line `CLAUDE.md` per DEC-0004
- 2026-05-21: P1.3 ⏩ skipped (rolled into P0.2 deferral); existing hooks/session-start already emits `additionalContext` field across Cursor / Claude / fallback branches — schema matches design-doc §C.5 expectation
- 2026-05-21: P2.1 done — `skills/workflow/SKILL.md` ported from commands/workflow.md; full Phase Matrix / TG broadcast / [NEED-DECISION] retained; Step 5 closeout extended with env-detect + Path A handoff (covers P5.1+P5.2)
- 2026-05-21: P2.2 done — `skills/workflow/references/codex-tools.md` with full tool mapping table, spawn_agent/wait_agent/close_agent usage, TG MCP optional section, multi_agent + plugin_hooks troubleshooting
- 2026-05-21: P2.3 done — `skills/bugfix/SKILL.md` + `references/codex-tools.md`
- 2026-05-21: P2.4 done — `skills/lint/SKILL.md` + thin `references/codex-tools.md`
- 2026-05-21: P2.5 done — commands/{workflow,bugfix,lint}.md rewritten as thin shells per orchestrator brief safe default; canonical source lives in skills/
- 2026-05-21: P2.6 done — `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` bumped to v0.0.7 (aligned with .codex-plugin); no commands/skills explicit field needed (auto-loaded by directory convention)
- 2026-05-21: P3.1 done — reviewer.md Forbidden section adds Codex no-mutation prose (read-only `cat`/`rg`/`find`/`git log/diff/show/blame` only)
- 2026-05-21: P3.2 done — dba.md Forbidden section adds Codex no-mutation + SQL no-write prose (covers psql/mysql/MCP DB; SELECT/EXPLAIN/SHOW only)
- 2026-05-21: P3.3 done — developer.md + tester.md each get `## Codex Runtime Note` mapping table; frontmatter `tools:` unchanged per DEC-0003
- 2026-05-21: P4.1 done — `skills/analyst/references/codex-tools.md` mapping table + channel-aware Codex variant + boundaries-unchanged note
- 2026-05-21: P4.2 done — `skills/architect/references/codex-tools.md` mapping table + 3-parallel `spawn_agent` research fan-out example + channel-aware decision protocol Codex variant
- 2026-05-21: P5.1+P5.2 done (folded into P2.1) — workflow SKILL.md Step 5 includes env-detect (GIT_DIR vs GIT_COMMON, BRANCH), decision matrix (4 rows), Path A handoff payload template with 4 fields (commit SHA / branch name / PR title / PR body), then Standard closeout
- 2026-05-21: P6.1 done — README.md + README-zh.md gain Codex CLI / Codex App install sections + troubleshooting (multi_agent / plugin_hooks / optional TG MCP); positioning line widened from "Claude Code plugin" to "multi-runtime plugin"
- 2026-05-21: P6.2 done — CONTRIBUTING.md gains "Codex 本地测试" checklist + AGENTS.md pointer note; updated existing checklist to cover both .claude-plugin and .codex-plugin JSON; fixed dangling `docs/onboarding.md` reference (file removed in v0.0.5) → now points to `docs/usage.md`
- 2026-05-21: P6.3 done — CHANGELOG.md v0.0.7 entry under Added / Changed / Notes; preserves existing Unreleased section (TG-broadcast checklist polish) intact above
- 2026-05-21: post-review follow-up — W1 移除 composerIcon/logo 引用；W2 hook 键改 PascalCase SessionStart；W5 加 Migration Note；版本升 0.0.7-rc1
