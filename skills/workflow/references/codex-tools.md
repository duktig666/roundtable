# Codex tool mapping — workflow skill

This skill is written in Claude Code idiom (`Skill`, `Agent`, `AskUserQuestion`, `TodoWrite`, `Read`, `Write`, `Edit`, `Grep`, `Glob`, `Bash`). Under Codex, invoke the equivalent Codex tool — behaviour is identical, only the tool name changes.

## Tool equivalents

| Claude Code | Codex | Notes |
|---|---|---|
| `Skill(skill: "roundtable:analyst", args: ...)` | Call the `analyst` skill via `/skills` or describe intent — Codex loads `skills/analyst/SKILL.md` directly | Both runtimes execute the same SKILL.md body |
| `Skill(skill: "roundtable:architect", args: ...)` | Same as analyst — `skills/architect/SKILL.md` | — |
| `Agent(subagent_type: "roundtable:developer", ...)` | `spawn_agent(task_name="developer", message=...)` + `wait_agent` + `close_agent` | One spawn per role; pass exec-plan path, `docs_root`, slug, optional design-doc path in the `message` |
| `AskUserQuestion(...)` | `request_user_input(prompt=..., options=[...])` | Schema is near 1:1; pack rationale into option labels |
| `TodoWrite(...)` | `update_plan(plan=[...])` | Codex schema is simpler; use it for matrix-style tracking |
| `Read(file_path=...)` | `shell` → `cat <path>` / `head -n N <path>` / `tail -n N <path>` | No dedicated Read tool in Codex |
| `Grep(pattern=..., path=...)` | `shell` → `rg <pattern> <path>` | `rg` is preferred over `grep` for speed |
| `Glob(pattern=...)` | `shell` → `find <root> -name '<pattern>'` or `rg --files \| rg '<pattern>'` | — |
| `Write(file_path=..., content=...)` | `apply_patch` with `*** Add File:` block | Unified diff format |
| `Edit(file_path=..., old=..., new=...)` | `apply_patch` with `*** Update File:` block | Unified diff format; preserve surrounding context lines |
| `Bash(command=...)` | `shell` (native) | Codex shell is the workhorse for everything non-patch |
| `mcp__plugin_telegram_telegram__reply` | TG MCP optional — see TG MCP section below | Codex MCP tool naming differs |

## Subagent dispatch (Phase 6–9)

Claude Code:
```
Agent(subagent_type: "roundtable:developer", prompt: "<exec-plan path> ...")
```

Codex:
```
spawn_agent(
  task_name="developer",
  message="exec-plan: <path>\ndocs_root: <path>\nslug: <slug>\ndesign-doc (optional): <path>"
)
# … other work in parallel if needed …
wait_agent(task_name="developer")
close_agent(task_name="developer")
```

The four subagent files (`agents/developer.md`, `tester.md`, `reviewer.md`, `dba.md`) work in both runtimes. Under Codex the frontmatter `tools:` field is not enforced; each agent's prose now contains the equivalent restrictions (see `agents/reviewer.md` and `agents/dba.md` Forbidden sections).

## `[NEED-DECISION]` relay

When a subagent's return text contains:

```
[NEED-DECISION] <topic> | options: A) <…> B) <…>
```

Parse one line; ask the user; append answer to exec-plan `## Change Log`; re-dispatch the same role. The mechanism is identical across runtimes. Under Codex use `request_user_input` instead of `AskUserQuestion`:

```
request_user_input(
  prompt="<topic>",
  options=[
    {"label": "A", "description": "<rationale + tradeoff>"},
    {"label": "B", "description": "<rationale + tradeoff>"}
  ]
)
```

## TG MCP (optional under Codex)

The channel-aware logic in Step 2 checks whether a Telegram MCP server is loaded. Under Claude Code this server is typically `plugin:telegram:telegram` and exposes `mcp__plugin_telegram_telegram__reply` / `edit_message` / `react`.

Under Codex, TG is optional. If you want phase broadcasts to TG:

1. Configure a TG MCP server in `~/.codex/config.toml`:
   ```
   codex mcp add telegram -- <your-telegram-mcp-command>
   ```
2. Confirm the server is loaded: `codex /mcp`
3. The channel-aware check will then post via the Codex-side TG MCP tool name (visible in `/mcp` output).

If no TG MCP is loaded, the workflow degrades to terminal mode automatically — `request_user_input` for gates, plain stdout for phase summaries. This is the default Codex experience and is fully functional.

## Troubleshooting

### `spawn_agent` reports unknown tool

Codex subagent support is gated by the `[features].multi_agent` flag in `~/.codex/config.toml`. The flag defaults to `true` on current Codex builds; if your build differs:

```toml
[features]
multi_agent = true
```

Restart the Codex session after editing config.

### SessionStart hook context missing

If the `Roundtable context:` block is not visible to the workflow skill, check:

1. `~/.codex/config.toml` has `[features] plugin_hooks = true`
2. `.codex-plugin/plugin.json` `hooks.sessionStart` block is well-formed JSON
3. `${PLUGIN_ROOT}/hooks/session-start` is executable: `chmod +x hooks/session-start`
4. Run the hook standalone to verify output:
   ```
   bash hooks/session-start <<< '{}'
   ```
   Expected: a JSON object with `additionalContext` (or `additional_context` / `hookSpecificOutput.additionalContext` depending on env vars).

### `apply_patch` rejects an edit

Codex App's `workspace-write` sandbox does not block file edits, only writes outside the worktree. If `apply_patch` fails:

- Check the patch context lines exactly match (`apply_patch` is strict)
- Verify the file path is inside the worktree
- For new files, use `*** Add File:` not `*** Update File:`
