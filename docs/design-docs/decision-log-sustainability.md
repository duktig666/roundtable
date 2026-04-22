---
slug: decision-log-sustainability
source: analyze/decision-log-sustainability.md
created: 2026-04-22
status: Draft
decisions: [DEC-025, DEC-026]
---

# decision-log 可持续性设计文档

> 关联 issue：[#84](https://github.com/duktig666/roundtable/issues/84) umbrella
> analyst 事实层：[analyze/decision-log-sustainability.md](../analyze/decision-log-sustainability.md)

## 1. 背景与目标

**背景**：`docs/decision-log.md` 575 行 / 20 unique DEC / 近 2 日 5 DEC/天节奏；`skills/architect/SKILL.md:L12` + `agents/reviewer.md:L91` 强制全读契约，纯读 22.8k tokens/workflow；外推 3 月 → 100+ DEC 线性涨至 ~115k tokens。同根：**DEC 开立门槛过低，细节 / UX 偏好 / post-fix 被升级为决策记录**（20 DEC 中 5 条走错路径）。

**目标**（按 D1-D5 决策锁定范围）：
1. **子议题 1**（D1=A）：收紧 DEC 开立门槛 —— **正例 5 类必开 + 负例 Red Flags 清单**
2. **子议题 2**（D2=A）：扩元规则 —— 铁律 4/5/6 + `Provisional` 状态 + `Refined by DEC-xxx` 一等公民
3. **子议题 3**（D3=A）：**仅 B.1** —— `docs/INDEX.md` 新增 DEC 索引段；**不改** architect SKILL + reviewer 全读契约（30 天观测窗）
4. **子议题 4**（D4=A）：归档铁律 7 草案占位 —— 本轮立规不执行

**非目标**：
- 不改 `skills/architect/SKILL.md:L12` / `agents/reviewer.md:L91` 的"全读"契约（子议题 3 B.2/B.3，本轮观测）
- 不做方案 A 分层存储（子议题 3 C 选项，~20 新 design-docs/dec-xxx.md 外放，大工程）
- 不归档任何现有 DEC（子议题 4 D 选项，无可归档对象）
- **不回溯**：DEC-001~020 不因新门槛 / 铁律被降级或改写（保已 commit 引用链，analyst FAQ 观察）

## 2. 业务逻辑

### 2.1 DEC 生命周期（D2=A 引入 Provisional + Refined by）

```
          ┌─────────────┐
          │  Proposed   │  (已提出，待确认)
          └──────┬──────┘
                 │ 落盘
                 ▼
          ┌─────────────┐
          │ Provisional │  (冷却 ≥7 天 OR 首次 dogfood run 通过)
          └──────┬──────┘
                 │ lint 扫描 or 人工转正
                 ▼
          ┌─────────────┐       ┌─────────────────────┐
          │  Accepted   │◄─────►│ Refined by DEC-xxx  │  (父 DEC 状态行追加引用)
          └──────┬──────┘       └─────────────────────┘
                 │
      ┌──────────┴──────────┐
      ▼                     ▼
┌──────────────┐      ┌──────────────┐
│  Superseded  │      │   Rejected   │
│  by DEC-xxx  │      │  (讨论后否决) │
└──────┬───────┘      └──────────────┘
       │  ≥90 天 AND 后继 ≥30 天无新 Refined/Superseded AND 无他处引用
       ▼
┌──────────────┐
│  Archived    │  (铁律 7 占位；本轮不执行)
└──────────────┘
```

**状态转换规则**：
- `Proposed → Provisional`：DEC 落盘时自动进入 Provisional；若属 D2=A 原子提交（本 DEC 本身及子议题 1+2 铁律），以 Provisional 入 DEC-025 自 dogfood（2026-04-22 first-use 即本 workflow 结束）
- `Provisional → Accepted`：满足 a) ≥7 日未被修订，OR b) 首次 dogfood run 通过（`/roundtable:workflow` 实际采用本 DEC 一轮无回归）
- `Accepted → Refined by DEC-xxx`：父 DEC 状态行改为 `Accepted（Refined by DEC-xxx）`；父 DEC 正文不改
- `Accepted → Superseded by DEC-xxx`：父 DEC 状态行改为 `Superseded by DEC-xxx`；父 DEC 正文不改

