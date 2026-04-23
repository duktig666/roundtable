---
slug: orchestrator-bootstrap-hardening
source: reviewer (orchestrator relay)
created: 2026-04-22
reviewer: reviewer subagent
verdict: Pass-with-post-fix
---

# 审查报告：orchestrator-bootstrap-hardening（issue #104 / DEC-028）

## Scope 与改动面确认

| 改动面 | 确认 |
|---|---|
| A `hooks/hooks.json` / `hooks/session-start` / `scripts/preflight.sh` | 新建；`chmod +x` OK；三平台分支 JSON 合法；raw-echo-only 契约符 |
| M `commands/workflow.md` | §Step -0 / -1 HARD-GATE prose 行；§Step 3 7 角色派发表；§Step 5b 事件类 a 扩展；§Step 6 rule 4 删除后 5-9→4-8 renumber |
| A `docs/design-docs/orchestrator-bootstrap-hardening.md` | 完整 D1-D5 锁定 + 测试矩阵 + 风险回滚 |
| M `docs/decision-log.md` | DEC-028 Provisional 条目置顶；7 必填字段齐；状态字面值严格；影响范围 5 bullet（铁律 5 合规） |
| M `docs/INDEX.md` / `docs/log.md` | DEC 索引表 + design-docs 段 + `design` / `decide` 双条目同步 |

---

## 审查结果

| # | 维度 | 结果 |
|---|---|---|
| 1 | Design-doc / DEC-028 质量（铁律 5 / 6 / CLAUDE.md 冲突评估）| PASS |
| 2 | Prompt inline ref 纪律（CLAUDE.md #22，0 新括注泄漏）| PASS |
| 3 | 语言规范（prompt 中文 prose / hook 英文注释 / docs 中文）| PASS |
| 4 | 绝对路径 0 命中 | PASS |
| 5 | Step 6 renumber 完整性 | **WARN**（见 W-R01）|
| 6 | Plugin 分发安全（hooks/ + scripts/ 打包）| PASS |
| 7 | Memory 对齐（plugin_vs_claudemd_validation / token_economy）| PASS |
| 8 | 覆盖完整性（Problem 1 + Problem 2）| **WARN**（见 W-R02）|

---

## Findings

### 🟡 Warning

**W-R01 §Step 6 rule renumber 遗留 4 个外部文档引用错位（非自修但语义明显）**

- **复现**：`commands/workflow.md` §Step 6 原 rule 5 = `developer 完成后 lint/test` / 原 rule 6 = `Tester 业务 bug`；renumber 后 rule 4 / rule 5 承载同语义。以下 4 处外部文档仍按旧编号表述 → 逐字读会指到错误 bullet：
  - `docs/design-docs/workflow-auto-execute-mode.md:35` "Step 6 规则 5 报告用户不静默重派"（原指 lint/test，现指 Tester bug）
  - `docs/design-docs/workflow-auto-execute-mode.md:71` "lint 或 test 失败（Step 6 规则 5）"（同上）
  - `docs/testing/phase-transition-rhythm.md:32` "lint/test 执行规则实际在 Step 6 规则 5"
  - `docs/testing/bugfix-rootcause-layered.md:136` "Step 6 规则 5 developer 完成后跑 lint_cmd + test_cmd"
- **影响**：读者追 "Step 6 规则 5" 会落在 Tester bug 描述；`docs/reviews/2026-04-19-phase-transition-rhythm.md:47` 同步 drift（历史 review，append-only 豁免，不必修）
- **Tester T6 blind spot**：T6 仅 grep `rule 9 leftover`，未扫外部 callers。design-doc §风险与回滚表声称 "prompt 本体无残留；历史 docs 引用属 append-only 豁免" —— 但 design-docs / testing 目录下是**活文档**非 append-only 历史，此条风险判据有误
- **post-fix 建议**（两选一，走铁律 4 inline append 至 DEC-028）：
  - **A** 按语义而非编号修上述 4 处（`Step 6 规则 5` → `Step 6 `developer 完成后` rule` 或 §引用锚点）
  - **B** sed 把 4 处的 "规则 5" → "规则 4"、"规则 6" → "规则 5"（机械修号）
- **严重度**：非阻塞；文本 drift 不破坏运行时行为

**W-R02 §Step 3 7 角色派发表与 DEC-023 Accepted 决定 1 不一致：tester / reviewer / dba 形态被收窄为仅 `agent`**

- **证据**：`commands/workflow.md:149-151` 三行形态列写 `agent`（无 `/ inline`）；`developer` 行 `agent / inline（见 §Step 6b）` 正确；DEC-023 决定 1 明文 "tester / reviewer / dba 在 DEC-005 既有 developer 双形态基础上**同样支持 `inline | subagent`**"
- **影响**：表面看与 Accepted DEC-023 drift；未来读者查表会得 "tester/reviewer/dba 只能 subagent" 错误结论；表下脚注仅说 "inline ↔ subagent 切换细节与 research 排除见 §Step 6b"，"research 排除" 对齐 DEC-023 边界但未回补 tester/reviewer/dba 的 inline 可选性
- **post-fix 建议**：表 tester / reviewer / dba 三行形态列改为 `agent / inline（见 §Step 6b）`，与 developer 行对称；DEC-028 inline post-fix 注明对齐 DEC-023
- **严重度**：非阻塞；但属 "新增/改 DEC | 评估与 Accepted DEC 冲突" 环节漏审

