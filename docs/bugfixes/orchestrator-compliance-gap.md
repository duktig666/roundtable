---
slug: orchestrator-compliance-gap
tier: 2
source: issue #111 / issue #113
created: 2026-04-24
---

# Orchestrator skill→orchestrator handoff forwarding 合规缺口 Postmortem

## 1. 根因

analyst 报告 `docs/analyze/orchestrator-compliance-gap.md` 3 hypothesis 佐证，architect posture（DEC-030 决定 2）：

- **A rule density**（workflow.md 552 行 ≥8 并发检索 —— §Step 5b 事件类 5 + §Step 6.1 A 类模板 ~60 行 + §Step 7/8 相关 fire 点散落）：**部分成立**，`§Step 5c` 抽独立小节局部微降密度（grep `Step 5c` 命中直达 checklist）；全文精简出 scope（issue #111 明示）
- **B 无 enforcement**（DEC-029 已对 prompt ref 密度做双层 prose+scripts；orchestrator emit 合规性无同构兜底）：**成立**，P2 follow-up 补 runtime enforcement（`scripts/orchestrator-compliance-check.sh` + JSONL audit log）
- **C cognitive load**（skill 返回后多事件类决策集中 1 tick；attention shift 在 LLM inference 非零成本）：**成立**，§Step 5c 6 条 action 按序排列降决策树深度；与 A 响应同频

**本质**：DEC-024 / DEC-013 §3.1a / §Step 6.1 MUST 语义均已 Accepted；缺口是 **SPEC→RUNTIME 合规性 drift** 而非 SPEC 缺失。Finding 2（YAML 契约终端可见）对 Finding 1 因果**无 A/B 实证**，D1=D 保持现状留 P2 enforcement 落地后再评估（DEC-030 §5 Q2）。

## 2. 复现

两次 observed 证据链：

1. **2026-04-22**（memory `feedback_tg_workflow_updates_to_tg`）：TG active channel sticky session orchestrator skill→A 类 producer-pause 漏 §Step 5b 事件类 b 转发，用户实测滑步后沉淀 memory
2. **2026-04-23**（`/roundtable:workflow #110` analyst pipeline）：skill 返回后 orchestrator 仅终端自然语言 summary，TG 零 reply / Phase Matrix stale / 无 A 类菜单 / 未 pause；用户补发"进展"触发 recover

**触发条件**：(i) decision_mode=text 或 TG active channel sticky；(ii) skill（analyst / architect）→ orchestrator A 类 producer-pause 正常返回；(iii) orchestrator tick 需同 1 轮内 fire 6 条 action（flush / sync / fwd-c / fwd-b / menu / pause）。

## 3. 修复

P1（本 PR #113）落盘 layout 层：

- `commands/workflow.md` +§Step 5c Skill→Orchestrator Handoff Checklist（6 条按序 action + audit emit 占位）
- `commands/workflow.md` §Step 6.1 A 类模板末尾 `详见 §Step 5c` ref 一行
- `docs/bugfixes/orchestrator-compliance-gap.md`（本文件）
- `docs/log.md` +1 `fix-rootcause` tier=2 entry
- `docs/INDEX.md` +bugfixes 段条目

P2（follow-up issue #114）补 runtime enforcement：

- `scripts/orchestrator-compliance-check.sh`（~50 行 bash，扫 JSONL audit log 断言 6 action 全命中）
- `CLAUDE.md` §工具链 +`lint_cmd_compliance` 字段
- `hooks/session-start` + `scripts/preflight.sh` +`ROUNDTABLE_AUDIT_PATH` echo
- `commands/workflow.md` §Step 5c / §Step 5b / §Step 6.1 fire 处各加 audit emit 注

## 4. 验证

**P1（本 PR）**：
- `lint_cmd_hardcode` exit 0（无外部 target 项目名命中）
- `lint_cmd_density` exit 0（DEC 16→17 +1 < per-file +3 阈值；§ 计数无变化，`scripts/ref-density-check.sh` 正则 `§[0-9]+` 不匹配 `§Step X` 形式；无需 `--update-baseline`）
- tester 对抗验证 §Step 5c 不冲突 §Step 6.1 A 类现有模板 / architect 变体 / Stage 9 变体 / Q&A 循环
- reviewer 对齐 DEC-024 / DEC-013 §3.1a / §Step 6 / DEC-014 4 维度确认 Refines 非 Supersede

**P2 merged 后**（本节由 P2 收尾时 update）：dogfood `/roundtable:workflow` TG-driven analyst pipeline 6 条 fire 清单全命中 + `scripts/orchestrator-compliance-check.sh` exit 0 → DEC-030 Provisional → Accepted。

## 5. Follow-ups

- **P2 实施**：issue #114（DEC-030 runtime compliance enforcement + audit log）；P2 自身可能开 DEC-031 Refines DEC-030（audit log schema / scan 算法若涉架构分歧）
- **P3 umbrella（条件触发）**：若 P2 enforcement 落地后仍捕获高频 miss + audit log 归因到 rule density dominant（hypothesis A），开新 issue 做 workflow.md 系统性精简（本 DEC out-of-scope）
- **Finding 2 结构性重议（条件触发）**：若 P2 捕获 miss 证据支撑 Finding 2 是 Finding 1 contributing factor（非纯 cosmetic），届时有实证开新 DEC 评估 mitigation c（外挂 /tmp/contracts）；本 DEC §5 Q2 已 anchor 该 follow-up 路径
