---
slug: process-consistency
date: 2026-06-12
status: active
analysis: ../../reviews/2026-06-12-comprehensive-review.md
issue: 129
---

# 流程一致性：exec-plan 生命周期 / bugfix mini exec-plan / NEED-DECISION canonical 化

## Solution（PR-2，user 已确认按 PR-1 同流程执行）

来源：[2026-06-12 全面审查报告](../../reviews/2026-06-12-comprehensive-review.md) 问题 2.1 / 2.2 / 2.3 / 2.7。纯 prompt/文档改动，无可执行代码。

## 设计决策（已定，不要重开）

- **DEC-1 exec-plan 生命周期单一 owner = orchestrator**：exec-plan 从 `active/` 移到 `completed/` 只由 orchestrator 在 closeout（workflow 的 `go-commit`/`go-all` 之后；bugfix 的 closeout）执行。
  - `agents/developer.md:29` 第 5 步（developer 自己移动）删除，developer 职责止于勾完 checkbox
  - 插件 `CLAUDE.md:41`「The user moves it」改为 orchestrator 在 closeout 移动；保留「lint never moves files」
  - `skills/workflow/SKILL.md:139,155` 既有表述为准绳（canonical），如措辞需要可微调使三处口径一字不差地兼容
- **DEC-2 bugfix 产 mini exec-plan**：`skills/bugfix/SKILL.md` 在 Step 3（tier 判定）与 Step 4（派 developer）之间新增 Step 3.5：orchestrator 写 `<docs_root>/exec-plans/active/<slug>.md`，内容最小化——frontmatter（slug/issue/tier，无 design-doc 故无 `source:`）+ `## Solution`（根因一句话 + 修法一句话）+ checkbox（至少 3 项：复现/回归测试、修复、验证）+ `## Change Log`。所有 tier 都写（与根工作流「小任务也写 exec-plan」对齐；tier 0 就是 4-5 行的事）。Step 4 派 developer 的参数改为传该 exec-plan path（消除 `agents/developer.md` 输入强依赖 exec-plan 与 bugfix 不产 exec-plan 的断裂）；closeout 按 DEC-1 移动。`skills/bugfix/references/codex-tools.md:9,16` 的 exec-plan 表述随之变为属实，核对无需改则不改。
- **DEC-3 NEED-DECISION canonical 化**：`skills/workflow/SKILL.md:90` 已是最全表述（channel-aware 提问 + 答案落 exec-plan `## Change Log` + 续派同一角色），指定为 canonical：
  - 该段落加显式标记（如 "(canonical NEED-DECISION relay rule)"）
  - `skills/bugfix/SKILL.md:46` 改为一行引用 canonical 规则（bugfix 现在有 mini exec-plan，Change Log 落点成立）
  - 插件 `CLAUDE.md:27` 缩成指针（协议细节见 workflow Step 5），删除「calls AskUserQuestion」的过窄表述
  - `agents/*.md` 与 `references/codex-tools.md` 中只描述「子 agent 怎么打印 NEED-DECISION 行」的内容不动（那是子 agent 侧协议，无矛盾）
- **DEC-4 reviewer 派发参数补 diff**：`skills/workflow/SKILL.md` phase 8 派 reviewer 的参数列表补「diff 范围（git range 或文件清单）」，与 `agents/reviewer.md:16` 的输入要求对齐。顺带核对 tester（phase 7）派发参数与 `agents/tester.md` 输入要求是否同样缺项，缺则一并补。
- **DEC-5 范围外**：文档债（CLAUDE.md 的 2 skills 计数、CONTRIBUTING 死链等）归 PR-3；codex-tools 去重归 0.0.8；不动 hooks/、tests/ 下任何文件。

## Phases

### Phase 1: exec-plan 生命周期统一（DEC-1）

- [x] 1.1 `agents/developer.md` 删第 5 步，确认无残余「developer 移动 exec-plan」表述
- [x] 1.2 插件 `CLAUDE.md` Conventions 末条改为 orchestrator-at-closeout 口径
- [x] 1.3 `skills/workflow/SKILL.md` 两处表述核对，必要时统一措辞

### Phase 2: bugfix mini exec-plan（DEC-2）

- [x] 2.1 `skills/bugfix/SKILL.md` 新增 Step 3.5（mini exec-plan 模板内联在该 step 里）
- [x] 2.2 Step 4 派发参数改传 exec-plan path；Step 5/closeout 按 DEC-1 移动
- [x] 2.3 `agents/developer.md` 输入段核对：bugfix 与 workflow 两来源现在都有 exec-plan path，消除歧义表述
- [x] 2.4 `skills/bugfix/references/codex-tools.md` 核对（预期不改）

### Phase 3: NEED-DECISION canonical（DEC-3）+ 派发参数（DEC-4）

- [x] 3.1 workflow SKILL.md:90 段加 canonical 标记
- [x] 3.2 bugfix SKILL.md:46 改引用
- [x] 3.3 插件 CLAUDE.md:27 缩指针
- [x] 3.4 workflow phase 8 派 reviewer 参数补 diff 范围；phase 7 tester 参数核对补齐

### Phase 4: 自查

- [x] 4.1 grep 验证：全仓不再存在「developer/user 移动 exec-plan」「orchestrator parses it and calls AskUserQuestion」类矛盾表述；CHANGELOG [Unreleased] 加条目

## Verification

- `grep -rn "move the exec-plan\|moves it" agents/ skills/ CLAUDE.md commands/` 输出全部指向 orchestrator-at-closeout 单一口径
- bugfix SKILL 通读：Step 3.5 → Step 4 → closeout 链路完整，developer 输入不再有无源依赖
- NEED-DECISION：canonical 标记唯一，bugfix/CLAUDE.md 均为引用

## Change Log

- 2026-06-12 user 确认 PR-2 按 PR-1 同流程执行
- 2026-06-12 tester 复核（docs/testing/process-consistency.md）后修复：F1 `skills/workflow/SKILL.md:140` Path A handoff 末行改为 orchestrator-at-closeout 口径（下一个 orchestrator 会话在 closeout 移动，不再指示 user 移动）；F4 `skills/bugfix/SKILL.md` Step 4 派发参数补 `docs_root` + slug，对齐 workflow Step 4 与 agents/developer.md 输入要求。F2/F3/F5/F6 不修（PR-3 文档债 / 已知问题 1.6 / info）。