### 2.2 开立门槛决策流（D1=A）

```
新变动产生
    │
    ▼
自问 5 类必开（正例）?
    ├─ 跨模块接口 / 协议 (schema / JSON / IPC)
    ├─ 改变 DEC-001 D1-D9 任一条
    ├─ 引入新依赖 (外部库 / Claude Code 新 API / plugin 新 skill)
    ├─ 推翻或细化已有 Accepted DEC 的决定条款 (走 Supersede / Refined)
    └─ 技术选型 / 数据模型 的方向性选择
    │
    │ 命中 ≥1 类 → 继续
    │ 0 命中 → 走其他路径
    ▼
自问 Red Flags（负例反模式）?
    ├─ "这看起来很重要所以该开 DEC" (importance 不等于 architectural significance)
    ├─ "影响了 3 个文件" (touch file 数不是门槛)
    ├─ "之前同类都开了我也开" (历史路径依赖)
    ├─ "不开不好记录下来" (commit message + inline 更合适)
    ├─ "要让未来知道有过这个讨论" (FAQ 段 / feedback memory)
    └─ "tester/reviewer 说要开" (post-fix 路径)
    │
    │ 命中任一 → 停下，走其他路径
    │ 全不命中 → 开 DEC
    ▼
其他路径（不开 DEC）:
    ├─ 纯实现细节 (命名 / 格式 / 字符串常量) → 在 design-doc 或 prompt 文件里直接定
    ├─ 文本补丁 / bug 修补 (如 DEC-017 Amendment)     → commit message + 相关 design-doc
    ├─ UX 偏好调整 (如 DEC-018 pretty 渲染)            → feedback memory 或 settings
    └─ post-fix clarification (父 DEC 落盘后)          → inline append 父 DEC (铁律 4)
```

### 2.3 INDEX.md DEC 索引格式（D3=A）

**post-fix 2026-04-22（reviewer W-R01）**：本节原列 5 列 `| DEC | 标题 | 状态 | 相关 slug | 相关文件 |`，实施层收紧为 4 列（"相关文件" 段与各 DEC "相关文档" 段同源 derive，避免重复）；DEC-026 决定 1 inline post-fix 同步。后续若 reviewer / lint 需扩第 5 列再 Refined DEC。

在 `docs/INDEX.md` `## 当前文档清单` 之前新增 `## 决策索引` 段：

```markdown
## 决策索引

> `decision-log.md` 的 DEC 级索引。按 DEC 号降序（最新在前）。
> 读取契约：本表是**入口**，各 DEC 正文在 `decision-log.md`；architect/reviewer 写新设计 / review 时先查本表定位相关 DEC，再按需 Read。

| DEC | 标题 | 状态 | 相关 slug |
|-----|------|------|----------|
| DEC-026 | decision-log token 优化 B.1：INDEX DEC 索引 | Provisional | decision-log-sustainability |
| DEC-025 | decision-log 可持续性：门槛 + 元规则 + 归档占位 | Provisional | decision-log-sustainability |
| DEC-020 | auto-halt text-mode render 形态命名 | Accepted（Refines DEC-016 §3.3）| dec016-auto-halt-text-render |
| ... | ... | ... | ... |
| DEC-001 | plugin 打包 D1-D9 | Accepted | roundtable |
```

