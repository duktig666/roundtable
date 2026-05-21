# Changelog

All notable changes to **roundtable** will be documented in this file.

本项目遵循 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)，版本号遵循 [Semantic Versioning](https://semver.org/)。

## [Unreleased]

### Changed

- `commands/workflow.md` Step 2: replaced the abstract "every phase transition must be posted" sentence with an explicit checklist of broadcast points (workflow start / phase 1·2·4·6·7·8·9 completion / user gates 3·5 / closeout). The v0.0.6 rule was too easy to miss at runtime — observed in practice: workflow start posted to TG, phase 1 completion did not.
- `commands/bugfix.md` Step 1: added a one-line reference to the workflow.md broadcast rule so bugfix runs don't go silent on TG either.

## [0.0.7-rc1] - 2026-05-21

Release candidate. Final v0.0.7 will follow after user verification of P0.1-P0.3 in docs/exec-plans/active/codex-compatibility.md and supply of assets/icon.svg + assets/logo.png.

Codex CLI + Codex App compatibility. Workflow / bugfix / lint move from `commands/*` to `skills/*` so a single canonical definition powers both runtimes. Subagent runtime safety hardened via prose under Codex (where the `tools:` frontmatter is not enforced). Workflow closeout learns about Codex App's detached-HEAD sandbox.

### Added

- `.codex-plugin/plugin.json` — Codex manifest with full `interface` block (displayName / category / capabilities / defaultPrompt / brandColor / composerIcon / logo placeholder) and inline `hooks.sessionStart` referencing `${PLUGIN_ROOT}/hooks/session-start`. Codex users install via `codex plugin add github.com/duktig666/roundtable`.
- `AGENTS.md` — single-line `CLAUDE.md` text pointer. Codex reads it as project memory; no content duplication.
- `skills/workflow/SKILL.md` + `skills/bugfix/SKILL.md` + `skills/lint/SKILL.md` — canonical workflow definitions migrated from `commands/*`. Same body in both runtimes.
- `skills/{workflow,bugfix,lint,analyst,architect}/references/codex-tools.md` — tool-mapping tables (Claude Code → Codex), TG MCP optional section, `spawn_agent`/`wait_agent`/`close_agent` usage, `request_user_input` decision protocol, `multi_agent` + `plugin_hooks` troubleshooting.
- `skills/workflow/SKILL.md` Step 5 — environment detection (`GIT_DIR` vs `GIT_COMMON`, `BRANCH`) and Path A handoff payload (commit SHA + suggested branch name + PR title/body) for Codex App's detached-HEAD `workspace-write` sandbox. Standard 4-option closeout still runs in all other cases.
- README / README-zh — Codex CLI + Codex App install sections + troubleshooting (`multi_agent`, `plugin_hooks`, optional TG MCP).
- CONTRIBUTING.md — `Codex 本地测试` checklist + AGENTS.md pointer note.

### Changed

- `commands/{workflow,bugfix,lint}.md` are now thin shells (single-line `Skill(...)` wrapper). Canonical body lives in `skills/<name>/SKILL.md`. Claude Code users keep their `/roundtable:<name>` muscle memory; Codex loads the same skill body.
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` bumped to v0.0.7.
- `agents/reviewer.md` Forbidden section — explicit Codex-runtime prose: no `apply_patch`, no mutating shell (`sed -i`, `mv`, `rm`, `tee`, `>`); read-only `cat`/`rg`/`find`/`git log|diff|show|blame` only.
- `agents/dba.md` Forbidden section — explicit Codex-runtime prose: no file mutations and no SQL writes (INSERT/UPDATE/DELETE/ALTER/DROP/TRUNCATE/MERGE/REPLACE) via shell, psql, mysql, or any MCP DB tool; SELECT/EXPLAIN/SHOW only.
- `agents/developer.md` + `agents/tester.md` — new `## Codex Runtime Note` section with Read/Grep/Glob/Bash/Write/Edit → Codex tool equivalents.

### Notes

- Subagent `tools:` frontmatter retained per DEC-0003. Under Claude Code the frontmatter is a hard rail; under Codex (where it is not enforced) the prose rails above carry the same constraints.
- TG MCP is optional under Codex. With no TG MCP loaded, the channel-aware logic degrades to terminal mode automatically (`request_user_input` for decision gates, plain stdout for phase summaries).
- Cursor / Gemini CLI / Copilot CLI / OpenCode adapters are explicit follow-ups; the `references/<runtime>-tools.md` pattern is ready to extend.
- Three pre-flight validation steps (P0.1 Claude `/<plugin>:<skill>` syntax, P0.2 Codex hook stdout schema, P0.3 Codex subagent filesystem IO) are deferred to the tester phase — see `docs/exec-plans/active/codex-compatibility.md` Change Log for details and safe defaults applied.

### Migration Notes (v0.0.6 → v0.0.7-rc1)

**No breaking changes for Claude Code users**: `/roundtable:workflow`, `/roundtable:bugfix`, and `/roundtable:lint` continue to work. The commands now dispatch to skills (`Skill(skill: "roundtable:<name>", args: ...)`) where the canonical workflow definitions live. If you were directly reading `commands/*.md` in tooling, switch to `skills/<name>/SKILL.md`.

**For Codex users**: ensure `[features] multi_agent = true` and `[features] plugin_hooks = true` in `~/.codex/config.toml`. See README Troubleshooting.

## [0.0.6] - 2026-05-11

Post-rewrite polish: channel-aware user prompts and phase broadcast, looser doc templates, leftover DEC-numbering cleanup.

### Added

- Channel-aware decision prompts in `skills/architect/SKILL.md`, `skills/analyst/SKILL.md`, `commands/workflow.md`: if the telegram MCP server is loaded, skills + orchestrator post `a) … b) …` text-protocol options via TG `reply` and wait for a text reply instead of calling `AskUserQuestion` (which blocks the TG flow).
- Phase-transition broadcast to TG in `commands/workflow.md` Step 2: when the telegram MCP is present, every phase transition and user gate is also posted via `reply`; in-phase progress uses `edit_message`, phase completion uses a new `reply` so the device push-notifies.

### Changed

- `skills/architect/SKILL.md` design-doc + exec-plan templates and `skills/analyst/SKILL.md` analyze template: marked sections `# required` vs `# optional`; agents must omit optional sections that have no real content (no empty placeholders). Visual skeleton retained as a code block for stable formatting.
- `skills/analyst/SKILL.md` six-question framework: dropped the `skip: <reason>` placeholder requirement — conditional questions are now skipped silently when not relevant.
- `CLAUDE.md` coding-principles bullet updated to document the channel-aware user-prompt + phase-broadcast behavior (previously said "Skills call AskUserQuestion plainly").

## [0.0.5] - 2026-04-29

Minimal rewrite: dropped 64% of prompt code and removed five auxiliary documentation mechanisms. Plugin is now language-neutral (output language follows the project's CLAUDE.md). Architect runs a two-track output flow for medium/large tasks (separate design-doc + exec-plan with two user gates) and a single-artifact flow for small tasks.

### Added

- `docs/roundtable.md` (architecture overview, 139 lines).
- `docs/usage.md` (5-min quickstart + install methods + plugin composition with superpowers / gstack + FAQ; renamed from `onboarding.md`).
- `docs/case-study-rewrite.md` (recursive dogfood case study covering both rounds of this rewrite).
- `[NEED-DECISION] <topic> | options: A) ... B) ...` line-based decision-relay pattern: subagents print one line in their return text, orchestrator parses and calls `AskUserQuestion`.
- SessionStart hook (`hooks/session-start`) that detects `docs_root` + `project_id` once per session and injects them as standard `additionalContext` (invisible to user, readable by all roles).
- Two-track architect output: `docs/design-docs/<slug>.md` (discussion-state) followed by `docs/exec-plans/active/<slug>.md` (execution-state) for medium/large tasks; `source: design-docs/<slug>.md` frontmatter links them.
- Local install instructions in README (both `claude --plugin-dir` and registering the local checkout as a marketplace).

### Changed

- All `agents/`, `skills/`, `commands/` prompt files rewritten in English.
- Output language is now driven by the project's CLAUDE.md (declare `文档中文` to get Chinese docs); plugin templates use English section names which the LLM translates at write time.
- `commands/lint.md` rebuilds `INDEX.md` instead of relying on every doc-creator to maintain it inline.
- 4 agents (developer / tester / reviewer / dba) now run as subagents only; analyst / architect remain skills (need `AskUserQuestion`).
- README.md / README-zh.md rewritten to match the new design (down from 285 → 133 lines each).
- `commands/workflow.md` Phase Matrix expanded from 7 to 9 rows (added design-doc emit + design confirmation gate).
- `docs/exec-plans/active/<slug>.md` frontmatter carries `source: design-docs/<slug>.md` when a design-doc exists.

### Removed

- `docs/decision-log.md` mechanism (architectural decisions now live in each exec-plan's `## Key Decisions` section and travel with it).
- `docs/log.md` mechanism (`git log` is authoritative for change history).
- `docs/faq.md` mechanism (slug-level FAQ stays inside the relevant analyze / design-doc).
- `<escalation>` JSON schema and the `Monitor` / progress JSONL pipeline (replaced by `[NEED-DECISION]` and short markdown summaries).
- `decision_mode` (modal/text) and `auto_mode` bootstrap (channel hooks now own remote rendering).
- `subagent` / `inline` dual execution form for developer/tester/reviewer/dba.
- `research` subagent (architect now dispatches general-purpose `Agent` for parallel research).
- `skills/_detect-project-context.md` (replaced by SessionStart hook).
- `skills/_progress-content-policy.md`.
- `scripts/preflight.sh`, `scripts/ref-density-check.sh`, `scripts/ref-density.baseline`.
- All v0.0.4-era internal dogfood records under `docs/{analyze,bugfixes,exec-plans,reviews,testing}/` and the `docs/_archive/` historical bundle (git history retained via prior commits).
- `examples/` snippets (3 v0.0.4-era CLAUDE.md templates per language; the minimal config style is documented in `docs/usage.md` §3).
- DEC-001..030 references throughout.

### Fixed

- SessionStart hook output uses the standard JSON `hookSpecificOutput.additionalContext` protocol and is invisible to the user (no more raw stdout leaking into the chat).
- Plugin no longer hardcodes Chinese section names in templates, restoring portability to English-only projects.

### Migration notes

- v0.0.4 historical docs are retained in git history (see commit 5472371 and earlier).
- New work should not link to `docs/_archive/` (now removed; references will 404).
- Project-level CLAUDE.md should declare `文档中文` if Chinese output is desired (otherwise the LLM follows the English template).
- If your project relied on `docs/decision-log.md`, migrate decisions into the relevant exec-plan's `## Key Decisions` section.

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
