---
name: _progress-content-policy
description: Internal helper. Shared progress-emission content policy included by developer/tester/reviewer/dba `## Progress Reporting` sections. Underscore prefix = include-only, not independently activatable. Layered on DEC-004 event schema.
---

# Progress Content Policy

被 `agents/{developer,tester,reviewer,dba}.md` 的 Progress Reporting 引用。叠加在 DEC-004 §3.1–3.2（schema —— 这里不重复）之上，与 DEC-002（escalation）正交。

## 1. Substantive-progress gate

每次 emit 之前，自上次 emit 起必须满足下列之一：

- 有**文件写入 / edit** 落盘，或
- 有**子里程碑**完成（测试通过、exec-plan checkbox 勾选），或
- 消耗了**≥50% 新 context**（有意义的新 read，不是 re-read）。

无触发器 → **不要** emit。替代时钟心跳（LLM 没有 timer）。与 DEC-004「每次派发 3–10 条事件、phase-checkpoint 级别」对齐。

`phase_blocked` + `<escalation>` **gate-exempt** —— blocker 总是立即 emit。

## 2. No-repeat summary

新的 `summary` **不得**与上一条 emit 的 `summary` 逐字相同。若无法区分，**宁可不 emit**。连续相同禁用；非连续重复（被其他事件分隔）是合法的 phase 循环。

## 3. Differentiated content

每条 `summary`（≤120 字符）**必须**带其中**至少一个**：

- **sub-step 名** —— 具体目标，如 `editing agents/developer.md Content Policy subsection`
- **progress 分数** —— 分数 / 计数，如 `2/5 files done`、`test 3/12`
- **milestone 标签** —— checkpoint 名，如 `milestone: P0.2 4-agents synced`

三者都缺 = 噪声；重写或跳过。

## 4. DONE / ERROR 信号

- **DONE**：最终的 `phase_complete` 兼作 DONE。约定（非强制）：summary 前缀 `✅`。无新事件类型；orchestrator 以 `Task` 返回作为权威 DONE。
- **ERROR**：先 emit `phase_blocked`（gate-exempt），再按 DEC-002 在 final message 中放 `<escalation>` JSON block。通道保持正交。

## 5. 反例 vs 正例

**A —— no-repeat（§2）**
- ❌ `"dev round2 progress"` 连续 3 条 emit。
- ✅ `"P0.2 editing tester.md"` → `"P0.2 2/4 agents synced"` → `"P0.2 milestone: 4 agents synced"`。

**B —— differentiated content（§3）**
- ❌ `"working on tests"` —— 无 sub-step / score / milestone。
- ✅ `"running case-fuzz 3/12 — boundary overflow"` —— sub-step + score。

**C —— gate（§1）**
- ❌ `phase_start` 紧接另一条 emit，中间无文件写入 / 子里程碑 / read。
- ✅ `phase_start` →（Edit 落盘）→ 带结果的 `phase_complete` —— 文件写入触发器。

**D —— DONE marker（§4）**
- ❌ 终结 `phase_complete` summary `"done"`。
- ✅ `"✅ P0.4 lint 0-hit + awk smoke folded x2"` —— ✅ 前缀 + 具体结果。

## 6. 边界情况

| 情形 | 处理 |
|------|------|
| 相邻 phase 共享 sub-step 名 | 用 score 或 milestone 区分；否则跳过第二条 emit（§2）。 |
| `ROUNDTABLE_PROGRESS_DISABLE=1` / 空 `{{progress_path}}` | Policy 失效；按各 agent Fallback 静默 skip。 |
| 无 exec-plan P0.n（tester / reviewer 自由格式） | 用 agent 原生 phase tag；§3 依然适用。 |
| Emit IO 失败 | 按 DEC-004 §3.2 静默降级；无新 fallback。 |

Refs：DEC-007、DEC-004 §3.1–3.2、DEC-002。
