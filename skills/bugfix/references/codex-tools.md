# Codex tool mapping — bugfix skill

This skill uses Claude Code idiom. Under Codex, invoke the equivalent tool — behaviour is identical.

## Tool equivalents

| Claude Code | Codex | Notes |
|---|---|---|
| `Agent(subagent_type: "roundtable:developer", ...)` | `spawn_agent(task_name="developer", message=...)` + `wait_agent` + `close_agent` | Pass bug description, tier, exec-plan path, slug |
| `AskUserQuestion(...)` | `request_user_input(prompt=..., options=[...])` | Used for tier disambiguation + `[NEED-DECISION]` relay |
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
spawn_agent(
  task_name="developer",
  message="bug: <description>\ntier: <0|1|2>\nslug: <slug>\ndocs_root: <path>\n\nMust add a regression test. Do not refactor unrelated code."
)
wait_agent(task_name="developer")
close_agent(task_name="developer")
```

## `[NEED-DECISION]` relay

Identical to workflow skill. Under Codex use `request_user_input`. See `skills/workflow/references/codex-tools.md` for the full pattern.

## Troubleshooting

### `spawn_agent` reports unknown tool

Verify `[features].multi_agent = true` in `~/.codex/config.toml`. Default is `true` on current builds.

### `apply_patch` rejects an edit

Verify context lines match exactly. For new files use `*** Add File:`, for existing files `*** Update File:`.
