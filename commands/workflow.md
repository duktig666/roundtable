---
description: Run the multi-role workflow (analyst → architect → developer → tester → reviewer → dba) on a task.
argument-hint: <task description or issue #N>
---

# /roundtable:workflow

**Task**: $ARGUMENTS

This command is a thin wrapper. The canonical workflow definition lives in `skills/workflow/SKILL.md`, which is also used by Codex and other runtimes.

Invoke: `Skill(skill: "roundtable:workflow", args: "$ARGUMENTS")`
