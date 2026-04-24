---
slug: orchestrator-compliance-gap
source: design-docs/orchestrator-compliance-gap.md
created: 2026-04-24
status: Active
decisions: [DEC-030]
---

# Orchestrator Handoff Forwarding 合规性修复 执行计划

> **Scope**：本 exec-plan 覆盖 DEC-030 两个 follow-up 实施阶段（P1 layout + postmortem / P2 runtime enforcement）。本 issue #111 自身**只**产出 design-doc + DEC + 本 plan，不做实施；P1/P2 实施在各自 follow-up issue 的新 workflow session 执行，届时本 plan 作为 architect→developer handoff 锚点。

## 总览

| Phase | 标题 | 预估 | 前置 | 关键风险 |
|-------|------|-----|------|---------|
| P1 | Layout §Step 5c + Tier 2 postmortem | ~60-80 行 / 1 PR | 本 DEC Accepted | workflow.md 编号冲突（§Step 5c 需与 §Step 5 / 5b 并列不冲突）+ tester 对抗 §Step 6.1 现有 A 类模板回归 |
| P2 | Runtime enforcement audit log + scripts | ~40-60 行 / 1 PR | P1 merged | audit log emit 点散落 orchestrator 多处（跨 tick 不漏写）+ scan 算法 false-positive（"skip-if-no-new" 边界）+ 可能开 DEC-031 Refines |

## P1: Layout §Step 5c + Tier 2 postmortem

### 目标

- 在 `commands/workflow.md` 新 §Step 5c Skill→Orchestrator Handoff Checklist 小节明示 6 条应 fire 动作
- `docs/bugfixes/orchestrator-compliance-gap.md` 落盘 Tier 2 postmortem（DEC-014 五段式）
- `docs/log.md` +1 `fix-rootcause` tier=2 entry 关联 postmortem
- `docs/INDEX.md` +bugfixes 段新条目
- critical_modules 命中（skill/agent/command prompt bodies）→ tester + reviewer 派发

### 任务清单

- [ ] P1.1 Read 现 `commands/workflow.md` §Step 5b / §Step 6 全段定位 §Step 5c 插入点（建议在 L304 §Step 5b 尾段之后、§Step 6 开头之前）
- [ ] P1.2 起草 §Step 5c 章节（~30 行）：
  - header `## Step 5c: Skill→Orchestrator Handoff Checklist (DEC-030)`
  - 6 条按序 action 编号列表：`1. [flush]` / `2. [sync]` / `3. [fwd-c]` / `4. [fwd-b]` / `5. [menu]` / `6. [pause]`
  - 每条 action 旁 anchor 原规则位置（`详见 §Step 8` / `详见 §Step 7` / `详见 §Step 5b 事件类 c` 等）
  - 末尾注 "每步 orchestrator emit audit JSONL 行至 ${ROUNDTABLE_AUDIT_PATH}（P2 实施时生效）"（P1 落盘时 P2 未实施，注 inline placeholder）
  - 纯终端 session fwd-b/c 降级规则行
- [ ] P1.3 在 §Step 6.1 A 类模板内旁加一行 `详见 §Step 5c Handoff Checklist`
- [ ] P1.4 跑 `lint_cmd_hardcode` + `lint_cmd_density` 双 exit 0 确认无回归（P1 新增 ~30 行可能触发 ref-density.baseline +≥3 per-file 需 baseline 更新；若触发走 `scripts/ref-density-check.sh --update-baseline` 并在 PR 说明）
- [ ] P1.5 起草 `docs/bugfixes/orchestrator-compliance-gap.md` Tier 2 postmortem（DEC-014 五段式，~30-40 行）：
  - ### 1. Root cause — hypothesis A/B/C architect posture
  - ### 2. Reproduction — 2026-04-22 + 2026-04-23 证据链 + 触发条件
  - ### 3. Fix — §Step 5c layout（P1）+ runtime enforcement（P2 ref）
  - ### 4. Verification — dogfood `/roundtable:workflow` TG analyst pipeline 6 条 fire 清单命中 + compliance-check.sh（P2 merged 后）exit 0
  - ### 5. Follow-ups — P2 enforcement / 若仍 miss 触发 P3 umbrella
- [ ] P1.6 orchestrator relay 写 `docs/log.md` 一条 `fix-rootcause` tier=2 entry（analysis 段含 root cause + fix + reproduction + 关联 postmortem 路径）
- [ ] P1.7 `docs/INDEX.md` §bugfixes 段 +1 条目
- [ ] P1.8 critical_modules 命中 → developer 返回后 orchestrator 派 tester（对抗性验证 §Step 5c 不冲突 §Step 6.1 现有 A 类模板 + Q&A 循环 + architect 变体 + Stage 9 变体）+ reviewer（对齐 DEC-024/013/006/030 维度 + 确认无 Accepted DEC 违背）
- [ ] P1.9 P1 PR 标题英文 ≤70 char：`feat(workflow): DEC-030 Step 5c handoff checklist + Tier 2 postmortem (#<P1-issue>)`
- [ ] P1.10 PR body 含 Summary / Fix / Quality gates / Follow-ups（ref P2 issue）/ Fixes #<P1-issue> / Claude Code footer

