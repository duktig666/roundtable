# Changelog

All notable changes to **roundtable** will be documented in this file.

本项目遵循 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)，版本号遵循 [Semantic Versioning](https://semver.org/)。

## [Unreleased]

### Added

- 初始化仓库骨架（`.claude-plugin/`、`skills/`、`agents/`、`commands/`、`hooks/`、`docs/`、`examples/`）
- 设计文档 `docs/design-docs/roundtable.md`（从 dex-sui 迁入，完整 D1-D9 决策记录 + 量化评分）
- 执行计划 `docs/exec-plans/active/roundtable-plan.md`（P0-P6 分阶段路线）
- 操作日志 `docs/log.md`（设计层文档时间索引，首条记录初始化事件）
- 文档索引 `docs/INDEX.md`
- 为符合 plugin 自己推荐的"产出契约"，docs 目录重构为 `design-docs/[slug].md` + `exec-plans/active/[slug]-plan.md` 分层结构（dogfooding）
- 决策日志 `docs/decision-log.md`（DEC-001 plugin 架构，承接自 dex-sui DEC-010）
- Apache-2.0 许可证

### 预期 v0.1.0 发布前完成

- P1: `skills/architect.md` + `commands/workflow.md`（POC）
- P2: 其余角色（`skills/analyst.md` + 4 agent + 2 command）
- P3: `docs/claude-md-template.md`、`docs/onboarding.md`、`docs/migration-from-dex-sui.md`、`examples/dex-sui-snippet.md`
- P4: dex-sui 自消耗闭环验证
- P5: 外部用户试装验证
- P6: 打 v0.1.0 tag