**维护责任**（与 Step 7 INDEX.md 整体维护一致）：orchestrator 在 A 类 phase-gate 前按 `log_entries:` 汇聚新增 DEC 追加本段；architect / reviewer 不直接编辑 INDEX.md。**首次建立例外**：本轮 Provisional 落盘时 INDEX.md §决策索引 由 developer 经 exec-plan P3 一次性填充，属 DEC-026 决定 3 W-R02 post-fix 确认的首次建立路径；后续增量仍按 orchestrator 维护。

## 3. 技术实现

### 3.1 decision-log.md 元规则区改动（DEC-025 归并子议题 1+2+4）

**位置**：`docs/decision-log.md` 顶部 `## 铁律` 区扩容 + 新增 `## 开立门槛` 小节 + `## 状态说明` 加 `Provisional`。

**改动前后对照**：

| 段 | 现状 | D1-D4=A 版 |
|---|---|---|
| `## 状态说明` | 4 态（Proposed/Accepted/Superseded/Rejected，本地预写已加 Refined by）| 5 态（+ **Provisional**） |
| `## 铁律` | 3 条（不删/冲突报 diff/编号递增，本地预写已加 4/5/6）| 7 条（铁律 4/5/6 见 §4.1-4.3，**铁律 7 归档占位** §4.7）|
| `## 开立门槛` | 无 | **新增**（§4.0 5 类必开 + Red Flags 负例清单，见 §4.0）|

### 3.2 commands/lint.md 扩展（DEC-025）—— decision-log 审查定位

**定位**：`commands/lint.md` 是 decision-log.md 元规则（门槛 + 铁律 + 状态机）的**执行层审查工具**。用户 2026-04-22 明确要求"lint 流程可以审查 decision-log"；本 DEC 把元规则里可机械判定的条款全部落进 lint 检查项。人工裁决项（如"某 DEC 是否真属 5 类必开"）不 lint，留 architect / reviewer 判断。

在 `## 检查项` 的 **6. decision-log 一致性** 追加 5 条检查（现有"长期 Proposed 超 30 天"保留）：

```markdown
### 6. decision-log 一致性（扩展）

- L6.1 状态流转
  - Proposed > 30 天未决 → 告警「长期 Proposed」（现有）
  - **Provisional > 30 天未转正** → 告警「Provisional 超期：建议评估 Accepted / Refined by / Rejected」
  - **Superseded ≥ 90 天** → 告警「归档候选（铁律 7 触发条件 1）；配合 4 触发条件人工裁决」

- L6.2 铁律 5 影响范围 ≤10 行
  - 扫每条 DEC 的 `**影响范围**:` 段
  - 段内行数（按字面换行符）> 10 → 告警「影响范围超 10 行，建议移 design-doc `## 影响文件清单`」
  - **不回溯** DEC-013~020（铁律 5 声明不回溯；lint 扫描时跳过这批 DEC）

- L6.3 状态行字面值 + ≤60 字符
  - 扫每条 DEC 的 `**状态**:` 行
  - 必须以 5 种字面值之一起首：`Proposed` / `Provisional` / `Accepted` / `Superseded by DEC-xxx` / `Rejected`（可附 `Refined by DEC-xxx` 并列）
  - 状态行总字符 > 60 → 告警「状态行超 60 字符，建议附加上下文放正文」

- L6.4 Refined by / Superseded by 引用完整性
  - 扫所有 `Refined by DEC-NNN` / `Superseded by DEC-NNN` 引用
  - 引用的 DEC-NNN 不存在于 decision-log.md → 报错「引用 DEC-NNN 不存在（悬空 Refined/Superseded）」
  - 引用自己 (DEC-NNN Refines DEC-NNN) → 报错「自引用」

- L6.5 DEC 必填字段完整
  - 每条 DEC 必含 `**日期**` / `**状态**` / `**上下文**` / `**决定**` / `**相关文档**` / `**影响范围**` 六项
  - 任一缺失 → 告警「DEC-NNN 缺字段: <清单>」
  - `**备选**` / `**理由**` 非强制（有则检，无则跳）
