---
slug: prompt-reference-density-audit
source: design-docs/prompt-reference-density-audit.md
created: 2026-04-23
status: Active
---

# Runtime Prompt 引用密度精简执行计划

## 总览

| Phase | 标题 | 预估 | 前置 | 关键风险 |
|-------|------|------|------|---------|
| P1 | Title 标签层清理 | 0.5h | DEC-029 Accepted | 低（5 处字面替换）|
| P2 | commands/workflow.md 热点收敛 | 1.5h | P1 | 中（42 命中判 "首处" 顺序精细）|
| P3 | 其他文件重复清理 | 1h | P2 | 低-中（8 文件逐个）|
| P4 | scripts/ref-density-check.sh + baseline | 0.5h | P3 | 低 |
| P5 | CLAUDE.md 同步 + DEC-010 状态行 | 0.2h | P4 | 低 |
| P6 | lint_cmd 本地跑 + workflow dogfood 验证 | 0.3h | P5 | 中（清理后 workflow 本身要自测）|

## P1 Title 标签层清理

### 目标

删除 5 处 title 标签内的 DEC/issue 括注（runtime prompt 本体），保 title 主体不动。

### 任务清单

- [ ] `commands/lint.md:65` `### 6. 决策状态与结构审计（DEC-025 扩）` → `### 6. 决策状态与结构审计`
- [ ] `agents/dba.md:146` `## 输出落盘（orchestrator relay 主路径；DEC-017）` → `## 输出落盘（orchestrator relay 主路径）`
- [ ] `agents/reviewer.md:128` 同上
- [ ] `commands/bugfix.md:57` `### Tier 判定（D1 双轴 + LOC；DEC-014）` → `### Tier 判定（D1 双轴 + LOC）`
- [ ] `commands/bugfix.md:100` `### Postmortem 硬约束（Tier 2，含 orchestrator 执行锚点；DEC-014 C1）` → `### Postmortem 硬约束（Tier 2，含 orchestrator 执行锚点）`

### 成功信号

`grep -rnE "^#+ .*DEC-[0-9]+" skills/ agents/ commands/` 0 命中。

### 风险与预案

Risk: 删 title 后引用该 title 的 hash-link 失效。
预案: 用 `grep -rnE "commands/lint\.md#决策状态" skills/ agents/ commands/ docs/` 扫内部链接，无命中可直接删。

---

## P2 commands/workflow.md 热点收敛

### 目标

34 个 DEC ref → ≤14；22 个 § ref → ≤10；3 个 issue# → 1-2 个。

### 任务清单

- [ ] **DEC-024 10 处 → 2 处**：
  - [ ] 保 line 20 `**渲染 locus = orchestrator**（DEC-024，与 ...）`；删同 line 20 内第二次 `（DEC-024，不新增事件类）`
  - [ ] 保 line 314 Step 5b 事件类 b 表格行的首处 `（DEC-024）`
  - [ ] 删 lines 317 / 318 / 384 / 386 / 388 / 545 / 547 的 `（DEC-024）` / "Phase Matrix re-emit（DEC-024）" 括注
- [ ] **DEC-013 §3.1.1 / §3.1a 各 3 处 → 各 1 处**：保首处删后续
- [ ] **DEC-006 5 处 → 2 处**：保首处 + A/B/C phase gating 分类段首处；其他删
- [ ] **DEC-018 3 处 → 1 处**：保首处
- [ ] **DEC-017 3 处 → 1 处**：保 §Step 7 Orchestrator Relay Write 段首
- [ ] **DEC-023 §3.3 / §3.4 / §6b 5 处 → 2 处**：保 §Step 6b 首 + 三级切换段首
- [ ] **DEC-005 / DEC-003 各 2 处 → 各 1 处**
- [ ] **issue #nn title 3 处**：
  - [ ] `commands/workflow.md:73` `## Step 0.5: FAQ Sink Protocol（issue #27；...）` → `## Step 0.5: FAQ Sink Protocol`（"常驻规则..." 条件保）
  - [ ] `commands/workflow.md:364` Stage 9 Closeout bold heading 删 `issue #26 + #30`
  - [ ] `commands/workflow.md:491` 行内 `issue #67 DEC-017 修订` 改为 `DEC-017`（删 issue# 保 DEC）

### 成功信号

`grep -cE "DEC-[0-9]+" commands/workflow.md` ≤ 14；`grep -cE "§[0-9]" commands/workflow.md` ≤ 10。

### 风险与预案

Risk: "首处" 判定字面顺序若删错导致规则失源。
预案: Developer 每删一处先 `grep -n "DEC-xxx" commands/workflow.md` 确认字面首次行号；用 Edit 工具保留首次行上下文完整。

---

## P3 其他文件重复清理

### 目标

per-file DEC 重复收敛。

### 任务清单

