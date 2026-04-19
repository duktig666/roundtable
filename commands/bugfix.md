---
description: Bug fix workflow. Skips design phase and routes directly through developer → (optional tester/reviewer/dba) with mandatory regression test.
argument-hint: <bug 描述 或 issue 编号>
---

# Bug Fix 工作流

你即将为以下 bug 编排修复流程：

**Bug 描述 / Issue**：$ARGUMENTS

---

## 执行前提

本命令要求项目已按 roundtable 约定组织 docs 目录。若尚未配置，先提醒用户按 plugin 仓库的 `docs/claude-md-template.md` 补齐 `target_project/CLAUDE.md` 的「# 多角色工作流配置」section。

---

## Step 0: Project Context Detection

**Execute the 4-step detection inline** — `Read` `skills/_detect-project-context.md` and follow the 4 steps directly. Do NOT use the `Skill` tool to activate the underscore-prefixed helper.

The 4 steps: D9 target-project identification → toolchain detection → `docs_root` detection → `CLAUDE.md` "# 多角色工作流配置" loading.

When later dispatching `developer` / `tester` / `reviewer` / `dba` agents, inject the detected values (`target_project`, `docs_root`, `lint_cmd`, `test_cmd`, `critical_modules`, `slug`, `primary_lang`) in the dispatch prompt.

---

## Step 0.5: Progress Monitor Setup

**See `commands/workflow.md` §Progress Monitor Setup for the full template.** The bugfix command reuses the same mechanism with the following deltas:

1. **Default fan-out is narrower**: bugfix typically dispatches only ONE developer subagent (plus an optional reviewer / dba / tester). Run the Monitor setup per dispatch — one `dispatch_id` + one `progress_path` per subagent.
2. **Opt-out env**: `ROUNDTABLE_PROGRESS_DISABLE=1` suppresses Monitor startup + progress injection, identical to workflow semantics.
3. **Per-dispatch Bash (run before every `Task` call)** — identical to the workflow template:
   - Generate `DISPATCH_ID=$(openssl rand -hex 4)`
   - Derive `PROGRESS_PATH=/tmp/roundtable-progress/${SESSION_ID}-${DISPATCH_ID}.jsonl` (with `SESSION_ID=${CLAUDE_SESSION_ID:-$(date +%s)-$$}`)
   - `mkdir -p` + `touch` the file
   - Launch `Monitor` with `tail -F "$PROGRESS_PATH" 2>/dev/null | jq -R --unbuffered -c 'fromjson? | select(.event) | "[" + .phase + "] " + .role + " " + .event + " — " + .summary' | awk 'BEGIN{last="";n=0} {if($0==last){n++} else {if(n>1) print last" (x"n")"; else if(last!="") print last; last=$0; n=1} fflush()} END{if(n>1) print last" (x"n")"; else if(last!="") print last}'`（`-R` + `fromjson?` makes the pipe tolerant to malformed lines; without them a single bad line kills Monitor and loses all later events — see `commands/workflow.md` §3.5.3 Notes + `docs/testing/subagent-progress-and-execution-model.md` Case 1.2. The trailing `awk` folds CONSECUTIVE identical lines only (not global uniq) per DEC-007 §3.4 as a source-drift safety net.）
4. **Inject 4 variables** (`progress_path`, `dispatch_id`, `slug`, `role`) into the `developer` / `tester` / `reviewer` / `dba` Task prompt. The subagent's `## Progress Reporting` section consumes them.
5. Relay each Monitor notification to the user in real time with the `[<phase>] <role> <event> — <summary>` format (DEC-004).

If the user has no `developer_form_default` preference and the bugfix runs inline (see Step 3 Developer Form Selection below), **skip Monitor setup for the inline branch** — the main session observes the developer directly, no progress emit is produced.

---

## 步骤 1：定位问题

1. 如有 GitHub Issue 编号，用 `gh issue view <n>` 读取 Issue 描述和复现步骤
2. 如仅描述现象，先在对话中分析 / 探索定位可疑文件
3. 复杂定位可派发 `@roundtable:analyst` skill 协助调研（只在定位不清时；简单 bug 直接跳过）
4. **跳过 design 阶段**（bug fix 通常不需要新设计）

## 步骤 2：分析根因

