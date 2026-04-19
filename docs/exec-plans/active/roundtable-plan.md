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
> **当前进度**：P0 → P4 已完成；下一步 P5 外部试装（或先做 P4 反馈的 top 3 plugin 改进）

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
- [x] 建内部文档目录：`docs/analyze/` `docs/design-docs/` `docs/exec-plans/active/` `docs/exec-plans/completed/` `docs/testing/` `docs/reviews/`（各带 .gitkeep，已 dogfood plugin 自身的产出契约分层）
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

### 前置：原型归档隔离

P1 开工前，已将原型实现（成熟的本地多角色 agent 定义）从 Claude Code 自动发现路径挪到**归档位置**，避免测试时干扰（可能无前缀调用优先命中原型，让 plugin 的 bug 被静默 fallback 掩盖）。

- 原型归档位置：workspace 下 `.claude-prototype-archive/`（不在 Claude Code 发现路径）
- 作为维护者实现 skill/agent 时的"参考答案"，用于行为对照；但不 commit 进 roundtable
- P4 自消耗验证通过后再决定是否永久删除

### 任务清单

- [x] `plugin.json` 保持**无 userConfig 字段**（D2 B-0 决策）
- [x] 写 `skills/_target-project-detect.md`（共享 skill，供 architect / analyst 等调用）—— 实际落盘为 `skills/_detect-project-context.md`（2026-04-17 refactor 改名，见 log.md）
  - 实现 D9 算法：session 记忆 → `git rev-parse` → 候选池扫描 → 任务描述正则匹配 → AskUserQuestion 兜底
  - 实现工具链检测：扫 `target_project` 根的 `Cargo.toml` / `package.json` / `pyproject.toml` / `go.mod` / `Move.toml`
  - 实现文档路径检测：`docs/` → `documentation/` → AskUserQuestion
  - 返回结构化结果给上层 skill 使用
- [x] 写 `skills/architect.md`
  - frontmatter：`name: architect`，**不声明 `tools`**（skill 自动继承主会话工具，含 AskUserQuestion）
  - 开工第一件事：调用 `_target-project-detect` 拿到 target_project 和工具链
  - 路径占位符：`{target_project}/{docs_root}/design-docs/[slug].md`
  - 约束：业务规则 / 设计参考 / critical_modules 一律从 `target_project/CLAUDE.md` 的「# 多角色工作流配置」section 读取，skill prompt 里不含任何语言 / 业务 / 项目特定术语
  - 保留三阶段工作流（探索 → 决策弹窗 → 落盘 → 用户审阅 → 按需 exec-plan）
  - 保留 AskUserQuestion 强制规则（决策点必须弹窗，不得文字提问）
- [x] 写 `commands/workflow.md`
  - 编排逻辑区分两种派发：interactive role 通过 Skill 工具激活；autonomous role 通过 Task 工具派发
  - P1 阶段仅实现到 architect skill 激活；后续 developer/tester 派发在 P2 补齐
  - 所有技术栈判断委托给 `_target-project-detect` skill
- [x] 本地开发验收（两种启动方式都测）
  - **方式 A**：从 workspace 根目录启动（非 git）
    - `cd <workspace> && claude --plugin-dir <workspace>/roundtable`
    - 触发 `/roundtable:workflow 设计 <project> 的 <topic>`
    - 验收：D9 正则命中或 AskUserQuestion 弹窗，识别 target_project
  - **方式 B**：从项目目录启动（git 仓库内）
    - `cd <workspace>/<project> && claude --plugin-dir <workspace>/roundtable`
    - 触发 `/roundtable:workflow 设计 <topic>`
    - 验收：`git rev-parse` 短路识别，不弹 D9
- [x] 验收清单（方式 A + B 均完成）
  - [x] 安装过程零弹窗（D2 B-0）
  - [x] D9 识别机制在方式 A（workspace 根启动）下工作（2026-04-17 smoke）
  - [x] architect skill 激活后 AskUserQuestion **真的弹决策窗**（2026-04-17 smoke + 2026-04-18 gleanforge P4 多轮复验）
  - [x] design-doc 落到正确路径（P4 gleanforge `docs/design-docs/mvp-foundation.md`）
  - [x] 加载了 target_project 的 CLAUDE.md（P4 中 critical_modules 触发 tester，设计参考体现在 DEC 阐释）
  - [x] 工具链自动检测正确（P4 识别 pnpm + Node 20 + TS strict ESM + vitest + tsx）
  - [x] 方式 B（从子项目内启动，`git rev-parse` 短路）（2026-04-18 gleanforge 从 `/data/rsw/gleanforge` 内启动验证）

