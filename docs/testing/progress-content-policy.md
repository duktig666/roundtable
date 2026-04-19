---
slug: progress-content-policy
source: design-docs/progress-content-policy.md
dispatch_id: 94c1ff9e
created: 2026-04-19
role: tester
---

# Progress Content Policy (DEC-007) 对抗性测试报告

> 测试范围：`skills/_progress-content-policy.md`（新建）、`agents/{developer,tester,reviewer,dba}.md` 的 `### Content Policy` 子节、`commands/workflow.md` Step 3.5.3 + `commands/bugfix.md` Step 0.5 的 jq | awk pipeline、DEC-007 决策条目、issue #14 dogfood 回归。

## 执行摘要

| 等级 | 数量 | 典型代表 |
|---|---|---|
| Critical | 0 | — |
| Warning | 3 | W-01（awk 末行延迟交付）、W-02（C 类「非连续重复」呈现语义）、W-03（research.md 未对齐政策）|
| Suggestion | 4 | S-01 ~ S-04 |

**总体判断**：DEC-007 实现在源端策略（§A 6 项）、4 agent 对称（§B 4 项）、awk 折叠正确性（§C 10 项）、回归（§D 2 项）、DEC 边界（§E 3 项）共 25 个 case 全数 Pass 或 Pass-with-note。**无 Critical**。awk 状态机有一项固有延迟交付副作用（W-01）是真实 UX 风险，建议在后续 issue 讨论；其他 Warning 均为 cosmetic / 可选增强。**判定**：DEC-007 可流转 reviewer。

---

## 1. 范围

被测件：

- `skills/_progress-content-policy.md`（68 行；§1–§6）
- `agents/developer.md` §Progress Reporting → §Content Policy（lines 169–182）
- `agents/tester.md` §Progress Reporting → §Content Policy（lines 134–147）
- `agents/reviewer.md` §Progress Reporting → §Content Policy（lines 141–154）
- `agents/dba.md` §Progress Reporting → §Content Policy（lines 112–125）
- `commands/workflow.md` Step 3.5.3 Monitor 命令（line 174 + notes 182）
- `commands/bugfix.md` Step 0.5 Monitor 命令（line 40）
- DEC-007 decision-log 条目

未测（明确非目标）：DEC-004 event schema 本身（未改）、Monitor 工具实现（plugin 非目标）、`agents/research.md` Progress Reporting（设计 §3.1 明示「暂不改」，本轮验证该状态未被意外更改）。

---

## 2. 测试用例

### §A 共享 helper 内容审计（`skills/_progress-content-policy.md`）

#### A1 · Substantive-progress gate ambiguity（"read an edit" 借口）

- **输入**：LLM 推理 "我 Read 了一个文件就算 gate 触发吗？"
- **预期**：policy 明确只允许 "file write / edit landed on disk"；Read 不算。
- **实际**：§1 第一项 "a **file write / edit** landed on disk" — write/edit 用斜体强调，无歧义。`≥50% new context` 第三项特别注明 "not re-reads"。
- **判定**：Pass。

#### A2 · No-repeat edge: trailing whitespace / punctuation

- **输入**：两条 summary 仅差尾空格或句号。
- **预期**：policy 说 "MUST NOT equal ... verbatim" → 字面比较即可区分。
- **实际**：§2 "MUST NOT equal the previous emit's `summary` **verbatim**" — verbatim 明确；但 `"foo"` vs `"foo "`（尾空格）在 `$0==last` 的 awk 比较下**不相等**（不折叠）。策略层面"应视为重复"但未强制。
- **判定**：Pass-with-note → **S-01**：在 §2 加一句 "trivially different variants (trailing whitespace, terminal punctuation alone) SHOULD be treated as repeat; prefer skip."

#### A3 · Differentiated content: milestone-tag-only

- **输入**：summary 仅 `milestone: P0.2`（无其他文本）。
- **预期**：policy 接受 "milestone tag" 作为独立项 → 合规。
- **实际**：§3 "MUST carry at least ONE of" → 任一即可。示例 `P0.2 milestone: 4 agents synced` 含更多文本但不强制。裸 `milestone: P0.2` 字面符合。
- **判定**：Pass。

