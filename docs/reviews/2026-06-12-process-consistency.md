---
slug: process-consistency
date: 2026-06-12
issue: 129
scope: PR-2 代码审查（git diff main...HEAD，3 commits：308081c / 848dc12 / cfc9771）
---

# process-consistency — Review (2026-06-12)

对象：纯 prompt/markdown 改动，7 文件（含 tester 报告），对照 exec-plan DEC-1~DEC-5 与 tester 发现项 F1~F6 处置。

## Critical

（无）

## Warning

- `skills/workflow/SKILL.md:140` — F1 修复消除了字面矛盾（不再指示 user 移动），但新承诺「the next orchestrator session moves it to completed/ at closeout」在全 prompt 图中**没有执行者指令**：workflow Step 5（:156）与 bugfix Step 7（:99）都只指示移动**当前任务**的 exec-plan，且 gate 在当前任务自己的 `go-commit`/`go-all` 上；没有任何 Step 指示后续 orchestrator 会话在 closeout 时清扫 active/ 下遗留的 fully-ticked exec-plan（lint :53-54 只 suggest，CLAUDE.md:41 明确 lint never moves）。Path A 任务永远不会发出自己的 `go-commit`/`go-all`，因此其 exec-plan 只能搭**别的任务**的 closeout 顺风车——与 CLAUDE.md:41 的全称限定「(only after go-commit/go-all)」勉强自洽（gate 属于另一个任务），但这层搭车语义无任何文字背书；若 user 此后不再跑 workflow，文件无限期滞留 active/。→ 建议一行修复：`skills/workflow/SKILL.md:156` 末尾补「at closeout, also move any leftover fully-ticked exec-plans in active/ (e.g. from a prior Path A handoff)」，bugfix Step 7 经「Same as workflow Step 5」自动继承。可本 PR 内改，也可随 PR-3 收口。

## Suggestion

- `skills/bugfix/SKILL.md:43` — mini exec-plan frontmatter 固化 `tier:`，而 developer 被禁改 exec-plan body（`agents/developer.md:39`），diff 后 tier 实际升级时无步骤指定 orchestrator 回写；Step 6 postmortem 触发依赖 `tier == 2`。即 tester F3，处置（归已知问题 1.6）合理，建议 1.6 修复时把 frontmatter 回写责任明确给 orchestrator。
- `skills/bugfix/SKILL.md:61-71` — Step 4 的 runtime bullet 与参数 bullet 之间隔空行，渲染为两个独立列表，参数列表与 Claude Code 路径的从属关系靠推断；本 PR 在该列表追加了承重的 exec-plan path 三项，使既有结构性歧义负担加重（tester F5 定 pre-existing/info，成立）。建议 0.0.8 合并为单一 "with:" 引导列表。
- `docs/usage.md:92,154`、`docs/roundtable.md:85` — CLAUDE.md:27 canonical 化后，这三处成为非 _archive 文档中仅存的窄口径「grep 后调 AskUserQuestion」（缺 channel-aware 分支）。矛盾相对 workflow:91 pre-existing，按 DEC-5 归 PR-3 文档债正确；备案确保 PR-3 范围包含这三行（tester F2 已记录）。
- `skills/workflow/SKILL.md:156` / `skills/bugfix/SKILL.md:99` — 移动发生在 `go-commit` 之后，意味着 commit 进库的是 active/ 路径、移动产生一次未提交 rename。Pre-existing 模式（workflow :156 本 PR 未动，bugfix 仅如实镜像），不要求本 PR 处理，记录备查。

## 审查维度核验

### 1. DEC 符合度

- **DEC-1** ✅：`agents/developer.md` 第 5 步已删，:28 改 orchestrator-at-closeout；`CLAUDE.md:41` 改口径且保留 lint never moves；workflow :140/:156 与 bugfix :99 三处口径兼容（:140 残留即 tester F1，已在 cfc9771 修复，残余执行者缺口见 Warning）。全仓 grep `completed/` 无 developer/user-move 残留。
- **DEC-2** ✅：Step 3.5 模板含 frontmatter（slug/issue/tier，无 source:）+ Solution + 3 checkbox + Change Log，全 tier 适用；Step 4 改传 exec-plan path；`codex-tools.md:25` message 同步加 `exec-plan:` 行（Step 4 参数的 Codex 具体化，可追溯）；codex-tools :9,16 未改（核对属实，符合「无需改则不改」）。
- **DEC-3** ✅：canonical 全量表述唯一（workflow:91，带显式标记且反向声明引用方）；`CLAUDE.md:27` 与 `bugfix:73` 均为引用式，「calls AskUserQuestion」窄表述已删；`agents/*.md` 子 agent 侧打印协议（developer:33,35 / tester:40 / reviewer:55 / dba:47）按设计未动；两个 codex-tools relay 节为 runtime 工具映射，语义与 canonical 一致（Change Log 落点 + 续派同角色齐备）。
- **DEC-4** ✅：workflow:89 补 reviewer diff 范围，对齐 `agents/reviewer.md:16`；tester 输入（exec-plan path + docs_root，`agents/tester.md:13-14`）被 :88 通用参数覆盖，「无缺项不补」结论正确。
- **DEC-5** ✅：diff 未触 hooks/、tests/、CONTRIBUTING、README 双语、CLAUDE.md Layout 计数（"2 skills" 旧账留给 PR-3，未夹带）。

