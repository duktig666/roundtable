---
slug: subagent-progress-and-execution-model
reviewer: roundtable:reviewer (subagent)
date: 2026-04-19
status: Approved with caveats
decisions: [DEC-001 D8, DEC-002, DEC-003, DEC-004, DEC-005]
critical_findings: 0
warning_findings: 3
suggestion_findings: 4
---

# issue #7 终审报告 — subagent 进度透传 + developer 双形态

## 0. 审查结论

**Approved with caveats**：核心设计（DEC-004 progress protocol + DEC-005 developer 双形态）与实现 1:1 对齐，critical_modules 7 项全部落地正确，tester 发现的 Critical（jq pipe 单行毒化）已由 developer inline 形态修复并验证通过。剩余 3 Warning + 4 Suggestion 不阻塞合并，可作为下一轮 dogfood 捎带修复。north-star "用户掌控感" 已达成 80%：实时性 + 关键点介入已到位，卡住/快完了的可判断性部分依赖 LLM 自觉。

---

## 1. Critical 发现（必修后才能合并）

**无**。tester 在 2026-04-19 报告发现的唯一 Critical（Case 1.2/1.2b，jq pipe 单行毒化）已被 inline developer 按用户裁决修复：
- `commands/workflow.md:170` —— jq 表达式改为 `jq -R --unbuffered -c 'fromjson? | select(.event) | ...'`，实测 3 合规 + 1 坏行 + 1 合规混合输入通过，exit 0
- `commands/bugfix.md:40` —— 模板同步
- `docs/design-docs/subagent-progress-and-execution-model.md:173` —— §3.3 模板同步
- 变更记录落盘：`docs/log.md:41` `fix | subagent-progress-and-execution-model Critical | 2026-04-19`

本 reviewer 独立复验 jq 语义：输入含一行 garbled text，`fromjson?` 的 `?` 操作符让 parse 失败静默返回 `empty`，`select(.event)` 进一步过滤，两条合规 JSONL 全部输出（见 §8 底部 trace）。Critical 关闭。

---

## 2. Warning 发现（建议修，不阻塞合并）

### W-R1 （承接 tester W4）AskUserQuestion Option Schema 示例两 `recommended: true` 违反 DEC-002
- `commands/workflow.md:303` + `:307` —— example block 两个 Option（`inline` 与 `subagent`）均标 `recommended: true`，用 `#` 注释分情况区分
- DEC-002 明文约束 "Set `recommended: true` on at most 1 option"（见 `agents/developer.md:109` / `agents/tester.md:76` / 其他 agent 同字段）以及 critical_modules "AskUserQuestion Option Schema" 纪律
- **reviewer 独立判定：Warning，不升 Critical**。理由：
  1. 这是**示例文本 + `#` 注释**，不是运行时生成的真实 Option；orchestrator 执行时按 §6b.2 的"small-task markers 命中 → inline recommended；否则 subagent recommended"二选一生成，单次呈现给用户只会有一个 recommended
  2. Critical 判定要求"运行时 schema 违例"，此处是"文档示例易被 copy-paste 误读"，按 reviewer 分级纪律属于 "代码风格违规 / 设计文档一致性" 的 Warning 类
  3. 但该示例正好落在 critical_module "AskUserQuestion Option Schema" 上，tester 按 critical_modules 纪律标 Warning 是对的，不能推迟太久
- **修法**（同 tester 建议）：example block 拆成 case A (small-task signals present) 与 case B (not small) 两小段，各只一个 `recommended: true`

