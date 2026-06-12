---
name: workflow
description: Run the multi-role workflow (analyst → architect → developer → tester → reviewer → dba) on a task.
argument-hint: <task description or issue #N>
---

# /roundtable:workflow

**Task**: $ARGUMENTS

Orchestrate the workflow. Don't design or code — dispatch each substantive step to a role. User-facing strings follow the project's CLAUDE.md language convention.

## Step 1: Read context

The SessionStart hook may inject roundtable context (`Roundtable context:` block) when the runtime exposes hook additionalContext. Check `mode` first:

- **`mode: project`** — extract `docs_root`, `project_id`, `status`.
- **`mode: workspace`** — cwd is a parent workspace, not a single project; the context lists the git subprojects under `workspace_root` (`(docs)` marks those with a docs dir). Infer the **target subproject** from the task description / issue / files involved; if it can't be inferred, ask the user (channel-aware: TG `reply` if telegram MCP is loaded, else `AskUserQuestion`; options = the project list). Then resolve `docs_root = <workspace_root>/<project>/docs` and pass that `docs_root` in **every** role dispatch. This paragraph is the canonical workspace-resolution rule — `bugfix` and `lint` reference it.
- **Block missing** (runtime doesn't surface hook context) or **`status: needs-init`** — recover `docs_root` before asking:
  1. Scan CWD for child git projects with docs:
     `find . -maxdepth 2 -type d -name .git 2>/dev/null | sed 's|/.git$||' | sed 's|^\./||'`
  2. Keep only candidates with `docs/` or `documentation/`; their `docs_root` is that directory.
  3. If `$ARGUMENTS` uniquely mentions one candidate basename or path segment, use it. Prefer exact basename matches; if a shorter candidate name is embedded in a longer candidate name, treat that as ambiguous. If exactly one candidate exists, use it and report the choice.
  4. If multiple candidates remain, ask the user to choose one using the runtime's user-question tool (`AskUserQuestion` in Claude Code, `request_user_input` in Codex when available, or normal chat if not).
  5. If no candidate exists, ask the user where to put `docs/`.

Pick a kebab-case `slug` for this task (or ask).

## Step 2: Phase Matrix

Render before each phase transition and every user pause. Status: ⏳ todo · 🔄 doing · ✅ done · ⏩ skipped.

**Channel broadcast**: if the telegram MCP server is loaded (check system-reminders for `plugin:telegram:telegram`), the orchestrator must post a new `mcp__plugin_telegram_telegram__reply` at each of these points — terminal-only output is a bug:

- workflow start (matrix + config)
- each phase completion (1 / 2 / 4 / 6 / 7 / 8 / 9): one-line summary + output path + next phase
- each user gate (3 / 5): the `accept / modify / reject / ask` prompt
- workflow closeout (commit / PR bundle)

Use `edit_message` only for in-phase progress updates; phase *completion* must always be a new `reply` (edits don't push-notify). Skills own their own in-phase decision prompts; the orchestrator owns transition broadcasts — never assume a skill posted the completion message.

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

Phase 1, 2, 4 are skills (run in main session):

Claude Code:
- `Skill(skill: "roundtable:analyst", args: "<task summary + slug>")`
- `Skill(skill: "roundtable:architect", args: "<task summary + slug + analyst report path if any>")` — architect handles both phase 2 (design-doc) and phase 4 (exec-plan) internally; it pauses for user confirm between them.

Codex:
- Open `skills/analyst/SKILL.md` / `skills/architect/SKILL.md` and execute their instructions directly in the main session.
- If the skill needs runtime-specific tool syntax, read the matching `references/codex-tools.md` file first.

Phase 3 and 5 are user gates. After architect produces design-doc (medium / large), render a 3-line summary + matrix and stop:

```
✅ architect — design-doc ready
file: <docs_root>/design-docs/<slug>.md
reply: `accept` / `modify: <…>` / `reject` / `ask: <…>`
```

On `accept`, architect proceeds to write the exec-plan, then pauses again for the second confirmation.

Phase 6–9 are subagents. Dispatch one role per call:
- Claude Code: use `Agent(subagent_type: "roundtable:<role>", prompt: ...)`.
- Codex: first read `agents/<role>.md`, then call `spawn_agent` with `agent_type: "worker"` and a `message` containing that role prompt plus exec-plan path, `docs_root`, slug, optional design-doc path, and "You are not alone in the codebase; do not revert edits made by others." Keep the returned agent id for `wait_agent(targets: [id])` and `close_agent(target: id)`.
- For reviewer (phase 8), the dispatch prompt/message must also include the diff scope (git range or file list), per `agents/reviewer.md` inputs.
- Read return text. Tick matrix status.
- **If return text contains `[NEED-DECISION]`** (canonical NEED-DECISION relay rule — `bugfix` and the plugin CLAUDE.md reference it): parse the line, ask the user (TG `reply` with `a/b` options if telegram MCP is loaded; else the runtime's user-question tool, falling back to normal chat when needed), append answer to the exec-plan's `## Change Log`, then re-dispatch the same role with the answer.
- After phase 6 (developer), if the project's CLAUDE.md declares `critical_modules` and the diff hits one, phases 7 and 8 are mandatory; otherwise ask the user.

## Step 5: Closeout

### Step 0: Detect environment

Before rendering the closeout bundle, detect git state with read-only commands:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

Signals:
- `GIT_DIR != GIT_COMMON` → already in a linked worktree (Codex App / Claude Agent / user-created)
- `BRANCH` empty → detached HEAD

### Decision matrix

| Linked Worktree? | Detached HEAD? | Path |
|---|---|---|
| No | No | **Standard** (4-option menu below) |
| Yes | Yes | **Path A — handoff payload** (Codex App workspace-write sandbox) |
| Yes | No | Standard (Codex App Full access / manual worktree) |
| No | Yes | Standard with warning (unusual: manual detached HEAD) |

### Path A — handoff payload (Codex App detached HEAD)

When in a Codex App-managed worktree with detached HEAD, `git checkout -b` / `git push` / `gh pr create` are sandbox-blocked. Skip the 4-option menu. Instead:

1. Commit all uncommitted work (`git add` + `git commit` work in workspace-write sandbox)
2. Capture commit SHA: `COMMIT=$(git rev-parse HEAD)`
3. Output the handoff payload:

```
🚧 Codex App handoff (detached HEAD detected)

✅ all phases done; work committed locally at <COMMIT>
suggested branch name: feat/<slug>
suggested PR title: <type>(<scope>): <one-line summary>
suggested PR body:
  <body derived from exec-plan summary + design-doc summary>

Codex App cannot push from a sandboxed worktree. Use the App's native controls:
  - "Create branch" — names the branch, commits/pushes via App UI, opens PR
  - "Hand off to local" — transfers work to your local checkout

The exec-plan stays in active/ for now; after the App finishes the branch / PR, the next orchestrator session moves it to completed/ at closeout (lint will suggest the move once all checkboxes are ticked).
```

### Standard closeout (other paths)

After the last phase, render a closeout bundle and stop:

```
✅ all phases done
suggested commit message:
  <type>(<scope>): <summary>
  <body>
suggested PR title / body: …
reply: `go-commit` / `go-pr` / `go-all` / `modify: <…>` / `stop`
```

Never auto-run `git commit` / `git push` / `gh pr create` without an explicit `go-*`. Move the exec-plan from `active/` to `completed/` only after `go-commit` or `go-all`. At closeout, also move any leftover fully-ticked exec-plans in `active/` (e.g. from a prior Path A handoff whose branch / PR has since finished).

## Forbidden

- Skipping the user gates at phase 3 / phase 5
- Auto-running git or gh commands
- Designing or coding yourself instead of dispatching to a role
- Modifying CLAUDE.md