```

对应步骤 **9. 统计** 更新：
```markdown
- 决策总数: X（Accepted: X, Provisional: X, Proposed: X, Refined by: X, Superseded: X, Rejected: X）
- 超期告警: 长期 Proposed X | Provisional 超 30 天 X | 归档候选 X
- 结构告警: 影响范围 > 10 行 X | 状态行超长 X | 缺字段 X | 悬空 Refined/Superseded X
```

**不改** `commands/lint.md` 的其他章节（1-5 / 7-8）；5 条新增均为**机械判定**，不涉门槛类 judgement。

**critical_modules 覆盖说明**：`commands/lint.md` 不在 CLAUDE.md critical_modules 清单，本改动不触发 tester 必派，但 developer 实施时仍需 self-test（跑一轮 lint 确认新检查项不误报）。

### 3.3 skills/architect/SKILL.md 阶段 2 加自问句（DEC-025）

在 `### 阶段 2：落盘 design-docs` 第 8 步前（"新决策 → 追加 decision-log.md"）插入一句：

```markdown
**开立前自问**：该决策是否落入 **§开立门槛 5 类必开**（跨模块接口 / 改 D1-D9 / 新依赖 / 推翻或细化 Accepted DEC / 技术选型 or 数据模型）且 **不踩 Red Flags 负例**？若否，走 commit message / inline post-fix 父 DEC / feedback memory 路径，不开 DEC。
```

**critical_modules 触发**：`skills/architect/SKILL.md` 本体属 critical_modules（CLAUDE.md 声明），本行改动需走 Stage 6 tester + Stage 7 reviewer。

### 3.4 docs/INDEX.md 新增 §决策索引 段（DEC-026）

见 §2.3。

## 4. 关键决策与权衡

### 4.0 子议题 1 门槛方案（D1=A）

| 选择 | 5 类必开 + Red Flags 负例补强（本 DEC）|
|---|---|
| 备选 B | 仅 5 类必开 issue 原版 |
| 备选 C | 纯定性 Nygard 版（"architecturally significant"）|
| 备选 D | 不做 |
| 理由 | 正例 + 负例双维度守护；analyst 失败模式 #1 "LLM 按旧习惯 collapse" 直接缓解；Red Flags 模式借鉴 superpowers `using-superpowers` SKILL.md（analyst FAQ §A3）|

**量化评分**（维度 0-10）：

| 维度 | A ★ | B | C | D |
|---|---|---|---|---|
| 失败模式 #1 缓解度 | **9** | 6 | 3 | 0 |
| 实施简洁度 | 7 | **8** | **9** | **10** |
| 新 DEC 节奏降幅预期 | **8** | 7 | 5 | 0 |
| 未来可修订成本 | 7 | 7 | **8** | 5 |
| **合计** | **31** | 28 | 25 | 15 |

### 4.1 铁律 4 clarification inline post-fix（D2=A 核心项）

**选择**：DEC 落盘后的 tester/reviewer findings / 文本补丁 / 边角场景 id 格式等细化 → **inline append 父 DEC 末尾**并注日期（形如 `**post-fix YYYY-MM-DD（issue #N）**：...`），不新开 DEC 也不另立 Amendment 小节。

**仅当**改动引入新 tradeoff / 新备选评估 / 跨 DEC 语义重构时才开新 DEC。

**实证**：DEC-017 Accepted 2026-04-21 当日即由 tester/reviewer W1/W2/W3 finding 逼出 DEC-019 修补 —— 铁律 4 若当时已立则 DEC-019 全部内容应 inline 到 DEC-017 末尾。

### 4.2 铁律 5 影响范围 ≤10 行（D2=A）

**选择**：自 DEC-009 决定 10 起立规，本次显式化为铁律（而非散在单 DEC 的决定条款）。超出 10 行移至关联 design-doc `## 影响文件清单`。

**不回溯** DEC-013~020。

### 4.3 铁律 6 默认不改清单（D2=A）

