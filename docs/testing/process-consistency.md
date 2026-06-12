---
slug: process-consistency
date: 2026-06-12
issue: 129
scope: 对抗核查（一致性与可执行性），非自动化测试
---

# process-consistency — Test Plan

对象：PR-2（`308081c`，`feat/process-consistency-botB`，`git diff main...HEAD` 共 6 文件，纯 prompt/markdown）。
方法：步骤引用逐一比对 + 三视角角色走查（workflow orchestrator / bugfix orchestrator / developer subagent）+ 全仓 grep 矩阵 + CHANGELOG↔diff 对账。

## Coverage

### 1. 步骤编号引用核对（4/4 通过）

| 引用处 | 声称 | 实际 | 结论 |
|---|---|---|---|
| `CLAUDE.md:27` → workflow SKILL.md Step 4 | canonical NEED-DECISION relay | `skills/workflow/SKILL.md:91`，位于 `## Step 4: Run phases`（line 64） | ✅ |
| `CLAUDE.md:41` → workflow SKILL.md Step 5 | closeout/go-commit 移动规则 | `skills/workflow/SKILL.md:156`，位于 `## Step 5: Closeout`（line 94） | ✅ |
| `skills/bugfix/SKILL.md:71` → workflow Step 4 | canonical NEED-DECISION relay | 同上 line 91 | ✅ |
| `skills/bugfix/SKILL.md:97` → workflow Step 5 | closeout 渲染 + go-* 等待 | 同上 line 94-156 | ✅ |

### 2. canonical 唯一性

- 全量表述唯一：`skills/workflow/SKILL.md:91`（带 "(canonical NEED-DECISION relay rule — `bugfix` and the plugin CLAUDE.md reference it)" 标记）。
- 引用式：`CLAUDE.md:27`、`skills/bugfix/SKILL.md:71` ✅。
- 子 agent 侧打印协议（`agents/developer.md:33`、`tester.md:40`、`reviewer.md:55`、`dba.md:47`）按 DEC-3 未动 ✅。
- `skills/*/references/codex-tools.md` 仅作 runtime 工具映射（含 Change Log 落点 + 续派，workflow references:50 与 canonical 语义一致）✅。

### 3. DEC-1/2/4 实施核对

- DEC-1：`agents/developer.md` 第 5 步已删，line 28 改为 orchestrator-at-closeout，无残余 developer-move 表述 ✅；`CLAUDE.md:41` 改 orchestrator 口径且保留 lint never moves ✅。
- DEC-2：Step 3.5 模板与根 CLAUDE.md 约定兼容 —— slug ✅ / 无 design-doc 故无 `source:` ✅（根 CLAUDE.md「小任务无 design-doc 则省」）/ `## Change Log` 存在（NEED-DECISION 答案落点成立）✅ / ≥3 checkbox ✅。`codex-tools.md:25` message 已加 `exec-plan:` 行，路径与 Step 3.5 一致 ✅；codex-tools 表格 :9,16 表述现属实（核对未改，符合 DEC-2 预期）✅。
- DEC-4：`skills/workflow/SKILL.md:89` 已补 reviewer diff 范围，对齐 `agents/reviewer.md:16` ✅；tester 输入（exec-plan path + docs_root，`agents/tester.md:13-14`）已被通用派发参数（SKILL.md:88：exec-plan path / docs_root / slug / design-doc）覆盖，「无缺项不补」结论正确 ✅。

### 4. lint 对 mini exec-plan 的兼容

- fully-checked 判定（`skills/lint/SKILL.md:54`）：基于 `- [ ]`→`- [x]`，模板 3 个 checkbox 兼容 ✅。
- stale 判定（lint:53）：基于 `git log -1 --format=%cs`，不依赖 frontmatter `date:`，模板无 date 字段无影响 ✅。
- INDEX 重建（lint:31）：读 `slug` + 首个 H1，模板均有 ✅；无 `source:` 不触发断链 Critical ✅。

### 5. 全仓 grep 矩阵（move/completed · NEED-DECISION · AskUserQuestion · exec-plan path）

- `agents/` `skills/` `commands/` `CLAUDE.md` `AGENTS.md` `README*.md`：除下述 Found Bugs F1 外，全部为 orchestrator-at-closeout / canonical-引用单一口径。`commands/*.md` 均为 thin wrapper 无独立口径。
- `CHANGELOG.md:108,128` 旧口径属历史版本记录，允许。
- `docs/`：`pre.md` / `case-study-rewrite.md` 为历史记录，允许；`usage.md` / `roundtable.md` 见 F2。

### 6. CHANGELOG ↔ diff 对账（一一对应 ✅）

| CHANGELOG [Unreleased] 条目 | 对应 diff 文件 |
|---|---|
| exec-plan lifecycle single owner | `agents/developer.md`、`CLAUDE.md:41`、`skills/bugfix/SKILL.md:97` |
| bugfix Step 3.5 mini exec-plan | `skills/bugfix/SKILL.md:35-57,66`、`skills/bugfix/references/codex-tools.md:25` |
| NEED-DECISION canonicalized | `skills/workflow/SKILL.md:91`、`skills/bugfix/SKILL.md:71`、`CLAUDE.md:27` |
| reviewer dispatch diff scope | `skills/workflow/SKILL.md:89` |

