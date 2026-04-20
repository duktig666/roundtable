---
slug: bugfix-rootcause-layered
source: docs/design-docs/bugfix-rootcause-layered.md
created: 2026-04-20
status: Draft
decisions: [DEC-014]
related_issue: "#37"
related_pr: "#39"
description: DEC-014 bugfix 根因分层落盘（Tier 0/1/2）终审；8 文件 diff（design-doc + decision-log + commands/bugfix.md + commands/workflow.md + docs/log.md + docs/INDEX.md + docs/claude-md-template.md + CLAUDE.md）；结论 Approve-with-caveats；0 Critical / 3 Warning / 5 Suggestion；验收对齐 / DEC 正交 / lint 0 命中
---

# DEC-014 bugfix 根因分层落盘 终审

## 0. 结论

**Approve-with-caveats**。可合并，3 Warning 建议 post-fix 或 follow-up issue。

| 等级 | 数量 |
|------|------|
| Critical | 0 |
| Warning | 3 |
| Suggestion | 5 |

lint（`grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/`）：**0 命中**。

## 1. 范围核对

### 1.1 Diff stat（HEAD 工作树）

| 文件 | 添加 | 性质 |
|------|------|------|
| `docs/design-docs/bugfix-rootcause-layered.md` | 187 | new（已 commit） |
| `docs/decision-log.md` | 28 | DEC-014 置顶（已 commit） |
| `commands/bugfix.md` | +20 | prompt 落地 |
| `commands/workflow.md` | +5 | Step 7 + Step 8 渲染契约 |
| `docs/log.md` | +37（含 1 本 PR 的 fix + test-plan + design entry） | 前缀表 + 示例 |
| `docs/INDEX.md` | +4 | `### bugfixes` 占位 |
| `docs/claude-md-template.md` | +1 | 文档约定 |
| `CLAUDE.md` | +3 | GH issue/PR 标题语言 + P0-P3 label 规则 × 2 |

**prompt 本体 commands 净增（DEC-010 视角）**：bugfix.md +20 + workflow.md +5 = **25 行**，低于 tester round 1 实测 57 行（round 2 压缩后），DEC-010 token 纪律 PASS。

### 1.2 PR #39 现状观察（W3 — 见下）

`gh pr view 39` 返回 state=OPEN / additions=215 / 仅 2 文件（design-doc + decision-log）。其余 6 个 prompt 落地文件当前是**工作树未 commit 状态**（`git status` 显示 8 个 modified 均未 staged）。design-confirm 后的 developer 实施轮产出仍未进 PR diff，合并前必须推送，否则 PR 只含设计文档、下游调用者看到 Accepted DEC-014 但 prompt 未落地，造成 drift。

## 2. Design-doc 一致性（PASS）

`docs/design-docs/bugfix-rootcause-layered.md` 读全 187 行，8 节齐全：

| 检查项 | 结果 |
|------|------|
| §2 Tier 表（LOC 维度并入） | PASS —— 三档阈值 `≤80 / >80 / critical` 三处一致（bugfix.md L53-55 / design-doc §2 / 捷径 §3.2） |
| §3.2 灰区捷径 "≤3 句" | PASS —— 消除 round 1 "≤50 字" i18n 歧义；落地 `commands/bugfix.md` L57 一致 |
| §4 YAML schema（`analysis` 合并字段） | PASS —— 3 字段合并为 `analysis: |` 多行 literal block，合并规则 "首条非空不拼接" 明确；`docs/log.md` §条目格式 L192-204 示例同步；workflow.md §Step 8 L302-303 渲染规则同步 |
| §5 postmortem 模板 7 section + 尺寸 ≤150 行 | PASS |
| §5.3 C1 4 条执行锚点 | PASS —— session `{slug}.tier` 记忆 / mini-loop 回派 / closeout gate 校验 / scope 限 §5.2 模板；`commands/bugfix.md` §步骤 4 L90-95 镜像 4 条，与 design-doc §5.3 逐字对齐 |
| §6 影响清单 INDEX `### bugfixes` 预建（W4） | PASS —— INDEX.md L98-100 section 已建，空占位 |
| §7 待确认项 | 5 条待确认，第 3/4 项（tester + reviewer）即本轮执行中，第 1/2 项已完成 |

**post-fix 标注**：design-doc §8 变更记录 L186 明确标 "tester C1/W1/W2/W3/W4 + 3 字段合并 `analysis` 压缩"；DEC-014 §影响范围末尾标 "post-fix 2026-04-20"（decision-log.md L62）—— clarification scope 不新开 DEC，与 DEC-011 append-only 规则一致。

## 3. DEC 对齐（PASS）

