---
slug: bugfix-rootcause-layered
source: 原创（issue #37）
created: 2026-04-20
status: Draft
decisions: [DEC-014]
---

# bugfix 分层根因落盘设计

## 1. 背景与目标

### 1.1 问题

`commands/bugfix.md` 步骤 1+2 设有「定位 + 根因分析」阶段，但原文第 46 行明确"复杂 bug 分析过程落盘到对话（不创建新 design-doc）"。由此产生 4 项缺陷：

1. 根因分析是未来改动的资产（同类 bug 复现 / 同模块 refactor），会话结束即丢
2. commit message 压缩过狠，容纳不下完整根因
3. Abort 退化窗口：developer 派发前用户退出 → 分析连 `log.md` 都进不去（只有 `log_entries:` 才走 DEC-008 batching）
4. 不该升级为 design-doc（语义不符，且破坏 bugfix 轻量化 —— DEC-010 心智）

### 1.2 目标

为 bug 根因分析引入**分层**落盘机制：三档 tier（对话 / log.md 结构化 entry / 独立 postmortem 文件）按 bug 复杂度自动或半自动选档；不升级为 design-doc；复用 DEC-008 batching 机制。

### 1.3 非目标

- 不改 5 agent prompt（developer/tester/reviewer/dba/research）—— 沿用 DEC-013 最小改动心智
- 不抬 target CLAUDE.md 业务规则（沿用 DEC-011 / DEC-012 边界）
- 不改 DEC-004 progress event schema / DEC-006 Phase Matrix / Step 4 并行判定树 / critical_modules 触发机制
- 不动 analyst / architect skill prompt

## 2. 分层 Tier 定义

| Tier | 产物 | 触发条件（D1=A 双轴） |
|------|------|-----------------------|
| **0** 对话 | 仅主会话 transcript，不落盘 | 单文件 + 单模块 + 无 critical_modules 命中 |
| **1** log.md entry | `fix-rootcause` 前缀结构化 entry（内嵌 `root_cause` / `fix_summary` / 可选 `reproduction`） | ≥2 文件 或 跨模块，且未命中 critical_modules |
| **2** postmortem | `{docs_root}/bugfixes/[slug].md` 简版 postmortem | critical_modules 命中 **或** 涉 DEC / 设计缺陷候选 **或** 生产事故标签 |

**Tier 2 上升条件优先级**：critical_modules > 涉 DEC > 生产事故；任一命中直接 Tier 2，不降级。

**Tier 1/2 共生**：Tier 2 的 bug **同时**写 `fix-rootcause` entry（指向 postmortem 文件），保留 `log.md` 时间线索引连续性。

## 3. Orchestrator 触发门（D4=B）

### 3.1 自动档（critical hit）

`commands/bugfix.md` 步骤 2 根因分析开始时，orchestrator 先判 critical_modules hit：

- 命中 → 直接声明 "Tier 2 forced (critical_modules hit: [...])"，无用户问询
- 不命中 → 进入 3.2 灰区门

### 3.2 灰区问询门

步骤 2 根因分析输出对话后（developer 或 inline 分析完成），orchestrator emit 一次 `<decision-needed>` 让用户选 tier。三选项 `Tier 0 对话 / Tier 1 log.md entry / Tier 2 postmortem`，每项带 rationale + tradeoff；orchestrator 按以下启发式挂 ★ recommended：

- 单文件 + 单模块 → Tier 0 ★
- ≥2 文件 或 跨模块 → Tier 1 ★
- 涉多组件 或 行为异常（现象非局部）→ Tier 2 ★

**简单 bug 捷径**：步骤 2 summary ≤50 字 且 涉及单文件 → orchestrator 可跳过 emit 直接 Tier 0（避免 UX 噪声，对齐 bugfix 轻量化）。

## 4. YAML schema 扩展（D2=A）

### 4.1 前缀白名单扩展

DEC-008 §Step 8 原白名单 `analyze | design | decide | exec-plan | review | test-plan | lint | fix` → 新增 `fix-rootcause`：

```
analyze | design | decide | exec-plan | review | test-plan | lint | fix | fix-rootcause
```

`docs/log.md` §前缀规范表同步追加一行。

### 4.2 entry schema

`fix-rootcause` 在 Step 8 既有 `prefix/slug/files/note` 基础上追加 3 个**可选**字段：

```yaml
log_entries:
  - prefix: fix-rootcause
    slug: <bug-slug>
    files: [src/foo.rs, tests/foo_test.rs]  # 实际修复文件（与 fix entry 同源）
    note: <一句话总结>
    root_cause: |
      <2-5 句根因描述；复杂 bug 可引用 docs/bugfixes/<slug>.md §根因>
    fix_summary: |
      <1-3 句修复方案>
    reproduction: |              # 可选：复现步骤（已有测试覆盖则省略）
      <步骤>
```

