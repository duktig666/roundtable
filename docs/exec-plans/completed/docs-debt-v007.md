---
slug: docs-debt-v007
date: 2026-06-12
status: completed
analysis: ../../reviews/2026-06-12-comprehensive-review.md
issue: 131
---

# 文档债清算 + v0.0.7 正式版发布准备

## Solution（PR-3，user 已确认「继续 然后发0.0.7」）

来源：[全面审查报告](../../reviews/2026-06-12-comprehensive-review.md) 问题 2.4/2.5/2.6/3.3 + PR-2 tester/reviewer 备案（usage/roundtable 旧口径）。纯文档改动 + 版本号 bump；merge 后由 orchestrator 打 tag 发 release（不在本 exec-plan 内）。

已销项（现状核实 2026-06-12）：README `~760 lines` 声明已不存在（W3）；`documentation/` 备选目录已在 PR-1 文档化（3.4）。

## 设计决策（已定，不要重开）

- **DEC-1 计数与清单全面对真**：
  - 插件 `CLAUDE.md` Layout 节：`2 skills` → 5 个（analyst/architect/workflow/bugfix/lint）；补缺失条目：`tests/`（hook 测试两套）、根级 `hooks.json`（Codex 侧 hook 声明，matcher `*`）与 `hooks/hooks.json`（Claude Code 侧，matcher `startup|clear|compact`）的分叉为**有意为之**各写一行、`.codex-plugin/`、`skills/*/references/`、`AGENTS.md`（指针文件）
  - `.claude-plugin/plugin.json` description：`2 skills, 3 commands` → `5 skills, 3 commands`
  - `.codex-plugin/plugin.json` description：改为 `5 skills`，删去 `3 commands`（Codex 无 commands）
  - `README.md`/`README-zh.md` 的 Commands/Skills/Agents 清单表核对补全 5 skills（phase 表里的 analyst/architect 角色标注不动）
- **DEC-2 CONTRIBUTING.md 修死链**（:37,42,43,45 一带）：「三件套」段重写为当前文档体系（7 目录 + INDEX.md 由 lint 重建）；`docs/design-docs/roundtable.md` → `docs/roundtable.md`；删除 `docs/log.md`、`docs/decision-log.md`（v0.0.5 已删）引用；`docs/INDEX.md` 表述改为「由 /roundtable:lint 生成」。同文件 AGENTS.md 段（3.3）：「Codex 读到指针后会去读 CLAUDE.md」的断言软化为「指针文件，效果取决于 runtime 是否跟随」
- **DEC-3 dogfood 欠账**：
  - 按 `skills/lint/SKILL.md` Step 2 规范生成 `docs/INDEX.md`（7 目录全扫，slug + 首个 H1）
  - `docs/exec-plans/active/codex-compatibility.md`（全勾/⏩）按 closeout 清扫规则移入 `completed/`
  - W5：`skills/workflow/SKILL.md:96` 内嵌 `### Step 0: Detect environment` 改为非 Step 编号标题（如 `### Environment detection`），消除与顶层 Step 编号的混淆；全文检查无其他内嵌 Step 0
- **DEC-4 docs/usage.md 与 docs/roundtable.md 对齐现行规范**：
  - 三处窄口径 AskUserQuestion（usage:92,154、roundtable:85）改为引用 canonical NEED-DECISION relay 规则（channel-aware）
  - roundtable.md:20 `2 skills` → 5 skills；roundtable.md:95 与 usage:139 的 docs_root 发现描述更新为双模式 hook（bounded walk-up + workspace 模式 + `.roundtable.json`，一两句即可，细节链 README）
  - 其余历史性叙述（如 roundtable.md:118 设计决策记录）不动——历史记录不改写
- **DEC-5 release 准备**：三个 manifest（`.claude-plugin/plugin.json`、`.claude-plugin/marketplace.json`、`.codex-plugin/plugin.json`）版本 `0.0.7-rc3` → `0.0.7`；`CHANGELOG.md` `[Unreleased]` 改为 `[0.0.7] - 2026-06-12` 并在其上新增空 `[Unreleased]` 节；CHANGELOG 已发布历史节（rc1~rc3 及更早）一字不改
- **DEC-6 范围外**：codex-tools 去重、description 触发词、PreToolUse 硬拦（0.0.8）；hooks/session-start、tests/、skills 行为性内容不动；root hooks.json 的 `async` 字段不动（行为未验证，仅文档化分叉）

## Phases

### Phase 1: 计数对真（DEC-1）

- [x] 1.1 插件 CLAUDE.md Layout 节重写
- [x] 1.2 两个 plugin.json description 修正
- [x] 1.3 README 双语 skills 清单核对补全

### Phase 2: CONTRIBUTING + dogfood（DEC-2/3）

- [x] 2.1 CONTRIBUTING.md 死链修复 + AGENTS.md 断言软化
- [x] 2.2 生成 docs/INDEX.md（按 lint Step 2 规范）
- [x] 2.3 codex-compatibility exec-plan 移 completed/
- [x] 2.4 W5 内嵌 Step 0 标题改名

### Phase 3: usage/roundtable 旧口径（DEC-4）

- [x] 3.1 usage.md 三处更新（92/139/154 一带）
- [x] 3.2 roundtable.md 三处更新（20/85/95 一带）

### Phase 4: release 准备（DEC-5）

- [x] 4.1 三 manifest 版本 → 0.0.7
- [x] 4.2 CHANGELOG [Unreleased] → [0.0.7] - 2026-06-12，新增空 [Unreleased]

## Verification

- `grep -rn "2 skills" . --include="*.md" --include="*.json" -r`（排除 docs/_archive、CHANGELOG 历史节、docs/reviews|testing 报告类）零命中
- `grep -n "log.md\|decision-log" CONTRIBUTING.md` 零命中
- `ls docs/exec-plans/active/` 仅剩本 exec-plan；`docs/INDEX.md` 存在且收录 7 目录全部 .md
- `grep -rn "0.0.7-rc" .claude-plugin/ .codex-plugin/` 零命中
- 两套 hook 测试仍全绿（确认未误伤）：`bash tests/session-start.test.sh` + `STRICT=1 bash tests/session-start.adversarial.test.sh`

## Change Log

- 2026-06-12 user 确认 PR-3 + 发 0.0.7
- 2026-06-12 tester F1（exec-plan 未入库致发布树 INDEX 断链）归 closeout 处理；F2/F3/F4 NEED-DECISION 采 A 全修（orchestrator 决策，依据：发布门槛从严 + 三处均一两行）
- 2026-06-12 reviewer fix-critical-then-merge：Critical=F1（closeout 入库时解决）；Suggestion ②（frontmatter status 顺手改 completed）已采纳
