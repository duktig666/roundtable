---
slug: dispatch-mode-strategy
source: analyze/dispatch-mode-strategy.md
created: 2026-04-20
status: Accepted
decisions: [DEC-012]
---

# 前台/后台派发选择策略 设计文档

## 1. 背景与目标

### 背景

DEC-008（issue #15）引入 `commands/workflow.md` Step 3.5.0 gate —— `run_in_background: true` 才启 Monitor，前台派发 skip。但**上游决策缺失**：orchestrator 如何选择 `run_in_background` 的值？

`commands/workflow.md` / `commands/bugfix.md` / 5 agent prompt **均无** `run_in_background` 选择规则（见 analyst 报告 F1/F2），orchestrator 靠 LLM 自由心证。dogfood 实录显示"Monitor 通知 + 主会话缩进流双份信号"偶发（P8 bug），即误判典型。

### 目标

给 orchestrator 补一条**确定性规则**指导 `run_in_background` 选择，保留 DEC-004/007/008 所有投入，不丢并行派发能力，与 Claude Code Task 工具官方默认（foreground）对齐。

### 非目标

- 不动 DEC-004 Progress event schema
- 不动 DEC-005 developer 双形态（inline / subagent）
- 不动 DEC-007 Content Policy
- 不动 DEC-008 前台免 Monitor gate（DEC-012 正交补齐上游）
- 不决策 tester / reviewer / dba 是否支持 inline 形态（issue #20 scope）
- 不引入 target CLAUDE.md 新配置项（对齐 DEC-011 边界 —— dispatch mode 属 orchestrator 内部策略）

## 2. 业务逻辑

### 2.1 选择规则主流程

```
orchestrator 准备发 Task 调用
  ├─ 用户 prompt 含 per-session @声明？
  │   ├─ "@<role> bg" / "后台派 <role>" → force background
  │   └─ "@<role> fg" / "前台派 <role>" → force foreground
  │   （任一匹配 → 跳过 D2，进入执行）
  │
  ├─ 本 assistant message 内还有其他 Task 调用？
  │   ├─ 是（并行批 ≥2）→ 全部 `run_in_background: true` + Monitor（per DEC-008 gate）
  │   └─ 否（单发）→ `run_in_background: false`（默认，skip Monitor per DEC-008 gate）
  │
  └─ 模糊（用户意图不清 / 判据边界）→ AskUserQuestion（per-dispatch）
```

### 2.2 派发模式与 Monitor 的级联

| 派发模式 | DEC-008 gate | Monitor | 主会话可见 |
|---------|-------------|---------|-----------|
| foreground（`false` / 缺省） | skip | 不启 | 子 agent 工具调用缩进流实时回显 |
| background（`true`） | 进入 | 启动 | 仅 Monitor phase 级 summary |

DEC-012 决定派发 mode；DEC-008 决定 mode 后 Monitor 是否启动；两者串联为完整触发链路。

## 3. 技术实现

### 3.1 `commands/workflow.md` 修改

**新增 §3.4 "Dispatch mode selection"**（位于 Step 3 artifact chain 后、Step 3.5 Progress Monitor Setup 前）：

```markdown
## Step 3.4: Dispatch Mode Selection

每次 `Task` 派发前按序评估 `run_in_background`（第一匹配胜出）：

1. **用户声明**：prompt 含 `@roundtable:<role> bg|fg` / "后台派 <role>" / "前台派 <role>" 等中英文等价 → 按声明
2. **并行度**：本 assistant message 内 Task 调用数
   - 单发 → `false`（对齐 Claude Code 默认）
   - 并行批 ≥2 → 全部 `true`
3. **模糊兜底** → `AskUserQuestion` fg / bg 两选

前置：Step 4 并行判定必须先行，其结论是步骤 2 的输入。选完进入 §3.5.0 gate。
```

**精简记录**：本节代码块 2026-04-20 post-fix 从 16 行压至 10 行（~40% 精简），作为 issue #22 "reference density audit" 的 dogfood precedent —— 删 `（DEC-012）` title ref、删 per-session 7 种变体（保留 2 典型 + 等中英文等价兜底）、删 per-dispatch rationale/tradeoff 散文（留 AskUserQuestion 动作）、删独立"边界"段（本 Step 只处理 Task 派发天然无歧义）、前置声明合并入 1 行尾注。workflow.md 实装同步 precedent。

### 3.2 `commands/bugfix.md` 修改

Step 0.5 加一句引用：`bugfix 通常单 developer 派发 → D2 命中 foreground；reviewer / dba / tester 兜底派发同样走 §3.4（workflow）规则`。

