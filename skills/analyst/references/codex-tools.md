# Codex tool mapping — analyst skill

This skill is read-only by design. Under Codex the mapping is small; behaviour is identical.

## Tool equivalents

| Claude Code | Codex | Notes |
|---|---|---|
| `Read(file_path=...)` | `shell` → `cat`/`head`/`tail` | Used to read prior analyze reports, project files |
| `Grep(pattern=..., path=...)` | `shell` → `rg <pattern> <path>` | Source surveying |
| `Glob(pattern=...)` | `shell` → `find` / `rg --files` | — |
| `Bash(command=...)` | `shell` (native) | `git log`, `gh issue view`, etc. |
| `WebFetch(url=..., prompt=...)` | `web.run` (Codex web tool) or `shell` → `curl` + summarise | Codex `web.run` reads URLs; behaviour comparable |
| `WebSearch(query=...)` | `web.run` (Codex web tool) | Use the same query; analyst still produces facts only |
| `Write(file_path=..., content=...)` | `apply_patch` with `*** Add File:` | Used to create `<docs_root>/analyze/<slug>.md` |
| `Edit(file_path=..., old=..., new=...)` | `apply_patch` with `*** Update File:` | Used to append to `## FAQ` on follow-up |
| `AskUserQuestion(...)` | `request_user_input(prompt=..., options=[...])` | When research scope is ambiguous |
| `mcp__plugin_telegram_telegram__reply` | TG MCP optional under Codex | See workflow `references/codex-tools.md` TG section |

## Channel-aware decision prompt

Under Claude Code with TG MCP loaded, the analyst posts `a) … b) …` options via TG `reply` and waits for a text reply. Under Codex:

- If no TG MCP server is configured, use `request_user_input` with structured options. Each option label packs the fact + source URL/file:line + objective tradeoff (per SKILL.md "Asking the user").
- If a TG MCP server is configured (see workflow `references/codex-tools.md` TG section), the same channel-aware logic applies; use the Codex-side TG MCP tool name visible in `codex /mcp`.

Never mark `★ recommended` regardless of runtime — that is the architect's job.

## Boundaries unchanged

- Read-only on source / web / prior reports
- Writes only to `<docs_root>/analyze/<slug>.md` (and `## FAQ` appends on follow-ups)
- No git writes, no CLAUDE.md edits

These boundaries hold across runtimes; no Codex-specific exception applies.