#### A4 · DONE prefix 规范性：✅ vs DONE vs [DONE]

- **输入**：用户读 `### Content Policy` 看到 `✅`，但没说是强制。
- **预期**：policy 明确 "convention (non-mandatory)" + orchestrator 靠 Task 返回判定 DONE，所以前缀是软约定。
- **实际**：§4 "Convention (non-mandatory): prefix summary with `✅`. No new event type; orchestrator uses `Task` return as authoritative DONE." — 清晰声明软约定 + 权威判据。4 agent 的 summary 说法 "the final `phase_complete` uses a `✅` summary prefix (no new event type)" 略措辞强于 helper（"uses" 不带 "convention" 修饰）。
- **判定**：Pass-with-note → **S-02**：4 agent `### Content Policy` 可把 "uses a `✅` summary prefix" 改为 "MAY prefix with `✅`" 以对齐 helper 软约定语义；目前偏差极轻，非 Warning。

#### A5 · ERROR channel: phase_blocked + escalation 是 AND 还是 OR

- **输入**：LLM 可能读成 "二选一"。
- **预期**：政策必须 AND。
- **实际**：§4 "emit `phase_blocked` **first** (gate-exempt), **then include** `<escalation>` JSON block" — 用 first/then 明确顺序 + AND 语义。4 agent `### Content Policy` 说 "`phase_blocked` + `<escalation>` block; both channels remain orthogonal" — `+` 和 "both" 都指向 AND，无歧义。tester.md §Ordering discipline 重复强调 1→2→3 步序。
- **判定**：Pass。

#### A6 · Fallback 对 DONE 信号的覆盖

- **输入**：`progress_path` 未注入时，DONE 信号需不需要？
- **预期**：完全静默（含最终 `phase_complete`）——fallback 优先于 DONE。
- **实际**：helper §6 table: "`ROUNDTABLE_PROGRESS_DISABLE=1` / empty `{{progress_path}}` → Policy inert; silent-skip per agent Fallback." developer.md 的 §Fallback "silently skip all emits" 与 helper 对齐。
- **判定**：Pass。

### §B 4-agent 对称（`agents/{developer,tester,reviewer,dba}.md`）

#### B1 · Position parity

- **检查方法**：四处 `### Content Policy` 均紧跟 `### Granularity`（tester/developer/reviewer/dba 分别在 granularity 后、Fallback 前）。
- **实际**：developer 125-186 / tester 87-151 / reviewer 86-158 / dba 86-129：4 处 position 一致，在 Emit rules + Granularity 之后，Fallback 之前。
- **判定**：Pass。

#### B2 · Body parity

- **检查方法**：diff 四份 Content Policy 正文（5 条 bullet + 引用句）。
- **实际**：四份 bullet 逐字相同（见 §5 Audit trail）；只有 "Role-specific example summaries" 两行示例不同（预期差异）。
- **判定**：Pass。

#### B3 · Role-example suitability（自验证：示例本身是否合规）

- developer: `editing agents/developer.md — Content Policy subsection` → sub-step name ✅；`P0.2 milestone: 4 agents synced` → milestone ✅
- tester: `running case-fuzz 3/12 — boundary overflow` → sub-step + score ✅；`benchmark baseline captured` → milestone ✅
- reviewer: `reviewing auth-module 2/5 files` → sub-step + score ✅；`critical finding drafted — RW-01` → milestone ✅
- dba: `analyzing migration 0042 locking behavior` → sub-step ✅；`schema diff captured for user_events` → milestone ✅
- **判定**：Pass。所有 8 个角色示例自身即符合 §3 differentiated-content 规则。

#### B4 · Cross-reference consistency

- **检查方法**：四处结尾 "Refs: DEC-007, DEC-004 §3.1–3.2, DEC-002."
- **实际**：4 份 100% 字面相同。helper `Refs: DEC-007, DEC-004 §3.1–3.2, DEC-002.` 一致。
- **判定**：Pass。

### §C awk collapse layer（bash 实测）

