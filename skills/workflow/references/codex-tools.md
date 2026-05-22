# Codex tool mapping — workflow skill

This skill is written in Claude Code idiom (`Skill`, `Agent`, `AskUserQuestion`, `TodoWrite`, `Read`, `Write`, `Edit`, `Grep`, `Glob`, `Bash`). Under Codex, keep the same workflow semantics but use the Codex tool wiring below.

## Tool equivalents

| Claude Code | Codex | Notes |
|---|---|---|
| `Skill(skill: "roundtable:analyst", args: ...)` | Call the `analyst` skill via `/skills` or describe intent — Codex loads `skills/analyst/SKILL.md` directly | Both runtimes execute the same SKILL.md body |
| `Skill(skill: "roundtable:architect", args: ...)` | Same as analyst — `skills/architect/SKILL.md` | — |
| `Agent(subagent_type: "roundtable:developer", ...)` | `spawn_agent(agent_type="worker", message=...)` + `wait_agent(targets=[id])` + `close_agent(target=id)` | One spawn per role; read `agents/<role>.md` first and embed that role prompt in the `message` |
| `AskUserQuestion(...)` | `request_user_input(questions=[...])` when available; otherwise ask in normal chat and wait | One question object with `header`, `id`, `question`, and 2-3 `options` |
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
result = spawn_agent(
  agent_type="worker",
  message="<contents of agents/developer.md>\n\nexec-plan: <path>\ndocs_root: <path>\nslug: <slug>\ndesign-doc (optional): <path>\n\nYou are not alone in the codebase; do not revert edits made by others."
)
# … other work in parallel if needed …
wait_agent(targets=[result.id])
close_agent(target=result.id)
```

The four subagent files (`agents/developer.md`, `tester.md`, `reviewer.md`, `dba.md`) are not auto-registered as Codex agent types. Under Codex, the orchestrator must read the target role file and embed it in the spawned worker's `message`. The frontmatter `tools:` field is not enforced; each agent's prose contains the equivalent restrictions (see `agents/reviewer.md` and `agents/dba.md` Forbidden sections).

## `[NEED-DECISION]` relay

When a subagent's return text contains:

```
[NEED-DECISION] <topic> | options: A) <…> B) <…>
```

Parse one line; ask the user; append answer to exec-plan `## Change Log`; re-dispatch the same role. The mechanism is identical across runtimes. Under Codex use `request_user_input` when available, otherwise ask in normal chat and wait:

```
request_user_input(
  questions=[
    {
      "header": "Decision",
      "id": "decision",
      "question": "<topic>",
      "options": [
        {"label": "A", "description": "<rationale + tradeoff>"},
        {"label": "B", "description": "<rationale + tradeoff>"}
      ]
    }
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

If no TG MCP is loaded, the workflow degrades to terminal mode automatically — `request_user_input` for gates when available, or normal chat prompts otherwise, plus plain stdout for phase summaries. This is the default Codex experience.

## Troubleshooting

### `spawn_agent` reports unknown tool

Codex subagent support is gated by the `[features].multi_agent` flag in `~/.codex/config.toml`. The flag defaults to `true` on current Codex builds; if your build differs:

```toml
[features]
multi_agent = true
```

Restart the Codex session after editing config.

### SessionStart hook context missing

Continue the workflow by asking the user for `docs_root`; the hook is an optimization, not a hard dependency.

If the `Roundtable context:` block is not visible to the workflow skill, check:

1. `~/.codex/config.toml` has `[features] plugin_hooks = true`
2. The plugin root contains `hooks.json` with a `SessionStart` hook
3. `${PLUGIN_ROOT}/hooks/session-start` is executable: `chmod +x hooks/session-start`
4. Run the hook standalone to verify output:
   ```
   bash hooks/session-start <<< '{}'
   ```
   Expected: a JSON object with `additionalContext` (or `additional_context` / `hookSpecificOutput.additionalContext` depending on env vars).

5. On Codex CLI builds where `codex exec` does not surface hook `additionalContext` to the model, use the fallback prompt path and ask once for `docs_root`.

### `apply_patch` rejects an edit

Codex App's `workspace-write` sandbox does not block file edits, only writes outside the worktree. If `apply_patch` fails:

- Check the patch context lines exactly match (`apply_patch` is strict)
- Verify the file path is inside the worktree
- For new files, use `*** Add File:` not `*** Update File:`
