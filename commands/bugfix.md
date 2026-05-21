---
description: Bug-fix workflow. Skip analyst + design-doc phases; route directly to developer with a mandatory regression test.
argument-hint: <bug description or issue #N>
---

# /roundtable:bugfix

**Task**: $ARGUMENTS

This command is a thin wrapper. The canonical workflow definition lives in `skills/bugfix/SKILL.md`, which is also used by Codex and other runtimes.

Invoke: `Skill(skill: "roundtable:bugfix", args: "$ARGUMENTS")`