### 2. F1 修复质量（Path A 语境）

方向正确：Path A 渲染 payload 时工作未 merge，exec-plan 留 active/ 是对的语义；新表述从「给 user 的指令」改为「状态陈述 + lint 兜底」，与 CLAUDE.md:41 单一 owner 不再字面冲突。但「下一个 orchestrator 会话执行」缺指令背书 → 见 Warning（一行可补）。

### 3. 引用图完整性（逐一打开目标核对）

| 引用 | 目标 | 结果 |
|---|---|---|
| `CLAUDE.md:27` → workflow Step 4 | `skills/workflow/SKILL.md:91`（位于 `## Step 4` :64 内） | ✅ |
| `CLAUDE.md:41` → workflow Step 5 | :94/:156 | ✅ |
| `bugfix:15` → workflow Step 1 canonical workspace rule | :18（自带 canonical 声明） | ✅ 未受本 PR 影响 |
| `bugfix:17` → workflow Step 2 channel broadcast | :33-40 | ✅ |
| `bugfix:73` → workflow Step 4 canonical relay | :91 | ✅ |
| `bugfix:99` → workflow Step 5 | :94-156 | ✅ |
| `workflow:89` → `agents/reviewer.md` inputs | reviewer.md:16 | ✅ |

canonical NEED-DECISION 标记全仓唯一（workflow:91）；commands/*.md 均 thin wrapper 无独立口径。

### 4. mini exec-plan 走查（tier 0 字面执行）

Step 1（docs_root+slug，经 workflow Step 1 canonical 规则）→ Step 2（root cause 在此产出，Step 3.5 的一句话有来源）→ Step 3（tier 0）→ Step 3.5（写文件，前置全齐）→ Step 4（path/docs_root/slug/tier 全传，覆盖 `agents/developer.md:13-15` 全部输入）→ developer 按 3 checkbox 顺序（失败测试先行与 developer.md:26 吻合）→ Step 5 verify → Step 6 跳过 → Step 7 closeout 移动。**无死路**。lint 兼容（fully-checked :54 / stale :53 / INDEX slug+H1）成立；tier 回写缺口见 Suggestion 第 1 条。

### 5. 二阶矛盾（改动句 vs 未改文件）

- `README.md:81` / `README-zh.md:81`：NEED-DECISION 描述为泛化措辞（不点名 AskUserQuestion），与新口径无新矛盾 ✅
- `agents/tester.md` / `reviewer.md` / `dba.md`：仅子 agent 侧打印协议，无 lifecycle/relay 口径 ✅
- `AGENTS.md`、commands/：无相关表述 ✅
- 仅存旧口径：`docs/usage.md` / `docs/roundtable.md`（pre-existing，PR-3 范畴，见 Suggestion 第 3 条）

### 6. Surgical Changes 逐 hunk 溯源

CHANGELOG 4 条目→Phase 4.1；CLAUDE.md:27→DEC-3；:41→DEC-1；developer.md:28→DEC-1；bugfix Step 3.5→DEC-2；Step 4 exec-plan path→DEC-2、docs_root/slug→F4；:73→DEC-3；:99→DEC-1/2.2；codex-tools:25→DEC-2；workflow:89→DEC-4；:91→DEC-3；:140→F1；docs/testing/→tester 产物（848dc12）。**全部可追溯，无夹带行**。CHANGELOG↔diff 对账与 tester 报告一致。

### tester 发现项处置复核

F1 修复 ✅（残余缺口降级为本报告 Warning）· F4 修复 ✅（参数对齐 workflow:88 与 developer.md 输入）· F2/F3/F5/F6 不修的理由（PR-3 / 已知 1.6 / pre-existing / 风格）均成立，且已回写 exec-plan Change Log ✅。

## Verdict

**CLEAN-WITH-NOTES**（can-merge）— 0 Critical · 1 Warning（workflow:140 承诺缺执行者指令，一行可补，可本 PR 顺手或 PR-3 收口）· 4 Suggestion（均 pre-existing / PR-3 / 已知问题范畴）。
