---
description: Run the multi-role workflow (analyst → architect → developer → tester → reviewer → dba) on a task.
argument-hint: <task description or issue #N>
---

# /roundtable:workflow

**Task**: $ARGUMENTS

You orchestrate the workflow. You don't design or code yourself — every substantive step goes to a role.

## Step 1: Read context

The SessionStart hook injects roundtable context (look for "Roundtable context:" in the session). Extract `docs_root`, `project_id`, and `status`. If `status: needs-init`, call `AskUserQuestion` to confirm where to put `docs/`. Pick a kebab-case `slug` for this task (or ask the user).

## Step 2: Phase Matrix

Maintain this 7-row table for the lifetime of the workflow. Re-emit the full table to the user before each phase transition and at every user pause. Status: ⏳ todo · 🔄 doing · ✅ done · ⏩ skipped.

| # | Role             | Output                                            | Optional? |
|---|------------------|---------------------------------------------------|-----------|
| 1 | analyst (skill)  | `<docs_root>/analyze/<slug>.md`                   | yes (small task) |
| 2 | architect (skill)| `<docs_root>/exec-plans/active/<slug>.md`         | no |
| 3 | user             | confirm exec-plan                                 | no |
| 4 | developer        | `src/`, `tests/`, exec-plan checkboxes ticked     | no |
| 5 | tester           | `<docs_root>/testing/<slug>.md`                   | yes |
| 6 | reviewer         | `<docs_root>/reviews/<YYYY-MM-DD>-<slug>.md`      | yes |
| 7 | dba              | `<docs_root>/reviews/<YYYY-MM-DD>-db-<slug>.md`   | yes (DB change only) |

## Step 3: Decide skip-list

Ask the user to confirm task size if it's not obvious from the prompt:

- **small** (bug-ish / single file / docs / UI tweak) → consider `/roundtable:bugfix` instead, or skip phase 1, 5, 6
- **medium** (new feature / module change) → run all of 2, 3, 4; analyst optional; tester/reviewer when project's CLAUDE.md flags it as `critical_modules` or when the change is risky
- **large** (cross-module / new module) → run everything

Trigger phase 7 (dba) iff the task touches schema, migrations, or hot SQL.

## Step 4: Run phases

Phase 1 and 2 are skills (run in main session via the `Skill` tool):
- `Skill(skill: "roundtable:analyst", args: "<task summary + slug>")`
- `Skill(skill: "roundtable:architect", args: "<task summary + slug + analyst report path if any>")`

Phase 3 is a user gate. After architect finishes, render a 3-line summary + the matrix, then **stop**:

```
✅ architect 完成。
exec-plan: <docs_root>/exec-plans/active/<slug>.md
请阅读后告诉我：`go` / `问: ...` / `调: ...` / `停`
```

`go` → advance to phase 4. `问:` → re-dispatch architect to answer and append to FAQ. `调:` → re-dispatch with widened/narrowed scope. `停` → halt.

Phase 4–7 are subagents. Dispatch via `Agent` tool, one role per Agent call:
- Pass: exec-plan path, `docs_root`, slug
- Read the subagent's return text. Tick matrix status.
- **If return text contains `[NEED-DECISION]`**: parse the line, call `AskUserQuestion` with the options, append answer to the exec-plan under a "## 决策追加" section, then re-dispatch the same role with the answer.
- After phase 4 (developer), if the project has `critical_modules` declared in its CLAUDE.md and the diff hits one, phases 5 and 6 are mandatory; otherwise ask the user.

## Step 5: Closeout

After the last phase, render a closeout bundle and **stop**:

```
✅ 全部阶段完成。
建议 commit message:
  <type>(<scope>): <one-line summary>
  <body>
建议 PR title / body: …
请确认：`go-commit` / `go-pr` / `go-all` / `调: ...` / `停`
```

Never auto-run `git commit` / `git push` / `gh pr create` without an explicit `go-*` from the user. Move the exec-plan from `active/` to `completed/` only after `go-commit` or `go-all`.

## Forbidden

- Skipping the user gate at phase 3
- Auto-running git or gh commands
- Designing or coding yourself instead of dispatching to a role
- Modifying CLAUDE.md
