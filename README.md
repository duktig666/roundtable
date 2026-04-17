# roundtable

> **一张圆桌，把分析师、架构师、开发、测试、审查、DBA 请到同一个 Claude Code 会话里，用 plan-then-execute 的纪律逐步推进复杂需求。**

`roundtable` 是一个 [Claude Code](https://code.claude.com) plugin，把一套成熟的多角色 AI 开发工作流打包成"一行命令装完即用"的形态。

```bash
/plugin marketplace add duktig666/roundtable
/plugin install roundtable@roundtable --scope user
# 零弹窗，秒装完
```

装完即可在任意项目里用：

```bash
/roundtable:workflow 设计 funding-rate 功能
/roundtable:bugfix 修复 Issue #123
/roundtable:lint
```

---

## 为什么叫 roundtable

> 亚瑟王的圆桌骑士制度有个精髓 —— **没有主位，每位骑士平等地围坐议事，用各自的专长共同做出决策**。

这个 plugin 做的正是这件事：

- **Analyst**（分析师）先把需求的痛点、竞品、失败模式、6 个月后评价想清楚
- **Architect**（架构师）拿 analyst 的产出做设计 —— 关键决策用 `AskUserQuestion` 弹窗让你逐个点选，不是单方面推方案
- **Developer**（开发）在架构确定后才动手，用 plan-then-execute 纪律先出实现计划再写代码
- **Tester**（测试）对关键模块做对抗性测试和 benchmark，不是应付式的单元测试
- **Reviewer / DBA**（代码 / 数据库审查）关键模块必过一眼

你不是听一个 Claude 自说自话，而是在主持一场圆桌讨论。

---

## 设计原则

1. **零配置安装** —— plugin.json 没有 `userConfig` 弹窗，运行时自动检测工具链（Cargo.toml / package.json / pyproject.toml / go.mod / Move.toml），项目业务规则通过各项目自己的 `CLAUDE.md` 自描述
2. **Plan-then-execute** —— architect 出设计要用户确认再落盘，落盘后再写 exec-plan；developer 中大任务先出实现方案再编码；tester 关键模块先出测试计划再写测试
3. **决策逐点弹窗** —— architect 遇到关键决策点立即 `AskUserQuestion` 让用户点选，不堆砌成文字列表最后一次性问
4. **交互式 role 用 skill，自主执行 role 用 agent** —— architect/analyst 是 skill（主会话运行，AskUserQuestion 可用），developer/tester/reviewer/dba 是 agent（subagent 隔离上下文，避免主会话污染）
5. **多项目原生支持** —— 根目录启动 Claude Code 时自动识别目标项目（git repo 扫描 + 任务描述正则匹配 + AskUserQuestion 兜底）

---

## 快速上手（5 分钟）

### 1. 安装 plugin

```bash
/plugin marketplace add duktig666/roundtable
/plugin install roundtable@roundtable --scope user
```

### 2. 在项目的 `CLAUDE.md` 里加配置 section

```markdown
# 多角色工作流配置

## critical_modules（tester / reviewer 必触发）
- <你项目里"改错了会出大事"的关键模块>

## 设计参考
- <你的项目对标什么产品、参考什么框架>

## 工具链覆盖（可选，默认走自动检测）
- lint: <你项目的 lint 命令>
- test: <你项目的 test 命令>

## 条件触发规则（可选）
- <涉及 X → 必须 Y 的业务规则>
```

完整模板见 [`docs/claude-md-template.md`](docs/claude-md-template.md)（P3 阶段产出）。

### 3. 跑起来

```bash
# 在项目内或根目录 workspace 都行
claude
> /roundtable:workflow 设计一个 XXX 功能

# roundtable 会：
#  1. 识别目标项目（根目录启动时自动扫 .git/ 子目录 + 匹配任务描述 → AskUserQuestion 兜底）
#  2. 检测技术栈（读 Cargo.toml / package.json 等）
#  3. 加载你项目的 CLAUDE.md 业务规则
#  4. 激活 architect skill，决策点逐个 AskUserQuestion 弹窗让你点选
#  5. 落盘 design-doc → 你审阅 → 派发 developer agent 写代码 → tester agent 跑测试 → reviewer agent 审查
```

---

## 角色清单

| 角色 | 形态 | 干什么 | 什么时候触发 |
|------|------|-------|------|
| `@roundtable:analyst` | Skill | 调研、六问框架、事实 vs 推论 | 需求不清晰时 |
| `@roundtable:architect` | Skill | 三阶段：决策弹窗 → 落盘 design-doc → 按需 exec-plan | 新功能 / 重大重构 |
| `@roundtable:developer` | Agent | plan-then-code、TDD、多技术栈 | 架构确定后 |
| `@roundtable:tester` | Agent | 对抗性测试、E2E、benchmark | 关键模块 / 性能敏感路径 |
| `@roundtable:reviewer` | Agent | 代码审查、设计一致性 | 关键模块合并前 |
| `@roundtable:dba` | Agent | PG schema、迁移、索引策略 | 涉及数据库变更 |

## 命令清单

| 命令 | 用途 |
|------|-----|
| `/roundtable:workflow <任务>` | 按任务规模自动编排 agent 协作（小 / 中 / 大三档） |
| `/roundtable:bugfix <issue>` | Bug 定位和修复，跳过 design 阶段 |
| `/roundtable:lint` | 项目文档健康检查（断链、孤儿、决策不一致） |

---

## 贡献

欢迎提 Issue、PR。贡献者本地开发模式见 [CONTRIBUTING.md](CONTRIBUTING.md)。

- 提 PR 之前读一下 [`docs/design-docs/roundtable.md`](docs/design-docs/roundtable.md)，了解 D1-D9 决策脉络，避免提出已被评估过否决的方案
- 文档导航见 [`docs/INDEX.md`](docs/INDEX.md)
- 涉及决策变更的 PR 请在 `docs/decision-log.md` 加 DEC-xxx 条目，列明备选和理由

---

## 许可证

Apache-2.0 — 详见 [LICENSE](LICENSE)

---

## 致谢

- 原型来自 [`/data/rsw/.claude/`](https://github.com/duktig666/roundtable)（dex-sui 工作流的演化版本）
- 六问框架借鉴自 gstack 的 office-hours 实践
- 文档三件套（design-docs + decision-log + log）机制参考 Karpathy LLM Wiki 的"Raw Source → Wiki → Schema"分层
