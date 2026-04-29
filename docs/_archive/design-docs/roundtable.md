---
slug: roundtable
source: 原创
created: 2026-04-17
updated: 2026-04-17
status: Accepted
decisions: [DEC-001]
owner: duktig666 (https://github.com/duktig666)
license: Apache-2.0
plugin_name: roundtable
repository: https://github.com/duktig666/roundtable
---

# roundtable — 多角色 Agent 工作流 Claude Code Plugin 设计文档

> slug: `roundtable` | 状态: Accepted | 参考: gstack office-hours（六问框架）、Claude Code Plugin 官方文档

---

## 0. 决策总览

本设计涉及 9 项关键决策（D1-D9），每项的完整备选 / 权衡 / 量化评分见「§6 关键决策与权衡」，以下为速览：

| # | 决策点 | 选择 |
|---|--------|------|
| D1 | design-doc 落盘位置 | **B** 仅 plugin 仓库（single source of truth） |
| D2 | 项目参数化方式 | **B-0 零 userConfig**（全走 CLAUDE.md + 运行时自动检测；plugin 安装零弹窗） |
| D3 | 分发形态 | **A** 单 repo 单 marketplace |
| D4 | 本地 clone 使用方式 | **D 混合**（普通用户远程 install，贡献者用 `--plugin-dir` 本地开发） |
| D5 | Scope 默认推荐 | **user** 装一次全局通用（与 B-0 配套） |
| D6 | 实施策略 | **B POC 增量**（P1 先通用化 architect skill + /workflow command） |
| D7 | 业务特定如何容纳 | **A** 项目 CLAUDE.md 自描述（plugin 提供可抄模板） |
| D8 | 角色形态分配 | **C 混合**（architect / analyst → skill；developer / tester / reviewer / dba → agent） |
| D9 | 目标项目识别机制 | 任务内自动识别（正则匹配 / 扫 CWD 子目录含 `.git` 的候选池） + AskUserQuestion 兜底 + session 内记忆 |

**元信息**：Plugin 名 `roundtable`；Owner `duktig666`；许可证 Apache-2.0；权威决策 DEC-001（见 `docs/decision-log.md`）

---

## 1. 背景与目标

### 1.1 背景

用 Claude Code 做中大型项目时，单一 LLM 对话容易出现"一路拍脑袋推下去"的失控感：架构决策没人把关、实现和设计脱节、测试和 review 被跳过。社区已有的单个 agent 模式不足以支撑纪律化的开发流程，需要一套**多角色协同**的框架，同时保留用户对关键决策的把控权。

核心需求：
- **多角色协同**：analyst 调研 → architect 决策 → developer 编码 → tester 测试 → reviewer / dba 审查
- **plan-then-execute 纪律**：中大任务必须先出方案等用户确认再执行，而不是 Claude 一口气做完让用户收拾
- **关键决策交互式**：架构决策点用弹窗让用户逐个裁决，而非单方面推结论
- **跨项目可复用**：同一套工作流应能服务 Rust / TypeScript / Python / Move 等不同技术栈的项目，业务规则由各项目自描述

### 1.2 目标

把上述工作流**打包成 Claude Code plugin**，让任何团队在 1 行命令内装上用：

```bash
/plugin marketplace add duktig666/roundtable
/plugin install roundtable@roundtable --scope user
```

目标受众：
1. 用 Claude Code 做中大型项目开发的团队（Rust / TS / Python / Move / 混合栈均可）
2. 希望在同一 Claude Code 实例里管理多个项目（workspace 根目录启动，切换目标项目）
3. 希望贡献改进的开发者 —— clone 仓库后用 `--plugin-dir` 本地开发

### 1.3 非目标（v0.1 不做）

- ❌ **不做 profile 系统**（rust-backend / ts-frontend / move-contract 这种硬预设）—— 由项目 CLAUDE.md 自描述更灵活
- ❌ **不做 agent 之间的 RPC 或共享状态**—— 保持"通过 slug + 文件系统串联"的简单模型
- ❌ **不做 GUI 配置 / 安装向导**—— Claude Code 原生机制已够用
- ❌ **不做"猜测项目语言"的魔法**—— 用读 `Cargo.toml` / `package.json` 等显式信号；CLAUDE.md 可覆盖
- ❌ **不在 v0.1 发布 publish-to-marketplace 脚本**—— 从 GitHub 直接装就够了

---

## 2. 业务逻辑

### 2.1 用户 onboarding 流程（端到端）

```
 1. 用户听说 roundtable
      │
      ▼
 2. 在 Claude Code 里执行（workspace 根目录或任意子项目均可）
      /plugin marketplace add duktig666/roundtable
      /plugin install roundtable@roundtable --scope user
      ↓ 零弹窗，秒装完（D2 B-0）
      │
      ▼
 3. 用户在每个项目的 CLAUDE.md 追加「# 多角色工作流配置」section（一次性，抄模板改）：
      # 多角色工作流配置
      ## critical_modules（tester / reviewer 必触发）
      - <项目关键模块，如支付 / 订单 / 认证 / 数据管道 ...>
      ## 设计参考
      - <项目对标产品 / 框架>
      ## 工具链覆盖（可选，不写走自动检测）
      - lint: <项目 lint 命令>
      │
      ▼
 4. 用户在 Claude Code 里触发工作流
      /roundtable:workflow 设计 <project> 的 <feature>
      │
      ▼
 5. Skill / Agent 运行时自动：
      a. 目标项目识别（D9）：从任务描述匹配 → target_project 定位
         · 识别失败 → AskUserQuestion 弹窗让用户选
      b. 工具链检测：扫 target_project 根的 Cargo.toml / package.json / pyproject.toml / go.mod / Move.toml
      c. 文档路径：target_project/docs/ 存在 → 用它（或 documentation/）
      d. 加载 target_project/CLAUDE.md 的「# 多角色工作流配置」section（声明覆盖检测值）
      e. architect skill 激活 → AskUserQuestion 逐个做架构决策
      f. 落盘到 <target_project>/<docs_root>/design-docs/<slug>.md
```

### 2.2 Agent / Skill 运行时加载流程（D2 B-0 + D9 新模型）

无 userConfig 替换环节，改为运行时检测 + CLAUDE.md 自动加载：

```
skill/agent 被激活
  ↓ 第一步：D9 识别 target_project
  ↓   - 查 session 记忆 → 有则复用
  ↓   - git rev-parse 成功 → 用
  ↓   - 任务描述匹配 candidates → 用
  ↓   - 失败 → AskUserQuestion 问用户
  ↓
target_project = "<workspace>/<project>"
  ↓ 第二步：检测工具链
  ↓   - scan target_project 根的 Cargo.toml / package.json / pyproject.toml ...
  ↓   - 解析出 lint_cmd / test_cmd / primary_lang
  ↓
  ↓ 第三步：加载该项目 CLAUDE.md
  ↓   - target_project/CLAUDE.md 自动拼接进 context
  ↓   - 业务规则（critical_modules / design_ref / 触发规则）就位
  ↓   - CLAUDE.md 里「# 多角色工作流配置」的工具链声明覆盖第二步检测值
  ↓
  ↓ 第四步：拼接当轮用户 prompt
  ↓
最终 LLM context：skill/agent 通用 prompt + 识别结果 + 检测结果 + CLAUDE.md + 用户任务
```

关键机制：
- **零 userConfig**：plugin 安装无弹窗，所有配置靠运行时
- **session 记忆**：D9 识别结果 + 工具链检测结果缓存在主会话上下文里，后续 agent 派发不重复
- **CLAUDE.md 最高优先级**：用户在 CLAUDE.md 声明的任何值覆盖自动检测
- **多项目天然支持**：target_project 切换后整个加载链路重新跑，CLAUDE.md 也会切到对应项目的

### 2.3 核心用例时序

**用例 A：新用户装 plugin 并跑第一次 /workflow**

```
User                 Claude Code                    Skill (architect)
 │                        │                               │
 │ /plugin marketplace add duktig666/roundtable           │
 │ /plugin install roundtable@roundtable --scope user     │
 ├──────────────────────>│  (无 userConfig 弹窗，零门槛)   │
 │                       │                                │
 │ 在项目 CLAUDE.md 写「# 多角色工作流配置」section         │
 │                       │                                │
 │ /roundtable:workflow <任务描述>                         │
 ├──────────────────────>│                                │
 │                       │ 识别 target_project（D9）      │
 │                       │ 检测工具链（Cargo.toml 等）    │
 │                       │ 加载 target_project/CLAUDE.md  │
 │                       │ 激活 architect skill           │
 │                       ├───────────────────────────────>│
 │                       │ AskUserQuestion 决策弹窗       │
 │<──────────────────────┼────────────────────────────────┤
 │ 点选决策              │                                │
 ├──────────────────────>│                                │
 │                       │ 落盘 <target_project>/<docs_root>/design-docs/<slug>.md
```

**用例 B：已有本地 `.claude/` 的项目切换到 plugin**

项目原先在自己的 `.claude/agents/` `.claude/commands/` 下放了若干本地 agent/command 定义。切换路径：

1. `git mv .claude/agents/ .claude/agents.backup/` `git mv .claude/commands/ .claude/commands.backup/`（保底）
2. `/plugin install roundtable@roundtable --scope user`
3. 在项目 CLAUDE.md 追加「# 多角色工作流配置」section，按项目实际填 critical_modules / 设计参考 / 工具链覆盖
4. 跑一个冒烟需求验证 —— design-doc / decision-log / log.md 等落盘路径是否与原本地版行为一致
5. 确认无回归后删 `.claude/agents.backup/` `.claude/commands.backup/`

---

## 3. 技术实现

### 3.1 Plugin 仓库目录结构

```
roundtable/                            # GitHub: duktig666/roundtable
├── .claude-plugin/
│   ├── plugin.json                         # Manifest（唯一固定位置）
│   └── marketplace.json                    # 单 repo 单 marketplace（D3 决策）
├── skills/                                 # 交互式角色（D8 决策）
│   ├── architect.md                        # 三阶段工作流 + AskUserQuestion 决策弹窗
│   └── analyst.md                          # 六问框架 + 研究中 AskUserQuestion 澄清
├── agents/                                 # 自主执行角色（D8 决策）
│   ├── developer.md                        # 读写代码（隔离上下文）
│   ├── tester.md                           # 对抗性测试 + benchmark（隔离上下文）
│   ├── reviewer.md                         # 代码审查（隔离上下文）
│   └── dba.md                              # PG / migration 审查（隔离上下文）
├── commands/
│   ├── workflow.md                         # 编排：激活 skill / 派发 agent
│   ├── bugfix.md
│   └── lint.md
├── hooks/                                  # 预留，v0.1 暂不用
├── docs/                                   # dogfooding：roundtable 自己按 plugin 推荐的"产出契约"管理文档
│   ├── INDEX.md                            # 全文档导航
│   ├── decision-log.md                     # DEC 注册表
│   ├── log.md                              # 设计层文档时间索引（append-only）
│   ├── analyze/[slug].md                   # analyst 调研报告（按需）
│   ├── design-docs/
│   │   └── roundtable.md                   # 本 doc
│   ├── exec-plans/
│   │   ├── active/
│   │   │   └── roundtable-plan.md          # P0-P6 路线
│   │   └── completed/                      # 归档
│   ├── testing/[slug].md             # tester 测试计划（按需）
│   ├── reviews/[YYYY-MM-DD]-[slug].md      # reviewer/dba 落盘审查（按需）
│   ├── onboarding.md                       # [P3] 5 分钟上手
│   ├── claude-md-template.md               # [P3] 给用户抄的 CLAUDE.md section 模板
│   └── migration-from-local.md             # [P3] 从本地 .claude/ 切换到 plugin 的 runbook
├── examples/
│   └── <profile>-snippet.md                # [P3] 典型项目类型的 CLAUDE.md section 片段示例
├── README.md                               # GitHub 首页（install 命令 + Quick Start）
├── LICENSE                                 # Apache-2.0 全文
├── CHANGELOG.md
└── CONTRIBUTING.md
```

> **关键点 1**：plugin 目录结构由 Claude Code 规范限定 —— 只有 `plugin.json` 必须在 `.claude-plugin/` 下，其他目录（`agents/`、`commands/`、`skills/`、`hooks/`）放在仓库根。
>
> **关键点 2**：`docs/` 下的"内部维护者文档"按 roundtable plugin 自己推荐的"多角色工作流产出契约"组织（slug 命名 + design-docs / exec-plans / analyze / reviews 分层）—— **dogfooding**，方便用户安装后直接把本仓库当作标准样本参考。"用户向文档"（onboarding / claude-md-template / migration）平铺在 `docs/` 根。

### 3.2 plugin.json Manifest

```json
{
  "name": "roundtable",
  "version": "0.1.0",
  "description": "Multi-role AI agent workflow (analyst/architect/developer/tester/reviewer/dba) with plan-then-execute discipline. Zero-config install, per-project CLAUDE.md drives everything.",
  "author": {
    "name": "duktig666",
    "url": "https://github.com/duktig666"
  },
  "homepage": "https://github.com/duktig666/roundtable",
  "repository": "https://github.com/duktig666/roundtable",
  "license": "Apache-2.0"
}
```

**注意**：根据 D2 决策，plugin.json **不含 userConfig 字段** —— 安装时零弹窗。所有项目特定配置走各自项目的 `CLAUDE.md` 的「# 多角色工作流配置」section，运行时 agent 自动检测工具链 + 文档路径（详见 §6 D2 决策的"自动检测规则"）。

### 3.3 agent 模板通用化示意（以 architect 为例）

以 architect skill 为例，prompt 里的路径用占位符：

```markdown
## 目标
- 输出设计文档到 `{target_project}/{docs_root}/design-docs/[slug].md`
- 按需输出执行计划到 `{target_project}/{docs_root}/exec-plans/active/[slug]-plan.md`
- 按需输出接口定义到 `{target_project}/{docs_root}/api-docs/[slug].md`

## 约束
- 项目特定的设计参考、critical_modules、触发规则在**项目 CLAUDE.md 的「# 多角色工作流配置」section 里自描述**。skill 运行时自动加载 target_project 的 CLAUDE.md，请把该项目 CLAUDE.md 的声明作为权威来源。
```

`{target_project}` 和 `{docs_root}` 都在 D9 识别 + 工具链检测阶段由 skill 自己解析得到，不靠 plugin.json userConfig 注入。

### 3.4 项目 CLAUDE.md 接入模板

用户在项目根 `CLAUDE.md` 追加以下 section（若无 CLAUDE.md 新建）；每个 section 内按项目实际情况填：

```markdown
# 多角色工作流配置

## critical_modules（tester / reviewer 必触发）
# 列项目里"改错会出大事"的关键模块，命中任一关键词时强制触发 tester 和 reviewer
- <模块或关键词 1>
- <模块或关键词 2>

## 设计参考
# 项目对标什么产品 / 框架，影响 architect 的设计取向
- <参考 1>
- <参考 2>

## 工具链覆盖（可选，不写走自动检测）
# 仅在自动检测不够准时填
- lint: <项目 lint 命令>
- test: <项目 test 命令>

## 文档约定
- 决策日志 `docs/decision-log.md`（追加 DEC-xxx，不删旧条目）
- 操作日志 `docs/log.md`（append-only，顶部最新）
- 变更记录写在各 doc 底部，不入 log.md
- 主题 slug 用 kebab-case 英文，贯穿整个工作流

## 条件触发规则（可选，按项目业务追加）
- <条件 → 动作>
```

plugin 仓库的 `docs/claude-md-template.md`（P3 产出）提供一份可抄的完整示例，`examples/` 下放典型项目类型（Rust 后端 / TS 前端 / Python 数据管道 等）的示范片段。

### 3.5 配置加载模型（D2 B-0：零 userConfig）

**所有配置集中在项目 `CLAUDE.md`**，plugin.json 不含 userConfig 字段。agent 运行时按以下优先级获取配置：

```
1. session 记忆（已识别过的 target_project / 已检测过的工具链）
2. target_project/CLAUDE.md 的「# 多角色工作流配置」section（显式声明）
3. 运行时自动检测（Cargo.toml / package.json / docs 目录）
4. 硬编码兜底（docs_root 默认 "docs"）
```

| 配置项 | 来源 | 说明 |
|-------|------|------|
| `target_project` | D9 机制识别 | session 内记忆；根目录启动时 AskUserQuestion 兜底 |
| `docs_root` | 检测 `docs/` → `documentation/` → CLAUDE.md 覆盖 | 默认 "docs"；CLAUDE.md 里 `## 多角色工作流配置 → docs_root: xxx` 可覆盖 |
| `lint_cmd` | 检测项目根文件 → CLAUDE.md 覆盖 | Cargo.toml → `cargo xclippy`；package.json → 读 scripts.lint；等等 |
| `test_cmd` | 同 lint_cmd | 同上机制 |
| `primary_lang` | 检测项目根文件 | 不暴露给用户，只影响 agent 措辞 |
| `critical_modules` | CLAUDE.md 必填 | plugin 模板提供示例，用户必须写到自己项目的 CLAUDE.md |
| `design_references` | CLAUDE.md 可选 | 鼓励填，影响 architect 设计决策 |
| `trigger_rules` | CLAUDE.md 可选 | 如"涉及金额禁浮点" |

### 3.6 数据流（Agent 读 CLAUDE.md + userConfig）

```
┌──────────────────────────┐
│  plugin.json            │  (安装时写入 settings)
│  userConfig schema      │
└──────────┬───────────────┘
           │ /plugin install 弹窗
           ▼
┌──────────────────────────┐
│  ~/.claude/settings.json │  或 .claude/settings.local.json
│  { plugin_config: ... }  │
└──────────┬───────────────┘
           │ 运行 /roundtable:workflow
           ▼
┌──────────────────────────┐
│  agent.md 模板展开       │
│  ${user_config.xxx} →值  │
└──────────┬───────────────┘
           │ + 项目 CLAUDE.md 自动加载
           ▼
┌──────────────────────────┐
│  LLM 最终 context         │
└──────────────────────────┘
```

### 3.7 安装 / 本地开发两种路径（D4 决策）

**普通用户（远程 install 模式）**

```bash
# 在 Claude Code 里（根目录或子项目都行）
/plugin marketplace add duktig666/roundtable
/plugin install roundtable@roundtable --scope user
# 零弹窗，装完即用（D2 B-0）
# 首次在某子项目跑 /roundtable:workflow 时，
# agent 会：(1) 通过 D9 机制识别目标项目；(2) 检测工具链；(3) 读 CLAUDE.md 业务规则
```

**贡献者 / 维护者（本地开发模式）**

```bash
# 把 plugin 源码 clone 到 workspace
cd <workspace>
git clone git@github.com:duktig666/roundtable.git

# 在任意项目里用 --plugin-dir 指向本地 clone，改 plugin 立刻生效（无需 release）
cd <workspace>/<project>
claude --plugin-dir <workspace>/roundtable
```

**不推荐 symlink 到 `~/.claude/plugins/` 的方案**：跨项目全局生效但与"不同项目 CLAUDE.md 声明不同"的诉求冲突时缺少清晰回退路径。

---

## 4. 命名空间与 scope

- **命名空间**：`/roundtable:workflow`、`/roundtable:bugfix`、`/roundtable:lint`（Claude Code 自动为 plugin 加前缀）
- **Scope（D5）**：
  - **user** scope（`~/.claude/plugins/`）：**推荐** —— 装一次，全局所有项目可用；适配"workspace 根目录启动 Claude Code"场景
  - project scope：B-0 下无意义，本就没 userConfig 可存
  - local scope：同理不需要
- **两种运行场景**：
  - **workspace 根目录启动**：plugin 已装（user scope） → 通过 D9 识别 target_project → 读那个项目的 CLAUDE.md → 跑工作流 → 落盘到那个项目的 `<docs_root>/design-docs/`
  - **子项目内启动**：`git rev-parse` 直接拿到项目根，跳过 D9 的 AskUserQuestion 步骤

---

## 5. 前置依赖与边界

### 5.1 前置
- Claude Code CLI 支持 `/plugin install`
- 项目 CLAUDE.md 自动加载机制（Claude Code 原生支持）
- Skill 与 Agent 可同时存在于一个 plugin（已核实 Claude Code 官方文档）

### 5.2 兼容性
- 若项目本地 `.claude/agents/` 有同名自建文件，Claude Code 合并规则是 user/project level 覆盖 plugin level —— 会导致"装了 plugin 但行为没变"的困惑。用户迁移时建议先 `git mv .claude/agents/ .claude/agents.backup/` 验证无回归后再删

### 5.3 路径限制
- Plugin 内部不能 `../` 引用外部文件 —— 所有模板、示例必须放在 plugin 仓库内
- Plugin skill/agent 运行时读取的是**用户项目 CWD 及其 CLAUDE.md**，不是 plugin 自身目录；所有路径占位符（如 `{target_project}/{docs_root}`）在运行时解析为项目相对路径

---

## 6. 关键决策与权衡

### D1 design-doc 落盘位置

| 方案 | 决策 |
|------|------|
| **选择** | **B** —— design-doc 归属 plugin 仓库本身（`docs/design-docs/roundtable.md`） |
| 备选 | A 放消费方项目；C 双份主从；D 双份对等 |
| 理由 | single source of truth，避免双份漂移维护成本；plugin 面向所有用户，设计文档作为 plugin 的一部分自然归属本仓库 |

### D2 项目参数化方式（B-0 零 userConfig）

多项目场景下，"一个全局 userConfig 值"天然无法表达 per-project 差异（docs_root / lint_cmd / critical_modules 等各项目不同）。借助 Claude Code 原生的 per-project CLAUDE.md 机制 + 运行时文件检测（Cargo.toml / package.json 等），零 userConfig 反而是最简也最准的方案。

| 方案 | 决策 |
|------|------|
| **选择** | **B-0 零 userConfig**：plugin 安装不弹任何窗，全靠 CLAUDE.md + 运行时自动检测 + 目标项目识别（D9） |
| 备选 | A 多字段 userConfig（6-20 项弹窗）；B-1 仅保留 docs_root 一个字段 |
| 理由 | (1) 弹窗零门槛，真正做到"一行命令装完即用"；(2) SSOT 单一配置源（CLAUDE.md），git 版本管控；(3) 多项目天然 per-project；(4) lint / test / lang 自动检测已够准（读项目根文件） |
| 风险 | 首次跑时自动检测可能错 —— 对策：skill/agent 写任何文档前先 AskUserQuestion 确认目标路径；结果记入 session 记忆不重复问 |

**自动检测规则**（内联到各 skill / agent prompt）：

```markdown
## 工具链识别（task 开始时执行）

1. 目标项目识别（D9）：
   - 已在当前 CWD 的 git 仓库内（`git rev-parse --show-toplevel` 成功）→ 直接用
   - 否则扫描当前 CWD 下含 `.git/` 的一级子目录作为候选池
   - 从用户任务描述里匹配候选池里的项目名（正则）
   - 唯一命中 → target_project = 那个子目录
   - 零命中 / 多命中 → AskUserQuestion 弹窗选

2. 技术栈检测（基于 target_project 根）：
   - Cargo.toml → Rust，lint=`cargo xclippy`，test=`cargo nextest run`
   - package.json → 读 scripts.lint / scripts.test，fallback `pnpm lint` / `pnpm test`
   - pyproject.toml → lint=`ruff check`，test=`pytest`
   - go.mod → lint=`go vet ./...`，test=`go test ./...`
   - Move.toml → Move 项目
   - 多文件并存 → 混合项目，按用户任务涉及的文件判断

3. 文档路径检测（基于 target_project 根）：
   - `docs/` 存在 → 用它
   - `documentation/` 存在 → 用它
   - 都不存在 → AskUserQuestion "我要建 `<target_project>/docs/` 目录，确认？"

4. CLAUDE.md 覆盖（最高优先级）：
   - 如果 `<target_project>/CLAUDE.md` 的「# 多角色工作流配置」section 声明了 docs_root / lint_cmd / test_cmd，以 CLAUDE.md 为准，覆盖检测值
```

| 维度 (0-10) | A 多字段 userConfig | B-1 单 docs_root | B-0 零弹窗 ★ |
|------------|-------------------|-----------------|--------------|
| 安装门槛 | 3（多弹窗） | 7（1 弹窗） | **10**（0 弹窗） |
| 多项目友好度 | 2（单值冲突） | 4 | **9**（天然 per-project） |
| 配置 SSOT | 4（两处） | 5 | **9**（只有 CLAUDE.md） |
| 可维护性 | 6 | 7 | **9** |
| 首次体验准确度 | 9（用户明确填） | 7 | **6**（依赖检测） |
| 灵活性 | 5（字段固化） | 6 | **9**（CLAUDE.md 任意） |
| **合计** | 29 | 36 | **52** |

### D3 分发形态

| 方案 | 决策 |
|------|------|
| **选择** | **A** 单 repo + 单 marketplace.json |
| 备选 | B plugin repo + 独立 marketplace repo；C 一 repo 多 plugin |
| 理由 | v0.1 只有一个 plugin，B/C 是过早抽象；单 repo 最易 onboarding（`add duktig666/roundtable` 一步到位） |

| 维度 (0-10) | A ★ | B | C |
|------------|-----|---|---|
| 实现复杂度 | **9** | 6 | 7 |
| 新用户上手 | **9** | 6（要 add 两个 repo） | 8 |
| 扩展性 | 6 | **9**（可放多 plugin） | 8 |
| 可维护性 | 8 | **8** | 7（多 plugin 版本对齐麻烦） |
| **合计** | **32** | 29 | 30 |

> 迁移路径：未来 plugin 数 >3 时拆成 B 形态（独立 marketplace repo 聚合），编号 DEC-009' 处理。

### D4 本地 clone 使用方式

| 方案 | 决策 |
|------|------|
| **选择** | **D 混合**：默认 A（远程 install），贡献者用 B（`--plugin-dir`）本地开发 |
| 备选 | A 纯远程；B 纯 --plugin-dir；C symlink 到 `~/.claude/plugins/` |
| 理由 | (1) A 给一般用户最低门槛；(2) B 给贡献者即改即生效，闭环快；(3) C 隐式全局影响难于回滚，放弃 |

| 维度 (0-10) | A 纯远程 | B 纯 --plugin-dir | C symlink | D 混合 ★ |
|------------|---------|-------------------|-----------|---------|
| 新用户上手时间 | **9** | 4（要懂 CLI flag） | 5 | **9** |
| 贡献者迭代速度 | 3（改要发 release） | **9** | 7 | **9** |
| 冲突风险 | 7 | 7 | 3（全局生效） | **8** |
| 文档清晰度 | 8 | 7 | 6 | **7**（要写两条路径） |
| **合计** | 27 | 27 | 21 | **33** |

### D5 Scope 默认推荐

| 方案 | 决策 |
|------|------|
| **选择** | **user scope**（`~/.claude/plugins/`）—— plugin 装一次，全局所有项目可用 |
| 备选 | project scope（每项目各装一次，与 D2 B-0 不搭）；local scope（B-0 下没东西可 override） |
| 理由 | (1) workspace 根目录启动 Claude Code 是常见场景，user scope 最自然；(2) 业务配置走 CLAUDE.md（已 per-project git 共享），不需要 settings.json 再分层；(3) 一行命令装完所有项目立刻有 |

### D6 实施策略

| 方案 | 决策 |
|------|------|
| **选择** | **B POC 增量** |
| 备选 | A big-bang；C 并行双存 |
| 理由 | 先通用化最复杂的角色（architect，含三阶段工作流 + AskUserQuestion 逻辑）+ /workflow command，跑通端到端链路后，批量改其余角色 |

详见 §7「分阶段实施路线」。

### D7 业务特定如何容纳

| 方案 | 决策 |
|------|------|
| **选择** | **A 项目 CLAUDE.md 自描述** |
| 备选 | B plugin 内置 profile；C 纯用户自填 |
| 理由 | (1) Claude Code 原生支持 CLAUDE.md 自动加载，零额外机制；(2) profile 抽象过早，不同 rust 项目 critical_modules 也不同；(3) 纯用户自填不如"有模板抄"好学 |
| 支撑 | plugin 仓库的 `docs/claude-md-template.md` 提供完整可抄模板 |

### D8 角色形态分配（Skills vs Agents 混合）

**背景**：Claude Code 提供两套机制（官方文档已核实）：
- **Skill**：激活后在主会话上下文运行，有 AskUserQuestion，但会污染主会话 context（长任务会爆）
- **Agent**：subagent 隔离上下文运行，**AskUserQuestion 系统级禁用**，但不污染主会话

这决定了不同角色适合不同形态：

| 方案 | 决策 |
|------|------|
| **选择** | **C 混合**：architect / analyst 用 skill；developer / tester / reviewer / dba 用 agent |
| 备选 | A 全 agent；B 全 skill |
| 理由 | (1) architect 依赖 AskUserQuestion 逐个决策弹窗，这是核心交互体验；(2) analyst 研究中也有交互式澄清需求；(3) developer / tester 读写大量代码，必须隔离上下文避免主会话污染；(4) reviewer / dba 同理 |
| 风险 | 用户心智成本：为什么 "@architect" 不派发 subagent？—— 对策：README 用"交互式 role（skill）" vs "自主执行 role（agent）" 二分法讲清楚 |

**机制要点**（已核实）：
- Skill 不能直接调 Task 工具派发 agent；但**主会话（激活 skill 后）仍可以**。工作流：`/workflow` command → 主会话激活 `architect` skill → architect 用 AskUserQuestion 决策 + 写 design-doc → 用户确认 → 主会话（仍在 architect skill 上下文）派发 `developer` agent 到 subagent 执行
- Skill 可通过 Skill 工具互相调用
- 一个 plugin 同时包含 `agents/` + `skills/` + `commands/` 三个目录无冲突，命名空间自动加前缀
- `agents/xxx.md` 和 `skills/xxx.md` 同名时 **skill 优先**

| 维度 (0-10) | A 全 agent | B 全 skill | C 混合 ★ |
|------------|-----------|-----------|---------|
| AskUserQuestion 可用性 | 3（失效） | 9 | **9** |
| 主会话 context 污染 | 9（不污染） | 3（大任务爆） | **7** |
| 角色职责清晰度 | 8 | 8 | **7**（要解释二分法） |
| 用户心智一致性 | 9（全 @mention） | 9（全 /skill） | **6** |
| 实现复杂度 | 8 | 8 | **6**（两套文件） |
| 迁移参考实现贴近度 | 9（原型全 agent） | 4 | **7** |
| **合计** | 46 | 41 | **42** |

**评分 A 略高于 C，但 A 的致命缺陷（AskUserQuestion 失效）是一票否决项 —— 量化分不捕捉"核心体验倒退"的决定性权重**。故选 C。

### D9 目标项目识别机制

当用户从 workspace 根目录（非 git 仓库）启动 Claude Code 时，`git rev-parse` 无法确定目标项目，但任务描述往往已暗含目标（如"实现 X 项目的某功能"）。需要一套算法识别 target_project。

| 方案 | 决策 |
|------|------|
| **选择** | 任务内自动识别 + AskUserQuestion 兜底 + session 内记忆 + 用户可显式切换 |
| 备选 | A 强制用户在子项目根启动（违背"workspace 根目录启动"场景）；B 要求用户每次 prompt 显式写项目路径（体验差）；C 只看当前编辑文件路径（任务刚开始时无文件可看） |
| 理由 | 适配多种启动场景（workspace 根 / 子项目根）；avoid 冷启动时无法识别；session 记忆降低重复询问成本 |

**算法**（skill/agent prompt 内联）：

```markdown
## 目标项目识别（每次任务开始时执行一次）

1. session 记忆里已有 `target_project` 且本任务未显式切换 → 直接复用
2. 尝试 `git rev-parse --show-toplevel`：
   - 成功（在子项目内启动）→ 用它，写入 session 记忆
   - 失败（workspace 根非 git）→ 继续下一步
3. 扫描 CWD 下所有含 `.git/` 的一级子目录，得到候选池 `candidates`
4. 从用户任务描述里正则匹配候选池里的项目名：
   - 唯一匹配 → 用它
   - 多匹配 → AskUserQuestion 从命中项中选
   - 零匹配 → AskUserQuestion 从 candidates 全集中选
5. 用户显式说"切到 <other>" / "改做 <other> 的 xxx" → 清空 session 记忆重跑识别
6. 跨项目任务（"A 项目的 X 和 B 项目的 Y 都改"）→ 告知用户分拆成独立任务处理
```

**session 记忆实现**：在主会话 context 中持有 `target_project = "<workspace>/<project>"`，所有后续 agent 派发在 prompt 里注入这个值。

---

## 7. 分阶段实施路线（D6 决策的展开）

| Phase | 动作 | 产出 | 成功信号 |
|-------|------|------|---------|
| **P0 建仓与骨架** | 创建 GitHub 公开仓库；初始化 plugin.json / marketplace.json / LICENSE / README / CHANGELOG / CONTRIBUTING / .gitignore；建 `skills/` `agents/` `commands/` `hooks/` `examples/` 目录；建 `docs/design-docs/` `docs/exec-plans/active/` `docs/analyze/` `docs/reviews/` `docs/testing/` 子目录；落盘 design-doc / exec-plan / decision-log / log / INDEX | 可安装 plugin 骨架（内容尚未通用化） | `/plugin marketplace add duktig666/roundtable` 成功；目录结构完整 |
| **P1 POC：architect skill + workflow command** | 写 `skills/architect.md`（skill 形态，含 AskUserQuestion 三阶段 + D9 识别 + 工具链检测）；写 `commands/workflow.md`（编排逻辑区分"激活 skill"和"派发 agent"） | 2 份文件 | 本地 `--plugin-dir` 装上，`/roundtable:workflow` 能跑架构阶段，**AskUserQuestion 真实弹窗**，D9 识别正确，文档落到正确的 `<target_project>/<docs_root>/design-docs/` |
| **P2 批量改剩余角色** | `skills/analyst.md`（交互式）；`agents/developer.md` `agents/tester.md` `agents/reviewer.md` `agents/dba.md`（隔离执行）；`commands/bugfix.md` `commands/lint.md` | 2 skill + 4 agent + 2 command | 全流程跑一遍，skill / agent 分工清晰，grep 无业务术语硬编码 |
| **P3 文档 + 模板 + onboarding** | `docs/claude-md-template.md`、`docs/onboarding.md`、`docs/migration-from-local.md`、`examples/<profile>-snippet.md`（几种典型项目类型的 CLAUDE.md 片段示例） | 4+ 份文档 | 陌生项目按 5 分钟 onboarding 能跑通 /workflow |
| **P4 自消耗闭环** | 挑一个实际项目装 plugin，按 onboarding 走一遍：补 CLAUDE.md 的「# 多角色工作流配置」section → `/roundtable:workflow` 做一个需求 → 验证 design-doc 落盘 / decision-log / log.md 都正常产出 | 内部验收报告 | end-to-end 流程无阻塞 |
| **P5 外部用户试装** | 邀一位未参与设计的开发者按 README + onboarding 独立走完安装 → 配置 → 首次跑工作流 | 外部反馈清单 | 1 小时内完成配置；收集到至少一条 non-trivial 反馈并处理 |
| **P6 v0.1 发布** | 打 tag、写 CHANGELOG、推 README | GitHub release | `/plugin marketplace add duktig666/roundtable` + 远程 install 可用 |

---

## 8. 性能考量

Plugin 本质是 prompt 模板 + manifest，无运行时性能影响。关注点：

- **CLAUDE.md 膨胀**：接入模板 section 控制在 ≤ 100 行，超过时拆子文档并在主 CLAUDE.md 引用
- **session 记忆**：target_project + 工具链检测结果缓存在 session 内，单次任务内不重复检测

## 9. 安全与风控

- Plugin 不自动执行任何命令，只改 prompt
- 当 skill/agent 在"完成后"执行 lint/test 命令时，命令来源于自动检测（读项目 `Cargo.toml` 等）或用户在 CLAUDE.md 的声明 —— 都是用户项目信任边界内的配置
- 不存储任何凭据信息；plugin.json 无 userConfig 字段

## 10. 测试策略

- **单元级**：grep 校验 skill/agent prompt 里无硬编码的业务术语、语言特定命令；所有路径用 `{target_project}/{docs_root}/...` 占位符形式
- **集成级**：准备若干最小 demo 项目（`examples/demo-*/`）覆盖典型栈（Rust / TS / Python / 混合），`claude --plugin-dir ./roundtable --headless` 走端到端 smoke test
- **回归级**：维护者自消耗 —— plugin 维护者自己用它做 plugin 的下一轮设计，发现问题立即反馈

## 11. 兼容性

- 项目本地 `.claude/agents/` 下的同名 agent 会 override plugin（Claude Code 合并规则：user/project level 优先于 plugin）。用户迁移时需清理本地同名文件或改名，否则会出现"装了 plugin 但行为没变"的困惑 —— README 和 migration runbook 明确说明这点

---

## 12. 讨论 FAQ

以下是设计过程中对几个关键问题的讨论记录。

- **Q**：本地 clone 了 roundtable 仓库，如何与 `/plugin install` 结合使用？
- **A**：见 D4 + §3.7。普通用户不需要 clone，直接 `/plugin install`；贡献者 / 自消耗场景用 `claude --plugin-dir <workspace>/roundtable` 即改即生效；不推荐 symlink 到 `~/.claude/plugins/`（全局生效难于回滚）。

- **Q**：为什么不做 `profile: rust-backend | ts-frontend | move-contract`？
- **A**：见 D7。(1) 同语言不同项目 critical_modules 差异很大（如 Rust Web 服务 vs Rust 高频交易系统）；(2) profile 是"另一层参数化"，用户要额外学；(3) CLAUDE.md 自描述 + plugin 提供模板已足够。未来若真需要，可增量以 `userConfig.profile: enum` 方式加入，不冲突。

- **Q**：本地开发模式下，plugin 改了要等 release 才生效吗？
- **A**：否。D4 决策的 B 路径 —— 用 `claude --plugin-dir <workspace>/roundtable`，改 plugin 源码立刻生效。建议把这个调用方式写入项目的运行脚本（如 Makefile 的 `make claude` target）。

- **Q**：plugin.json 的 userConfig / 项目 CLAUDE.md / 项目 `.claude/settings.json` 三处配置之间会冲突吗？
- **A**：roundtable 走 D2 B-0（零 userConfig），所以 plugin.json 根本不声明 userConfig 字段，天然没有冲突源。业务语义全走 CLAUDE.md 一处。

- **Q**：workspace 根目录不是 git 仓库，clone 到这里的 roundtable 数据怎么保证不丢？
- **A**：roundtable 自己是独立 GitHub 仓库，本地 clone 只是工作副本，push 后数据在 remote。workspace 目录是否归 git 与 plugin 使用无关。

- **Q**：多角色工作流应该用 Claude Code Skills 还是 Agents 机制实现？
- **A**：**两者都用**（D8 C 混合）。官方文档确认：Skill 跑在主会话上下文，**AskUserQuestion 可用**；Agent 跑在 subagent 隔离上下文，**AskUserQuestion 被系统级禁用**。
  - architect / analyst → **Skill**（需要交互决策弹窗）
  - developer / tester / reviewer / dba → **Agent**（需要隔离上下文读写大量代码）
  - `/workflow` `/bugfix` `/lint` → **Command**（轻量 prompt 模板）
- **机制要点**：Skill 不能直接调 Task 工具派发 agent，但主会话激活 skill 后仍可调 Task；Skill 之间可通过 Skill 工具互调；一个 plugin 内 `skills/` `agents/` `commands/` 共存无冲突；同名时 skill 优先。
- **用户心智**：README 清楚区分"交互式 role（skill）" vs "自主执行 role（agent）"，避免"为什么 @architect 不启动 subagent" 的困惑。

- **Q**：多项目场景下（用户同时维护多个项目），每个项目的文档落到对应项目里，怎么实现？
- **A**：D2 B-0 + D9 共同解决。利用 Claude Code 原生的 per-project CLAUDE.md 发现机制 + 子项目自带 `.git/` 的事实，运行时识别 target_project 再落盘。不存储全局 docs_root。

- **Q**：用户常从 workspace 根目录启动 Claude Code 而非子项目内，根目录非 git，`git rev-parse` 失效，怎么识别目标项目？
- **A**：见 D9。算法：先查 session 记忆 → 再试 `git rev-parse` → 再扫 CWD 下含 `.git/` 的一级子目录构成候选池 → 从任务描述正则匹配 → 失败时 AskUserQuestion 弹窗。一旦确定 target_project，后续 agent 派发/skill 激活都带上这个值。

---

## 13. 待确认项

本设计文档本身已全部确认。以下是实施过程中仍需跟进的事项：

- [ ] Claude Code 的最低支持版本（需要在 README 里写明），P6 发布前核实
- [ ] 外部首发用户挑谁试装（P5 需要真实新用户反馈）
- [ ] plugin 稳定后是否从个人 owner `duktig666` 转到组织 owner（GitHub 支持 Transfer，URL 自动 redirect）

---

## 14. 变更记录

- 2026-04-17 创建，确认 D1-D9 九项决策并记入 `decision-log.md` DEC-001，产出 `exec-plans/active/roundtable-plan.md` 展开 P0-P6 实施路线

---

> **本 doc 状态**：Accepted。D1-D9 决策已确认，实施路线见 §7 及 `docs/exec-plans/active/roundtable-plan.md`。
