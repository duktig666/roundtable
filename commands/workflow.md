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
| 9. Closeout | (user) | ⏳ / 🔄 / ✅ | aggregate findings summary; user-driven commit / PR / amend decision (DEC-006 producer-pause, workflow terminus) |

Legend: ⏳ pending · 🔄 in-progress · ✅ complete · ⏩ skipped (with reason) · — inapplicable

**Real-time progress stream (below the matrix)**: Progress notifications from active subagent dispatches appear here in real time, in the format `[<phase>] <role> <event> — <summary>` per DEC-004. The stream is independent of the matrix columns; it is not a matrix column but an append-only relay driven by the `Monitor` tool launched in Step 3.5. Each notification originates from one subagent's `## Progress Reporting` emit; multiple parallel dispatches interleave by `dispatch_id`.

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
closeout  → aggregates findings across reviewer / dba output
            produces no new files
            user drives commit / PR / amend decision (DEC-006 A producer-pause)
```

---

## Step 3.5: Progress Monitor Setup (DEC-004)

Every subagent dispatch is paired with a `Monitor` tool invocation so the user sees phase-level progress in the main session in real time. This Step executes **before every `Task` dispatch** (developer subagent / tester / reviewer / dba / research fan-out) and is independent of the Phase Matrix column semantics above.

**Tool note**: the backticked `Monitor` name below is the Claude Code native tool (v2.1.98+). If the orchestrator has not loaded its schema yet, it MUST use `ToolSearch` to fetch the `Monitor` schema before this Step executes. `Monitor` streams stdout lines from a background process as notifications back to the main session.

### 3.5.1 Opt-out check

Read env var `ROUNDTABLE_PROGRESS_DISABLE`. If it equals `1`, skip this entire Step: do NOT generate a `progress_path`, do NOT start `Monitor`, and do NOT inject the 4 progress variables into the dispatch prompt. Subagents receiving an empty `progress_path` silently degrade to "no emit" per each agent's `## Progress Reporting` fallback clause (matches DEC-004 §3.2 "missed emit degrades to silent, not worse than current").

### 3.5.2 Per-dispatch Bash preparation

For every `Task` dispatch, run this Bash snippet **before** the Task call (one Bash invocation per dispatch; do NOT reuse paths across dispatches):

```bash
# 8-hex dispatch_id (openssl preferred, falls back to sha1 of ts+nanos if openssl is absent)
DISPATCH_ID=$(openssl rand -hex 4 2>/dev/null || date +%s%N | sha1sum | head -c 8)

# session_id: prefer Claude Code injected env; fall back to unix ts + pid for uniqueness
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%s)-$$}"

# Progress file path; one file per dispatch, naturally disjoint across parallel dispatches
PROGRESS_PATH="/tmp/roundtable-progress/${SESSION_ID}-${DISPATCH_ID}.jsonl"

# Create directory and touch the file so `tail -F` starts clean
mkdir -p "$(dirname "$PROGRESS_PATH")" && touch "$PROGRESS_PATH"

# Export values so the next steps can inject them
echo "DISPATCH_ID=$DISPATCH_ID"
echo "PROGRESS_PATH=$PROGRESS_PATH"
```

Capture `DISPATCH_ID` and `PROGRESS_PATH` from Bash output; both are needed for Step 3.5.3 and 3.5.4.

### 3.5.3 Launch the Monitor

Immediately after the Bash preparation, launch `Monitor` with:

```
Monitor script: "tail -F ${PROGRESS_PATH} 2>/dev/null | jq -R --unbuffered -c 'fromjson? | select(.event) | \"[\" + .phase + \"] \" + .role + \" \" + .event + \" — \" + .summary' | awk 'BEGIN{last=\"\";n=0} {if($0==last){n++} else {if(n>1) print last\" (x\"n\")\"; else if(last!=\"\") print last; last=$0; n=1} fflush()} END{if(n>1) print last\" (x\"n\")\"; else if(last!=\"\") print last}'"
```