| DEC | 对齐结论 |
|-----|--------|
| **DEC-014 自身** | Accepted 置顶于 DEC-013 上方（decision-log.md L38）；8 决定 + 8 备选 + 5 理由完整；影响范围 post-fix 段注标；与 `bugfix-rootcause-layered.md` 双向引用 |
| **DEC-008** | 正交补齐 —— 前缀白名单扩 `fix-rootcause` / 可选 `analysis` 字段 / 渲染扩 2 行（workflow.md L302-303）；flush 3 触发点 / 合并规则 `files` union + `note` 首条 / Read+Edit 步骤零改动；不 Supersede |
| **DEC-010** | 轻量化心智 —— commands 净增 25 行（<60 预算）；新 feature incremental extension 非 helper 抽取；Tier 0 简单 bug 零额外开销对齐"简单路径零成本" |
| **DEC-011** | 置顶规则 —— DEC-014 在 DEC-013 上方；不删旧条目；冲突报 diff 不适用（正交）；编号递增 014 |
| **DEC-013** | `<decision-needed>` 复用于 D4 灰区门 —— bugfix.md §步骤 2 L57 "灰区 emit 一次 `<decision-needed>`"；workflow.md §Step 5 两分支 modal/text 自适应（未显式引用，见 S5） |
| **DEC-006** | Stage 9 Closeout gate 协调 —— C1 锚点 3 "closeout gate 前最终校验" 与 Step 8 flush 触发点 1 同位不同行为（log flush vs postmortem exists），序无冲突；tester round 2 R1 已验 |
| **DEC-005** | developer 执行形态 —— bugfix.md §步骤 3 inline 偏好未改动；critical_modules hit 8 未触 |
| **DEC-004** | progress event schema 零改动 |

## 4. Prompt 落地一致性（PASS）

### 4.1 前缀白名单 3 处同步

| 源 | 白名单 | 一致 |
|----|------|------|
| `commands/workflow.md` L310 | `analyze \| design \| decide \| exec-plan \| review \| test-plan \| lint \| fix \| fix-rootcause` | ✓ |
| `commands/bugfix.md` L127 | "沿用 workflow §Step 8 + `fix-rootcause`" | ✓ |
| `docs/log.md` L181 前缀表 | 9 行齐全含 `fix-rootcause`（L181 追加） | ✓ |

### 4.2 Tier 判定落地（bugfix.md vs design-doc）

`commands/bugfix.md` L49-57 "Tier 判定（D1 双轴 + LOC；DEC-014）" section：Tier 表 3 行 / 优先级 critical > DEC > 生产事故 / 捷径 ≤3 句 + 单文件 + ≤80 LOC / 灰区 `<decision-needed>` 三选；全部与 design-doc §2-§3 对齐。

### 4.3 postmortem 硬约束落地

`commands/bugfix.md` §步骤 4 L90-95 "Postmortem 硬约束（Tier 2，含 orchestrator 执行锚点；DEC-014 C1）" 4 条逐字对齐 design-doc §5.3。

### 4.4 INDEX bugfixes 占位

`docs/INDEX.md` L98-100 `### bugfixes` + 单行占位说明，风格与既有 section 一致。

## 5. Testing 文档核对（PASS）

`docs/testing/bugfix-rootcause-layered.md` 读全 377 行：
- Round 1：10 risk items × 8 边界用例 + Y1-Y5 schema + 白名单 3 处；1 Critical (C1) + 4 Warning (W1-W4)
- Round 2：C1 + W1-W4 全 PASS；发现 W5（nit）+ 3 nit
- C1 修复证据充分：锚点 1+2+3+4 逐条核查可机械执行 / 与 DEC-006 Closeout 协调 / session 记忆写入契约明示
- lint 复跑 0 命中
- §6 Acceptance 映射 7 项对齐 issue #37

## 6. Warnings

### W1 — PR #39 仅含 design commit，实施改动未 commit/push

**证据**：`git status` 显示 8 modified files + 4 untracked（docs/progress / log.md.progress / testing/ / legacy-multi-role-workflow.md）未 staged；`gh pr view 39` additions=215 仅 2 文件。

**影响**：如果现在 merge PR #39，target main 将只获得 Accepted DEC-014 + design-doc，`commands/bugfix.md` 仍无 Tier 判定逻辑 / `docs/log.md` 仍无 `fix-rootcause` 前缀 / INDEX 无 bugfixes 分类 → 下游调用者与 DEC-014 契约 drift。

**建议动作**：merge 前 developer/orchestrator **必须 commit + push 剩余 6 文件** 到 `feat/37-bugfix-rootcause-layered` 分支刷新 PR #39 的 diff。若分两 commit（设计 / 实施），commit 消息参考既有 `design(#37):` + `feat(#37): DEC-014 落地（bugfix.md / workflow.md / log.md / INDEX / template / CLAUDE.md）`。

### W2 — CLAUDE.md 改动 scope 溢出 DEC-014

**证据**：`CLAUDE.md` diff 3 行：`GitHub Issue / PR 标题: 英文` + `创建 issue 必须加 P0/P1/P2/P3 标签` + `评估 issue 执行顺序按 priority 排序`。这 3 条是通用协作约定，与 DEC-014 (bugfix 根因分层落盘) 无语义关联。