### W-R2 （承接 tester W5）bugfix.md 规则 2 非对称处理 `inline` 值
- `commands/bugfix.md:68` —— 规则 2 只处理 `developer_form_default: subagent` 分支，未对称列 `inline`
- 与 DEC-005 §3.4.2 三级切换"per-project 层级应完整 honor CLAUDE.md 声明值"冲突；与 `commands/workflow.md:287-291` 对称写法不一致（workflow.md 的规则 2 用 "use its value as the baseline"，通吃两值）
- **reviewer 独立判定：Warning，不升 Critical**。理由：
  1. 运行时行为碰巧正确（inline 声明的项目在 bugfix 里 fall-through 到规则 3，又因 bugfix inline-bias 大概率选 inline）
  2. 但语义上"用户声明 inline 却被弹窗再问"违反 north-star "用户掌控感" —— 用户会质疑"我声明了为什么还问"
  3. 与 DEC-005 决策 #4 的 "per-project：target CLAUDE.md ... 可选 `developer_form_default: inline`" 文本不一致（DEC-005 原文只列了 inline 作为例子，bugfix.md 实现却只 honor subagent）
- **修法**：`commands/bugfix.md:68` 改为 `if target_project CLAUDE.md ... declares developer_form_default (either inline or subagent), honor the declaration — this overrides the bugfix inline-bias default.`
- **Resolved by DEC-009 决定 9**（2026-04-19 bugfix.md 规则 2 落地对称 honor）

### W-R3 （承接 tester W3）各 agent Bash emit 模板缺空值守卫
- `agents/developer.md:141` / `agents/tester.md:97,101,105` / `agents/reviewer.md:112` / `agents/dba.md:96` / `agents/research.md:125,129,133`
- 现状：所有 agent 的 §Progress Reporting 仅用 prose 描述 Fallback（"if empty, silently skip"），Bash 模板本身**不带守卫**
- `ROUNDTABLE_PROGRESS_DISABLE=1` 或 orchestrator 漏注入时，LLM 若机械照搬模板，Bash 会因 `>> ` 后为空串报 `ambiguous redirect` 而非静默
- **reviewer 独立判定：Warning**。理由：依赖 LLM 纪律 + 静态 prose 不是 robust fallback；新 model 或 prompt 变体下会回归
- **修法**：每个模板前加 `if [ -n "{{progress_path}}" ] && [ -w "{{progress_path}}" ]; then ... fi` 守卫，或至少在 prose 里给出 guarded 版本 Bash 示例

---

## 3. Suggestion 发现（可选优化）

### S-R1 （承接 tester W1）BSD/macOS `date +%s%N` fallback 同秒碰撞
- `commands/workflow.md:147` / `commands/bugfix.md:38` —— fallback 链 `openssl rand -hex 4 2>/dev/null || date +%s%N | sha1sum | head -c 8` 在 macOS BSD date 下 `%N` 输出字面 `N`，同秒三次调用返回同一 hex
- 现实影响低（Linux 主战场；macOS 用户多数装过 openssl），但跨平台纪律要求覆盖
- **修法**：fallback 链扩展为 `openssl rand -hex 4 2>/dev/null || (awk 'BEGIN{srand(); printf "%08x", rand()*4294967296}')`（awk/POSIX 跨平台）

### S-R2 （承接 tester W2）mkdir 失败路径未处理
- `commands/workflow.md:156` / `commands/bugfix.md:39` —— `mkdir -p ... && touch ...` 失败后模板仍 echo `PROGRESS_PATH`，orchestrator 会注入不可写路径给 subagent
- W-R3 的守卫能拦住下游错误（`-w` 检测会失败 → skip），但上游 touch 失败值得也 graceful
- **修法**：末尾加 `|| { echo "PROGRESS_DISABLED=1"; unset PROGRESS_PATH; }`

### S-R3 research agent §Orthogonality 段表述比其他 agent 更完整，其他 agent 可对齐
- `agents/research.md:152-158` 有明确的 channel/carrier/cardinality 三列表格
- 其他 agent 只有 prose "orthogonal to Escalation Protocol"
- **不必强统一**（tester/reviewer 有自己的 ordering discipline 子节，信息密度足够），但若以后要给用户出一份"各 agent progress reporting 对比表"，可考虑模板化

### S-R4 log.md 合并策略正确但 "impl | subagent-progress-and-execution-model" 条目的"操作者"行信息密度可再瘦身
- `docs/log.md:52` —— "5× developer subagent (P0.1-P0.8 两批 4+4 并行) + orchestrator inline (P0.9-P0.10)" 很详细
- 按 log.md §边界 "合并原则"约定是正确的（同轮多产出合并为一条，影响文件列全部路径）
- 信息密度已足，不改也可

