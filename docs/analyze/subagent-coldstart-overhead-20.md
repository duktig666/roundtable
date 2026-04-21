---
slug: subagent-coldstart-overhead-20
source: 原创
created: 2026-04-21
---

# Subagent 冷启开销与小任务形态调研（issue #20）

## 背景与目标

DEC-005 确立四角色执行形态：developer 双形态（inline | subagent，默认 subagent），**tester / reviewer / dba 强制 subagent**（`agents/tester.md:3` "Runs in isolated subagent context"；DEC-005 决定 3 "tester/reviewer/dba 不扩展...仍仅 subagent（大 context 无例外）"）。

issue #20 问题陈述：强制规则建立在"tester 17 suites / reviewer 全仓扫 / dba 跨库 schema"的**大任务**预设上；但 roundtable 被小项目（demo CLI、单文件 bugfix、docs-only 变动）使用时，"隔离价值"边际收益低，"冷启 + 派发开销"变成主要成本。

目标：(1) 记录冷启事实层观察；(2) 陈列现行规则边界；(3) 列权衡表供 architect 后续 DEC 承接。Analyst **不做选型**。

## 调研发现

### F1 现行规则（事实）

| 文件 | 行号 | 规则 |
|------|------|------|
| `docs/decision-log.md` DEC-005 决定 3 | §414-416 | tester/reviewer/dba 仅 subagent；"全四角色双形态"选项因"维护成本 4× + reviewer/tester inline 撑爆主会话"被拒 |
| `docs/decision-log.md` DEC-005 备选 | §431 | "auto 档（按任务规模自动选）"被拒，理由："触发规则解释成本高；6 个月后易成摆设" |
| `commands/workflow.md` §6b | 410-425 | developer form gate 三级触发（per-session @声明 / per-project `developer_form_default` / per-dispatch AskUserQuestion 小任务启发式 "单文件 / wall time <2min / token <20k / 单模块内"）；**末段明示**"tester/reviewer/dba/research 的同类 key 忽略（DEC-005 边界）" |
| `commands/workflow.md` §3.5.0 | — | subagent 才进 progress protocol；inline 路径 skip |
| `docs/decision-log.md` DEC-012 决定 6 | §279 | 明确"本 DEC 只决策 subagent 形态下的 fg/bg；不碰 role 是否支持 inline（issue #20 独立）" |

### F2 实证观察（P4 dogfood）

来源：`docs/testing/p4-self-consumption.md`、issue #20 body。

- P4 dogfood 9 次 subagent 派发（4 developer + 1 tester + 1 reviewer + 1 bugfix + 2 组合）。
- issue #20 body 报告一例：developer subagent 实现几百行 Python CLI，**wall-clock ≥ 6 分钟**；等价 inline 估算 **< 1 分钟**。Delta 约 5×。
- **原因拆解（issue #20 作者自注为"推断，需验证"）**：
  1. 独立 context 重读 CLAUDE.md / skill / agent 本体
  2. 工具调度（pip install 串行、pytest 启动）
  3. progress protocol JSON echo
- p4-self-consumption §51 已独立记录"subagent 没有 AskUserQuestion"为摩擦来源，tester/reviewer 小任务摩擦同源。
- **未量化项**：tester / reviewer / dba 在 < 10 LOC / docs-only / <5 test suites 场景下的 wall-clock 与 token delta 缺落盘实录；issue #20 本身也没给 tester/reviewer 的独立数字（只引 developer 样本）。

### F3 冷启开销成分（推论，标注来源）

基于 DEC-004 / DEC-012 / DEC-005 文本推导：

- **每次 subagent 冷启必然发生**：agent 本体 Read、CLAUDE.md Read、注入变量解析、progress_path 初始化
- **规模无关的固定成本**：无论 task 是 5 LOC 还是 500 LOC，冷启开销常数
- **隔离价值随任务规模线性增长**：大任务 subagent 隔离保护主会话 1M context；小任务隔离保护的 context 本就 < 10k

### F4 "小任务"判定先例

`commands/workflow.md` §6b developer per-dispatch 启发式已有定义：**单文件 / bug hotfix / wall time <2min / token <20k / 单模块内**。若扩展到 tester/reviewer/dba，启发式可复用（事实：已有先例降低"6 个月漂移"风险 —— 对比 DEC-005 备选 "auto 档"被拒时尚无此先例）。

## 对比分析

三条路径的客观代价（不打推荐）：

