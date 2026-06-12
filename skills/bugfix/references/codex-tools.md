# Codex tool mapping — bugfix skill

This skill uses Claude Code idiom. Under Codex, keep the same bugfix workflow while using Codex tool wiring.

## Tool equivalents

| Claude Code | Codex | Notes |
|---|---|---|
| `Agent(subagent_type: "roundtable:developer", ...)` | `spawn_agent(agent_type="worker", message=...)` + `wait_agent(targets=[id])` + `close_agent(target=id)` | Read `agents/developer.md` first and embed it in the `message` |
| `AskUserQuestion(...)` | `request_user_input(questions=[...])` when available; otherwise ask in normal chat and wait | Used for tier disambiguation + `[NEED-DECISION]` relay |
| `Read(file_path=...)` | `shell` → `cat`/`head`/`tail` | — |
| `Grep(pattern=..., path=...)` | `shell` → `rg <pattern> <path>` | Used in Step 2 to locate the bug |
| `Glob(pattern=...)` | `shell` → `find` / `rg --files` | — |
| `Bash(command=...)` | `shell` (native) | `git blame`, `git log`, `gh issue view`, lint/test runners |
| `Write(file_path=..., content=...)` | `apply_patch` with `*** Add File:` | Tier 2 postmortem creation |
| `Edit(file_path=..., old=..., new=...)` | `apply_patch` with `*** Update File:` | exec-plan checkbox ticks |
| `mcp__plugin_telegram_telegram__reply` | TG MCP optional under Codex | See workflow `references/codex-tools.md` TG section |

## Subagent dispatch (Step 4)

Codex:
```
result = spawn_agent(
  agent_type="worker",
  message="<contents of agents/developer.md>\n\nexec-plan: <docs_root>/exec-plans/active/<slug>.md\nbug: <description>\ntier: <0|1|2>\nslug: <slug>\ndocs_root: <path>\n\nMust add a regression test. Do not refactor unrelated code.\nYou are not alone in the codebase; do not revert edits made by others."
)
wait_agent(targets=[result.id])
close_agent(target=result.id)
```

## `[NEED-DECISION]` relay

Identical to workflow skill. Under Codex use `request_user_input(questions=[...])` when available; otherwise ask the user in normal chat and stop until they reply. See `skills/workflow/references/codex-tools.md` for the full pattern.

## Troubleshooting

### `spawn_agent` reports unknown tool

Verify `[features].multi_agent = true` in `~/.codex/config.toml`. Default is `true` on current builds.

### `apply_patch` rejects an edit

Verify context lines match exactly. For new files use `*** Add File:`, for existing files `*** Update File:`.
