# 测试报告：issue #68 绝对路径残留修复回归

> 测试范围：`commands/workflow.md` Step 0.5 FAQ Sink example；`CLAUDE.md` §工具链覆盖 dev_cmd。
>
> 关联：issue #68（P3 bug）；源自 `docs/reviews/2026-04-21-reviewer-write-harness-override.md` W1。

## 背景

Reviewer W1 flag：派发 prompt 中出现 `/data/rsw/roundtable/skills/_progress-content-policy.md` 绝对路径，
在其他用户机器上 plugin 无法解析。违反 `feedback_no_absolute_paths_in_docs`。

实际定位：

- `skills/_progress-content-policy.md` 的引用（`agents/{developer,tester,reviewer,dba}.md`）**已**使用 `${CLAUDE_PLUGIN_ROOT}`（PR #64 DEC-017 完成），无需修改。
- 残留在两处**非引用**语境：
  1. `commands/workflow.md:71` — FAQ Sink Protocol 示例用 `/data/rsw/roundtable` 说明 `basename(target_project)`。
     这是 **runtime prompt** 的一部分，会随 orchestrator dispatch 下发到 subagent；虽是"example 字面值"
     而非路径引用，但派发时被 reviewer 模式扫描直接识别为绝对路径命中。
  2. `CLAUDE.md:38` — `dev_cmd` 示例含 `--plugin-dir /data/rsw/roundtable`，泄漏本地克隆路径。

## 修复

| 文件 | 修改 |
|---|---|
| `commands/workflow.md:71` | 示例 `/data/rsw/roundtable` → `target_project=/path/to/myapp` → `myapp` |
| `CLAUDE.md:38` | `/data/rsw/roundtable` → `<path-to-roundtable-clone>` 占位符 + 替换说明 |

注：`docs/**/*.md` 下的 dogfood trace / exec-plan / analyze / review 历史档保留绝对路径 —— 属于**内部
贡献者溯源**语境，非 runtime prompt 组合，不会被 dispatch 注入到 subagent prompt。

## 回归测试

**R-01**：runtime prompt 文件无绝对路径残留

```bash
grep -rn '/data/rsw/roundtable' commands/ agents/ skills/ CLAUDE.md
# 预期：0 命中
```

**R-02**：lint_cmd 无新增命中

```bash
grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/
# 预期：0 命中（与 CLAUDE.md §工具链覆盖 lint_cmd 一致）
```

**R-03**：`_progress-content-policy.md` 4 处引用仍用 `${CLAUDE_PLUGIN_ROOT}`

```bash
grep -rn '_progress-content-policy' agents/ | grep -v CLAUDE_PLUGIN_ROOT
# 预期：0 命中（所有引用必须 envvar 形式）
```

## 决策一致性

无新 DEC；属 bugfix 范畴。与 `feedback_no_absolute_paths_in_docs` 一致性恢复。

## 未修范围

- `docs/exec-plans/` / `docs/analyze/` / `docs/reviews/` 历史档中的绝对路径：保留（历史档不随 dispatch 下发，
  属内部贡献者读物）。若未来需要全局清洗可另开 issue。
- `docs/decision-log.md:117` / `:337` 等条目中的绝对路径：同上，保留。