| 维度 | (a) 保持现状 | (b) size-gated 双形态 | (c) 可配置阈值 (`*_form_default`) |
|------|-----|-----|-----|
| **规则改动面** | 0 | `agents/{tester,reviewer,dba}.md` 新增 Execution Form 段；`commands/workflow.md` §6b 从 developer-only 扩 4 角色；新 DEC Refines DEC-005 | (b) 全部 + `docs/claude-md-template.md` 新增 3 键 + 每角色 form 解析三级链 |
| **小任务 wall-clock（推论）** | 不变（issue #20 报 5× 延迟） | 小任务命中 inline 降至 ~主会话内嵌耗时 | 同 (b)；另加 per-project baseline 覆盖 |
| **小任务 token（推论）** | 不变 | 冷启固定成本消除；progress JSON emit 消除 | 同 (b) |
| **大任务 context 风险** | 低（DEC-005 原始保证） | 需启发式正确性；**误判为小任务** → reviewer 全仓扫 inline 撑爆主会话（DEC-005 决定 3 拒绝"全四角色双形态"的原始理由） | 同 (b)；另加 per-project 误配置风险（target CLAUDE.md 设 `reviewer_form_default: inline` 于大仓库） |
| **维护成本** | 0 | 4 角色 × 3 级触发 = 12 处规则点（developer 已有 3 处，新增 9 处） | (b) + claude-md-template 维护 + 覆盖链解释文档 |
| **UX** | 小任务"失去掌控感"（issue #20 + p4-self-consumption §51 同源） | 小任务恢复主会话可见性；但增加"这次会 inline 还是 subagent"的认知负担 | (b) + 项目级配置可调（优点）/ 配置爆炸（缺点） |
| **规则漂移风险（6 个月后）** | 低（单纯约束） | 中（启发式需 dogfood 校准；复用 developer §6b 先例降低风险） | 中高（3 个新 `*_form_default` 键 —— 对比 DEC-012 决定 4 明确"不引入 target CLAUDE.md 配置项"的边界声明） |
| **与 DEC-012 正交性** | 本就不触发 | inline 路径不经 Task → 不触发 DEC-012 §3.4（DEC-012 决定 6 预留该边界） | 同 (b) |
| **与 DEC-011 边界** | — | — | 需论证 `*_form_default` 是否"项目级业务规则"（DEC-005 为 developer 已开例）vs "orchestrator 内部策略"（DEC-011/012 边界）—— 属架构层 judgement |

## 必答 2 问

### 失败模式

- **(a) 现状**：小项目用户放弃 roundtable 或 override 成 inline 手动执行，规则形同虚设
- **(b) size-gated**：启发式误判大任务为小 → reviewer inline 爆 context；或启发式过保守 → 仍强制 subagent，改动失效
- **(c) 可配置**：`reviewer_form_default: inline` 被误用于大仓库；或 3 个新键无人用（DEC-005 备选"auto 档"原始拒绝理由）

### 6 个月后评价

- **(a)**：若小项目用例占比上升，现状成为 UX 债务触发反复讨论
- **(b)**：若 developer §6b 启发式在 dogfood 中证明稳定（DEC-005 已 Accepted 数月，可追溯），扩展到其他角色有先例降风险；否则漂移成 DEC-005 备选"auto 档"拒绝的复现
- **(c)**：若 `developer_form_default` 实际使用率低（可查 target 项目 CLAUDE.md 配置），新增 3 键更可能闲置

## 按需 4 问

本调研**部分不适用**：
- 痛点 / 使用者 journey：已在 §背景 + F2 覆盖
- 最简方案：(a) 即最简
- 竞品对比：roundtable 是自研编排，无直接对标；内部先例 = DEC-005 developer 双形态已是竞品参考

## 开放问题清单（事实层）

- **Q1**：issue #20 推断的"冷启 6 分钟"未给 tester/reviewer 独立实测；需新一轮 dogfood 在同一小任务分别派 inline developer vs subagent tester/reviewer，量化 delta。来源：issue #20 body "推断，需验证"；p4-self-consumption 仅记派发总次数未记 per-role wall-clock
- **Q2**：DEC-005 决定 3 的"reviewer/tester inline 撑爆主会话"基于"17 suites / 全仓扫"预设；小任务场景下该失效边界是否仍成立，未实证。来源：`docs/decision-log.md:430`
- **Q3**：`developer_form_default` 在真实 target 项目（gleanforge / dex-sui / moongpt-harness）CLAUDE.md 中的实际配置值与使用率未采集。来源：无
- **Q4**：DEC-012 决定 4 的"dispatch mode 不抬 CLAUDE.md"边界 vs DEC-005 `developer_form_default` 允许 per-project 配置 —— 两者对"角色形态 vs 运行时参数"的分类标准由 architect 承接判定。来源：`docs/decision-log.md:277`
- **Q5**：`commands/workflow.md` §6b 启发式（wall time <2min / token <20k / 单文件 / 单模块）扩展到 tester/reviewer/dba 时，阈值是否需按角色调整（例如 reviewer 的 token 预算本就高于 developer）。来源：`commands/workflow.md:414-415`
- **Q6**：`research` 角色在 DEC-005 / workflow §6b 中是否纳入本次讨论范围（DEC-005 未提 research；workflow §425 与 tester/reviewer/dba 并列忽略 form_default）。来源：`commands/workflow.md:425`

## FAQ

（待追问填充）

---

**Analyst observations（过程副记）**：
- 本报告由 `/roundtable:workflow` analyst 路径产出，skill 在主会话 inline 执行，未派 subagent（DEC-014 analyst 字段天然适配 inline）
- 未触发 `<decision-needed>` 块（scope 由 orchestrator brief 清晰预定），故 DEC-018 TG pretty render 本轮未被行权

```yaml
created:
  - docs/analyze/subagent-coldstart-overhead-20.md

log_entries:
  - prefix: analyze
    slug: subagent-coldstart-overhead-20
    actor: analyst (skill, inline)
    files:
      - docs/analyze/subagent-coldstart-overhead-20.md
    note: "issue #20 P3 调研 —— DEC-005 强制 tester/reviewer/dba subagent 在小任务场景的冷启开销权衡；3 选项 (a 现状 / b size-gated / c 可配置阈值) 客观代价表 + 6 事实层开放问题；analyst 不选型留给 architect"
```
