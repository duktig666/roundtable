# roundtable 文档索引

> 按产出类型分类的文档导航。**决策权威性**：`decision-log.md` > `design-docs/` > `exec-plans/`。

## 👤 用户向（装 plugin 的人看）

| 文件 | 用途 |
|------|-----|
| [../README.md](../README.md) | GitHub 首页：roundtable 是什么、怎么装、角色分工 |
| `onboarding.md`（P3 产出） | 5 分钟上手手册 |
| `claude-md-template.md`（P3 产出） | 给用户抄到自己项目 CLAUDE.md 的完整模板 |
| `migration-from-local.md`（P3 产出） | 从项目本地 `.claude/agents/` 切换到 plugin 的迁移 runbook |

## 🧑‍💻 维护者向（内部开发纪律）

### 决策与索引

| 文件 | 用途 |
|------|-----|
| [decision-log.md](decision-log.md) | **项目决策权威注册表**（DEC-xxx），append-only |
| [log.md](log.md) | 设计层文档时间索引（"何时、谁、动了哪份文档"） |

### 按工作流阶段分类

| 目录 | 产出者 | 说明 |
|------|-------|------|
| `analyze/` | analyst | 调研报告，文件名 `[slug].md` |
| [design-docs/](design-docs/) | architect | 核心设计文档，文件名 `[slug].md` |
| `exec-plans/active/` | architect | 进行中的执行计划，文件名 `[slug]-plan.md` |
| `exec-plans/completed/` | developer（归档） | 已完成的执行计划 |
| `testing/plans/` | tester | 测试计划，文件名 `[slug].md` |
| `reviews/` | reviewer / dba | 关键审查归档，文件名 `[YYYY-MM-DD]-[slug].md` 或 `[YYYY-MM-DD]-db-[slug].md` |

## 当前文档清单

### design-docs

- [roundtable.md](design-docs/roundtable.md) — roundtable plugin 本身的完整设计（D1-D9 决策 + 量化评分 + §12 FAQ）

### exec-plans

- active/
  - [roundtable-plan.md](exec-plans/active/roundtable-plan.md) — roundtable 实施计划（P0-P6，6 天）

## 主题 slug 约定

**文件名使用统一的"主题 slug"**，贯穿整个工作流便于关联：

- `analyze/[slug].md` → `design-docs/[slug].md` → `exec-plans/active/[slug]-plan.md` → `testing/plans/[slug].md`
- 主题 slug 使用 kebab-case 英文，例：`roundtable`、`role-profile-system`

## 变更记录约定（三件套）

| 位置 | 记录什么 |
|------|---------|
| 文档内"变更记录"章节 | **改了什么、为什么改**（design-docs / exec-plans / analyze 都要有） |
| `log.md` | **哪个文档在何时被更新**（时间索引） |
| `decision-log.md` | **决策层面演进**（Superseded 机制） |

三者互补：log.md 是索引，变更详情在文档自己的"变更记录"章节里，决策演进走 decision-log。
