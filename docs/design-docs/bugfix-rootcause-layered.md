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

| Tier | 产物 | 触发条件（D1=A 双轴 + LOC；post-fix W1） |
|------|------|-----------------------|
| **0** 对话 | 仅主会话 transcript，不落盘 | 单文件 + 单模块 + 修改 ≤80 LOC + 无 critical hit |
| **1** log.md entry | `fix-rootcause` 前缀结构化 entry（内嵌 `analysis` 字段） | ≥2 文件 或 跨模块 或 单文件 >80 LOC；且未命中 critical |
| **2** postmortem | `{docs_root}/bugfixes/[slug].md` 简版 postmortem | critical_modules 命中 **或** 涉 DEC / 设计缺陷候选 **或** 生产事故（issue 带 `production-incident` label 或 issue body 显式声明 —— post-fix W2） |

**Tier 2 上升条件优先级**：critical_modules > 涉 DEC > 生产事故；任一命中直接 Tier 2，不降级。用户在 `/bugfix` 对话中显式说"降级到 Tier 1"可 override critical 自动门，但 orchestrator 需 emit 一次警示让用户确认（post-fix W2）。

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

**简单 bug 捷径**：步骤 2 summary ≤3 句 且 单文件 且 ≤80 LOC → orchestrator 可跳过 emit 直接 Tier 0（post-fix W3：原 "≤50 字" 改 "≤3 句" 消 i18n 歧义）。

## 4. YAML schema 扩展（D2=A）

### 4.1 前缀白名单扩展

DEC-008 §Step 8 原白名单 `analyze | design | decide | exec-plan | review | test-plan | lint | fix` → 新增 `fix-rootcause`：

```
analyze | design | decide | exec-plan | review | test-plan | lint | fix | fix-rootcause
```

`docs/log.md` §前缀规范表同步追加一行。

### 4.2 entry schema（post-fix：3 字段合并为 `analysis`）

`fix-rootcause` 在 Step 8 既有 `prefix/slug/files/note` 基础上追加 1 个**可选**多行字段：

```yaml
log_entries:
  - prefix: fix-rootcause
    slug: <bug-slug>
    files: [src/foo.rs, tests/foo_test.rs]
    note: <一句话总结>
    analysis: |
      根因: <2-5 句>
      修复: <1-3 句>
      复现: <步骤；已有测试覆盖则省略本行>
```

**合并规则**：`files:` union / `note:` 取首条 / `analysis:` 取首条非空值（不拼接，避免 developer+reviewer 双报重复）。

### 4.3 渲染到 log.md（post-fix 精简）

```markdown
## fix-rootcause | [slug] | [YYYY-MM-DD]
- 操作者: [developer / reviewer]
- 影响文件: [path1, path2]
- 说明: [note]
- 分析: [analysis 原样缩进渲染]
- 关联 postmortem: docs/bugfixes/<slug>.md   # 仅 Tier 2 才追加
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
- **硬约束 + orchestrator 执行锚点**（post-fix C1）：
  1. orchestrator 派发 developer 前把本轮 tier 值（0/1/2）写入 session 记忆 `{slug}.tier`
  2. developer final message 返回后，orchestrator 按 tier 检查：`tier==2 && !exists({docs_root}/bugfixes/[slug].md)` → 回派 developer 补写 postmortem（mini-loop），否则进入步骤 5
  3. closeout gate 前最终一次校验：任何本 session 的 `tier==2 && 缺 postmortem` 立即 block closeout 并报告用户
  4. developer 接续补写时只读 design-doc §5.2 模板，不改其他产出

### 5.4 与 Tier 1 同源

Tier 2 的 developer final message **同时**上报 `fix-rootcause` log_entry（`files:` 含 postmortem 路径）+ 写 postmortem 文件。log.md entry 的 `root_cause` / `fix_summary` 字段可直接 copy 自 postmortem §2/§3 头几句。

## 6. 影响清单

1. `commands/bugfix.md` §步骤 2 补"Tier 判定决策树 + 灰区问询门"（~15 行）；§步骤 3 派发 developer prompt 追加 tier 注入（~3 行）；§步骤 4 补 postmortem 写入硬约束（~5 行）；§log.md Batching 节追加 `fix-rootcause` 前缀引用（~2 行）
2. `commands/workflow.md` §Step 7 Index Maintenance "identify category" 列表新增 `bugfixes/`（~1 行）；§Step 8 前缀白名单新增 `fix-rootcause`（~1 行）；§渲染规则追加扩展字段（~5 行）
3. `docs/log.md` §前缀规范表新增 `fix-rootcause` 行（~1 行）；§条目格式节追加扩展字段示例（~6 行）
4. `docs/claude-md-template.md` §文档约定列表新增 `bugfixes/`（~1 行）
5. `docs/decision-log.md` 置顶 DEC-014
6. `docs/INDEX.md` 预建 `### bugfixes` 分类 section（空占位，避免首次 auto-create 不友好；post-fix W4）+ 本 design-doc 条目
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
| 2026-04-20 | post-fix tester C1/W1/W2/W3/W4 + 3 字段合并 `analysis` 压缩：§2 加 LOC 维度 / §3.2 "≤3 句" / §4.2-4.3 schema 精简 / §5.3 C1 执行锚点 / §6 INDEX 预建 | orchestrator inline |
