---
slug: dec016-auto-halt-text-render
source: issue #61
created: 2026-04-21
status: Accepted
decisions: [DEC-020]
description: DEC-016 follow-up —— `decision_mode=text` + `auto_mode=true` 且 batch 任一 question 缺 `recommended` 时 auto-halt 的渲染形态命名（3 条澄清：render 顺序 audit-first / forwarding 1 audit + N blocks / fallback 块 id `batch-<slug>-<n>-q<m>`）。Refines DEC-016 §3.3 + §Step 4b Auto_mode 段 + §Step 5b 事件类 e。
---

# DEC-016 Auto-halt Text-mode Render 设计文档

## 1. 背景

Tester S-03（PR #58, `docs/testing/parallel-decisions.md`）identified 一处契约未定义：当 `decision_mode=text` + `auto_mode=true` 同时成立、且 §Step 4b 批量决策中任一 question 缺 `recommended` 时，§Auto-pick 规则要求整组 auto-halt 并降级走 text mode 的 `<decision-needed>` 块 fallback。但以下三点未明示：

1. audit 行（`🔴 auto-halt batch-<id>`）与 N 个 fallback `<decision-needed>` 块的 **render 顺序**
2. Active channel 转发时这两类 artifact 的 **fan-out 语义**（单 reply 合并 / 多 reply 独立）
3. fallback `<decision-needed>` 块的 **id 命名**（保留 batch 前缀 / 退化为 single slug / 混合形态）

issue #61 P3 本设计补齐，Refines DEC-016（§3.3 auto_mode 交互），不 Supersede。

## 2. 决策

### 2.1 Clarification 1 — Render 顺序：audit-first

**决定**：auto-halt 触发时，orchestrator 先 emit audit 行（`🔴 auto-halt batch-<id>: no recommended option at [q_k, ...]`），后 emit N 个 fallback `<decision-needed>` 块。块间沿用 DEC-013 §3.1.1 多块串行语义。

**理由**：self-evident —— audit 行是事件因由（为何 halt），`<decision-needed>` 块是兜底 UI（请用户回答）；先因后果符合日志/对话可读性；与 §Step 5b 事件类 d+e 合并 reply 的「audit 行在前、transition 在后」语序一致。未形式化 options。

### 2.2 Clarification 2 — 转发 fan-out：1 audit + N blocks

**决定**：Active channel（sticky）下，auto-halt audit 行按 §Step 5b 事件类 e 规则转发为**单条** `markdownv2` 粗体 reply；N 个 fallback `<decision-needed>` 块按 DEC-013 §3.1a（DEC-018 松弛语义）**逐块独立** pretty markdownv2 reply，每块保留 `id` / `question` / `option label` 三字段不改写。共 `1 + N` 条 reply。

**理由**：self-evident ——（a）与 §Step 4b batch `decision_mode=text` 既有规则「每块独立 reply 不合单 payload」同构；（b）合并 audit + blocks 会超 TG 4096 字符上限风险 / 破坏每块 sticky 回复锚点；（c）audit 属事件类 e 格式，`<decision-needed>` 属 §3.1a 规则，两者来源不同不应强合并。未形式化 options。

### 2.3 Clarification 3 — Fallback 块 id 格式：`batch-<slug>-<n>-q<m>`

**决定**：fallback `<decision-needed>` 块 id = `batch-<slug>-<n>-q<m>`，其中：
- `<slug>` = 本轮 issue / 任务 slug（与 batch id 同源）
- `<n>` = 同 slug 下本轮 batch 序号（batch id 根部分）
- `<m>` = batch 内 question 0-based 或 1-based 索引（与 orchestrator 内部 per-question 解析对齐；推荐 1-based 以匹配人类计数）

示例：`batch-auto-halt-text-61-1-q1` / `batch-auto-halt-text-61-1-q2` / `batch-auto-halt-text-61-1-q3`。

**备选**：
- A（本决定）hyphen-suffix 保 batch id 根部：`batch-<slug>-<n>-q<m>` —— 单 grep `^batch-<slug>-<n>-` 拉齐整组；q<m> 后缀明示「batch 的第 m 问」；与现行 `batch-<slug>-<n>` batch id 无歧义前后缀关系
- B slash-path 分层：`batch-<slug>-<n>/q<m>` —— 可读性高但 `/` 与文件路径语义冲突、log grep 正则字符须转义
- C 退化 single slug：`<slug>-<n>-q<m>`（丢 batch 前缀）—— 丢失 batch 归属信息、grep 无法区分单问 escalation 与 batch 降级问

**理由（D3=A）**：用户延迟到 auto-mode → per A 星推荐自动选 A。hyphen-suffix 保 batch id 根部可 grep 对齐、与现行 batch id `batch-<slug>-<n>` 前缀兼容、无 `/` 转义负担、`q<m>` 后缀语义明确。

## 3. 落地

### 3.1 `commands/workflow.md` 改动点

- **§Step 4b Auto_mode 段（行 265 附近）**：append 3 clarification 子句——render 顺序 audit-first / forwarding 1 audit + N blocks / fallback id 格式 `batch-<slug>-<n>-q<m>`
- **§Step 5b 事件类 e 表格行（行 295 附近）**：扩写「auto-halt」case——audit 行走 markdownv2 单行 + 随后 N 个 fallback `<decision-needed>` 块按 §3.1a 逐块独立 pretty reply（1 + N reply）

### 3.2 不改

- DEC-016 其他 Accepted 决定（D1=B / D2=A / D3=A 失败处理 / max_concurrent=3）
- DEC-013 §3.1a sticky 语义、DEC-018 pretty markdownv2 松弛
- §Step 5b 事件类 a / b / c / d 格式（本轮 scope 外）
- 4 agent prompt 本体 / Phase Matrix / critical_modules 触发
- target CLAUDE.md

### 3.3 影响

orchestrator runtime 在 `decision_mode=text` + `auto_mode=true` + batch 任一缺 recommended 路径上：stdout emit 1 audit 行 + N 个 `<decision-needed id="batch-<slug>-<n>-q<m>">` 块；active channel reply 1 + N 条。用户自由文本回复走 §Step 4b per-question fuzzy parse 分派（已答推进，cancel/歧义单独重问）。

## 4. 变更记录

- 2026-04-21（issue #61 DEC-020）：初版，3 clarifications 落定
