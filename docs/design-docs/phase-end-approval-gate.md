---
slug: phase-end-approval-gate
source: 原创（issue #30）
created: 2026-04-21
status: Draft
decisions: [DEC-006 §A producer-pause append-only clarification]
---

# Phase-End Approval Gate 统一协议 设计文档

## 1. 背景与目标

### 1.1 背景

issue #30（P1 bug）指出 DEC-006 A 类 producer-pause 在**两处实施点**缺失显式菜单 / 说理，导致 silent default 跳转：

- **症状 1（analyst）**：用户「问: ...」追问 → orchestrator 回答 FAQ → **直接**跳 architect，未回到菜单支持多轮追问
- **症状 2（architect）**：design-doc + DEC 落盘 → 菜单仅列 `go / 问 / 调 / 停`，**不显示 exec-plan 取舍**。architect 若判 "task 够小不写 exec-plan"，用户无从知情，违反 "deliberate choice not silent skip" 原则

同一抽象：**phase-end approval gate** 的菜单必须穷举 + 显式说理 + 禁止 silent default。

### 1.2 目标

1. 统一 A 类 producer-pause 菜单协议：**列全**可能动作 + 显式说理
2. 支持 analyst / architect 阶段的 Q&A **多轮循环**（直到用户 `go` / `调` / `停`）
3. architect 阶段的 `go` 拆成 `go-with-plan` / `go-without-plan`；后者必须给理由并写入 design-doc 或 log.md
4. Phase Matrix 的 "exec-plan 可选" 精确化为 "中/大任务默认产出、显式豁免可跳"

### 1.3 非目标

- 不改 DEC-006 A/B/C 三分法本身
- 不改 B 类 approval-gate（Stage 4 Design confirmation）协议 —— **architect `go-with/without-plan` 与 Stage 4 B 类 Accept/Modify/Reject 正交**（exec-plan 产出决定 vs 设计整体 Accept 决定）
- 不改 C 类 verification-chain 自动推进
- 不动 tester / reviewer / dba / developer（均属 C 类，非 A）
- 不新开 DEC（append-only clarification 延续 DEC-013 §3.1a 先例）
- **bugfix 流程的 A 类 Stage 9 Closeout** 由 `commands/bugfix.md` 独立 gate 协议管，本 issue 不扩展；workflow.md Stage 9 本 post-fix 覆盖（由 orchestrator 直接回答 FAQ，非 skill 回派）

## 2. 关键决策与权衡

### 2.1 D1：Q&A 多轮循环落点

**选择**：**orchestrator-only**（`commands/workflow.md` Step 6.1 A 类块明确 Q&A 循环语义）

**备选**：

| 方案 | 描述 | 评分 |
|------|------|------|
| **A. orchestrator-only ★** | Step 6.1 A 类条款明确：用户 `问: ...` → skill 回答 FAQ → orchestrator **重新 emit** 菜单等用户下一条 | **46** |
| B. skill-level loop | 每个 A 类 producer skill（analyst / architect）prompt 本体加 Q&A 循环逻辑 | 32 |

**理由**：
- A 方案中心化 gate 协议，只改 orchestrator，skill prompt 零改动
- B 方案把 orchestrator-level 的 gate 协议散到 skill，违反 DEC-009 "最小改动面" 心智
- 事实上 Q&A 循环的控制流天然在 orchestrator（skill 执行完 FAQ 就 return，orchestrator 决定是否重派菜单）

### 2.2 D2：architect exec-plan 取舍落点

**选择**：**双落点** —— architect SKILL.md 在菜单中列 `go-with-plan` / `go-without-plan`；orchestrator 校验 `go-without-plan` 时必须携理由

**备选**：

| 方案 | 描述 | 评分 |
|------|------|------|
| **A. 双落点 ★** | architect 菜单拆 `go-with-plan` / `go-without-plan`（必含理由 field）；orchestrator 检查理由并落盘到 design-doc §执行计划豁免 或 log.md | **44** |
| B. orchestrator-only | architect 菜单仍 `go`；orchestrator 在 skill 返回后独立问一次 exec-plan 取舍 | 35 |
| C. skill-only | architect 自己判断 + 落盘；orchestrator 不介入 | 25（现状；即 bug 根源）|

