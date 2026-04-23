---
slug: workflow-auto-execute-mode
source: 原创（issue #33）
created: 2026-04-20
status: Draft
decisions: [DEC-015]
---

# `/roundtable:workflow` Auto-Execute Mode 设计文档

## 1. 背景与目标（含非目标）

### 背景

`/roundtable:workflow` 默认高交互：每个 A 类 producer-pause（analyst ✅ / architect ✅ / Stage 9）等用户 `go`，B 类 approval-gate（Design confirmation）调 `AskUserQuestion` 等点选，内部决策点（exec-plan 要不要 / developer form 选 inline vs subagent 等）也逐个阻塞等回复。

在下列场景交互成本远大于决策价值：

- **批量 dogfood**：一次消化多个 P2/P3 issue，用户只想看最终 PR 合不合理
- **CI 场景**：无人工值守，每次 gate 永久阻塞
- **信任型自 dogfood**：用户已熟悉决策模板，`recommended` 选项可直接采纳
- **#43 batch 编排器前置依赖**：多 issue 并行调度依赖"单 issue auto 跑完"能力

### 目标

引入 auto 模式：orchestrator 读 flag 后在每个决策点自动采纳 `recommended: true` 的 option，phase gate 自动推进，用户只在**真 tie-break**（无 recommended）/ **subagent escalation** / **critical_modules hard regression** 时被打断。

### 非目标

- **不改 Phase Matrix 语义**（DEC-006）—— auto 只是 A/B 类 gate 的"批量预授权"，category 不变
- **不改 4 agent prompt**（developer/tester/reviewer/dba）—— orchestrator 读 flag 后自动处理，agent/skill 零感知
- **不抬到 target CLAUDE.md**（对齐 DEC-011 / DEC-012 "dispatch mode 是 orchestrator 内部策略" 边界）
- **不做每阶段粒度**（`ROUNDTABLE_AUTO=analyst,architect` YAGNI，v1 不造）
- **不豁免 critical_modules tester 派发**（verification-chain C 类强制依然成立；仅 hard regression 打断）
- **不豁免 lint + test 失败**（developer 完成后 failure 仍按 Step 6 规则 4 报告用户不静默重派）

## 2. 业务逻辑

### 2.1 Flag 优先链（三级，对齐 DEC-013）

```
CLI  /roundtable:workflow <task> --auto
  ↓  覆盖
env  ROUNDTABLE_AUTO=1
  ↓  覆盖
default  auto_mode = false
```

取值：`true` / `false`（布尔二态；不做 per-stage 粒度）。

### 2.2 决策点行为矩阵

| 决策位置 | manual 模式（现状） | auto 模式 |
|---------|-------------------|----------|
| A 类 producer-pause（analyst / architect / Stage 9）| 3 行 summary + 停等用户 `go` | emit `🟢 auto-go <role> ✅` 一行自动推进 |
| B 类 approval-gate（Stage 4 Design confirmation）| `AskUserQuestion` Accept/Modify/Reject | 选项含 `recommended` → 自动 Accept；否则强停走 manual 交互（text 模式 emit `<decision-needed>`）|
| 内部 `AskUserQuestion`（architect / analyst skill）| 弹窗等选 | 有 `recommended` → 自动采纳；否则强停 |
| Subagent `<escalation>`（developer/tester/reviewer/dba）| orchestrator 按 decision_mode 渲染 → 等用户 | option 含 `recommended` → 自动采纳重派；否则强停渲染 |
| C 类 verification-chain（自动交接）| 现状已自动 | 不变 |
| Tester hard regression / lint+test failure | 打断汇报 | 打断汇报（**不受 auto 影响**）|
| Exec-plan 豁免 | `AskUserQuestion` 询问 | 沿用 Step 1 中/大任务启发式自判；用户同步未问（`recommended` 即 "按体量决定"）|
| Developer form 选择 (Step 6b) | `AskUserQuestion` 询问 | 沿用小任务启发式自判（inline / subagent）|