Notes:
- `tail -F` (capital F) survives the file briefly not existing and re-opens on truncation.
- `jq --unbuffered` defeats pipe buffering so each JSONL line is flushed as a separate notification. Without `--unbuffered`, jq may batch lines and delay the user-visible relay by several seconds.
- **`-R` + `fromjson?` (required fault tolerance)**: `-R` reads each line as a raw string and `fromjson?` attempts to parse it — the `?` swallows parse errors per line so unparseable input (garbled debug prints, truncated writes under disk pressure, concurrent interleaving) is silently skipped instead of aborting the whole pipe. Without this, a single malformed line makes jq exit 4 and silently kills the Monitor; all subsequent events are lost. See `docs/testing/subagent-progress-and-execution-model.md` Case 1.2 / 1.2b for the failure mode this guards against.
- `select(.event)` further filters out parsed-but-incomplete rows (valid JSON but missing `event` field).
- **awk consecutive-collapse filter (DEC-007 §3.4 bottom-layer guard)**: the trailing `awk` folds CONSECUTIVE identical lines only (not global uniq); guards against source-side drift without suppressing valid repeated phase tags separated by other events. Emits `<line> (xN)` when a run of ≥2 identical lines ends; `fflush()` after each print preserves per-line delivery to Claude Code's Monitor (matches the `--unbuffered` intent upstream). DEC-007 source-side content policy (in each agent's `## Progress Reporting → Content Policy`) is the primary defence; the awk layer is a cheap safety net.
- The formatted output becomes the "Real-time progress stream" line documented below the Phase Matrix.

### 3.5.4 Inject 4 variables into the Task prompt

Every `Task` call dispatched after Step 3.5.3 MUST inject these 4 variables into the subagent prompt (in addition to the regular context variables from Step 0):

| Variable | Source | Used by subagent |
|----------|--------|------------------|
| `progress_path` | `$PROGRESS_PATH` from Step 3.5.2 | `Bash echo '{...}' >> {{progress_path}}` at every phase boundary |
| `dispatch_id` | `$DISPATCH_ID` from Step 3.5.2 | included as `dispatch_id` JSON field in every emitted event |
| `slug` | from Step 3 (Slug + Artifact Handoff) | included as `slug` JSON field |
| `role` | the dispatched subagent role (`developer` / `tester` / `reviewer` / `dba` / `research`) | included as `role` JSON field |

The subagent's `## Progress Reporting` section handles the emit format; the orchestrator is only responsible for the 4-variable injection.

### 3.5.5 Lifecycle & cleanup

- `Monitor` runs in the background for the duration of the dispatch. When the `Task` call returns, `tail -F` idles (no new writes); the Monitor instance can be left to expire naturally, or explicitly torn down with `MonitorStop` if the orchestrator is about to dispatch another subagent and wants a clean channel. Default: let it expire.
- Progress files accumulate under `/tmp/roundtable-progress/`; rely on OS tmpfiles.d cleanup (DEC-004 §3.5). Plugin does not gc.

### 3.5.6 Parallel-dispatch safety

Per DEC-004 §3.7 and DEC-002 §4 parallel dispatch rules, each parallel `Task` gets its own `DISPATCH_ID` → its own `PROGRESS_PATH` → its own `Monitor`. The 4 conditions of the parallel decision tree hold:

1. **PREREQ MET** — progress files only append, no pre-existing state required.
2. **PATH DISJOINT** — per-dispatch filename (`${SESSION_ID}-${DISPATCH_ID}.jsonl`) guarantees disjoint file sets.
3. **SUCCESS-SIGNAL INDEPENDENT** — each `Monitor` watches a distinct file; its notifications are scoped to one `dispatch_id`.
4. **RESOURCE SAFE** — no shared lock on `/tmp/roundtable-progress/`; concurrent `tail -F` on distinct files is OS-level safe.

Parallel dispatches therefore produce interleaved notifications in the user's stream, each prefixed with `role` and tagged by `phase` — the `dispatch_id` is preserved in the underlying JSONL for debug / audit but not rendered in the default format.

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