**W-R03 T10 hook→sessionContext runtime 路径未经实证（DEFER 无替代 gate）**

- **证据**：tester 报告 T10 `DEFER（待 runtime dogfood）`；design-doc D1 选 A 明言 "dogfood 实证 orchestrator 能看见 `additionalContext` 后再扩范围"；但**当前交付无 post-merge 验证 gate**
- **影响**：若 subagent 不继承主 session 的 `additionalContext`（memory `feedback_plugin_vs_claudemd_validation` 警示模式），`<roundtable-preflight>` 块等于空投；D1 初衷"最小 scope 验证"缺乏闭环
- **post-fix 建议**（择一）：
  - 本 PR 合并前由用户在交互 session 手验一次（reload plugin + 启新会话 grep context）作为 acceptance gate
  - design-doc §风险与回滚补 "merge 后首次 `/roundtable:workflow` 冒烟：orchestrator 若未报 `<roundtable-preflight>` 读到 → 即启 R2 回落并开 follow-up issue"
- **严重度**：非阻塞；回落路径（workflow.md L48 "未见时回落到 env 直读"）存在，最差退化为无 hook 状态

---

### 🔵 Suggestion

- **S-R01** DEC-028 决定 3 "外挂 vs 内嵌判据"第 2 条 "被 ≥2 处调用" 对 `scripts/preflight.sh` 首批略牵强（当前仅 hook + 手动 2 处），未来若仅 hook 单一调用会回归内嵌吗？条款缺 "单一 hook 调用时的倾向"
- **S-R02** `hooks/session-start` L19 error 文案 `scripts/preflight.sh exited non-zero` 丢失 stderr 内容（`2>&1 || echo ...` 在 bash 层 stderr 被 stdout 吞但 `||` 前非零才触发 echo）——排障时 stderr 可能被覆盖；与 tester S-02 同类文案细化
- **S-R03** DEC-028 `备选` 段仅 B/C 无 A 行（与 DEC-025 / DEC-023 风格不一致）—— tester S-03 已提；建议 Provisional 期内 inline 补 "**A** ★（本决定）" 一行

---

### ✅ Positive

- **铁律 5 ≤10 行 影响范围硬约束** DEC-028 仅 5 bullet，PASS
- **铁律 6 默认不改清单自检** §Step 5b 事件类 a 改动限 *source* 列扩展，未触 **格式** 范畴；Phase Matrix / Step 4 / Step 4b 零触碰
- **CLAUDE.md #22 inline ref 纪律** 全工作流 prompt 文件 `(DEC-028)` / `（DEC-028）` 括注 0 命中；DEC 锚点仅出现在 §Step -0 HARD-GATE 的 `docs/design-docs/...` 跳转（白名单）；lint baseline 42→42 零回升
- **DEC-001 D1 plugin 分发** `.claude-plugin/plugin.json` 无需新增 hooks 字段（Claude Code 约定自动发现 `hooks/hooks.json`；superpowers 5.0.7 plugin.json 同无 hooks 字段对照实证）；moongpt-harness 打包路径对 `hooks/` + `scripts/` 顶层目录天然兼容
- **memory 对齐** DEC-028 D1 理由显式引 `feedback_plugin_vs_claudemd_validation`，D5 引 `feedback_roundtable_token_economy`；硬边界 `feedback_roundtable_auto_mode_source` 被 hook context HARD-GATE 勒行加固
- **Problem 1 (auto_mode) 解** hook 注入 raw env + §Step -0 HARD-GATE prose + 不把更高层 harness Auto Mode 提示误解声明 = 三层防御
- **Problem 2 (analyst-subagent) 解** §Step 3 派发表首引入 + skill/agent 语义白名单 + HARD-GATE 跳转指针

---

## Verdict

**Pass-with-post-fix**

- 0 Critical：核心 hook / DEC / design-doc / workflow 结构改动全面 PASS；Problem 1 + 2 双重覆盖
- 3 Warning：W-R01 外部 docs rule 号 drift（4 处）属 renumber 审计漏扫；W-R02 §Step 3 派发表与 DEC-023 不一致（3 行需补 `/ inline`）属 Accepted DEC 冲突漏评；W-R03 T10 runtime DEFER 无替代 gate
- 3 Suggestion：外挂判据边界 / hook error 文案 / DEC-028 备选 A 显式

所有 Warning 均非阻塞；W-R01 / W-R02 均为 minutes-of-edits 级 post-fix（走铁律 4 inline append 父 DEC-028）；W-R03 可选择 merge 前冒烟 OR 落入 follow-up。

---

## Follow-ups

- **F1**（W-R01 post-fix）：按语义修 4 处外部 rule 5 引用 → DEC-028 inline 注
- **F2**（W-R02 post-fix）：§Step 3 派发表 tester / reviewer / dba 三行补 `/ inline（见 §Step 6b）` → DEC-028 inline 注对齐 DEC-023
- **F3**（W-R03 merge 后）：首次 workflow 冒烟 orchestrator 是否读到 `<roundtable-preflight>` 块；未读则即启 R2 + 开 follow-up issue
- **F4**（S-R02 follow-up issue）：hook error 文案分 `missing` / `not executable` / `exited non-zero` 三枝 + stderr preserve
