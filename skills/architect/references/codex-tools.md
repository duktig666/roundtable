# Codex tool mapping — architect skill

This skill orchestrates research, decisions, and emits the design-doc + exec-plan. Under Codex, keep the same architecture workflow while using Codex tool wiring.

## Tool equivalents

| Claude Code | Codex | Notes |
|---|---|---|
| `Skill(skill: "roundtable:analyst")` | Call the `analyst` skill via `/skills` or describe intent | Both runtimes execute `skills/analyst/SKILL.md` |
| `Agent(...)` for general-purpose research fan-out | `spawn_agent(agent_type="explorer", message=...)` + `wait_agent(targets=[id])` + `close_agent(target=id)` | Up to 3 parallel spawns per Workflow Step 3 |
| `AskUserQuestion(...)` | `request_user_input(questions=[...])` when available; otherwise ask in normal chat and wait | Used at every architectural decision point — one per call |
| `Read(file_path=...)` | `shell` → `cat`/`head`/`tail` | Read prior design-docs, exec-plans, analyst report |
| `Grep(pattern=..., path=...)` | `shell` → `rg <pattern> <path>` | Slug-collision check, prior decision check |
| `Glob(pattern=...)` | `shell` → `find` / `rg --files` | — |
| `Bash(command=...)` | `shell` (native) | `git log` for context |
| `Write(file_path=..., content=...)` | `apply_patch` with `*** Add File:` | Creates design-doc + exec-plan |
| `Edit(file_path=..., old=..., new=...)` | `apply_patch` with `*** Update File:` | Iterates design-doc on `modify`; appends `## Change Log` |
| `mcp__plugin_telegram_telegram__reply` | TG MCP optional under Codex | See workflow `references/codex-tools.md` TG section |

## Research fan-out (Workflow Step 3)

Claude Code:
```
# In a single assistant message, multiple Agent calls in parallel:
Agent(subagent_type: "general-purpose", prompt: "<research topic 1>")
Agent(subagent_type: "general-purpose", prompt: "<research topic 2>")
Agent(subagent_type: "general-purpose", prompt: "<research topic 3>")
```

Codex:
```
# In a single assistant message, multiple spawn_agent calls in parallel:
a = spawn_agent(agent_type="explorer", message="<topic 1>")
b = spawn_agent(agent_type="explorer", message="<topic 2>")
c = spawn_agent(agent_type="explorer", message="<topic 3>")
# Then collect:
wait_agent(targets=[a.id, b.id, c.id])
close_agent(target=a.id)
close_agent(target=b.id)
close_agent(target=c.id)
```

Limit: at most 3 parallel research agents (per Workflow Step 3).

## Decision protocol (channel-aware)

The architect asks the user at every architectural decision point. Under Claude Code with TG MCP loaded, options go via TG `reply` with `a) … b) … c) …` labelled text and the architect waits for a text reply.

Under Codex:

- If no TG MCP server is configured and `request_user_input` is available: call `request_user_input(questions=[...])` with structured options. Pack rationale + tradeoff into each option's `description`. At most one option marked `★ Recommended`. If no preference, recommend nothing.
- If `request_user_input` is not available in the current Codex mode: ask the same options in normal chat and stop until the user replies.
- If a TG MCP server is configured (see workflow `references/codex-tools.md`): use the channel-aware TG branch; do not call `request_user_input` (it would block the TG flow).

One decision per call. Batch only **independent** decisions into a single call.

## Boundaries unchanged

- Read-only on `src/`, `tests/`
- Writes only to design-doc + exec-plan + (optional) `<docs_root>/analyze/<slug>.md` FAQ append
- No git writes
- No CLAUDE.md edits

These hold across runtimes.
