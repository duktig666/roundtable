# CLAUDE.md

Roundtable is a Claude Code plugin that runs a multi-role AI workflow:
analyst → architect → developer → tester → reviewer → dba.

## Layout

- `agents/` — 4 subagents (developer, tester, reviewer, dba), English prompts
- `skills/` — 2 skills (analyst, architect), English prompts
- `commands/` — 3 commands (workflow, bugfix, lint), English prompts
- `hooks/` — SessionStart hook injects `docs_root` + `project_id`
- `docs/` — user-facing artifacts (analyze, design-docs, exec-plans, testing, reviews, bugfixes)
- `docs/_archive/` — pre-rewrite history kept for `git log` traceability; do not link to from new docs

## Output language

**Plugin prompts are language-neutral.** Output language for user-facing docs is determined by the **project's** CLAUDE.md (e.g., a project may declare `代码英文、注释中文、文档中文、回答中文`). Subagents inherit the project CLAUDE.md when invoked, so the language convention propagates automatically.

This plugin's templates use English section names; the LLM translates to the project's documentation language at write time.

## Coding principles

Inherit the four baselines from the parent CLAUDE.md at the workspace root: Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution.

Specific to this repo:
- **Two artifacts per task** (medium / large): architect first writes a design-doc (problem + solution + decisions, iterates with user), then writes an exec-plan (steps + verification, stable after design confirm). Small tasks combine both into a single exec-plan with a `## Solution` section.
- Subagents return short markdown summaries. If they need a decision, they print one line: `[NEED-DECISION] <topic> | options: A) <…> B) <…>`. The orchestrator parses it and calls `AskUserQuestion`.
- Channel rendering (TG / etc.) is the channel hook's job, not the skill's. Skills call `AskUserQuestion` plainly.

## Toolchain

- `lint_cmd`: `/roundtable:lint` (rebuilds `docs/INDEX.md`, reports orphans / broken links / stale exec-plans)
- `test_cmd`: dogfood — run `/roundtable:workflow` end-to-end on a sample task in a target project
- `dev_cmd`: `claude --plugin-dir <absolute path to this repo>`

## Conventions

- New `.md` user-facing docs go under one of the 7 dirs above. `lint` will discover them and add to `INDEX.md`. Don't hand-edit INDEX.md.
- One slug per task, kebab-case English (`user-auth`, `payment-idempotency`). The slug links design-doc → exec-plan → analyze → tests → reviews.
- exec-plan frontmatter must include `source: design-docs/<slug>.md` when a design-doc exists, so reviewer / dba / lint can resolve the linkage.
- When all checkboxes are ticked or an exec-plan is idle >30 days, lint suggests moving it from `active/` to `completed/`. The user moves it; lint never moves files.
