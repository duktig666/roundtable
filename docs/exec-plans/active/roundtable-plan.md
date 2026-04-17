---
slug: roundtable
source: docs/design-docs/roundtable.md
created: 2026-04-17
updated: 2026-04-17
status: Active
decisions: [DEC-001]
---

# roundtable Plugin 执行计划

> 本计划展开自 design-doc `docs/design-docs/roundtable.md` §7 分阶段路线（D6 POC 增量策略）
> **当前进度**：P0 已完成；下一步 P1

---

## 总览

| Phase | 标题 | 预估 | 前置 | 关键风险 |
|-------|------|-----|------|---------|
| P0 | 建仓与骨架 | 0.5 天 | GitHub 公开仓库创建权 | — |
| P1 | POC：architect skill + /workflow command | 1.5 天 | P0 完成；本地 Claude Code 支持 `--plugin-dir` | Skill 机制实测与官方文档一致性 |
| P2 | 批量通用化其余角色 | 2 天 | P1 链路跑通 | Skill / Agent 在同一 plugin 的协作实测 |
| P3 | 文档 + 模板 + onboarding | 0.5 天 | P2 内容稳定 | 模板对多种项目类型的覆盖度 |
| P4 | 自消耗闭环 | 0.5 天 | P3 完成 | 用户项目本地 `.claude/` override 冲突 |
| P5 | 外部试装 | 0.5 天 | P4 成功 | 外部用户反馈周期 |
| P6 | v0.1 发布 | 0.5 天 | P5 通过 | 发布后安装命令须稳定 |
| **合计** | | **~6 天** | | |

---

## P0 建仓与骨架（已完成）

### 目标
建一个可安装但内容尚未通用化的 plugin 骨架，落盘设计文档与执行计划。

### 任务清单

- [x] 创建 GitHub 公开仓库 `duktig666/roundtable`（Apache-2.0）
- [x] 本地 clone 到 `<workspace>/roundtable/`
- [x] 配置 SSH（`id_duktig666` + ssh/config alias + gitconfig includeIf）
- [x] 初始化 plugin manifest：`.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`
- [x] 建占位目录：`skills/` `agents/` `commands/` `hooks/` `examples/`（各带 .gitkeep）
- [x] 建内部文档目录：`docs/analyze/` `docs/design-docs/` `docs/exec-plans/active/` `docs/exec-plans/completed/` `docs/testing/plans/` `docs/reviews/`（各带 .gitkeep，已 dogfood plugin 自身的产出契约分层）
- [x] 落盘 `docs/design-docs/roundtable.md` / `docs/exec-plans/active/roundtable-plan.md`（本文件）/ `docs/decision-log.md`（DEC-001）/ `docs/log.md`（时间索引）/ `docs/INDEX.md`（文档导航）
- [x] 基础治理文件：README.md / LICENSE（Apache-2.0）/ CHANGELOG.md / CONTRIBUTING.md / .gitignore
- [x] 首次 commit + push

### 成功信号
- [x] `duktig666/roundtable` 公开可见，LICENSE 为 Apache-2.0
- [x] 仓库目录结构完整（skills / agents / commands / docs 分层清晰）
- [ ] 冒烟验证：`/plugin marketplace add duktig666/roundtable` + `/plugin install roundtable@roundtable --scope user` 在 Claude Code 里能跑完（即使角色文件都空）—— 可放到 P1 开工时顺带做

---

## P1 POC：architect skill + /workflow command

### 目标
通用化最复杂的角色（architect，含三阶段 + AskUserQuestion）和主编排命令（/workflow），端到端验证 **D2 B-0 + D8 skill 形态 + D9 target_project 识别** 链路。

### 任务清单

