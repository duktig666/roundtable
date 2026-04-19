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

## Step 0：Project Context Detection

**必须 inline 执行 4 步检测** —— `Read` `skills/_detect-project-context.md` 并直接按 4 步执行。不要用 `Skill` 工具去激活下划线前缀的 helper。

4 步：D9 target-project 识别 → toolchain detection → `docs_root` detection → 加载 `CLAUDE.md` 的「# 多角色工作流配置」section。

后续派发 `developer` / `tester` / `reviewer` / `dba` agent 时，把检测结果（`target_project` / `docs_root` / `lint_cmd` / `test_cmd` / `critical_modules` / `slug` / `primary_lang`）注入派发 prompt。

---

## Step 0.5：Progress Monitor Setup

**完整模板见 `commands/workflow.md` §Progress Monitor Setup。** bugfix 命令复用同一套机制，差异如下：

0. **前台 / 后台派发 gate（DEC-008）**：在执行下方任何步骤前，先检查即将发起的 `Task` 调用的 `run_in_background` 参数。**只有 `run_in_background: true` 的派发触发本 Step**。前台 `Task` 派发（`run_in_background` 缺省或 `false`，Claude Code 当前默认）完全 skip Monitor 准备 —— 具体而言，对每个前台调用：(a) 不生成 `DISPATCH_ID` / `PROGRESS_PATH`，(b) 不跑 `mkdir -p` / `touch`，(c) 不启动 Monitor，(d) 不向 Task prompt 注入 4 个 progress 变量（`progress_path` / `dispatch_id` / `slug` / `role`）。主会话本就把 subagent 工具调用以缩进形式看在眼里，Monitor 只会是重复信号。Subagent 收到空 `progress_path` 时按各自 `## Progress Reporting` fallback 静默降级。并行批里每个 `Task` 调用独立评估。与 `commands/workflow.md` §3.5.0 语义完全一致。
1. **默认 fan-out 更窄**：bugfix 通常只派发一个 developer subagent（外加可选的 reviewer / dba / tester）。按派发维度跑 Monitor setup —— 每个后台 subagent 一个 `dispatch_id` + 一个 `progress_path`。
2. **Opt-out env**：`ROUNDTABLE_PROGRESS_DISABLE=1` 抑制 Monitor 启动 + progress 注入，与 workflow 语义一致。
3. **Per-dispatch Bash（每次 `Task` 调用前运行）** —— 与 workflow 模板一致：
   - 生成 `DISPATCH_ID=$(openssl rand -hex 4)`
   - 推导 `PROGRESS_PATH=/tmp/roundtable-progress/${SESSION_ID}-${DISPATCH_ID}.jsonl`（`SESSION_ID=${CLAUDE_SESSION_ID:-$(date +%s)-$$}`）
   - `mkdir -p` + `touch` 文件
   - 启动 `Monitor`：`tail -F "$PROGRESS_PATH" 2>/dev/null | jq -R --unbuffered -c 'fromjson? | select(.event) | "[" + .phase + "] " + .role + " " + .event + " — " + .summary' | awk 'BEGIN{last="";n=0} {if($0==last){n++} else {if(n>1) print last" (x"n")"; else if(last!="") print last; last=$0; n=1} fflush()} END{if(n>1) print last" (x"n")"; else if(last!="") print last}'`（`-R` + `fromjson?` 让 pipe 对畸形行容错；没有它们时单个坏行就能杀掉 Monitor 并丢掉后续全部事件 —— 见 `commands/workflow.md` §3.5.3 Notes + `docs/testing/subagent-progress-and-execution-model.md` Case 1.2。尾部 `awk` 按 DEC-007 §3.4 只折叠**连续**相同行（不是全局 uniq），作为源端飘移的安全网。）
4. **注入 4 个变量**（`progress_path` / `dispatch_id` / `slug` / `role`）到 `developer` / `tester` / `reviewer` / `dba` Task prompt。subagent 的 `## Progress Reporting` section 消费这 4 个变量。
5. 把每条 Monitor notification 用 `[<phase>] <role> <event> — <summary>` 格式实时中继给用户（DEC-004）。

若用户未声明 `developer_form_default` 偏好且 bugfix 走 inline（见下方 Step 3 Developer Form Selection），**inline 分支下 skip Monitor setup** —— 主会话直接观察 developer，不产生 progress emit。

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

### Developer Form Selection（bugfix 默认）

Bugfix 任务通常很小（单个 bug hotfix，1–2 个文件），所以**本 command 偏向 `inline` 形态** —— 和 `/roundtable:workflow` 相反。按优先级应用的选择规则：

1. **用户显式声明**（per-session）：如果 bug 描述里含 `@roundtable:developer inline` 或 `@roundtable:developer subagent`，直接遵从。
2. **Target CLAUDE.md 偏好**：若 `target_project` CLAUDE.md 的「# 多角色工作流配置」里声明了 `developer_form_default: subagent`，尊重项目声明（覆盖 bugfix 默认偏向 inline 的倾向）。
3. **任务形态启发式 → AskUserQuestion**：若 1 和 2 都不决定，调 `AskUserQuestion`，按 architect 的 Option Schema 给出带 `rationale` + `tradeoff` + `recommended` 的选项：
   - 明显是小 bug（单文件 + 简单逻辑，影响面窄）→ `inline` = **recommended**（主会话能看到每一步、`AskUserQuestion` 可用、零 subagent 边界）
   - Bug 跨多个模块，或需要大范围重构才能干净修复 → `subagent` = **recommended**（context 隔离，避免大量 read 污染主会话，progress 经 Monitor 中继）
   - Bug 形态明确时，两个选项都出，但只标记一个为 `recommended`。

三级切换机制（用户声明 > CLAUDE.md > AskUserQuestion）与 `/roundtable:workflow` §Developer Form Selection 完全一致；完整规则见该 section 和 `docs/design-docs/subagent-progress-and-execution-model.md` §3.4。两个 command 的差异只在**默认偏向**。

**Form → 派发路径**：
- `inline`：orchestrator `Read` `agents/developer.md` 并在主会话中执行其 prompt（与 architect / analyst 的 inline 执行机制一致）。`AskUserQuestion` 直接可用。无 progress emit。本分支 skip 上面的 Monitor setup。
- `subagent`：用 `Task` 工具派发，按 Step 0.5 完整注入 progress（`progress_path` / `dispatch_id` / `slug` / `role`）。

### 派发契约

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
