# CLAUDE.md

roundtable plugin：analyst / architect / developer / tester / reviewer / dba / research 七角色多角色 AI 开发工作流 Claude Code plugin。

## 通用规则

- **语言**：代码英文、注释中文、文档中文、回答中文
- **Plugin prompt 文件本体**（`skills/*.md` / `agents/*.md` / `commands/*.md`）**英文**，见 `feedback_roundtable_prompt_language`
- **用户产出文档**（`docs/design-docs/` / `docs/decision-log.md` / `docs/log.md`）保持**中文**
- **GitHub Issue / PR 标题**：英文；body / 评论可中英混合
- **架构决策需确认**：影响 DEC-001（D1-D9）的改动必须走 DEC-xxx Superseded 流程，不删旧条目

## 设计参考

roundtable 自身设计可横向参考以下仓库，遇到跨角色编排 / skill 拆分 / progress 事件等取舍时先看他们怎么做：

- **superpowers** — https://github.com/obra/superpowers
- **gstack** — https://github.com/garrytan/gstack

## 多角色工作流配置

> 本 section 由 roundtable plugin 自读。roundtable 自身开发走 roundtable 工作流（递归 dogfood）。

### critical_modules（tester / reviewer 必触发）

| 模块 | 影响面 |
|------|--------|
| skill / agent / command prompt 本体（含 `_detect-project-context.md` / `_progress-content-policy.md`） | bug 传播到所有下游 `/roundtable:workflow` |
| Resource Access matrix | 权限错漏 → 并行派发 race 或越权 |
| Escalation Protocol JSON schema | 格式错 → orchestrator 无法解析 subagent 决策 relay |
| `_detect-project-context` 4 步检测 | 错 → 全链路 target_project 识别失败 |
| AskUserQuestion Option Schema | schema 偏差 → 选项失去 rationale/tradeoff/recommended |
| workflow Phase Matrix + Step 4 Task 并行判定 + Step 4b 决策并行（DEC-016）+ phase gating（DEC-006） | 编排状态 / 并行安全 / phase transition 核心 |
| Progress event JSON schema（DEC-004） | 所有 subagent emit 依赖；偏差 → Monitor/jq 解析失败 |
| Developer execution-form switching（DEC-005） | 切换规则错位 → inline/subagent 选择错位 |

### 工具链

- **primary_lang**：markdown（YAML frontmatter）
- **lint_cmd**：`grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/`（target-project 名 / 外部路径硬编码，应 0 命中；DEC-00X 引用本就合法，不扫）
- **test_cmd**：dogfood —— `/roundtable:workflow` 在 target 项目跑一轮 E2E（样例见 `docs/testing/p4-self-consumption.md`）
- **build_cmd / dev_cmd**：N/A ∕ `claude --plugin-dir <本地 roundtable 仓库绝对路径>`

### 条件触发规则

| 改动 | 强制动作 |
|------|---------|
| 修 skill/agent/command prompt 本体 | 跑 lint_cmd，0 命中才合并 |
| 新增/改 DEC | 评估与 Accepted DEC 冲突，走 Superseded |
| 改任一 agent Resource Access | review 其它 3 个 agent 对应列保持一致 |
| 新增 agent/skill | 完整加 `## Resource Access` + `## Escalation Protocol`（agent）或 `## AskUserQuestion Option Schema`（skill）|
| 跨阶段约束变动 | 同步更新 `docs/exec-plans/active/roundtable-plan.md` §跨阶段约束 |
| 改 `_detect-project-context.md` | review 5 个调用方（`commands/workflow.md`∕`bugfix.md`∕`lint.md`、`skills/architect.md`∕`analyst.md`）|
| 新增/改 Phase Matrix stages | 同步更新 `commands/workflow.md` §Step 3 artifact chain 与 `docs/INDEX.md` 6 类 orphan 扫描 |
| 新增用户产出文档类别 | 同步更新 Step 7 Index Maintenance "identify category" 列表 |
| `gh issue create` | 必加 `P0/P1/P2/P3` 标签（P0 阻塞/数据损坏；P1 主干/UX；P2 质量/缺口；P3 优化）|
| 评估 issue 顺序 | 先 priority（P0→P3），同级再看依赖 / dogfood 串联 |
| 改 skill/agent/command prompt 本体（行内 DEC/issue 引用纪律；#22）| 禁新增"仅 maintainer 可溯源"类括注：`（DEC-xxx）` 标签 / `（DEC-xxx §y.z）` 行内 / `issue #nn` 行内。白名单：跨文档 `详见 docs/xxx` 跳转、`file:line` 源码位置、Accepted DEC 原文段落。新 DEC 落 prompt 时全文只留 1 处锚点 ref，其余靠上下文自释；扩既有规则禁旧句反复加括注。回归监控 `grep -cE "DEC-[0-9]+\|§[0-9]" <file>` per-file baseline，单文件回升 >20% 或 `skills/+agents/+commands/` 合计 ≥ #22 旧快照（28）→ 开 follow-up audit issue 走 #22 方法论 |