**合并规则**（同轮多 entry）：沿用 Step 8 已有规则 —— `files:` union / `note:` 取首条；**新规则**：`root_cause` / `fix_summary` / `reproduction` 取首条非空值（不拼接，避免 developer + reviewer 双报重复）。

### 4.3 渲染到 log.md

orchestrator flush 时把扩展字段渲染为 markdown：

```markdown
## fix-rootcause | [slug] | [YYYY-MM-DD]
- 操作者: [developer / reviewer]
- 影响文件: [path1, path2]
- 说明: [note]
- 根因: [root_cause]
- 修复: [fix_summary]
- 复现: [reproduction]            # 若省略则不渲染本行
- 关联 postmortem: docs/bugfixes/<slug>.md   # 仅 Tier 2 才渲染
```

## 5. Postmortem 模板（Tier 2）

### 5.1 文件位置

`{docs_root}/bugfixes/[slug].md`。docs_root/bugfixes/ 目录按需创建。

### 5.2 模板

```markdown
---
slug: [bug-slug]
created: YYYY-MM-DD
status: Open | Fixed | Reopened
severity: critical | major | minor
related_issue: #NN                  # 若有 GitHub issue
related_dec: DEC-XXX                # 若触及设计决策
---

# [bug 一句话描述] Postmortem

## 1. 现象
[用户可见症状 / 触发条件 / 影响面]

## 2. 根因
[2-10 行技术分析；引用相关源码行 / git blame]

## 3. 修复
[修改文件列表 + 关键 diff / 为何这样修]

## 4. 复现步骤
[若已有回归测试覆盖，引用测试文件路径；否则给出最小复现]

## 5. 验证
[lint / test / 手动验证结果；reviewer / dba findings 摘要]

## 6. 后续动作
[潜在 DEC 候选 / 同类 bug 审计 / 设计改动提议 / follow-up issues]

## 7. 变更记录
| 日期 | 改动 | 操作者 |
```

**尺寸纪律**：≤150 行；超出部分拆 follow-up design-doc。

### 5.3 写入时机 & 作者（D3=A）

- **时机**：`commands/bugfix.md` 步骤 4（验证）lint + test 通过之后，步骤 5（关键模块审查）之前
- **作者**：developer（与 fix 同轮产出）；reviewer / dba 在 Stage 5 审查完成后 append §5 findings + §7 变更记录
- **硬约束**：步骤 4 验证未通过 → 不生成 postmortem 草稿（避免 factual drift）；closeout 前 orchestrator 检查"Tier 2 bug 是否有 postmortem 文件"，缺失时阻止 closeout gate

### 5.4 与 Tier 1 同源

Tier 2 的 developer final message **同时**上报 `fix-rootcause` log_entry（`files:` 含 postmortem 路径）+ 写 postmortem 文件。log.md entry 的 `root_cause` / `fix_summary` 字段可直接 copy 自 postmortem §2/§3 头几句。

## 6. 影响清单

1. `commands/bugfix.md` §步骤 2 补"Tier 判定决策树 + 灰区问询门"（~15 行）；§步骤 3 派发 developer prompt 追加 tier 注入（~3 行）；§步骤 4 补 postmortem 写入硬约束（~5 行）；§log.md Batching 节追加 `fix-rootcause` 前缀引用（~2 行）
2. `commands/workflow.md` §Step 7 Index Maintenance "identify category" 列表新增 `bugfixes/`（~1 行）；§Step 8 前缀白名单新增 `fix-rootcause`（~1 行）；§渲染规则追加扩展字段（~5 行）
3. `docs/log.md` §前缀规范表新增 `fix-rootcause` 行（~1 行）；§条目格式节追加扩展字段示例（~6 行）
4. `docs/claude-md-template.md` §文档约定列表新增 `bugfixes/`（~1 行）
5. `docs/decision-log.md` 置顶 DEC-014
6. `docs/INDEX.md` 新增 `docs/bugfixes/` 分类 section + 本 design-doc 条目
7. `skills/_detect-project-context.md` **不改**（它只检测 docs_root，不枚举子目录）—— 对齐 issue #37 验收标准 5

## 7. 待确认项

- [ ] design-doc 通过用户审阅
- [ ] developer 实施（改 bugfix.md / workflow.md / log.md / claude-md-template.md）
- [ ] tester 覆盖 critical_modules 命中：prompt 本体 + schema 扩展 + `_detect-project-context.md` 不受影响
- [ ] reviewer 终审（critical_modules 命中必落盘）
- [ ] 一轮 dogfood bugfix（#37 自身 commit 即 dogfood）

## 8. 变更记录

| 日期 | 改动 | 操作者 |
|------|------|--------|
| 2026-04-20 | 初版（issue #37 四决策 D1-D4 = A/A/A/B 锁定） | architect |
