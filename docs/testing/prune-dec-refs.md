---
slug: prune-dec-refs
source: issue #22 P3（runtime prompt token economy）
created: 2026-04-21
branch: fix/22-prune-dec-refs
---

# Prune DEC / issue refs in runtime prompts — 测试计划 & 对抗性审查

## 0. Scope

Runtime-loaded prompt 本体（`skills/*`、`agents/*`、`commands/*`）去 DEC-xxx / issue #N 冗余标签，保留 cross-doc 指针与语义必需 anchor。`docs/` 内所有 DEC 溯源（DEC-010 north star 服务文档读者）保持不动。

## 1. 当前覆盖现状

- 人工 PR review（analyst / architect / developer 视角）
- 无自动化 lint 覆盖 "prompt-vs-docs 术语一致性"
- 无 snapshot test 监控 runtime prompt 体积

## 2. 验证要点（pass / fail 判据）

| # | 检查项 | 命令 / 方法 | 期望 |
|---|--------|-------------|------|
| V1 | runtime prompts 无 parenthesized `（DEC-xxx）` 纯标签 | `grep -rnE '\(DEC-[0-9]+[^§]*\)' skills/ agents/ commands/` | 0 命中（带 `§` 的不算，结构 anchor 保留） |
| V2 | runtime prompts 无 parenthesized `（issue #N）` 纯标签 | `grep -rnE '\(issue #[0-9]+\)' skills/ agents/ commands/` | 0 命中 |
| V3 | section anchor refs 保留 | `grep -rnE 'DEC-[0-9]+ §' skills/ agents/ commands/` | ≥7 命中（3× DEC-013 §3.1a / DEC-005 §3.4.2 / DEC-007 §3.4 / DEC-004 §3.1–3.2 / DEC-004 §3.5 等） |
| V4 | DEC-010 north star 尊重：docs/ 内 DEC 引用 0 触动 | `git diff docs/ | grep -c "DEC-"` | 0 |
| V5 | `_progress-content-policy.md` schema anchor 未被误删 | 读文件行 3/8/18/39/66/68 | 全部仍含 DEC-0XX |
| V6 | markdown 锚点回归：内部 `[...](#step--0...)` 链接 | `grep -rnE '\(#step--?[0-9]' docs/` | 0 命中（当前 0，删 title label 安全） |
| V7 | 跨 prompt 一致性：`decision_mode`/`auto_mode`/`§Auto-pick` 在 skills 与 command 侧表述保留一致 | 人工对齐 `skills/architect/SKILL.md:84` vs `commands/workflow.md:250` | 概念等价，label 差异已被 V1 允许 |

## 3. 新增对抗性场景

### 3.1 Critical / Warning / Positive 评级 findings

#### C1（Warning）cross-prompt label 不对称 — **跨 prompt 一致性**

**定位**：
- `skills/architect/SKILL.md:84`：`**decision_mode 分支**（orchestrator 注入 context prefix；DEC-013）`
- `skills/analyst/SKILL.md:37`：同上
- `commands/workflow.md:250`：`3. **按 decision_mode 分支**：`（无 DEC-013 label）

**风险**：同一段 forwarding 规则在 3 个文件，skills 两处保留 `DEC-013` 内联 label，workflow 处已删。读者若从 workflow 跳到 skills 会被多余 label 干扰；反向从 skills 到 workflow 会疑惑 DEC-013 是否被撤回。

**建议**：**保留 skills 两处**（`（DEC-013）` 属于顶层概念来源声明，非结构 anchor），workflow 侧可选回补；或**一致删除**两 skills 内 `（DEC-013）` 纯标签保持对称。当前 PR 策略倾向前者（DEC-013 是 decision_mode 的权威定义来源，首次出现加 label 合理），建议文档里留 note 明示该约定。

**严重度**：Warning（不影响 runtime 行为，影响 maintenance DX）。

