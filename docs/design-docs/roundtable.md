---
slug: roundtable
source: 原创
created: 2026-04-17
updated: 2026-04-17
status: Accepted
decisions: [DEC-001]
migrated_from: dex-sui/docs/design-docs/moongpt-harness-plugin.md @ 2026-04-17（plugin 改名 moongpt-harness → roundtable；owner chainupcloud → duktig666）
owner: duktig666 (https://github.com/duktig666)
license: Apache-2.0
plugin_name: roundtable
repository: https://github.com/duktig666/roundtable
---

# roundtable — 多角色 Agent 工作流 Claude Code Plugin 设计文档

> slug: `roundtable` | 状态: Accepted | 参考: `/data/rsw/.claude/`（原型，dex-sui 下的本地实现）、gstack office-hours（六问框架来源）、Claude Code Plugin 官方文档

---

## 0. 读者须知 —— 决策待确认项（阶段 1 弹窗代替方案）

本次 architect 会话运行在 subagent 环境，`AskUserQuestion` 工具不可用（已验证：`Error: No such tool available: AskUserQuestion. AskUserQuestion is not available inside subagents.`）。按 architect.md 铁律本应逐个决策实时弹窗确认，现退化为在 doc 顶部显著标注**所有关键决策点 + 推荐方案 + 理由 + 量化评分**，请用户在审阅本文档时一次性裁决、反悔或补充。

**每个决策点的完整量化对比见「§6 关键决策与权衡」**，以下仅为速览：

**全部 8 项决策已在 2026-04-17 用户审阅后确认 Accepted**，记录如下（详细评分见 §6）：

| # | 决策点 | 最终选择 |
|---|--------|---------|
| D1 | design-doc 落盘位置 | **B** 仅 roundtable（已于 2026-04-17 从 dex-sui 迁出并删除原副本） |
| D2 | 项目参数化方式 | **B-0 零 userConfig**（全走 CLAUDE.md + 运行时自动检测；plugin 安装零弹窗） |
| D3 | 分发形态 | **A** 单 repo 单 marketplace（duktig666/roundtable） |
| D4 | 根目录 clone 用法 | **D 混合**（普通用户远程 install，贡献者 / dex-sui 自消耗用 --plugin-dir 本地开发） |
| D5 | Scope 默认推荐 | **user** 装一次全局通用（与 B-0 配套，无需 project scope 的 settings.json） |
| D6 | 迁移策略 | **B POC 增量**（P1 只通用化 architect skill + /workflow command） |
| D7 | 业务特定如何容纳 | **A** 项目 CLAUDE.md 自描述（plugin 提供可抄模板） |
| D8 | 角色形态分配 | **C 混合**（architect / analyst → skill；developer / tester / reviewer / dba → agent；commands 保持不变） |
| **D9** | **目标项目识别机制**（适配团队"根目录启动 Claude Code"习惯） | 任务内自动识别（正则匹配 / 扫 CWD 子目录含 `.git` 的候选池） + 失败时 AskUserQuestion 兜底 + session 内记忆 + 用户可显式切换 |

**其他元信息**：
- Plugin 名：`roundtable`（非 `roundtable`）
- Owner: `duktig666`（https://github.com/duktig666）—— GitHub 组织；如需转移所有权后续用 GitHub Transfer
- 许可证：Apache-2.0
- 决策追加：DEC-010

---

## 1. 背景与目标

### 1.1 背景

`/data/rsw/.claude/` 下已经跑通一套多角色 agent 工作流：

- **6 个 agent**：analyst、architect、developer、tester、reviewer、dba
- **3 个 command**：`/workflow`、`/bugfix`、`/lint`
- **支撑机制**：AskUserQuestion 实时弹窗、主题 slug 串联、decision-log、log.md、变更记录三件套

但原型深度绑定 dex-sui：

| 硬编码点 | 举例 |
|---------|------|
| 路径 | `dex-sui/docs/design-docs/`、`dex-sui/docs/analyze/`、`dex-sui/docs/exec-plans/active/` |
| 工具链命令 | `cargo xclippy`、`cargo nextest run -p`、`pnpm lint` |
| 业务术语 | Hyperliquid、dYdX、QCE、quantums、撮合 / 清算 / funding rate |
| 关键模块白名单 | "撮合引擎、资金、清算" 出现在 reviewer/tester 的触发条件中 |
| 技术栈选择规则 | `dex-sui/` → cargo，`dex-ui/` → pnpm（路径直接写死） |

### 1.2 目标

把这套工作流**通用化并打包成 Claude Code plugin**，仓库名 `roundtable`，让任何团队在 1 行命令内装上用：

```bash
/plugin marketplace add duktig666/roundtable
/plugin install roundtable@roundtable
```

目标受众：
1. **主场景**：dex-sui 自消耗（通用化完成后 dex-sui 装回来验证闭环）
2. **次场景**：任何用 Claude Code 做中大型项目开发的团队，只要愿意写一份项目 CLAUDE.md 就能用
3. **贡献者**：直接 clone 到本地，用 `--plugin-dir` 开发、改、测

### 1.3 非目标（这版不做）

- ❌ **不做 profile 系统**（rust-backend / ts-frontend / move-contract 这种硬预设）—— 由项目 CLAUDE.md 自描述更灵活
- ❌ **不做 agent 之间的 RPC 或共享状态**—— 保持原型的"通过 slug + 文件系统串联"模型
- ❌ **不做 GUI 配置 / 安装向导**—— Claude Code 原生 `/plugin install` 的 userConfig 弹窗够用
- ❌ **不做跨语言多工具链的自动探测**（比如"自动识别这是 Python 项目还是 Rust 项目"）—— 显式配置 > 魔法推断
- ❌ **不在 v0.1 发布 publish-to-marketplace 脚本**—— 从 GitHub 直接装就够了
- ❌ **不改动原型 `/data/rsw/.claude/`**—— 作为参考实现保留，自消耗阶段 dex-sui 会主动迁移

---

## 2. 业务逻辑

### 2.1 用户 onboarding 流程（端到端）

```
 1. 用户听说 roundtable
      │
      ▼
 2. 在 Claude Code 里执行（根目录 /data/rsw/ 或任意子项目均可）
      /plugin marketplace add duktig666/roundtable
      /plugin install roundtable@roundtable --scope user
      ↓ 零弹窗，秒装完（D2 B-0）
      │
      ▼
 3. 用户在各子项目的 CLAUDE.md 追加「# 多角色工作流配置」section（一次性，提供模板）：
      # 多角色工作流配置
      ## critical_modules（tester / reviewer 必触发）
      - 撮合引擎 / 清算 / 资金结算 / ...
      ## 设计参考
      - API 对标 Hyperliquid
      ## 工具链覆盖（可选，不写走自动检测）
      - lint: cargo xclippy
      │
      ▼
 4. 用户在 Claude Code 里用（注意：Claude 从根目录 /data/rsw/ 启动）
      /roundtable:workflow 设计 dex-sui 的 funding-rate
      │
      ▼
 5. Agent 运行时自动：
      a. 目标项目识别（D9）：从任务里匹配到 "dex-sui" → target_project = /data/rsw/dex-sui
         · 识别失败 → AskUserQuestion 弹窗让用户选
      b. 工具链检测：扫 target_project/Cargo.toml → Rust 项目 → lint=cargo xclippy
      c. 文档路径：target_project/docs/ 存在 → 用它
      d. 读 target_project/CLAUDE.md 的「# 多角色工作流配置」section 覆盖 /补充
      e. architect skill 激活 → AskUserQuestion 做架构决策
      f. 落盘到 /data/rsw/dex-sui/docs/design-docs/funding-rate.md
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
target_project = "/data/rsw/xxx"
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
User           Claude Code        GitHub            Agent (architect)
 │                  │                │                    │
 │ /plugin install  │                │                    │
 ├─────────────────>│                │                    │
 │                  │ fetch manifest │                    │
 │                  ├───────────────>│                    │
 │                  │<───────────────┤                    │
 │                  │ 弹窗 userConfig │                    │
 │<─────────────────┤                │                    │
 │ 填 DOCS_ROOT 等  │                │                    │
 ├─────────────────>│                │                    │
 │                  │ 写 ~/.claude/plugins/moongpt-.../   │
 │                  │ + settings 记录 config 值           │
 │                  │                                     │
 │ 写项目 CLAUDE.md │                                     │
 │                  │                                     │
 │ /roundtable:workflow 实现 xxx                    │
 ├─────────────────>│                                     │
 │                  │ 激活 architect agent                │
 │                  ├────────────────────────────────────>│
 │                  │  注入 ${user_config.docs_root} =    │
 │                  │  "docs"；拼接项目 CLAUDE.md         │
 │                  │                                     │
 │                  │ 决策弹窗 AskUserQuestion            │
 │<─────────────────┼─────────────────────────────────────┤
 │ 点选 A           │                                     │
 ├─────────────────>│                                     │
 │                  │ 落盘 docs/design-docs/xxx.md        │
```

**用例 B：dex-sui 自消耗**

dex-sui 原本就有 `.claude/`，迁移时把本地 `.claude/agents/` `.claude/commands/` 目录下同名文件备份后删除（参考原型保留在 `/data/rsw/.claude/` 根目录一份），改为 `/plugin install roundtable`，然后在 `dex-sui/CLAUDE.md` 追加「## 多角色工作流配置」section 填 critical_modules（撮合/清算/资金 Keeper）、设计参考（Hyperliquid）、工具链提示（cargo xclippy）等。

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
│   ├── decision-log.md                     # DEC 注册表（DEC-001 承接自 dex-sui DEC-010）
│   ├── log.md                              # 设计层文档时间索引（append-only）
│   ├── analyze/[slug].md                   # analyst 调研报告（按需）
│   ├── design-docs/
│   │   └── roundtable.md                   # 本 doc（2026-04-17 从 dex-sui 迁入）
│   ├── exec-plans/
│   │   ├── active/
│   │   │   └── roundtable-plan.md          # P0-P6 路线
│   │   └── completed/                      # 归档
│   ├── testing/plans/[slug].md             # tester 测试计划（按需）
│   ├── reviews/[YYYY-MM-DD]-[slug].md      # reviewer/dba 落盘审查（按需）
│   ├── onboarding.md                       # [P3] 5 分钟上手
│   ├── claude-md-template.md               # [P3] 给用户抄的 CLAUDE.md section 模板
│   └── migration-from-dex-sui.md           # [P3] dex-sui 自消耗 runbook
├── examples/
│   └── dex-sui-snippet.md                  # [P3] 示例：dex-sui 怎么写 CLAUDE.md
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

原型关键差异段改造如下（前后对照）：

**原型（硬编码）**：

```markdown
## 目标
- 输出设计文档到 `dex-sui/docs/design-docs/[slug].md`
- 按需输出执行计划到 `dex-sui/docs/exec-plans/active/[slug]-plan.md`
- 按需输出接口定义到 `dex-sui/docs/api-docs/[slug].md`

## 约束
- 首要对标 Hyperliquid，dYdX 仅辅助参考
```

**通用化**：

```markdown
## 目标
- 输出设计文档到 `${user_config.docs_root}/design-docs/[slug].md`
- 按需输出执行计划到 `${user_config.docs_root}/exec-plans/active/[slug]-plan.md`
- 按需输出接口定义到 `${user_config.docs_root}/api-docs/[slug].md`

## 约束
- 项目特定的设计参考、critical_modules、触发规则在**项目 CLAUDE.md 的「## 多角色工作流配置」section 里自描述**，agent 运行时自动加载 CLAUDE.md，请把项目配置作为权威来源
- 参考提示：${user_config.design_ref_hint}
```

### 3.4 项目 CLAUDE.md 接入模板

用户只需在项目根 `CLAUDE.md` 追加（若无 CLAUDE.md 新建）：

```markdown
## 多角色工作流配置（roundtable）

### critical_modules（tester / reviewer 触发条件）
<任一命中触发关键模块 flow>
- 撮合引擎（order matching、fill、order book）
- 清算 / 保险基金 / ADL
- 保证金 / 资金结算 / funding rate
- Keeper 自治服务
- 性能敏感热路径（需要 benchmark）

### 设计参考
- API 对标 Hyperliquid，辅助参考 dYdX
- 事件模式参考 dYdX OnChainUpdates / OffChainUpdates
- 索引框架基于 sui-indexer-alt

### 工具链
- 构建 `cargo build -p <crate>`
- Lint `cargo xclippy`（提交前必跑）
- 测试 `SUI_SKIP_SIMTESTS=1 cargo nextest run -p <crate>`
- 单独技术栈路径：`dex-sui/` 走 cargo、`dex-ui/` 走 pnpm

### 文档约定
- 决策日志 `docs/decision-log.md`（追加 DEC-xxx，不删旧条目）
- 操作日志 `docs/log.md`（append-only，顶部最新）
- 变更记录写在各 doc 底部，不入 log.md
- 主题 slug 用 kebab-case 英文，贯穿整个工作流

### 条件触发规则（补充）
- 涉及金额精度 → 禁止浮点，使用 quantums 整数体系
- 涉及 migration → 运行 `diesel migration run` 验证
- 涉及关键模块 → 必须触发 tester
```

（以上为 dex-sui 的实际内容，仅作示例；其他项目按自己业务填）

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

**贡献者 / dex-sui 自消耗（本地开发模式）**

```bash
# 根目录（/data/rsw/）clone
cd /data/rsw
git clone git@github.com:duktig666/roundtable.git

# 在项目里用 --plugin-dir 指向本地 clone，改 plugin 立刻生效
cd /data/rsw/dex-sui
claude --plugin-dir /data/rsw/roundtable
```

**不推荐 symlink 到 ~/.claude/plugins/ 的方案**（C）：跨项目全局生效但不受 per-project userConfig 控制，与"不同项目 critical_modules 不同"的诉求冲突。

---

## 4. 命名空间与 scope

- **命名空间**：`/roundtable:workflow`、`/roundtable:bugfix`、`/roundtable:lint`（Claude Code 自动为 plugin 加前缀）
- **Scope（D5 最终决策：user）**：
  - **user** scope（`~/.claude/plugins/`）：**推荐** —— 装一次，全局所有项目可用；完美适配"根目录启动 Claude Code"团队习惯
  - project scope：B-0 下无意义，本就没 userConfig 可存
  - local scope：同理不需要
- **团队工作流**：
  - 根目录 `/data/rsw/` 启动 Claude Code → plugin 已装（user scope） → 通过 D9 机制识别 target_project（dex-sui / dex-ui / ...） → 读那个项目的 CLAUDE.md → 跑架构流程 → 落盘到那个项目的 `docs/design-docs/`
  - 子项目内启动 Claude Code → `git rev-parse` 直接拿到项目根，跳过 D9 的 AskUserQuestion 步骤

---

## 5. 前置依赖与边界

### 5.1 前置
- Claude Code CLI 支持 `/plugin install`（当前版本已支持）
- Claude Code 支持 `userConfig` 安装时弹窗（需确认最低版本 —— 在 FAQ 中列为待核实项）
- 项目 CLAUDE.md 自动加载机制（原生支持）

### 5.2 兼容性
- 现有 `/data/rsw/.claude/` 原型不改动，作为参考样本保留
- dex-sui 迁移到 plugin 后，原 `.claude/agents/` 下自建文件**可选保留或删除**：保留（在 merge 时 user agent 会 override plugin agent）会导致"改了 plugin 没生效"的困惑，推荐迁移完成后删除

### 5.3 路径限制
- Plugin 内部不能 `../` 引用外部文件 —— 所有模板、示例必须放在 plugin 仓库内
- Plugin agent 运行时读的是**用户项目当前目录**，不是 plugin 目录；所以 `${user_config.docs_root}` 必须是相对项目根的路径

---

## 6. 关键决策与权衡

### D1 design-doc 落盘位置

| 方案 | 决策 |
|------|------|
| **选择** | **B 仅 roundtable/docs/design-docs/roundtable.md** |
| 备选 | A 仅 dex-sui；C 双份 dex-sui 主；D 双份 roundtable 主 |
| 理由 | single source of truth，避免双份漂移维护成本；plugin 面向所有用户，文档本应归属 plugin 仓库本身 |
| 落地状态 | 2026-04-17 已从 `dex-sui/docs/design-docs/moongpt-harness-plugin.md` 迁至 `duktig666/roundtable`（本文件），dex-sui 副本已删除，dex-sui 的 `decision-log.md` DEC-010 的"相关文档"字段指向本仓库 URL |

### D2 项目参数化方式（2026-04-17 重评：由 C 改为 B-0）

**初版决策 C 被用户挑战后重新评估**：经过讨论，原 C 方案的 6 项 userConfig 字段中 5 项是过度设计（`lint_cmd` / `test_cmd` / `primary_lang` 可自动检测；`critical_modules_hint` / `design_ref_hint` 与 CLAUDE.md 重合），仅 `docs_root` 有保留价值，但也可通过运行时检测 `docs/` 或 `documentation/` 目录替代。

更关键的是团队习惯是**从根目录（非 git 的 `/data/rsw/`）启动 Claude Code**，一个 Claude 会话要服务多个子项目（dex-sui / dex-ui / roundtable），单一的 userConfig 值天然无法表达 per-project 差异。

| 方案 | 决策 |
|------|------|
| **选择** | **B-0 零 userConfig**：plugin 安装不弹任何窗，全靠 CLAUDE.md + 运行时自动检测 + 目标项目识别（D9） |
| 备选 | A 纯 userConfig；B-1 仅保留 docs_root 一个字段；C 原混合方案（多字段 userConfig） |
| 理由 | (1) 弹窗零门槛，真正做到"一行命令装完即用"；(2) SSOT 单一配置源（CLAUDE.md），git 版本管控；(3) 多项目天然 per-project；(4) lint / test / lang 自动检测已够准（读 Cargo.toml / package.json 等） |
| 风险 | 首次跑时自动检测可能错 —— 对策：agent 写任何文档前先 AskUserQuestion 确认目标路径；结果记入 session 记忆不重复问 |

**自动检测规则**（内联到各 skill / agent prompt）：

```markdown
## 工具链识别（task 开始时执行）

1. 目标项目识别（D9）：
   - 扫描当前 CWD 下含 `.git/` 的子目录作为候选池
   - 从用户任务描述里匹配子项目名（如 "dex-sui 的 xxx"）
   - 匹配成功 → target_project = 那个子目录
   - 失败 / 多候选 → AskUserQuestion 弹窗二选一
   - 已在当前 CWD 的 git 仓库内（`git rev-parse --show-toplevel` 成功）→ 直接用

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

| 维度 (0-10) | A 纯 userConfig | B-1 单 docs_root | B-0 零弹窗 ★ | C 原混合 |
|------------|----------------|-----------------|--------------|---------|
| 安装门槛 | 3（20+ 弹窗） | 7（1 弹窗） | **10**（0 弹窗） | 6（6 弹窗） |
| 多项目友好度 | 2（单值冲突） | 4 | **9**（天然 per-project） | 2 |
| 配置 SSOT | 4（两处） | 5 | **9**（只有 CLAUDE.md） | 4 |
| 可维护性 | 6 | 7 | **9** | 7 |
| 首次体验准确度 | 9（用户明确填） | 7 | **6**（依赖检测） | 8 |
| 灵活性 | 5（字段固化） | 6 | **9**（CLAUDE.md 任意） | 7 |
| **合计** | 29 | 36 | **52** | 34 |

**重新评估结果：B-0 大幅领先原 C 方案**。核心原因是团队多项目场景下"一个 userConfig 值"本质上无法满足需求；B-0 借助 Claude Code 原生的 per-project CLAUDE.md 机制把配置问题消解掉，同时零安装门槛。

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

### D4 根目录 clone roundtable 如何结合使用（用户新问题）

| 方案 | 决策 |
|------|------|
| **选择** | **D 混合**：默认 A（远程 install），贡献者 / dex-sui 自消耗用 B（`--plugin-dir`） |
| 备选 | A 纯远程；B 纯 --plugin-dir；C symlink |
| 理由 | (1) A 给一般用户最低门槛；(2) B 给贡献者即改即生效，闭环快；(3) C 隐式全局影响与 per-project 诉求冲突，放弃 |
| 风险 | 本地开发模式下，dex-sui 里 userConfig 存哪里？—— 对策：`--plugin-dir` 模式下 Claude Code 仍用项目 `.claude/settings.json` 读 userConfig，一致 |

| 维度 (0-10) | A 纯远程 | B 纯 --plugin-dir | C symlink | D 混合 ★ |
|------------|---------|-------------------|-----------|---------|
| 新用户上手时间 | **9** | 4（要懂 CLI flag） | 5 | **9** |
| 贡献者迭代速度 | 3（改要发 release） | **9** | 7 | **9** |
| 冲突风险 | 7 | 7 | 3（全局生效） | **8** |
| 文档清晰度 | 8 | 7 | 6 | **7**（要写两条路径） |
| **合计** | 27 | 27 | 21 | **33** |

### D5 Scope 默认推荐（2026-04-17 重评：由 project 改为 user）

**联动 D2 的重评**：既然 B-0 零 userConfig，project scope 的 `.claude/settings.json` 就失去存在理由（本来主要存 userConfig 值）。所有配置已经落在每个项目的 CLAUDE.md（git 管控，per-project），不需要 project scope 的 settings.json 再承担一份。

| 方案 | 决策 |
|------|------|
| **选择** | **user scope**（`~/.claude/plugins/`）—— plugin 装一次，全局所有项目可用 |
| 备选 | project scope（每项目各装一次，无意义）；local scope（personal override，但 B-0 下没东西可 override） |
| 理由 | (1) 根目录启动 Claude Code 是团队常态，user scope 最自然；(2) 业务配置走 CLAUDE.md（已 per-project git 共享），不需要 settings.json 再分层；(3) 一行命令装完所有项目立刻有，符合"别人易用"优先级 |

### D6 迁移策略

| 方案 | 决策 |
|------|------|
| **选择** | **B POC 增量** |
| 备选 | A big-bang；C 并行双存 |
| 理由 | 先通用化 architect + /workflow（最复杂，含三阶段工作流 + AskUserQuestion 逻辑），跑通 userConfig 链路后，批量改 analyst / developer / tester / reviewer / dba / bugfix / lint |

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
| 备选 | A 全 agent（原设计）；B 全 skill |
| 理由 | (1) architect 依赖 AskUserQuestion 逐个决策弹窗，这是核心体验（之前已投入大量约束设计）；(2) analyst 研究中也有交互式澄清需求；(3) developer / tester 读写大量代码，必须隔离上下文；(4) reviewer / dba 同理 |
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

**评分 A 略高于 C，但 A 的致命缺陷（AskUserQuestion 失效）一票否决 —— 量化分不捕捉"核心体验倒退"的一票否决权**。故选 C。

**对 D6（迁移策略）的影响（clarification，不是重投）**：P1 POC 的目标从"通用化 architect **agent**"调整为"通用化 architect **skill** + /workflow command"；P2 批量改"其他 agent" 细化为"analyst skill + developer/tester/reviewer/dba agent + /bugfix /lint command"。

### D9 目标项目识别机制（2026-04-17 新增，因 D2+D5 重评暴露"根目录启动"场景）

| 方案 | 决策 |
|------|------|
| **选择** | 任务内自动识别 + AskUserQuestion 兜底 + session 内记忆 + 用户可显式切换 |
| 备选 | A 强制用户在子项目根启动（违背团队习惯，否决）；B 要求用户每次 prompt 显式写"dex-sui 的 xxx"（体验差）；C 只看当前编辑文件路径（任务刚开始时无文件可看） |
| 理由 | 适配"根目录 `/data/rsw/` 启动 Claude Code"团队习惯；避免冷启动时无法识别；session 记忆降低重复询问成本 |

**算法**（skill/agent prompt 内联）：

```markdown
## 目标项目识别（每次任务开始时执行一次）

1. 在 session 记忆里找 `target_project` —— 存在且本任务未显式切换 → 直接复用
2. 尝试 `git rev-parse --show-toplevel`：
   - 成功（在子项目内启动）→ 用它，写入 session 记忆
   - 失败（根目录启动，`/data/rsw/` 非 git）→ 继续下一步
3. 扫描 CWD 下所有含 `.git/` 的一级子目录，得到候选池 `candidates`
4. 从用户任务描述里正则匹配候选池里的名字（如 "dex-sui"、"dex-ui"）：
   - 唯一匹配 → 用它
   - 多匹配 → AskUserQuestion 从命中项中选
   - 零匹配 → AskUserQuestion 从 candidates 全集中选
5. 用户显式说 "切到 dex-ui" / "改做 dex-ui 的 xxx" → 清空 session 记忆重跑识别
6. 跨项目任务（"dex-sui 的 A 和 dex-ui 的 B 都改"）→ 明确告知用户分拆成两个独立任务处理
```

**session 记忆实现**：在主会话 context 中持有 `target_project = "/data/rsw/dex-sui"`，所有后续 agent 派发在 prompt 里注入这个值。

---

## 7. 分阶段实施路线（D6 决策的展开）

| Phase | 动作 | 产出 | 成功信号 |
|-------|------|------|---------|
| **P0 建 repo**（2026-04-17 已完成） | duktig666 账号创建公开仓库；初始化 plugin.json / marketplace.json / LICENSE / README / CHANGELOG / CONTRIBUTING / .gitignore；建 `skills/` `agents/` `commands/` `hooks/` `examples/` 目录；从 dex-sui 迁入 design-doc 和 exec-plan 到 `docs/design-docs/roundtable.md` + `docs/exec-plans/active/roundtable-plan.md`；初始化 `docs/decision-log.md`（DEC-001）、`docs/log.md`、`docs/INDEX.md`；dex-sui 原副本删除 | 可安装 plugin 骨架（内容尚未通用化） | `/plugin marketplace add duktig666/roundtable` 成功；dex-sui `docs/design-docs/moongpt-harness-plugin.md` 已删除 |
| **P1 POC：architect skill + workflow command** | 把原型 `agents/architect.md` 改造为 **`skills/architect.md`**（保留 AskUserQuestion 三阶段流程，替换路径、删 dex-sui 术语）；改 `commands/workflow.md` 的编排逻辑区分"激活 skill"和"派发 agent" | 2 份文件 + userConfig schema（docs_root 至少） | dex-sui 本地 `--plugin-dir` 装上，`/roundtable:workflow` 能跑架构阶段，**AskUserQuestion 真实弹窗**，文档落到 `${docs_root}/design-docs/` |
| **P2 批量改剩余角色** | `skills/analyst.md`（另一交互式）；`agents/developer.md` `agents/tester.md` `agents/reviewer.md` `agents/dba.md`（隔离执行）；`commands/bugfix.md` `commands/lint.md` | 2 skill + 4 agent + 2 command | 全流程跑一遍，不残留 dex-sui 硬编码，skill / agent 分工清晰 |
| **P3 文档 + 模板 + onboarding** | `docs/claude-md-template.md`、`docs/onboarding.md`、`docs/migration-from-dex-sui.md`、`examples/dex-sui-snippet.md` | 4 份文档 | 任意陌生项目按 5 分钟 onboarding 能跑通 /workflow |
| **P4 dex-sui 自消耗闭环** | 在 dex-sui 删本地 `.claude/agents/` `.claude/commands/`（保留 `/data/rsw/.claude/` 作参考）；装 plugin；补 CLAUDE.md 的「## 多角色工作流配置」 section | dex-sui 改动 | `/roundtable:workflow 设计 xxx 功能` 和本次 architect 行为完全一致 |
| **P5 首个外部用户试装** | 挑一个 non-DEX 项目（比如 dex-ui 独立试）让新人跑 onboarding | 外部反馈 | 非 DEX 背景用户 1 小时内能完成配置 |
| **P6 v0.1 发布** | 打 tag、写 CHANGELOG、推 README | GitHub release | `/plugin marketplace add duktig666/roundtable` 生效 |

---

## 8. 性能考量（非主要，但列出）

Plugin 本质是 prompt 模板 + manifest，无运行时性能影响。关注点：

- **userConfig 变量数量**：弹窗 ≤ 6 项（当前 6 项：docs_root、lint_cmd、test_cmd、primary_lang、critical_modules_hint、design_ref_hint），超过 8 项考虑拆 profile 或挪 CLAUDE.md
- **CLAUDE.md 膨胀**：接入模板 section ≤ 100 行，超过时考虑拆子文档并在主 CLAUDE.md 引用

## 9. 安全与风控

- Plugin 不自动执行任何命令，只改 prompt
- `lint_cmd` / `test_cmd` 是 developer agent 在"完成后"跑的命令，要求在用户项目信任边界内；不引入额外权限
- userConfig 值存在项目 `.claude/settings.json`（project scope）或 `.claude/settings.local.json`（local scope），不含凭据信息

## 10. 测试策略

- **单元级**：每个 agent.md 的 `${user_config.xxx}` 占位符有 grep 清单，CI 校验无遗漏硬编码
- **集成级**：准备一个最小 demo 项目（`examples/demo-project/`），CI 走 `claude --plugin-dir ./roundtable --headless -p "/roundtable:workflow 帮我设计 xx"` 的端到端 smoke test
- **回归级**：dex-sui 自消耗是最好的回归 —— 现有 dex-sui 文档流程能继续跑

## 11. 兼容性与迁移

### 11.1 向后兼容
- dex-sui 在迁移期间可**并存**：`.claude/agents/` 的同名 agent 会 override plugin（Claude Code 合并规则：user/project level 优先于 plugin）。迁移完成后删本地，避免歧义。

### 11.2 迁移 runbook（dex-sui）
1. 安装 plugin：`/plugin install roundtable@roundtable`
2. 填 userConfig 弹窗（docs_root="docs"、lint_cmd="cargo xclippy"、test_cmd="SUI_SKIP_SIMTESTS=1 cargo nextest run"、primary_lang="rust"）
3. `git mv dex-sui/.claude/agents/ dex-sui/.claude/agents.backup`（保底）
4. 追加 `dex-sui/CLAUDE.md` 的「## 多角色工作流配置」section（按 §3.4 模板）
5. 跑一次 `/roundtable:workflow 对比测试` 验证：decision-log、log.md、design-docs 路径全部落在原位
6. 确认无回归后删 `.claude/agents.backup/` 和 `.claude/commands.backup/`

---

## 12. 讨论 FAQ

记录本次设计过程中用户提出的追问与回答（按时间追加）。

- **Q（用户初始输入）**：根目录 clone roundtable 如何与 plugin install 结合使用？
- **A**：见 D4 决策 + §3.7。简言之：普通用户不需要 clone，直接 `/plugin install`；贡献者 / dex-sui 自消耗用 `claude --plugin-dir /data/rsw/roundtable` 即改即生效；不推荐 symlink 到 `~/.claude/plugins/`（全局生效与 per-project userConfig 冲突）。

- **Q（architect 自问自答）**：AskUserQuestion 在 subagent 里用不了怎么办？
- **A**：已观察到 `No such tool available` 错误。作为替代，本 doc 在顶部「§0 决策待确认项」列出全部决策 + 推荐 + 量化评分，让用户在审阅时一次性裁决；在父 orchestrator 非 subagent 环境下（比如用户直接在主 Claude Code 跑 architect），AskUserQuestion 仍为首选。建议在 architect.md 里补一条 fallback 规则："检测到 AskUserQuestion 不可用时，在 doc 顶部集中列决策清单"。

- **Q**：为什么不做 `profile: rust-backend | ts-frontend | move-contract`？
- **A**：见 D7。(1) 同语言不同项目 critical_modules 差异很大（rust web 服务 vs rust DEX 撮合）；(2) profile 是"另一层参数化"，用户还要学一遍；(3) CLAUDE.md 自描述 + plugin 提供模板已经覆盖 80% 场景。未来若真需要，可以以 `userConfig.profile: enum` 方式增量加入，不冲突。

- **Q**：dex-sui 自消耗如何避免"plugin 改了要等 release 才生效"？
- **A**：D4 决策的 B 路径 —— dex-sui 永久用 `claude --plugin-dir /data/rsw/roundtable` 模式（贡献者模式），直到 plugin 足够稳定再切 remote。建议把 `--plugin-dir` 写入 dex-sui 的运行脚本（比如 Makefile `make claude` target）。

- **Q**：三份 variables（plugin.json userConfig / 项目 CLAUDE.md / 项目 `.claude/settings.json`）之间会不会冲突？
- **A**：Claude Code 的合并规则是 user > project > plugin（后者被前者覆盖）。我们的约定：userConfig 只放"路径 + 命令"这类机械拼接需要的静态值，CLAUDE.md 放"业务语义"，两者职责正交无覆盖；`.claude/settings.json` 只是 userConfig 的存储介质，用户一般不手改。

- **Q**：`/data/rsw/` 根目录不归 git，clone 下来的 roundtable 怎么保证不丢？
- **A**：roundtable **自己是独立 git 仓库**（GitHub），clone 下来的是工作副本，数据在 GitHub remote；`/data/rsw/` 作为工作空间，丢了重新 clone 即可。dex-sui 也是同理。这跟"`/data/rsw/` 不归 git"是一致的，各子项目独立。

- **Q（后续追问）**：现在的多角色工作流是否推荐用 Claude Code Skills 机制来实现？
- **A**：**部分是**。核实 Claude Code 官方文档后确认：Skill 跑在主会话上下文，**AskUserQuestion 可用**；Agent 跑在 subagent 隔离上下文，**AskUserQuestion 被系统级禁用**。两者各有优劣，不是二选一：
  - architect / analyst → **Skill**（需要交互决策弹窗，这是之前设计的核心体验）
  - developer / tester / reviewer / dba → **Agent**（需要隔离上下文读写大量代码）
  - `/workflow` `/bugfix` `/lint` → 保持 **Command**（轻量 prompt 模板）
  - 此结论已落到 **D8 决策**（§6），并调整 P1/P2 路线（§7）和目录结构（§3.1）
- **机制要点**：Skill 不能直接调 Task 工具派发 agent，但主会话激活 skill 后仍可调 Task；Skill 之间可通过 Skill 工具互调；一个 plugin 内 `skills/` `agents/` `commands/` 可共存无冲突；同名时 skill 优先
- **用户心智**：README 需清楚区分"交互式 role（skill，自动/主动激活）" vs "自主执行 role（agent，@mention 派发）"，避免"为什么 @architect 不启动 subagent" 的困惑

- **Q（对刚才 7 决策的影响评估）**：加入 Skills 机制后，D1-D7 是否需要重新投票？
- **A**：**不需要重投，仅 D6 有 clarification**：
  - **D1-D5、D7 不受影响**：落盘位置 / 参数化方式 / 分发形态 / 根目录 clone 用法 / Scope / 业务特定容纳 —— 都与"用 skill 还是 agent"正交
  - **D6（迁移策略）有 clarification 不重投**：B POC 增量的选择不变，但 P1 POC 目标从"通用化 architect agent"改为"通用化 architect **skill** + /workflow command"；P2 从"批量改 agent"细化为"analyst skill + 4 agent + 2 command"。详见 §7

- **Q（用户挑战 D2 是否过度设计）**：lint_cmd / test_cmd / primary_lang 能不能自动检测？critical_modules_hint / design_ref_hint 和 CLAUDE.md 不是重复吗？除了 docs_root 其他是不是过度设计？
- **A**：用户批判成立。评估 6 个 userConfig 字段：5 项是过度设计 —— lint/test/lang 读项目根 Cargo.toml / package.json 等能精准检测；两个 hint 字段与 CLAUDE.md 完全重合。唯一有保留价值的 docs_root 也能通过"检测 docs/ 或 documentation/"兜底。
- **结果**：**D2 由原 C 混合改为 B-0 零 userConfig**；自动检测规则写进各 skill/agent prompt。

- **Q（D2 重评后，多项目场景怎么办）**：用户常并行开发多个项目（dex-sui / dex-ui），每个项目 docs 要落到对应项目里。单一 userConfig 值无法表达 per-project 差异。
- **A**：这是 D2 B-0 的关键驱动。利用 Claude Code 原生的 per-project CLAUDE.md 发现机制 + 子项目自带 .git 的事实，改成"agent 运行时识别目标项目再写"。不存储全局 docs_root。

- **Q（团队习惯：从根目录 /data/rsw/ 启动 Claude Code，而非子项目内）**：根目录非 git，`git rev-parse` 失效；启动时 Claude Code 不知道这次任务是给哪个子项目做的。
- **A**：**新增 D9 决策** —— 任务内自动识别 + AskUserQuestion 兜底 + session 内记忆 + 用户可显式切换。算法：先查 session 记忆 → 再试 `git rev-parse` → 再扫 CWD 下含 `.git/` 的一级子目录构成候选池 → 从任务描述正则匹配 → 失败时 AskUserQuestion 弹窗。目标项目一旦确定，后续 agent 派发/skill 激活都带上这个值，落盘路径以它为基准。

- **Q（D5 Scope 从 project 改为 user 的原因）**：B-0 下 project scope 的 `.claude/settings.json` 失去存在理由（本来主要存 userConfig 值）。业务配置已经落在 CLAUDE.md（per-project git 共享）；plugin 本身装 user scope（`~/.claude/plugins/`）一次全局通用，完美适配根目录启动场景。所以 D5 由 project 改为 **user**。

---

## 13. 待确认项

- [x] D1-D8 决策已于 2026-04-17 确认
- [x] D2/D5 重评（B-0 零 userConfig + user scope）已于 2026-04-17 确认（团队根目录启动习惯暴露）
- [x] D9 目标项目识别机制已于 2026-04-17 确认
- [ ] Plugin 名称最终确定：是 `roundtable` 还是直接 `roundtable`？（当前 manifest 写 `roundtable`，留有扩展余地）
- [ ] `duktig666` 最终 GitHub 账号（ChainUp 组织还是个人 fork？）
- [ ] Claude Code userConfig 弹窗的最低支持版本是多少？需要在 README 里写明
- [ ] 是否要预留 `skills/` 和 `hooks/` 目录（v0.1 不用，但先放占位 README）
- [ ] 外部首发用户挑谁试装？（P5 需要真实新用户反馈）
- [ ] roundtable 许可证（MIT / Apache-2.0 / proprietary？）
- [ ] 是否追加 DEC-010（决策重要性够格，**推荐追加**，跟 DEC-002 "API 对标 Hyperliquid" 层级类似；DEC-009 已被返佣表改名占用）

---

## 14. 变更记录

- 2026-04-17 创建（architect Claude），阶段 1 弹窗因 subagent 环境不可用降级为 "decision-summary-in-doc-top" 模式；待用户审阅后转 Accepted 并追加 DEC-010
- 2026-04-17 追加 D8 决策（角色形态分配 Skills vs Agents 混合）—— 原因：原设计假设全 agent，但 AskUserQuestion 在 subagent 禁用，失去 architect 核心交互体验。核实官方文档后确认 hybrid 架构可行。同步更新 §3.1 目录结构、§7 P1/P2 路线、§12 FAQ（两条新追问）、§13 待确认项。D1-D7 均未受影响，无需重投
- 2026-04-17 用户确认 D1-D8 决策转 Accepted：D1 改 C→**B**（放弃 dex-sui 镜像，回归单一权威源，dex-sui 副本 P0 迁出后删除）；D2-D8 接受推荐（D2 混合参数化 / D3 单 repo / D4 混合 clone / D5 project+local 覆盖 / D6 POC 增量 / D7 CLAUDE.md 自描述 / D8 skill-agent 混合）。确认 plugin 名 `roundtable`（非 `-workflow` 后缀）、owner `duktig666`、许可证 Apache-2.0。追加 DEC-010 至 decision-log；产出 exec-plan `exec-plans/active/roundtable-plugin-plan.md`（6 天 P0-P6）
- 2026-04-17 **D2 / D5 重评 + D9 新增**（用户挑战触发）：
  - **D2 由 C 混合改为 B-0 零 userConfig** —— 原 6 项 userConfig 里 5 项是过度设计（lint/test/lang 自动检测；两个 hint 与 CLAUDE.md 重合）；docs_root 也改为运行时检测兜底
  - **D5 由 project 改为 user scope** —— B-0 下 project scope 失去存在理由，user scope 适配"根目录启动 Claude Code"团队习惯
  - **新增 D9 目标项目识别机制** —— 从根目录启动时自动识别 target_project（git rev-parse → 任务描述正则匹配 → AskUserQuestion 兜底 → session 记忆）
  - 同步更新 §2.1/§2.2/§3.2/§3.5/§3.7/§4/§6/§12/§13；plugin.json 删除 userConfig 字段；P1/P2 路线调整

---

> **本 doc 状态**：Draft，待用户确认 §0 决策清单后转 Accepted、补 DEC-010、产出 exec-plan（按 §7 分阶段路线展开）。
