# roundtable 决策日志

> 记录 roundtable 项目所有关键设计和技术决策。
> 新条目追加在顶部（最新在前）。
> 本文件是项目知识的权威来源。

## 条目格式

```markdown
### DEC-[编号] [标题]
- **日期**: YYYY-MM-DD
- **状态**: Proposed | Accepted | Superseded by DEC-xxx | Rejected
- **上下文**: 为什么需要做这个决策
- **决定**: 最终选择
- **备选**: 考虑过但未采用的方案
- **理由**: 为什么这么选（关键权衡）
- **相关文档**: design-docs/xxx.md 等
- **影响范围**: 哪些部分受影响
```

## 状态说明

| 状态 | 含义 |
|------|------|
| Proposed | 已提出，待确认 |
| Accepted | 已确认采纳，正在执行或已落地 |
| Superseded by DEC-xxx | 被新决策取代（保留原文不删，标注取代者） |
| Rejected | 讨论后否决 |

## 铁律

1. **不删除旧条目**：被取代的条目标记为 Superseded，不删除
2. **冲突报 diff**：新决策与旧决策冲突时，必须在新条目中引用旧条目编号
3. **编号递增**：DEC 编号只增不减，不复用

---

### DEC-002 基于 P4 自消耗反馈的三项增量改进（shared resource protocol / escalation / workflow matrix）
- **日期**: 2026-04-19
- **状态**: Accepted
- **上下文**: P4 自消耗闭环在 gleanforge 项目完成（见 `docs/testing/plans/p4-self-consumption.md`），识别出三类主要摩擦 —— (a) 共享资源协议隐式（exec-plan checkbox / log.md / decision-log / testing/plans 写权限靠 orchestrator 逐次 prompt 注入，并行派发时易 race）；(b) subagent 通信封闭性（tester / developer 遇到用户决策点只能文字建议，orchestrator 手动 relay 成 AskUserQuestion）；(c) workflow command 缺少阶段可视化（orchestrator 状态靠对话追踪，用户难以判断当前位置）。同时副带两个已知 plugin 层 bug：prompt 文件中英混杂（违反自家「跨阶段约束：prompt 英文为主」）、AskUserQuestion 弹窗给裸选项（用户难决策）
- **决定**:
  1. **每个 role 文件加 Resource Access 矩阵**（`Read` / `Write` / `Report to orchestrator` / `Forbidden`）—— 权限声明从隐式 prompt 注入升级为 role prompt 本体的一等公民 section，对 7 个 role 文件生效（3 skills + 4 agents）
  2. **agent 层加 Escalation Protocol + skill 层加 AskUserQuestion Option Schema**：
     - agents (developer / tester / reviewer / dba) 在最终报告追加结构化 `<escalation>` JSON 块（`type` / `question` / `context` / `options[label, rationale, tradeoff, recommended]` / `remaining_work`），orchestrator 自动解析并转 `AskUserQuestion` 再派发
     - skills (architect / analyst) 强制 `AskUserQuestion` 每个 option 必含 `label` / `rationale` / `tradeoff` / `recommended`（analyst 禁 `recommended`，保持事实层；architect 最多 1 个标 `recommended`）
  3. **commands/workflow.md 重写为阶段矩阵编排器**：
     - 引入 Phase Matrix（8 阶段 × `⏳ / 🔄 / ✅ / ⏩` 状态 × artifacts 列），每次阶段转场向用户汇报并更新
     - 新增 Step 4 并行派发判定树（4 条硬条件：PREREQ MET / PATH DISJOINT / SUCCESS-SIGNAL INDEPENDENT / RESOURCE SAFE；默认串行，满足四条且加速 >30% 才并行）
     - exec-plan checkbox 写入由 orchestrator **串行化**（即使并行派发 developer，orchestrator 代写 checkbox 避免 race）
     - 跨角色转场（developer → tester 等）必须用户确认；同角色顺承（P0.4 → P0.5）在无 Critical 发现时可自动推进
  4. **`_detect-project-context` 切换为"Read 内联执行"**：不再用 `Skill` 工具激活（下划线前缀 skill 在部分 Claude Code 版本激活失败），改为调用方 `Read` 该 markdown 文件后按 4 步内联执行；5 个调用方（workflow / bugfix / lint / architect / analyst）同步改
  5. **prompt 文件本体统一英文**：workflow.md / bugfix.md / lint.md 中英混杂的步骤描述改为英文，保留关键 domain 注释中文
  6. **版本号不 bump**：本轮累计为 alpha 迭代改进，`plugin.json` / `marketplace.json` 保持 `0.1.0-alpha.1`；CHANGELOG 走 `[Unreleased]` section
- **备选**:
  - **推翻双形态架构**（全 agent 或全 skill）：解决 subagent AskUserQuestion 禁用，但失去 architect 交互体验或污染主会话 context —— 见 DEC-001 已拒绝
  - **依赖 Claude Code 未来原生支持 Task 工具进度事件**：等待期内 P4 摩擦持续；本轮先做可控的增量
  - **每条改动各自独立 DEC（DEC-002/003/004/005）**：粒度过细，单轮改动语义 coherent，一条 DEC 足够
  - **仅改文档不改 prompt**：prompt 约束是 plugin 运行时行为的唯一载体，仅改文档不解决 race / relay 摩擦
  - **bump version 到 0.2.0-alpha.1**：本轮只增补结构化约束，无破坏性变更，不到 minor bump 门槛