测试脚本使用 workflow.md Step 3.5.3 原样 pipeline：`jq -R --unbuffered -c 'fromjson? | select(.event) | "[" + .phase + "] " + .role + " " + .event + " — " + .summary' | awk 'BEGIN{last="";n=0} {if($0==last){n++} else {if(n>1) print last" (x"n")"; else if(last!="") print last; last=$0; n=1} fflush()} END{if(n>1) print last" (x"n")"; else if(last!="") print last}'`。

| Case | Input | Expected | Actual | Verdict |
|---|---|---|---|---|
| C1 | 2× `A` | `A (x2)` | `A (x2)` | Pass |
| C2 | 3× `A` | `A (x3)` | `A (x3)` | Pass |
| C3 | `A A B A A` | `A (x2)` / `B` / `A (x2)` (3 lines) | 3 行一致 | Pass |
| C4 | `A B A B`（非连续） | 4 行未折叠 | 4 行未折叠 | Pass（符合 §3.4 设计） |
| C5 | 单行 `A` | `A` | `A` | Pass |
| C6 | empty | no output, exit 0 | no output, exit 0 | Pass |
| C7 | 合法 + malformed + 合法 | malformed 被 `fromjson?` 吞，两行合法输出 | 2 行合法 | Pass |
| C8 | 3 行非重复异步注入（1s 间隔） | 流式输出，延迟 = 前一行到达时刻 | 见下 W-01 | **Warning** |
| C9 | 150-char summary | 折叠 `(x2)`，行长 ~185 char | `(x2)` 185 char | Pass |
| C10 | 含 `"` / `\\` / 中文 | 保留转义，折叠 `(x2)` | `"[P0.1] dev phase_start — has \"quotes\" and 中文 and \\backslash" (x2)` | Pass |

**C8 详细（W-01 源）**：

输入序列（生产者各 sleep 1 + 2）：
```
t=1s: A
t=3s: B
t=5s: (close)
```

观察到消费者接收时刻：
```
t+3.006s got: "[P0.1] dev phase_start — A"
t+5.009s got: "[P0.1] dev phase_start — B"
```

awk 状态机的固有行为：**每条输出行都要等到下一行到达（或 EOF）才被打印**（要决定是否追加 `(xN)`）。这意味着：

- 在真实 Monitor `tail -F` 场景，Monitor 持续运行到 dispatch 结束后 orchestrator `MonitorStop` 才关闭管道。**dispatch 的最后一条 `phase_complete`（通常是 `✅ DONE` 标识）在 Monitor 被 stop 前一直**不**交付给用户**。
- 如果下一个 dispatch 的 Monitor 立刻启动，上个 dispatch 的最后一条 event 可能**永远不出现**在用户视野（取决于 orchestrator 是否 MonitorStop 前一个）。
- 对于同一 dispatch 内连续 emit（预期 3-10 条），中间行会有 "下一行到达时才可见" 的延迟，约等于 agent emit 间隔（数秒至数分钟）。

这是 awk 状态机 + `(xN)` 折叠需求的**固有延迟交付**，不是 bug，但是 UX 影响。

### §D 回归测试

#### D1 · 原 dogfood 刷屏重放

- **输入**：5 条完全相同 `{"summary":"dev round2 progress", ...}` JSONL。
- **预期**：pipeline 输出 1 行 `(x5)` 而非 5 行独立通知。
- **实际**：`"[round2] developer phase_start — dev round2 progress" (x5)`
- **判定**：Pass — DEC-007 兼底层正确解决原刷屏模式。

#### D2 · DEC-004 schema 兼容性

- **输入**：典型 DEC-004 event JSON。
- **预期**：`jq -r '.event, .phase, .role, .dispatch_id, .slug, .summary, .ts'` 全部解析成功。
- **实际**：7 字段全部输出（`phase_start` / `P0.1` / `developer` / `a1b2c3d4` / `foo` / `bar` / `2026-04-19T00:00:00Z`）。
- **判定**：Pass — DEC-004 schema 未被改动。

### §E 相邻 DEC 边界

#### E1 · DEC-005 inline 形态