6 个 diff 文件全部被 4 条覆盖，无漏报、无虚报条目。

## New Cases (Adversarial / E2E / Benchmark)

三视角字面走查：

- **workflow orchestrator**：Step 1→5 链路无死路；Step 4 新增 reviewer diff 行位置正确（派发 bullet list 内）；NEED-DECISION 行自洽。
- **bugfix orchestrator**：Step 1（docs_root 经 workflow Step 1 canonical 规则解析）→ Step 3.5（此时 docs_root 已解析，写文件不缺前置）→ Step 4（exec-plan path 来源明确）→ Step 7（移动条件与 workflow Step 5 一字不差）链路完整。
- **developer subagent**：bugfix 与 workflow 两来源现在都传 exec-plan path，`agents/developer.md:13` 输入依赖在两条流程下均成立；step 4 止于勾 checkbox，与两 orchestrator closeout 口径无冲突。

## Found Bugs / Gaps

无 Blocker。按严重度：

### Major

- **F1** `skills/workflow/SKILL.md:140` — Path A handoff payload 末行 "Move the exec-plan to completed/ after the App finishes the branch / PR." 残留非单一 owner 口径：Path A 无 `go-commit`/`go-all`（sandbox-blocked，跳过 4-option menu），该句是渲染给 user 的指令，即 "user moves it" 在 Codex App detached-HEAD 路径下幸存；与 `CLAUDE.md:41` "(only after `go-commit` / `go-all`)" 的全称限定矛盾，exec-plan Phase 4.1「全仓不再存在 developer/user 移动 exec-plan 表述」的自查结论对该行不成立。溯源：DEC-1 把旧 SKILL.md:139（即此行）列为「既有表述为准绳」，设计输入本身未察觉该行就是 user-move 口径，实施如实沿袭——属设计盲点而非实施错误。修法建议（二选一，PR-2 内一行可改）：A) 改为 "The orchestrator moves the exec-plan to completed/ once the App finishes the branch / PR (Path A's closeout equivalent)"；B) 在 CLAUDE.md:41 的括号限定中补 Path A 例外。

### Minor

- **F2** `docs/usage.md:92,154`、`docs/roundtable.md:85` — 现行规范类文档（非 _archive）仍是窄口径「主会话 grep 后调 AskUserQuestion」，缺 channel-aware 分支，与 canonical 规则（workflow:91）不一致。usage.md:154 至少含 Change Log 落点，roundtable.md:85 同；usage.md:92 连落点都无。属 DEC-5 划给 PR-3 的文档债范畴，但 exec-plan 4.1 的「全仓」措辞与 Verification grep 范围（仅 agents/skills/CLAUDE.md/commands）不一致，记录备案，建议 PR-3 收口时一并改。
- **F3** `skills/bugfix/SKILL.md:43` — Step 3.5 模板把 `tier:` 固化进 frontmatter，而 tier 判定（Step 3，LOC = `git diff --numstat`）发生在 developer 产生 diff **之前**（审查报告已知问题 1.6，范围外）；新增风险点：developer 被禁改 exec-plan body（`agents/developer.md:39`），diff 后 tier 实际升级（如 >80 LOC 或 critical hit）时无任何步骤指示 orchestrator 回写 frontmatter，而 Step 6 postmortem 触发依赖 `tier == 2`。已知问题被模板轻微固化，建议 1.6 修复时（预估 tier + 返回后复核）同步规定 frontmatter 回写责任归 orchestrator。
- **F4** `skills/bugfix/SKILL.md:66-69` — Step 4 参数列表未列 `docs_root` / `slug`，而 `agents/developer.md:15` 输入需要 docs_root；Codex 路径由 `codex-tools.md:25` 显式传入兜底，Claude Code 路径靠 SessionStart hook 注入兜底，可运行但与 workflow Step 4（line 88 显式列 docs_root+slug）口径不一。

### Info

- **F5** `skills/bugfix/SKILL.md:63-69` — Step 4 两个 runtime bullet 与参数 bullet list 之间隔空行，Markdown 渲染为两个独立列表，参数列表与 Claude Code bullet 的从属关系靠读者推断。Pre-existing 结构，本 PR 仅追加一项，不计入本 PR 问题。
- **F6** mini exec-plan 模板无 `date:` / `status:` 字段（本仓自身 exec-plan 均有）；lint 与根 CLAUDE.md 均不强制，无实际影响，仅风格不一。

## Stats

- 步骤引用核对：4/4 通过
- DEC 实施核对：DEC-1 ✅（除 F1 边缘残留）· DEC-2 ✅ · DEC-3 ✅ · DEC-4 ✅ · DEC-5 边界遵守 ✅（未动 hooks/、tests/）
- grep 矩阵：4 维度 × 全仓，残余 2 处（F1 in-scope 边缘、F2 PR-3 范畴）
- CHANGELOG 对账：4 条 ↔ 6 文件，一一对应
- 结论：**无 Blocker**；1 Major（F1，一行可修）+ 3 Minor + 2 Info