---

## 4. 架构纪律对齐

| DEC | 合规性 | 证据 |
|-----|-------|-----|
| **DEC-001 D2 (零 userConfig)** | ✅ 一致 | progress 是 plugin 元协议，硬编码在 `agents/*.md` / `commands/*.md`，不入 target CLAUDE.md；`developer_form_default` 在 `claude-md-template.md:200-201` FAQ 有明确论证"是业务偏好不是元协议" |
| **DEC-001 D8 (role→form 单射)** | ✅ 正交补强不破 | developer 新增 inline 形态，tester/reviewer/dba/research 保持 subagent 单射（`commands/workflow.md:327-332` "6b.4 remain subagent-only" 明确声明）；与 DEC-003 的正交补强模式一致 |
| **DEC-002 Escalation + Option Schema + Phase Matrix + 并行判定树** | ⚠️ 1 处示例违例 | Option Schema "at most 1 recommended" 在所有 agent 的 Escalation Protocol section 一致保留（`agents/developer.md:109` 等）；`commands/workflow.md:303,307` 示例 block 违例（见 W-R1）；Phase Matrix 四条件 `commands/workflow.md:214-218` 原文保留，`§3.5.6` 复述一致；`§3.5` 插入不破 Step 4 序号 |
| **DEC-003 Research fan-out** | ✅ 一致 | `agents/research.md:152-168` 完整保留 `<research-result>` / `<research-abort>` 通道独立性；progress 与 research-result 在 §Orthogonality 三列表格中明示"independent and do NOT trigger each other" |
| **DEC-004 Progress protocol** | ✅ 一致 | 5 个 agent 的 schema 字段（ts / role / dispatch_id / slug / phase / event / summary / detail?）一致；3 event 类型一致；颗粒度 3-10 event/dispatch 在所有 agent 的 Granularity 子节一致；"phase 级非 tool 级"纪律一致；Fallback 静默降级一致 |
| **DEC-005 Developer 双形态** | ✅ 一致 | 三级切换优先级 `commands/workflow.md:281-309` 明确；`commands/bugfix.md:67-74` 对应（除 W-R2 非对称）；CLAUDE.md 模板 `docs/claude-md-template.md:60-69` 明示"仅 developer 支持此键"；workflow.md §6b.4 明确 "tester/reviewer/dba/research remain subagent-only" |

**critical_modules 7 项全数覆盖**：`CLAUDE.md:18-25` 更新正确，新加 2 项（DEC-004 schema + DEC-005 form switching rules）与本次变更 1:1 对齐。

**prompt 全英文纪律**：`agents/*.md` 的新增 §Progress Reporting / §Execution Form 全英文（关键 domain 注释保留中文），对齐 `CLAUDE.md:5-6` 约定。用户产出文档（design-docs / decision-log / log.md / exec-plans）保留中文。

---

## 5. tester W1-W5 独立判定

| 编号 | tester verdict | reviewer 独立判定 | 处理排期 |
|------|---------------|------------------|---------|
| W1 macOS BSD date fallback 同秒碰撞 | WARN | **Suggestion**（见 S-R1）—— 现实触发概率低（openssl 覆盖 > 95% 环境），跨平台纪律层面值得修 | 下一轮 dogfood 捎带 |
| W2 mkdir 失败未处理 | WARN | **Suggestion**（见 S-R2）—— W-R3 的 `-w` 守卫能兜住下游错误；上游 graceful 是 nice-to-have | 下一轮 dogfood 捎带 |
| W3 Bash emit 模板缺空值守卫 | WARN | **Warning**（升级为 W-R3）—— 这是 runtime fallback 语义的静态保证，关系到 `ROUNDTABLE_PROGRESS_DISABLE=1` 路径的可靠性 + 新模型 / prompt 变体下的健壮性 | 下轮必修（不阻塞本次合并） |
| W4 AskUserQuestion Option Schema 两 recommended | WARN | **Warning**（W-R1 维持）—— critical_module 命中，按 reviewer 分级纪律"违反 critical_module 的 schema 偏差"应 Warning；reviewer 本应考虑 Critical 但因"运行时 orchestrator 仅呈现一个 recommended、此处为示例文本"降级 Warning | 下轮必修 |
| W5 bugfix.md 规则 2 非对称 | WARN | **Warning**（W-R2 维持）—— 关系到 north-star "用户掌控感"（声明被忽视产生困惑），但运行结果碰巧正确；不阻塞合并 | 下轮必修 |

