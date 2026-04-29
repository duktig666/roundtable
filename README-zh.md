# roundtable

[English](./README.md) · [中文](./README-zh.md)

> **让 analyst、architect、developer、tester、reviewer、DBA 同坐一桌，用 plan-then-execute 纪律推进复杂工作。**

`roundtable` 是 [Claude Code](https://code.claude.com) plugin，把多角色 AI 开发工作流封装成一行安装。**极简设计**：4 subagent + 2 skill + 3 command + 1 SessionStart hook，全部 prompt+config 约 760 行。

## 安装

### 从 marketplace 安装（推荐）

```
/plugin marketplace add duktig666/roundtable
/plugin install roundtable@roundtable --scope user
```

### 本地安装（hacking / 跟踪未发布改动）

```bash
git clone git@github.com:duktig666/roundtable.git ~/code/roundtable
cd <your-project>
claude --plugin-dir ~/code/roundtable
```

或把本地 checkout 注册成 marketplace：

```
/plugin marketplace add /absolute/path/to/roundtable
/plugin install roundtable@roundtable --scope user
```

本地文件改动**新会话立即生效**。

## 在任何项目里用

```
/roundtable:workflow 设计资金费率功能
/roundtable:bugfix 修 Issue #123
/roundtable:lint
```

## 为什么叫 "roundtable"

> 圆桌骑士的规矩是没有上座 —— 每个骑士平等而坐，把各自的专长汇入共同决策。

这就是这个 plugin 的模型：

- **Analyst** 跑六问框架（失败模式 / 6 个月评价 + 4 个按需问题），只产**事实**——不做推荐
- **Architect** 消费 analyst 的事实；每个架构决策点都通过 `AskUserQuestion` 让你拍板；medium/large 任务先产 **design-doc**（讨论态），用户确认后再产 exec-plan（执行态）
- **Developer** 只在 exec-plan 锁定后才动代码；非平凡行为先写失败测试
- **Tester** 写对抗性 / E2E / Playwright 测试；发现业务 bug 只写复现测试不改业务码
- **Reviewer / DBA** 只读；reviewer 标 Critical / Warning / Suggestion；DBA 禁所有 SQL 写（不允许 INSERT/UPDATE/ALTER/DROP）

## 设计原则

1. **零配置安装** —— `plugin.json` 无 userConfig 弹窗；工具链按项目根文件 auto-detect
2. **architect 双轨产出** —— design-doc（讨论态，频繁迭代）和 exec-plan（执行态，稳定）拆成两份文件用于 medium/large 任务；small 任务合并
3. **逐决策弹窗** —— architect 每个关键决策当场调 `AskUserQuestion`，不积压成文字列表
4. **交互角色 → skill / 自主角色 → subagent** —— analyst/architect 主会话执行（需要 `AskUserQuestion`）；developer/tester/reviewer/dba 独立 subagent 上下文
5. **`[NEED-DECISION]` 模式** —— subagent 不能弹窗，在返回文本印一行，orchestrator grep 后调 `AskUserQuestion` 续派
6. **SessionStart hook 注入 `docs_root`** —— bash 在 session 开始时检测 docs_root + project_id（env > 向上找 `docs/` > `needs-init` 兜底），所有角色从注入上下文读，不再 inline 检测
7. **plugin 语言无关** —— prompt 全英文；输出语言由项目自己的 CLAUDE.md 决定（声明 `文档中文` 后所有产出自动中文）
8. **无机制堆叠** —— 没有 decision-log / log.md / faq.md / progress JSONL / Monitor / `<escalation>` JSON。决策直接写进 exec-plan 的 `## Key Decisions`；FAQ 追加到对应 analyze/design-doc；INDEX.md 由 `/roundtable:lint` 重建

## Phase Matrix

`/roundtable:workflow` 实时维护 9 行状态表，每次 phase transition 重新渲染。

| # | 角色 | 产出 | 可跳过？ |
|---|------|------|---------|
| 1 | analyst (skill) | `docs/analyze/<slug>.md` | 是（小任务）|
| 2 | architect (skill) | `docs/design-docs/<slug>.md` | 是（小任务）|
| 3 | user | 确认设计文档 | 是（无 design-doc 时跳过）|
| 4 | architect (skill) | `docs/exec-plans/active/<slug>.md` | 否 |
| 5 | user | 确认执行计划 | 否 |
| 6 | developer | `src/`, `tests/`，exec-plan 勾选 | 否 |
| 7 | tester | `docs/testing/<slug>.md` | 是 |
| 8 | reviewer | `docs/reviews/<YYYY-MM-DD>-<slug>.md` | 是 |
| 9 | dba | `docs/reviews/<YYYY-MM-DD>-db-<slug>.md` | 是（仅 DB 改动）|

状态：⏳ 待办 · 🔄 进行中 · ✅ 完成 · ⏩ 跳过

## Commands / Skills / Agents

| 类型 | 名称 | 用途 |
|------|------|------|
| command | `/roundtable:workflow <任务>` | 完整编排——自动判规模 / 派发角色 / 用户 gate / 解析 `[NEED-DECISION]` |
| command | `/roundtable:bugfix <issue>` | 跳过设计阶段，Tier 0/1/2 决策树，必须有回归测试 |
| command | `/roundtable:lint` | 只读文档检查；重建 `INDEX.md`；报告孤儿文档 / 断链 / 停滞 exec-plan |
| skill | `@roundtable:analyst` | 六问框架，事实层产出 |
| skill | `@roundtable:architect` | 双轨产出：design-doc → 用户确认 → exec-plan → 用户确认 |
| subagent | `@roundtable:developer` | 实施 + 单元测试；勾 exec-plan checkbox |
| subagent | `@roundtable:tester` | 对抗性 / E2E / Playwright；不改 `src/` |
| subagent | `@roundtable:reviewer` | 只读评审；输出 `<docs_root>/reviews/<date>-<slug>.md` |
| subagent | `@roundtable:dba` | 只读 DB 评审；禁所有 SQL 写操作 |

## 文档目录布局

```
your-project/docs/
├── INDEX.md                          ← /roundtable:lint 自动重建
├── analyze/<slug>.md                 ← analyst
├── design-docs/<slug>.md             ← architect（仅 medium/large）
├── exec-plans/
│   ├── active/<slug>.md              ← architect + developer 勾选
│   └── completed/                    ← 完工归档
├── testing/<slug>.md                 ← tester
├── reviews/<YYYY-MM-DD>-<slug>.md    ← reviewer / dba
└── bugfixes/<slug>.md                ← Tier 2 严重 bug postmortem
```

每个主题用一个 slug 串起来。exec-plan 的 frontmatter 通过 `source: design-docs/<slug>.md` 链回设计文档。

## 与其它 plugin 协同

roundtable = 流程编排层。叠加：

- **[superpowers](https://github.com/obra/superpowers)** 工程纪律（TDD / debug / verification，auto-trigger）
- **[gstack](https://github.com/garrytan/gstack)** 显式工具（`/cso` 安全审 / `/investigate` 根因调试 / `/codex` 独立 review / `/careful` destructive 防护）

完整推荐 + 冲突劝退见 [`docs/usage.md` §6](docs/usage.md)。

## 延伸阅读

- [`docs/roundtable.md`](docs/roundtable.md) —— 架构总览
- [`docs/usage.md`](docs/usage.md) —— 完整使用指南
- [`CHANGELOG.md`](CHANGELOG.md) —— 版本历史
- [`CONTRIBUTING.md`](CONTRIBUTING.md) —— 如何贡献

## 许可

[Apache-2.0](LICENSE)