1. **Phase gating taxonomy (DEC-006)**: every phase transition falls into one of three categories; gating behavior is determined by category.

   - **A. producer-pause** — phase ends with user-consumable artifacts. Stages: Research (analyst) / Design (architect Draft) / Closeout (Stage 9). Orchestrator emits a 3-line summary and **stops, invoking no tools**, waiting for the user's next message:
     ```
     ✅ <role> 完成。
     产出：
     - <path1> — <desc>
     - <path2> — <desc>
     请阅读后告诉我：`go` / `调范围: ...` / 问题
     ```
     User drives advancement via free-text: `go` / `继续` advances; `问: …` stays in FAQ (orchestrator answers directly or appends to the artifact's FAQ section per that role's convention); `调: …` re-dispatches the same role with expanded scope under the same slug; `停` aborts the workflow, leaving the Phase Matrix at the current stage.

   - **B. approval-gate** — hard directional lock. The ONLY B-class transition is Design confirmation (Stage 4). Orchestrator MUST invoke `AskUserQuestion` with options following the Option Schema (`feedback_askuserquestion_options`): Accept / Modify <specific part> / Reject / etc. Each option carries `rationale` + `tradeoff` + optional `recommended`. User's choice determines whether to advance to Implementation, re-dispatch architect, or abort.

   - **C. verification-chain** — internal machine/AI handoff with no user decision point. Stages: context-detect → analyst, design-confirm accepted → developer, developer → tester, tester → reviewer, reviewer → closeout, dba → closeout. Orchestrator **auto-advances**, emitting a single-line handoff notice (e.g., `🔄 developer 完成 → dispatching tester (critical_modules hit: [...])`). `critical_modules`-driven mandatory tester/reviewer dispatches remain in C (mechanical, CLAUDE.md pre-authorizes it; the handoff notice annotates `(critical_modules hit: ...)` for transparency). Critical findings / `<escalation>` blocks / lint+test failures still interrupt immediately per Step 5 and Step 6 rules 5–6. Before emitting the C-class handoff notice, the orchestrator MUST scan the subagent's final message for `<escalation>` tags; if present, suspend auto-advance and route through Step 5.

   **Phase Matrix → category mapping**:

   | Stage | Role | Category |
   |---|---|---|
   | 1. Context detection | inline | C |
   | 2. Research | analyst | A |
   | 3. Design | architect | A |
   | 4. Design confirmation | user | **B** |
   | 5. Implementation | developer | C |
   | 6. Adversarial testing | tester | C |
   | 7. Review | reviewer | C |
   | 8. DB review | dba | C |
   | 9. Closeout | user | A |

   See `{docs_root}/design-docs/phase-transition-rhythm.md` and DEC-006 for full rationale.

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

## Step 6b: Developer Form Selection (DEC-005)

The `developer` role supports two execution forms per DEC-005: `subagent` (DEC-001 D8 default) and `inline` (main-session execution of `agents/developer.md`). `tester` / `reviewer` / `dba` / `research` remain subagent-only (DEC-005 explicitly does not extend the dual-form pattern to them). This Step runs **immediately before** every developer dispatch.

### 6b.1 Default form

**Default = `subagent`** (preserves DEC-001 D8 role→form mapping). Switching to `inline` requires one of the three triggers in §6b.2 to fire.

### 6b.2 Three-level switch triggers (DEC-005 §3.4.2)

Evaluate in order; the first matching trigger wins.

1. **Per-session (user prompt)** — the user's current task description, or an earlier message in the same session, explicitly asks for inline:
   - Marker phrases: `@roundtable:developer inline`, `developer 用 inline`, `this developer task inline`, or natural-language equivalents the orchestrator recognizes.
   - Effect: force `form = inline` for this dispatch. No AskUserQuestion.

2. **Per-project (target CLAUDE.md)** — read the `# 多角色工作流配置` section (already parsed in Step 0) for the optional key:
   ```markdown
   developer_form_default: inline    # or: subagent
   ```
   If present, use its value as the baseline. If absent, baseline stays `subagent`. Per-session (level 1) still overrides per-project (level 2).

3. **Per-dispatch (AskUserQuestion)** — when neither of the above applies, invoke `AskUserQuestion` before dispatch. Build options following the architect's Option Schema (`rationale` + `tradeoff` + `recommended`). Choose the recommendation by the "small task signal" heuristic:
   - **Small task markers** (any one): single-file change, bug hotfix, estimated < 2 min wall time, estimated < 20k total tokens, strictly inside one module.
   - If small-task markers present → set `recommended: true` on the `inline` option.
   - Otherwise → set `recommended: true` on the `subagent` option.

   Example options payload:
   ```
   Option A: inline
     rationale: "Small task (1 file, bug hotfix) — inline keeps decisions visible and AskUserQuestion available."
     tradeoff:  "Pollutes main-session context with developer's reads/edits."
     recommended: true   # when small-task markers present
   Option B: subagent
     rationale: "Isolates developer's context and enables parallel dispatch."
     tradeoff:  "Progress only via phase-level events (DEC-004); interactive decisions gated through <escalation>."
     recommended: true   # when task is not small
   ```
   The user's answer is final; the orchestrator never overrides the user choice.

### 6b.3 Execution paths

Once `form` is decided:

