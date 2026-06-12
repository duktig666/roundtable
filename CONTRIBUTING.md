# Contributing to roundtable

## 贡献者本地开发模式（推荐）

不用等 release，直接用本地 clone 调试：

```bash
cd /path/to/your/workspace
git clone git@github.com:duktig666/roundtable.git

# 在你的项目里用 --plugin-dir 指向本地 clone，改代码立刻生效
cd /path/to/your/project
claude --plugin-dir /path/to/your/workspace/roundtable
```

改完 `skills/`、`agents/`、`commands/` 下任意文件，重启 Claude Code 即可验证。

## 分支约定

- `main`：稳定分支，只接受 PR
- `v0.x-dev`：v0.1 阶段开发主线
- 功能分支：`feat/<slug>`、`fix/<slug>`、`docs/<slug>`

## PR 规范

- 标题用英文：`type: short description`（type = feat/fix/docs/refactor/chore/test）
- PR body 用英文说明 motivation + change list + test plan
- 中文讨论可以放 Issue 和 review comment 里

## Commit 规范

- Commit message 用英文
- 如果涉及 Claude Code Plugin 规范变更，在 commit message 里引用官方文档链接

## 文档变更纪律

本仓库的文档体系（架构总览见 `docs/roundtable.md`）：用户产出文档统一落在 `docs/` 下 7 个目录 —— `analyze/`、`design-docs/`、`exec-plans/active|completed/`、`testing/`、`reviews/`、`bugfixes/`。

- `docs/INDEX.md` 由 `/roundtable:lint` 生成，禁止手改
- 决策写进对应 exec-plan 的 `## Key Decisions` / `## Change Log`，跟随 exec-plan 一起归档（不另设独立的决策日志 / 时间索引文件）
- 文件名用统一 slug（kebab-case），一个主题从 analyze → design-docs → exec-plans → testing 贯穿

## 本地测试

v0.1 尚无自动化 CI，手动测试清单：

- [ ] `.claude-plugin/plugin.json` JSON 合法
- [ ] `.claude-plugin/marketplace.json` JSON 合法
- [ ] `.codex-plugin/plugin.json` JSON 合法
- [ ] `/plugin install` 在本地 `--plugin-dir` 模式下能装上
- [ ] 各 skill / agent / command 在本地模拟触发能执行（参考 `docs/usage.md`）
- [ ] grep 硬编码：`grep -rEi "<project-specific-term>|<language-specific-cmd>" skills/ agents/ commands/` 应返回空 —— 所有业务 / 语言特定术语都应在 skill/agent prompt 里用占位符（`{target_project}` / `{docs_root}` 等），运行时从检测或 CLAUDE.md 声明填充

## Codex 本地测试

Codex CLI / App 路径的手动测试清单：

- [ ] 装 Codex CLI（参 Codex 官方文档）
- [ ] `codex plugin add /absolute/path/to/roundtable`（或 git 仓库 URL）
- [ ] 启动 Codex session 后 `/skills` 列表能看到 `workflow / bugfix / lint / analyst / architect`
- [ ] 用「跑多角色工作流」之类描述触发 workflow skill，跑通 phase 1-5
- [ ] developer / tester / reviewer / dba subagent 通过 `spawn_agent` + `wait_agent` + `close_agent` 派出
- [ ] 决策点弹 `request_user_input`；TG MCP 未配置时自动降级到终端
- [ ] SessionStart hook 注入的 `Roundtable context:` block 能在 skill 里读到
- [ ] Codex App 管理的 worktree（detached HEAD）下走 closeout，输出 handoff payload 而非 4-option menu

## AGENTS.md

`AGENTS.md` 是 Codex 用的文本指针，内容仅一行 `CLAUDE.md`。无需同步 CLAUDE.md 内容；它只是指针文件，实际效果取决于 runtime 是否跟随指针去读 `CLAUDE.md` 主体。