### 成功信号

- `commands/workflow.md` §Step 5c 存在且 6 条 action 完整
- §Step 6.1 A 类模板含 `详见 §Step 5c` ref 行
- `docs/bugfixes/orchestrator-compliance-gap.md` 五段式完整
- `docs/log.md` 顶部 `fix-rootcause | orchestrator-compliance-gap | 2026-04-XX` tier=2 entry 带 postmortem 链接
- lint_cmd 双 exit 0；tester Pass 或 Pass-with-post-fix；reviewer Approve 或 Approve-with-caveats
- PR merged 后本 plan P1 checkbox 全勾 + plan 由 orchestrator git mv 到 `exec-plans/completed/`（若 P2 未启动则保 active）

### 风险与预案

- **R1**：§Step 5c 编号与未来 Step 编号冲突（如未来 §Step 5d）→ **预案**：命名遵循 "5 家族 = escalation 后继路径"；编号段 5c/5d 预留给 handoff / audit 相关子节，与 §Step 6 前置 gating 家族区分
- **R2**：tester 发现 §Step 5c 与现有 §Step 6.1 "停下不调用任何工具" 有重叠描述造成 ambiguity → **预案**：§Step 5c action 6 `[pause]` 直接 ref `§Step 6.1 pause 规则不重复`；§Step 6.1 原文不动
- **R3**：postmortem 5 段式字数超 DEC-014 指导（Tier 2 典型 50-80 行）→ **预案**：`### 3. Fix` 段只列 fix 落点 file:line + 一句话，具体实施 diff 指向 P1 PR；`### 5. Follow-ups` 段只列 P2 / P3 issue 编号 + 一句话
- **R4**：lint_cmd_density baseline 因新增 §Step 5c 触发 +≥3 → **预案**：`scripts/ref-density-check.sh --update-baseline` 重锁 + PR 说明 methodology-stable 而非 ref 回弹（与 DEC-029 post-fix 2026-04-23 C1 修复先例同构）

## P2: Runtime enforcement audit log + scripts

### 目标

- orchestrator 在每次 event class b/c/d/e fire + A 类 menu emit + pause 各 emit 一条 JSONL audit 行
- `scripts/orchestrator-compliance-check.sh` 扫 audit log 断言 "skill→orchestrator handoff" 6 条 action 全命中；miss 打印 COMPLIANCE FAIL + exit 1
- `CLAUDE.md` §工具链 追 `lint_cmd_compliance` 字段（与 `lint_cmd_hardcode` / `lint_cmd_density` 并列）
- `hooks/session-start` + `scripts/preflight.sh` 追 `ROUNDTABLE_AUDIT_PATH` echo
- critical_modules 命中 → tester + reviewer 派发
- P2 自身可能开 DEC-031 Refines DEC-030（若 audit log schema / scan 算法需 architect 级决策）

### 任务清单

- [ ] P2.1 P2 follow-up architect round 第一步：决定 audit log schema 细节是否需开 DEC-031 Refines DEC-030。判据：若只是 schema 字段确定 + 实施细节 → 铁律 4 inline post-fix DEC-030；若涉及 new tradeoff（如 audit log 持久化策略 / scan 算法 per-transition vs per-session / 纯终端 session fwd-b/c 降级是否写 audit）→ 新开 DEC-031
- [ ] P2.2 （若 P2.1 决 inline post-fix）直接进入实施；（若决 DEC-031）先走 analyst（可选，若事实层未清）→ architect AskUserQuestion 锁决策点 → DEC-031 Provisional 置顶落盘
- [ ] P2.3 新 `scripts/orchestrator-compliance-check.sh`（~50 行 bash）：
  - Accept `${ROUNDTABLE_AUDIT_PATH}` env 或 `--path <path>` 参数
  - Parse JSONL → group by `dispatch_id`
  - 对 "skill return" 类 dispatch（识别条件 P2 architect 定）assert { flush, sync, fwd-c, fwd-b, menu, pause } 或其 skip-if-no-new 变体
  - Miss → stderr "COMPLIANCE FAIL: dispatch=<id> slug=<slug> missed=[...]" + exit 1
  - 0 miss → exit 0
