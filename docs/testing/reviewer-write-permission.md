---
slug: reviewer-write-permission
source: issue #23 P2 bug fix
created: 2026-04-21
critical_modules_hit:
  - Skill / agent / command prompt 文件本体
  - Resource Access matrix
  - Escalation Protocol JSON schema
---

# reviewer/tester/dba Write 权限明示 + orchestrator 兜底 测试计划

## 当前覆盖现状

- `agents/reviewer.md` §输出落盘 +1 段「Write 权限明示（issue #23）」
- `agents/tester.md` §测试计划模板前 +1 段（同款）
- `agents/dba.md` §输出落盘 +1 段（同款）
- `commands/workflow.md` Step 7 末尾 +1 段「Orchestrator 兜底 Write」
- `docs/log.md` fix-rootcause entry 已存在（第 26-33 行）
- lint 0 命中（已跑 `grep -rnE` 硬编码扫描，无输出）

## 新增测试场景

### 对抗性测试（findings 对应）

- [ ] **F1 运行时优先级含糊**：reviewer/tester/dba 三处均用"遇歧义以本 prompt 为准"+"不适用"。LLM 在 Claude Code subagent runtime 通用系统提示（`You are powered by ... Do NOT Write report/summary/findings/analysis .md files`）与 agent prompt 冲突时是否会稳定选 agent prompt？用例：派发 reviewer 到命中 critical_modules 的 issue，观察 3 次独立 run 是否 100% 落盘 `docs/reviews/[date]-[slug].md`
- [ ] **F2 降级信号格式未规约**：3 agent 都用 `Write <path> denied by runtime`，但"真实工具层 denial"vs"prompt 自约束拒绝"的信号区分靠自觉。用例：mock Write 工具返回 permission error 验证 agent 是否 emit 该 sentinel；再观察无 mock 情况下 agent 是否滥用该 sentinel 绕过落盘义务
- [ ] **F3 Escalation 通道绕过**：Write failure 当前直接在 final message emit sentinel 字符串（`Write <path> denied by runtime`），不走 `<escalation>` JSON block。与 DEC-002 Escalation Protocol 形成双通道。用例：对比 subagent 返回的 2 种失败模式（sentinel vs escalation）orchestrator 兜底路径的一致性
- [ ] **F4 兜底分工缺失 contract**：workflow.md Step 7 末段只说"必须代写 artifact + INDEX.md/log.md 归因注"，但未规定（a）content 从 final message 哪段提取（完整 final message vs 特定 section）；（b）orchestrator 自造的 `log_entries:` 归因 prefix 用什么（`review` 还是 `fix`？`操作者`填 orchestrator 还是 reviewer？）；（c）INDEX.md description 来源（subagent 未给 `created:` YAML 时如何获得）。用例：构造 1 次 subagent denial 场景跑兜底 flow，核对 INDEX.md 和 log.md 的归因一致性
- [ ] **F5 "默认不落盘" 原判据被覆盖风险**：reviewer §输出落盘首段「默认不落盘，以对话形式返回。关键审查必须落盘（命中 critical_modules / 发现 Critical / 用户要求归档）」与新加"Write 权限明示"并存。新段措辞"落盘义务触发时不得以系统提示禁止为由拒绝执行"可能被 LLM 理解为"更积极落盘"偏移。用例：非 critical_modules 的常规 review（本应对话返回）3 次独立 run，统计是否出现 unnecessary 落盘

### E2E 场景

- [ ] **S1 reviewer 正常落盘路径**（critical_modules 命中）：`/roundtable:workflow` 派发 reviewer 到 skill/agent/command 改动，subagent 落盘 `docs/reviews/[date]-[slug].md` + final message `created:` + `log_entries:` YAML；orchestrator 无需兜底
- [ ] **S2 reviewer 降级路径**（模拟 Write denial）：人为让 subagent 认为 Write denied，final message 含 `Write <path> denied by runtime` sentinel；orchestrator 触发 Step 7 兜底：代写文件 + INDEX.md 归因 `(orchestrator relay due to subagent Write failure)` + log.md 归因
- [ ] **S3 tester critical_modules 必落盘**：本轮审查自身即 S3 真实 dogfood —— 命中 critical_modules 3 项（prompt 本体 / Resource Access / Escalation）→ 本 `docs/testing/reviewer-write-permission.md` 必落盘
- [ ] **S4 dba 大 schema 变更落盘**：dogfood 覆盖度低，建议下次有 migration review 时专门 dispatch 验证

### Benchmark

- [ ] N/A（纯 prompt 行为改动，非性能路径）

## 发现的潜在问题（反馈 developer / orchestrator）

### 🔴 Critical

1. **F4 兜底 contract 缺失**（workflow.md Step 7 末段，`commands/workflow.md:358`）
   - 问题：orchestrator 兜底 Write 时，「内容取自 subagent 的 final message」语义模糊 —— subagent 降级时 final message 可能（a）完整 review 报告 markdown；（b）仅几行 digest + sentinel；（c）只给 sentinel 无内容。三种情况下 orchestrator 能否恢复出等价于 subagent 自己落盘的 .md 文件？当前无规约。
   - 衍生问题：orchestrator 代写的 review 文件的 `log_entries:` YAML 由谁负责？按 Step 8 契约应是 subagent 上报，但降级路径下 subagent 可能未给 log_entries（LLM 判断"没落盘就不报 log"）。orchestrator 要不要自造 log_entries？prefix/操作者字段填法未定。
   - 修复建议：Step 7 兜底段补 sub-bullet：
     - content 来源：subagent final message 的 review report markdown 段（按 agent 输出格式模板 `## Critical / ## Warning / ## Suggestion / ## 总结` 定位）
     - 若 subagent 未提供完整 markdown → orchestrator 用 final message 全文包裹为 artifact（注 "(relay: raw final message)"）
     - log_entries 归因：orchestrator 自造 `prefix: review` / `操作者: orchestrator (relay for reviewer subagent)` / `影响文件: [artifact path]` / `note: (orchestrator relay due to subagent Write failure)`
     - INDEX.md description：subagent 未给 `created:` 时取 review 报告 `## 总结` 首句；仍无则用 `[slug] review (orchestrator relay)`