- 阅读相关代码 + `git blame` 看历史
- 复杂 bug 把分析过程落盘到对话（不创建新 design-doc）
- 如果发现 bug 是设计缺陷而非实现缺陷（需要改 design-doc / 新增 DEC），**中止 bugfix 流程**，改走 `/roundtable:workflow` 走架构流程

## 步骤 3：Fix + 回归测试

### Developer Form Selection (bugfix defaults)

Bugfix tasks are typically small (single bug hotfix, 1–2 files), so **the bugfix command biases toward `inline` form** — the opposite default from `/roundtable:workflow`. Selection rules, applied in priority order:

1. **Explicit user declaration** (per-session): if the bug description contains `@roundtable:developer inline` or `@roundtable:developer subagent`, honor it.
2. **Target CLAUDE.md preference**: if `target_project` CLAUDE.md `# 多角色工作流配置` declares `developer_form_default: subagent`, respect the project's declaration (overrides the bugfix inline-bias default).
3. **Task-shape heuristic → AskUserQuestion**: if neither 1 nor 2 decides, invoke `AskUserQuestion` with options carrying `rationale` + `tradeoff` + `recommended` per the architect Option Schema:
   - Clearly small bug (single file + simple logic, narrow blast radius) → `inline` = **recommended** (main session sees every step, AskUserQuestion available, zero subagent boundary)
   - Bug spans multiple modules OR requires a broad refactor to fix cleanly → `subagent` = **recommended** (context isolation, avoids polluting main session with large reads, progress relayed via Monitor)
   - If the bug is clearly of one shape, present both options but only mark one as `recommended`.

The 3-tier switching mechanism (user declaration > CLAUDE.md > AskUserQuestion) is identical to `/roundtable:workflow` §Developer Form Selection; see that section and `docs/design-docs/subagent-progress-and-execution-model.md` §3.4 for the complete rules. Only the **default bias** differs between the two commands.

**Form → dispatch path**:
- `inline`: the orchestrator reads `agents/developer.md` and executes its prompt in the main session (same mechanism as architect / analyst inline execution). `AskUserQuestion` is directly available. No progress emit. Skip the Monitor setup above for this branch.
- `subagent`: dispatch via `Task` tool with the full progress injection per Step 0.5 (`progress_path` / `dispatch_id` / `slug` / `role`).

### Dispatch contract

派发 `@roundtable:developer` 实施修复（inline 或 subagent 形态，按上述规则选），派发 prompt 里注入：
- target_project / docs_root / lint_cmd / test_cmd
- bug 描述 / 根因分析
- subagent 形态：额外注入 `progress_path` / `dispatch_id` / `slug` / `role`（per Step 0.5）
- 明确要求：**必须补充回归测试**，确保同类 bug 不再出现
- 明确要求：Fix 不附带无关重构

## 步骤 4：验证

developer 完成后：
- 运行 `lint_cmd` 和 `test_cmd`，确保无回归
- 手动验证修复效果（如 bug 有明确复现步骤，让用户确认）

## 步骤 5：关键模块审查（按需）

- 若涉及 target_project CLAUDE.md 的 `critical_modules` 中任一关键词，派发 `@roundtable:reviewer` agent 审查
- 若涉及数据库 schema / migration / SQL 变更，派发 `@roundtable:dba` agent 审查
- Bug fix **默认不触发** tester（developer 已补回归测试）
- 仅当 bug 暴露出"边界条件未覆盖"类问题且涉及关键模块时，才补充调用 tester 加强对抗性测试

每次派发 reviewer / dba / tester subagent 前，按 Step 0.5 的模板重新生成 `dispatch_id` + `progress_path` 并启 Monitor；progress 变量注入到各自 Task prompt 里。

---

## 报告格式

修复完成后，向用户输出：

```markdown
## Bug 描述
[问题现象]

## 根因分析
[为什么出现]

## 修复方案
[改了什么文件 / 函数]

## 回归测试
[新增的测试文件 / 用例]

## 验证结果
[lint / test 通过情况；手动验证结果]

## 审查结论（如派发了 reviewer / dba）
[审查意见摘要]
```

---

## 执行规则

1. **跳过 design**：bug fix 不走 architect
2. **必有回归测试**：developer 必须补回归测试，不能"只改代码不加测试"
3. **不扩大范围**：Bug fix 只修该 bug，相关但无关的问题单独另开 issue / PR
4. **发现设计缺陷及时中止**：如果 bug 实际是设计错误，改走 `/roundtable:workflow` 流程重新设计
