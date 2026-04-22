---
slug: batch-97-dogfood-findings
created: 2026-04-22
status: Fixed
severity: minor
related_issue: #97
related_dec: DEC-011 / DEC-025 / DEC-026
---

# #84 DEC-025/026 落盘后 dogfood findings batch follow-up Postmortem

## 1. 现象

`/roundtable:workflow` 对 issue #84（DEC-025 / DEC-026 sustainability umbrella）的 Stage 6/7 产出 9 Warning + 6 Suggestion；其中 6 条属可机械落实的 follow-up（原拟拆 #91~#96 六条 issue，按用户 #717 指示合并为 #97 batch）。发现项未阻塞落盘但留下 5 处"弱声明 / 漏字段 / 引用漂移"，若不补会在下一轮 dogfood 时回放。

## 2. 根因

DEC-025 落盘同时触发了多处耦合，导致以下五类残留：

| 编号 | 根因 | 位置 |
|------|------|------|
| F1 | L6.3 字面值检查没涵盖"新 DEC 必带 Provisional 首值" —— DEC-025 决定 5 引入 Provisional 状态但 lint 侧未加时间窗判定 | `commands/lint.md` L6.3 |
| F2 | 铁律 4 对 "新 tradeoff 才开新 DEC" 没说 tradeoff 的判定 / 升级路径，architect 与 reviewer 分歧时无默认裁决人 | `docs/decision-log.md` §铁律 4 |
| F3 | DEC-025 决定 8 在 `skills/architect/SKILL.md` §阶段 2 第 8 步前插入自问句，使 DEC-011 正文 "§阶段 2 第 8 步" 字面指代变化（原指追加 decision-log，现指门槛自问句） | `docs/decision-log.md` DEC-011 |
| F4 | L6.1-L6.5 有重复的 code-fence 感知 / regex 约束 / grandfather 声明，编辑成本高且易漂移 | `commands/lint.md` §6 |
| F5 | reviewer `§审查维度` 只有 Critical/Warning/Suggestion 三级严重度，无 DEC-025 §开立门槛的专项检查维度 | `agents/reviewer.md` §审查维度 |

均非实现缺陷，而是元规则落盘时的信息完整性 / 一致性漏洞 —— 属 DEC-014 §Tier 2 的"critical_modules 命中"分类（F5 动 `agents/reviewer.md` 本体）。

## 3. 修复

5 项改动，单 PR：

- **F1**：`commands/lint.md` L6.3 补 "新 DEC（落盘日 ≤ 7 天）状态行必须起首 `Provisional`" 告警项，判定依据 DEC `**日期**` vs 当前日期差 ≤ 7 天
- **F2**：`docs/decision-log.md` §铁律 4 后追加 `**post-fix 2026-04-22（issue #97 F2）**` 段，明确 tradeoff 判定归属（architect 主张 / reviewer 终审 / 分歧升用户 AskUserQuestion）
- **F3**：`docs/decision-log.md` DEC-011 正文末追加 `**post-fix 2026-04-22**` 段，说明 §阶段 2 第 8 步字面漂移到 step 9，语义锚点不变
- **F4**：`commands/lint.md` §6 提取 `**实施共性**（L6.1-L6.5 共用）` preface 段含 3 共用条款（code-fence 扫描 / `DEC-\d{3}` regex / grandfather DEC-001~020），各子节去掉重复条款。L6.2 自有 DEC-013~020 范围 + L6.4 悬空引用例外在 preface 显式保留
- **F5**：`agents/reviewer.md` §审查维度 在 🔴/🟡/🔵 三级严重度前追加 "门槛合规（DEC 专项）" 检查 —— 新 DEC 是否命中 §开立门槛 5 类必开 + 不踩 Red Flags；严重度由 reviewer judgement 归类

## 4. 复现步骤

无独立回归测试（纯文档元规则改动）。等价复现：

1. 下一轮任意 roundtable 自身 `/roundtable:workflow` 写新 DEC 时，`commands/lint.md` §6 L6.3 会自动扫 Provisional 首值
2. DEC-011 正文读者从 "§阶段 2 第 8 步" 跳转时，post-fix 指示按 step 9 理解
3. reviewer 遇 PR 改 `decision-log.md` 新 DEC 段时，按新增 §审查维度 "门槛合规" 检查

lint_cmd 硬编码扫描 0 命中验证：`grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/` → 0 match

## 5. 验证

- **lint_cmd**：0 match（roundtable 自家 lint，纯硬编码扫描）
- **diff 规模**：3 files changed, 14 insertions(+), 5 deletions(-)（initial） → 含 F5/F2 advisor 反馈后调整
- **critical_modules 命中**：F5 `agents/reviewer.md` 本体 → reviewer 自审（inline 形态，见 §6 后续动作）
- **advisor 审查**：对 F5 初版"严重度映射（Red Flags→Critical / 5 类不命中→Warning）"指出为 scope creep，已删；F2 格式对齐 DEC-011 post-fix 样式

## 6. 后续动作

- **观察项 #94**（issue #97 保留的独立观察）：Refined by first-use validation —— 等下个 Refines 类 DEC 落盘时验证 Provisional + 父 DEC 状态行加 `Refined by` + lint L6.4 不悬空三者链路
- **follow-up**：本 batch 合并 `#91 / #92 / #93 / #95 / #96`，闭 #97；`#94` 保留独立观察
- **DEC 候选**：无；本批纯 clarification 走铁律 4 inline post-fix，不新开 DEC

## 7. 变更记录

| 日期 | 改动 | 操作者 |
|------|------|--------|
| 2026-04-22 | F1-F5 初版落盘（3 files） | orchestrator (inline developer) |
| 2026-04-22 | advisor 反馈：F5 scope 收敛；F2 格式与 DEC-011 post-fix 对齐 | orchestrator |