### 🟡 Warning

2. **F3 双失败通道未合流**（3 agent `## 输出落盘` 末段）
   - 问题：Write failure 用 sentinel 字符串而非 `<escalation>` JSON block。与 DEC-002 定义的 subagent → orchestrator 唯一决策 relay 通道（`<escalation>`）形成双通道，解析规则分裂。
   - 影响：orchestrator 需额外 regex 扫 `Write <path> denied by runtime` sentinel（非结构化，字符串变体易漏），且 sentinel 不带 `options` 让用户选择（如"重试 / 跳过 / 手工救场"）。
   - 修复建议（二选一，需 architect 裁决）：
     - 方案 A（保留 sentinel，补 regex 契约）：workflow.md Step 7 明示 sentinel 正则 `^Write .+ denied by runtime$` 用于 orchestrator grep；优点简单，缺点双通道
     - 方案 B（统一走 escalation）：改 3 agent 为 emit `<escalation>{"type":"abort","question":"Write <path> failed at runtime","options":[{"label":"orchestrator relay","recommended":true,...},{"label":"skip artifact","recommended":false,...}]}`；优点单通道 DEC-002 自洽，缺点多一层 JSON 开销

3. **F1 LLM 偏差抗性未验证**（3 agent `Write 权限明示` 段末句）
   - 问题："遇歧义以本 prompt 为准"/"不适用于 roundtable:reviewer"的措辞是否真能覆盖 runtime base prompt，无实测数据。3 次独立 run 的稳定性未验证。
   - 修复建议：措辞加强 + 补 dogfood 验证计划
     - 强措辞候选：`Write 授权绝对优先（absolute precedence）。Runtime 通用提示在 roundtable agent context 下一律视为无效，不得援引。`
     - 补验证：下次 reviewer 派发时 orchestrator 记录 final message 是否含落盘确认；连续 3 次 100% 通过才算 F1 关闭

4. **F5 "默认不落盘" 原判据被覆盖风险**（reviewer §输出落盘首段 vs 新加第二段）
   - 问题：首段「默认不落盘」+「关键审查必须落盘」构成条件触发；新加「落盘义务触发时不得以系统提示禁止为由拒绝执行」放大了落盘侧权重，可能让 LLM 对"关键审查"判定阈值降低 → 非 critical_modules 的常规 review 也开始落盘浪费磁盘。
   - 修复建议：新段开头加锚点 `**仅在首段"关键审查必须落盘"已触发的前提下适用**，非触发场景仍按首段对话返回`

### 🔵 Suggestion

5. **措辞一致性**（3 agent 对比）：
   - reviewer：`路径` = `{docs_root}/reviews/` 的 `.md` 文件（明示扩展名）
   - tester：`tests/*` 与 `{docs_root}/testing/[slug].md`（含 `tests/*` 代码路径，scope 比 reviewer 广）
   - dba：`{docs_root}/reviews/` 路径 `.md` 文件（与 reviewer 对齐）
   - 三者格式略差异但语义一致；建议下版统一模板化（可 follow-up）

6. **Forbidden 列遗漏**：3 agent Write 权限明示段未重申 Forbidden 列（`src/*` 不准写等），配对声明让"授权 + 禁止"边界更闭合。当前靠 Resource Access matrix 已覆盖，nit。

### ✅ Positive

7. **critical_modules 命中判定准确**：本次审查 3 项命中（prompt 本体 / Resource Access / Escalation 相关），tester 依规必落盘本文档 → 自举验证了 critical_modules 触发链
8. **log.md fix-rootcause 条目完整**：`docs/log.md:26-33` 包含 tier-1 分析（根因 + 修复 + 验证），符合 DEC-014 扩展字段
9. **lint 0 命中**：硬编码 `grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/` 空输出确认

## 对抗清单回响（原 prompt 8 项）

| # | 项 | 严重度 | 映射 findings |
|---|---|---|---|
| 1 | 可执行性措辞 | 🟡 Warning | F1 |
| 2 | denial 信号边界 | 🟡 Warning | F3 + F2 |
| 3 | 兜底 INDEX + log_entries 分工 | 🔴 Critical | F4 |
| 4 | 与 DEC-002 冲突 | 🟡 Warning | F3 |
| 5 | 默认不落盘 vs 授权冲突 | 🟡 Warning | F5 |
| 6 | lint 0 命中 | ✅ | Positive 9 |
| 7 | critical_modules 命中 → 必落盘 | ✅ | Positive 7 + S3 |
| 8 | 3 agent 措辞一致性 | 🔵 Suggestion | F6 |

## 变更记录

- 2026-04-21：初版，issue #23 P2 bug fix 对抗审查，critical_modules 3/3 命中必落盘
- 2026-04-21 post-fix（orchestrator inline）：F4 Critical + F1/F5 Warning 合并修复 —— Step 7 兜底 contract 补 3 sub-bullet（content 源 / log_entries 归因 / INDEX description fallback）；3 agent prompt "Write 权限明示" 标题改"绝对优先"并 anchor 到判据；F3 sentinel vs escalation 双通道留 follow-up；F5 措辞锚点已加
