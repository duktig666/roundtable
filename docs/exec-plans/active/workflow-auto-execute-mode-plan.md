---
slug: workflow-auto-execute-mode
source: design-docs/workflow-auto-execute-mode.md
created: 2026-04-20
status: Active
---

# Workflow Auto-Execute Mode 执行计划

## 总览

| Phase | 标题 | 预估 | 前置 | 关键风险 |
|-------|------|------|------|----------|
| P0 | Orchestrator bootstrap Step -0 | ~10 min | 设计确认 | flag 解析优先级歧义 |
| P1 | Step 5 Escalation 加 auto 分支 | ~10 min | P0 | 与 decision_mode 分支嵌套顺序 |
| P2 | Step 6 A/B 类 phase gating 加 auto 分支 | ~15 min | P1 | B 类 recommended 检测规则不清 |
| P3 | Step 1 / Step 6b inline 决策加 auto 注记 | ~5 min | P2 | — |
| P4 | bugfix.md ref 继承确认 | ~5 min | P3 | — |
| P5 | Tester 对抗评审 + 回归修正 | 单轮 30 min | P4 | critical_modules 多命中 |
| P6 | Reviewer 一致性巡视（可选） | 单轮 15 min | P5 | — |
| P7 | dogfood E2E（跑 auto 跑一个 medium issue） | ~20 min | P6 | recommended 缺失场景覆盖不全 |
| P8 | Closeout + PR | ~10 min | P7 | — |

## P0 Orchestrator Bootstrap Step -0

### 目标
在 `commands/workflow.md` 顶部插入 Step -0 Auto Mode Bootstrap，解析 `auto_mode` bool，注入后续派发 prompt。

### 任务清单
- [ ] 在 `## Step -1: Decision Mode Bootstrap` 之前插入 `## Step -0: Auto Mode Bootstrap` 章节（~6 行）
- [ ] 优先级链文案：CLI `--auto` > env `ROUNDTABLE_AUTO` > default=false
- [ ] 注入策略：`Task` prompt prefix + skill activation context prefix 加 `auto_mode: <value>`
- [ ] 使用场景提示：批量 dogfood / CI / 信任型；不适用初次探索陌生决策域
- [ ] 确认 Step -0 在 Step -1 之前（auto_mode 解析先于 decision_mode，理由：auto-halt 时依然需要 decision_mode 渲染）

### 成功信号
- workflow.md Step -0 段可独立阅读，无循环引用
- lint_cmd 0 命中

### 风险与预案
- 风险：flag 解析若未显式写 `--no-auto` 关闭语义，用户无法在 env 开启时临时关 →（设计待确认项 §7 item 1）推荐添加 `--no-auto` 显式关语法

## P1 Step 5 Escalation 加 Auto 分支

### 目标
在 Step 5 Escalation 的 "按 `decision_mode` 分支" 步骤之前加 "按 `auto_mode` 分支" 上层判定。

### 任务清单
- [ ] 在 Step 5 第 2 步 "按 `decision_mode` 分支" 之前插入 "2a. 按 `auto_mode` 分支"
- [ ] auto_mode=true + option 含 recommended → 直接注入决策事实重派 agent，emit `🟢 auto-pick <letter> <label> (auto_mode=on, why: <why_recommended>)`
- [ ] auto_mode=true + 无 recommended → emit `🔴 auto-halt: no recommended option at <esc-...>` + 沿用 `decision_mode` 渲染（fallback）
- [ ] auto_mode=false → 直接进入 `decision_mode` 分支（现状）
- [ ] 注：已存在的 `decision_mode` text 分支下 `active channel forwarding` 规则在 fallback 路径依然生效（auto-halt 后走 manual text 渲染仍须转 TG）

### 成功信号
- Step 5 三种 auto_mode × 两种 decision_mode 路径均可追溯
- grep `auto-pick` `auto-halt` 在 workflow.md 出现

## P2 Step 6 A/B 类 Phase Gating 加 Auto 分支

### 目标
Step 6 规则 1 的 A / B / C 三档 phase gating 各加 auto_mode 子分支（C 不变）。

### 任务清单
- [ ] A 类 producer-pause：`auto_mode=true` 时 emit `🟢 auto-go <role> ✅ (auto_mode=on)` 一行自动推进，不输出 3 行 summary 也不停
- [ ] B 类 approval-gate：`auto_mode=true` 且 option 含 recommended → 自动 Accept，emit `🟢 auto-accept <role> design (recommended: <label>, auto_mode=on)`；无 recommended → auto-halt 沿用 manual
- [ ] C 类 verification-chain：不变（现状已自动）
- [ ] Phase Matrix → category 映射注释保留（不改）

### 成功信号
- A / B 类 auto_mode on/off 4 路径在 prompt 中均可追溯
- Phase Matrix 1-9 stage 映射表（在 workflow.md 顶部 matrix）无改动