#### C2（Warning）DEC-013 §3.1a 3× 重复 anchor — 可接受但需 note

**定位**：`skills/architect/SKILL.md:88` / `skills/analyst/SKILL.md:41` / `commands/workflow.md:253` 各有 `（DEC-013 §3.1a）`。

**风险**：`commands/workflow.md:278` 的 meta-note 已主动枚举 "3 处 prompt 本体 —— 继续生效"，即把该冗余视为架构契约。但三处 anchor 并不服务 prompt 读者（LLM consumer）—— skill/agent LLM 读 prompt 不会去 decision-log.md 跳 §3.1a。这个 anchor 是给**人类 maintainer** 用的。

**建议**：**保留现状** — DEC-013 §3.1a 是跨 3 文件行为契约，anchor 便于 maintainer 同步更新；符合"保留语义澄清段"原则。**Positive 侧**：PR 正确保留而没有粗暴删除。

**严重度**：Suggestion（已 Positive 处理）。

#### C3（Suggestion）Phase Matrix Stage 9 cell 失去 `（DEC-006 producer-pause 终点）` 类型归属标签

**定位**：`commands/workflow.md:30`（`| 9. Closeout | 用户 | ⏳/🔄/✅ | 汇总 findings；用户驱动 commit / PR / amend |`）

**风险**：矩阵原 cell 携带 "producer-pause 终点"（A 类归属）关键提示；纯粹依赖读者到 Step 6.1 A 类 / Stage 9 Closeout 段展开读。Token 节省显著但初读者 context missing。

**建议**：**保留 PR 决定**（Step 6.1 A 类 block 已详解，矩阵 cell 保持精简）；可选在 cell 文末加极短 `（A）` 单字符提示，token 成本极低但恢复类型归属信号。优先级 Suggestion，不 blocking。

**严重度**：Suggestion。

#### C4（Positive）`_progress-content-policy.md` 6 处 DEC 保留

**定位**：行 3/8/18/39/66/68 — DEC-004 §3.1–3.2 / DEC-002 正交 / DEC-004 §3.5 / DEC-007 等。

**判断**：这些是 schema / 分层契约语义锚点（event schema 契约来源 + orthogonality claim）；删除会使 include helper 失去与上游 DEC 的可追溯性。保留正确。

#### C5（Positive）title label 删除 - markdown anchor 兼容性

**验证**：`grep -rnE '\(#step--[0-9]|#step-3-5-0|#step-5b|#step-6b' docs/` 0 命中。GFM 自动生成的 `#step--0` / `#step-5b` / `#step-6b` anchor 依赖的是 heading 的**前缀部分**（`## Step -0`），删除尾部 `（DEC-015）` 反而让 anchor 更稳定（anchor 不再含 `-dec-015`）。

**判断**：无回归风险，PR 操作安全。

#### C6（Suggestion）`commands/workflow.md:82` 保留 `DEC-\d+` (regex) 与 `DEC-015` 示例

**定位**：Step 0.5 FAQ sink 的 sink trigger term list 枚举。

**判断**：这是 trigger 匹配正则的自描述，**必须**保留（功能性 code-like content，非叙述性 label）。PR 正确保留。Positive。

#### C7（Suggestion）`commands/bugfix.md:74` 单处 `DEC-005 §3.4.2 / DEC-009` 长引文

**定位**：`对称处理是 DEC-009 决定 9 对 DEC-005 §3.4.2 per-project 三级切换的 follow-through 修正`

**判断**：这是 DEC-009 与 DEC-005 的 follow-through 关系说明；若删会丢失 "对称处理为什么存在" 的历史 rationale。保留合理。Positive。

#### C8（Warning）DEC-014 refs 密集于 `commands/bugfix.md`

**定位**：line 57 / 90 / 98 / 137 四处 `（DEC-014）` / `DEC-014 C1` / `DEC-014 步骤 2` / `DEC-014；postmortem`。

