# roundtable

[English](./README.md) · [中文](./README-zh.md)

> **Sit the analyst, architect, developer, tester, reviewer, and DBA at the same session, and push complex work forward with plan-then-execute discipline.**

`roundtable` is a multi-runtime plugin (Claude Code + Codex CLI + Codex App) that packages a multi-role AI development workflow into a one-line install. **Minimal-by-design**: 4 subagents + 2 skills + 3 commands + 1 SessionStart hook, with compact prompt+config files.

## Install

### From marketplace (recommended)

```
/plugin marketplace add duktig666/roundtable
/plugin install roundtable@roundtable --scope user
```

### Local install (for hacking / unreleased changes)

```bash
git clone git@github.com:duktig666/roundtable.git ~/code/roundtable
cd <your-project>
claude --plugin-dir ~/code/roundtable
```

Or register the local checkout as a marketplace:

```
/plugin marketplace add /absolute/path/to/roundtable
/plugin install roundtable@roundtable --scope user
```

Edits to the local files take effect on the **next session**.

### Codex CLI

```
codex plugin add github.com/duktig666/roundtable
```

Then run `/skills` inside Codex to confirm `workflow`, `bugfix`, `lint`, `analyst`, `architect` are loaded. Trigger by description (e.g. "run the multi-role workflow on this task") or pick from `/skills`.

### Codex App

In the Codex App plugin UI, add `github.com/duktig666/roundtable`. The App handles install + worktree provisioning. Closeout under an App-managed worktree (detached HEAD) emits a handoff payload instead of running `git push` / `gh pr create` — use the App's native "Create branch" / "Hand off to local" controls.

### Codex troubleshooting

- **`spawn_agent` reports unknown tool** — verify `~/.codex/config.toml` has `[features] multi_agent = true` (default `true` on current builds).
- **SessionStart `Roundtable context:` block missing** — verify `~/.codex/config.toml` has `[features] plugin_hooks = true`, the plugin root contains `hooks.json`, and `hooks/session-start` is executable. Some Codex CLI builds may not surface hook `additionalContext` in `codex exec`; in that case the workflow asks for `docs_root` as a fallback.
- **TG MCP is optional under Codex** — phase broadcasts automatically degrade to terminal mode when no TG MCP server is configured. To enable: `codex mcp add telegram -- <your-telegram-mcp-command>`; channel-aware logic then routes via the Codex-side TG MCP tool name (visible in `codex /mcp`).

## Use it in any project

```
/roundtable:workflow design the funding-rate feature
/roundtable:bugfix fix Issue #123
/roundtable:lint
```

Under Claude Code use the slash commands above. Under Codex CLI / App, describe the intent or select the skill from `/skills` — the same `skills/<name>/SKILL.md` definition executes in both runtimes.

## Why "roundtable"

> The Knights of the Round Table had no head seat — every knight sat as an equal and brought their expertise to a shared decision.

That's the model:

- **Analyst** runs the six-question framework (failure mode / 6-month review + 4 conditional questions) and emits **facts only** — no recommendations
- **Architect** consumes the analyst's facts; surfaces every architectural decision via the runtime's user-question mechanism; produces a **design-doc** for medium/large tasks (then a separate exec-plan after design confirm)
- **Developer** only touches code after the exec-plan is locked; writes failing tests first when behavior is non-trivial
- **Tester** writes adversarial / E2E / Playwright tests; finds business bugs without modifying business code
- **Reviewer / DBA** are read-only; reviewer flags Critical / Warning / Suggestion; DBA bans all SQL writes (no INSERT/UPDATE/ALTER/DROP)

## Design principles