**理由**：
- 方案 A 把取舍决定留在用户手里（符合 "deliberate choice"），architect 只列可见选项与默认推荐；理由落盘由 orchestrator 保证（因 skill 可能遗忘）
- 方案 B 单方增加一轮 AskUserQuestion，UX 冗；skill 已在菜单里 emit 完整选项，不需要二次问
- 方案 C 就是当前 bug

### 2.3 D3：DEC 处理方式

**选择**：**append-only clarification to DEC-006 §A**（不新开 DEC）

**理由**：
- DEC-006 §A 已定义 4 选项 `go / 问 / 调 / 停`；本文档仅澄清菜单穷举要求 + Q&A 循环 + go-with-plan 拆分
- 延续 DEC-013 §3.1a post-fix（2026-04-20 #38 / 2026-04-21 #48）的 append-only 范式
- 不改 DEC-006 决定正文；影响范围段 post-fix 2026-04-21（issue #30）追加 ~3 行

## 3. 技术实现

### 3.1 `commands/workflow.md` Step 6.1 A 类改写

现有文本：

```
- A. producer-pause —— 阶段以用户可消费产物结尾...
  ```
  ✅ <role> 完成。
  产出：
  - <path1> — <desc>
  请阅读后告诉我：`go` / `调范围: ...` / 问题
  ```
  用户驱动：`go`/`继续` 推进；`问: ...` 留 FAQ；`调: ...` 以扩展 scope 重派；`停` 中止。
```

改为：

```
- A. producer-pause —— 阶段以用户可消费产物结尾...
  ```
  ✅ <role> 完成。
  产出：
  - <path1> — <desc>
  请阅读后告诉我：
    `go`（或 role-specific 变体；见下）
    `问: <具体疑问>`（回答后回到本菜单，可多轮）
    `调: <扩展或收窄 scope>`
    `停`
  ```
  **用户驱动**：
  - `go` / `继续`：推进下一阶段（architect 变体见下）
  - `问: ...`：orchestrator 回派 **同一** skill 回答 FAQ，skill 返回后 orchestrator **重新 emit** 本菜单等用户下一条（**Q&A 循环**直到 go / 调 / 停）
  - `调: ...`：以扩展 scope 重派
  - `停`：中止

  **architect 阶段变体**（Stage 3 完成后）：`go` 拆两条：
  - `go-with-plan`：写 exec-plan 后进入 Stage 4（推荐：中/大任务）
  - `go-without-plan: <理由>`：跳过 exec-plan 直接 Stage 4 design confirmation（理由必填；orchestrator 落盘到 design-doc 末尾「§执行计划豁免」或 log.md 条目）

  **菜单穷举原则**：列全可能动作，不 silent default；"跳过某产出" = deliberate choice，需显式说理并落盘
```

### 3.2 `skills/architect/SKILL.md` Phase 3 改写

现有：

```
### 阶段 3：exec-plan（按需）
11. 跨多模块 / 分阶段 / 数据迁移 / 破坏性变更 / 用户要求 → 写 `{docs_root}/exec-plans/active/[slug]-plan.md`
12. exec-plan 产出并入同一轮 `log_entries:` YAML
```

改为：

```
### 阶段 3：exec-plan（默认中/大任务产出 / 小任务显式豁免）

architect 在阶段 2 结束时 **必须** 在菜单显式列：

- `go-with-plan`：写 exec-plan 后 closeout（推荐：跨多模块 / 分阶段 / 数据迁移 / 破坏性变更 / 用户要求）
- `go-without-plan: <理由>`：跳过 exec-plan（小 bug fix / UI 微调 / 决策全在 DEC 已闭合 / 任务足够小 —— 理由 1-2 句）

用户选 `go-with-plan` → 11. 写 `exec-plans/active/[slug]-plan.md` → closeout。
用户选 `go-without-plan` → orchestrator 把理由落盘到 design-doc 末尾新增「§执行计划豁免」section（或 log.md fix-rootcause-style entry）→ closeout。

12. exec-plan（或豁免理由）产出并入同一轮 `log_entries:` YAML。
```

### 3.3 `skills/analyst/SKILL.md` §工作流程 step 8 改写

现有：`8. 回答用户追问，追加到 FAQ`

改为：

```
8. 回答用户追问 → 追加到 FAQ → 返回 orchestrator 由其重 emit phase-end 菜单（支持多轮追问；用户 `go` / `调` / `停` 才离开 analyst 阶段）
```

