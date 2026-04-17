---
slug: roundtable
source: docs/design-docs/roundtable.md
created: 2026-04-17
updated: 2026-04-17
status: Active
decisions: [DEC-001]
migrated_from: dex-sui/docs/exec-plans/active/moongpt-harness-plugin-plan.md @ 2026-04-17
---

# roundtable Plugin 执行计划

> 本计划展开自 design-doc `docs/design-docs/roundtable.md` 的 §7 分阶段路线（D6 POC 增量策略）
> **当前进度**：P0 基本完成（建仓、骨架、文档迁入 + dogfooding 重构、首次 commit + push）；下一步 P1 POC

---

## 总览

| Phase | 标题 | 预估 | 前置 | 关键风险 |
|-------|------|-----|------|---------|
| P0 | 建仓与骨架 | 0.5 天 | duktig666 组织权限；GitHub 公开仓库创建权 | 组织账号权限申请阻塞 |
| P1 | POC：architect skill + /workflow command | 1.5 天 | P0 完成；本地 Claude Code 支持 `--plugin-dir` | userConfig 字段命中率实测 |
| P2 | 批量改其余角色 | 2 天 | P1 链路跑通 | Skills 与 Agents 在同 plugin 的实际协作（尤其 Skill 调 Task 工具派发 Agent 的真实行为） |
| P3 | 文档 + 模板 + onboarding | 0.5 天 | P2 内容稳定 | claude-md-template.md 是否覆盖非 DEX 场景 |
| P4 | dex-sui 自消耗闭环 | 0.5 天 | P3 完成 | plugin 与 dex-sui 本地 `.claude/` override 冲突 |
| P5 | 首个外部试装 | 0.5 天 | P4 成功 | 外部用户反馈周期 |
| P6 | v0.1 发布 | 0.5 天 | P5 通过 | 发布后不可逆（install 命令需稳定） |
| **合计** | | **6 天** | | |

---

## P0 建仓与骨架（2026-04-17 执行中）

### 目标
在 `duktig666/roundtable` 建一个可安装但内容未通用化的 plugin 骨架；把 design-doc 和 exec-plan 从 dex-sui 迁到 plugin 仓库。

### 任务清单

- [x] duktig666 个人账号创建公开仓库 `roundtable`（Apache-2.0 将在首次 commit 加入 LICENSE）
- [x] 本地 clone 到 `/data/rsw/roundtable/`
- [x] 配置 SSH（`~/.ssh/id_duktig666` + `~/.ssh/config` alias + `~/.gitconfig-duktig666` + includeIf）
- [x] 初始化目录结构 + dogfooding 重构：
  ```
  .claude-plugin/plugin.json / marketplace.json
  skills/ agents/ commands/ hooks/ examples/ 下 .gitkeep
  docs/design-docs/roundtable.md               ← 从 dex-sui 迁入（dogfood slug 分层）
  docs/exec-plans/active/roundtable-plan.md    ← 从 dex-sui 迁入（本文件）
  docs/exec-plans/completed/.gitkeep           ← 预留
  docs/analyze/.gitkeep                        ← 预留
  docs/testing/plans/.gitkeep                  ← 预留
  docs/reviews/.gitkeep                        ← 预留
  docs/decision-log.md                         ← DEC-001
  docs/log.md                                  ← 新建（时间索引）
  docs/INDEX.md                                ← 全文档导航
  README.md / LICENSE(Apache-2.0) / CHANGELOG.md / CONTRIBUTING.md / .gitignore
  ```
- [x] **从 dex-sui 删除**：
  - `docs/design-docs/moongpt-harness-plugin.md`
  - `docs/exec-plans/active/moongpt-harness-plugin-plan.md`
- [x] 更新 dex-sui DEC-010 的"相关文档"字段指向 https://github.com/duktig666/roundtable
- [x] 更新 dex-sui `docs/log.md` 追加 migrate 索引条目
- [x] 首次 commit `feat: initialize roundtable plugin repository` + push 到 `origin/main`
- [x] dogfooding 重构 commit（本次）
- [ ] 安装验收：`/plugin marketplace add duktig666/roundtable` + `/plugin install roundtable@roundtable --scope user` 能跑完（即使 agents/skills 都空）

### 成功信号
- [x] `duktig666/roundtable` 公开可见，LICENSE 为 Apache-2.0
- [x] `/data/rsw/dex-sui/docs/design-docs/` 下不再有 `moongpt-harness-plugin.md`
- [x] dex-sui log.md 有"迁出"索引条目（`migrate | roundtable plugin docs 迁出 dex-sui | 2026-04-17`）
- [ ] dex-sui 本地用 `/plugin install` 或 `--plugin-dir` 能装上（待 P1 验证时一并做）