- **理由**: (1) 报告已证实三条 top 都是增量演进，不推翻架构；(2) Resource Access 权限矩阵变隐式为显式，消除 per-dispatch prompt 负担；(3) Escalation + Option Schema 让"subagent 封闭 + AskUserQuestion 裸选项"两类摩擦在同一协议层解决；(4) Phase Matrix 让 orchestrator 状态对用户透明，配合并行判定树给出可证伪的加速决策；(5) inline _detect 是对 "Skill 激活失败" 的稳健规避，配合 session 记忆复用语义不变；(6) 不 bump 版本避免误导使用者以为 minor 行为变更
- **相关文档**: docs/testing/plans/p4-self-consumption.md（详细观察报告）、docs/design-docs/roundtable.md（原设计），本次改动具体落点见 feature branch 的 commit 1 / 2 / 3（git log 查）
- **影响范围**: 所有 skill / agent / command prompt 文件（7 + 3 = 10 个），decision-log 本条目；运行时行为变化表现在并行策略更明确、escalation 不再 relay、phase 可视化、_detect 激活方式改变；现有测试 / 用户接入流程无破坏

---

### DEC-001 多角色 AI 工作流打包为 Claude Code plugin（roundtable）
- **日期**: 2026-04-17
- **状态**: Accepted
- **上下文**: 用 Claude Code 做中大型项目开发时，单一对话容易失控；已有的单 agent 模式不足以支撑纪律化流程。需要一套"多角色协同 + plan-then-execute + 交互式决策"的通用工作流，能适配不同技术栈的项目，业务规则由各项目自描述
- **决定**:
  1. **分发机制**：打包为 Claude Code plugin，仓库 `github.com/duktig666/roundtable`，Apache-2.0 许可；用户通过 `/plugin marketplace add duktig666/roundtable` + `/plugin install roundtable@roundtable --scope user` 一行命令全局安装
  2. **角色形态混合**（D8）：architect / analyst 为 **skill**（主会话运行，保留 AskUserQuestion 决策弹窗）；developer / tester / reviewer / dba 为 **agent**（subagent 隔离上下文避免主会话污染）；命令保持 command
  3. **配置模型 B-0 零 userConfig**（D2）：plugin.json **不含 userConfig 字段**，安装零弹窗；所有配置走两条通道 —— (a) 运行时自动检测（扫 target_project 根的 Cargo.toml / package.json 等识别 primary_lang / lint_cmd / test_cmd；扫 `docs/` 或 `documentation/` 识别 docs_root）；(b) 每个项目的 CLAUDE.md「# 多角色工作流配置」section 声明业务规则（critical_modules / 设计参考 / 触发规则 / 工具链覆盖）。CLAUDE.md 声明值覆盖自动检测
  4. **Scope = user**（D5）：plugin 装在 `~/.claude/plugins/`，一次装所有项目通用；不依赖 project scope 的 `.claude/settings.json`
  5. **目标项目识别（D9）**：适配"从 workspace 根目录启动 Claude Code"场景。Skill / Agent 启动时按优先级识别 target_project —— session 记忆 → `git rev-parse --show-toplevel` → 任务描述正则匹配 CWD 下含 `.git/` 的一级子目录 → AskUserQuestion 弹窗兜底。识别结果 session 内记忆，用户可显式切换
  6. **实施策略（D6）**：POC 增量 —— P1 先通用化 architect skill + /workflow command + D9 识别机制，P2 批量改剩余角色，P4 真实项目自消耗验证
  7. **文档归属（D1）**：roundtable/docs/design-docs/roundtable.md 为唯一权威设计文档
- **备选**:
  - 全 agent 形态（一致性好，但 AskUserQuestion 在 subagent 系统级禁用，失去 architect 核心交互体验）
  - 全 skill 形态（AskUserQuestion 可用，但 developer / tester 读写大量代码会撑爆主会话 context）
  - 多 userConfig 字段（如 docs_root / lint_cmd / test_cmd / primary_lang / critical_modules_hint / design_ref_hint）：多项目场景下单一值天然冲突；lint/test/lang 本可自动检测；hint 字段与 CLAUDE.md 重合。评估为过度设计
  - project scope 安装：workspace 根启动时根目录非 git，project scope 无落脚点
  - 强制从子项目启动 Claude Code：违背常见场景
  - plugin 内置 profile 系统（rust-backend / ts-frontend 等硬预设）：抽象过早，同语言不同项目 critical_modules 差异大
- **理由**: (1) 零 userConfig 是最优的"一行命令装上即用"体验；(2) CLAUDE.md 作为单一配置源，天然 per-project，git 版本控；(3) 运行时自动检测对工具链精准度够（读项目根文件比用户手填还准）；(4) D9 识别机制填补 workspace 根启动场景的空白；(5) skill / agent 混合在同一 plugin 无冲突（已核实官方文档）
- **相关文档**: docs/design-docs/roundtable.md（完整设计 + D1-D9 量化评分）、docs/exec-plans/active/roundtable-plan.md（P0-P6 实施路线）
- **影响范围**: 本项目全部 skill / agent / command 定义；项目 manifest（plugin.json）
