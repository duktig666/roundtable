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
- **相关文档**: docs/design.md 的 §x
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

### DEC-001 多角色 AI 工作流打包为 Claude Code plugin（roundtable）
- **日期**: 2026-04-17
- **状态**: Accepted
- **历史**: 本决策承接自 dex-sui/docs/decision-log.md 的 DEC-010（plugin 名改为 `roundtable`、owner 改为 `duktig666`）。dex-sui DEC-010 的"相关文档"字段已更新为本仓库 URL
- **上下文**: `/data/rsw/.claude/` 下的多角色 agent 工作流（analyst/architect/developer/tester/reviewer/dba + /workflow /bugfix /lint）原本硬编码 dex-sui 专属路径、命令、业务术语，无法被其他团队复用。需决定通用化方式、分发机制、多项目适配机制
- **决定**:
  1. **分发机制**：打包为 Claude Code plugin，仓库 `github.com/duktig666/roundtable`，Apache-2.0 许可；用户通过 `/plugin marketplace add duktig666/roundtable` + `/plugin install roundtable@roundtable --scope user` 一行命令全局安装
  2. **角色形态混合**（D8）：architect / analyst 为 **skill**（主会话运行，保留 AskUserQuestion 决策弹窗）；developer / tester / reviewer / dba 为 **agent**（subagent 隔离上下文避免主会话污染）；commands 保持 commands
  3. **配置模型 B-0 零 userConfig**（D2）：plugin.json **不含 userConfig 字段**，安装零弹窗；所有配置走两条通道 —— (a) 运行时自动检测（扫 target_project 根的 Cargo.toml / package.json 等识别 primary_lang / lint_cmd / test_cmd；扫 docs/ 或 documentation/ 识别 docs_root）；(b) 每个项目的 CLAUDE.md「# 多角色工作流配置」section 声明业务规则（critical_modules / 设计参考 / 触发规则 / 工具链覆盖）。CLAUDE.md 声明值覆盖自动检测
  4. **Scope = user**（D5）：plugin 装在 `~/.claude/plugins/`，一次装所有项目通用；无 project scope 的 `.claude/settings.json` 依赖
  5. **目标项目识别**（D9）：适配团队"从根目录 `/data/rsw/` 启动 Claude Code"习惯。Agent 启动时按优先级识别 target_project —— session 记忆 → `git rev-parse --show-toplevel` → 任务描述正则匹配 CWD 下含 `.git/` 的一级子目录 → AskUserQuestion 弹窗兜底。识别结果 session 内记忆，用户可显式切换
  6. **迁移策略**（D6）：POC 增量 —— P1 先通用化 architect skill + /workflow command + D9 识别机制，P2 批量改剩余角色，P4 dex-sui + dex-ui 双项目自消耗验证闭环
  7. **文档归属**（D1）：roundtable/docs/design.md 为唯一权威；dex-sui 原副本已于 2026-04-17 迁出并删除
- **备选**:
  - 全 agent 形态（一致性好，但 AskUserQuestion 在 subagent 系统级禁用，失去 architect 核心交互体验）
  - 全 skill 形态（AskUserQuestion 可用，但 developer / tester 读写大量代码会撑爆主会话 context）
  - 多 userConfig 字段（6 项 docs_root/lint_cmd/test_cmd/primary_lang/两个 hint）：多项目场景下单一值天然冲突；lint/test/lang 本可自动检测；两个 hint 与 CLAUDE.md 内容重合。评估为过度设计
  - project scope 安装：根目录启动时 `/data/rsw/` 非 git，project scope 无落脚点
  - 强制从子项目启动 Claude Code：违背团队习惯
  - 放 `~/.claude/` 个人级（不通过 plugin 分发）：与"团队易分享"优先级冲突
  - plugin 内置 profile 系统（抽象过早，同语言不同项目 critical_modules 差异大）
  - 放 moongpt-harness 仓库（与其 CI/CD 自动化职责错位，且 `agents/` 目录命名空间冲突）
- **理由**: (1) 零 userConfig 是最优的"一行命令装上即用"体验；(2) CLAUDE.md 作为 SSOT，自然 per-project，git 版本控；(3) 运行时自动检测对工具链精准度够（读 Cargo.toml / package.json 比用户手填还准）；(4) D9 识别机制填补根目录启动场景的空白；(5) skill / agent 混合在同一 plugin 无冲突（已核实官方文档）
- **相关文档**: docs/design.md（完整设计 + D1-D9 量化评分）, docs/exec-plan.md（P0-P6 分阶段路线）
- **影响范围**: 全局 AI 工作流机制；dex-sui 在 P4 阶段将移除本地 `.claude/agents/` `.claude/commands/` 并切到 plugin
