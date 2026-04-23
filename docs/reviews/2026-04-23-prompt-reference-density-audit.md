---
slug: prompt-reference-density-audit
source: reviewer subagent (aa650bb12d7c45c4d)
created: 2026-04-23
reviewer: roundtable:reviewer (subagent)
---

# Review: Runtime Prompt Reference Density Audit (issue #99)

## 总结

Verdict: **Approve with caveats**

本次 DEC-029 清理执行整体稳健，14 处 runtime prompt + 2 处脚本 + CLAUDE.md + `_detect-project-context.md` 的改动方向对齐 design-doc；8 个 critical_modules 结构性不变（Resource Access / Escalation JSON schema / AskUserQuestion Option Schema / Phase Matrix / Progress event schema / _detect 4 步骨架 / Developer execution-form 全部保持）；`scripts/ref-density-check.sh` exit 0 对 baseline 通过，W1/W2/W3 三项 adversarial 修复均正确落地（oE count / 新文件 NOTE / dup path 预检）。DEC-029 的 DEC-010 `Refined by` 状态行追加与 2 条 post-fix inline append 按铁律 4 执行到位。

留下 3 条 Warning（非阻塞 follow-up）：2 处 runtime prompt 中的 `design-doc §x` 裸引用未加 `docs/` 前缀（ε 违例 3 处）、`commands/workflow.md:73` 的 H2 title 尾巴 issue# 括注未清（η 漏网）、`lint_cmd_*` 多字段契约只补了 `_detect-project-context.md` §4 正文，未同步输出模板 line 112 与 5 个调用方的"必须注入"清单。建议 merge 后独立 follow-up issue 收拾，不阻塞本 PR。

## Critical

- 无。critical_modules 结构不变；regression gate（`scripts/ref-density-check.sh`）通过 baseline；DEC-029 决定 6 Refines DEC-010 执行到位。

## Warning

- **W-R01**：`commands/workflow.md:279,298` + `skills/analyst/SKILL.md:40` — 3 处 `canonical schema 见 design-doc §3.1` / `ref design-doc §3.2` **裸引用违 DEC-029 决定 3 (ε)** —— ε 明确"禁不带 `docs/` 路径前缀的裸 `§y.z` 跨文件引用"。`design-doc` 是 slug-agnostic 占位词但仍是跨文件引用。修复建议：`commands/workflow.md:279` 改 `ref docs/design-docs/parallel-decisions.md §3.2`；`commands/workflow.md:298` + `analyst:40` 改 `canonical schema 见 docs/design-docs/decision-mode-switch.md §3.1`。
- **W-R02**：`commands/workflow.md:73` — H2 title `## Step 0.5: FAQ Sink Protocol（issue #27；常驻规则，在 Step 0 之后激活）` 命中 η 反模式（title 标签 issue ref），design-doc §3.1.1 列 5 处 title 删除但漏此处。修复建议：改为 `## Step 0.5: FAQ Sink Protocol`（issue #27 保留在 decision-log / 相关文档里供溯源，title 不背 issue 标签）；`常驻规则，在 Step 0 之后激活` 这句非 ref 性质可放入紧随段首句。
- **W-R03**：`skills/_detect-project-context.md` §4 lint_cmd_* 多字段契约扩展面覆盖不全 —— 新增正文（line 82）声明"调用方遍历跑各字段并独立判 exit code"，但 (a) 本文件输出模板 line 112 `lint_cmd: <cmd>` 仍 singular；(b) `commands/workflow.md:69` / `commands/bugfix.md:30` 的"必须注入"清单仍写 `lint_cmd` singular；(c) `agents/developer.md:22,87` / `agents/reviewer.md:24` 的「必需上下文注入」全部 singular。实际影响：当 target 是 roundtable 自身（递归 dogfood），developer/reviewer subagent 拿到的是 singular `lint_cmd`，`scripts/ref-density-check.sh` 的 enforcement 在 subagent 侧不会被自动跑；orchestrator 主会话层能 cover（它直接 Read target CLAUDE.md），但契约面破缺。修复建议：(i) line 112 输出模板加行 `lint_cmd_*:  <单/多字段标记与值映射>` 或把 `lint_cmd` 重定义为 `Record<string,string>`；(ii) 5 调用方注入清单同步扩为 `lint_cmd_hardcode / lint_cmd_density / lint_cmd`（三字段任一存在即合法，调用方遍历跑）。走独立 follow-up issue 不阻塞本 PR。