- [ ] P2.4 `commands/workflow.md` §Step 5c + §Step 5b + §Step 6.1 相关 fire 点各 +1 行 audit emit 注（~10 行跨多处）
- [ ] P2.5 `hooks/session-start` + `scripts/preflight.sh` 追 ROUNDTABLE_AUDIT_PATH echo（~4 行）
- [ ] P2.6 `CLAUDE.md` §工具链 追 `lint_cmd_compliance: scripts/orchestrator-compliance-check.sh`（~2 行）
- [ ] P2.7 跑 lint_cmd 三字段（hardcode + density + compliance）全 exit 0；dogfood `/roundtable:workflow` 新 analyst 派发 E2E + compliance-check exit 0
- [ ] P2.8 P2 tester 对抗：构造"有意 skip 某 action"场景验证 compliance-check 能捕获（正向 + 反向测试）
- [ ] P2.9 P2 reviewer 对齐 DEC-030 + DEC-013 + DEC-024 + DEC-028 + DEC-029
- [ ] P2.10 P2 PR 标题 `feat(workflow): DEC-030 runtime compliance enforcement + audit log (#<P2-issue>)`
- [ ] P2.11 P2 merged 后：DEC-030 状态从 `Provisional` → `Accepted`（冷却窗满足：P1+P2 dogfood 通过 = 首次 dogfood run pass）；本 plan checkbox 全勾 + git mv 到 `exec-plans/completed/`
- [ ] P2.12 `docs/bugfixes/orchestrator-compliance-gap.md` §4 Verification 段填实（P1 落盘时只占位，P2 merged 后 update）

### 成功信号

- `scripts/orchestrator-compliance-check.sh` 存在且 double dogfood（正向 pass + 反向 detect miss）
- `CLAUDE.md` §工具链含 3 个 lint_cmd_* 字段
- `hooks/session-start` 新 session 启动时 `<roundtable-preflight>` 块含 `ROUNDTABLE_AUDIT_PATH=<path>` 行
- dogfood `/roundtable:workflow` 1 轮完整 analyst → architect pipeline 后 `lint_cmd_compliance` exit 0
- DEC-030 状态改 `Accepted`；DEC-031（若开）Provisional

### 风险与预案

- **R5**：audit log emit 点散落多处（每次 event class b/c/d/e + menu + pause），orchestrator 仍可能漏 emit → **预案**：(i) §Step 5c action 6 条与 audit event 一一对应 one-to-one，同一 tick 检查表心智；(ii) compliance-check 本身检测 meta case "session active 但 audit log 空"，发现后加 self-assertion
- **R6**：tmpfs 路径 `/tmp/roundtable-audit/` 多 session 并发不冲突但跨 session 不持久 → **预案**：复用 DEC-028 `${SESSION_ID}` 为文件名；GC 依赖 OS tmpfiles 清理；plugin 不 gc（P2 architect round 可重议持久化策略，若需改则开 DEC-031）
- **R7**：纯终端 session fwd-b/c 降级为 terminal-only 时是否写 audit → **预案**：P2.1 architect 决策点；默认建议 "仍写 audit（channel 字段 = terminal）"确保 compliance-check 覆盖所有 session 类型
- **R8**：compliance-check 误报（false positive）影响 lint CI 或 dogfood → **预案**：P2.8 tester 强制正反测试；初版允许 `--strict` / `--warn` 模式 gate（默认 warn）；Accepted 后切 strict

## 跨阶段约束

- **不改 final message YAML 契约**（D1=D 硬约束）：P1/P2 均不改 4 agent + 2 skill prompt 本体的 `log_entries:` + `created:` YAML 位置 / 包裹 / 渠道
- **不改 Accepted DEC 正文**：DEC-024 / DEC-013 / DEC-006 / DEC-028 / DEC-029 正文不动，仅在相关 design-doc / workflow.md 处 ref DEC-030
- **Refines 非 Supersede**：P1 / P2 PR body 必显式 Refines DEC-024 + DEC-013 §3.1a + §Step 6，非 Supersede
- **P2 依赖 P1 merged**：P2 implementation 依赖 P1 §Step 5c 结构；两 issue 可并开 design 但 P2 merged 顺序必后于 P1
- **postmortem 统一 P1 落盘**：即便 P2 merged 前 postmortem §4 Verification 段仍占位，不延 postmortem 落盘时机（issue #111 AC 约束）
- **DEC-025 冷却窗**：DEC-030 Provisional → Accepted 条件 = P1 + P2 merged + dogfood run pass；首次 dogfood 失败回归 Provisional 等修复

## 变更记录

- 2026-04-24（初稿）：基于 DEC-030 3 决策（D1=D / D2=C / D3=B）落盘 P1 + P2 两 phase；待 Stage 4 B 类用户 Accept 后进入 follow-up issue 创建 + 实施