### 3.3 5 agent prompt 不变

agent 本体不感知派发形态（DEC-008 §理由 (1)）。

### 3.4 Step 4 并行判定树不变

Step 4 决定"是否升级为并行派发"；DEC-012 §3.4 决定"派发模式是 fg 还是 bg"。两者正交：
- Step 4 判否并行 → 单发 → D2 → fg
- Step 4 判可并行 → 多发 → D2 → bg（全部）

## 4. 关键决策与权衡

### 决策 1：方向选择 = 方向 1（规则补齐）

| 维度 (0-10) | 方向 1 ★ | 方向 2（全前台删 Monitor） | 方向 3（全后台强制） |
|------------|---------|---------------------------|---------------------|
| DEC 投入保留 | **10** | 2 | 9 |
| 并行派发能力 | **9** | 2 | 10 |
| 对齐 Claude Code 默认 | **9** | 10 | 4 |
| 改动面 | **9**（2 commands + 1 DEC） | 3（Supersede 3 DEC + 删 600+ 行） | 6（Supersede DEC-008） |
| 与 #20 scope | **9**（正交） | 4（scope 缩小） | 8 |
| 主会话 UX | **8** | 6（长任务缩进流刷屏风险） | 7（phase summary 信息密度低） |
| **合计** | **54** | 27 | 44 |

### 决策 2：判据组合 = D2 + D4（两层）

| 维度 (0-10) | D2+D4 ★ | D1+D2 | D2 only | D1+D2+D4 |
|------------|---------|--------|---------|----------|
| 规则简洁度 | **8** | 6 | **10** | 5 |
| 用户逃生门 | **9** | 3 | 3 | **10** |
| 覆盖 S1-S5 | **9** | 8 | 7 | **10** |
| 改动面 | **9**（2 commands） | 6（含 5 agent 硬编码） | **10** | 6 |
| P8 bug 修复 | **9** | 9 | 9 | 9 |
| **合计** | **44** | 32 | 39 | 40 |

- D2+D4 胜出：规则扁平 + 用户 per-session 逃生门 + per-dispatch 兜底，不引入 per-role 硬编码（避免 critical_modules 多点改动）

### 决策 3：D4 层级 = 两级（per-session + per-dispatch）

- 不抬 target CLAUDE.md 配置项 —— dispatch mode 是 orchestrator 层策略，不是项目业务规则，对齐 DEC-011 边界
- 与 DEC-005 developer form 三级保持**有意区别**：DEC-005 涉及每角色形态（subagent vs inline），是项目级偏好；DEC-012 仅涉及 Task 派发时的 fg/bg 参数，是 orchestrator 运行时选择

### 决策 4：DEC-008 Accepted 保留

DEC-012 正交补齐 DEC-008 上游（决定 mode），不 Superseded。两者合璧：DEC-012 选 mode → DEC-008 根据 mode 决定 Monitor 是否启。

### 决策 5：#20 scope 边界声明

本 DEC **只决策 subagent 形态（Task 派发）下的 fg/bg**；不碰 "role 是否支持 inline 形态"（issue #20 独立决策）。若 #20 后续给 tester/reviewer/dba 加 inline 逃生门，inline 路径天然不经过 Task，不触发 §3.4。

## 5. P8 验收点

落地后应满足：

- **单发 developer subagent 派发**：D2 命中 fg，DEC-008 gate skip Monitor。主会话仅看到缩进流，不再出现"Monitor + 缩进流双份信号"
- **并行批派发**（reviewer + tester + dba 同期）：D2 全部 bg，每个 Task 独立 Monitor
- **用户显式 `@<role> bg` 单发**：尊重用户，Monitor 启动（即使单发）
- **用户显式 `@<role> fg` 并行批**：尊重用户，全部 fg 串行执行（Step 4 并行判定树应已拒，否则提示用户）

**测试归档位置**：`docs/testing/dispatch-mode-strategy.md`（按需 tester 兜底；与 DEC-008 follow-up pattern `docs/testing/step35-foreground-skip-monitor.md` 对齐）。

## 6. 变更记录

- 2026-04-20：初稿（issue #19）；DEC-012 Accepted
- 2026-04-20：reviewer post-fix —— W-01 section-number 统一 §3.4.5 → §3.4（6 处）；W-03 前置顺序声明；S-01 补 2 条 @声明等价模式；S-02 补 testing anchor
- 2026-04-20：issue #22 dogfood 精简 —— workflow.md §Step 3.4 实装从 16 行压至 10 行；§3.1 代码块同步；反向收敛 S-01（过度等价列表）

## 7. 待确认项

（无）
