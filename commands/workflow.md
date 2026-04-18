---
description: Multi-role AI workflow orchestrator. Selects a path among analyst / architect / developer / tester / reviewer / dba based on task size.
argument-hint: <task description>
---

# Multi-Role Workflow

You are orchestrating multi-role collaboration for:

**Task**: $ARGUMENTS

---

## Prerequisite

The target project must follow roundtable's docs layout (`design-docs/`, `exec-plans/active/`, `analyze/`, `testing/`, `reviews/`, `decision-log.md`, `log.md`). Missing subdirectories are created on first write by the role that needs them; the orchestrator reports the creation to the user.

---

## Phase Matrix

Maintain this matrix across the dispatch lifecycle. Report it back to the user on every phase transition and at any user request for progress.

| Stage | Role | Status | Artifacts |
|-------|------|--------|-----------|
| 1. Context detection | (inline, this command) | ⏳ / 🔄 / ✅ | `target_project`, `docs_root`, `lint_cmd`, `test_cmd`, `critical_modules`, `design_ref` |
| 2. Research (optional) | analyst skill | ⏳ / 🔄 / ✅ / ⏩ skipped | `{docs_root}/analyze/[slug].md` |
| 3. Design | architect skill | ⏳ / 🔄 / ✅ | `{docs_root}/design-docs/[slug].md`, `decision-log.md` DEC entries, optional `{docs_root}/exec-plans/active/[slug]-plan.md`, optional `{docs_root}/api-docs/[slug].md` |
| 4. Design confirmation | (user) | ⏳ / 🔄 / ✅ | user acknowledgement |
| 5. Implementation | developer agent(s) | ⏳ / 🔄 / ✅ | code in `src/`, tests in `tests/`, exec-plan checkboxes (orchestrator writes from dev report) |
| 6. Adversarial testing | tester agent | ⏳ / 🔄 / ✅ / ⏩ skipped | tests, `{docs_root}/testing/[slug].md`, bug findings via escalation |
| 7. Review | reviewer agent | ⏳ / 🔄 / ✅ / ⏩ skipped | findings in conversation or `{docs_root}/reviews/[YYYY-MM-DD]-[slug].md` |
| 8. DB review (if DB involved) | dba agent | ⏳ / 🔄 / ✅ / ⏩ N/A | findings in conversation or `{docs_root}/reviews/[YYYY-MM-DD]-db-[slug].md` |

Legend: ⏳ pending · 🔄 in-progress · ✅ complete · ⏩ skipped (with reason) · — inapplicable

---

## Step 0: Project Context Detection

**Execute the 4-step detection inline** — do NOT use the `Skill` tool to activate `_detect-project-context`. That file is a markdown helper containing the detection procedure; `Read` it at turn start and follow the 4 steps directly, storing the result in session memory.

The 4 steps (see `skills/_detect-project-context.md` for details):

1. **Target-project identification (D9)**: session memory → `git rev-parse --show-toplevel` → CWD `.git/` subdirectory scan → regex match against task description → `AskUserQuestion` fallback.
2. **Toolchain detection**: scan the target-project root for `Cargo.toml` / `package.json` / `pyproject.toml` / `go.mod` / `Move.toml`; derive default `lint_cmd` and `test_cmd`.
3. **docs_root detection**: `docs/` → `documentation/` → `AskUserQuestion` with default "create `docs/`".
4. **CLAUDE.md loading**: read the `# 多角色工作流配置` section for `critical_modules`, `设计参考`, `工具链覆盖`, `条件触发规则`. CLAUDE.md values override automatic detection.

Any role dispatched later MUST have the detection output injected in its prompt:
- `target_project` (absolute path)
- `docs_root`
- `primary_lang`, `lint_cmd`, `test_cmd`
- `critical_modules` (array)
- `design_ref` (array, for architect / analyst)
- `slug` (once assigned)

Never let subagents re-run detection.

---

## Step 1: Size the Task

Decide after reading the task description plus target-project `CLAUDE.md`.

