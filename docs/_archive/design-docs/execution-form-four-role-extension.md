---
slug: execution-form-four-role-extension
source: issue #20
created: 2026-04-22
status: Accepted
decisions: [DEC-023]
description: DEC-005 决定 3 follow-up —— tester / reviewer / dba 扩展支持 inline 形态（与 developer 同构三级切换；启发式复用 workflow §6b 不新增 per-role 阈值；默认仍 subagent；research 排除）。Refines DEC-005 决定 3 非 Supersede。
---

# 四角色执行形态扩展（DEC-023）

## 1. 背景

DEC-005 决定 3：「tester / reviewer / dba 不扩展 inline（大 context 无例外）」，基于 P4 实录的**大任务预设**（tester 17 suites / reviewer 全仓扫 / dba 跨库 schema）。

[issue #20](https://github.com/duktig666/roundtable/issues/20) 问题陈述：roundtable 被小项目（demo CLI / 单文件 bugfix / docs-only）使用时，强制 subagent 的"隔离价值"边际收益低，"冷启 + 派发开销"变成主要成本。

[docs/analyze/subagent-coldstart-overhead-20.md](../analyze/subagent-coldstart-overhead-20.md) 已沉淀事实层观察与 3 选项代价表；analyst 不选型，交 architect 承接决策。

## 2. 测量与证据

**测量方法**：`anecdote-only`（P4 dogfood 实录 + 文本推导，未做独立 inline vs subagent 对照实验）。

| 数据点 | 来源 | 数值 |
|------|------|------|
| developer subagent 小 CLI wall-clock | issue #20 body | ≥ 6 分钟 |
| 等价 inline 估算 | issue #20 body | < 1 分钟 |
| Delta | 推导 | ~5× |
| tester / reviewer 小任务 wall-clock | **未实测** | analyst Q1 flagged |

**冷启成分（推论）**：
1. 独立 context 重读 CLAUDE.md / skill / agent 本体（规模无关的固定成本）
2. 工具调度（pip install / pytest 启动）
3. progress protocol JSON echo

**§6b 启发式先例**：workflow.md §6b 对 developer 已定义 "单文件 / bug hotfix / wall time <2min / token <20k / 单模块内" 启发式并 Accepted 数月，为本 DEC 降低 "6 月漂移" 风险（DEC-005 备选 "auto 档" 原始拒绝理由）。

## 3. 决策

### 3.1 形态扩展（自明采纳）

tester / reviewer / dba 在既有 `subagent` 基础上**同样支持 `inline`**。默认仍 `subagent`（preserves DEC-005 context 保护纪律 + 向后零破坏）。

### 3.2 三级切换复用 DEC-005 §3.4.2 机制

与 developer 同构（降认知负担）：

| 级别 | 触发形式 | 示例 |
|------|---------|------|
| per-session | 用户 prompt `@roundtable:<role> inline` | `@roundtable:tester inline` |
| per-project | target CLAUDE.md `# 多角色工作流配置` 新键 | `tester_form_default: inline` |
| per-dispatch | AskUserQuestion，§6b 启发式命中 → `inline` = recommended | orchestrator 派发前触发 |

per-session > per-project > per-dispatch（与 DEC-005 同）。

### 3.3 启发式阈值复用 §6b 既有（不新增 per-role 阈值）

**决定**：沿用 `单文件 / wall time <2min / token <20k / 单模块内`；所有 4 角色同一判定。

**备选（拒绝）**：analyst Q5 提出 per-role 独立阈值（reviewer token 预算天然高于 developer）。拒绝理由：当前缺实证 per-role delta；先用统一阈值 dogfood 校准，证明需要差分后再 Refines。对齐 "证据驱动，不预支配置复杂度"。

### 3.4 边界与 context 保护

- `*_form_default` 省略 → `subagent`（向后兼容；现有 target 项目零改动）
- 大任务场景启发式自然落在 `subagent` 侧
- 用户 per-session 强制 `inline` 时 orchestrator **不做安全兜底拒绝**（用户自担 context 爆风险，同 DEC-005 developer inline 边界纪律）
- **research 角色排除**：research 由 architect skill 派发（DEC-003，非用户 trigger），交互模型与用户可选形态正交。analyst Q6 flagged，本 DEC 明确排除；`agents/research.md` 零改动

### 3.5 Resource Access 与 Progress

- **Resource Access 两形态一致**：tester 仍 `tests/*` Write；reviewer / dba 仍只读；DEC-017 relay 主路径对归档 .md 继续生效（reviewer / dba / tester **不 Write 归档 .md 无论形态**）
- **Progress**：`inline` 整段 skip `## Progress Reporting`（主会话已观察；与 developer inline 对称）
- **Escalation**：`inline` 形态直接调 `AskUserQuestion`；`subagent` 仍走 `<escalation>` block

### 3.6 Refines DEC-005 决定 3 非 Supersede

DEC-005 决定 1/2/4-7 全保留；决定 3 从"仅 subagent（无例外）"refines 为"默认 subagent + 可选 inline（per 3-level switch）"。保 decision-log 单调递增，对齐 DEC-003 对 D8 / DEC-020 对 §3.3 的 "Refines 非 Supersede" 和谐模式。

### 3.7 审计

form 解析为 `inline` 时 phase-gate summary 加行：

```
<role> dispatched inline (trigger: <per-session | per-project | per-dispatch>)
```

与 developer 对称（`commands/workflow.md` §Step 6b 既有规则）。

## 4. 失败模式与 6 月后评估

| 模式 | 触发 | 缓解 |
|------|------|------|
| per-project 误配置 | 大仓库设 `reviewer_form_default: inline` → reviewer 全仓扫爆主会话 | 用户自担；per-dispatch AskUserQuestion 仍兜底 |
| 启发式过保守 | 小任务仍强制 `subagent` → 改动失效 | 6 月 dogfood 校准阈值；per-role 差分 future issue |
| 启发式误判大为小 | reviewer inline 撑爆 1M context | per-dispatch AskUserQuestion 用户可覆盖；DEC-005 context 保护边界原语义 |
| 3 新键无人用 | 同 DEC-005 备选 "auto 档" 原始拒绝理由复现 | developer `developer_form_default` 使用率可作先行指标（analyst Q3 flagged） |

**6 月评估锚点**：
- 3 个 `*_form_default` 在 gleanforge / dex-sui 等 target 项目 CLAUDE.md 的声明率
- per-dispatch AskUserQuestion 的 inline / subagent 选择分布（orchestrator log）
- tester / reviewer inline 形态下 context 爆 / 误判事故数（应 = 0）

## 5. Open Questions（analyst 6 问应答）

| 问 | 应答 |
|---|------|
| Q1 tester/reviewer per-role delta 未实测 | 本 DEC 用 developer 样本 + 推论先行；future issue 追踪实测 |
| Q2 "撑爆主会话"失效边界未实证 | 本 DEC 不改 DEC-005 context 保护语义，仅加可选 opt-in；边界仍在用户侧 |
| Q3 `developer_form_default` 实际使用率未采集 | 归 future dogfood 观察项；不阻塞本 DEC |
| Q4 "角色形态 vs 运行时参数"分类 | 本 DEC 明确 `*_form_default` 属**业务偏好**（与 `developer_form_default` 同类），不违 DEC-001 D2；不违 DEC-012 "dispatch mode 不抬 CLAUDE.md" 边界（dispatch mode ≠ form selection） |
| Q5 per-role 阈值调整 | 本 DEC 拒绝，列为 future issue（§3.3 备选理由） |
| Q6 research 纳入范围 | 本 DEC 排除（§3.4；DEC-003 正交） |

## 6. 影响

**文件清单**：

| 文件 | 改动 |
|------|------|
| `agents/tester.md` | 新增 `## Execution Form` section（与 developer 同构） |
| `agents/reviewer.md` | 同上 |
| `agents/dba.md` | 同上 |
| `commands/workflow.md` §Step 6b | form gate 从 developer-only 扩到 4 角色；标题 "Developer Form Selection" → "Role Form Selection" |
| `commands/bugfix.md` §Developer Form Selection | 扩到 reviewer / dba / tester（保 "偏向 inline" 语义） |
| `docs/claude-md-template.md` | §角色偏好 新增 3 键 + 表述扩 4 角色 |
| `docs/decision-log.md` | DEC-023 置顶 |
| `docs/INDEX.md` | design-docs 条目追 |
| `docs/log.md` | decide \| DEC-023 条目 |

**不改**：`agents/research.md` / `agents/developer.md`（已有 Execution Form）/ Resource Access 矩阵 / Escalation Protocol schema / Progress event JSON schema / DEC-005 其他决定 / DEC-003 research 派发 / DEC-017 relay 契约 / Phase Matrix / critical_modules。

**运行时**：target 项目省略 3 新键则行为零变化（向后兼容）；声明后可用 inline 降小任务冷启。

## 7. 变更记录

- 2026-04-22 初版（DEC-023 Accepted，architect）

```yaml
created:
  - docs/design-docs/execution-form-four-role-extension.md

log_entries:
  - prefix: design
    slug: execution-form-four-role-extension
    actor: architect (inline)
    files:
      - docs/design-docs/execution-form-four-role-extension.md
      - docs/decision-log.md
      - agents/tester.md
      - agents/reviewer.md
      - agents/dba.md
      - commands/workflow.md
      - commands/bugfix.md
      - docs/claude-md-template.md
      - docs/INDEX.md
    note: "issue #20 P3 —— DEC-023 Refines DEC-005 决定 3：tester/reviewer/dba 扩展可选 inline 形态；三级切换复用 developer 机制；启发式复用 §6b 不加 per-role 阈值；research 排除；默认仍 subagent 向后零破坏"
```
