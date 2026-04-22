---
slug: decision-log-sustainability
source: design-docs/decision-log-sustainability.md
created: 2026-04-22
status: Active
decisions: [DEC-025, DEC-026]
---

# decision-log 可持续性执行计划

> 关联 design-doc：[decision-log-sustainability.md](../../design-docs/decision-log-sustainability.md)
> DEC-025（规则）/ DEC-026（索引）/ issue [#84](https://github.com/duktig666/roundtable/issues/84)

## 总览

| Phase | 标题 | 预估 | 前置 | 关键风险 |
|-------|------|------|------|---------|
| P0 | decision-log.md 元规则区扩容 | 30 min | — | 已 commit 历史 DEC 引用链；不回溯 |
| P1 | commands/lint.md 5 检查项 + 统计扩 | 45 min | P0（铁律 5 / Provisional 定义入库后 lint 才能引）| 误报 / 漏报；跳过 DEC-013~020 |
| P2 | skills/architect/SKILL.md Stage 2 自问句 | 10 min | P0 | **critical_modules 命中**，必走 Stage 6 tester + Stage 7 reviewer |
| P3 | docs/INDEX.md §决策索引段 | 20 min | P0-P2 完成（落盘 DEC 后再写索引）| INDEX.md 维护责任声明需对齐 Step 7 契约 |
| P4 | 本地预写 15 行 commit 归并 | 5 min | P0-P3 | 用户本地已打底，P0 应 Edit 覆盖而非叠加 |

**Stage 6（tester）/ Stage 7（reviewer）由 orchestrator 驱动**，不在本 exec-plan 中细列；工作流规则见 `commands/workflow.md` §Step 6 C 类 verification-chain 交接。

## 跨阶段约束

- **不回溯 DEC-001~020**：禁止改历史 DEC 正文 / 状态 / 影响范围；铁律 5 lint 扫描跳过 DEC-013~020
- **已 Accepted DEC 保护**：DEC-017 Amendment / DEC-018 / DEC-019 / DEC-020 虽实证"应走其他路径"仍保留原条目（analyst FAQ 观察 + DEC-025 决定 10）
- **critical_modules 命中**：仅 P2（architect SKILL）触发；P0/P1/P3/P4 不触发
- **本地预写 15 行的处理**：用户本地 `docs/decision-log.md` 已预写铁律 4/5/6 + Refined by 状态（未 commit）；developer P0 应 Read 实际文件 → Edit 整合（不是叠加新段 on top of 本地预写）
- **Provisional 自 dogfood**：DEC-025 / DEC-026 本身以 Provisional 落盘；本 workflow Stage 9 closeout 前若无回归 → first-use dogfood 通过，commit 前状态改 Accepted（单 Edit）

## P0: decision-log.md 元规则区扩容

### 目标

将 DEC-025 决定 1-8 落到 `docs/decision-log.md` 顶部元规则区（含本地预写 15 行整合）。

### 任务清单

- [x] Read 当前 `docs/decision-log.md` L1-L51（元规则区）
- [x] 确认本地预写 15 行位置（git diff 显示 +状态 Refined by / +铁律 4/5/6）
- [x] 在 `## 状态说明` 表格插入 `Provisional` 行（在 `Accepted` 下、`Superseded` 上）
- [x] 在 `## 铁律` 区保留铁律 1-3（不删除旧条目 / 冲突报 diff / 编号递增），确认铁律 4/5/6 措辞对齐 DEC-025 决定 2/3/4
- [x] 追加 **铁律 7 归档占位**（完整条目含 4 触发条件 AND 逻辑 + stub 格式 + 精简纪律 + 本轮不执行声明）
- [x] 在 `## 铁律` 之后、第一个 `---` 分隔符之前新增 `## 开立门槛` 小节：
  - 5 类必开（正例）带示例实证
  - Red Flags 负例清单（~6 条反模式，含实证 DEC-017 Amendment / DEC-018 等）
  - 4 类不应开 DEC 的正确落点路由表（**post-fix clarification** 行直接引铁律 4，不重述，对齐 design-doc §4.8 "单一权威源"）

### 成功信号

- `grep -cE "^### DEC-[0-9]+" docs/decision-log.md` 仍为 23（DEC-025 / DEC-026 已落盘，P0 不动条目）
- `grep -n "^## 开立门槛\|^### 铁律 7\|^| Provisional |" docs/decision-log.md` 命中 3 项
- `git diff docs/decision-log.md` 净增 ≤ 100 行（元规则区扩容上限）

### 风险与预案

- **风险**：与本地预写 15 行重复 → **预案**：developer 必须先 Read actual 文件再 Edit，不重复添加 `Refined by` 状态 / 铁律 4/5/6
- **风险**：铁律 7 和本 DEC 决定 7 措辞漂移 → **预案**：复制 DEC-025 决定 7 原文 + 加"本轮立规不执行"声明一致

## P1: commands/lint.md 5 检查项 + 统计扩

### 目标

将 DEC-025 决定 9（lint 扩 5 检查）落到 `commands/lint.md` §6 与 §9 统计段。

### 任务清单

- [x] Read `commands/lint.md` L60-L110（§6 decision-log 一致性 + §9 统计）
- [x] §6 现有"长期 Proposed"保留，重构为 **L6.1 状态流转**（含现有 + Provisional + 归档候选）
- [x] 新增 **L6.2 铁律 5 影响范围 ≤10 行**（扫 `**影响范围**:` 段；**跳过 DEC-013~020**）
- [x] 新增 **L6.3 状态行字面值 + ≤60 字符**（5 字面值白名单 + 长度）
- [x] 新增 **L6.4 Refined by / Superseded by 引用完整性**（悬空 + 自引用）
- [x] 新增 **L6.5 DEC 必填字段完整**（6 项：日期 / 状态 / 上下文 / 决定 / 相关文档 / 影响范围）
- [x] §9 统计段：决策总数按 6 状态细分 + 超期告警 3 项 + 结构告警 4 项

### 成功信号

- `grep -cE "^- L6\.[1-5]" commands/lint.md` ≥ 5
- self-test：本地跑 `/roundtable:lint roundtable` 对当前 decision-log.md：
  - L6.3 应识别 23 条 DEC 状态行，全部有效字面值
  - L6.4 应识别 Refined by 引用（DEC-017 Amendment / DEC-020），无悬空
  - L6.5 应识别 23 条 DEC 必填字段齐全
  - L6.2 对 DEC-013~020 skip（不报错），对 DEC-025 / DEC-026 扫（≤10 行应通过）

### 风险与预案

- **风险**：DEC-013~020 跳过逻辑实现错 → **预案**：lint 规则里显式硬编码"DEC-013 ≤ NNN < DEC-025 跳过 L6.2"；测试样例含跨边界 DEC
- **风险**：state 枚举拼写敏感（"Accepted" vs "accepted"）→ **预案**：检查大小写敏感，与 decision-log.md 文本严格一致

## P2: skills/architect/SKILL.md Stage 2 自问句（critical_modules）

### 目标

在 `skills/architect/SKILL.md` 阶段 2 第 8 步前插入"开立前自问"句。

### 任务清单

- [x] Read 当前 `skills/architect/SKILL.md` 阶段 2 全文定位"8. 新决策 → 追加 decision-log.md"
- [x] 在第 8 步前插入自问句（design-doc §3.3 措辞完整照搬）
- [x] 跑 lint_cmd：`grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/` 确保 0 命中
- [x] self-check：阅读 architect SKILL 完整阶段 2，确认自问句位置语义连贯，不干扰现有 Research Fan-out（阶段 3.5）流程

### 成功信号

- `grep -n "开立前自问\|§开立门槛" skills/architect/SKILL.md` 命中 1 次
- lint_cmd 0 命中

### 风险与预案

- **风险**：**critical_modules 命中** —— 行位置错放会影响整个 architect skill 的 flow → **预案**：插入点严格按 design-doc §3.3（"第 8 步前"而非第 8 步开头 bullet），必走 Stage 6 tester + Stage 7 reviewer，由 tester 回归 "architect 跑一轮完整流程" 验证
- **风险**：tester 回归可能逼出 DEC-025 新修订 → **预案**：若出现，沿铁律 4 走 inline post-fix DEC-025 路径，不开新 DEC；Stage 9 closeout 前 Provisional → Accepted 的判定仍成立

## P3: docs/INDEX.md §决策索引段（DEC-026）

### 目标

在 `docs/INDEX.md` 新增 `## 决策索引` 段，覆盖 23 条 DEC。

### 任务清单

- [x] Read 当前 `docs/INDEX.md` 定位 `## 当前文档清单` 段位置
- [x] 在 `## 当前文档清单` **之前**插入 `## 决策索引` 段：
  - 表头：`| DEC | 标题 | 状态 | 相关 slug | 相关文件 |`
  - 按 DEC 号降序（DEC-026 最上，DEC-001 最下）
  - 23 行数据全填（相关 slug 来自 design-doc frontmatter `slug:`；无 slug 的历史 DEC 用关联 design-doc 文件名的 basename）
- [x] 顶部 doc-briefing 句（design-doc §2.3）：`> 决策日志的 DEC 级索引。按 DEC 号降序（最新在前）。读取契约：本表是入口，各 DEC 正文在 decision-log.md；architect/reviewer 先查索引定位，再按需 Read。`

### 成功信号

- `grep -c "^| DEC-" docs/INDEX.md` = 23
- `wc -l docs/INDEX.md` 净增 ~30 行

### 风险与预案

- **风险**：历史 DEC（如 DEC-001）无 slug → **预案**：用 `roundtable` / `decision-mode-switch` 等 design-doc basename；无 design-doc 对应时填 `—`
- **风险**：后续新 DEC 索引条目维护遗漏 → **预案**：DEC-026 决定 3 已声明 orchestrator Step 7 负责；本 exec-plan 结束后首个 workflow 即验证 orchestrator 是否自动追加

## P4: 本地预写 15 行 commit 归并

### 目标

清理 `docs/decision-log.md` 本地未 commit 的预写内容，确保 P0 完成后 git status 干净。

### 任务清单

- [x] P0-P3 完成后跑 `git diff docs/decision-log.md`
- [x] 确认本地预写 15 行已被 P0 扩容**覆盖 / 整合**（非叠加）
- [x] 若出现冗余 → Edit 删除冗余；若位置漂移 → Edit 归位
- [x] 最终 `git status` 应仅显示 5 文件 modify：`docs/decision-log.md` / `commands/lint.md` / `skills/architect/SKILL.md` / `docs/INDEX.md` / `docs/log.md`（+ `docs/exec-plans/active/` 本 plan 本体 + `docs/design-docs/` + `docs/analyze/`）

### 成功信号

- `git diff docs/decision-log.md` 无残留重复段
- 5 目标文件全部修改就位

### 风险与预案

- **风险**：用户可能已本地 commit 了 15 行而非 dirty state → **预案**：developer 实施前 `git log -1 docs/decision-log.md` 确认本轮基线，避免与已 commit 历史冲突

## 变更记录

- 2026-04-22 初稿（D1-D6 = A/A/A/A/A/A，go-with-plan ★）
- 2026-04-22 developer (inline) P0-P4 全部完成：
  - P0 decision-log.md 575→676 行（+Provisional + 铁律 7 + §开立门槛 38 行）
  - P1 commands/lint.md +41 行（L6.1-L6.5 + 统计扩）
  - P2 skills/architect/SKILL.md Stage 2 step 8 自问句 + step 9 Provisional 默认（**critical_modules**，待 Stage 6 tester 验证）
  - P3 docs/INDEX.md +36 行（§决策索引 23 DEC 行 + 维护责任声明）
  - P4 本地预写 15 行 git diff 确认整合（无重复段），5 M + 3 ?? 符预期
  - lint_cmd 0 命中 pass
