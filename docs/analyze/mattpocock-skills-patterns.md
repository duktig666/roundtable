---
slug: mattpocock-skills-patterns
created: 2026-06-02
---

# Matt Pocock Skills 模式分析

## 背景与目标

用户希望 clone 并详细分析 `https://github.com/mattpocock/skills`，用于后续完善 Roundtable。

仓库已 clone 到 `/home/ubuntu/rsw/pm/mattpocock-skills`，当前提交为 `aaf2453`。本报告对比该仓库的可观察模式与 Roundtable `v0.0.7-rc3`，Roundtable 当前提交为 `a91f3a4`。

本报告只做事实和模式分析，不直接做架构选择。与 Roundtable 后续改造相关的决策点列在「开放问题」中，适合作为下一步设计输入。

## 发现

### 仓库形态

`mattpocock/skills` 是一个 skill 库，不是一个固定流程编排器。它的 plugin manifest 只发布 `skills/engineering` 和 `skills/productivity` 下的技能；`misc`、`personal`、`in-progress`、`deprecated` 被明确排除在发布面之外。项目 `CLAUDE.md` 要求每个正式发布的 skill 同时出现在顶层 README 和 `.claude-plugin/plugin.json` 中。

Roundtable 是一个 workflow plugin，公开面更小：`workflow`、`bugfix`、`lint`、`analyst`、`architect`，以及四个角色 agent。README 把 Roundtable 描述为一个带固定 Phase Matrix 的流程编排层。

### setup-first 配置

`setup-matt-pocock-skills` 是一个显式的一次性 setup skill。它会先探索当前 repo，展示发现，再逐个询问用户决策，最后写入：

- 现有 `CLAUDE.md` 或 `AGENTS.md` 中的 `## Agent skills` 配置块
- `docs/agents/issue-tracker.md`
- `docs/agents/triage-labels.md`
- `docs/agents/domain.md`

这个 setup skill 把 issue tracker、triage label、domain docs layout 都当作项目拥有的持久配置。它不依赖启动 hook 去推断这些值。

Roundtable 当前依靠 `SessionStart` 推断 `docs_root` 和 `project_id`；当 hook 上下文缺失或为 `needs-init` 时，`workflow`、`bugfix`、`lint` 再做 fallback。Roundtable 目前没有一个会写入持久项目配置的 setup skill。

### hard dependency 与 soft dependency

`0001-explicit-setup-pointer-only-for-hard-dependencies.md` 这份 ADR 把 skills 分成两类：

- hard dependency：`to-issues`、`to-prd`、`triage`。如果缺少 issue tracker 或 label 映射，输出会是错误的。
- soft dependency：`diagnose`、`tdd`、`improve-codebase-architecture`、`zoom-out`。缺少 domain docs 会降低输出质量，但 skill 仍然可以运行。

Roundtable 实际上也有类似依赖分层，但当前 prompt 里没有明确命名。`docs_root` 对 artifact 写入是硬依赖；`critical_modules`、`lint_cmd`、`test_cmd`、项目语言约定则更像软依赖，可以自动检测或降级。

### 域语言与 ADR 记忆

`grill-with-docs` 会在用户访谈过程中创建或更新 `CONTEXT.md`。它把 `CONTEXT.md` 严格限定为 glossary，不允许写实现细节。只有当一个决策同时满足三个条件时才建议写 ADR：难以回滚、没有上下文会令人意外、确实存在 trade-off。ADR 也保持很短，放在 `docs/adr/` 下。

Roundtable 当前把任务相关 artifact 放在 `docs/analyze`、`docs/design-docs`、`docs/exec-plans`、`docs/testing`、`docs/reviews`、`docs/bugfixes` 中。它没有把 domain glossary 或 ADR 目录作为一等概念。Roundtable 的 design-doc 会记录单个任务的决策，但没有一个要求后续任务读取的长期决策记忆层。

### grilling loop 与 phase gate

Matt Pocock 的 `grill-with-docs` 一次只问一个问题；如果问题能通过读代码回答，就先读代码而不是问用户；当决策逐步清晰时，会立即更新文档。它的交互重点是消除模糊语言和决策分支。

Roundtable 的 architect skill 也会逐个询问架构决策点，并要求用户确认 design-doc 和 exec-plan。区别是 Roundtable 的交互是 phase-oriented：analyst 产事实，architect 产设计，用户确认，生成 exec-plan，再确认，然后 developer、tester、reviewer、dba 接力。

### 反馈环诊断纪律

`diagnose` 把快速、确定性的 pass/fail 信号视为调试核心资产。它要求先构建反馈环，再复现、提出 ranked hypotheses、一次只 instrument 一个变量、修复、补回归测试、清理 debug instrumentation。

Roundtable 的 `bugfix` skill 要求回归测试，并有 Tier 0/1/2 分层。但它目前没有完整写出诊断循环，例如反馈环构建、可证伪假设排序、带唯一前缀的 debug instrumentation、清理检查等。

### TDD 纪律

`tdd` 强烈反对 horizontal slicing：不是先写一堆测试再写一堆实现，而是一个行为测试、一段最小实现、循环推进。它强调只测 public interface、只测行为、green 后再 refactor。

Roundtable 的 developer 指令要求写测试，也说明非平凡行为要先写失败测试。但当前 workflow prompt 没有像 `tdd` 一样明确要求 one-test-at-a-time 的 vertical cycle，也没有把 public-interface-only tests 写成强约束。

### 工作切片与 durable agent brief

