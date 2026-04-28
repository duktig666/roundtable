---
slug: progress-content-policy
source: 原创（issue #14 follow-up of DEC-004 / DEC-005）
created: 2026-04-19
status: Draft
decisions: [DEC-007]
---

# Subagent Progress Content Policy 设计文档

> slug: `progress-content-policy` | 状态: Draft | 关联: issue #14、DEC-004（progress 协议）、DEC-005（developer 双形态）

## 1. 背景与目标（含非目标）

### 1.1 背景

DEC-004 落地 subagent progress event 协议后，2026-04-19 roundtable 自消耗 dogfood 实测暴露主会话 Monitor 输出刷屏。典型片段：

```
● Monitor event: "dev round2 progress"
● 等通知。
● Monitor event: "dev round2 progress"
● 等通知。
● Monitor event: "dev round2 progress"
```

developer agent 在同一 phase 内持续发送**完全相同**的 summary 字符串，Monitor 每行触发一次通知，主会话被无信息量重复淹没，用户失去对 subagent 真实进度的感知。

### 1.2 根因

DEC-004 规定了 event schema（JSON 字段 + phase 颗粒度 + 3 种 event type），但**没有规定 summary 的内容质量**。Monitor 本身是事件驱动（每 stdout 行一条通知），不含节拍、去重、语义区分——这些本应由**源端 agent prompt**约束。当前 4 个 subagent（developer / tester / reviewer / dba）prompt 的 Progress Reporting section 对内容仅一条弱约束："summary ≤120 char 一句话"，缺失：

- 最小 emission 间隔（LLM 缺计时器，但可用代理指标）
- 连续相同字符串去重
- 每条 emit 必须携带可区分内容（子步骤 / 进度分数 / 里程碑）
- DONE / ERROR 终止信号与持续 progress 的语义分离

### 1.3 目标

在 4 个 subagent prompt 新增 **Progress Content Policy**，约束 emit 内容质量。具体：

1. **共享策略引用**：新建 `skills/_progress-content-policy.md`（下划线前缀标记 include-only helper，非独立 skill），4 agent 的 Progress Reporting section 一行引用。单一真相源。
2. **代理节拍**：以"实质进度门阁"替代时间间隔——LLM 在两次 emit 之间必须完成以下之一：(a) 一次实质文件写/编辑、(b) 一个已完成子里程碑、(c) ≥50% 新 token context。LLM 可自查确定性条件，替代无法执行的"30s"。
3. **连续 summary 去重**：相邻两次 emit 的 `summary` 字段禁止相同；若无新信息，宁可不发。
4. **内容差异化**：每条 emit 的 summary 必含以下至少一项——具体子步骤名（`editing workflow.md` / `running test 3/10`）、进度分数（`2/5 files done`）、里程碑标签（`milestone: round2-edit-complete`）。
5. **终止信号复用**：DONE = 本 dispatch 最后一次 `phase_complete`（可在 summary 前缀 `✅` 或在 detail 里标 `terminal: true`）；ERROR = `phase_blocked` + `<escalation>` 块（沿用 DEC-002）。**不新增 event type**，避免改 DEC-004 schema。orchestrator 凭 Task 返回判定 dispatch 结束。
6. **orchestrator 端 jq 兼底 dedup**：`commands/workflow.md` Step 3.5.3 的 jq pipeline 追加"连续相同输出折叠为 `...x3`"的轻量过滤，作为源端失守时的保护层。

### 1.4 非目标

- **不改 Monitor 工具本身**：Monitor 是 Claude Code 原生工具，协议外部化。
- **不改 DEC-004 event schema**：字段、event 枚举、JSONL 格式全保留，本设计是纯补丁性内容策略。
- **不改 subagent 执行模型（DEC-005 双形态）**：inline 形态仍不 emit；subagent 形态仍走 `{{progress_path}}`。
- **不做 prompt 瘦身**（属 issue #9）。
- **不改 target CLAUDE.md 规范**：policy 是 plugin 元协议层，与 DEC-001 D2 "CLAUDE.md 零 userConfig" 边界一致。

---

## 2. 业务逻辑

### 2.1 角色与交接

| 角色 | 负责 |
|------|------|
| 源端 agent（developer / tester / reviewer / dba）| 按 policy 决定何时 emit、每条 summary 填什么 |
| orchestrator（commands/workflow.md）| 启动 Monitor 时 compose jq pipeline，加兼底 dedup |
| 用户 | 主会话接收 Monitor 格式化通知，消费可读进度流 |