- [ ] `commands/bugfix.md`（8 DEC → ≤3）：P1 删 2 title + 行内 DEC-014 保首删 3
- [ ] `agents/tester.md`（7 DEC → ≤3）：行内重复 DEC-017 保首删 ~4
- [ ] `skills/_progress-content-policy.md`（6 DEC → ≤3）：保 DEC-004 schema 出处 + DEC-007 首处，删其余
- [ ] `skills/architect/SKILL.md`（6 DEC + 1 issue# → ≤3 + 1）：`### 阶段 3：exec-plan（...；issue #30）` 删 issue title；DEC-025 保 1 删 1
- [ ] `agents/dba.md` / `agents/reviewer.md`（P1 删 title + 行内 DEC-017 保首各删 ~3）
- [ ] `skills/analyst/SKILL.md`（4 DEC + 1 issue# → ≤2 + 1）：issue #30 行内单次保留；DEC-013 § ref 保首
- [ ] `commands/lint.md`（4 DEC → ≤2）：P1 title 删 + 行内 DEC-025/026 保首
- [ ] `agents/research.md` / `agents/developer.md` / `skills/_detect-project-context.md`：不动

### 成功信号

`grep -rnE "DEC-[0-9]+" skills/ agents/ commands/ | wc -l` ≤ 33（本 phase 后整体命中）。

### 风险与预案

Risk: skill/agent 删多 DEC ref 破坏 schema 契约说明可读性。
预案: 删改后跑 developer 语义自检（Read 清理后的文件全文，确认规则陈述仍完整可执行）。

---

## P4 scripts/ref-density-check.sh + baseline

### 目标

落盘 enforcement 工具 + baseline 锁定清理后水位。

### 任务清单

- [ ] `Write` `scripts/ref-density-check.sh`（内容见 design-doc §3.3；chmod +x）
- [ ] P3 完成后跑 `scripts/ref-density-check.sh --update-baseline` 生成 `scripts/ref-density.baseline`
- [ ] commit 两文件（baseline 需作者或 architect sign-off）

### 成功信号

- `scripts/ref-density-check.sh` 不带参数跑返回 exit 0（current == baseline）
- `scripts/ref-density.baseline` TSV 格式，每行 `<path>\t<dec>\t<sec>\t<iss>`

### 风险与预案

Risk: shell 兼容性（bash vs dash）/ grep BSD vs GNU 差异。
预案: `#!/usr/bin/env bash` + 保持 `grep -cE` 不用 `-P`；tester 阶段用 Linux / macOS 各跑一次。

---

## P5 CLAUDE.md 同步 + DEC-010 状态行

### 目标

规则固化到 target 项目自身 CLAUDE.md，并声明 DEC-010 Refines 关系。

### 任务清单

- [ ] `CLAUDE.md §工具链` `lint_cmd` 末尾 `&& scripts/ref-density-check.sh`
- [ ] `CLAUDE.md §条件触发规则` 表内"改 skill/agent/command prompt 本体（行内 DEC/issue 引用纪律；#22）"整行替换为 DEC-029 固化版（见 design-doc §3.4）
- [ ] `docs/decision-log.md` DEC-010 状态行 `Accepted` → `Accepted (Refined by DEC-029)`

### 成功信号

- `CLAUDE.md` 新 rule 可直 grep 到 `DEC-029`
- `docs/decision-log.md` DEC-010 状态行含 `Refined by DEC-029`

### 风险与预案

Risk: CLAUDE.md 被识别为 roundtable 自 CLAUDE.md 同时影响 target 项目默认（dogfood 递归）。
预案: 条件触发规则表在 `# 多角色工作流配置` 段内，只 roundtable 自己的 CLAUDE.md 生效；其他 target 项目的 CLAUDE.md 不同步本 rule（各项目自管）。

---

## P6 lint_cmd 本地跑 + workflow dogfood 验证

### 目标

验证清理不破坏 workflow 执行 + enforcement 生效。

### 任务清单

- [ ] 本地跑 `grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/ && scripts/ref-density-check.sh`，exit 0
- [ ] 故意 Edit 加一处 `（DEC-024）` 到 workflow.md 内某 DEC-024 已出现的行外，跑 lint，确认 exit 1 + 提示信息
- [ ] `git checkout -- commands/workflow.md` 恢复
- [ ] tester 阶段对 DEC-029 adversarial case 跑（per #22 方法论保 critical_modules 命中）
- [ ] `/roundtable:workflow` 在 gleanforge 或 dex-sui 跑一轮 E2E（CLAUDE.md §工具链 test_cmd），确认清理后 workflow 本体仍正常编排

### 成功信号

- lint 正向 pass + 反向 fail 测试 exit code 正确
- workflow dogfood E2E 不出新 bug（Phase Matrix / Step 5b / Step 6 / Step 7 / Step 8 全路径命中无 regression）

### 风险与预案

Risk: workflow.md 清理后规则陈述不完整导致 orchestrator 执行漂移（如 Phase Matrix re-emit 漏条件）。
预案: 首处锚点规则必须在 P2 每删一处后，Read 上下文核对"规则陈述完整性"—— tester 阶段以此作 T1 adversarial case。

---

## 变更记录

- 2026-04-23：新建（Active）