1. **Zero-config install** — `plugin.json` has no userConfig prompts; toolchain auto-detected from project root files
2. **Two-track architect output** — design-doc (discussion-state, churns) and exec-plan (execution-state, stable) are separate files for medium/large tasks; small tasks combine both
3. **Decision-by-decision prompts** — architect asks at every key decision point, never piles them up at the end
4. **Interactive roles → skills, autonomous roles → subagents** — analyst/architect run in main session (need user decisions); developer/tester/reviewer/dba run as isolated subagents (clean context)
5. **`[NEED-DECISION]` pattern** — subagents can't pop dialogs; they print one line in their return text, the orchestrator parses it and asks the user, then re-dispatches
6. **SessionStart hook for `docs_root`** — bash detects context once at session start, in two modes: **project** (cwd inside a git repo: env override → `.roundtable.json` → repo-bounded walk-up) and **workspace** (cwd above multiple git projects: inject the project list, resolve docs_root per task). Roles read the injected context when the runtime exposes it, otherwise the skill falls back per workflow Step 1. See [SessionStart hook](#sessionstart-hook-docs_root-detection)
7. **Language-neutral plugin** — prompts in English; output language follows your project's CLAUDE.md (e.g. declare `文档中文` and all docs come out in Chinese)
8. **No mechanism bloat** — no decision-log / log.md / faq.md / progress JSONL / Monitor / `<escalation>` JSON. Decisions live inside exec-plan `## Key Decisions`; FAQ appends to the relevant analyze/design-doc; INDEX.md is rebuilt by `/roundtable:lint`

## Phase Matrix

`/roundtable:workflow` keeps a 9-stage status table live and re-emits it on every phase transition.

| # | Role             | Output                                            | Optional? |
|---|------------------|---------------------------------------------------|-----------|
| 1 | analyst (skill)  | `docs/analyze/<slug>.md`                          | yes (small) |
| 2 | architect (skill)| `docs/design-docs/<slug>.md`                      | yes (small) |
| 3 | user             | confirm design-doc                                 | yes (skipped if no design-doc) |
| 4 | architect (skill)| `docs/exec-plans/active/<slug>.md`                | no |
| 5 | user             | confirm exec-plan                                  | no |
| 6 | developer        | `src/`, `tests/`, exec-plan checkboxes ticked     | no |
| 7 | tester           | `docs/testing/<slug>.md`                           | yes |
| 8 | reviewer         | `docs/reviews/<YYYY-MM-DD>-<slug>.md`             | yes |
| 9 | dba              | `docs/reviews/<YYYY-MM-DD>-db-<slug>.md`          | yes (DB only) |

Status: ⏳ todo · 🔄 doing · ✅ done · ⏩ skipped

## Commands / Skills / Agents

| Type | Name | Purpose |
|------|------|---------|
| command | `/roundtable:workflow <task>` | Full orchestrator — auto-sizes, dispatches roles, handles user gates and `[NEED-DECISION]` |
| command | `/roundtable:bugfix <issue>` | Skip design phase, Tier 0/1/2 decision tree, mandatory regression test |
| command | `/roundtable:lint` | Read-only docs sweep; rebuilds `INDEX.md`; reports orphans / broken links / stale exec-plans |
| skill | `@roundtable:analyst` | Six-question framework, fact-only output |
| skill | `@roundtable:architect` | Two-track output: design-doc → user confirm → exec-plan → user confirm |
| subagent | `@roundtable:developer` | Implementation + unit tests; ticks exec-plan checkboxes |
| subagent | `@roundtable:tester` | Adversarial / E2E / Playwright; never touches `src/` |
| subagent | `@roundtable:reviewer` | Read-only review; emits `<docs_root>/reviews/<date>-<slug>.md` |
| subagent | `@roundtable:dba` | Read-only DB review; bans all SQL writes |

## Layout

```
your-project/docs/
├── INDEX.md                          ← /roundtable:lint auto-rebuilds
├── analyze/<slug>.md                 ← analyst
├── design-docs/<slug>.md             ← architect (medium/large only)
├── exec-plans/
│   ├── active/<slug>.md              ← architect + developer tick
│   └── completed/                    ← finished work
├── testing/<slug>.md                 ← tester
├── reviews/<YYYY-MM-DD>-<slug>.md    ← reviewer / dba
└── bugfixes/<slug>.md                ← Tier 2 postmortem
```

One slug per task (`user-auth`, `payment-idempotency`). exec-plan frontmatter carries `source: design-docs/<slug>.md` for linkage.

## SessionStart hook: docs_root detection

The hook runs on `startup|clear|compact` and injects a `Roundtable context:` block. Two modes:

**Project mode** (cwd inside a git repo). `docs_root` resolution order:

1. `ROUNDTABLE_DOCS_ROOT` env var — used as-is when the directory exists (no structure check); otherwise a `warning:` line is emitted and resolution falls through
2. `<git_top>/.roundtable.json` — flat JSON with two optional string keys: `docs_root` (absolute, or relative to the repo root; no structure check) and `project_id` (overrides the default id)

   ```json
   { "docs_root": "documents", "project_id": "my-project" }
   ```

3. Walk-up from cwd looking for `docs/` (then `documentation/`), **bounded by the repo root** — it never escapes into parent directories. A candidate counts as `status: ok` only if it contains one of the six roundtable dirs or `INDEX.md`; an unstructured hit is still reported, with `status: needs-init`.

Context fields: `mode / docs_root / docs_root_source (env|config|walk-up) / project_id / git_top / status`. In a linked worktree, `project_id` is the **main** repo's directory name.

**Workspace mode** (cwd not in a git repo, e.g. a parent dir holding several projects). The hook scans one level of subdirectories for git projects and injects `workspace_root` + the project list (`(docs)` marks projects that have a docs dir). Skills then resolve `docs_root = <workspace_root>/<project>/docs` per task — see workflow Step 1.

Output protocol: a single JSON line carrying both `additionalContext` and `hookSpecificOutput.additionalContext`; each runtime reads the key it understands and ignores the other.

## Compose with other plugins

roundtable = orchestration layer. Stack with:

- **[superpowers](https://github.com/obra/superpowers)** for engineering discipline (TDD / debugging / verification — auto-triggered)
- **[gstack](https://github.com/garrytan/gstack)** for explicit tools (`/cso` security audit, `/investigate` root-cause, `/codex` independent review, `/careful` destructive-cmd guard)

See [`docs/usage.md` §6](docs/usage.md) for which skills/commands to enable vs disable to avoid conflicts.

## Further reading

- [`docs/roundtable.md`](docs/roundtable.md) — architecture overview
- [`docs/usage.md`](docs/usage.md) — full usage guide
- [`docs/case-study-rewrite.md`](docs/case-study-rewrite.md) — case study: how we used roundtable to refactor itself
- [`CHANGELOG.md`](CHANGELOG.md) — version history
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — how to contribute

## License

[Apache-2.0](LICENSE)
