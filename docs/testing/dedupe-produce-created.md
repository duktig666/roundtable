---
slug: dedupe-produce-created
source: issue #29 P2 bug fix（commit 2f5b101 on fix/29-dedupe-produce-created）
created: 2026-04-21
description: issue #29 dedupe produce vs created fix 对抗审查测试计划
---

# 禁 `产出:` 自然语言清单 / 保留 `created:` YAML 唯一机读源 对抗审查测试计划

## 审查范围

本次 bug fix 改动 8 文件 +18 行：

- `skills/architect/SKILL.md` §完成后 +1 行 "Final message 输出规范"
- `skills/analyst/SKILL.md` §完成后 +1 行 "Final message 输出规范"
- `agents/developer.md` §完成后 +1 行
- `agents/tester.md` §完成后 +1 行
- `agents/reviewer.md` §完成后 +1 行
- `agents/dba.md` §完成后 +1 行
- `commands/workflow.md` Step 7 +1 段 "单一产出字段原则"
- `docs/log.md` `fix-rootcause` entry

全部落在 `critical_modules`（skill / agent / command prompt 本体）命中范围，故本审查必落盘。

## 覆盖现状

- lint_cmd `grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/"` 0 命中
- 无代码层测试（纯 prompt 包）；验证走 prompt 语义 + dogfood
- 本修复暂无 dogfood E2E 观察点记录

## 对抗审查 Findings

### Critical

无。

### Warning

#### W1 —— A 类 producer-pause 3 行模板"产出：" 字样与禁令字面冲突（可读性陷阱）

**定位**：`commands/workflow.md:245`（Step 6.1 A 类模板示例块）含字面 `产出：` 行；`commands/workflow.md:354` Step 7 新增条款禁 agent/skill 输出 `产出:` / `Outputs:` 自然语言清单。

**风险**：LLM 在 prompt 内同时看到「A 类模板里 orchestrator emit 的 summary 含 `产出：`」与「skill/agent 禁输出 `产出:`」时，边界（谁 emit）并非每次都从上下文精准推断出来。某些 subagent 可能保守理解为"既然有 `产出：`字样就可以我也跟着写"或者"完全不碰这 2 字"，两种误读都偏离设计意图。

**当前缓解**（已在 7 处 prompt 内强调）："orchestrator 从 `created:` 路径 + `description:` 生成用户可见 A 类 producer-pause summary，skill/agent 自带 summary 会与 orchestrator 生成重复"。语义已到位，但字面边界仍靠读者跨节对齐。

**建议**（non-blocking）：在 workflow.md Step 6.1 A 类模板示例块或 Step 7 单一产出字段段落加一句"`产出：` 行由 orchestrator 基于 `created:` 自动生成；agent/skill final message 不得自行 emit 本行或等价自然语言清单"。

#### W2 —— `log_entries.files[]` 与 `created[].path` 一致性谁校验未写清

**定位**：`commands/workflow.md:354`（Step 7 新增条款，"`log_entries.files[]` 与之一致（Step 8）"）。

**风险**：条款只声明"应当一致"，未声明校验时机与失配策略：
- 是 orchestrator 每次 Step 8 flush 前做差集对比？
- 失配时以哪边为准？（`created:` 是 INDEX 源 / `log_entries.files[]` 是 log.md 源 —— 两处落盘目标不同）
- 失配时报错 / 警告 / union / 静默？

潜在失配场景：角色新建 3 文件但 log_entries 只 union 了 2 条；或 log_entries 含已存在文件的 update 记录（`created:` 不列）。两种都算 "log.md 扩张 / INDEX 遗漏" 或反之。

**建议**：Step 7 或 Step 8 任一节加一句 "orchestrator flush 前 union 两源；`created[]` 是新建文件权威、`log_entries.files[]` 可额外含 updates"，或明示"失配时以 created[] 为准，log_entries.files[] 补集仅写进 log.md 不入 INDEX"。目前解释由读者自行推导，中长期可能在并发派发场景踩坑。

#### W3 —— 测试代码 vs 测试计划 的 `created:` 边界对 tester 未足够显式

**定位**：`agents/tester.md:125`（"代码层面的测试新增不进 log_entries（归 git log）"）和 `agents/tester.md:127`（新条款）。

**风险**：新条款禁 `产出:` 自然语言但没重申"测试代码不进 `created:`"这条既有边界。新手 LLM 读到"唯一机读产出字段是 `created:` YAML"可能把 `tests/` 下新测试文件也塞进 `created:`，污染 INDEX.md（INDEX 只识别 `docs/` 6 类 artifact，不识 `tests/`）。

**当前缓解**：tester.md `## Resource Access` 「新建文件 description」走 orchestrator Step 7；`## 完成后` 第 2 条区分"代码层 vs 测试计划"；Step 7 `{docs_root}/` 6 类清单未列 `tests/`，orchestrator 侧有过滤可能性。

**建议**（non-blocking）：tester.md 新条款改写 "**唯一**机读产出字段是 `created:` YAML（Step 7；**仅限 testing 文档等 `{docs_root}/` 产出，不含 `tests/` 代码**）"。其他 4 agent 无此二义性。

#### W4 —— 向后兼容：既有 design-doc 的 `## 产出` section 是否被误伤

**定位**：实况扫描 `docs/design-docs/phase-transition-rhythm.md:64` 含 `产出：` 字样（文档正文内的设计说明，不是 final message）。

