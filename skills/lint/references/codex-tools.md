# Codex tool mapping — lint skill

This skill is mechanical and read-mostly. Under Codex the mapping is small.

## Tool equivalents

| Claude Code | Codex | Notes |
|---|---|---|
| `Read(file_path=...)` | `shell` → `cat <path>` | Used to read frontmatter + first H1 |
| `Grep(pattern=..., path=...)` | `shell` → `rg <pattern> <path>` | Used for broken-link detection (`\[.*\]\(.*\)`) |
| `Glob(pattern=...)` | `shell` → `find <docs_root> -name '*.md'` or `rg --files <docs_root>` | Discovers `.md` files in the 7 directories |
| `Bash(command=...)` | `shell` (native) | `git log -1 --format=%cs <file>` for stale-detection |
| `Write(file_path=..., content=...)` | `apply_patch` with `*** Add File:` or `*** Update File:` | Only writes `<docs_root>/INDEX.md` |

## Behaviour

The lint skill is fully self-contained: no subagents, no user input, no TG broadcasts. The only mutation is `<docs_root>/INDEX.md`. Everything else is read-only.