**影响**：
- DEC-014 §影响范围明文声明"不改 target CLAUDE.md 业务规则边界"（对齐 DEC-011/012）—— 本仓库 CLAUDE.md 是 plugin 自身的 CLAUDE.md（roundtable meta），不是 target；改 plugin 自身 CLAUDE.md 不违反该边界。但增项与 DEC-014 无关。
- 没有 DEC 支撑 / 没有 design-doc / 没有 log_entries。若合进 PR #39 会造成 "一 PR 一议题"（"不要自动开 PR" / issues-workflow-pr-merge 单议题原则）偏离。

**建议动作**：两选一 —— (a) 从本 PR 剔除 CLAUDE.md 改动另发 issue + PR；(b) 若 3 条约定是既定 user instruction（观察 memory `feedback_askuserquestion_options` 相关但非该规则），在 PR description 显式声明"附带入 3 行协作约定（非 DEC-014 scope）"让 merger 知情。**优先 (a)**。

### W3 — INDEX `按工作流阶段分类` table 未同步 bugfixes 行（tester round 2 nit 4.1）

**证据**：`docs/INDEX.md` L32-39 table 6 行（analyze / design-docs / exec-plans/active/ / exec-plans/completed/ / testing / reviews）未追加 `bugfixes/` 行；下半部 L98 `### bugfixes` section 已建，两者导航入口未对齐。

**影响**：新手读 INDEX 上部 table 时发现不到 bugfixes 分类；只有滚到下半部清单才看到空占位。机械可执行性不受影响（Step 7 "不存在则创建" 能兜底），纯 UX。

**建议动作**：`docs/INDEX.md` L39 后 append 一行 `| bugfixes/ | developer | Tier 2 postmortem（DEC-014），文件名 [slug].md |`。本 PR 内 1 行可修。

## 7. Suggestions

- **S1**：W5（tester round 2 §R6）—— `workflow.md` §Step 8 YAML 契约 L308-314 可在 L314 后追加注释 `# fix-rootcause 下可选: analysis: | ...（多行 YAML literal block）`，避免 subagent LLM 读 workflow.md 契约生成 log_entries 时漏 `analysis`。non-block，follow-up。
- **S2**：tester round 2 §R2 nit —— `commands/bugfix.md` Tier 表可在表注加一句 "LOC 指 `git diff --stat` 的 insertions+deletions 合计" 消口径歧义。follow-up。
- **S3**：tester round 2 §R1 / §R3 nit —— postmortem 硬约束锚点 3 "block closeout 报告用户" 和 W2 critical override 警示确认的 UI 形式未显式声明 `按 decision_mode 渲染`；workflow.md §Step -1 / Step 5 可兼容但未显式引用。下一次触碰 bugfix.md §步骤 4 / §步骤 2 时补 1 句。follow-up。
- **S4**：`docs/design-docs/bugfix-rootcause-layered.md` §5.3 C1 锚点描述中"session 记忆 `{slug}.tier`" 对 LLM 实务是 in-context state（非持久），若后续跨 session resume 不保证记忆存活；目前 bugfix 单 session 内完成问题不大，但建议 design-doc 加一行 "本 session 有效；跨 session resume 时 orchestrator 重建 tier（从对话 history 解析）" 澄清边界。follow-up。
- **S5**：`design-doc` §7 待确认项 第 3 / 4 项（tester + reviewer）应在本轮闭环后勾选，下次 touch 时 update。

## 8. critical_modules 命中确认

本 PR 命中 CLAUDE.md §critical_modules：
- 条目 1（Skill / agent / command prompt 文件本体 + 共享 helper）—— `commands/bugfix.md` + `commands/workflow.md` + `docs/log.md`（日志协议）
- 条目 6（workflow command Phase Matrix + phase gating taxonomy）—— Step 7/8 渲染契约扩展
- 条目 7（Progress event JSON schema）—— 零改动 PASS
- 条目 8（Developer execution-form switching rules）—— 未触动 PASS

→ tester + reviewer 必触发。tester 两轮已落盘 `docs/testing/bugfix-rootcause-layered.md`；本 review 必落盘（本文件）。

## 9. lint

```
grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/
```

**0 命中** PASS。

## 10. 总结

- DEC-014 设计完备、prompt 落地精准、tester 双轮闭环、DEC 正交严谨、lint 0 命中、INDEX 预建到位
- 阻塞级问题：**无**
- W1 merge-time 必须处理（commit + push 6 实施文件到 PR #39）；W2 建议剔除或显式声明；W3 1 行可顺手修
- 5 Suggestion 均 non-block，列入 follow-up

## 11. 变更记录

| 日期 | 改动 | 操作者 |
|------|------|--------|
| 2026-04-20 | 初版终审（Approve-with-caveats；0 C / 3 W / 5 S；lint 0 命中） | reviewer subagent fg（critical_modules 多命中 → 必落盘） |