- **检查**：helper 与 4 agent Content Policy 均不强制 inline 形态 emit。developer.md line 127 明确 "Applies only when dispatched in **subagent form**. In inline form, skip this section entirely"。helper §6 table 覆盖 `empty {{progress_path}}` → policy inert。
- **判定**：Pass — inline 形态豁免正确。

#### E2 · DEC-002 escalation 正交性

- **检查**：`phase_blocked` + `<escalation>` 同一 dispatch 是否依然合法？helper §4 明确保留 "Channels stay orthogonal"。4 agent 同样表述 "both channels remain orthogonal"。tester.md §Ordering discipline 保留完整 1→2→3 步序。
- **判定**：Pass — DEC-002 正交性未被破坏。

#### E3 · DEC-003 research agent

- **检查**：`agents/research.md` 在本次改动中是否被意外加入 Content Policy？
- **实际**：grep 确认 `research.md` 无 `### Content Policy` 子节、无 DEC-007 引用。`research.md` §Progress Reporting 保留原 DEC-004 风格。与设计 §3.1 "暂不改 research.md" 状态一致。
- **判定**：Pass。**W-03（后续优化建议）**：research agent 在 architect fan-out ≤4 并行时，若 4 份 research 的 summary 撞同（如都 `fetching sources for option A`），刷屏风险与 developer 原 issue 同构。应在后续 issue 中评估是否把 research.md 也纳入 Content Policy。**当前非阻塞**。

---

## 3. 发现汇总

### Critical（0）

—

### Warning（3）

#### W-01 · awk 末行延迟交付

- **位置**：`commands/workflow.md` line 174 + `commands/bugfix.md` line 40 的 awk state machine。
- **现象**：awk 状态机必须 HOLD 住当前行直到下一行到达（或 EOF）才能决定是否追加 `(xN)`；在 `tail -F` 长开管道场景下，dispatch 最后一条 `phase_complete`（通常是 `✅` DONE marker）要等下一次写入或 Monitor 被 stop 才交付给用户。
- **影响**：用户体验上 "最后一条 event 看不到"；orchestrator 若不主动 MonitorStop，末行永远不出现。
- **复现**：见 §C C8。
- **建议修复**（可选，下一轮 issue）：
  - (a) 接受现状，由 orchestrator 在 Task 返回后显式 `MonitorStop`（让 awk END 触发末行 flush）。**推荐**。
  - (b) awk 逻辑改为"见到新行立即打印上一行 + 独立 flush 连续组"（但丢失折叠能力）。
  - (c) 用 stdbuf / unbuffer 之类工具包裹 awk（未必对 awk state hold 生效，因问题是逻辑层不是 buffer 层）。
- **严重度**：Warning（UX 不致命，现已在 workflow.md 中注释了 `Default: let it expire` 自然 flush 路径；但用户在 expire 期内看不到末行）。

#### W-02 · "非连续重复不折叠" 的呈现语义

- **位置**：`commands/workflow.md` line 182 注释 + `skills/_progress-content-policy.md` §2。
- **现象**：设计明确 "A B A B" 不折叠（§3.4 论证"非连续重复通常是有效的阶段循环"）。但用户看到两次相同 summary 之间被 1 条 B 打断后再次出现相同 summary，可能误以为 "agent 在重复，却没被折叠——bug?"。
- **影响**：用户 mental model 混乱；awk 行为正确但不直观。
- **建议**：workflow.md Step 3.5.3 注释补一句 "consecutive-only collapse is intentional; A/B/A interleaves do NOT fold because they carry valid phase-loop signal." 目前注释已有 "not global uniq"，语义隐含但可更显。
- **严重度**：Warning（cosmetic，不影响功能）。

#### W-03 · research.md 未对齐 Content Policy

- **位置**：`agents/research.md` §Progress Reporting。
- **现象**：research agent 在 architect 并行 fan-out（≤4）时，4 份 subagent summary 撞同的风险与 developer dogfood 原 issue 同构。helper + 4 agent 已覆盖但 research.md 未纳入。
- **影响**：未来 architect 大规模 fan-out 研究可能重现刷屏；awk 兼底仅折叠 CONSECUTIVE lines，4 并行 research 的 event 会交错（不连续），awk 帮不上。
- **建议**：后续 issue 评估把 research.md 也纳入 `### Content Policy`；summary 须携带 `option_label` 已在 research.md line 117 有要求，实操上已经差异化，风险相对低。
- **严重度**：Warning（未来风险，当前非阻塞，设计 §3.1 明确 "暂不改" 是有意决策）。