**风险**：新条款字面 "禁止在 final message 额外输出 `产出:` / `Outputs:` 自然语言文件清单"。作用域限定短语是 "final message"，理论上不应波及落盘文档正文。但：

1. 某些 LLM 在本次派发中**同时**写 design-doc 正文**与**输出 final message 时，可能保守把正文里也去掉 `产出:` 字样（过度合规）
2. 历史文档正文的 `产出:`（如 phase-transition-rhythm.md:64）会不会在下次 architect 迭代时被当"存量违规"误删

**当前缓解**：7 处新增条款全部带 "final message" 作用域限定词。语义正确。

**建议**：若未来出现 LLM 过度合规删除文档正文 `产出:`，加一句"仅限 final message stdout；落盘文档正文的 `## 产出` / `产出：` 段落属业务内容，不受本条款约束"。本轮可不加，留作 follow-up。

### Suggestion

#### S1 —— 7 处表述基本一致，微调可更统一

**定位**：7 处新增条款措辞对比：

- architect/analyst skill：`**禁止**在 final message 额外输出 ... —— orchestrator 会从 ...`
- developer/tester/reviewer/dba agent：`**禁止**额外输出 ... —— orchestrator 生成用户可见 summary，subagent 自带 summary 重复浪费 token`（developer tester 多一句 "浪费 token"；reviewer/dba 少"浪费 token"）

发现细差：developer.md:118 尾句 "subagent 自带 summary 重复浪费 token"；tester 同；reviewer/dba 无。analyst/architect skill 句尾 "skill 本层自带 summary 会与 orchestrator 生成重复"。

**建议**：统一尾句风格（可保留 skill vs agent 差异但同类内部一致）。nit，不阻塞。

#### S2 —— `commands/workflow.md:354` 条款位置可再优化

**定位**：Step 7 末段新条款 "**单一产出字段原则**（issue #29）"。

**观察**：条款置于 Step 7 Index Maintenance 尾、Fallback 句之前。语义与 Step 7 主旨（INDEX 维护）部分相关但跨越到 final message 规范；放 Step 8（log.md batching）之前做桥段落也合理。

**建议**：当前位置可接受；未来如果 Step 7/8 之间出现更多跨节约束，考虑抽一个独立 §Step 7.5 或 Final Message Schema 段。nit。

#### S3 —— 缺 dogfood E2E 观察点清单

**定位**：`docs/log.md:24`（fix-rootcause entry 验证段）写"后续 /roundtable:workflow 派发观察 final message 应不再含 `产出:` 段"但没具体观察清单。

**建议**：follow-up 补一条观察点：
- O1：架构/分析 skill 在 Stage 3/2 收尾 `log_entries:` + `created:` YAML 后是否还跟自然语言 `产出:` 段
- O2：developer/tester/reviewer/dba subagent final report 头部摘要段是否省掉 `产出:` 行
- O3：orchestrator A 类 producer-pause 3 行 summary 是否正确从 `created:` 自动生成（不是 skill/agent 自写）
- O4：测试 tester 派发后 INDEX.md 不意外多出 `tests/` 条目（W3 相关）

可写 `docs/testing/dedupe-produce-created.md` §观察点 或 log.md append。

### Positive

- **P1**：修复遵守 producer-pause 既有边界（不动 orchestrator A 类模板本身；agent/skill 单向约束；orchestrator 从 `created:` 生成仍合约）
- **P2**：7 处措辞均含 "final message" 作用域限定词，正确限制副作用不波及文档正文
- **P3**：新条款全部引 issue #29 便追溯；与 Step 7 `created:` 契约 / Step 8 `log_entries:` 契约 cross-ref 清晰
- **P4**：lint 0 命中，未引入硬编码外部名 / 路径
- **P5**：`docs/log.md` fix-rootcause entry `tier=1` 格式齐全（操作者 / 影响文件 / 分析三段），遵守 DEC-014

## 矛盾 / 兼容性检查

### 与 DEC-006 producer-pause A 类 3 行模板
- 模板 `产出：` 行由 orchestrator emit，不归 agent/skill；新条款限定 "skill/agent final message 不得自行输出"，**语义兼容**
- 字面层的"字 `产出：` 出现在 workflow.md 内部两处"可能读者混淆见 W1

### 与 DEC-009 log_entries `files:` union 规则
- log_entries.files[] 是 log.md flush 源；created[] 是 INDEX.md flush 源
- 新条款声明两者应一致 —— 互补非冗余，**语义兼容**，校验细节见 W2

### 与 DEC-014 fix-rootcause entry 格式
- log.md:17-24 entry 格式遵守 tier=1（无 tier=2 postmortem 引用），**兼容**

### 与 DEC-013 decision_mode text
- 不涉及（新条款纯 final message 产出规范，不改 `<decision-needed>` emit 路径）

## 结论

- **可合并**（未发现 Critical 或 Warning 阻塞项）
- 4 个 Warning 均为语义边界澄清 / 向后兼容 nit，均可 follow-up issue 吸收
- 强烈建议至少处理 W1（A 类模板 `产出：` 字面冲突一句话注释）与 W2（一致性校验规则一句话澄清）—— 两项在下次 A 类转场派发前易被 LLM 误读，合并至本 PR 成本 <2 行

## 变更记录

- 2026-04-21 tester 对抗审查 —— 0 Critical / 4 Warning (W1-W4) / 3 Suggestion (S1-S3) / 5 Positive (P1-P5)；结论可合并，建议至少吸收 W1+W2