### 2.3 强停打断 fallback

auto 模式下遇以下情况**必须**打断（即使 flag 设 true）：

1. 决策点所有 option 均无 `recommended: true`（真 tie-break；DEC-006 B 类 approval 原意保留）
2. subagent `<escalation>` 的 options 均无 `recommended`（同上）
3. Tester `<escalation>` bug report（业务 bug 永远人工）
4. lint 或 test 失败（Step 6 规则 4）
5. Format/schema 解析错误（现状行为沿用）

打断渲染方式与 manual 模式完全一致（modal `AskUserQuestion` / text `<decision-needed>`）—— auto 模式对 fallback 路径零侵入。

### 2.4 审计 trail

每次 auto 模式自动决策必须 emit 一行可观察记录，便于用户事后追溯：

- A 类：`🟢 auto-go <role> ✅ (auto_mode=on)`
- B 类：`🟢 auto-accept <role> design (recommended: <option_label>, auto_mode=on)`
- 决策点：`🟢 auto-pick <letter> <label> (auto_mode=on, why: <why_recommended>)`
- fallback 打断：`🔴 auto-halt: no recommended option at <decision_id>`（此时同时渲染 manual 版决策块）

这些 emit 归 C 类 verification-chain，不改 Phase Matrix category。

## 3. 技术实现

### 3.1 Orchestrator 实现位置

**唯一改动落点**：`commands/workflow.md`（+ `commands/bugfix.md` 通过 ref 继承）。skill / agent / README 均零改动。

#### 3.1.1 新增 Step -0 Auto Mode Bootstrap（置于 Step -1 之前）

```markdown
## Step -0: Auto Mode Bootstrap（DEC-015）

解析 `auto_mode` = `true` | `false`（默认 `false`）。优先级：CLI `--auto` > env `ROUNDTABLE_AUTO` > default。

注入：每次 `Task` 派发 prompt prefix + 每次 skill 激活 context prefix 加一行 `auto_mode: <value>`。
orchestrator 自身按 flag 选择 Step 5 Escalation / Step 6 phase gating 的 auto / manual 分支。

`auto_mode=true` 适用：批量 dogfood、CI 非交互、信任型自消耗。**不适用**于初次探索陌生决策域（recommended 缺失概率高会频繁 auto-halt）。
```

#### 3.1.2 Step 5 Escalation 加 `auto_mode` 分支

在现有 `decision_mode` 分支（modal / text）**之外**叠加一层判定（auto 优先；manual fallback）：

```
2. 按 auto_mode 分支：
   - auto_mode=true 且 option 含 recommended: true → 不调 AskUserQuestion / 不 emit <decision-needed>，
     直接将 recommended 的决策事实注入 prompt 重派 agent；emit 审计行 `🟢 auto-pick <letter> <label> (auto_mode=on, why: <why_recommended>)`
   - auto_mode=true 且所有 option 均无 recommended → 打断，emit `🔴 auto-halt: no recommended option at <esc-...>`，
     然后沿用 decision_mode 渲染路径（manual fallback）
   - auto_mode=false → 沿用 decision_mode 现行渲染（modal/text）
```

#### 3.1.3 Step 6 Phase Gating 加 `auto_mode` 分支

**A 类 producer-pause**：

```
A. producer-pause —— 阶段以用户可消费产物结尾。
   - auto_mode=false → 现行 3 行 summary 停等 `go`
   - auto_mode=true → emit `🟢 auto-go <role> ✅ (auto_mode=on)` 一行自动推进下一 stage
```

**B 类 approval-gate**（Stage 4 Design confirmation）：

```
B. approval-gate —— Accept/Modify/Reject。
   - auto_mode=false → 现行 AskUserQuestion / <decision-needed>（按 decision_mode）
   - auto_mode=true 且有 recommended → 自动 Accept，emit `🟢 auto-accept <role> design (recommended: <label>, auto_mode=on)`
   - auto_mode=true 且无 recommended → auto-halt 打断，沿用 manual 渲染
```

