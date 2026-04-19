---
name: _progress-content-policy
description: Internal helper. Shared progress-emission content policy included by developer/tester/reviewer/dba `## Progress Reporting` sections. Underscore prefix = include-only, not independently activatable. Layered on DEC-004 event schema.
---

# Progress Content Policy

Referenced by `agents/{developer,tester,reviewer,dba}.md` Progress Reporting. Layered on DEC-004 §3.1–3.2 (schema — not repeated here), orthogonal to DEC-002 (escalation).

## 1. Substantive-progress gate

Before every emit, ONE of the following must hold since the previous emit:

- a **file write / edit** landed on disk, OR
- a **sub-milestone** completed (test passed, exec-plan checkbox ticked), OR
- **≥50% new context** consumed (meaningful new reads, not re-reads).

No trigger → do NOT emit. Replaces clock heartbeats (LLM has no timer). Aligns with DEC-004 "3–10 events per dispatch, phase-checkpoint level".

`phase_blocked` + `<escalation>` is **gate-exempt** — blockers always emit immediately.

## 2. No-repeat summary

New `summary` MUST NOT equal the previous emit's `summary` verbatim. If indistinguishable, **prefer not emitting**. Consecutive-identical is forbidden; non-consecutive repeats (separated by other events) are valid phase cycles.

## 3. Differentiated content

Every `summary` (≤120 chars) MUST carry at least ONE of:

- **sub-step name** — concrete target, e.g. `editing agents/developer.md Content Policy subsection`
- **progress score** — fraction / count, e.g. `2/5 files done`, `test 3/12`
- **milestone tag** — checkpoint name, e.g. `milestone: P0.2 4-agents synced`

Lacking all three = noise; rewrite or skip.

## 4. DONE / ERROR signals

- **DONE**: the final `phase_complete` doubles as DONE. Convention (non-mandatory): prefix summary with `✅`. No new event type; orchestrator uses `Task` return as authoritative DONE.
- **ERROR**: emit `phase_blocked` first (gate-exempt), then include `<escalation>` JSON block in the final message per DEC-002. Channels stay orthogonal.

## 5. Anti-pattern vs good-pattern

**A — no-repeat (§2)**
- ❌ `"dev round2 progress"` × 3 consecutive emits.
- ✅ `"P0.2 editing tester.md"` → `"P0.2 2/4 agents synced"` → `"P0.2 milestone: 4 agents synced"`.

**B — differentiated content (§3)**
- ❌ `"working on tests"` — no sub-step / score / milestone.
- ✅ `"running case-fuzz 3/12 — boundary overflow"` — sub-step + score.

**C — gate (§1)**
- ❌ `phase_start` immediately followed by another emit with no file write / sub-milestone / read between.
- ✅ `phase_start` → (Edit lands) → `phase_complete` with outcome — file-write trigger.

**D — DONE marker (§4)**
- ❌ Terminal `phase_complete` summary `"done"`.
- ✅ `"✅ P0.4 lint 0-hit + awk smoke folded x2"` — ✅ prefix + concrete outcome.

## 6. Edge cases

| Case | Handling |
|------|----------|
| Adjacent phases share a sub-step name | Differentiate via score or milestone; else skip second emit (§2). |
| `ROUNDTABLE_PROGRESS_DISABLE=1` / empty `{{progress_path}}` | Policy inert; silent-skip per agent Fallback. |
| No exec-plan P0.n (tester / reviewer free-form) | Use agent-native phase tags; §3 still applies. |
| Emit IO failure | Silent degrade per DEC-004 §3.2; no new fallback. |

Refs: DEC-007, DEC-004 §3.1–3.2, DEC-002.