- [ ] `plugin.json` 保持**无 userConfig 字段**（D2 B-0 决策）
- [ ] 写 `skills/_target-project-detect.md`（共享 skill，供 architect / analyst 等调用）
  - 实现 D9 算法：session 记忆 → `git rev-parse` → 候选池扫描 → 任务描述正则匹配 → AskUserQuestion 兜底
  - 实现工具链检测：扫 `target_project` 根的 `Cargo.toml` / `package.json` / `pyproject.toml` / `go.mod` / `Move.toml`
  - 实现文档路径检测：`docs/` → `documentation/` → AskUserQuestion
  - 返回结构化结果给上层 skill 使用
- [ ] 写 `skills/architect.md`
  - frontmatter：`name: architect`，**不声明 `tools`**（skill 自动继承主会话工具，含 AskUserQuestion）
  - 开工第一件事：调用 `_target-project-detect` 拿到 target_project 和工具链
  - 路径占位符：`{target_project}/{docs_root}/design-docs/[slug].md`
  - 约束：业务规则 / 设计参考 / critical_modules 一律从 `target_project/CLAUDE.md` 的「# 多角色工作流配置」section 读取，skill prompt 里不含任何语言 / 业务 / 项目特定术语
  - 保留三阶段工作流（探索 → 决策弹窗 → 落盘 → 用户审阅 → 按需 exec-plan）
  - 保留 AskUserQuestion 强制规则（决策点必须弹窗，不得文字提问）
- [ ] 写 `commands/workflow.md`
  - 编排逻辑区分两种派发：interactive role 通过 Skill 工具激活；autonomous role 通过 Task 工具派发
  - P1 阶段仅实现到 architect skill 激活；后续 developer/tester 派发在 P2 补齐
  - 所有技术栈判断委托给 `_target-project-detect` skill
- [ ] 本地开发验收（两种启动方式都测）
  - **方式 A**：从 workspace 根目录启动（非 git）
    - `cd <workspace> && claude --plugin-dir <workspace>/roundtable`
    - 触发 `/roundtable:workflow 设计 <project> 的 <topic>`
    - 验收：D9 正则命中或 AskUserQuestion 弹窗，识别 target_project
  - **方式 B**：从项目目录启动（git 仓库内）
    - `cd <workspace>/<project> && claude --plugin-dir <workspace>/roundtable`
    - 触发 `/roundtable:workflow 设计 <topic>`
    - 验收：`git rev-parse` 短路识别，不弹 D9
- [ ] 验收清单
  - [ ] 安装过程零弹窗（D2 B-0）
  - [ ] D9 识别机制在两种启动方式下都正确
  - [ ] architect skill 激活后 AskUserQuestion **真的弹决策窗**（不是文字问）
  - [ ] design-doc 落到正确路径 `<target_project>/<docs_root>/design-docs/<slug>.md`
  - [ ] 加载了 target_project 的 CLAUDE.md（体现在决策阐释引用到业务规则）
  - [ ] 工具链自动检测正确（Rust → `cargo` 相关；JS → `pnpm` / `npm` 相关等）

### 成功信号
- [ ] 零 userConfig 弹窗，装完立即可用
- [ ] D9 target_project 识别在两种启动场景下准确
- [ ] AskUserQuestion 决策弹窗真实弹出（验证 D8 决策）
- [ ] `skills/architect.md` 和 `commands/workflow.md` 无任何语言 / 业务 / 项目特定硬编码（grep 验证）

### 风险与预案

| 风险 | 预案 |
|------|------|
| Skill → Skill 调用（`_target-project-detect` 被 architect 调）不符合预期 | 先跑 Claude Code 官方文档的 Skill 示例验证；不行则把 detect 逻辑内联到每个角色 prompt |
| D9 正则匹配误判（任务里提到 A 项目实际想操作 B 项目） | 命中后仍用 AskUserQuestion 二次确认；session 记忆生效后跳过 |
| Skill 激活后行为不可预期 | 官方文档的 hello-world skill 先跑通，再移植 architect |
| CLAUDE.md 里声明的工具链命令与自动检测冲突 | 以 CLAUDE.md 为准（显式 > 隐式），skill 里明确这个优先级 |