**C 类 verification-chain**：不变（现状已自动）。

#### 3.1.4 Step 1 / Step 6b 的 "inline AskUserQuestion" 处理

Step 1 规模判定模糊时 / Step 6b developer form 模糊时，orchestrator 原 spec 调 `AskUserQuestion`。auto 模式下：

- auto_mode=true + 有 recommended（按启发式命中）→ 直接采纳，emit `🟢 auto-pick ...`
- auto_mode=true + 无 recommended（罕见，启发式全过 tie）→ auto-halt

### 3.2 Skill 层（architect / analyst）

**零 prompt 改动**。skill 继续按 `decision_mode` 调 `AskUserQuestion` 或 emit `<decision-needed>`。auto 模式的决策采纳完全在 orchestrator 决策层，skill 不需知道 `auto_mode` 存在。

**边界确认**：skill 的 `AskUserQuestion` 仅在 `decision_mode=modal` 下调；modal + auto 组合时 orchestrator 必须**拦截** `AskUserQuestion` 的返回前？—— 不现实，工具调用由 Claude Code runtime 执行。因此 modal + auto 下 skill 行为仍是"弹窗等点选"，auto 采纳只对 text 模式 `<decision-needed>` 和 orchestrator 本身的决策块生效。

**实际策略**：
- **modal + auto**：弹窗照常弹；用户体验上 auto 失效（这是 modal 的本质约束）。文档明示 auto 推荐搭配 `decision_mode=text` 使用
- **text + auto**：完整 auto 生效路径（orchestrator 渲染 `<decision-needed>` 前读 recommended 自动采纳）

### 3.3 4 Agent（developer/tester/reviewer/dba）

零改动。现状已不访问 `decision_mode` / `auto_mode`，按 `<escalation>` JSON 上报，orchestrator 渲染决策块。

### 3.4 与 #30 的关系

#30 关注 manual 模式下 phase-end approval gate 缺失（analyst / architect silently skip）的补强。auto 模式显式豁免 A 类 producer-pause，两 issue 修改正交：

- 先 #33 落地 → auto 模式 Step 6 A 类分支产生 `auto_mode=on` 路径
- 再 #30 补强 `auto_mode=off` 路径的 summary 格式 / go 指令捕获严格度
- 无 merge 冲突（两 issue 各自改 Step 6 A 类不同子分支）

## 4. 关键决策与权衡

### D1. 路径：新 command vs 加 flag

**选 B（加 flag）** ★ 推荐

| 维度 (0-10) | A 新 `/autoworkflow` | B `/workflow --auto` ★ |
|------------|--------------------|----------------------|
| prompt 复杂度 | 4（复制一套 prompt）| **9**（+~15 行条件分支）|
| orchestrator 分支可读性 | 7（两 command 各自线性）| **8**（集中心智模型）|
| skill 对 caller 感知 | 3（必须感知）| **10**（零感知）|
| DEC-010 对齐 | 5（新 command 违反精简）| **10**（加法而非重复）|
| 维护负担 | 4（2x prompt 同步）| **9**（单源）|
| **合计** | 23 | **46** |

### D2. Flag 形态

**CLI `--auto` + env `ROUNDTABLE_AUTO` 两级** ★ 推荐

- 沿用 DEC-013 `--decision=modal|text` + `ROUNDTABLE_DECISION_MODE` 三级链模式，心智同源
- 不做每阶段粒度（`ROUNDTABLE_AUTO=analyst,architect`）—— YAGNI，无实际需求，v1 避免组合爆炸

### D3. Recommended 缺失 fallback

**强停 emit 决策块等用户** ★ 推荐

- 对齐 DEC-006 B 类 approval-gate 语义（真决策不绕过）
- 对比"选第一个"：静默错决策风险；对比"报错退出"：摧毁已完成 phase 产出
- 打断渲染沿用 manual 路径（modal/text），零新增实现

