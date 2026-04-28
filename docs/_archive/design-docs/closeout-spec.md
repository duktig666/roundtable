---
slug: closeout-spec
source: 原创（issue #26）
created: 2026-04-21
status: Draft
decisions: [DEC-006 §A Stage 9 Closeout append-only clarification]
---

# Stage 9 Closeout 用户驱动流程规范 设计文档

## 1. 背景与目标

### 1.1 背景

DEC-006 把 Stage 9 Closeout 归为 A 类 producer-pause 终点，标注"用户驱动 commit / PR / amend"。但缺少结构化定义：
- 用户如何触发 commit → push → PR 流程
- orchestrator 在 closeout 阶段应提供哪些辅助（commit message 建议 / PR body 模板）
- follow-up issues 的创建时机与流程
- 用户触发形式（`go` 后 orchestrator 生成建议还是被动等待）

本批 #48/#30/#29/#23/#27 5 个 PR 实际执行时已采用某种模式（每个 PR body 含 Summary / Fix / Quality gates / Follow-ups / `Fixes #N`），但未形成 prompt 本体规范；下次 workflow 可能漂移。

### 1.2 目标

1. `commands/workflow.md` Stage 9 Closeout 新增结构化 **closeout bundle** 协议
2. orchestrator 在用户 `go` 时 emit 3-section 建议包：commit message / PR body / follow-up issue 草稿
3. 每项**用户可 accept / 调整 / skip**
4. commit / PR / issue 实际创建仍需用户**二次 `go`**（非 accept 建议就自动 push；保守默认对齐 memory `feedback_no_auto_push` + `feedback_no_auto_pr`）

### 1.3 非目标

- 不改 DEC-006 A 类 producer-pause 三段式
- 不跨项目强制（commit / PR 格式本就是 per-project 约定；本 spec 是 roundtable **自身**的约定，target 项目 CLAUDE.md 可 override）
- 不自动推送 / 不自动开 PR / 不自动创 issue（违反 memory）
- 不覆盖 `/roundtable:bugfix` 的独立 closeout（bugfix 有自己的 Stage 9 路径）

## 2. 关键决策与权衡

### 2.1 D1：commit message 格式

**选择**：**Conventional Commits + scope + `(#N)` issue ref**

格式：`<type>(<scope>): <summary> (#N)`

- type：`feat | fix | refactor | docs | test | chore | perf | style`
- scope：`workflow | bugfix | architect | analyst | developer | tester | reviewer | dba | prompts | ci | deps | release` 或 slug
- summary：≤50 字符，祈使句，小写起头
- `(#N)`：issue 编号
- body：对齐本批 PR body 模式（Summary / Fix / Quality gates / Follow-ups）
- footer：`Fixes #N` + `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`

**备选**：纯自然语言 commit（rejected — 不可机读 + 不支持 `Fixes #N` GitHub auto-close）

### 2.2 D2：PR body 模板

**选择**：**本批 5 PR 已稳定的模板**

