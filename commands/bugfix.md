---
description: Bug fix workflow. Skips design phase and routes directly through developer → (optional tester/reviewer/dba) with mandatory regression test.
argument-hint: <bug 描述 或 issue 编号>
---

# Bug Fix 工作流

**Bug 描述 / Issue**：$ARGUMENTS

## 执行前提

项目已按 roundtable 约定组织 docs。未配置时先提醒用户按 `docs/claude-md-template.md` 补齐 target CLAUDE.md 的「# 多角色工作流配置」section。

## Step 0: Project Context Detection

**inline 执行 4 步检测**：`Read` `${CLAUDE_PLUGIN_ROOT}/skills/_detect-project-context.md` 并按 4 步执行（D9 → toolchain → docs_root → CLAUDE.md 加载）。**不用 `Skill` 工具**。

后续派发 developer / tester / reviewer / dba 时注入：`target_project` / `docs_root` / `lint_cmd` / `test_cmd` / `critical_modules` / `slug` / `primary_lang`。

## Step 0.5: Progress Monitor Setup

复用 `/roundtable:workflow` §3.5 机制。

**Dispatch mode selection（DEC-012）**：派发前按 `commands/workflow.md` §Step 3.4 评估 `run_in_background`。Bugfix 通常单派发 → D2 命中 fg；reviewer / dba / tester 兜底派发同规则。

**Gate（DEC-008）+ env opt-out**：仅 `run_in_background: true` 且 `ROUNDTABLE_PROGRESS_DISABLE` 未设为 `1` 的派发触发本 Step。前台派发 / env opt-out / developer inline（见 Step 3）均 skip Monitor setup 并不注入 4 progress 变量；subagent 按其 `## Progress Reporting` fallback 静默降级。并行批每个 `Task` 独立评估。

**执行**：Gate 通过且未 opt-out → 按 `commands/workflow.md` §3.5.1–3.5.4 执行 Bash 准备 / Monitor 启动 / 4 变量注入 / Lifecycle。

**Bugfix 差异**：默认 fan-out 窄（通常 1 个 developer + 可选 reviewer / dba / tester），每个后台派发独立跑一次。Developer inline 分支整体 skip 本 Step。

## 步骤 1：定位问题

1. 有 GitHub Issue 编号 → `gh issue view <n>` 读 Issue
2. 仅现象描述 → 在对话分析 / 探索定位可疑文件
3. 复杂定位可派 `@roundtable:analyst`（简单 bug 直接跳过）
4. **跳过 design 阶段**

## 步骤 2：分析根因

- 读相关代码 + `git blame`
- 复杂 bug 分析过程落盘到对话（不创建新 design-doc）
- 若发现 bug 是**设计缺陷而非实现缺陷**（需改 design-doc / 新增 DEC）→ **中止 bugfix 流程**改走 `/roundtable:workflow`

## 步骤 3：Fix + 回归测试

### Developer Form Selection（bugfix 偏向 inline）

Bugfix 任务通常很小（单 bug hotfix / 1-2 文件），本 command **偏向 `inline`**（与 workflow 相反）。按优先级：

1. **用户显式声明**：`@roundtable:developer inline` 或 `@roundtable:developer subagent` → 直接遵从
2. **Target CLAUDE.md**：`developer_form_default: inline | subagent` 任一声明均遵从（对称处理是 DEC-009 决定 9 对 DEC-005 §3.4.2 per-project 三级切换的 follow-through 修正）
3. **AskUserQuestion**：前两条都不决定时，按 architect Option Schema 调用：
   - 小 bug（单文件 + 简单逻辑）→ `inline` = recommended
   - 跨多模块 / 需大范围重构 → `subagent` = recommended

三级切换机制（用户 > CLAUDE.md > AskUserQuestion）与 workflow §Step 6b 一致；差异仅在**默认偏向**。

**Form → 派发路径**：
- `inline`：orchestrator `Read` `agents/developer.md` 在主会话执行；`AskUserQuestion` 直接可用；skip Step 0.5 Monitor setup
- `subagent`：`Task` 派发，按 Step 0.5 完整注入 progress

### 派发契约

派发 `@roundtable:developer` 时注入：
- `target_project` / `docs_root` / `lint_cmd` / `test_cmd`
- bug 描述 / 根因分析
- subagent 形态：额外注入 `progress_path` / `dispatch_id` / `slug` / `role`
- 明确要求：**必须补回归测试**；Fix 不附带无关重构

## 步骤 4：验证

developer 完成后跑 `lint_cmd` + `test_cmd` 无回归；bug 有明确复现步骤时让用户确认。

## 步骤 5：关键模块审查（按需）

- 涉 `critical_modules` 任一关键词 → 派 `@roundtable:reviewer`
- 涉 DB schema / migration / SQL → 派 `@roundtable:dba`
- Bug fix **默认不触发** tester（developer 已补回归）；仅当 bug 暴露"边界未覆盖"且涉关键模块时才补 tester

每次派发 reviewer / dba / tester subagent 前按 Step 0.5 模板重生成 `dispatch_id` + `progress_path` + Monitor。

## 报告格式

```markdown
## Bug 描述
## 根因分析
## 修复方案（改了什么文件 / 函数）
## 回归测试（新增测试文件 / 用例）
## 验证结果（lint / test / 手动验证）
## 审查结论（如派了 reviewer / dba）
```

## 执行规则

1. **跳过 design**
2. **必有回归测试**
3. **不扩大范围** —— Bug fix 只修该 bug，相关但无关的另开 issue / PR
4. **发现设计缺陷及时中止** 改走 `/roundtable:workflow`

## log.md Batching（同 workflow §Step 8）

agent / reviewer / dba **不直接写 `{docs_root}/log.md`** —— 在 final message `log_entries:` YAML 上报，orchestrator 聚合写入。完整协议（flush 步骤 / YAML 契约 / 合并规则）见 `commands/workflow.md` §Step 8。

**Bugfix flush 点简化**（只有 developer → 可选 reviewer / dba / tester 两阶段）：
- reviewer / dba / tester 完成后（C 终点，无后续）一次 flush
- 用户 commit / 结束 bugfix 前（等价 Stage 9 Closeout 终点）一次 flush

**Bugfix abort 退化窗口声明**：bugfix 无 A 类 producer-pause → 无 pause-point flush 机会；用户在 developer 完成到后续派发之间**直接退出 Claude Code** → 所有未落盘 log_entries 丢失。窗口略宽于 workflow（workflow 有 3 个 A 类边界可清 queue）。
