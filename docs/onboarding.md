# Roundtable 5 分钟上手

## 1. 装 plugin

在 Claude Code 会话里：

```
/plugin marketplace add duktig666/roundtable
/plugin install roundtable@roundtable --scope user
```

零弹窗。装完即可用：

- `/roundtable:workflow <任务>` — 多角色编排（analyst → architect → developer → tester → reviewer → dba）
- `/roundtable:bugfix <bug 描述>` — 跳过设计阶段直接修 bug
- `/roundtable:lint` — 文档健康检查 + 重建 `docs/INDEX.md`
- `@roundtable:analyst` / `@roundtable:architect`（skill，主会话弹窗交互）
- `@roundtable:developer` / `@roundtable:tester` / `@roundtable:reviewer` / `@roundtable:dba`（subagent，独立上下文）

## 2. 在你的项目根 `CLAUDE.md` 加配置（可选）

最少不写也能跑（auto-detect）。但建议至少加 critical_modules，让 tester / reviewer 在该 modules 命中时强制触发：

```markdown
## roundtable 配置

- critical_modules: <列 1–3 个改错就出大事的模块名 / 关键词>
- lint_cmd: <项目自身的 lint 命令；默认按工具链推断>
- test_cmd: <项目自身的 test 命令；默认按工具链推断>
```

## 3. 第一次跑

```bash
cd <your-project>
claude
```

会话里：

```
/roundtable:workflow 设计一个 XXX 功能
```

会发生什么：

1. SessionStart hook 注入 `docs_root` + `project_id`（向上找 `docs/` 或 `documentation/`，找不到时 AskUserQuestion 让你确认创建位置）
2. orchestrator 渲染 7 行 Phase Matrix；按任务规模决定哪些阶段可跳过
3. analyst（可选）出调研报告 `docs/analyze/<slug>.md`
4. architect 出 `docs/exec-plans/active/<slug>.md`（含问题陈述 / 方案 / 关键决策 / 步骤清单 / 风险）；遇决策点弹 AskUserQuestion
5. **停**等用户 `go` / `问:` / `调:` / `停` —— 这是唯一硬 gate
6. developer subagent 实施，勾 exec-plan checkbox；如需决策返回 `[NEED-DECISION]`，主会话再弹 AskUserQuestion 后续派
7. 按需 tester / reviewer / dba subagent
8. 终点 closeout：渲染 commit msg + PR draft，等用户 `go-commit` / `go-pr` / `go-all` / `停`

## 4. 文档产出

```
<project>/docs/
├── INDEX.md                          ← /roundtable:lint 自动重建
├── analyze/<slug>.md                 ← analyst
├── exec-plans/
│   ├── active/<slug>.md              ← architect + developer 勾选
│   └── completed/                    ← 完工归档
├── testing/<slug>.md                 ← tester
├── reviews/<YYYY-MM-DD>-<slug>.md    ← reviewer / dba
└── bugfixes/<slug>.md                ← Tier 2 严重 bug postmortem
```

每个主题用一个 slug 串起来。架构决策直接写在 exec-plan 的"关键决策"小节里，跟该 exec-plan 一起从 `active/` 归档到 `completed/`。

## 5. 常见问题

**Q: 在 workspace 根启动，识别不到子项目？**
A: 确认子项目是 git 仓库；hook 用 `git rev-parse --show-toplevel` 拿 project_id。非 git 目录走 `pwd` 的 basename 兜底。

**Q: AskUserQuestion 没弹窗？**
A: 工具不可用时（MCP 断开等）skill 会以文字问。重启 Claude Code 试试。

**Q: 我有本地 `.claude/agents/` 自建 agent 会冲突吗？**
A: 会。project level 同名 agent 覆盖 plugin level。改名或删除即可。

**Q: 旧版 design-docs / decision-log 在哪？**
A: `docs/_archive/`，git history 完整保留。新工作不要再链到 `_archive/`。