### 风险与预案
| 风险 | 预案 |
|------|------|
| SSH push 权限问题 | 已用 `~/.ssh/id_duktig666` + GitHub pubkey 配置并验证通过 |
| 迁移时 design-doc 内链断裂 | 本批迁移仅用 sed 批量改 `moongpt-harness → roundtable`、`chainupcloud → duktig666`；人工校对 D1 / 目录结构 / frontmatter |
| Plugin install 实测失败 | dex-sui 本地用 `--plugin-dir /data/rsw/roundtable` 先验证再切 remote install |

---

## P1 POC：architect skill + /workflow command

### 目标
通用化"最复杂"的一个角色（architect，含三阶段 + AskUserQuestion）和一个命令（/workflow，含编排逻辑），验证 **D2 B-0 + D9 target_project 识别 + 根目录启动** 端到端工作。

### 任务清单

- [ ] `plugin.json` 保持**无 userConfig 字段**（D2 B-0 决策）
- [ ] 写 `skills/_target-project-detect.md`（共享 skill，被 architect / analyst 等调用）：
  - 实现 D9 算法：session 记忆 → git rev-parse → candidates 扫描 → 任务描述正则匹配 → AskUserQuestion
  - 实现工具链检测：扫 target_project 根的 Cargo.toml / package.json / pyproject.toml / go.mod / Move.toml
  - 实现文档路径检测：`docs/` → `documentation/` → AskUserQuestion
  - 返回 JSON-like 结构供上层 skill 使用
- [ ] 写 `skills/architect.md`：
  - 从 `/data/rsw/.claude/agents/architect.md` 复制
  - frontmatter：`name: architect`，**不设 `tools`**（skill 继承主会话工具，含 AskUserQuestion）
  - 开工第一件事：调用 `_target-project-detect` skill 获得 target_project + 工具链信息
  - 所有硬编码路径替换：`dex-sui/docs/...` → `{target_project}/{detected_docs_root}/...`
  - 删除 "对标 Hyperliquid，dYdX 仅辅助参考" 等业务术语
  - 加 "读取 target_project/CLAUDE.md 的「# 多角色工作流配置」section 作为业务规则权威源；声明值覆盖检测值"
  - 保留三阶段工作流 + AskUserQuestion 强制规则
- [ ] 写 `commands/workflow.md`：
  - 从 `/data/rsw/.claude/commands/workflow.md` 复制
  - 删掉技术栈分支（`dex-sui/ → cargo` 等），改为"委托 skill 链判断"
  - 编排逻辑区分 skill 和 agent：architect / analyst 激活 skill；developer / tester / reviewer / dba 派发 agent，派发时注入 target_project 变量
- [ ] 本地 dex-sui 开发测试（两种启动方式都要验证）：
  ```bash
  # 方式 A：从根目录启动（主要团队习惯）
  cd /data/rsw
  claude --plugin-dir /data/rsw/roundtable
  # 无弹窗直接装好（D2 B-0）
  # 触发 /roundtable:workflow 设计 dex-sui 的测试主题
  # 验收：D9 从任务描述正则匹配到 "dex-sui"，或 AskUserQuestion 让用户选

  # 方式 B：从子项目内启动
  cd /data/rsw/dex-sui
  claude --plugin-dir /data/rsw/roundtable
  # git rev-parse 直接拿到 dex-sui，跳过 AskUserQuestion
  # 触发 /roundtable:workflow 设计测试主题
  ```
- [ ] 验收项：
  - [ ] 安装过程零弹窗（D2 B-0）
  - [ ] 方式 A：D9 识别机制工作（或 AskUserQuestion 选项框弹出）
  - [ ] 方式 B：git rev-parse 短路识别，不弹 D9
  - [ ] architect skill 激活后 AskUserQuestion **真能弹决策窗**（不是文字问）
  - [ ] design-doc 落到 `/data/rsw/dex-sui/docs/design-docs/<slug>.md`
  - [ ] architect 引用 dex-sui CLAUDE.md 的 critical_modules / 设计参考（通过 target_project/CLAUDE.md 自动加载）
  - [ ] 工具链自动检测到 Rust + cargo xclippy（来自 dex-sui/Cargo.toml）
- [ ] 修 bug 直到 POC 跑通
- [ ] 提交 `v0.1.0-alpha.2` tag

