---
slug: coding-principles
created: 2026-04-21
updated: 2026-04-22
status: Reference-Template
decisions: []
description: 编码基线原则参考模板（非 plugin 强制）——六角色共用四条 P1-P4，用户按需复制到自己项目的 CLAUDE.md 启用
---

# 编码原则 参考模板

> slug: `coding-principles` | 状态: Reference-Template | 源头: [andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills)（基于 Karpathy 关于 LLM 编码陷阱的观察，MIT）
>
> **本文件定位**：roundtable 向用户推荐的编码基线**参考模板**，**不是 plugin 强制条款**。
>
> - **传导机制**：CLAUDE.md 自动加载（主会话 + subagent cwd 层级继承），比 plugin 内嵌更可靠。
> - **用户启用路径**：复制 §2 四原则到你项目的 `CLAUDE.md`（或 `~/.claude/CLAUDE.md` user 级）即可，roundtable 工作流内所有子代理自动遵守。
> - **rsw 本仓库已启用**：`/data/rsw/CLAUDE.md` §通用规则 §编码原则 段内嵌四条基线。

## 1. 背景

六角色 roundtable 工作流缺统一的 LLM 编码陷阱防御基线——不顺手重构、不投机抽象、不扩设计范围、验收可验证。本模板压缩 Karpathy 四原则（Think Before / Simplicity / Surgical / Goal-Driven），用户按需采纳。

**为什么不做成 plugin 强制？**

- roundtable 是**工作流编排**插件，不是代码风格强制插件，两件事正交
- 外部使用者有自己的编码风格偏好，plugin 不该代选
- CLAUDE.md 路径同样覆盖 subagent（经本会话实测验证），无需 plugin 内嵌

## 2. 四条原则

| # | 原则 | 核心条款 | 典型反例 |
|---|------|---------|---------|
| P1 | Think Before Coding | 假设要说出来；歧义呈现多解不默默选；更简单做法就说出来；困惑停下问 | "导出用户数据"默默选 CSV 全量 |
| P2 | Simplicity First | 最少代码解决本次问题；不为单次使用造抽象；不写未要求的灵活性；不防御不可能场景；200 行能 50 行就重写 | "加折扣函数"写出 Strategy Pattern + 30 行 setup |
| P3 | Surgical Changes | 每行改动可追溯到本次需求；不改相邻风格/注释/格式；不重构没坏的；匹配现有风格；自产孤儿自清 | 改 bug 顺手 rename 变量 + 重排 imports |
| P4 | Goal-Driven Execution | 任务转可验证目标（测试优先）；多步任务先给"步骤 → 验证点"计划 | "让它工作"收工，无重复验收依据 |

**适用边界**：琐碎改动（typo、一行 fix）自行判断松紧；非琐碎改动四条全适用。

## 3. 六角色落点（参考，不强制）

用户如希望把四原则特化到 roundtable 各角色，可参考以下落点（自由采纳，不加入 plugin）：

| role | 主攻 | role-specific 落点 |
|------|-----|------------------|
| analyst | P1 | 呈现多解释与 tradeoff，不默默选 |
| architect | P1 + P2/P3/P4 翻译 | AskUserQuestion 给完整 tradeoff；不预留投机扩展点；不扩设计范围；design-doc 含可验证验收标准 |
| developer | P1-P4 原文 | 编码前锁定改动边界，超出边界另开 PR |
| tester | P4 + P2 | 失败测试先于实现（落点限 `tests/*`，DEC-001 D4）；避免过度 mock |
| reviewer | P1-P4 作 checklist | P3 违反默认 🟡 Warning（沿用 `agents/reviewer.md §审查维度` 三档）|
| dba | P3 + P2 | migration 不带非必要 schema；schema 不预留未来字段 |

## 4. 决策历史

本模板几经反复，决策路径记录以供参考：

| 时间 | 决策 | 理由 |
|------|------|------|
| 2026-04-21 初版 | 计划 6 prompt 内嵌 + helper 指针 | 假设 agent 会 Read 指针文件 |
| 同日 Review | 否决指针模式改内嵌 | agent 可能跳 Read；4 行稳定内嵌更可靠 |
| 同日阶段 C | 6 prompt 落地 `## Coding Principles` 段 + CLAUDE.md Rule A/B lint | 走完 dogfood 流程 |
| 2026-04-22 撤销 | Revert 阶段 C，改用户 CLAUDE.md 路径 | **关键发现**：CLAUDE.md 自动传导到 subagent（本会话实测），plugin 内嵌反而：(1) 造成 24 行 DRY 违反 / (2) 外部使用者被强加风格 / (3) 6 处同步 drift 风险；CLAUDE.md 路径一次修复三问题 |

**经验教训**：`plugin 内嵌 vs 用户 CLAUDE.md` 这类选择前，先用当前 session Agent 工具声明的 tool 列表验证子代理是否真的能继承 plugin 范围——skill/CLAUDE.md 的传导机制完全不同。

## 5. 路线

- **阶段 A**（2026-04-21）：✅ 本模板落盘
- **阶段 B**（2026-04-22）：✅ rsw 本仓库通过 `/data/rsw/CLAUDE.md` §通用规则 §编码原则 启用
- **外部使用者**：无需特别操作；若想启用，复制本文件 §2 到自己项目的 CLAUDE.md
