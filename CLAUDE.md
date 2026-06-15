# CLAUDE.md

Roundtable is a Claude Code plugin that runs a multi-role AI workflow:
analyst → architect → developer → tester → reviewer → dba.

## Layout

- `agents/` — 4 subagents (developer, tester, reviewer, dba), English prompts
- `skills/` — 5 skills (analyst, architect, workflow, bugfix, lint), English prompts
- `skills/*/references/` — per-skill `codex-tools.md` (Claude Code → Codex tool-mapping tables)
- `commands/` — 3 thin command shells (workflow, bugfix, lint), each dispatching to the same-named skill
- `hooks/` — `session-start` script (injects `docs_root` + `project_id`), `hooks/hooks.json` (Claude Code registration), and `hooks/hooks-codex.json` (Codex registration)
- `.codex-plugin/plugin.json` — Codex manifest; `hooks` explicitly points at `./hooks/hooks-codex.json` so Codex does not fall back to the Claude-side `hooks/hooks.json`
- `tests/` — two hook test suites (`session-start.test.sh`, `session-start.adversarial.test.sh`)
- `.codex-plugin/` — Codex manifest (`plugin.json`)
- `AGENTS.md` — single-line pointer file (`CLAUDE.md`) for Codex
- `docs/` — user-facing artifacts (analyze, design-docs, exec-plans, testing, reviews, bugfixes)

## Output language

**Plugin prompts are language-neutral.** Output language for user-facing docs is determined by the **project's** CLAUDE.md (e.g., a project may declare `代码英文、注释中文、文档中文、回答中文`). Subagents inherit the project CLAUDE.md when invoked, so the language convention propagates automatically.

This plugin's templates use English section names; the LLM translates to the project's documentation language at write time.

## Coding principles

Inherit the four baselines from the parent CLAUDE.md at the workspace root: Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution.

Specific to this repo:
- **Two artifacts per task** (medium / large): architect first writes a design-doc (problem + solution + decisions, iterates with user), then writes an exec-plan (steps + verification, stable after design confirm). Small tasks combine both into a single exec-plan with a `## Solution` section.
- Subagents return short markdown summaries. If they need a decision, they print one line: `[NEED-DECISION] <topic> | options: A) <…> B) <…>`. The orchestrator relays it per the canonical NEED-DECISION relay rule in `skills/workflow/SKILL.md` Step 4.
- Channel-aware user prompts: if the telegram MCP server is loaded, skills + orchestrator post questions via TG `reply` (`a) … b) …` text protocol) and wait for a text reply; otherwise they call `AskUserQuestion`. The workflow orchestrator also broadcasts phase transitions to TG when the MCP is present (use `edit_message` for in-phase updates, new `reply` for phase completion so the device push-notifies).

## Toolchain

- `lint_cmd`: `/roundtable:lint` (rebuilds `docs/INDEX.md`, reports orphans / broken links / stale exec-plans)
- `test_cmd`: dogfood — run `/roundtable:workflow` end-to-end on a sample task in a target project
- `dev_cmd`: `claude --plugin-dir <absolute path to this repo>`

## Conventions

- New `.md` user-facing docs go under one of the 7 dirs above. `lint` will discover them and add to `INDEX.md`. Don't hand-edit INDEX.md.
- One slug per task, kebab-case English (`user-auth`, `payment-idempotency`). The slug links design-doc → exec-plan → analyze → tests → reviews.
- exec-plan frontmatter must include `source: design-docs/<slug>.md` when a design-doc exists, so reviewer / dba / lint can resolve the linkage.
- When all checkboxes are ticked or an exec-plan is idle >30 days, lint suggests moving it from `active/` to `completed/`. The orchestrator moves it at closeout (only after `go-commit` / `go-all` — see `skills/workflow/SKILL.md` Step 5); lint never moves files.
