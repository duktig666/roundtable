# CLAUDE.md

Roundtable is a Claude Code plugin that runs a multi-role AI workflow:
analyst → architect → developer → tester → reviewer → dba.

## Layout

- `agents/` — 4 subagents (developer, tester, reviewer, dba), ~40 lines each, English
- `skills/` — 2 skills (analyst, architect), ~80 lines each, English
- `commands/` — 3 commands (workflow, bugfix, lint), English
- `hooks/` — SessionStart hook injects `docs_root` + `project_id`
- `docs/` — user-facing artifacts (analyze, exec-plans, testing, reviews, bugfixes); Chinese
- `docs/_archive/` — pre-rewrite history kept for `git log` traceability; do not link to from new docs

## Language

- Code & comments: English
- User-facing docs (`docs/analyze/`, `docs/exec-plans/`, `docs/testing/`, `docs/reviews/`, `docs/bugfixes/`): Chinese
- Plugin prompt files (`agents/*.md`, `skills/*/SKILL.md`, `commands/*.md`, `hooks/*`): English
- GitHub issue / PR title: English; body / comments: bilingual OK
- Replies to the user: Chinese

## Coding principles

Inherit the four baselines from the parent `CLAUDE.md` at the workspace root: Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution.

Specific to this repo:
- One artifact per task: architect writes a single exec-plan that contains the design + decisions + steps. No separate design-doc, no decision-log, no per-doc log entries.
- Subagents return short markdown summaries. If they need a decision, they print one line: `[NEED-DECISION] <topic> | options: A) <…> B) <…>`. The orchestrator parses that line and calls `AskUserQuestion`.
- TG / channel rendering is the channel hook's job, not the skill's. Skills call `AskUserQuestion` plainly.

## Toolchain

- `lint_cmd`: `/roundtable:lint` (rebuilds `docs/INDEX.md`, reports orphans / broken links / stale exec-plans)
- `test_cmd`: dogfood — run `/roundtable:workflow` end-to-end on a sample task in a target project
- `dev_cmd`: `claude --plugin-dir <absolute path to this repo>`

## Conventions

- New `.md` user-facing docs go under one of the 6 dirs above. `lint` will discover them and add to `INDEX.md`. Don't hand-edit INDEX.md.
- One slug per task, kebab-case English (`user-auth`, `payment-idempotency`). The slug links the analyze report → exec-plan → tests → reviews.
- When an exec-plan's checkboxes are all ticked or it's been idle >30 days, lint suggests moving it from `active/` to `completed/`. The user moves it; lint never moves files.
