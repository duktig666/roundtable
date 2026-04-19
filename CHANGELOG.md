# Changelog

All notable changes to **roundtable** will be documented in this file.

本项目遵循 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)，版本号遵循 [Semantic Versioning](https://semver.org/)。

## [Unreleased]

## [0.0.1] - 2026-04-20

首个公开 release —— 完整多角色工作流编排可用（analyst / architect / developer / tester / reviewer / dba），Phase Matrix + A/B/C gate 分类 + Escalation Protocol + Monitor 实时进度全部就绪。

### Added (README documentation, 2026-04-20)

- README 新增 **Phase Matrix 机制** 节：9 阶段状态表 + ⏳🔄✅⏩ 图例 + DEC-006 A/B/C gate 分类说明
- README 新增 **workflow 流程图** 节：mermaid 流程图覆盖 Step 0→9 全链路（skill / agent / gate 配色），附 Step 3.5/4/5/6b/7-8 跨阶段编排要点

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
- `docs/testing/plans/` → `docs/testing/` (flatten double-nesting); tester artifacts now named `[slug].md` / `[slug]-bug-<id>.md` / `[slug]-benchmark.md`; 14 files updated to new path
- Agent Forbidden list explicitly adds `target_project/CLAUDE.md` (orchestrator owns writes to 工具链覆盖 section); applies to developer / tester / reviewer / dba

### Fixed (P4 dogfood improvements, 2026-04-19)

- Project-specific references (`gleanforge`, `vault/`, `llm/`, `DEC-003`, concrete `P0.x` numbers) removed from prompt files; 0-hardcoded scan passes
- `docs/exec-plans/active/roundtable-plan.md` P1 / P2 historical checkboxes backfilled with P4 evidence; previously left [ ] pending "real-world validation needed"

### Docs (P4 dogfood improvements, 2026-04-19)

- `docs/claude-md-template.md`: `工具链覆盖` section gains package manager / runtime / dev cmd fields; new "谁填、何时填、怎么填？" subsection explaining orchestrator-fills-on-P0.1-completion contract; two worked 回填样板 examples (TS+pnpm+vitest / Rust+cargo+nextest)

### Added (INDEX auto-maintenance, 2026-04-19)

- `commands/workflow.md` new Step 7 "Index Maintenance (batched)": orchestrator accumulates `created:` paths across a phase and updates `{docs_root}/INDEX.md` once per phase gate (single Read+Edit), instead of per-subagent-return. ~1-2% token overhead vs ad-hoc update.
- Role-report contract: every agent's final report MUST list newly-created files under a `created:` section with `path` + `description`. Orchestrator parses this to build the INDEX update.
- `agents/developer.md` / `tester.md` / `reviewer.md` / `dba.md`: Resource Access `Report to orchestrator` column adds "newly-created files under `{docs_root}/`" entry. Forbidden: roles never edit `INDEX.md` directly.
- `docs/INDEX.md` header: formalized "index-or-it-didnt-happen" maintenance contract for future drift prevention.
- New `testing/` subsection under `当前文档清单` indexing the P4 self-consumption report (previously unindexed).

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
- [x] P4: 真实项目自消耗闭环验证（gleanforge dogfood；`docs/testing/p4-self-consumption.md`）
- [ ] P5: 外部用户试装验证
- [ ] P6: 打 v0.1.0 tag 和 GitHub Release
