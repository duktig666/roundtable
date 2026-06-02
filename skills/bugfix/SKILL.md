---
name: bugfix
description: Bug-fix workflow. Skip analyst + design-doc phases; route directly to developer with a mandatory regression test.
argument-hint: <bug description or issue #N>
---

# /roundtable:bugfix

**Bug / Issue**: $ARGUMENTS

Fast path for fixing a bug. Skip analyst, design-doc, and user gates around design. User-facing strings follow the project's CLAUDE.md language convention.

## Step 1: Read context

SessionStart hook may inject `docs_root` + `project_id`. Pick a slug. If context is missing or `status: needs-init`, resolve `docs_root` before asking:

1. Scan CWD for child git projects with docs:
   `find . -maxdepth 2 -type d -name .git 2>/dev/null | sed 's|/.git$||' | sed 's|^\./||'`
2. Keep only candidates with `docs/` or `documentation/`; their `docs_root` is that directory.
3. If `$ARGUMENTS` uniquely mentions one candidate basename or path segment, use it. Prefer exact basename matches; if a shorter candidate name is embedded in a longer candidate name, treat that as ambiguous. If exactly one candidate exists, use it and report the choice.
4. If multiple candidates remain, ask the user to choose one using the runtime's user-question tool (`AskUserQuestion` in Claude Code, `request_user_input` in Codex when available, or normal chat if not).
5. If no candidate exists, ask the user where to put `docs/`.

**Channel broadcast**: same rule as `/roundtable:workflow` Step 2 — if telegram MCP is loaded, post a new `reply` at workflow start, each phase completion (Step 4 developer / Step 5 reviewer or dba / Step 6 postmortem), and closeout. Terminal-only output is a bug.

## Step 2: Locate the bug

- If the input is an issue # (`#123`, `gh issue view 123`, GitLab / Jira / URL), fetch the body
- Otherwise read the user's description and grep / `git blame` to find the suspect file
- **If the root cause is a design defect (not an implementation bug)**: stop. Tell the user to switch to `/roundtable:workflow` instead.

## Step 3: Tier the bug

| Tier | Trigger | Postmortem |
|------|---------|------------|
| 0 | single file + ≤80 LOC + no critical_modules hit | none |
| 1 | ≥2 files OR cross-module OR >80 LOC; no critical hit | none |
| 2 | critical_modules hit / production incident / data integrity | `<docs_root>/bugfixes/<slug>.md` |

LOC = `git diff --numstat` insertions + deletions. If unclear, ask the user.

## Step 4: Dispatch developer

Dispatch developer:

- Claude Code: `Agent(subagent_type: "roundtable:developer", ...)`
- Codex: read `agents/developer.md`, then call `spawn_agent` with `agent_type: "worker"` and a `message` containing that role prompt plus:

- bug description + root-cause analysis
- tier (0 / 1 / 2)
- explicit instruction: **must add a regression test**; do not refactor unrelated code

If developer returns `[NEED-DECISION]`, ask with the runtime's user-question tool and re-dispatch.

## Step 5: Verify + optional review

After developer returns:
- run `lint_cmd` + `test_cmd` (or whatever the project's CLAUDE.md declares); fail-fast to user
- if `critical_modules` was hit → dispatch reviewer
- if the bug touched schema / migrations / SQL → dispatch dba
- bugfix usually skips tester (developer added the regression test); add tester only if the bug exposed an uncovered boundary in a critical module

## Step 6: Tier 2 postmortem

Before closeout, if `tier == 2` and `<docs_root>/bugfixes/<slug>.md` doesn't exist, re-dispatch developer to write it. Template (output language follows project CLAUDE.md):

```
# <slug> — Postmortem

## Symptom
## Root Cause
## Fix
## Reproduction / Regression Test Path
## Prevention
```

## Step 7: Closeout

Same as `/roundtable:workflow` Step 5 — render commit / PR draft, wait for `go-commit` / `go-pr` / `go-all` / `stop`. Never auto-run git or gh.

## Forbidden

- Skipping the regression test
- Expanding scope beyond the bug
- Auto-running git or gh