（analyst 不管控 Q&A 循环，仅响应单次问答；循环由 orchestrator 驱动）

### 3.4 落点清单

| 文件 | 改动 |
|------|------|
| `commands/workflow.md` | Step 6.1 A 类条款扩写（~12 行）明确 Q&A 循环 + architect go 变体 |
| `skills/architect/SKILL.md` | §阶段 3 改写（~6 行）菜单显式 go-with-plan / go-without-plan |
| `skills/analyst/SKILL.md` | §工作流程 step 8 改写（1 行）Q&A 循环由 orchestrator 驱动 |
| `docs/decision-log.md` | DEC-006 影响范围 post-fix 2026-04-21（#30）追加 ~3 行 |
| `docs/design-docs/phase-end-approval-gate.md` | 新建本文件 |
| `docs/INDEX.md` | design-docs/ 追加条目 |
| `docs/log.md` | orchestrator Step 8 flush |

**不改**：`commands/bugfix.md`（bugfix 无 A 类 producer-pause）/ 4 agent prompt / DEC-006 任何 Accepted 决定 / target CLAUDE.md 业务规则边界。

## 4. 影响范围

- 运行时：TG-driven / terminal-driven / auto_mode 下 A 类 producer-pause 菜单多 2 条 option（analyst Q&A 循环暗示 + architect go-with-plan/without），用户决策面扩大但不增加强制交互（auto_mode 下 `go-with-plan` = recommended → auto-accept）
- 与 DEC-006 §A / DEC-013 text mode `<decision-needed>` 协议 / DEC-015 §Auto-pick B 类规则：完全兼容；A 类菜单变化对 `<decision-needed>` 渲染路径透明（orchestrator 同样用文本块 emit）
- 与 DEC-009 log batching：`go-without-plan` 理由走 log.md fix-rootcause-style entry 或 design-doc inline 均接受

## 5. 测试策略

| 场景 | 期望 |
|------|------|
| analyst 返回 + 用户 `问: X` | FAQ 答 X 后 orchestrator 重 emit 菜单 |
| analyst 多轮 Q&A | 每次答完回到菜单；`go` 离开阶段 |
| architect 返回菜单 | 显示 `go-with-plan` / `go-without-plan: <理由>` 两条可见 |
| architect `go-without-plan: 任务仅 1 文件` | orchestrator 落盘理由；推进无 exec-plan |
| architect `go-with-plan` | 正常写 exec-plan |
| auto_mode=on + architect 中任务 | auto-pick `go-with-plan`（recommended）|
| auto_mode=on + architect 小任务 | auto-pick `go-with-plan`（保守默认）；小任务判定不由 orchestrator 自动做 |
| 纯终端（无 channel） | 行为同 TG/modal，菜单 `<decision-needed>` 文本 emit |
| `go` 直接（不含 -with-plan 后缀）| 降级兼容：orchestrator fuzzy 解析为 `go-with-plan`（保守默认）|

### 5.1 critical_modules 命中

`workflow Phase Matrix` + `Escalation Protocol` + `skill/agent/command prompt 本体` 3/3 → tester 必触发 + reviewer 落盘。

## 6. 变更记录

- 2026-04-21 初版（issue #30，Draft）
- 2026-04-21 post-fix（tester F1/F2 Critical + F3/F4/F5/F6 Warning 合并修复）：(F1) `go-with-plan` / `go-without-plan` 明示与 Stage 4 B 类 Accept/Modify/Reject 正交，不再写"进 Stage 4 design confirmation"混同；(F2) 豁免理由落盘路径固定 `log.md` prefix `decide`，orchestrator 不回写 architect 已 Accepted 的 design-doc 以守 architect Resource Access；(F3) architect SKILL §阶段 3 `go-with-plan` 显式标 `★ 推荐`（recommended: true）供 §Auto-pick 识别；(F4) fuzzy `go` 降级按 Step 1 size 分岔：中/大 → `go-with-plan` / 小 → `AskUserQuestion` 二选，避免单向掩盖 skip 意图；(F5) Q&A 循环边界：不重跑 Phase 0 context、5 轮软上限、skill log_entries 跨轮合并；(F6) Stage 9 Closeout `问:` 由 orchestrator 直接回答（查 design-doc/DEC/review/testing），非 skill 回派。F7-F10 归次 post-fix。

## 7. 待确认项

无阻塞；auto_mode=on 下全决策 auto-pick。
