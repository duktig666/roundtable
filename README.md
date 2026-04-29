# roundtable

[English](./README.md) · [中文](./README-zh.md)

> **Sit the analyst, architect, developer, tester, reviewer, and DBA at the same Claude Code session, and push complex work forward with plan-then-execute discipline.**

`roundtable` is a [Claude Code](https://code.claude.com) plugin that packages a multi-role AI development workflow into a one-line install. **Minimal-by-design**: 4 subagents + 2 skills + 3 commands + 1 SessionStart hook, ~760 lines of prompt+config total.

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

## Use it in any project

```
/roundtable:workflow design the funding-rate feature
/roundtable:bugfix fix Issue #123
/roundtable:lint
```

## Why "roundtable"

> The Knights of the Round Table had no head seat — every knight sat as an equal and brought their expertise to a shared decision.

That's the model:

- **Analyst** runs the six-question framework (failure mode / 6-month review + 4 conditional questions) and emits **facts only** — no recommendations
- **Architect** consumes the analyst's facts; surfaces every architectural decision via `AskUserQuestion`; produces a **design-doc** for medium/large tasks (then a separate exec-plan after design confirm)
- **Developer** only touches code after the exec-plan is locked; writes failing tests first when behavior is non-trivial
- **Tester** writes adversarial / E2E / Playwright tests; finds business bugs without modifying business code
- **Reviewer / DBA** are read-only; reviewer flags Critical / Warning / Suggestion; DBA bans all SQL writes (no INSERT/UPDATE/ALTER/DROP)

## Design principles

1. **Zero-config install** — `plugin.json` has no userConfig prompts; toolchain auto-detected from project root files
2. **Two-track architect output** — design-doc (discussion-state, churns) and exec-plan (execution-state, stable) are separate files for medium/large tasks; small tasks combine both
3. **Decision-by-decision popups** — architect fires `AskUserQuestion` at every key decision point, never piles them up at the end
4. **Interactive roles → skills, autonomous roles → subagents** — analyst/architect run in main session (need `AskUserQuestion`); developer/tester/reviewer/dba run as isolated subagents (clean context)
5. **`[NEED-DECISION]` pattern** — subagents can't pop dialogs; they print one line in their return text, the orchestrator parses it and asks the user, then re-dispatches
6. **SessionStart hook for `docs_root`** — bash detects `docs_root` + `project_id` once at session start (env override → walk-up tree → `needs-init` fallback); all roles read from injected context, no inline detection
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