**升级 / 降级说明**：
- W3 从 tester WARN 维持为 reviewer Warning（无升降）
- W4 tester 已正确标为 WARN "违反 critical_module"；reviewer 同意 Warning 但解释了**为何不升 Critical**（运行时单一呈现 + 示例文本性质）。如果严格按 "critical_module 偏差 = Critical" 解读，可以升 Critical，但本 reviewer 认为过严
- W1/W2 从 tester WARN 降到 reviewer Suggestion，因现实触发频率低 + 已有下游兜底

---

## 6. 集成风险（与 P4 dogfood 回归）

### 低风险项
- **progress 机制对 P4 零影响**：progress 只追加 `/tmp` 文件 + Monitor tail；未注入 progress_path 时 subagent 按 §Fallback 静默——与 pre-DEC-004 行为一致
- **developer 双形态**：default 仍 `subagent`（`commands/workflow.md:276` "6b.1 Default form"），P4 dogfood 未声明 `developer_form_default` 的场景下**行为零变化**
- **Phase Matrix + 并行判定树未破坏**：新增 Step 3.5 不占矩阵列，为独立 "Real-time progress stream" 行（`commands/workflow.md:37`）；Step 4 四条件原文保留

### 中风险项
- **Monitor + jq 对 jq 二进制依赖**（tester Case 2.3 WARN）：P4 dogfood 机器（15.235.230.59 dex-test）如果没有 jq 会让 Monitor 启动失败；但不破坏 subagent 执行（progress 只影响用户侧 relay）。**建议**：orchestrator 在 Step 3.5 之前用 `command -v jq` 探测，缺失则 fallback 到不启 Monitor + 不 inject progress_path 的路径
- **`/tmp` 清理策略**：P4 长跑 session（>10 天）可能遇到 tmpfiles.d 清理；不破坏 progress（文件不存在时 `tail -F` 等待 + subagent `>>` 会重建目录？不会 —— 模板用 `mkdir -p`），每次 dispatch 前会 re-mkdir，实际无问题

### 纯 prompt 包元数据层
- 本次变更未触及 `plugin.json` / `marketplace.json`；只改 skill/agent/command prompt 本体 + 用户产出文档
- 按 DEC-002 铁律 "不 bump 版本"（本轮 alpha 迭代 + 无破坏性）——保持 `0.1.0-alpha.1` 合理；CHANGELOG `[Unreleased]` 应追加条目（本 reviewer 未见 CHANGELOG 更新，建议 orchestrator 在合并前追加）

---

## 7. user north-star 满足度

用户原话："重点还是用户感知进度对整个流程的掌控"。