### Suggestion（4）

- **S-01**：`skills/_progress-content-policy.md` §2 加一句 "trivially different variants (trailing whitespace / terminal punctuation alone) SHOULD be treated as repeat; prefer skip." 见 A2。
- **S-02**：4 agent `### Content Policy` DONE 行 "uses a `✅` summary prefix" 改为 "MAY prefix with `✅`" 对齐 helper "non-mandatory" 语义。见 A4。
- **S-03**：workflow.md 注释加 "awk consecutive-only, interleaves do NOT fold" 显式化（见 W-02）。
- **S-04**：progress-content-policy design-doc §3.4 列出 awk 末行延迟的已知副作用，让后续维护者不再踩同一坑（见 W-01）。

---

## 4. 建议

1. **可流转 reviewer**：无 Critical，DEC-007 实现与设计、决策、执行计划三者对齐；helper 与 4 agent 对称正确；awk 兼底在 9/10 场景正常，仅 C8 末行延迟是固有副作用（用 MonitorStop 规避）。
2. **W-01 建议作为后续 issue 单独跟踪**：属 "tail -F × stateful awk" 的交互细节，可以接受现状 + 在 orchestrator 末端 MonitorStop。
3. **S-01 ~ S-04 可与本次 DEC-007 一同落地**（改动极小），也可留到 DEC-007 follow-up。
4. **research.md 纳入 Content Policy**：单开 issue，按 W-03。

---

## 5. Audit trail

- **dispatch_id**: `94c1ff9e`
- **progress_path**: `/tmp/roundtable-progress/1776593234-3477977-94c1ff9e.jsonl`
- **test runner**: bash + jq + awk（local），运行于 target_project 根目录。
- **lint_cmd 结果**：`grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/` → 0 命中 ✅
- **Body-parity diff 依据**：§B2 对 4 份 Content Policy 正文逐字比对。
- **Pipeline 原文**（与 `commands/workflow.md` line 174 一致）：
  ```
  tail -F "$PROGRESS_PATH" 2>/dev/null | jq -R --unbuffered -c 'fromjson? | select(.event) | "[" + .phase + "] " + .role + " " + .event + " — " + .summary' | awk 'BEGIN{last="";n=0} {if($0==last){n++} else {if(n>1) print last" (x"n")"; else if(last!="") print last; last=$0; n=1} fflush()} END{if(n>1) print last" (x"n")"; else if(last!="") print last}'
  ```
- **§C transcript**（关键片段）：
  ```
  C1: printf 'A\nA\n' | awk ... → "A (x2)"
  C2: printf 'A\nA\nA\n' | awk ... → "A (x3)"
  C3: printf 'A\nA\nB\nA\nA\n' | awk ... → "A (x2)" / "B" / "A (x2)"
  C4: printf 'A\nB\nA\nB\n' | awk ... → 4 lines unfolded
  C5: printf 'A\n' | awk ... → "A"
  C6: printf '' | awk ... → (no output)
  C7: good + GARBAGE_NOT_JSON{{{ + good | jq|awk → 2 good lines, garbage suppressed by fromjson?
  C8: async 1s spacing → line A arrives when B enters awk (~t+3s), B arrives at EOF (~t+5s)
  C9: 150-char summary × 2 → "...(150 x's)..." (x2), output 185 chars
  C10: quotes/backslash/CJK × 2 → "...has \"quotes\" and 中文 and \\backslash" (x2)
  ```
- **§D transcript**：
  ```
  D1: 5× {"summary":"dev round2 progress",...} | jq | awk → '"[round2] developer phase_start — dev round2 progress" (x5)'
  D2: jq -r '.event, .phase, .role, .dispatch_id, .slug, .summary, .ts' → 7 fields all parsed
  ```

## 6. 变更记录

- 2026-04-19 创建 Final（DEC-007 实现对抗性测试通过，无 Critical）
