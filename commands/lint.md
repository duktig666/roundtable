---
description: Documentation health check. Rebuilds INDEX.md and reports orphans, broken links, stale exec-plans.
argument-hint: [target project path or "."]
---

# /roundtable:lint

**Task**: $ARGUMENTS

This command is a thin wrapper. The canonical workflow definition lives in `skills/lint/SKILL.md`, which is also used by Codex and other runtimes.

Invoke: `Skill(skill: "roundtable:lint", args: "$ARGUMENTS")`