**风险**：DEC-014 是 bugfix Tier + postmortem 决策，4 处均属**结构 anchor**（步骤 / section / 硬约束标号）。但 line 57 `### Tier 判定（D1 双轴 + LOC；DEC-014）` 与 line 90 `DEC-014 步骤 2 判定结果` 有轻度冗余 —— 既然 Section title 已标注 DEC-014，body 内再重复 "DEC-014 步骤 2" 可压缩为 "步骤 2"。

**建议**：**可选进一步精简**；非 blocking，可 follow-up P3 issue。

**严重度**：Suggestion。

### 3.2 Benchmark：token 经济指标

| 指标 | Baseline（PR 前） | 当前 | Δ |
|------|------|------|---|
| Parenthesized `（DEC-xxx）` 标签总数 | 52（声明值） | 12（V3 结构 anchor + 保留） | -77% |
| Parenthesized `（issue #N）` 标签 | 18 | 0 | -100% |
| 总 `DEC-[0-9]+` 出现次数 | 声明 "28 baseline → 34 当前" | 34 | +6（累积 5 PR 引入 > 本 PR 删） |
| 文件 churn | — | 9 文件 / 41+ / 41- | 纯平衡 rename |

**注**：第 3 行 +6 的净增 **不是本 PR 回归**，是 #26/#27/#29/#30/#48 五个相邻 PR 累积引入的新增 refs；本 PR 实际净删 **parenthesized labels** 40+。建议 PR body 明示该累积背景避免审查者误读。

## 4. 跨 DEC-010 对齐审查

DEC-010 north star = "让用户读得懂 docs/"。本 PR:
- docs/ 内 DEC 溯源 **0 改动** → north star 尊重 ✅
- runtime prompt 本体 = LLM consumer，不是人类读者 → 可激进瘦身 ✅
- 保留的 cross-doc 指针 `详见 docs/design-docs/...` 全数保留 → 双向 traceability ✅

## 5. 测试命令

```bash
# V1–V3 lint
grep -rnE '\(DEC-[0-9]+[^§]*\)' skills/ agents/ commands/  # expect 0
grep -rnE '\(issue #[0-9]+\)' skills/ agents/ commands/    # expect 0
grep -rnE 'DEC-[0-9]+ §' skills/ agents/ commands/ | wc -l # expect ≥7

# V4 docs/ 0 touch
git diff main...HEAD -- docs/ | grep -c "DEC-"  # expect 0

# V6 anchor 回归
grep -rnE '\(#step--?[0-9]|#step-3-5-0|#step-5b|#step-6b' docs/  # expect 0
```

## 6. 发现的潜在问题（反馈 developer / orchestrator）

- **M1 (Warning, C1)**：`decision_mode 分支` 标题在 3 处 runtime prompt 里 DEC-013 label 不对称（skills 保留 / workflow 删除）。建议在 PR description 或 follow-up 补一致性处理。
- **M2 (Suggestion, C3)**：Phase matrix Stage 9 cell 失去 A 类归属提示，可选补 `（A）` 单字符。
- **M3 (Suggestion, C8)**：`commands/bugfix.md` DEC-014 4 处可进一步去冗余 1-2 处。
- 无 Critical。

## 7. 变更记录

- 2026-04-21 initial adversarial review（tester）

```yaml
log_entries:
  - prefix: test-plan
    slug: prune-dec-refs
    files:
      - docs/testing/prune-dec-refs.md
    note: runtime prompt DEC/issue 标签瘦身对抗性审查；0 Critical / 3 Warning-Suggestion（cross-prompt label 不对称 / matrix Stage 9 cell A 类归属缺失 / bugfix DEC-014 可进一步去冗余）；6 Positive（title anchor 安全 / _progress-content-policy 保留正确 / DEC-013 §3.1a 3× 契约合理 / DEC-010 north star 尊重 / V1-V7 lint 全绿 / token 经济 parenthesized labels -77% / issue labels -100%）
```