| Size | Signal | Pipeline |
|------|--------|----------|
| **Small** | Bug fix, single-file tweak, UI styling, doc edit | Suggest `/roundtable:bugfix` or direct `@roundtable:developer` |
| **Medium** | New feature, module change, contained business logic | analyst (optional) → architect → design-confirm → developer → tester (if critical) → reviewer (optional) |
| **Large** | New module, cross-component, architectural shift | analyst → architect → design-confirm → developer → tester → reviewer |

DB-involved changes (schema / migration / SQL): also dispatch `@roundtable:dba` after developer.

If the size is ambiguous, invoke `AskUserQuestion` with two options (medium / large) carrying `rationale` + `tradeoff` each per the architect's Option Schema.

---

## Step 2: Tester Trigger Rules

Read `critical_modules` from the injected CLAUDE.md summary. When the task touches any listed module or keyword, **tester MUST be dispatched** after developer.

Generic fallback (if CLAUDE.md does not declare `critical_modules`):
- Money / account / permission decisions
- Performance-critical hot paths (benchmark-gated)
- Concurrency / lock / transaction boundaries
- Security (signature verification / input sanitization / permission check)
- External-system integration (DB / message queue / payment / identity)

Optional tester: medium+ features' E2E scenarios; front-end critical interaction flows.

Skip tester: bug fix (developer already adds regression), UI styling, doc update, non-critical utility.

---

## Step 3: Slug + Artifact Handoff

Pick ONE kebab-case slug and use it across all phases. If the user does not specify, the first dispatched role names it and declares it in the output header.

Artifact chain:

```
analyst   → {docs_root}/analyze/[slug].md
architect → reads analyze/[slug].md
            writes design-docs/[slug].md
            optional: exec-plans/active/[slug]-plan.md
            optional: api-docs/[slug].md
            appends decision-log.md DEC entries
developer → reads design-docs/[slug].md + exec-plans/active/[slug]-plan.md
            writes src/ and tests/
            reports exec-plan checkbox updates; orchestrator writes them
            when feature fully done: requests orchestrator to move
            exec-plan from active/ to completed/
tester    → reads src/ and design-docs/[slug].md
            writes tests/ (adversarial / E2E / benchmark)
            medium+ tasks: writes testing/[slug].md
            business bugs: escalate (never fixes src/*)
reviewer  → reads src / design-docs / decision-log
            default: conversation-only findings
            writes reviews/[YYYY-MM-DD]-[slug].md when critical_modules
            triggered or Critical findings emerge
dba       → reads migrations / schema / src
            default: conversation-only findings
            writes reviews/[YYYY-MM-DD]-db-[slug].md when change is
            large or Critical emerges
```

---

## Step 4: Parallel Dispatch Decision Tree

The orchestrator MAY dispatch multiple subagents in parallel when ALL of the following hold. When any fails, dispatch sequentially.

1. **PREREQ MET** — Both candidates have their `前置` from the exec-plan already satisfied (prior phases complete or artifacts in place).
2. **PATH DISJOINT** — The candidates write to disjoint file sets (e.g., one phase writes `moduleA/`, another writes `moduleB/` — no path overlap).
3. **SUCCESS-SIGNAL INDEPENDENT** — Each candidate has its own success signals (lint / test checkpoint) that do not depend on the other candidate's output.
4. **RESOURCE SAFE** — Combined parallel work does not trip rate limits, lockfiles, or shared tool single-writer constraints (e.g., only one process may hold the test DB).

Default: sequential. Escalate to parallel only when all four rules hold AND the speedup is material (> 30% expected time reduction).

When dispatching in parallel: issue the Task calls in ONE assistant message so they run concurrently.

**Exec-plan checkbox writes are serialized.** Even in parallel dispatches, the orchestrator writes checkboxes back to the plan file. Developers report completed items in their final message; the orchestrator updates the file. This prevents races on the shared exec-plan markdown.

---

## Step 5: Subagent Escalation Handling