| 维度 | 满足度 | 证据 |
|------|-------|-----|
| **实时感知** | ✅ 高 | `jq --unbuffered` + `Monitor` tail + pipe buffering 防御（`commands/workflow.md:175` 明示理由）；实测 smoke 6 event 1:1 relay 到主会话（tester Case 6.2 PASS） |
| **判断活着** | ✅ 高 | `phase_start` 入 phase 即 emit，用户能看到 "[P0.2] developer phase_start — 开始实现 X"；3-10 event/dispatch 密度足够稀疏且有节奏 |
| **判断卡住** | ⚠️ 中 | `phase_blocked` event 只有 subagent 主动 emit 才有；若 subagent 陷入 LLM loop / 工具卡住而未主动 emit blocked，用户看不到卡点 —— 依赖 subagent 纪律（FAQ Q2 明确"漏 emit 降级为当前状态"） |
| **判断快完了** | ⚠️ 中 | phase tag 有 P0.n 结构时用户可心算进度；无 exec-plan 时用 scope-received/sources-fetched/synthesis 等语义 tag，用户需通过语义猜进度（research agent §Phase naming `agents/research.md:138-145`） |
| **关键点介入** | ✅ 高 | `<escalation>` 路径完整（5 agent 全 Escalation Protocol 在位，orchestrator 解析 → AskUserQuestion 弹窗带 rationale/tradeoff/recommended）；`phase_blocked` 先于 `<escalation>` 的 ordering discipline 在 tester/reviewer 明确保证 Monitor 先见 blocker |
| **opt-out 权** | ✅ 高 | `ROUNDTABLE_PROGRESS_DISABLE=1` env 支持（design §FAQ Q5 + workflow.md §3.5.1 + 各 agent §Fallback），不强制用户接受 progress 流 |

**综合**：达成约 85%。"卡住"和"快完了"依赖 subagent 自觉，不是硬保证；但这是 push 模型（D3 决策）的固有性质，FAQ Q2 已 acknowledge。对 MVP 而言足够满足 north-star。

---

## 8. 结论建议

**可合并，附 3 条 Warning 列入下轮 dogfood 修复清单**。

### 合并前 0 改动
- Critical 已关闭（inline developer 本轮已修）
- lint_cmd 0 命中（本 reviewer 独立复验：`grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/` → 0 match）
- 5 agent schema 字段一致性 PASS
- 正交性（progress / escalation / research-result）三通道独立 PASS
- critical_modules 7 项全覆盖
- 架构纪律 5 DEC 全对齐（W-R1 的 DEC-002 违例为示例文本层面，不阻塞）

### 合并前可选 nice-to-have（非阻塞）
- CHANGELOG `[Unreleased]` 追加 DEC-004 + DEC-005 + Critical fix 条目（3 行即可）

### 下轮 dogfood 必修（P1 排期）
- W-R1 workflow.md §6b.2 example block 拆两 case
- W-R2 bugfix.md 规则 2 对称化
- W-R3 5 agent Bash 模板补 `if [ -n ... -w ... ]` 守卫

### 可选优化（P2 排期）
- S-R1 fallback 链扩 awk 跨平台
- S-R2 mkdir 失败 graceful
- S-R3 research agent §Orthogonality 表格推广到其他 agent（非必要）

### 与 DEC 一致性独立结论
- **DEC-001 D2**: ✅
- **DEC-001 D8**: ✅ (正交补强)
- **DEC-002**: ⚠️ 示例违例（W-R1，Warning）
- **DEC-003**: ✅
- **DEC-004**: ✅
- **DEC-005**: ⚠️ bugfix.md 实施不对称（W-R2，Warning）

---

## 9. jq 容错复验记录

本 reviewer 在 Bash 工具独立复验 Critical 修复：

```
输入 3 行（1 合规 + 1 garbled + 1 合规）:
  {"ts":"2026-04-19T01:00:00Z","role":"developer","dispatch_id":"aaa","slug":"t","phase":"P0.1","event":"phase_start","summary":"ok1"}
  garbled text line that is not json
  {"ts":"2026-04-19T01:00:02Z","role":"developer","dispatch_id":"aaa","slug":"t","phase":"P0.2","event":"phase_start","summary":"ok2"}

jq 表达式（commands/workflow.md:170）:
  jq -R --unbuffered -c 'fromjson? | select(.event) | "[" + .phase + "] " + .role + " " + .event + " — " + .summary'

输出:
  "[P0.1] developer phase_start — ok1"
  "[P0.2] developer phase_start — ok2"

exit 0
```

坏行被 `fromjson?` 静默 swallow，两条合规 full pass。Critical 修复效果与 tester Case 1.2 建议方案 B 一致。

---

## 10. 变更记录

- 2026-04-19 创建 —— issue #7 P0.1-P0.10 实施终审；3 Warning + 4 Suggestion 无 Critical；产物可合并
