---
slug: decision-log-sustainability
source: reviewer (orchestrator relay)
created: 2026-04-22
reviewer: reviewer subagent
---

# 审查报告：decision-log-sustainability（issue #84 / DEC-025 + DEC-026）

## Scope 与改动面确认

| 改动面 | 确认 |
|---|---|
| M `docs/decision-log.md` | 元规则区 + §开立门槛 + 铁律 7 + DEC-025/022 Provisional 正文 + DEC-025 post-fix block（L152-L158） |
| M `commands/lint.md` §6 | L6.1-L6.5 + 统计段扩（含 F3/F4 post-fix grandfather + code-fence skip） |
| M `skills/architect/SKILL.md` Stage 2 **critical_modules** | step 8 自问句 + step 11 renumber + L71 去"11."号（F1/F2） |
| M `docs/INDEX.md` | §决策索引 23 row 表 |
| M `docs/log.md` / new 4 .md | 未直接核查全部，但交叉引用链从 INDEX / decision-log / exec-plan / testing 间走通 |

---

## 🔴 Critical

**C-R01 `docs/decision-log.md` L158-L159 之间 DEC-020 header 被 F1/F2 post-fix 误删（结构性损坏，违反铁律 1 "不删除旧条目"）**

- **复现**：`grep -cE "^### DEC-[0-9]+"` 得 22（应 23）；DEC-020 header 缺失
- **根因**：post-fix F1/F2 Edit 的 new_string 遗漏 `---` 分隔符 + `### DEC-020 ...` header；old_string 包含了这两行但 new_string 未补回
- **影响**：(1) 违反铁律 1；(2) DEC-020 不可被 `grep '^### DEC-020'` 寻址；(3) exec-plan P0 成功信号未达；(4) L6.5 必填字段扫描对 DEC-020 无法定位；(5) DEC-016/DEC-020 Refines 语义链断裂；(6) L159 `日期` 行归属被 LLM 误读为 DEC-025 一部分
- **状态**：**已修复**（orchestrator relay 期间 developer inline 补 `---` + DEC-020 header，`grep` 恢复 23）；DEC-025 正文末追加 post-fix block 记注（`**post-fix 2026-04-22（reviewer Critical C-R01）**`）
- **规避建议**：post-fix 接在 DEC 正文末段时，Edit old_string 必须包含下一 DEC 的 header + 分隔符以 preserve 边界；或 Edit 前先 Read 校验目标锚点

---

## 🟡 Warning

**W-R01 `docs/INDEX.md` §决策索引 实际 4 列 vs design-doc §2.3 + DEC-026 决定 1 均写明 5 列**

- **证据**：INDEX.md L48 `| DEC | 标题 | 状态 | 相关 slug |`（4 列）；design-doc L112 5 列；DEC-026 决定 1 指定 5 列
- **影响**：设计 ↔ 实现 drift；DEC-026 决定 1 正文 unfulfilled
- **修复建议**：二选一
  - (a) INDEX.md 加 "相关文件" 第 5 列（23 行每行补路径）
  - (b) DEC-026 inline post-fix 收紧到 4 列（+ design-doc §2.3 同步修订）；成本低且符合铁律 4 心智

**W-R02 DEC-026 决定 3 "orchestrator 维护" vs exec-plan P3 由 developer 直写 — 首次建立契约冲突**

- **证据**：DEC-026 决定 3 明文 "architect/reviewer 不直接编辑 INDEX.md"；exec-plan P3 由 developer 直写
- **影响**：首次建立路径违反 DEC-026 决定 3；Provisional 首轮 dogfood 语义上未达
- **修复建议**：DEC-026 inline post-fix 加 "首次建立本索引段由 developer 一次性填充；后续增量由 orchestrator 在 A 类 phase-gate 前追加"

**W-R03 DEC-025 决定 6 "Refined by DEC-xxx 一等公民" 未对现有父 DEC 状态行补充（不回溯合规但 first-use 验证缺）**

- **证据**：本轮无父 DEC 状态行被补 `Refined by DEC-xxx`
- **影响**：Provisional → Accepted 判据 "首次 dogfood run 通过" 对决定 6 尚无证据
- **修复建议**：Stage 9 closeout 前文字声明此观察；或下一个 Refines 类 DEC 落盘时验证

**W-R04 DEC-025 决定 10 正文"跳过 DEC-013~020"vs lint.md L6.3/L6.5 实施"DEC-001~020 全 grandfather"范围不一致**