### D4. Exec-plan 策略 in auto

**按任务体量探测（与 manual 同启发式）** ★ 推荐

- auto 只节约"问用户 exec-plan 要不要" 的交互，不改"何时需要 exec-plan" 的判据
- Step 1 中/大任务启发式是已有判据，orchestrator 自判即可

### D5. #30 / #33 顺序

**先 #33 再 #30** ★ 推荐

- auto 显式豁免 A 类 gate，#30 补强 manual 路径；两 issue 正交
- 先 #33 可批量消化 P2 积压，并解锁 #43 batch 编排器依赖链

## 5. 影响文件清单

- `commands/workflow.md` — 新增 Step -0 Auto Mode Bootstrap (~6 行) + Step 5 Escalation 加 auto 分支 (~5 行) + Step 6 A 类 + B 类 加 auto 分支 (~8 行) + Step 1 / Step 6b 加 auto 注记 (~3 行)
- `commands/bugfix.md` — 通过 Step -1 ref workflow.md 自动继承；若其独立 bootstrap 段需单独引用 Step -0（~2 行）
- `docs/design-docs/workflow-auto-execute-mode.md` — 本文档
- `docs/decision-log.md` — DEC-015 置顶
- `docs/exec-plans/active/workflow-auto-execute-mode-plan.md` — 执行计划
- `docs/log.md` — orchestrator 聚合 `log_entries:` YAML flush

**不改**：
- 4 agent prompt（developer/tester/reviewer/dba）
- `skills/architect/SKILL.md` / `skills/analyst/SKILL.md`
- `skills/_detect-project-context.md` / `skills/_progress-content-policy.md`
- `README.md` / `README-zh.md`（v1 不抢发布节奏；v0.0.5 release notes 补章节）
- target CLAUDE.md 业务规则

## 6. 验收标准

- [ ] `/roundtable:workflow <task> --auto` 全程无阻塞跑完一个含 recommended 完整链的 medium 任务
- [ ] `ROUNDTABLE_AUTO=1 /roundtable:workflow <task>` 等效
- [ ] CLI `--auto` 优先级高于 env（CLI `--auto=false` 可覆盖 env 开）——**需确认语法**，见 §7
- [ ] 某决策点 option 无 `recommended` → auto-halt 并渲染 manual 决策块
- [ ] subagent `<escalation>` 无 recommended → auto-halt
- [ ] tester hard regression `<escalation>` → 打断不受 auto 影响
- [ ] lint 或 test 失败 → 打断不受 auto 影响
- [ ] `auto_mode=true` + `decision_mode=modal` → 文档化警示"auto 对 modal skill AskUserQuestion 无效，建议搭配 text"
- [ ] Audit trail `🟢 auto-go / auto-accept / auto-pick` + `🔴 auto-halt` 在终端 / TG 均可见
- [ ] 4 agent prompt 0 字节改动（grep verified）
- [ ] critical_modules tester 派发依然触发
- [ ] dogfood：`/roundtable:workflow #43 --auto` 跑通（依赖 #33 合并后自验证）

## 7. 待确认项

1. **CLI flag 语法**：`--auto` 作为布尔开关（无值即真），需否支持 `--auto=false` 覆盖 env？建议：支持 `--no-auto` 显式关，与 GNU 常规对齐；无 `--auto=false` 形态（避免与 `--decision=` 形态混淆）
2. **Step -0 vs Step -1 顺序**：auto_mode 与 decision_mode 两个 bootstrap 顺序可互换；推荐 auto_mode 先解析（Step -0），decision_mode 后（Step -1），因 auto 打断时依然需要 decision_mode 渲染
3. **README 更新时机**：v1 落地后 release notes 是否补用户文档章节？本设计默认 v0.0.5 stable 后再加（减小 PR scope）

## 8. 变更记录

- 2026-04-20 初版（issue #33 architect 输出；D1-D5 一揽子 Accepted by 用户 msg 380）
