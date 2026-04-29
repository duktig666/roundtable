---
description: Run the multi-role workflow (analyst → architect → developer → tester → reviewer → dba) on a task.
argument-hint: <task description or issue #N>
---

# /roundtable:workflow

**Task**: $ARGUMENTS

Orchestrate the workflow. Don't design or code — dispatch each substantive step to a role. User-facing strings follow the project's CLAUDE.md language convention.

## Step 1: Read context

The SessionStart hook injects roundtable context (`Roundtable context:` block). Extract `docs_root`, `project_id`, `status`. If `status: needs-init`, call `AskUserQuestion` to confirm where to put `docs/`. Pick a kebab-case `slug` for this task (or ask).

## Step 2: Phase Matrix

Render and re-render before each phase transition and at every user pause. Status: ⏳ todo · 🔄 doing · ✅ done · ⏩ skipped.

| # | Role             | Output                                              | Optional? |
|---|------------------|-----------------------------------------------------|-----------|
| 1 | analyst (skill)  | `<docs_root>/analyze/<slug>.md`                     | yes (small task) |
| 2 | architect (skill)| `<docs_root>/design-docs/<slug>.md` (medium / large) | yes (small task) |
| 3 | user             | confirm design-doc                                   | yes (skipped if no design-doc) |
| 4 | architect (skill)| `<docs_root>/exec-plans/active/<slug>.md`           | no |
| 5 | user             | confirm exec-plan                                   | no |
| 6 | developer        | `src/`, `tests/`, exec-plan checkboxes ticked       | no |
| 7 | tester           | `<docs_root>/testing/<slug>.md`                     | yes |
| 8 | reviewer         | `<docs_root>/reviews/<YYYY-MM-DD>-<slug>.md`        | yes |
| 9 | dba              | `<docs_root>/reviews/<YYYY-MM-DD>-db-<slug>.md`     | yes (DB change only) |

## Step 3: Decide skip-list

Confirm task size with the user if not obvious:

- **small** (bug-ish / single file / docs / UI tweak) → architect skips phase 2 design-doc; writes only the exec-plan with an inline `## Solution` section. May also skip 1, 7, 8.
- **medium** (new feature / module change) → run phases 2-5; analyst optional; tester/reviewer when project's CLAUDE.md flags `critical_modules` or the change is risky
- **large** (cross-module / new module) → run everything

Trigger phase 9 (dba) iff the task touches schema, migrations, or hot SQL.

## Step 4: Run phases

Phase 1, 2, 4 are skills (run in main session via `Skill` tool):
- `Skill(skill: "roundtable:analyst", args: "<task summary + slug>")`
- `Skill(skill: "roundtable:architect", args: "<task summary + slug + analyst report path if any>")` — architect handles both phase 2 (design-doc) and phase 4 (exec-plan) internally; it pauses for user confirm between them.

Phase 3 and 5 are user gates. After architect produces design-doc (medium / large), render a 3-line summary + matrix and stop:

```
✅ architect — design-doc ready
file: <docs_root>/design-docs/<slug>.md
reply: `accept` / `modify: <…>` / `reject` / `ask: <…>`
```

On `accept`, architect proceeds to write the exec-plan, then pauses again for the second confirmation.

Phase 6–9 are subagents. Dispatch via `Agent` tool, one role per call:
- Pass: exec-plan path, `docs_root`, slug, optional design-doc path
- Read return text. Tick matrix status.
- **If return text contains `[NEED-DECISION]`**: parse the line, call `AskUserQuestion`, append answer to the exec-plan's `## Change Log`, then re-dispatch the same role with the answer.
- After phase 6 (developer), if the project's CLAUDE.md declares `critical_modules` and the diff hits one, phases 7 and 8 are mandatory; otherwise ask the user.

## Step 5: Closeout

After the last phase, render a closeout bundle and stop:

```
✅ all phases done
suggested commit message:
  <type>(<scope>): <summary>
  <body>
suggested PR title / body: …
reply: `go-commit` / `go-pr` / `go-all` / `modify: <…>` / `stop`
```

Never auto-run `git commit` / `git push` / `gh pr create` without an explicit `go-*`. Move the exec-plan from `active/` to `completed/` only after `go-commit` or `go-all`.

## Forbidden

- Skipping the user gates at phase 3 / phase 5
- Auto-running git or gh commands
- Designing or coding yourself instead of dispatching to a role
- Modifying CLAUDE.md
