# CLAUDE.md

roundtable plugin：多角色 AI 开发工作流 Claude Code plugin。将 analyst / architect / developer / tester / reviewer / dba 六角色打包为可安装组件，适配不同技术栈项目。

## 通用规则

- **语言**：代码英文、注释中文、文档中文、回答中文
- **Plugin prompt 文件本体**（`skills/*.md` / `agents/*.md` / `commands/*.md`）**以中文为主，关键专有名词保留英文**（工具名、字段名、DEC-xxx、env var、`Task` / `Monitor` / `AskUserQuestion` 等 Claude Code / plugin 术语不翻译）—— 约定 2026-04-19 更新，见 `feedback_roundtable_prompt_language`
- **用户产出文档**（`docs/design-docs/` / `docs/decision-log.md` / `docs/log.md`）保持**中文**
- **GitHub Issue / PR 标题**：英文；body / 评论可中英混合
- **架构决策需确认**：任何影响 DEC-001（D1-D9）的改动必须走 DEC-xxx Superseded 流程

---

# 多角色工作流配置

> 本 section 由 roundtable plugin 自读。roundtable 本身的开发也走 roundtable 工作流（递归 dogfood）。

## critical_modules（tester / reviewer 必触发）

- **Skill / agent / command prompt 文件本体（含 `skills/_detect-project-context.md` 与 `skills/_progress-content-policy.md` 共享 helper）**：任何 bug 会传播到所有下游 `/roundtable:workflow` 调用
- **Resource Access matrix**：权限声明错漏会在并行派发时 race 或角色越权
- **Escalation Protocol JSON schema**：格式改错导致 orchestrator 无法解析，subagent 决策 relay 失效
- **`_detect-project-context` 4 步检测逻辑**：错了整个 workflow 链路起不来，所有 target_project 识别失败
- **AskUserQuestion Option Schema**：schema 偏差让弹窗选项失去 rationale / tradeoff / recommended，用户难以决策
- **workflow command Phase Matrix + Step 4 Task 并行判定树 + Step 4b 决策并行判定树（DEC-016） + phase gating taxonomy (DEC-006)**：编排状态、Task 派发 / 决策批量化的并行安全性、phase transition 节奏（producer-pause / approval-gate / verification-chain）的核心
- **Progress event JSON schema (DEC-004)**：所有 subagent 的进度 emit 依赖此 schema；schema 偏差让 orchestrator Monitor / jq 解析失败、主会话失去实时感知
- **Developer execution-form switching rules (DEC-005)**：切换规则（per-session @声明 / per-project `developer_form_default` / per-dispatch AskUserQuestion）错位会导致 inline/subagent 选择错位，UX 与 context 风险同时受影响

## 工具链覆盖

> roundtable 本身是纯 prompt 包，无传统 build/test 链路。

- **primary_lang**: markdown（含 YAML frontmatter）
- **lint_cmd**: `grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/`（target-project 名 / 外部路径硬编码扫描，应 0 命中。**DEC-00X 引用本就合法**，不再扫 —— 过去误把 DEC-003/004/005 当"未完成 DEC 泄漏"是规则 bug）
- **test_cmd**: dogfood run —— `/roundtable:workflow` 在 target 项目跑一轮做 E2E 验证（见 `docs/testing/p4-self-consumption.md` 样例）
- **build_cmd**: N/A
- **dev_cmd**: `claude --plugin-dir /data/rsw/roundtable`（本地测试 plugin）

## 条件触发规则

- 修改 skill / agent / command prompt 本体 → 必须跑 lint_cmd 硬编码 grep 扫描，0 命中才可合并
- 新增或修改 DEC → 必须评估与已有 Accepted DEC 的冲突，走 Superseded 流程（不删旧条目）
- 修改任一 agent 的 Resource Access 矩阵 → 必须 review 其他 3 个 agent 的对应列保持纪律一致
- 新增 agent / skill → 必须完整加 `## Resource Access` matrix + `## Escalation Protocol`（agent 专属）或 `## AskUserQuestion Option Schema`（skill 专属）
- 跨阶段约束变动 → 必须同步更新 `docs/exec-plans/active/roundtable-plan.md` §跨阶段约束章节
- 修改 `_detect-project-context.md` → 必须同步 review 所有 5 个调用方（`commands/workflow.md` / `commands/bugfix.md` / `commands/lint.md` / `skills/architect.md` / `skills/analyst.md`）
- 新增或修改 Phase Matrix 的 stages → 必须同步更新 `commands/workflow.md` §Step 3 artifact chain 和 `docs/INDEX.md` 的 6 类 orphan 扫描清单
- 新增用户产出文档类别（如 `benchmarks/`）→ 必须同步更新 Step 7 Index Maintenance 的 "identify category" 列表
- 创建 issue（`gh issue create`）→ 必须加 `P0/P1/P2/P3` 标签（P0 阻塞全流程/数据损坏；P1 主干缺陷/UX 中断；P2 质量缺陷/功能缺口；P3 优化/长期议题）
- 评估 issue 执行顺序 → 优先按 priority 排序（P0 → P1 → P2 → P3），同优先级内再看依赖 / dogfood 串联
