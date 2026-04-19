---
slug: progress-content-policy
source: design-docs/progress-content-policy.md
dispatch_id: reviewer-2026-04-19
created: 2026-04-19
role: reviewer
triggers: [critical_modules]
---

# DEC-007 Progress Content Policy 代码审查

> 审查范围：`skills/_progress-content-policy.md`（新建）、`agents/{developer,tester,reviewer,dba}.md` 的 `### Content Policy` 子节、`commands/workflow.md` Step 3.5.3 + `commands/bugfix.md` Step 0.5 的 jq | awk pipeline、`docs/decision-log.md` DEC-007、`docs/design-docs/progress-content-policy.md`、`docs/testing/progress-content-policy.md`（tester 报告）。

> 触发落盘原因：critical_modules 命中「Skill/agent/command prompt 本体」+「Progress event JSON schema (DEC-004)」。per `agents/reviewer.md` 强制归档。

## 执行摘要

| 等级 | 数量 |
|---|---|
| Critical | 0 |
| Warning | 2 |
| Suggestion | 3 |
| Positive | 5 |

**Verdict**：**Approve-with-caveats**。DEC-007 的 4 条核心决策（共享 helper / substantive-progress gate / no-repeat & differentiated / DONE-ERROR 信号复用）在代码层面全部忠实落地；4 agent 的 Content Policy 正文达成逐字对称（除 role-specific 示例外），无跨 DEC 污染；awk 折叠层在 10 个测试场景 9 pass + 1 已识别的固有副作用（W-01）。落盘审查仅为触发 critical_modules 归档纪律，并非存在阻塞问题。

---

## Critical

（无）

---

## Warning

### RW-01 · design-doc §3.4 未收录 developer 实装 `fflush()` 的语义细节

- **位置**：`docs/design-docs/progress-content-policy.md` §3.4 示例 awk 片段 vs `commands/workflow.md` line 174 / `commands/bugfix.md` line 40 实装。
- **现象**：design-doc §3.4 的 awk 字面不含 `fflush()`，但实装的 awk 块在每次 print 后调用 `fflush()`。`commands/workflow.md` Notes bullet 第 4 点（line 182）已明确描述 `fflush()` 的必要性（「preserves per-line delivery to Claude Code's Monitor (matches the `--unbuffered` intent upstream)」），语义正确且与上游 `--unbuffered` 对称，**这是正向修正**（缺失会导致 awk 在管道下游 block-buffer 输出、吞掉用户实时感知）。但 design-doc 正文未收录这一发现，后续维护者若只读 design-doc 重写 pipeline 会回退丢失 flush 行为。
- **影响**：单一真相源漂移，属 critical_modules「Progress event JSON schema」相关基础设施的文档一致性风险。
- **建议**：将 `fflush()` 以及其理由 back-feed 到 design-doc §3.4（添加脚注或直接修正 awk 代码块），并在 §6 变更记录追加一行 "2026-04-19 back-fed fflush() from implementation"。不涉及 DEC-007 的任何决策语义，非 Superseded。
- **严重度**：Warning（实装正确；仅文档漂移）。

### RW-02 · 测试报告 W-01（awk 末行延迟交付）的 MonitorStop 缓解方案评估

- **位置**：`docs/testing/progress-content-policy.md` §W-01 建议 (a)；实装 `commands/workflow.md` Step 3.5.3 + bugfix Step 0.5。
- **评估**：tester 提出的修复路径 (a) "orchestrator 在 Task 返回后显式 `MonitorStop` 让 awk END 触发末行 flush" **技术上成立**——awk 的 END block 仅在 stdin EOF 触发，而 `tail -F` 的 EOF 由 Monitor tail 进程退出（或 MonitorStop）强制产生，因此 MonitorStop 确实会让末行在 awk END 分支被打印后交付。方向正确。
- **局限**：在 DEC-007 scope 内看不见 orchestrator 端是否已系统化"Task 返回 → MonitorStop"的纪律。查 `commands/workflow.md` Step 3.5.3 本身无 teardown 说明；Monitor 被动靠 Default expire 回收，在 expire 窗口内末行（通常是 `✅ DONE` marker）对用户不可见。**设计 §2.3 明示 "orchestrator 无需专门解析 DONE token" 依赖的是 Task 返回作为权威信号，这一点不动摇**；但 Monitor 的 UX 层仍会丢末行。
- **与 issue #15 的关系**：用户已观察到 foreground Task dispatch 不需要 Monitor（一并用 background Monitor 属过度基础设施）。W-01 的锐度与 issue #15 的方向**一致但非重叠**：即使 foreground 直接观察去掉 Monitor 依赖，其他仍走 Monitor 的 subagent 类型（dba / reviewer 并行派发等）仍有该末行延迟。**本 PR 不要为了 W-01 引入 MonitorStop 纪律**（那是 issue #15 的范围），但建议在 `docs/design-docs/progress-content-policy.md` §3.5 边界情况表追加一行"末行延迟交付（awk 状态机固有）—— 依赖 orchestrator MonitorStop 或 Monitor 自然 expire；前者由 issue #15 跟踪"以留存维护者上下文。
- **严重度**：Warning（已知 UX 副作用；不阻塞，建议文档留痕）。

---

## Suggestion

### RS-01 · 沿用测试报告 S-01：`skills/_progress-content-policy.md` §2 加 trivial-variant 条款

