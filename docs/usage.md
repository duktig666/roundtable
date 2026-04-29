# Roundtable 使用指南

5 分钟上手 + 安装方式 + 与 superpowers / gstack 协同。架构总览见 [`roundtable.md`](roundtable.md)。

## 1. 安装

### 方式 A：从 marketplace 安装（推荐）

```
/plugin marketplace add duktig666/roundtable
/plugin install roundtable@roundtable --scope user
```

零弹窗，秒装完。

### 方式 B：本地开发安装

适合贡献代码 / 跟踪未发布改动 / fork 自定义。两种 sub-mode：

**B1. 一次性运行（最简）**：
```bash
git clone git@github.com:duktig666/roundtable.git ~/code/roundtable
cd <your-project>
claude --plugin-dir ~/code/roundtable
```

每次启动 `claude` 时加 `--plugin-dir`，编辑插件文件后**新会话立即生效**。

**B2. 持久注册（local marketplace）**：
```bash
git clone git@github.com:duktig666/roundtable.git ~/code/roundtable
# 然后在 Claude Code 会话里：
/plugin marketplace add ~/code/roundtable
/plugin install roundtable@roundtable --scope user
```

注册一次后免 `--plugin-dir`，仍读 local 文件，编辑即生效。

## 2. 装完即可用

```
/roundtable:workflow <任务>     # 多角色编排
/roundtable:bugfix <bug 描述>   # 跳过设计直接修 bug
/roundtable:lint                # 文档健康检查 + 重建 INDEX.md

@roundtable:analyst             # 直接调研（skill）
@roundtable:architect           # 直接设计（skill）
@roundtable:developer           # 直接派发实施（subagent）
@roundtable:tester              # 直接派发测试（subagent）
@roundtable:reviewer            # 直接派发评审（subagent）
@roundtable:dba                 # 直接派发 DB review（subagent）
```

## 3. 在你的项目根 CLAUDE.md 加配置（可选）

不写也能跑（auto-detect）。建议加：

```markdown
## 语言与风格
- 代码英文、注释中文、文档中文、回答中文

## roundtable 配置
- critical_modules: <列 1–3 个改错就出大事的模块名 / 关键词>
- lint_cmd: <项目 lint 命令；默认按工具链推断>
- test_cmd: <项目 test 命令；默认按工具链推断>
```

plugin 模板用英文 section 名（Background, Solution, Steps 等），输出语言由你 CLAUDE.md 决定（`文档中文` → LLM 自动翻译为中文输出）。

## 4. 第一次跑（典型流程）

```bash
cd <your-project>
claude
```

会话里：

```
/roundtable:workflow 设计一个 XXX 功能
```

会发生什么（**medium / large 任务双轨制**）：

1. SessionStart hook 注入 `docs_root` + `project_id`
2. orchestrator 渲染 9 行 Phase Matrix
3. analyst（可选）调研 → `docs/analyze/<slug>.md`
4. architect 出**设计文档** → `docs/design-docs/<slug>.md`（含问题 / 方案 / 关键决策 / 备选 / 风险 / FAQ），遇决策点弹 AskUserQuestion
5. **停**等用户 `accept` / `modify` / `reject`（设计 gate）
6. architect 出**执行计划** → `docs/exec-plans/active/<slug>.md`（仅含步骤 / 验证 / 风险）
7. **停**等用户 `accept` / `modify` / `reject`（计划 gate）
8. developer subagent 实施，勾 exec-plan checkbox；如需决策返回 `[NEED-DECISION]`，主会话弹 AskUserQuestion 后续派发
9. 按需 tester / reviewer / dba subagent
10. closeout：渲染 commit msg + PR draft，等用户 `go-commit` / `go-pr` / `go-all` / `stop`

**small 任务**（bug fix / 单文件 / UI 微调）：跳过 step 4-5，architect 直接写一个 exec-plan 含 `## Solution` 小节；只有一道 confirm gate。

## 5. 文档产出

```
<project>/docs/
├── INDEX.md                          ← /roundtable:lint 自动重建
├── analyze/<slug>.md                 ← analyst
├── design-docs/<slug>.md             ← architect 设计文档（讨论态，medium/large）
├── exec-plans/
│   ├── active/<slug>.md              ← architect 执行计划（执行态）+ developer 勾选
│   └── completed/                    ← 完工归档
├── testing/<slug>.md                 ← tester
├── reviews/<YYYY-MM-DD>-<slug>.md    ← reviewer / dba
└── bugfixes/<slug>.md                ← Tier 2 严重 bug postmortem
```

每个主题用一个 slug 串起来。exec-plan 的 frontmatter 通过 `source: design-docs/<slug>.md` 链回设计文档。

## 6. 与 superpowers / gstack 协同

roundtable = 流程编排层。叠加另两层：

**superpowers**（auto-trigger 工程纪律）：
```
/plugin install superpowers@claude-plugins-official
```
推荐核心：`test-driven-development` / `systematic-debugging` / `verification-before-completion`。

**gstack**（显式工具）：
```bash
git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack
cd ~/.claude/skills/gstack && ./setup
```
推荐：`/cso`（安全审）/ `/investigate`（系统化 debug）/ `/codex`（独立 review）/ `/careful` `/guard`（destructive 防护）；UI 项目加 `/qa` `/browse`。

**避免冲突**（disable 或不调用）：
- superpowers: brainstorming / writing-plans / subagent-driven-development（与 architect/developer subagent 重叠）
- gstack: /office-hours / /plan-eng-review / /autoplan / /ship / /land-and-deploy（重叠或与"merge 永远等用户"硬冲突）

## 7. 常见问题

**Q: SessionStart hook 注入失败？**
A: 在 cwd 向上找 `docs/` 或 `documentation/` 目录，找不到时标 `status: needs-init`。command 启动会 AskUserQuestion 让你确认。也可设环境变量 `ROUNDTABLE_DOCS_ROOT=/abs/path` 强制。

**Q: AskUserQuestion 没弹窗？**
A: 工具不可用时（MCP 断开等）skill 会以文字问。重启 Claude Code 试试。

**Q: 我有本地 `.claude/agents/` 自建 agent 会冲突吗？**
A: 会。project level 同名 agent 覆盖 plugin level。改名或删除即可。

**Q: 旧版 design-docs / decision-log 在哪？**
A: `docs/_archive/`，git history 完整保留。新工作不要再链到 `_archive/`。

**Q: 我项目 CLAUDE.md 没声明文档语言？**
A: LLM 会按 plugin 模板的英文 section 名输出英文文档。要中文请加`文档中文`那行。

**Q: subagent 需要决策怎么办？**
A: subagent 不直接弹窗，在返回文本里印 `[NEED-DECISION] <topic> | options: A) ... B) ...`。主会话 grep 后调 AskUserQuestion，把答案写入 exec-plan `## Change Log`，重派同一 subagent 续做。
