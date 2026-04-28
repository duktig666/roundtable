---
description: Bug-fix workflow. Skip design phase; route directly to developer with a mandatory regression test.
argument-hint: <bug description or issue #N>
---

# /roundtable:bugfix

**Bug / Issue**: $ARGUMENTS

Fast path for fixing a bug. Skip analyst + architect + design confirmation.

## Step 1: Read context

The SessionStart hook injects `docs_root` + `project_id`. Pick a slug (or ask).

## Step 2: Locate the bug

- If the input is an issue # (`#123`, `gh issue view 123`, GitLab / Jira / URL), fetch the body
- Otherwise read the user's description and grep / `git blame` to find the suspect file
- **If you discover the root cause is a design defect (not an implementation bug)**: stop. Tell the user to switch to `/roundtable:workflow` instead.

## Step 3: Tier the bug

| Tier | Trigger | Postmortem |
|------|---------|------------|
| 0 | single file + ≤80 LOC + no critical_modules hit | none (conversation only) |
| 1 | ≥2 files OR cross-module OR >80 LOC; no critical hit | none |
| 2 | critical_modules hit / production incident / data integrity | `<docs_root>/bugfixes/<slug>.md` |

LOC = `git diff --numstat` insertions + deletions. If unclear, ask the user.

## Step 4: Dispatch developer

`Agent(subagent_type: "roundtable:developer", ...)` with:
- bug description + root-cause analysis
- tier (0 / 1 / 2)
- explicit instruction: **must add a regression test**; do not refactor unrelated code

If the developer returns `[NEED-DECISION]`, call `AskUserQuestion` and re-dispatch.

## Step 5: Verify + optional review

After developer returns:
- run `lint_cmd` + `test_cmd` (or use whatever the project's CLAUDE.md declares); fail-fast to user
- if `critical_modules` was hit → dispatch reviewer
- if the bug touched schema / migrations / SQL → dispatch dba
- bugfix usually skips tester (developer already added the regression test); add tester only if the bug exposed an uncovered boundary in a critical module

## Step 6: Tier 2 postmortem

Before closeout, if `tier == 2` and `<docs_root>/bugfixes/<slug>.md` doesn't exist, re-dispatch developer to write it. Template:

```markdown
# <slug> Postmortem

## 现象
## 根因
## 修复
## 复现 / 回归测试路径
## 防复发
```

## Step 7: Closeout

Same as `/roundtable:workflow` Step 5 — render commit / PR draft, wait for `go-commit` / `go-pr` / `go-all` / `停`. Never auto-run git or gh.

## Forbidden

- Skipping the regression test
- Expanding scope beyond the bug ("while I'm here" refactors → open a separate issue)
- Auto-running git or gh