### 2.2 emit 决策流

subagent 每次考虑是否 emit 进度事件时按此序判断：

1. **门阁检查**：距上一次 emit 是否满足代理节拍三项之一？否 → 不 emit。
2. **去重检查**：新 summary 是否与上一次相同？是 → 不 emit。
3. **内容检查**：summary 是否含子步骤 / 进度分数 / 里程碑三项之一？否 → 改写 summary 直到符合，或不 emit。
4. **通过** → 按 DEC-004 schema `echo '{...}' >> {{progress_path}}`。

ERROR 路径（phase_blocked + escalation）**豁免门阁检查**——阻塞是重要信号必须立即发。

### 2.3 DONE 识别

orchestrator 无需专门解析 DONE token：Task 工具返回即表示 dispatch 结束。progress 流的最后一条 `phase_complete` 天然就是 dispatch 的 DONE。summary 文案建议（非强制）用 `✅` 前缀标记本 dispatch 的收官 phase，辅助用户识别。

---

## 3. 技术实现

### 3.1 组件清单

| 文件 | 操作 | 用途 |
|------|------|------|
| `skills/_progress-content-policy.md` | 新建 | 共享 policy 正文；`_` 前缀约定 = plugin 内部 include-only helper，不作为独立 skill 对外暴露 |
| `agents/developer.md` | 编辑 | Progress Reporting section 加 `### Content Policy` 子节，一行引用 + 本角色特化示例 |
| `agents/tester.md` | 编辑 | 同上 |
| `agents/reviewer.md` | 编辑 | 同上 |
| `agents/dba.md` | 编辑 | 同上 |
| `commands/workflow.md` | 编辑 | Step 3.5.3 jq pipeline 追加连续 dedup 过滤 |
| `docs/decision-log.md` | 追加 DEC-007 | policy 决策存档 |

`agents/research.md` **暂不改**：research agent 的 emit 生命周期短（research agent 默认不 emit progress，见其 Progress Reporting section），刷屏风险低；如后续反馈出问题再补。

### 3.2 共享 policy 文件（`skills/_progress-content-policy.md`）结构

```markdown
---
name: _progress-content-policy
description: Shared progress-emission content policy, included by developer/tester/reviewer/dba Progress Reporting sections. Not an independently activatable skill (underscore-prefix convention).
---

# Progress Content Policy

（不可单独激活；引用者：agents/developer.md / tester.md / reviewer.md / dba.md 的 Progress Reporting section）

## 1. 代理节拍（substantive-progress gate）
## 2. 连续去重（no-repeat-summary）
## 3. 内容格式（differentiated-content）
## 4. 终止与失败信号（DONE / ERROR）
## 5. 反例与正例对照
```

正文 ≤ 2 KB，纯策略规范；不重复 DEC-004 的 JSON schema。

### 3.3 agent 引用样式

每个 agent 的 Progress Reporting section 加如下小节（位于 Emit rules 之后、Fallback 之前）：

```markdown
### Content Policy

All emits MUST conform to the shared content policy in `skills/_progress-content-policy.md`.
Summary: substantive-progress gate before each emit, never repeat previous summary verbatim,
always carry one of: sub-step name / progress score / milestone tag. DONE signals use the
final `phase_complete` with `✅` summary prefix; ERROR signals use `phase_blocked` + `<escalation>`.
See the shared file for examples and edge cases.
```

### 3.4 orchestrator jq pipeline 兼底

`commands/workflow.md` Step 3.5.3 当前 pipeline：

```
tail -F ${PROGRESS_PATH} 2>/dev/null | jq -R --unbuffered -c 'fromjson? | select(.event) | "[" + .phase + "] " + .role + " " + .event + " — " + .summary'
```

改为追加 awk 连续 dedup 折叠（仅折叠相邻相同行，非全局 uniq）：

```
tail -F ${PROGRESS_PATH} 2>/dev/null | jq -R --unbuffered -c 'fromjson? | select(.event) | "[" + .phase + "] " + .role + " " + .event + " — " + .summary' | awk 'BEGIN{last="";n=0} {if($0==last){n++} else {if(n>1) print last" (x"n")"; else if(last!="") print last; last=$0; n=1} fflush()} END{if(n>1) print last" (x"n")"; else if(last!="") print last}'
```

折叠语义：**连续相同**行（即使 agent 源端失守）在 Monitor 通知里合并为一条 `... x3`；**非连续重复**（被其他事件打断后再次出现）不折叠——后者通常是有效的阶段循环信息。

