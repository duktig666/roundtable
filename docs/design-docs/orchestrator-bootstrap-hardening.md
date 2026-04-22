---
slug: orchestrator-bootstrap-hardening
source: 原创（issue #104，supersedes issue #89）
created: 2026-04-22
status: Design
---

# Orchestrator Bootstrap Hardening 设计文档

## 目标

解决 `/roundtable:workflow` 编排器两类 cold-start 误判：

1. `auto_mode` 被错当成 Claude Code harness "Auto Mode Active" 系统提示的同义
2. `analyst` / `architect` 被错派为 subagent（`Agent type not found`）

L1 memory 层已在（`feedback_roundtable_auto_mode_source` / `feedback_skill_vs_agent_dispatch` 等）；本 L2 层在 `commands/workflow.md` 与 plugin 资产层回写可观测锚点，替代 shelved PR #103 的 inline Bash 方案。参考 superpowers 5.0.7 的 SessionStart hook + scripts/ 外挂模式。

## 架构决策

### D1 — SessionStart hook 作用域：保守最小范围

**选 A**：先引入最小 hook，仅向 `sessionContext` 注入 raw env 值 + HARD-GATE 指令，dogfood 实证 orchestrator 能看见 `additionalContext` 后再扩范围。

**理由**：memory `feedback_plugin_vs_claudemd_validation` 警示 subagent 继承不等同于主 session；从最小 scope 起步降低未知风险。

### D2 — `scripts/` 目录约定：开新 DEC-028 Provisional

**选 A**：开 DEC-028 确立 `scripts/` 顶层目录为 plugin-level shell 脚本外挂地；与 `commands/*.md` 内 §3.5.1-style 内嵌 bash 并存，按"脚本复用度 / 测试独立性"判据挑选哪些外挂。

**理由**：首次在 roundtable 引入新目录约定，命中 DEC-025 铁律 4 新 DEC 正例（新备选路径 / 新 tradeoff）。

### D3 — raw echo vs resolved 值

**选 A**：hook 与 scripts 只输出 raw env，不解算 CLI 优先级。resolved 值由编排器 LLM 按 §Step -0 / §Step -1 既定优先级在运行时解算。

**理由**：CLI flag 读取路径在 Claude Code / Cursor / Codex / Gemini 各 harness 不统一（见 superpowers hook 的平台分支）；env 读取是最小共集稳定路径。

### D4 — HARD-GATE 样式：inline prose，不引入自定义块

**选 A**：§Step -0 / §Step -1 章首追加一行 HARD-GATE prose 标记，不引入 superpowers 的 `<HARD-GATE>` 自定义块。

**理由**：roundtable `commands/*.md` 以 prose 为主，新增自定义块语法成本超过本期收益。

### D5 — 7 角色 Skill/Agent 派发表位置

**选 A**：`commands/workflow.md` §Step 3 起首追加 7 角色派发映射表；§Step 6 原 rule 4 `角色形态` bullet 删除，后续 rules 5-9 → 4-8 renumber。与 shelved PR #103 同位；**research** 行补入。

**理由**：单一权威节契合 memory `feedback_roundtable_token_economy`。

## 产出清单

- `hooks/hooks.json` — SessionStart 触发注册
- `hooks/session-start` — hook 主脚本，delegate 给 `scripts/preflight.sh`
- `scripts/preflight.sh` — raw env echo，hook / 手动均可调用
- `commands/workflow.md` 编辑 — §Step -0/-1 HARD-GATE / §Step 3 映射表 / §Step 5b 事件类 a scope / §Step 6 rule renumber
- `docs/decision-log.md` — DEC-028 Provisional
- `docs/INDEX.md` + `docs/log.md` — 同步索引

## 测试矩阵（交付 tester）

| # | 场景 | 预期 |
|---|---|---|
| T1 | 新会话 `ROUNDTABLE_AUTO` 未设 | `hooks/session-start` 输出 JSON 含 `ROUNDTABLE_AUTO=<unset>` |
| T2 | `ROUNDTABLE_AUTO=true` | echo 读到 `true` raw 值 |
| T3 | `ROUNDTABLE_AUTO=""` 空串 | echo sentinel 合并为 `<unset>`（bash `:-` 行为），LLM resolve 为 false（§Step -0 空串视 false 同落点） |
| T4 | `scripts/preflight.sh` 独立调用 | stdout 3 行契约符合 |
| T5 | §Step 3 派发表 | 7 行含 `research`；§Step 6 旧 rule 4 删除 |
| T6 | §Step 6 renumber | rules 4-8 连续无漏号 |
| T7 | §Step 5b 事件类 a scope | 描述含 Step -0/-1 pre-flight echo 来源 |
| T8 | `lint_cmd` | 0 命中 |
| T9 | hook / scripts 权限 | `chmod +x` 已置 |
| T10 | dogfood E2E | 下次 workflow 启动能从 session context 读到 `<roundtable-preflight>` 块（或 hook 未触发时回落路径清晰） |

## 风险与回滚

| 风险 | 回滚 |
|---|---|
| hook 注入的 context 进入 session 但未传给 skill runtime | 删 `hooks/hooks.json`，回落到 §Step -0/-1 env 直读，重新评估 R2 方案 |
| `scripts/` 分发与 moongpt-harness 打包不兼容 | scripts 内容并入 hooks/ 私有，放弃公开 scripts/ 约定 |
| §Step 6 renumber 影响外部引用 | review 阶段已修 4 处 drift：`workflow-auto-execute-mode.md` / `phase-transition-rhythm.md` / `bugfix-rootcause-layered.md` |

**DEC-028 Provisional 转 Accepted 的验收门槛**（回应 reviewer W-R03）：

1. 下一次 `/roundtable:workflow` 冷启动在 session context 中能读到 `<roundtable-preflight>` 块（hook 真触达 orchestrator）
2. 读取后 §Step -0 / §Step -1 解算结果与 hook raw echo 一致（不被更高层 harness 信号污染）
3. `scripts/preflight.sh` 手动 invoke 输出契约稳定 ≥1 次

三条满足 → Provisional 转 Accepted；任一失败 → 回落 R2 `inline Bash` 方案（shelved PR #103 可复活）。Dogfood 观察窗：本 PR merged 后 7 日 / 或首个用到 workflow 的后续 issue 闭环。

## 非目标

- 不改 Phase Matrix 9 阶段语义
- 不重做 L1 memory 层
- 不尝试解决 "subagent 内无 Agent 工具" 原生限制
- 不引入 superpowers 作为运行依赖（仅参考模式）

## 参考

- shelved PR #103 — inline Bash 方案留作回滚候选
- superpowers 5.0.7 `hooks/session-start` / `hooks/hooks.json` / `skills/*/scripts/` 模式
- issue #104（本 issue）/ issue #89（supersedes）
