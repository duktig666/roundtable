---
slug: orchestrator-preflight-hardening
source: reviewer (inline, orchestrator-driven)
created: 2026-04-22
reviewer: reviewer inline（subagent dispatch tool unavailable in this session）
---

# 审查报告：orchestrator-preflight-hardening（issue #89）

## Scope 与改动面确认

| 改动面 | 改动 | 符合 design-doc |
|--------|------|-----------------|
| `commands/workflow.md` §Step -1 末尾 | 追加 Pre-flight Bash echo 块 + resolved 模板 + 输入源纪律 + env 全默认不转发规则 | ✅ 与 §2.2 / §2.3 原文一致 |
| `commands/workflow.md` §Step 3 起首 | 标题改 "Slug、角色形态与 Artifact Handoff" + 7 行表格 + 1 句 prose | ✅ 与 §3.1 / §3.2 / §3.3 原文一致；含 research 行（§3.2 表最后一行） |
| `commands/workflow.md` §Step 6 | rule 4 原 2 行 bullet 删除 + rule 5-9 顺延为 4-8 | ✅ 与 §3.3 原文一致；保留 §Step 6b 不动（§3.3 明示） |
| `commands/workflow.md` §Step 5b 事件类表 a 行 | 事件列 + 来源列扩 Step -0/-1 pre-flight echo；格式列 markdownv2 不变 | ✅ 与 §4 原文一致；b/d/e 行未动（#88 领地保护） |
| `docs/INDEX.md` | 新增 design-docs + testing 两条 | ✅ |
| `docs/log.md` | 新增 impl + test-plan 两条 | ✅ |

---

## 🔴 Critical

**无。**

---

## ⚠️ Warning

### W-R01 历史 docs/ 4 份文档中 "Step 6 rule 5" / "规则 5" / "rule 5-6" 未回溯

- **文件**：
  - `docs/analyze/orchestrator-preflight-hardening.md`（本 PR 新增；内部自述 §Step 6 rule 4 现址 line 382-384，反映编辑**前**状态，正确）
  - `docs/testing/bugfix-rootcause-layered.md:136`（引 "Step 6 规则 5 developer 完成后跑 lint_cmd"）
  - `docs/design-docs/workflow-auto-execute-mode.md:35,71`（2 处引 "Step 6 规则 5" "Step 6 规则 5" 指 lint+test 失败）
  - `docs/reviews/2026-04-19-phase-transition-rhythm.md:47`（引 "Step 6 规则 5 和规则 6"）
  - `docs/testing/phase-transition-rhythm.md:32`（引 "Step 6 规则 5 lint/test / 规则 6 tester 业务 bug"）
- **判定**：**Warning，非 Critical**。这些是 append-only 历史文档，记录当时 prompt 本体的状态；按 roundtable "不回溯" 纪律（DEC-025 决定 10）豁免。Plugin 本体（`commands/` / `skills/` / `agents/`）已 0 命中
- **规避建议**：future FAQ 可加一条"rule 5 / rule 6 在 issue #89 后分别为 rule 4 / rule 5"记注；本 PR 不处理
- **状态**：不 block；记录为 S 类 follow-up 或忽略

### W-R02 多行 `$ARGUMENTS` 视觉溢出（tester A3 发现）

- **情形**：`$ARGUMENTS` 含 `\n` 时，`echo "PREFLIGHT raw_args=$RAW_ARGS"` 会产生终端视觉多行输出
- **影响**：终端 grep `^PREFLIGHT raw_args=` 仍可锚定第一行；TG 转发的 markdownv2 bullet 合并为单反引号字段（DEC-022 格式约束），无破坏性
- **判定**：设计特性，不 block；可作为 future Bash 块优化的记录点（`tr '\n' '⏎'` 或 `printf "%s\n"` 单行化）

---

## 💡 Suggestion

### S-R01 Pre-flight Bash 块可加 `set +u` 防御

- 当 shell 以 `set -u` 启动时，`${var:-<unset>}` 已兜底，但显式 `set +u` 头行更稳
- 小改动，follow-up 即可；非 block

### S-R02 design-doc §6 tester handoff 场景与本 PR tester 矩阵对齐度检查

- tester 矩阵 T1-T5 完整覆盖 design-doc §6 场景 1-5 ✅
- 对抗场景 A1-A3（env 空白 / CLI vs env 冲突 / 多行 $ARGUMENTS）orchestrator brief 要求全覆盖 ✅
- 回归场景 R1-R5 覆盖 lint / plugin rule ref / Phase Matrix / §5b b/d/e / DEC 语义不破 ✅
- 无额外 gap

---

## 🟢 Positive

- **P-R01 单一权威节纪律** — §Step 3 表格 + §Step 6 rule 4 删除，消散点重复，符合 `feedback_roundtable_token_economy.md`（单一权威节 / 表格优于 bullet）与 #22 行内 DEC/issue 引用纪律
- **P-R02 无新 DEC 自洽** — DEC-025 §开立门槛 5 类自检 0 命中；L1 memory 已固化规则源，L2 仅 prompt 回写
- **P-R03 #88 领地保护完整** — git diff 仅改 §Step -1 / §Step 3 / §Step 6 / §Step 5b 事件类 a 行；§Phase Matrix 定义段、§Step 5b b/d/e 尾段、DEC-024 单行进度条均未触
- **P-R04 §Step 3 表格含 research 行** — memory `feedback_skill_vs_agent_dispatch` 原定义 7 角色全覆盖（含 research），修补了原 §Step 6 rule 4 bullet 遗漏 research 的缺陷（design-doc §3.2 F5 纪律）
- **P-R05 CLAUDE.md 行内引用纪律** — 新表格 + prose 使用 `§Step 6b` 形式 § 引用，不嵌 `（DEC-xxx）` / `issue #89` 括注；符合 #22 纪律
- **P-R06 lint_cmd 0 命中** — `skills/` + `agents/` + `commands/` 目标项目名与外部路径扫描 0 命中

---

## Verdict

**Pass** — 可直接进入 Stage 9 Closeout。

- 0 Critical
- 2 Warning（W-R01 历史 docs 豁免 / W-R02 多行设计特性）均不 block
- 2 Suggestion（S-R01 `set +u` 防御 / S-R02 矩阵对齐已验）均非 block

## 变更记录

- 2026-04-22：初版，inline 审查（subagent dispatch 工具缺失本 session）；design-doc ↔ diff 逐行核对；lint 0；plugin 本体无 rule 5-9 数字残留

created:
  - path: docs/reviews/2026-04-22-orchestrator-preflight-hardening.md
    description: "issue #89 reviewer inline 审查；verdict Pass；0 Critical；2 Warning（W-R01 历史 docs 编号豁免 / W-R02 多行 $ARGUMENTS 设计特性）；2 Suggestion（S-R01 set +u / S-R02 矩阵对齐已验）；6 Positive"

log_entries:
  - prefix: review
    slug: orchestrator-preflight-hardening
    files:
      - docs/reviews/2026-04-22-orchestrator-preflight-hardening.md
    note: "issue #89 reviewer inline 审查 verdict Pass；0 Critical；design-doc ↔ diff 逐行核对；#88 领地保护完整；lint 0"