awk 实现原因：jq 内建难以无状态 dedup（stdin 无 memory 需 foreach 累积器，写起来冗长且难调），awk 一行 BEGIN/END 处理更稳。

### 3.5 边界情况

| 情况 | 处理 |
|------|------|
| subagent 连续多个 phase 的 summary 偶然撞相同（比如多 phase 都在 `editing workflow.md`） | 源端规则要求至少带子步骤/分数/里程碑变化；若确撞同，source policy 说"宁可不发" |
| agent 漏 emit（网络/IO fail） | 按 DEC-004 §3.2 静默降级，policy 不引入新兜底 |
| tester/reviewer 没有 exec-plan 的 P0.n 颗粒度 | 使用自选 tag（如 `case-fuzz`, `review-deep-scan`），policy 的子步骤名字段天然覆盖此场景 |
| dispatcher 通过 `ROUNDTABLE_PROGRESS_DISABLE=1` 关停 | policy 不生效（`{{progress_path}}` 为空，所有 emit 静默 skip） |

---

## 4. 关键决策与权衡

### 决策 1：policy 物理放置——共享引用文件

| 选项 | 评分（0-10） |
|------|--------------|
| 维度 | **共享引用 `skills/_progress-content-policy.md` ★** | 内联 4 处 | 追加 DEC-004 §3.8 |
| 单源性 | **10** | 4 | 8 |
| 维护成本 | **9** | 5 | 7 |
| 额外 IO 开销 | 7 | **10** | 7 |
| 读取路径清晰 | **8** | 9 | 5 |
| 对齐 roundtable 现有范式 | **9**（_detect-project-context.md 已是 shared helper）| 6 | 6 |
| **合计** | **43** | 34 | 33 |

**选择**：共享引用文件。critical_modules 命中 prompt 本体，单源避免 4 份漂移；与 `skills/_detect-project-context.md` helper 范式一致。

### 决策 2：节拍编码——代理门阁

LLM 无计时器，"30s 间隔"不可执行。改"实质进度门阁"（文件写 / 子里程碑 / ≥50% 新 context）。

**理由**：
- 确定性条件，LLM 可自查
- 与 DEC-004 "phase-checkpoint level only, 3-10 events per dispatch" 原则同构
- 保持 issue #14 对"降噪"的实质诉求（避免无实质信息的 heartbeat）

### 决策 3：DONE/ERROR——复用现有 event 枚举

不扩 DEC-004 schema（扩会触发 Superseded 流程，成本高）。DONE 靠 Task 返回判定，ERROR 沿用 `phase_blocked` + `<escalation>` 双通道组合。summary 前缀 `✅` 作为软区分。

### 决策 4：orchestrator 端兼底——源端规范 + jq 轻量 dedup

**源端是主防线**，但 awk 一层 consecutive-collapse 作为保护，防止 agent prompt 不慎漂移时刷屏回归。awk 而非 jq stateful filter：调试友好、失败边界清晰。全局 uniq（`awk '!seen[$0]++'`）否决，因为"非连续重复"（如 case 1 / case 1 穿插出现）通常有效、不应过滤。

---

## 5. 讨论 FAQ

- **Q**: policy 不改 Monitor 工具会不会有天花板？
- **A**: 本 issue 明确"不改 Monitor"为非目标。Monitor 作为通用工具只管 stdout → 通知这一层；dedup / 语义区分本就属上游（pipeline jq/awk + 源端 agent）的责任。

- **Q**: 共享 policy 文件加重 subagent 每次 dispatch 的 Read 开销？
- **A**: `skills/_progress-content-policy.md` 预计 < 2 KB，相比 agent 本体（~10+ KB）与典型 exec-plan（~20+ KB），边际成本可忽略。

- **Q**: jq | awk 兼底会不会放过"应该告警的连续重复"？
- **A**: awk 只折叠、不吞——`...x3` 后缀仍呈现连续重复事实。用户看到 x3+ 的 summary 即可反推 agent prompt 在该条路径上失守，主动调试。

---

## 6. 变更记录

- 2026-04-19 创建 Draft
- 2026-04-19 back-feed `fflush()` 到 §3.4 pipeline（reviewer RW-01）—— 原因：developer 实装时发现 awk 默认 block-buffer 4 KB 会抵消 `jq --unbuffered` 的 streaming 语义，二段管道末端必须 per-line flush 才能让 Monitor 实时通知

## 7. 待确认项

（无 —— 4 决策点已通过 AskUserQuestion 确认）