### 成功信号
- [ ] 零 userConfig 弹窗，装完立即可用
- [ ] D9 target_project 识别在根目录启动场景下准确
- [ ] AskUserQuestion 弹窗真的弹出（验证 D8 决策）
- [ ] 零硬编码："dex-sui"、"Hyperliquid"、"cargo" 等字符串不再出现在 `skills/architect.md` 或 `commands/workflow.md` 里

### 风险与预案
| 风险 | 预案 |
|------|------|
| Skill 能否调另一个 Skill（`_target-project-detect`） | 已核实官方文档支持 Skill → Skill；失败则把 detect 逻辑内联到每个角色 prompt |
| D9 正则匹配误判（用户任务里提到 "dex-sui" 但其实想操作 dex-ui） | 匹配后仍用 AskUserQuestion 二次确认（"我识别到 dex-sui，对吗？"），session 记忆生效后跳过 |
| Skill 激活后行为不可预期 | 先跑官方文档的 hello-world skill 确认；再移植 architect |
| CLAUDE.md 里声明的工具链命令与自动检测不一致 | 以 CLAUDE.md 为准（显式 > 隐式），在 skill 里明确这个优先级 |

---

## P2 批量改其余角色

### 目标
通用化剩余 5 个角色 + 2 个命令。

### 任务清单

- [ ] `skills/analyst.md`（从 `/data/rsw/.claude/agents/analyst.md` 移植）
  - 改造：docs_root 占位符、删业务术语（DEX、撮合等）
  - 保留：六问框架、AskUserQuestion 澄清逻辑、开放问题清单"事实层"纪律
- [ ] `agents/developer.md`（从 `/data/rsw/.claude/agents/developer.md` 移植）
  - 改造：lint_cmd / test_cmd 占位符、删 `cargo xclippy` 硬编码、删 `diesel migration` 等技术栈特定规则（移到 CLAUDE.md 期望区）
- [ ] `agents/tester.md`（同理）
  - 改造：关键模块触发条件改为"读 CLAUDE.md 的 critical_modules section"；benchmark 命令占位符化
- [ ] `agents/reviewer.md`（同理）
- [ ] `agents/dba.md`（同理）
- [ ] `commands/bugfix.md`（同理）
- [ ] `commands/lint.md`（同理，文档健康检查逻辑与项目无关，改造点少）
- [ ] 补全 `commands/workflow.md` 的 skill → agent 派发编排逻辑（P1 只搭到 architect，P2 补齐 developer / tester / reviewer / dba 派发）
- [ ] dex-sui `--plugin-dir` 模式端到端跑一次 `/roundtable:workflow 实现一个小功能`，全角色触发
- [ ] 提交 `v0.1.0-alpha.3` tag

### 成功信号
- [ ] 全 7 个角色 + 3 个命令通用化完成
- [ ] grep `dex-sui|hyperliquid|qce|quantums|cargo xclippy|撮合` 在 `skills/` `agents/` `commands/` 下 0 命中
- [ ] 端到端跑通：architect 弹窗 → developer 派发写代码 → tester 派发跑测试 → reviewer 派发审查

### 风险与预案
| 风险 | 预案 |
|------|------|
| Skill 激活后派发 Agent 的行为与预期不符（官方文档说"不能直接调 Task 工具"） | P2 开工第一天用 architect skill → 手动派发 developer agent 验证真实行为；若不行降级为"architect skill 结束后，主 Claude 根据 skill 残留上下文派发" |

---

## P3 文档 + 模板 + onboarding

### 目标
让**任何**新用户在 5 分钟内跑通 /workflow。

### 任务清单

- [ ] 写 `docs/claude-md-template.md`（完整可抄模板，见 design-doc §3.4 的 dex-sui 示例去业务化）
- [ ] 写 `docs/onboarding.md`：
  ```
  1. 装 plugin
  2. 按弹窗填 userConfig（6 项）
  3. 在项目 CLAUDE.md 加「# 多角色工作流配置」（抄 template，改成自己的）
  4. 跑 /roundtable:workflow 实现第一个功能
  ```
- [ ] 写 `docs/migration-from-dex-sui.md`（给 dex-sui 自消耗用）
- [ ] 写 `examples/generic-project-snippet.md`（非 DEX 场景 CLAUDE.md 示例）
- [ ] 写 `examples/dex-sui-snippet.md`（从 dex-sui 当前 CLAUDE.md 提取多角色配置 section）
- [ ] 完善 `README.md`：Install 命令、Quick Start、Link to design.md / onboarding.md
- [ ] 更新 CHANGELOG：`v0.1.0-alpha.3` → `v0.1.0-beta`

