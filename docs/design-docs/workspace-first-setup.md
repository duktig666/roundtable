---
slug: workspace-first-setup
created: 2026-06-03
status: draft
source: analyze/mattpocock-skills-patterns.md
---

# Workspace-First Setup — 系统设计

## Background & Goals

Roundtable 当前 `v0.0.7-rc3` 通过 `SessionStart` hook 轻量检测 `docs_root` 和 `project_id`。当用户从具体项目根目录启动时，这个路径工作正常；当用户从一个非 git workspace 根目录启动，并同时管理多个子项目时，hook 无法安全地自动选择目标项目。

当前 `/home/ubuntu/rsw/pm` 就是这种形态：

- workspace 根目录不是 git 仓库，但有跨项目 `CLAUDE.md` / `AGENTS.md`
- 子目录 `pm-cup2026/`、`pm-cup2026-liquidity/`、`pm-sdk-go/`、`roundtable/` 才是具体 git 项目
- 子项目各自有自己的 `docs/`、`CLAUDE.md` 或项目规则
- 用户习惯从 workspace 根目录启动 agent，并在一次会话里处理多个项目

目标：

1. 支持从 workspace 根目录启动 Roundtable，并可靠路由到目标子项目。
2. 保持 `SessionStart` hook 轻量，只探测事实，不替用户猜项目。
3. 把 load-bearing 配置显式写入 workspace / project 配置，减少隐式推断。
4. 保持 Roundtable 当前 Phase Matrix 和 artifact 目录结构，不重新引入过重机制。
5. 先解决多项目路由，不急于引入 issue tracker、CONTEXT.md、ADR 等扩展能力。

## Solution

采用 **workspace-first + project-level setup**。

核心思路：

- workspace 层负责“当前任务属于哪个子项目”
- project 层负责“这个子项目的 docs_root、lint/test、critical_modules 等规则”
- hook 只输出当前 cwd 的探测结果和候选项目，不做最终选择
- `workflow` / `bugfix` / `lint` 在启动时完成项目路由，然后进入现有流程

### 1. Workspace Registry

在 workspace 根目录增加：

```text
.roundtable/workspace.toml
```

示例：

```toml
[workspace]
root = "/home/ubuntu/rsw/pm"
default_docs_policy = "project-docs"

[[projects]]
id = "pm-cup2026"
path = "pm-cup2026"
docs_root = "pm-cup2026/docs"
aliases = ["cup", "main"]

[[projects]]
id = "pm-cup2026-liquidity"
path = "pm-cup2026-liquidity"
docs_root = "pm-cup2026-liquidity/docs"
aliases = ["liquidity", "mm", "做市"]

[[projects]]
id = "pm-sdk-go"
path = "pm-sdk-go"
docs_root = "pm-sdk-go/docs"
aliases = ["sdk"]

[[projects]]
id = "roundtable"
path = "roundtable"
docs_root = "roundtable/docs"
aliases = ["rt"]
```

字段含义：

- `id`：稳定项目名，用于 prompt、日志、路由
- `path`：相对 workspace root 的项目路径
- `docs_root`：相对 workspace root 的 Roundtable artifact 写入路径
- `aliases`：用户自然语言任务里的项目别名

### 2. Project Config

每个子项目可以选择增加：

```text
<project>/.roundtable/project.toml
```

MVP 阶段只定义少数字段：

```toml
[project]
id = "pm-cup2026-liquidity"
docs_root = "docs"
default_branch = "dev"

[toolchain]
lint_cmd = "go test ./..."
test_cmd = "go test ./..."

[rules]
critical_modules = ["services/liquidity-service", "internal/risk", "migrations"]
```

读取优先级：

1. `<project>/.roundtable/project.toml`
2. 子项目 `CLAUDE.md` / `AGENTS.md`
3. 自动检测
4. 用户确认

MVP 可以先不实现全部字段，只把 schema 和读取顺序确定下来。

### 3. `/roundtable:setup`

新增 setup skill，分两个入口：

```text
/roundtable:setup workspace
/roundtable:setup project <project-id>
```

#### workspace setup

流程：

1. 扫描当前目录下一级/二级 git 项目。
2. 只保留存在 `docs/` 或 `documentation/` 的候选。
3. 展示项目列表、docs_root、是否有 `CLAUDE.md` / `AGENTS.md`。
4. 逐个询问用户确认项目 id 和 aliases。
5. 写 `.roundtable/workspace.toml`。

#### project setup

流程：

1. 读取目标项目 `CLAUDE.md` / `AGENTS.md`。
2. 确认 `docs_root`、默认分支、critical_modules、lint/test 命令。
3. 写 `<project>/.roundtable/project.toml`。

setup 不自动改业务代码，不创建 issue，不迁移历史 docs。

### 4. SessionStart Hook

hook 保持轻量。

当 cwd 位于具体项目内时：

```text
Roundtable context:
workspace_root: /home/ubuntu/rsw/pm
project_id: pm-cup2026-liquidity
project_root: /home/ubuntu/rsw/pm/pm-cup2026-liquidity
docs_root: /home/ubuntu/rsw/pm/pm-cup2026-liquidity/docs
status: ok
```

当 cwd 位于 workspace 根目录时：

