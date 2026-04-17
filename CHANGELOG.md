# Changelog

All notable changes to **roundtable** will be documented in this file.

本项目遵循 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)，版本号遵循 [Semantic Versioning](https://semver.org/)。

## [Unreleased]

### Added

- 仓库骨架：`.claude-plugin/`（plugin.json + marketplace.json）、`skills/`、`agents/`、`commands/`、`hooks/`、`examples/`、`docs/`
- 完整设计文档 `docs/design-docs/roundtable.md`：D1-D9 九项关键决策 + 量化评分 + FAQ
- 执行计划 `docs/exec-plans/active/roundtable-plan.md`：P0-P6 分阶段路线
- 决策日志 `docs/decision-log.md`：DEC-001 plugin 架构
- 操作日志 `docs/log.md`：设计层文档时间索引
- 文档索引 `docs/INDEX.md`
- Apache-2.0 许可证

### 预期 v0.1.0 发布前完成

- [x] P1: `skills/architect.md` + `commands/workflow.md`（POC，方式 A 冒烟通过）
- [x] P2: 剩余角色（`skills/analyst.md` + `agents/developer|tester|reviewer|dba.md` + `commands/bugfix|lint.md`）
- [x] P3: `docs/claude-md-template.md`、`docs/onboarding.md`、`docs/migration-from-local.md`、`examples/{rust-backend,ts-frontend,python-datapipeline}-snippet.md`
- [ ] P4: 真实项目自消耗闭环验证
- [ ] P5: 外部用户试装验证
- [ ] P6: 打 v0.1.0 tag 和 GitHub Release