---

## P2 批量通用化其余角色

### 目标
通用化剩余 5 个角色 + 2 个命令，使 workflow 全链路可跑。

### 任务清单

- [ ] `skills/analyst.md`（交互式，六问框架 + 研究中 AskUserQuestion 澄清）
  - 占位符化 docs_root，去除所有业务术语
  - 保留：六问框架、开放问题清单的"事实层"纪律
- [ ] `agents/developer.md`
  - frontmatter 声明 `tools`（developer 需要 Read / Edit / Write / Bash）
  - 去除所有语言 / 技术栈硬编码，改为读 target_project 的 CLAUDE.md 工具链覆盖或自动检测
  - 保留：plan-then-code 纪律、TDD 开启测试先写
- [ ] `agents/tester.md`
  - 关键模块触发条件从"读 CLAUDE.md 的 critical_modules section"动态获取
  - 对抗性测试 + E2E + benchmark 的方法论保留；具体框架命令靠检测
- [ ] `agents/reviewer.md`
  - 通用代码审查规则
  - 关键模块 / 安全敏感判断从 CLAUDE.md 读
- [ ] `agents/dba.md`
  - 通用 DB schema / migration 审查
  - 特定 DB 类型（PG / MySQL / ...）从 target_project 自动检测
- [ ] `commands/bugfix.md`（Bug 修复工作流，跳过 design 阶段）
- [ ] `commands/lint.md`（项目文档健康检查，通用程度高，改造点最少）
- [ ] 补全 `commands/workflow.md` 的"派发 agent"编排逻辑（P1 只走到 architect skill；P2 补齐 developer/tester/reviewer/dba 派发；派发时注入 target_project 变量）
- [ ] 在一个真实项目里端到端跑一次 `/roundtable:workflow`，全角色链路触发

### 成功信号
- [ ] 全 7 个角色 + 3 个命令通用化完成
- [ ] `grep` 验证：`skills/` `agents/` `commands/` 下 0 命中任何语言 / 业务特定关键词
- [ ] 端到端跑通：architect skill 决策弹窗 → developer agent 写代码 → tester agent 跑测试 → reviewer agent 审查

### 风险与预案

| 风险 | 预案 |
|------|------|
| Skill 激活后派发 Agent 的行为与设计预期不符 | P2 开工第一天用 architect skill → 手动派发 developer agent 验证；若不行降级为"主会话在 skill 结束后根据残留 context 派发" |
| Agent 在 subagent 里读不到项目 CLAUDE.md | 派发 agent 时在 prompt 里显式注入 target_project CLAUDE.md 内容片段 |

---

## P3 文档 + 模板 + onboarding

### 目标
让任何新用户 5 分钟跑通首次工作流。

### 任务清单

- [ ] 写 `docs/claude-md-template.md`（完整可抄模板，空槽位让用户按项目填）
- [ ] 写 `docs/onboarding.md`
  ```
  1. /plugin marketplace add duktig666/roundtable
  2. /plugin install roundtable@roundtable --scope user（零弹窗）
  3. 在项目 CLAUDE.md 追加「# 多角色工作流配置」section（抄模板改）
  4. /roundtable:workflow <你的任务>
  ```
- [ ] 写 `docs/migration-from-local.md`（给原来在项目本地 `.claude/` 定义了 agent/command 的用户）
- [ ] 写 `examples/` 下典型项目类型的片段
  - `examples/rust-backend-snippet.md`
  - `examples/ts-frontend-snippet.md`
  - `examples/python-datapipeline-snippet.md`
  - （其他按需追加）
- [ ] 完善 README：Quick Start、各角色简介、常见问题、链接到 design.md / onboarding.md

### 成功信号
- [ ] 挑一个没用过 plugin 的人按 onboarding 5 分钟跑通
- [ ] README 里的安装命令直接复制粘贴能用