```text
Roundtable context:
workspace_root: /home/ubuntu/rsw/pm
project_id: <none>
docs_root: <none>
status: needs-project
candidates:
- pm-cup2026
- pm-cup2026-liquidity
- pm-sdk-go
- roundtable
```

hook 不根据候选列表自动选项目。多个候选时，选择权交给 `workflow` / `bugfix` / `lint`。

### 5. Workflow Routing

`workflow` / `bugfix` / `lint` 启动顺序改为：

1. 读取 `Roundtable context`。
2. 如果 `status: ok`，直接使用 `project_root` 和 `docs_root`。
3. 如果 `status: needs-project`：
   - 读取 `.roundtable/workspace.toml`
   - 用 `$ARGUMENTS` 匹配 `id`、`path`、`aliases`
   - 精确唯一命中则使用
   - 多命中或无命中则询问用户
4. 选定项目后，后续所有 phase 都带上：
   - `project_id`
   - `project_root`
   - `docs_root`
5. 所有 artifact 写入目标项目的 `docs/`，不写 workspace 根目录。

示例：

用户在 `/home/ubuntu/rsw/pm` 输入：

```text
跑 liquidity 的库存风险控制 workflow
```

Roundtable 应路由到：

```text
project_id: pm-cup2026-liquidity
project_root: /home/ubuntu/rsw/pm/pm-cup2026-liquidity
docs_root: /home/ubuntu/rsw/pm/pm-cup2026-liquidity/docs
```

artifact 写入：

```text
pm-cup2026-liquidity/docs/analyze/<slug>.md
pm-cup2026-liquidity/docs/design-docs/<slug>.md
pm-cup2026-liquidity/docs/exec-plans/active/<slug>.md
```

### 6. Worktree Handling

workspace registry 中的 `projects[].path` 指向 canonical 项目目录，不指向临时 worktree。

如果用户任务明确指向 `worktrees/<name>`，Roundtable 可以把该 worktree 视为当前 `project_root`，但应从其 git common dir 或路径名反推出所属 project id。MVP 阶段可以不做复杂反推，只在命中不明确时询问用户。

## Key Decisions

### DEC-0001 — 不让 hook 自动选择子项目

决策：hook 只探测 workspace 和候选项目，不从多个候选中自动选择。

原因：hook 没有完整任务语义，也不能可靠交互。自动选择会把 design-doc / exec-plan 写错项目，代价高于多问一次用户。

### DEC-0002 — workspace 配置与 project 配置分层

决策：workspace registry 只负责项目路由；project config 负责子项目规则。

原因：`/home/ubuntu/rsw/pm` 同时承载多个项目。把所有配置写在 workspace 根会造成项目规则混杂；只写在子项目又无法解决从 workspace 启动时的路由问题。

### DEC-0003 — MVP 先做路由，不引入 issue tracker / ADR / CONTEXT

决策：第一阶段只实现 workspace registry、setup workspace、workflow/bugfix/lint 路由。

原因：当前痛点是多项目路由和 `docs_root` 选择。issue tracker、CONTEXT.md、ADR 是后续质量增强，不是路由 MVP 的必要条件。

### DEC-0004 — artifact 仍写入子项目 docs

决策：即使从 workspace 根启动，Roundtable artifact 仍写入目标子项目 `docs/`。

原因：分析、设计、执行计划、测试和评审都属于具体项目。写到 workspace 根会降低可追溯性，也不符合现有 Roundtable docs 布局。

## Non-Goals

- 不把 Roundtable 改成完整 issue tracker / triage 系统。
- 不在 MVP 中引入 `CONTEXT.md` 或 `docs/adr/` 作为必需机制。
- 不迁移已有项目文档。
- 不让 setup 自动修改业务代码。
- 不让 hook 执行耗时递归扫描或复杂选择。

## Alternatives

### A. 只增强 hook 向下扫描

优点：改动少。

问题：hook 无法安全选择多个候选项目；最终仍需要 workflow 提问。扫描结果也不会形成持久配置。

### B. 只在子项目写 project config

优点：项目规则隔离清晰。

问题：从 workspace 根启动时，仍然缺少“任务属于哪个子项目”的路由层。

### C. workspace 根作为唯一项目

优点：实现简单。

问题：artifact 会混在 workspace 根目录，破坏子项目边界；不适合同时处理多个 repo。

## Risks

- workspace registry 可能过期：子项目改名或移动后，路由会失效。缓解方式：`/roundtable:setup workspace` 支持重新扫描并更新。
- aliases 可能冲突：例如 `pm-cup2026` 和 `pm-cup2026-liquidity`。缓解方式：精确 basename 优先，短名嵌入长名时视为 ambiguous。
- project config 与 `CLAUDE.md` 冲突：缓解方式：明确读取优先级，并在冲突时报告给用户。
- worktree 路由复杂：MVP 不做自动深度反推，命中不明确时询问用户。

## Review Questions

1. `.roundtable/workspace.toml` 是否是合适的 workspace registry 文件名和位置？
2. workspace setup 是否应该写根 `CLAUDE.md` 摘要，还是只写 `.roundtable/workspace.toml`？
3. project config 是否应该在 MVP 中实现，还是先只做 workspace registry？
4. hook 输出 `candidates` 是否足够，还是应该直接输出 workspace registry 的解析结果？
5. worktree 是否需要 MVP 支持自动识别所属 canonical project？