测试报告 A2 已明确指出：`"foo"` vs `"foo "` 在 awk `$0==last` 下不相等（不折叠），策略层面应视为重复但当前未强制。建议 §2 追加："trivially different variants (trailing whitespace / terminal punctuation alone) SHOULD be treated as repeat; prefer skip."——收敛 LLM 在边缘情形的自由度，降低 awk 兼底层出现 `foo` / `foo ` / `foo` 序列的概率。

### RS-02 · 沿用测试报告 S-02：4 agent DONE 行表述对齐 helper "non-mandatory"

4 agent 的 Content Policy DONE 行"uses a `✅` summary prefix"稍强于 helper §4 的"Convention (non-mandatory): prefix with `✅`"。建议改为 "MAY prefix with `✅`"，保持 helper 与引用方一致。偏差轻，不影响行为正确性。

### RS-03 · design-doc §3.5 边界表追加"末行延迟"行（呼应 RW-02 与 issue #15 衔接）

如 RW-02 讨论。一句话文档条目即可。

---

## Positive（审查发现的实作亮点）

1. **4 agent Content Policy 达成真正的逐字对称**——diff 四份 Content Policy 正文仅"Role-specific example summaries"两行有预期差异（developer 编辑示例 / tester 测试示例 / reviewer 审查示例 / dba 迁移示例），bullet 正文、Refs 行 100% 一致。critical_modules 单源纪律到位。
2. **helper 的下划线前缀 + Internal helper 描述**清晰遵循与 `skills/_detect-project-context.md` 相同范式，不会被 Claude Code 的 skill auto-delegation 误激活。
3. **DEC-004 event schema 零改动**：`phase_start/complete/blocked` 三枚事件类型未扩、`ts/role/dispatch_id/slug/phase/event/summary` 七字段未改、`detail` 仍为 optional。测试 D2 7 字段全解析通过。
4. **DEC-002 / DEC-005 正交保持**：helper §4 "Channels stay orthogonal"、developer.md line 127 "inline form, skip this section entirely" 均在位；reviewer.md 的 Critical-finding ordering discipline 与 tester.md bug-found ordering discipline 均保留，与 Content Policy 的 gate-exempt 规则无冲突。
5. **awk 实装添加 `fflush()`**（相对 design-doc 字面的正向修正）——消除 pipe block-buffer，与上游 `jq --unbuffered` 对齐，Notes bullet 解释到位。值得在 design-doc 回补 back-feed（见 RW-01）。

---

## 决策一致性

| DEC | 本次实装是否一致 | 备注 |
|---|---|---|
| DEC-007 决定 1（共享 helper）| 一致 | `skills/_progress-content-policy.md` 新建；4 agent 以 `### Content Policy` 子节一行引用 |
| DEC-007 决定 2（substantive-progress gate）| 一致 | helper §1 三项条件完整呈现；"not re-reads" 补丁到位 |
| DEC-007 决定 3（no-repeat summary）| 一致 | helper §2 + 4 agent bullet 行对齐 |
| DEC-007 决定 4（differentiated content）| 一致 | helper §3 三选一结构；4 agent 示例自证合规（tester 报告 B3 通过）|
| DEC-007 决定 5（DONE/ERROR 复用，不扩 event）| 一致 | 未引入新 event type；gate-exempt 语义到位；summary 表述见 RS-02 |
| DEC-007 决定 6（orchestrator 兼底 awk）| 一致 | workflow.md Step 3.5.3 + bugfix.md Step 0.5 均含 awk consecutive-collapse；Notes 解释充分 |
| DEC-004 event schema | **未改动（正确）** | 7 必选字段 + 3 event 枚举未动 |
| DEC-005 developer 双形态 | 一致 | developer.md line 127 "inline form, skip this section entirely" 保留 |
| DEC-002 Escalation 正交性 | 一致 | helper §4 + 4 agent "both channels remain orthogonal" 明示 |
| DEC-003 research agent 不纳入 | 一致 | research.md 未被触碰；设计 §3.1 已明示"暂不改"；tester W-03 留为后续 issue |
| DEC-006 phase gating | 不相关 | 本 PR 属 C 类 verification-chain；无 gate 影响 |

---

## 总结 / 推荐

**Approve-with-caveats**。代码实装与 DEC-007 四条核心决策一致，无功能性缺陷，无安全 / 并发 / 资金类风险，无 DEC-004 schema 破坏，4 agent 对称纪律过硬。两条 Warning（RW-01 文档 back-feed `fflush()`、RW-02 末行延迟文档化）均为文档 / 维护性信号，不阻塞 branch closeout；建议落盘同 PR 修正 RW-01 以避免后续读者踩坑。三条 Suggestion 可与 DEC-007 同 PR 落地（改动量极小）或延后 issue 跟踪。

**分支就绪度**：本 branch 就 DEC-007 范围看**已可流转 Stage 9 Closeout**。RW-01 的 `fflush()` back-feed 建议在 closeout 前补一次 commit；RW-02 / RS-03 如选择留到 issue #15 讨论也可接受（不影响合并）。W-03（research.md 纳入政策）属另一 issue，与本 PR 无关。

## 变更记录

- 2026-04-19 创建 Final（critical_modules 触发落盘；0 Critical / 2 Warning / 3 Suggestion / 5 Positive）