- **证据**：decision-log L142 "跳过 DEC-013~020"；lint.md L80/L102 "DEC-001 ≤ NNN ≤ DEC-020"
- **影响**：正文 ↔ 实施 gap；post-fix 扩大范围是否构成"新 tradeoff"边界模糊
- **修复建议**：DEC-025 决定 10 正文 inline 加一行 "（L6.3/L6.5 实施层对 DEC-001~020 全 grandfather）" 消解 gap

**W-R05 DEC-025 post-fix block 位置 + C-R01 根因关联**

- **证据**：post-fix block 在 "影响范围" 之后属"末尾"（铁律 4 合规），但缺 `---` 分隔符收尾；与 DEC-020 body 粘连 → C-R01 的次级证据
- **修复建议**：C-R01 fix 同时补 `\n---\n`（本轮恢复时已补）

---

## 🔵 Suggestion

- **S-R01** exec-plan P0 成功信号未跑 `grep -c` 校验即勾 `[x]`（眼测漏 C-R01）→ 成功信号章节要求跑脚本而非眼测
- **S-R02** design-doc §7 `[ ]` 4 条待确认项未勾 `[x]`（tester S-05 已标）→ developer Stage 5 落盘时勾 `[x]` + 记实际选择
- **S-R03** lint L6.5 "实施硬约束" 和 "不回溯 grandfather" 两行被 bullet 稀释 → follow-up 将二者提为 §6 顶部统一 preface 段
- **S-R04** DEC-025 决定 9 "门槛类 judgement 留 architect/reviewer" 未在 reviewer.md 落点 → DEC-026 观测窗内 follow-up 扩写 reviewer.md §Review 维度（或 YAGNI 跳过）
- **S-R05** post-fix block 无 issue URL（与 DEC-013/014 历史风格一致但 lint 扩引用完整性会命中）→ follow-up

---

## 跨 DEC 一致性审计

| DEC | 与 DEC-025/022 的一致性 |
|---|---|
| **DEC-001** D1-D9 | 铁律 6 显式列 → ✅ 对齐 |
| **DEC-006** A/B/C 三分 | 铁律 6 显式列 → ✅ 对齐 |
| **DEC-011** 决定 1 引 SKILL L59 "§阶段 2 第 8 步" | step 8 内容已变；不回溯（铁律 6）但 DEC-011 可读性下降 → 未来 editorial post-fix 加 caveat |
| **DEC-013** §3.1a / DEC-018 / DEC-020 | DEC-025 决定 10 不回溯 → ✅ 对齐 |
| **DEC-015** `--auto` / auto_mode | 不回溯保 DEC-015 不变 → ✅ |
| **DEC-016** §Step 4b / DEC-020 Refines | C-R01 修复后语义链恢复 → ✅ |
| **DEC-017** Amendment + F4 post-fix grandfather | F4 显式注 "DEC-017 Amendment 缺 `**相关文档**` 属历史 grandfather" → ✅ |
| **DEC-019** Relay 契约收紧 | 本 workflow 若 Step 7 orchestrator relay 顺承 → Provisional 落盘前修 W-R02 更佳 |
| **铁律 6 "默认不改清单"** | DEC-025 影响范围 L150 显式声明 "skills/architect/SKILL.md Stage 2"（critical_modules 命中）→ ✅ 破例声明到位 |

---

## 总结

- **verdict**：**Pass-with-post-fix**（C-R01 已修；W-R01/W-R02 建议落盘前修，其余 Warning/Suggestion 可 follow-up）
- **主要关注点**：
  1. post-fix block 紧邻前后 DEC 条目时易引入 header 误删 → 建议 lint 补 `L6.0 "### DEC-NNN 连续编号 + 数量校验"` follow-up
  2. Provisional Day-0 dogfood 判据 "无新 post-fix" 已被本轮 post-fix 引入 C-R01 实证空洞 → DEC-025 决定 5 可追加 "post-fix 本身不引入结构性 regression" 作为转正必要条件
  3. DEC-025 / DEC-026 核心设计方向正确，失败模式为执行细节 + 工程卫生，不构成架构级回调

---

## 变更记录

- 2026-04-22 初稿 reviewer 审查（1 Critical + 5 Warning + 5 Suggestion；verdict Pass-with-post-fix 前 Block pending restore，C-R01 修复后降级）