`to-issues` 会把计划拆成 independently grabbable 的 vertical slices，标记 HITL 或 AFK，检查依赖顺序，并把 issue body 写成耐久说明而不是文件路径清单。`triage` 使用 `Agent Brief` 模板，避免文件路径和行号，强调 key interfaces、acceptance criteria 和 out-of-scope。

Roundtable 的 exec-plan 是本地文档，包含明确步骤、checkbox 和验证项。它通过 slug 串联同一任务的文档，也可能提到具体文件。Roundtable 目前没有定义 AFK-ready brief contract，因为它是 orchestrator 直接派发 subagent，而不是先发布到外部 issue tracker。

### 独立的架构改进 skill

`improve-codebase-architecture` 与 feature workflow 独立。它会读取 domain language 和 ADR，探索架构摩擦，把 HTML 报告写到临时目录，询问用户想深入哪个候选项，然后才进入 grilling loop。它有专门的架构词汇：Module、Interface、Implementation、Depth、Seam、Adapter、Leverage、Locality。

Roundtable 有 analyst 和 architect 角色，但没有专门的 architecture review / deepening skill。Reviewer 主要审查 diff，architect 主要产任务级 design-doc。

### Prompt 组织方式

Matt Pocock 的多个 skill 使用 progressive disclosure：主 `SKILL.md` 保持短小，详细格式和例子放到同目录文件，例如 `CONTEXT-FORMAT.md`、`ADR-FORMAT.md`、`tests.md`、`mocking.md`、`HTML-REPORT.md`、`AGENT-BRIEF.md`。

Roundtable 已经用 `references/codex-tools.md` 存放 runtime-specific tool mapping。除此之外，大多数 workflow 指令仍集中在 `SKILL.md` 和 agent prompt 文件中。

### 失败模式

把 Matt Pocock 模式搬进 Roundtable 的主要失败模式是机制膨胀。Roundtable 当前的价值主张是小型流程编排层和有限文档机制。如果不加范围控制就加入 setup、domain docs、ADR、issue tracker mapping、triage、architecture report，可能会重新形成 Roundtable 在 `v0.0.5` 前刻意删除的机制负担。

相反的失败模式是 Roundtable 继续过度依赖 hook 来承载关键配置。`docs_root` 已经暴露了这个问题：当 runtime 没有把 hook context 传给模型，或者用户从父目录启动时，workflow 启动就需要 fallback。未来如果加入 issue tracker、domain docs、critical modules、toolchain overrides，也可能遇到类似问题。

### 6 个月复盘视角

六个月后最可能仍然有价值的 Matt Pocock 模式包括：hard/soft dependency 分层、对 load-bearing 配置使用显式 setup、用 domain vocabulary 作为简洁项目记忆、以及诊断反馈环纪律。这些模式概念较小，也容易跨 runtime 复用。

六个月后最可能变成 Roundtable 技术债的模式包括：完整外部 issue tracker 编排、triage 状态机、富 HTML 架构报告。这些在原 repo 中有价值，是因为它是 composable skill collection；但在 Roundtable 中，如果没有作为可选能力隔离，可能会和现有 Phase Matrix 竞争。

## 对比

| 维度 | Matt Pocock Skills | Roundtable v0.0.7-rc3 |
|---|---|---|
| 主要形态 | 可组合 skill 库 | 固定多角色 workflow plugin |
| 启动配置 | 显式 `/setup-matt-pocock-skills` 写项目文档 | `SessionStart` 检测 `docs_root`，skill 缺失时 fallback |
| 持久记忆 | `CONTEXT.md`、`docs/adr/`、`docs/agents/*` | 任务 artifact：`docs/{analyze,design-docs,exec-plans,testing,reviews,bugfixes}` |
| 决策方式 | grilling loop，文档 inline 更新 | architect gate，design-doc 再 exec-plan |
| Bug 流程 | 以反馈信号为中心的 diagnose loop | bugfix tier + 必须回归测试 |
| 测试流程 | vertical red-green-refactor | developer/tester prompt，vertical loop 不够显式 |
| 工作发布 | issue tracker + durable agent brief | 本地 exec-plan + 直接 subagent dispatch |
| 架构审查 | 独立 architecture-deepening skill + 可视报告 | 任务级 analyst / architect / reviewer |
| Prompt 结构 | 多个小 skill + reference files | 小 public surface + role prompts + runtime references |

## 开放问题

1. Roundtable 是否应该新增 `/roundtable:setup` skill，用于 load-bearing project configuration？还是继续只使用 `SessionStart` + fallback？
2. 如果有 setup，哪些字段属于 hard dependency？候选包括：`docs_root`、issue tracker、critical modules、lint/test command overrides、domain-doc layout。
3. Roundtable 是否应该把 `CONTEXT.md` / `docs/adr/` 引入为一等项目记忆？还是继续把所有 durable decisions 放在任务级 design-doc 中？
4. `bugfix` 是否应该吸收 `diagnose` 的严格诊断循环？还是保持 fast path，把深度 debugging 做成独立 skill？
5. developer/tester prompt 是否应该加入显式 vertical TDD loop，包括 public-interface-only tests 和 one red-green cycle at a time？
6. Roundtable 是否应该新增独立 architecture-review skill？还是这会和 analyst + architect + reviewer 重叠？
7. 即使 Roundtable 不发布外部 issue，是否也应该为 subagent dispatch 定义 AFK-ready brief 格式？
8. Roundtable 应该采纳多少 progressive disclosure？如果拆太多 reference 文件，维护成本是否会超过当前紧凑文件结构？