**选择**：列出 roundtable 架构稳定边界作为 "新 DEC 默认不改" 的元声明：

- DEC-001 D1-D9
- 5 agent prompt 本体 + 2 skill prompt 本体
- `commands/workflow.md` Phase Matrix / Step 4 / 4b / 5b 事件类 a-d 格式
- critical_modules 机械触发机制
- target CLAUDE.md 业务规则边界
- DEC-002 Escalation JSON schema / DEC-004 Progress event schema / DEC-006 Phase Matrix A/B/C 三分

**新 DEC 影响范围段若未提及**上述项 → 默认视为"不改"，无需每条重复声明。

### 4.4 新状态 Provisional（D2=A）

**选择**：DEC 落盘后默认 Provisional 状态；满足 a) ≥7 日未被修订 OR b) 首次 dogfood run 通过 → 转 Accepted。

**Provisional 期内**：允许直接修订正文（非 post-fix / 非 Supersede），降低 落盘当日补丁 的仪式开销。

**自动化**：`commands/lint.md` 扩 "Provisional > 30 天告警"（见 §3.2）。

**dogfood 自我应用**：DEC-025 本体以 Provisional 入库，本 workflow 结束（Stage 9 closeout）即 first-use dogfood，转 Accepted。

### 4.5 新状态 Refined by DEC-xxx（D2=A）

**选择**：取代当前括注混写（`Accepted（Refines DEC-xxx，非 Supersede）` / `Accepted（Refines DEC-016 §3.3）`），一等公民。

父 DEC 状态行追加 `Refined by DEC-xxx`，**不降级 Accepted**；父 DEC 正文不改。

### 4.6 子议题 3 B.1 DEC 索引段（D3=A / DEC-026）

**选择**：仅做 `docs/INDEX.md` 新增 §决策索引 段；**不改** `skills/architect/SKILL.md:L12` / `agents/reviewer.md:L91` 全读契约。

**观测窗**：30 天（2026-04-22 → 2026-05-22）。观测指标：
1. 子议题 1+2 落地后新 DEC 节奏是否降至 ≤2 DEC/天（analyst 事实基线）
2. architect / reviewer 实测 workflow 是否出现"按索引点进去 Read 相关 DEC" 的 prompt 自我约束行为

**若观测满足**：子议题 3 B.2/B.3（改契约到"索引 + 按需"）转为独立 issue 开 P2。
**若观测不满足**：token 消费持续 ~22.8k/workflow，优先级升 P1。

### 4.7 铁律 7 归档占位（D4=A / DEC-025）

**选择**：立规草稿但**本轮不执行**。

**4 归档触发条件**（全部满足）：
1. 状态为 **Superseded** 或 **Rejected**
2. Superseded ≥ **90 天**
3. 后继 DEC 已 Accepted 且 ≥ **30 天** 无新 Refined / Superseded
4. 无其他 Accepted DEC 在 "相关文档" 段引用本条作为主依据

**归档位置**：`docs/archive/decision-log-YYYY-QN.md`（按季度分文件，永不动）

**主文件 stub 格式**（归档执行时才用）：

```markdown
### DEC-009 [标题]
- **状态**: 部分 Superseded by DEC-010（决定 1）
- **归档**: [archive/decision-log-2026-Q2.md#dec-009](archive/decision-log-2026-Q2.md#dec-009)
```

**精简纪律**：仅允许 a) 归档 stub 化，b) 同父 DEC 的多段 post-fix 合并（保时间戳前缀）。禁改 Accepted 正文 / 删备选段 / 压理由段（revisionist history）。

### 4.8 子议题 1+2 规则融合处理（analyst 观察）

analyst FAQ 观察：子议题 1 的 "clarification 走 post-fix 父 DEC" 与子议题 2 铁律 4 "clarification 统一 post-fix inline" 是**同一规则的两次表述**。