**Form = `inline`** (small / single-file / hotfix path):
- Orchestrator `Read`s `agents/developer.md` and executes its instructions **in the main session** (same mechanism as the `architect` and `analyst` skills).
- `AskUserQuestion` is directly available to the developer flow — no `<escalation>` indirection.
- **Do NOT run Step 3.5** for this dispatch (no `progress_path`, no `Monitor`, no 4-variable injection). The main session observes the developer flow directly; progress relay is redundant.
- Resource Access constraints match the subagent form (`agents/developer.md` Resource Access matrix applies identically; see DEC-005 decision #7).
- `<escalation>` blocks are not needed; decisions go through `AskUserQuestion` inline.

**Form = `subagent`** (default path):
- Run Step 3.5 (Progress Monitor Setup) first.
- Dispatch via `Task` with the subagent prompt carrying the 4 progress injection variables plus the regular Step 0 context.
- Developer's `## Progress Reporting` section handles phase-boundary emits; `<escalation>` handles user-decision points per Step 5.

### 6b.4 tester / reviewer / dba / research remain subagent-only

Per DEC-005, do NOT offer an inline form for `tester`, `reviewer`, `dba`, or `research`:
- Their contexts are large (adversarial test suites / full-repo review / cross-schema DB analysis / fan-out research) and inline execution would pollute or exhaust main-session context.
- These four roles always go through `Task` dispatch and always receive the 4 progress variables from Step 3.5.
- The per-project `developer_form_default` key in CLAUDE.md applies ONLY to developer. Ignore any user attempt to set analogous keys for the other three roles — this is a DEC-005 boundary.

### 6b.5 Form selection audit trail

When form resolves to `inline`, include one-line note in the phase-gate summary: `Developer dispatched inline (trigger: <per-session | per-project | per-dispatch user choice>)`. This keeps the user informed that the usual subagent-boundary isolation was relaxed for this task.

---

## Step 7: Index Maintenance (batched)

When a role creates new artifacts under `{docs_root}/` (`analyze/` / `design-docs/` / `exec-plans/` / `api-docs/` / `testing/` / `reviews/`), the orchestrator owns the `{docs_root}/INDEX.md` update. Roles do NOT edit `INDEX.md` directly — same serialization pattern as exec-plan checkboxes (DEC-002 shared-resource protocol).

**Batching rule**: Do NOT update `INDEX.md` after every subagent return. Accumulate new-file reports across the phase and update the index **once per phase gate** (before reporting phase summary to the user), or at workflow completion. This keeps token overhead to a single Read + Edit cycle per phase, not per subagent.

**DEC-006 C-verification-chain bridging clause**: C-class transitions auto-advance with a 1-line handoff (no user-facing phase-gate summary). To keep `INDEX.md` fresh, the orchestrator MUST run Step 7 (single Read + Edit) **before emitting each C→C handoff notice**. At the next A-class producer-pause (including Stage 9 Closeout) the final flush covers any still-pending entries. This preserves the "single Edit per boundary" cost ceiling while preventing stale-index windows during long C chains.

**Steps**:

1. **Collect**: Every role's final report MUST list newly-created files under a `created:` section (not merely in prose). Orchestrator parses this from each `Task` result and from each skill's in-session output.
2. **Aggregate**: Accumulate `created[]` paths across parallel / sequential subagents within the current phase.
3. **Sync**: Before the phase-gate summary to the user, `Read` `{docs_root}/INDEX.md` once (or `Grep` for the category-section anchors if large).
4. **Update**: For each new path, identify its category (`analyze` / `design-docs` / `exec-plans/active` / `exec-plans/completed` / `testing` / `reviews` / `api-docs`) and append one line under the matching `### <category>` subsection. If no such subsection exists yet, create it.
5. **Single Edit**: One `Edit` call on `INDEX.md` covers all appends for the phase.
6. **Report**: Include "`INDEX.md` updated with N new entries" in the phase-gate summary.

**Entry format**:

```
- [<file>](<relative-path-from-INDEX.md>) — <one-line description>
```

Description source priority: artifact frontmatter `description:` → role's report `description:` line → first sentence of the artifact's introduction.

**Role report contract** (for `created:` section):

```
created:
  - path: {docs_root}/design-docs/feature-x.md
    description: Feature X design (API shape + data model + rollout phases)
  - path: {docs_root}/testing/feature-x.md
    description: Adversarial / benchmark plan for feature-x (18 cases)
```

**Fallback**: `/roundtable:lint` detects INDEX orphans / broken links as a safety net for missed Step 7 updates (periodic audit, not creation-time enforcement).

**Forbidden**: roles never edit `INDEX.md` themselves — writes always routed through orchestrator per DEC-002.

---

## Starting Point

1. Run Step 0 inline (context detection).
2. Run Step 1 (task sizing). If ambiguous, `AskUserQuestion`.
3. Initialize the Phase Matrix (all ⏳).
4. Activate / dispatch the first role per the size pipeline.
5. Update the matrix at every phase transition and report it.
6. Accumulate `created:` paths from each role's report; update `INDEX.md` at phase gates per Step 7.
7. Obey the rules in Step 6.

**This command orchestrates only — it does not design, code, or review itself. Delegate all substantive work to the appropriate role.**
