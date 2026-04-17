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

本仓库的文档体系参考 dex-sui 的三件套（见 `docs/design-docs/roundtable.md` §2.2）：

| 位置 | 记录什么 |
|------|---------|
| 文档内"变更记录"章节 | 具体改了什么、为什么改 |
| `docs/log.md` | 哪个文档在何时被更新（时间索引） |
| `docs/decision-log.md` | 决策层面演进（含 Superseded 机制） |

目录结构见 `docs/INDEX.md`。文件名用统一 slug（kebab-case），一个主题从 analyze → design-docs → exec-plans → testing/plans 贯穿。

## 本地测试

v0.1 尚无自动化 CI，手动测试清单：

- [ ] `plugin.json` JSON 合法
- [ ] `marketplace.json` JSON 合法
- [ ] `/plugin install` 在本地 `--plugin-dir` 模式下能装上
- [ ] 各 skill / agent / command 在本地模拟触发能执行（参考 `docs/onboarding.md`）
- [ ] grep 硬编码：`grep -rE "dex-sui|hyperliquid|cargo xclippy|撮合" skills/ agents/ commands/` 应返回空