**处理**：在 `## 开立门槛` §4.0 的 "不应开 DEC，走其他路径" 分支表里，**`post-fix clarification` 一行直接引用铁律 4**，不重复表述。单一权威源。

### 4.9 DEC 编号拆分（D5=A）

| DEC | scope | 影响范围估算 |
|---|---|---|
| DEC-025 | 子议题 1+2+4：门槛 + 元规则 + 归档占位 | decision-log.md（元规则区扩容）/ commands/lint.md（+2 检查项）/ skills/architect/SKILL.md（+1 行自问句）/ docs/INDEX.md（design-docs 条目追）/ docs/log.md = **5 行**，满足铁律 5 |
| DEC-026 | 子议题 3 B.1：INDEX DEC 索引 | docs/INDEX.md（+§决策索引段）/ docs/log.md = **2 行**，满足铁律 5 |

两 DEC **不并入同一 commit**（虽然 PR 可合并）；commit 分拆便于后续 Supersede/Revert 独立操作。

## 5. 讨论 FAQ

### Q: Provisional 转 Accepted 的 "首次 dogfood run 通过" 判定源？

A：`/roundtable:workflow` 完整跑一轮 target 项目任务（非 bugfix / 非 lint 简化流程）且无新 post-fix / Supersede，即视为首次 dogfood 通过。本 DEC-025 自身以当前 workflow 为 first dogfood（若本 workflow Stage 5-7 不逼出新修订，则 Stage 9 closeout 之后 Provisional → Accepted）。

### Q: 如果 architect skill 阶段 2 新加的 "自问 5 类" 句被后续 prompt 压缩覆盖怎么办？

A：该行改动触发 critical_modules（`skills/architect/SKILL.md` 属 critical_modules），必走 tester + reviewer。tester 必须覆盖 "architect 跑一轮不提 §开立门槛" 的回归测试。

### Q: Red Flags 负例清单怎么保持不膨胀？

A：Red Flags 本身由门槛反模式实证 + Provisional 期修订驱动。若某条反模式实证率 <1 DEC/季度，下一季度候选移除。本轮初版含 ~6 条反模式，后续季度审查可调整。

### Q: INDEX.md 索引和 decision-log.md 本文漂移怎么办？

A：orchestrator Step 7 每次 A 类 phase-gate 前 flush INDEX.md，若新 DEC 落盘未同步索引视为 Step 7 执行 bug（ref DEC-017 Step 7 Relay contract）。lint 检查项 **6. decision-log 一致性** 可扩 "INDEX 决策索引是否覆盖所有 DEC" 后续 follow-up（本 DEC 不含）。

### Q: 为什么子议题 4 立规不执行？

A：analyst 事实 —— 当前 20 DEC 全 Accepted 或 Refined，仅 DEC-009 部分 Superseded 但 < 90 天（2026-04-19 落盘，距今 3 天），无任何可归档对象。立规 ≠ 立即执行；触发时机由季度审查（lint 扩写告警，见 §3.2）驱动。

## 6. 变更记录

- 2026-04-22 初稿（D1-D5 = A/A/A/A/A）

## 7. 待确认项（交 Stage 4 用户 Design Confirmation 决定）

- [ ] §3.3 architect SKILL.md 阶段 2 加自问句的行位置（插入到第 8 步前 vs 嵌到第 8 步开头子弹）—— 由 developer 决定
- [ ] Red Flags 负例清单的**具体措辞**（§4.0 列 6 条反模式 + 实证案例）—— 由 developer + tester 在实施时精修
- [ ] `Provisional` 状态的 lint 告警阈值（30 天）是否采用 `commands/lint.md` 已有 "Proposed 超 30 天" 阈值同值 —— 由 developer 在 §3.2 实施时对齐
- [ ] DEC-025 / DEC-026 的 commit 顺序（DEC-025 先 or DEC-026 先）—— 由 developer 在 exec-plan 中定