---

## P4 自消耗闭环

### 目标
挑一个真实项目完整走一遍安装 → 配置 → 工作流，作为最小回归。

### 任务清单

- [ ] 选定自消耗目标项目（推荐挑 v0.1 设计者自己最熟悉的那个）
- [ ] 在项目根跑 `/plugin install roundtable@roundtable --scope user`（或 `--plugin-dir` 过渡）
- [ ] 按 `docs/claude-md-template.md` 给该项目的 CLAUDE.md 追加「# 多角色工作流配置」section，按实际填
  - `## critical_modules`
  - `## 设计参考`
  - `## 工具链覆盖`（若自动检测不够精细）
  - `## 条件触发规则`（按业务填）
- [ ] 若项目本地 `.claude/` 下有同名 agent / command，`git mv` 到 `.claude.backup/` 保底（避免 override plugin）
- [ ] 跑一个真实需求 `/roundtable:workflow <需求>` —— 产出 design-doc / decision-log / log.md 条目 / 代码改动
- [ ] 记录任何与预期不符的行为，反馈到 bug 列表
- [ ] 回归确认无问题后删 `.claude.backup/`
- [ ] 提交项目 PR："Integrate roundtable plugin for multi-role workflow"

### 成功信号
- [ ] 目标项目用 roundtable 做的需求，design-doc / decision-log / log.md 落盘位置 / 格式全部正确
- [ ] 项目 CLAUDE.md 新增的 section 被 architect skill 正确读取（体现在决策阐释引用到业务规则）

### 风险与预案

| 风险 | 预案 |
|------|------|
| plugin 和本地 `.claude/` agent 同名冲突 | 本地重命名到 `.claude.backup/`；或删除本地文件由 plugin 接管 |
| 团队其他成员不知道要装 plugin | 项目 PR 描述写清迁移步骤；把 `claude --plugin-dir ...` 或 install 命令写入项目 Makefile / README |

---

## P5 外部试装

### 目标
找一位未参与设计的开发者独立完成安装和首次使用，收集盲区反馈。

### 任务清单

- [ ] 选定外部试装者（建议：跟 v0.1 设计完全无关的同事，最好项目栈也不同）
- [ ] 给他 README 链接，不做额外解释，观察他的步骤
- [ ] 记录所有困惑点、卡点、耗时异常点
- [ ] 按反馈修 bug / 补文档
- [ ] 更新 CHANGELOG

### 成功信号
- [ ] 外部试装者 1 小时内完成配置并成功跑通一次 `/workflow`
- [ ] 至少收集到一条 non-trivial 反馈并处理

---

## P6 v0.1 发布

### 任务清单

- [ ] P5 反馈全部处理
- [ ] 最终端到端验收（自消耗 + 外部试装都通过）
- [ ] CHANGELOG 添加 `v0.1.0` 正式版条目
- [ ] 打 `v0.1.0` tag 和 GitHub Release
- [ ] README 首页安装命令切为 `/plugin marketplace add duktig666/roundtable`（不再依赖 `--plugin-dir`）
- [ ] （可选）公告给团队 / 社区

### 成功信号
- [ ] `v0.1.0` 出现在 GitHub Releases
- [ ] 远程 install 路径可用（非维护者也能装上并跑）

---

## 跨阶段约束

- 每个 Phase 完成在 `docs/log.md` 顶部 append 一条（前缀 `design` / `refactor` 等合适的）
- Commit message 用英文，遵循 `type: short description`（type: feat/fix/docs/refactor/chore/test）
- PR 描述用英文
- skill / agent / command prompt 文件本体用英文为主 + 关键注释中文；但最终文档（design-doc / decision-log / log.md）保持中文

---

## 变更记录

- 2026-04-17 创建；确认 D1-D9 九项决策；P0 已完成（建仓 + 骨架 + 设计文档 + 决策日志）