### 风险与预案
- 风险：B 类 Stage 4 Design confirmation 的 architect AskUserQuestion 在 modal+auto 下由 runtime 执行 orchestrator 拦截不了 → 设计 §3.2 已说明"modal + auto skill 弹窗照常"，文档示警搭配 text

## P3 Step 1 / Step 6b Inline 决策加 Auto 注记

### 目标
Step 1 规模模糊 `AskUserQuestion` 与 Step 6b developer form `AskUserQuestion` 加 auto_mode 注记。

### 任务清单
- [ ] Step 1 模糊判定处注记：auto_mode=true + 启发式命中某档 → 采纳，emit `🟢 auto-pick size=<medium|large>`
- [ ] Step 6b 三级切换第 3 级 per-dispatch 注记：auto_mode=true + 小任务启发式命中 → inline 采纳；否则 subagent 采纳；emit `🟢 auto-pick form=<inline|subagent>`
- [ ] 注记控制在 3 行内，不重写整节

### 成功信号
- Step 1 / Step 6b 原结构未被打散；auto 注记放子 bullet

## P4 bugfix.md Ref 继承确认

### 目标
确认 `commands/bugfix.md` 的 Step -1 引用 `commands/workflow.md` 时自动继承 Step -0 Auto Mode Bootstrap。

### 任务清单
- [ ] 读 `commands/bugfix.md` Step -1 ref 段
- [ ] 若仅引用 "Step -1 Decision Mode Bootstrap" 需扩为 "Step -0 / Step -1 Auto & Decision Mode Bootstrap"（~2 行）
- [ ] 若是泛引 workflow.md 顶部 bootstrap 段则零改动

### 成功信号
- bugfix 路径下 `/roundtable:bugfix --auto` 与 workflow 一致生效

## P5 Tester 对抗评审

### 目标
critical_modules 多命中（skill/agent/command prompt 本体 + workflow Phase Matrix + DEC-005 developer form rules）必派 tester 做对抗性评审。

### 任务清单
- [ ] 派发 roundtable:tester subagent（foreground，critical 必落盘）
- [ ] Tester 读 workflow.md / bugfix.md / design-doc / DEC-015 做 prompt 层静态对抗
- [ ] 评审点：flag 优先链自洽 / recommended 检测规则明确 / audit trail 完备 / fallback 不漏 / 与 DEC-006 不冲突 / 4 agent 零改动字节 verified
- [ ] Tester 落盘 `docs/testing/workflow-auto-execute-mode.md`
- [ ] 若有 Critical/Warning → round 2 post-fix inline 回填

### 成功信号
- Tester 报告 PASS 或 PASS-WITH-FINDINGS
- round 2 回归后 0 Critical

## P6 Reviewer 一致性巡视（可选）

### 目标
critical_modules 命中 → reviewer 走行数纪律 / 跨文件一致性巡视。

### 任务清单
- [ ] 派发 roundtable:reviewer subagent（critical 必落盘）
- [ ] 审查：workflow.md + bugfix.md + design-doc + DEC-015 交叉一致性
- [ ] Reviewer 落盘 `docs/reviews/2026-04-DD-workflow-auto-execute-mode.md`

### 成功信号
- Reviewer Approve 或 Approve-with-caveats

## P7 Dogfood E2E

### 目标
auto 模式真跑一个 medium 任务验证闭环。

### 任务清单
- [ ] 候选：`/roundtable:workflow <某 P2 issue> --auto`
- [ ] 观察：4 审计 emit 是否齐全 / 决策点 recommended 采纳是否正确 / auto-halt 场景命中 / lint+test failure 打断
- [ ] 记录到 `docs/testing/workflow-auto-execute-mode.md` §dogfood 章节

### 成功信号
- auto 全链无意外阻塞
- auto-halt / failure 打断路径命中

### 风险与预案
- 风险：recommended 缺失场景 dogfood 未覆盖 → 人工构造一次无 recommended 决策点验证 fallback

## P8 Closeout + PR

### 目标
落仓 commit + push + PR open。

### 任务清单
- [ ] git commit message 含 close #33 + 设计摘要
- [ ] PR title: `feat(workflow): add --auto mode with three-tier priority (DEC-015)`
- [ ] PR body: 设计要点 / 影响文件 / 验收清单
- [ ] push + gh pr create

### 成功信号
- PR 开成功
- GitGuardian 等 check pass

## 跨阶段约束

- 所有 prompt 改动必须过 lint_cmd（硬编码 grep 扫描 0 命中）
- 所有 orchestrator 决策路径的 audit trail 可在终端 / TG 观察（decision_mode=text 时转发规则 DEC-013 §3.1a 沿用）
- critical_modules 多命中：tester 必派 + reviewer 可选但推荐

## 变更记录

- 2026-04-20 初版（issue #33 architect 输出，跟随 design-doc 同轮）