### 成功信号
- [x] 零 userConfig 弹窗，装完立即可用（P4 实测）
- [x] D9 target_project 识别在两种启动场景下准确（方式 A + B 均验证）
- [x] AskUserQuestion 决策弹窗真实弹出（P4 analyst / architect 均弹了真窗）
- [x] `skills/architect.md` 和 `commands/workflow.md` 无任何语言 / 业务 / 项目特定硬编码（grep 验证：feature/p4-dogfood-improvements 分支 commit `8981a0d` 后 0 命中）

### 风险与预案

| 风险 | 预案 |
|------|------|
| Skill → Skill 调用（`_target-project-detect` 被 architect 调）不符合预期 | 先跑 Claude Code 官方文档的 Skill 示例验证；不行则把 detect 逻辑内联到每个角色 prompt |
| D9 正则匹配误判（任务里提到 A 项目实际想操作 B 项目） | 命中后仍用 AskUserQuestion 二次确认；session 记忆生效后跳过 |
| Skill 激活后行为不可预期 | 官方文档的 hello-world skill 先跑通，再移植 architect |
| CLAUDE.md 里声明的工具链命令与自动检测冲突 | 以 CLAUDE.md 为准（显式 > 隐式），skill 里明确这个优先级 |

---

## P2 批量通用化其余角色（2026-04-17 已完成）

### 目标
通用化剩余 5 个角色 + 2 个命令，使 workflow 全链路可跑。

### 任务清单

- [x] `skills/analyst.md`（交互式，六问框架 + 研究中 AskUserQuestion 澄清；开放问题清单"事实层"纪律）
- [x] `agents/developer.md`（plan-then-code；工具链靠 target_project 根文件自动检测 + CLAUDE.md 覆盖；上下文变量由调度方注入）
- [x] `agents/tester.md`（对抗性 / E2E / benchmark；critical_modules 触发条件从注入变量读）
- [x] `agents/reviewer.md`（代码审查 + 决策一致性对照 decision-log；按 critical_modules 决定是否落盘 reviews）
- [x] `agents/dba.md`（DB schema / SQL / 迁移审查；支持 PG / MySQL / SQLite 等多种 DB 类型自动识别）
- [x] `commands/bugfix.md`（跳过 design 阶段，强制回归测试，发现设计缺陷即中止转 /workflow）
- [x] `commands/lint.md`（8 项文档健康检查，纯只读报告）
- [x] `commands/workflow.md` 的派发编排：P1 版本已包含完整的 skill 激活 + agent 派发逻辑，P2 无需新增（仅在 P4 真实使用时如有不足再调整）
- [x] 在真实项目里端到端跑一次 `/roundtable:workflow`，全角色链路触发（2026-04-18 P4 gleanforge 完成）

### 成功信号
- [x] 全 7 个角色 + 3 个命令通用化完成（2026-04-17 落盘）
- [x] `grep` 验证：`skills/` `agents/` `commands/` 下 0 命中任何语言 / 业务特定关键词（2026-04-19 commit `8981a0d` 后再次 0 命中）
- [x] 端到端跑通：architect skill 决策弹窗 → developer agent 写代码 → tester agent 跑测试 → reviewer agent 审查（2026-04-18 gleanforge P4，全角色链路真实触发，9 次 subagent 派发含 3 次并行）

### 风险与预案

| 风险 | 预案 |
|------|------|
| Skill 激活后派发 Agent 的行为与设计预期不符 | P2 开工第一天用 architect skill → 手动派发 developer agent 验证；若不行降级为"主会话在 skill 结束后根据残留 context 派发" |
| Agent 在 subagent 里读不到项目 CLAUDE.md | 派发 agent 时在 prompt 里显式注入 target_project CLAUDE.md 内容片段 |

---

## P3 文档 + 模板 + onboarding（2026-04-17 已完成）

### 目标
让任何新用户 5 分钟跑通首次工作流。

### 任务清单