```markdown
## Summary
<1-3 句 issue 复述 + 根因>

## Fix
<结构化列点：落点文件 / 新增 contract / 修改对齐 DEC>

## Quality gates
- **lint**: <命中数>
- **tester**: <Critical/Warning/Suggestion/Positive 计数>
- **reviewer**: Approve / Approve-with-caveats / Reject
- **critical_modules**: <hit ratio>

## Follow-ups (non-blocking)
1. ...
2. ...

Fixes #N

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### 2.3 D3：follow-up issue 创建时机

**选择**：**Stage 9 closeout bundle 汇总 + 用户 batch approve 后 gh create**

- orchestrator 从 tester/reviewer/dba final messages 提取所有 **non-blocking Warning / Suggestion**
- 草拟 issue titles（英文，≤70 字符）+ labels（P2 for Warning，P3 for Suggestion）+ body（自动关联当前 PR）
- 用户一次 `<decision-needed>` 块确认：accept 全部 / 剔除列表 / skip 全部
- 确认后 orchestrator 逐个 `gh issue create` + 在 PR body follow-ups section 补 issue #

### 2.4 D4：触发流程

**选择**：Stage 9 `go` → orchestrator 生成 bundle → 用户 accept/调整/skip → 二次 `go` 执行

```
Stage 9 producer-pause menu（扩展 A 类）：
  ✅ Workflow 闭环。
  产出清单：
  - <path1> ... <pathN>
  请告诉我：
    `go` → 生成 closeout bundle（commit msg / PR body / follow-up issues 草稿）
    `问: ...` → FAQ
    `调: ...` → 回某 stage
    `停` → 中止（保留本地修改不 commit）

  `go` 后 orchestrator emit：
    === commit message ===
    feat(scope): summary (#N)
    <body>
    === PR body ===
    <template>
    === follow-up issues ===
    (a) [P2] ...
    (b) [P3] ...

    请告诉我：
      `go-all` → 执行全部（commit + push + PR create + issue create）
      `调: ...` → 修改某项
      `skip-pr` / `skip-issues` → 只做 commit push
      `停`
```

`auto_mode=true` 下：`go` auto-推进生成 bundle + auto-accept → auto-`go-all` 执行。

## 3. 技术实现

### 3.1 `commands/workflow.md` Step 6.1 A 类块 Stage 9 扩展

追加段 **Stage 9 Closeout 变体（扩展，issue #26）**：

```
**Stage 9 Closeout 变体**（A 类终点；issue #26 spec）：

用户 `go` 触发 orchestrator emit **closeout bundle**（3 section）：

1. **commit message 建议**（Conventional Commits 格式 + scope + `(#N)` + body + `Fixes #N` footer）
2. **PR body 草稿**（本批 5 PR 稳定模板：Summary / Fix / Quality gates / Follow-ups / Fixes / Claude Code footer）
3. **follow-up issues 草稿**（从 tester/reviewer/dba final message 提取 non-blocking Warning+Suggestion；英文 title ≤70 + P2/P3 label + body 自动 ref 本 PR）

bundle emit 后再次 pause 等用户：
- `go-all`：执行全部（git commit + push + gh pr create + gh issue create 循环）
- `go-commit` / `go-pr` / `go-issues`：分别执行
- `skip-pr` / `skip-issues`：精细跳过
- `调: ...`：修改某 section（如 `调: commit scope=bugfix`）
- `停`：中止保留本地修改不 commit

**遵守 memory `feedback_no_auto_push` / `feedback_no_auto_pr`**：只在用户显式 `go-*` 时执行 git/gh 操作；**默认不自动**。`auto_mode=true` 仅改 orchestrator 自身的阶段决策，**不**授权跳过本 closeout pause —— 即 auto_mode 下仍需用户说 `go` / `go-all`（memory 是硬边界，优先于 auto_mode §Auto-pick）。
```

### 3.2 `commands/bugfix.md` 继承

bugfix.md Step 步骤 5 / 报告格式 后追加 1 行 ref：`**Closeout bundle**: 沿用 workflow.md Stage 9 Closeout 变体（issue #26）。bugfix Stage 9 同等 A 类终点。`

### 3.3 落点清单

| 文件 | 改动 |
|------|------|
| `commands/workflow.md` | Step 6.1 A 类块 Stage 9 变体段（~25 行）+ §Auto-pick 表末加 closeout bundle 不 auto 注记（~2 行）|
| `commands/bugfix.md` | +1 行 ref |
| `docs/design-docs/closeout-spec.md` | 新建本文件 |
| `docs/decision-log.md` | DEC-006 影响范围 post-fix 2026-04-21 (#26) 追加 ~3 行 |
| `docs/INDEX.md` / `docs/log.md` | 同步 |

**不改**：5 agent / 2 skill / DEC-006 决定正文 / target CLAUDE.md / memory `feedback_no_auto_*` 边界。

## 4. 测试策略

| 场景 | 期望 |
|------|------|
| workflow 闭环 + `go` | bundle 3 section emit |
| `go-all` | commit + push + PR + issues 顺序创建 |
| `go-commit skip-pr` | 只 commit，不 push 不 PR |
| `调: commit scope=prompts` | regenerate commit scope |
| `停` | 不动 git |
| auto_mode=on | **仍 pause 等 `go` / `go-all`**（memory 硬边界）|
| bugfix Stage 9 | 同款 bundle 流程 |

### 4.1 critical_modules 命中

`workflow Phase Matrix` + `Escalation Protocol` + `skill/agent/command prompt 本体` 3/3 → tester 必触发 + reviewer 必落盘。

## 5. 变更记录

- 2026-04-21 初版（issue #26，Draft）