## Suggestion

- **S-R01**：`commands/workflow.md:364` — `**Stage 9 Closeout 变体**（A 类终点，无 producer skill；issue #26 + #30）` 是有序列表内的加粗小标题（非 H 级 title），η 规则严格讲不触发，但语气与 H-title 的 issue# 括注高度相似；如追求 η 一致性可顺手清掉，保 `**Stage 9 Closeout 变体**（A 类终点，无 producer skill）`。
- **S-R02**：`commands/bugfix.md:76` — `DEC-009 决定 9 对 DEC-005 §3.4.2` 中 `DEC-005 §3.4.2` 的语义是 "DEC-005 正文中的 §3.4.2 子节"；严格 DEC-029 ε 条款只禁"裸 §y.z 跨文件"，DEC-NNN §y.z 读者约定是去 decision-log.md 找对应 DEC，解释性歧义可接受。可保留，但若未来统一格式可考虑 `docs/decision-log.md §DEC-005 §3.4.2`。
- **S-R03**：`scripts/ref-density-check.sh` — bash 健壮性：`set -euo pipefail` 下 `grep -oE | wc -l` 在匹配为 0 时 grep exit 1 会被 pipefail 捕获；本脚本已加 `2>/dev/null` 但若未来 grep 标 `|| true` 更明确保护。当前 pipeline 因 `wc -l` 是最后一个命令且返回 0，pipefail 结论依最后 cmd，实测 exit 0 通过，不构成 bug —— 但约定清晰点更健壮。
- **S-R04**：`scripts/ref-density.baseline` — TSV 中 `skills/_detect-project-context.md	0	0	0` 保留零值条目是好的（后续新增 ref 触发 `delta>=3` 判定），不变。

## Positive

- W1 方法论切换（`grep -cE` line count → `grep -oE | wc -l` match count）是正方向 —— DEC-029 aims at reference **density**，per-line unique count 会低估多 ref/行的真实负担；oE 计数正确反映 token 成本。baseline re-lock 至 40/30/3 水位在方法论切换下是必要，不是漂移。
- W2 新文件 NOTE stderr（非 fail）正确处理 baseline 缺失条目：保留 total_delta 贡献 + 单行友好提示，避免 baseline 过严阻塞合法新增。
- W3 baseline dup 预检（`awk | sort | uniq -d` + `exit 2`）堵住了 `grep -F` 命中非确定性的 silent fallthrough，是实质 robustness 升级。
- 铁律 4 post-fix inline append 执行到位（DEC-029 已含 2 条 post-fix；DEC-010 状态行 `Refined by DEC-029`），未违反 "DEC 不删除/不超影响范围 10 行硬约束" 元规则。
- critical_modules 8 个点位全部无 regression —— Resource Access Write 列 / Escalation JSON schema / Progress event schema / AskUserQuestion Option schema / Phase Matrix / Step 4/4b gating / _detect 4 步 / Developer execution-form 八线核验不动。
- 清理执行范围纪律性强：`agents/developer.md` / `agents/research.md` 等已极简或"0 命中/保底简"的文件主动跳过，体现 surgical changes 原则。

## 决策一致性

- **DEC-029（Provisional；本 issue 产出）**：清理方案 = 方案 B 中道 / 白名单严格 / enforcement γ+α₂ 三项核心决定与 landed 改动一致；scripts/ + baseline + CLAUDE.md §条件触发规则表 updates 与决定 4/5/7 匹配。
- **DEC-010（Accepted；Refined by DEC-029）**：状态行 `Accepted (Refined by DEC-029)` 于 `docs/decision-log.md:633` 正确落地；"token 成本 > SSOT" 北极星未被 DEC-029 覆盖（两 DEC lever 异源）。
- **铁律 4（inline post-fix）**：DEC-029 下 2 条 post-fix（decision 3 γ clarification / tester C1+3W fix）以 `**post-fix 2026-04-23（...）**：` 格式 inline append，合规。
- **铁律 5（影响范围 ≤10 行）**：DEC-029 正文总长超过 10 行属正常（决定段非影响范围段；影响范围若另列需独立检）—— 本次未新增独立 `**影响范围**` 段条目，若缺失建议 follow-up 补。
- **critical_modules 触发**：reviewer/tester/dba 归档走 orchestrator relay 未受影响；本 reviewer 报告按 relay 主路径归档（不 Write）。