Agents cannot invoke `AskUserQuestion` inside the Task sandbox. When an `<escalation>` block appears in the agent's final report, the orchestrator MUST:

1. **Parse** the JSON block (`type` / `question` / `context` / `options` / `remaining_work`).
2. **Invoke `AskUserQuestion`** with the options. Each option's description carries `rationale` + `tradeoff`. Flag the `recommended: true` option with a `★` marker and its `why_recommended` reason.
3. **On user answer**: re-dispatch the SAME agent with the decision fact injected into the prompt, scoped to the `remaining_work` listed in the escalation.
4. **Never decide on behalf of the user.** If the agent did not recommend an option, pick nothing — pass the decision through.

Parsing rules:
- One `<escalation>` block per dispatch. Multiple suggests the dispatch was poorly scoped; split the task.
- If the block is malformed (missing required fields), echo the error back to the agent and ask for a corrected block; do not forward to the user yet.
- Distinguish **escalation** (expected user input; continue unblocked work) from **abort** (missing prerequisite; stop and fix the dispatch).

See each agent's `## Escalation Protocol` section for the block format.

---

## Step 6: Execution Rules

1. **Phase gates**: after each phase completes, report outcome + artifacts + updated Phase Matrix to the user, then **wait for user confirmation** before advancing to the next phase. Exception: routine transitions within the same role (e.g., sequential `P0.n → P0.n+1` sub-phases inside one exec-plan) MAY auto-advance when the exec-plan's prerequisites are met, no Critical findings surfaced, and the user has not requested finer granularity. Cross-role transitions (developer → tester, tester → reviewer, etc.) always require confirmation unless CLAUDE.md `critical_modules` rule dictates the trigger (e.g., tester is mechanically dispatched after developer for `critical_modules`-tagged work; the user still sees the handoff report).

2. **In-phase decisions**: when an active skill encounters a user-decision point, invoke `AskUserQuestion` IMMEDIATELY following the skill's `## AskUserQuestion Option Schema`. Do not accumulate decisions for a batch ask.

3. **plan-then-execute**:
   - **architect**: three-phase flow (explore → land design-docs → optional exec-plan). See `skills/architect.md`.
   - **developer**: medium / large tasks output an implementation plan for user confirmation BEFORE coding (small tasks may skip).
   - **tester**: medium / large tasks output a test plan for user confirmation BEFORE coding (small tasks may skip).

4. **Role forms**:
   - `architect` / `analyst` are **skills** (main session; `AskUserQuestion` available) — activate via the `Skill` tool.
   - `developer` / `tester` / `reviewer` / `dba` are **agents** (subagent isolation; `AskUserQuestion` disabled) — dispatch via the `Task` tool; inject `target_project` / `docs_root` / `lint_cmd` / `test_cmd` / `critical_modules` / `slug` / `primary_lang` into every dispatch prompt.

5. **After developer**: run `lint_cmd` and `test_cmd` against target-project. Failures are reported to the user; the orchestrator does not silently re-dispatch to fix.

6. **Tester finds business bugs**: tester writes a reproduction test, reports via `<escalation>`, and does NOT fix business code. Orchestrator surfaces the bug to the user, who decides whether to dispatch a bug-fix sub-dispatch (typically via `/roundtable:bugfix`).

7. **Handling escalations**: see Step 5.

8. **No autonomous git operations**: `git commit` / `push` / `branch` / `tag` / `reset` / `stash` only when the user explicitly asks. Default: leave everything in the working tree. Staging (`git add`) for committing is likewise user-triggered.

---

## Starting Point

1. Run Step 0 inline (context detection).
2. Run Step 1 (task sizing). If ambiguous, `AskUserQuestion`.
3. Initialize the Phase Matrix (all ⏳).
4. Activate / dispatch the first role per the size pipeline.
5. Update the matrix at every phase transition and report it.
6. Obey the rules in Step 6.

**This command orchestrates only — it does not design, code, or review itself. Delegate all substantive work to the appropriate role.**
