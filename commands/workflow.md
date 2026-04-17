---
description: 多角色 AI 工作流编排命令。根据任务规模自动选择 analyst / architect / developer / tester / reviewer / dba 的协作路径。
argument-hint: <任务描述>
---

# 多角色工作流

你即将为以下任务编排多角色协作：

**任务**：$ARGUMENTS

---

## 执行前提

本命令要求项目已按 roundtable 约定组织 docs 目录（`design-docs/`、`exec-plans/active/`、`analyze/`、`testing/plans/`、`reviews/`、`decision-log.md`、`log.md`）。若目标项目目录结构不完整，在首次落盘时由 architect 创建缺失子目录并向用户说明。

---

## 步骤 0：目标项目识别

在分派任何角色之前，先激活 `architect` skill 的"开工第一步：项目上下文识别"来确定：
- `target_project`（通过 D9 机制 —— session 记忆 / git rev-parse / 子目录扫描 / AskUserQuestion）
- 工具链（读 Cargo.toml / package.json / pyproject.toml / go.mod / Move.toml）
- `docs_root`（`docs/` 或 `documentation/` 或 AskUserQuestion 建立）
- 加载 `target_project/CLAUDE.md` 的「# 多角色工作流配置」section

**后续所有角色派发都必须在 prompt 里注入这些已识别的上下文变量**，不要让每个角色各自重新识别。

---

## 步骤 1：判断任务规模

分三档，由当前 Claude（在读完任务描述 + target_project CLAUDE.md 后）决定：

| 规模 | 特征 | 推荐流程 |
|------|------|---------|
| **小改动** | bug fix / 简单修改 / UI 样式调整 / 文档修正 | 建议用户改用 `/roundtable:bugfix` 或直接 `@roundtable:developer` |
| **中等改动** | 新功能、模块修改、有一定业务逻辑 | analyst（可选）→ architect → 确认设计 → developer → **tester（关键模块必触发）** → reviewer（可选） |
| **大改动** | 新模块、架构变更、跨多组件 | analyst → architect → 确认设计 → developer → **tester** → reviewer |

涉及数据库 schema / migration 变更：额外调用 `@roundtable:dba` 审查。

**判定不清时**：用 AskUserQuestion 问用户"按中 / 大规模走？"

---

## 步骤 2：tester 触发条件

是否必须调用 tester，从 `target_project/CLAUDE.md` 的 `## critical_modules` section 读取关键模块清单。当前任务涉及的文件或业务域命中清单中任一项时，**必须**派发 tester。

**通用兜底规则**（若项目 CLAUDE.md 未声明 critical_modules）：
- 涉及金额 / 账户 / 权限判断的代码
- 性能敏感热路径（需要 benchmark 验证的）
- 并发 / 锁 / 事务边界
- 安全相关（签名验证 / 输入校验 / 权限检查）

**可选调用**：中大型功能的 E2E 场景规划、前端关键交互流程
**跳过**：Bug fix、UI 样式、文档更新、非关键工具类代码

---

## 步骤 3：成果传递约定

**使用统一的"主题 slug"**（kebab-case 英文）串联所有阶段：

```
analyst   → target_project/{docs_root}/analyze/[slug].md
architect → 读 analyze/[slug].md
            写 design-docs/[slug].md
            按需写 exec-plans/active/[slug]-plan.md
            按需写 api-docs/[slug].md
developer → 读 design-docs/[slug].md + exec-plans/active/[slug]-plan.md
            写代码 + 基础测试（单元 + TDD 验收）
            完成后将 exec-plan 移到 completed/
            不写 log.md（代码变更归 git log；仅在 exec-plan 归档时 append 一条 `exec-plan | [slug] completed`）
tester    → 读代码 + design-docs/[slug].md
            写对抗性测试 / E2E / benchmark（路径按项目实际，不硬编码）
            中大型功能输出测试计划到 testing/plans/[slug].md
reviewer  → 读代码 + design-docs/[slug].md
            默认对话输出，关键审查落盘到 reviews/[YYYY-MM-DD]-[slug].md
dba       → 读 migrations / schema / 代码
            默认对话输出，关键审查落盘到 reviews/[YYYY-MM-DD]-db-[slug].md
```

**主题 slug 规则**：
- 使用 kebab-case 英文
- 一个功能从头到尾使用同一个 slug
- 用户未指定时，由首个触发的角色命名并在输出中声明

---

## 步骤 4：执行规则

1. **阶段之间**：每个阶段完成后向用户汇报成果（简短 + 文件路径），**等用户确认再进入下一阶段**（用户的把关点，不自动推进）
2. **阶段之内**的决策点：遇到需要用户选择的决策，**立即用 `AskUserQuestion` 弹窗**让用户点选。不要攒到阶段末尾用文字列"N 项待确认"。典型场景：
   - analyst 在研究中遇到范围 / 优先级分歧
   - architect 在探索中识别出架构决策点
3. **plan-then-execute 模式**（强制）：
   - **architect**：三阶段工作流（探索 → 落盘 design-docs → 按需 exec-plan），见 `skills/architect.md`
   - **developer**：中大型任务先输出实现计划等用户确认，再写代码（小任务可跳过）
   - **tester**：中大型任务先输出测试计划等用户确认，再写测试（小任务可跳过）
4. **角色形态**：
   - `architect` / `analyst` 是 **skill**（在主会话上下文运行，AskUserQuestion 可用）—— 用 Skill 工具激活
   - `developer` / `tester` / `reviewer` / `dba` 是 **agent**（subagent 隔离上下文）—— 用 Task 工具派发，派发时在 prompt 里显式注入 target_project / docs_root / lint_cmd / test_cmd / critical_modules 等上下文变量
5. **developer 完成后**：必须跑目标项目的 lint 和 test（使用步骤 0 识别出的命令）；失败则反馈用户处理
6. **tester 发现业务 bug 时**：反馈给用户由 developer 修复，tester 不自行修业务代码

---

## 当前任务开始

1. 按"步骤 0"识别 `target_project` 和上下文
2. 按"步骤 1"判断任务规模
3. 按相应流程激活/派发第一个角色（通常是 analyst skill 或 architect skill）
4. 严格遵守"阶段之间用户确认 + 阶段之内立即 AskUserQuestion"的纪律

**注意**：本命令只做编排，不自己做设计 / 编码。把具体工作交给对应角色。