- [x] 写 `docs/claude-md-template.md`（完整模板 + 填写提示 + FAQ + 最小可用示例，139 行）
- [x] 写 `docs/onboarding.md`（5 分钟上手，安装 → 配置 → 首次跑，含常见问题，125 行）
- [x] 写 `docs/migration-from-local.md`（5 步迁移 runbook + 3 个常见坑 + 回归测试 checklist，139 行）
- [x] 写 `examples/rust-backend-snippet.md`（Rust 后端 / CLI，80 行）
- [x] 写 `examples/ts-frontend-snippet.md`（TS + React 前端，89 行）
- [x] 写 `examples/python-datapipeline-snippet.md`（Python 数据管道 / ML，93 行）
- [x] 更新 `docs/INDEX.md`（把 P3 新文件链上）
- [x] 完善 README：Quick Start、各角色简介、常见问题、链接到 design.md / onboarding.md（README 已在 P0 完成并已含 Quick Start / 角色表；P3 不需要再改）

### 成功信号
- [x] README 里的安装命令直接复制粘贴能用
- [ ] 挑一个没用过 plugin 的人按 onboarding 5 分钟跑通（放到 P5 外部试装一起做）

---

## P4 自消耗闭环（2026-04-18 已完成）

### 目标
挑一个真实项目完整走一遍安装 → 配置 → 工作流，作为最小回归。

### 任务清单

- [x] 选定自消耗目标项目：**gleanforge**（TS 栈、AI + Web3 每日资讯聚合工具，全新绿地项目）
- [x] 在项目根用 `--plugin-dir /data/rsw/roundtable` 过渡加载（marketplace install 留到 P6）
- [x] 按 `docs/claude-md-template.md` 给 gleanforge CLAUDE.md 追加「# 多角色工作流配置」section
  - `## critical_modules`（数据源认证 / 去重 / LLM prompt / 调度器）
  - `## 设计参考`（tldr.tech / The Batch / Feedly / Dune Spellbook）
  - `## 工具链覆盖`（P0.1 developer 回填：pnpm 9.15 / Node 20 / TS strict ESM / vitest / tsx）
  - `## 条件触发规则`（API token / sources/* / LLM prompt / 垂类新增 / 去重触碰）
- N/A 本地 `.claude/` agent 冲突 —— gleanforge 是绿地项目无同名文件
- [x] 跑真实需求 `/roundtable:workflow 设计 gleanforge MVP ...` —— 产出完整 design-doc / DEC-001..007 / analyze / exec-plan / testing/plan / review / 代码 50 文件 / 242 tests
- [x] 记录偏差反馈到 bug 列表 —— 产出 `docs/testing/p4-self-consumption.md`
- N/A `.claude.backup/` 清理 —— 无备份需要
- [ ] gleanforge 首次 commit + PR —— 推迟（等用户主动，符合 `feedback_no_auto_push` 约束）

### 成功信号
- [x] 目标项目用 roundtable 做的需求，design-doc / decision-log / log.md 落盘位置 / 格式全部正确（gleanforge/docs/ 完整 roundtable 分层）
- [x] 项目 CLAUDE.md 新增的 section 被 architect skill 正确读取（critical_modules 触发 tester 生效；设计参考体现在 DEC 阐释；条件触发规则被 developer/tester 遵守）

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
- 2026-04-18 P4 自消耗闭环完成：gleanforge 项目从零 build 到 MVP（P0.1-P0.7 + tester + reviewer + dry-run smoke），242 tests 全绿；产出 `docs/testing/p4-self-consumption.md` 观察报告，识别 3 条 top 改进（共享资源协议 / agent→orchestrator 决策协议 / workflow command checklist 化）；gleanforge 首次 commit + PR 推迟（用户主动）
- 2026-04-19 基于 P4 反馈落地三项增量改进（见 DEC-002）+ 回填 P1 / P2 历史 checkbox（方式 B / design-doc 落盘 / CLAUDE.md 加载 / 工具链检测 / grep 0 命中 / 端到端链路 —— 均由 P4 gleanforge 实证）。改进落在 feature 分支 `feature/p4-dogfood-improvements`：commits `02befbf` Resource Access matrix / `066f2a8` Escalation Protocol + Option Schema / `c9c5559` Phase Matrix + inline _detect / `85ecf38` DEC-002 / `309254b` CHANGELOG / `8981a0d` de-hardcode / `c02767d` flatten `docs/testing/` / 本条
