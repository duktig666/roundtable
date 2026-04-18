# Changelog

All notable changes to **roundtable** will be documented in this file.

本项目遵循 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)，版本号遵循 [Semantic Versioning](https://semver.org/)。

## [Unreleased]

### Added (P4 dogfood improvements, 2026-04-19)

- **Resource Access matrix** in every role file (3 skills + 4 agents): explicit Read / Write / Report-to-orchestrator / Forbidden columns; no-autonomous-git rule baked in
- **Escalation Protocol** in every agent file (developer / tester / reviewer / dba): structured `<escalation>` JSON block format (type / question / context / options[label, rationale, tradeoff, recommended] / remaining_work) so subagents can request user decisions without `AskUserQuestion`
- **AskUserQuestion Option Schema** in skills (architect / analyst): required fields per option — architect carries `recommended` (at most 1), analyst keeps it factual (no recommendation)
- **Phase Matrix + parallel dispatch decision tree** in `commands/workflow.md`: 8-stage visualization (⏳ / 🔄 / ✅ / ⏩) + 4-condition parallelism gate + exec-plan checkbox serialization rule
- Orchestrator `<escalation>` handling step (Step 5) with parse / invoke `AskUserQuestion` / re-dispatch workflow
- DEC-002 in decision log documenting the three accepted improvements

### Changed (P4 dogfood improvements, 2026-04-19)

- `commands/workflow.md`: near-total rewrite (96% rewrite ratio) into phase-matrix orchestrator; all prompt body in English per roundtable-plan cross-phase constraint
- `_detect-project-context` activation switched from Skill tool invocation to inline `Read + execute 4 steps` across all 5 call-sites (workflow / bugfix / lint / architect / analyst); `Skill` tool activation of underscore-prefixed internal helper was observed to fail in some Claude Code releases
- Phase gates refined: same-role auto-advance permitted when exec-plan prerequisites are met and no Critical findings; cross-role transitions always require user confirmation (unless `critical_modules` mechanically dictates)

### Initial scaffolding (P0, 2026-04-17)

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
- [x] P4: 真实项目自消耗闭环验证（gleanforge dogfood；`docs/testing/plans/p4-self-consumption.md`）
- [ ] P5: 外部用户试装验证
- [ ] P6: 打 v0.1.0 tag 和 GitHub Release
