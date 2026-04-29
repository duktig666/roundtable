---
description: Documentation health check. Rebuilds INDEX.md and reports orphans, broken links, stale exec-plans.
argument-hint: [target project path or "."]
---

# /roundtable:lint

Read-only docs sweep. Rebuilds `<docs_root>/INDEX.md`. Reports issues; does not auto-fix.

## Step 1: Read context

If `$ARGUMENTS` is an absolute path or `.`, use that as `target_project` directly. Otherwise read `docs_root` from session start context. If `docs_root` isn't set, abort with a one-line message asking the user to invoke from inside the target project or pass a path.

## Step 2: Rebuild INDEX.md

Scan every `.md` under `<docs_root>/{analyze,exec-plans/active,exec-plans/completed,testing,reviews,bugfixes}/`. For each, read frontmatter `slug` (or filename) and the first H1 heading. Write `<docs_root>/INDEX.md`:

```markdown
# 文档索引

> 由 `/roundtable:lint` 自动生成。手动修改会被下次 lint 覆盖。
> 上次更新：YYYY-MM-DD

## 调研报告 (analyze/)
- [<slug>](analyze/<slug>.md) — <first-H1>

## 执行计划 (exec-plans/active/)
- [<slug>](exec-plans/active/<slug>.md) — <first-H1>

## 已归档执行计划 (exec-plans/completed/)
- [<slug>](exec-plans/completed/<slug>.md) — <first-H1>

## 测试 (testing/)
- [<slug>](testing/<slug>.md) — <first-H1>

## 评审 (reviews/)
- [<YYYY-MM-DD>-<slug>](reviews/<YYYY-MM-DD>-<slug>.md) — <first-H1>

## Bug 复盘 (bugfixes/)
- [<slug>](bugfixes/<slug>.md) — <first-H1>
```

## Step 3: Issue checks

Report each finding under one of three buckets:

**Critical** (must fix):
- Broken internal links: any `[text](path)` or `[[page]]` whose target doesn't exist

**Warning** (should fix):
- Orphan files: a `.md` under one of the 6 dirs above that no other doc links to and that doesn't appear in INDEX.md (after rebuild)
- Stale active exec-plans: `<docs_root>/exec-plans/active/*.md` not modified in >30 days (use `git log -1 --format=%cs <file>`); suggest moving to `completed/`
- Fully-checked active exec-plans: every `- [ ]` is now `- [x]`; suggest moving to `completed/`

**Info**:
- Docs without an H1 heading
- Docs without a `slug:` frontmatter

## Step 4: Output

```markdown
# 文档健康检查报告

> 项目: <project_id>
> 日期: <YYYY-MM-DD>
> docs_root: <docs_root>

## Critical
- <path:line> — <issue> → <suggested action>

## Warning
- ...

## Info
- ...

## 统计
- INDEX.md 重建: <N> 条目
- Critical: <X>
- Warning: <Y>
- Info: <Z>
```

## Forbidden

- Modifying any file other than `<docs_root>/INDEX.md`
- Moving exec-plans (only suggest)
- Auto-fixing any reported issue