### 成功信号
- [ ] 挑一个没用过 plugin 的同事（或测试账号）按 onboarding 5 分钟跑通
- [ ] README 里的 install 命令直接复制能用

---

## P4 dex-sui 自消耗闭环

### 目标
dex-sui 切换到 plugin 模式，原本地 `.claude/agents/` 和 `.claude/commands/` 备份后删除。

### 任务清单

- [ ] 在根目录 `/data/rsw/` 跑 `/plugin install roundtable@roundtable --scope user`（如果 P6 未完成暂用 `--plugin-dir`），零弹窗完成
- [ ] 补 `dex-sui/CLAUDE.md` 的「# 多角色工作流配置」section（完整版，从 `docs/claude-md-template.md` 抄改），内容包括：
  - `## critical_modules`：撮合、清算、资金结算、Keeper、热路径
  - `## 设计参考`：API 对标 Hyperliquid 等
  - `## 工具链覆盖`（可选，默认检测即可）：lint=cargo xclippy 等
  - `## 触发规则`：金额禁浮点等
- [ ] 同样补 `dex-ui/CLAUDE.md`（前端项目的对应 section）
- [ ] `git mv dex-sui/.claude/agents/ dex-sui/.claude/agents.backup/`
- [ ] `git mv dex-sui/.claude/commands/ dex-sui/.claude/commands.backup/`（假设 dex-sui 有本地 commands；若无跳过）
- [ ] 回归测试：跑一次 `/roundtable:workflow 设计 XXX` —— 预期与原本地 agent 行为一致
- [ ] 检查 `/data/rsw/.claude/` **不动**（作为原型参考）
- [ ] 提交 dex-sui PR："Migrate to roundtable plugin (fixes DEC-010 P4)"

### 成功信号
- [ ] dex-sui `/roundtable:workflow` 行为 100% 匹配旧本地 agent（design-doc、decision-log、log.md 流程不变）
- [ ] `.claude/agents.backup/` 和 `.claude/commands.backup/` 存在但不影响运行
- [ ] dex-sui CLAUDE.md 新增「# 多角色工作流配置」section

### 风险与预案
| 风险 | 预案 |
|------|------|
| plugin agent 与 .claude/agents.backup/ 同名冲突（Claude Code 合并规则：user/project > plugin） | 确保 backup 目录名带 `.backup` 后缀，Claude Code 不会识别 |
| dex-sui 用户（团队其他成员）不知道要装 plugin | PR 描述里写清楚迁移步骤；或把 `--plugin-dir` 写入 dex-sui Makefile target |

---

## P5 首个外部试装

### 目标
非 dex-sui 团队成员装一遍，发现"作者视角看不到"的问题。

### 任务清单

- [ ] 挑一个合适的外部用户（建议：dex-ui 团队 or 非 DEX 背景同事）
- [ ] 给他 README link，观察他的步骤
- [ ] 记录所有他的困惑点 / 卡点
- [ ] 修 bug / 补文档
- [ ] 提交 `v0.1.0-rc.1` tag

### 成功信号
- [ ] 外部用户 1 小时内完成配置并跑通 /workflow
- [ ] 至少一个 non-trivial 的反馈（"README 不清楚"/"某变量不明"）被处理

---

## P6 v0.1 发布

### 任务清单

- [ ] P5 反馈全部处理
- [ ] 最后一次端到端验收（dex-sui 自消耗 + 外部试装 都通过）
- [ ] CHANGELOG `v0.1.0` 正式版
- [ ] 打 `v0.1.0` tag 和 GitHub Release
- [ ] README 首页 install 命令改为 `/plugin marketplace add duktig666/roundtable`（去掉 `--plugin-dir` 前置条件）
- [ ] 内部公告（团队 Slack / 邮件）
- [ ] dex-sui 切换到 remote install（不再用 `--plugin-dir`）

### 成功信号
- [ ] `v0.1.0` 发布在 GitHub Releases
- [ ] dex-sui 用 remote install 跑一次回归 OK
- [ ] 外部用户能成功从 remote install

---

## 跨阶段通用约束

- 每个 Phase 完成后在 roundtable 自己的 `docs/decision-log.md` / `docs/log.md` 记录（P0 后）
- 所有 commit 英文（遵循 dex-sui 约定）
- PR 描述用英文（跨项目可见）
- 代码（agent/skill prompt 文件）英文 + 中文注释（遵循 dex-sui 约定）
- 每阶段完成后跑一次手动冒烟测试（/plugin install → /roundtable:workflow）

---

## 变更记录

- 2026-04-17 创建，基于 design-doc v1.0（含 D1-D8 决策确认）
