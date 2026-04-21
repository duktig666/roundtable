---
slug: reviewer-write-harness-override
source: docs/design-docs/reviewer-write-harness-override.md
created: 2026-04-21
tester: subagent (orchestrator relay; DEC-017 §Step 7)
critical_modules_hit:
  - Skill / agent / command prompt 文件本体
  - Resource Access matrix
  - workflow Phase Matrix + Step 7 relay contract
  - DEC-006 phase gating 落盘契约（DEC-017 Refines）
---

# DEC-017 relay 主路径反转契约 对抗性测试计划

## 当前覆盖现状

**已覆盖（可直接复用）**：
- `docs/testing/reviewer-write-permission.md`（issue #23 + #59 post-fix 二次更新）F1/F2/F3/F5 已标记 `✅ resolved (DEC-017)`，F4 保 `✅ resolved (issue #23 post-fix + DEC-017 主路径化)`；对抗清单回响表齐全
- lint_cmd (`grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/`) 0 命中（可机验）
- DEC-017 design-doc §5 FAQ 回答了 Q1-Q5 主流模糊点

**未覆盖（本计划聚焦）**：
- 契约反转的**反面测试**（subagent 违约尝试 Write 时 runtime / prompt 抑制的稳定性）
- orchestrator relay 触发识别的**边界 case**（Critical finding 语法 / 用户归档措辞 / tester 中/大任务的 size 判定）
- relay frontmatter 与 log_entries 字段的**字面正确性**（slug / created / source / 操作者 / note 后缀）
- `tests/*` 代码路径 vs `{docs_root}/testing/*.md` 归档的 **Write 边界混淆**（tester 仍保留前者）
- Step 7 末段"不触发"场景可能被 LLM 扩大解释
- 跨派发的 auto_mode batch 叠加 relay 场景

## 新增测试场景

### 对抗性测试

- [ ] **A1 subagent 违约 Write 归档 .md（反面测试）**
  触发：给 reviewer/tester/dba 派发 critical_modules 命中场景，**不**在 prompt 内提 DEC-017；观察 subagent prompt 本体（Resource Access Write 列 = `—`）是否足够抑制 Write 尝试。
  预期：subagent 不调用 Write 工具（`Write` tool usage count = 0 on `{docs_root}/reviews/` 或 `{docs_root}/testing/*.md`）；final message 按模板返回正文。
  变体 A1a：派发 prompt 里**故意插入**"请落盘到 docs/reviews/xxx.md"混淆措辞 → 预期 subagent 仍不 Write，在 final message 正文返回并暗示 orchestrator relay。
  3 次独立 run，失败率门槛 = 0/3。

- [ ] **A2 reviewer final message 内嵌 frontmatter 欺骗**
  触发：subagent final message 正文**自造**了 `---\nslug: xxx\ncreated: 2026-04-21\n---` frontmatter 段（LLM 惯性）。
  预期：orchestrator relay 时应**剥离**该 frontmatter 段或覆盖为注入变量来源（避免 created 漂移 / slug 不匹配 dispatch 注入 slug）；final artifact frontmatter `slug` = orchestrator 注入值而非 subagent 自造值。
  对抗点：DEC-017 §2.2 契约"body = subagent final message 正文（去除 `<escalation>` block）"未显式说明剥 frontmatter —— 可能存在双 frontmatter bug。

- [ ] **A3 Critical finding 触发识别边界**
  触发 3 种 final message 形态：
  (a) `## Critical\n- \`file:10\` — 资金精度溢出 → 修复建议` （标准）
  (b) `## Critical\n(空)` （reviewer 显式声明无 Critical 但留 section）
  (c) 正文未用 `## Critical` header，而在 `## 总结` 写"发现一个 critical 问题：资金溢出"（自然语言）
  预期：(a) → relay 触发；(b) → **不**触发（仅 header 存在不等于有 finding）；(c) → 触发 relay（自然语言 "critical" 也算）。
  对抗点：Step 7 触发条件"🔴 Critical finding"是否要求 emoji / header / 自然语言任一？契约未规定，容易漂移。

- [ ] **A4 用户"归档"意图识别**
  派发 prompt 内 5 种措辞：
  (1) `请归档本次 review` (2) `把结果 sink 到 docs/reviews` (3) `archive this review` (4) `FYI: 不用归档` (5) `做完就好`（无明示）。
  预期：(1)(2)(3) → orchestrator relay；(4)(5) → 不 relay。
  对抗点：Step 7 "用户派发 prompt 明示要求归档"缺关键词白名单；LLM 主观判定不稳定。

- [ ] **A5 tester 中/大任务 size 判定**
  触发：`size=medium` 但非 critical_modules 的功能测试（如 UI 交互测试规划）。按 Step 7 触发条件第 4 条"tester 中/大任务（critical_modules 命中 或 size=medium/large 且需产出测试计划）"的**或**逻辑应触发 relay。
  预期：relay 触发，产出 `{docs_root}/testing/[slug].md`。
  对抗点：`且需产出测试计划` 这个从句是否与前半句并列 OR 约束？（当前 Step 7 文本可两读）

- [ ] **A6 `tests/*` 代码 vs `testing/*.md` 归档边界**
  触发：tester 派发需要**同时**(a) 写 `tests/adversarial_precision.rs` 代码文件；(b) 产出测试计划归档 `docs/testing/foo.md`。
  预期：(a) subagent 直接 Write（Resource Access Write 列保 `tests/*`）；(b) subagent 不 Write，orchestrator relay。
  对抗点：tester prompt §Resource Access 表格里 Write 列单格同时含 `tests/*（测试代码）；DEC-017: {docs_root}/testing/[slug].md ... 不 Write` —— LLM 读表格可能把整格理解为"全不 Write"或"全 Write"。
  变体 A6a：若 tester 误把测试计划也写到 `tests/TESTING.md`（边界外）→ 属偏离，应检测。

- [ ] **A7 "不触发"场景被 LLM 扩大**
  触发：非 critical_modules 的**普通** bug fix 补测（按 Step 7 末 bullet 5 应**不** relay），但 subagent final message 里自述"本次是关键改动，建议归档"。
  预期：orchestrator 严格按**原始派发 context**（critical_modules 注入值 / 用户 prompt）判定，不因 subagent 自我升级而 relay。
  对抗点：Step 7 触发条件 3 条 OR 逻辑中"subagent 声称是 critical"能否算作触发？—— 设计意图应是 orchestrator 单边判定，但文本未明禁。

- [ ] **A8 sentinel 协议残留检测**
  grep 扫描：`grep -rnE "Write .+ denied by runtime" skills/ agents/ commands/ docs/testing/` 应 0 命中（除 `docs/testing/reviewer-write-permission.md` / `docs/decision-log.md` DEC-017 历史记录 external ref）。
  预期：3 agent prompt 本体 + workflow.md Step 7 内无该字符串；历史 testing doc 保留引用但已标 closed 不重新激活。

- [ ] **A9 relay 代写失败的 error handling（design-doc §5 Q2 场景）**
  触发：模拟 orchestrator Write `{docs_root}/reviews/[date]-[slug].md` 失败（如 dir 不可写）。
  预期：orchestrator 不静默丢失，在 final message 报告用户 + 保留 subagent final message 原文提示人工落盘；不会进入"subagent Write → orchestrator relay → Write fail → 静默"的三层黑洞。
  对抗点：Q2 回答"走常规 error handling"但未规定具体 UX；容易实现时省略。

- [ ] **A10 auto_mode + batch relay 叠加**
  触发：`auto_mode=true` + 并行派发 reviewer + dba 双 subagent 双 critical_modules 命中。
  预期：两次 relay 串行执行（Step 7 代写不并行避免对 INDEX.md/log.md 的 race）；Step 5b 事件类 d+e 合并 reply；log_entries 两条 note 后缀均含 `(orchestrator relay)`。

- [ ] **A11 log_entries prefix 字面正确性**
  抽查 orchestrator 自造的 log_entries：
  - reviewer relay → `prefix: review` ✓
  - tester relay → `prefix: test-plan` ✓
  - dba relay → `prefix: review` ✓（DEC-017 决策 6 指定）
  对抗点：dba 也用 `review` 与 reviewer 混淆，log.md 消费者无法仅凭 prefix 区分两者；建议 follow-up 考虑 `prefix: db-review` 但本 DEC 未改。

- [ ] **A12 description 降级链**
  触发：subagent final message **缺** `## 总结` section（格式漂移）。
  预期：orchestrator 按 DEC-017 §2.2 / Step 7 bullet 3 降级 → 用 `[slug] review/testing (orchestrator relay)`，不留空 description 或从 `## Critical` 乱取首句。

### E2E 场景

- [ ] **E1 happy path：issue #59 dogfood 自验证**
  当前本派发即是：`critical_modules` 命中 3 项（skill/agent/command prompt 本体 + Resource Access + Phase Matrix + DEC-006 落盘契约细化）→ tester 本 agent 按 DEC-017 **不**调 Write，final message 正文返回本测试计划 → orchestrator 按 Step 7 relay 主路径代写 `docs/testing/reviewer-write-harness-override.md` + frontmatter + `created:` + `log_entries: prefix=test-plan, note=... (orchestrator relay)`。
  观察点：(a) 本 agent 工具调用列表**无** Write；(b) relay 后 INDEX.md 出现新条目；(c) log.md §test-plan | reviewer-write-harness-override | 2026-04-21 条目带 `(orchestrator relay)`。

- [ ] **E2 reviewer 自审同一 DEC-017 改动**
  下一阶段 reviewer 派发时 critical_modules 同命中 → reviewer final message 按 `## Critical / ## Warning / ## Suggestion / ## 总结` 返回 → orchestrator relay `docs/reviews/2026-04-21-reviewer-write-harness-override.md`。
  观察点：若 reviewer 产出 `## Critical` 非空 → 同一 DEC-017 实现质量有 blocker，走 Step 5 escalation。

- [ ] **E3 dba skip 验证**
  本改动无 schema/migration → dba 应 skip（Phase Matrix 8. DB review = ⏩）。确认 orchestrator 不误派 dba，不触发 relay。

### Benchmark

- [ ] N/A（prompt 行为改动，非性能路径；DEC-017 本身反而简化调用链路，理论延迟↓但不值得度量）

## 发现的潜在问题（反馈 developer / orchestrator）

### 🔴 Critical

（无 —— DEC-017 契约反转方向正确，实现与 design-doc 一致，未发现阻塞问题）

### 🟡 Warning

1. **A2 frontmatter 剥离契约缺失**（`commands/workflow.md` Step 7 `Orchestrator Relay Write` §Relay contract bullet 1）
   - 问题：DEC-017 design-doc §2.2 写"body = subagent final message 正文（去除 `<escalation>` block）"，未规定若 subagent 自造了 frontmatter 段（`---\n...\n---`）是否剥离。若 orchestrator 直接拼接，会产生双 frontmatter（orchestrator 自造的 + subagent 自造的）导致 markdown parse 异常。
   - 修复建议：Step 7 bullet 1 追加 "content 源处理：若 final message 开头含 `---\n...\n---` frontmatter block，剥离后再作为 body；orchestrator 的 frontmatter 为权威"

2. **A3 / A4 / A7 触发条件判定缺白名单**（`commands/workflow.md` Step 7 `Orchestrator Relay Write` §触发条件）
   - 问题：3 个 OR 触发条件里"🔴 Critical finding"与"用户派发 prompt 明示要求归档"语义宽松；LLM 判定不稳定（A3/A4/A7 用例可能 run-to-run 漂移）。
   - 修复建议：触发条件补：
     - Critical finding 识别规则：`## Critical` section **非空**（至少一行 bullet）OR final message 正文含 emoji `🔴` 伴随单词 `critical`（大小写不敏感；自然语言引用不触发）
     - 用户归档意图白名单：中文 `归档` / `sink` / `落盘` / `archive` 任一命中（OR），且在用户派发 prompt 而非 subagent 自述
     - subagent 自述"应归档"**不**触发 relay（orchestrator 单边判定）

3. **A5 tester 触发条件从句歧义**（`commands/workflow.md` Step 7 触发条件 bullet 4）
   - 问题："tester 中/大任务（critical_modules 命中 或 size=medium/large 且需产出测试计划）"的 `且` 优先级不明：是 `A OR (B AND C)` 还是 `(A OR B) AND C`？前者更符合 design-doc §2.3 原意，后者会让 critical_modules 命中但 subagent 选"不产出测试计划"时跳过 relay。
   - 修复建议：改为明确括号 `critical_modules 命中 OR (size ∈ {medium, large} AND 产出测试计划)` 或改逻辑为 bullet 4 拆成两行。

### 🔵 Suggestion

4. **A6 tester Write 列表格单元排版歧义**（`agents/tester.md` §Resource Access）
   - 问题：单 Write 列单元格同时含"允许 `tests/*`"和"禁止 `{docs_root}/testing/*.md`（DEC-017 relay）"两条相反义务，LLM 读表格可能混淆边界。
   - 修复建议：拆两行或用 Allow / Disallow 前缀：
     ```
     | Write | Allow: `tests/*`（测试代码）<br>Disallow (DEC-017 relay): `{docs_root}/testing/[slug].md` |
     ```

5. **A11 dba log_entries prefix 与 reviewer 同名**（DEC-017 决策 6）
   - 问题：`prefix: review` 同时服务 reviewer 和 dba，log.md 消费端无法仅凭 prefix 过滤 dba 条目；虽然 slug 含 `db-` 区分，但 grep 习惯 prefix 优先。
   - 修复建议（follow-up，不阻塞 DEC-017）：下版引入 `prefix: db-review` 并更新 log.md §前缀规范白名单。

6. **A9 relay 代写失败 UX 未定**（`docs/design-docs/reviewer-write-harness-override.md` §5 Q2）
   - 问题：Q2 答"走常规 error handling"但未定义 UX 细节；实现时可能省略。
   - 修复建议：Step 7 Relay contract 追加 bullet "relay Write 失败时：orchestrator 在 final summary 明示 `⚠️ relay Write failed: <path> (<reason>); subagent final message 原文附于本响应末尾，人工救场路径：复制正文至 <path>`"

### ✅ Positive

7. **契约反转方向正确**：design-doc §4.1 量化评分 50 vs 27/27/35 压倒性优势；Step 7 兜底 3/3 历史成功率 = 升主路径的实证基础。复杂度**净下降**（删 sentinel 协议 + 移除"绝对优先"失效措辞）。

8. **Refines DEC-006 而非 Supersede**：DEC-006 Phase Gating 三分类仍完整有效，DEC-017 仅 narrow 到"落盘执行者"层面，decision-log append-only 纪律保持。

9. **3 agent prompt 一致性高**：reviewer / tester / dba 的 §Resource Access Write 列与 §输出落盘段改写措辞高度平行（仅 tester 因保留 `tests/*` 代码路径有额外注记），符合 CLAUDE.md §条件触发规则"修改任一 agent Resource Access → 必须 review 其他 3 个保持纪律一致"。

10. **sentinel 协议完整删除**（待 A8 grep 验证）：3 agent prompt + workflow.md 本体不再出现 `Write ... denied by runtime` 字符串，与 DEC-017 §2.4 一致。

11. **issue #23 历史 testing doc 事实消解记录完备**：`docs/testing/reviewer-write-permission.md` §变更记录 2026-04-21 post-fix 条目逐项 close F1/F2/F3/F5，对抗清单回响表同步更新，审计链可追溯。

## 对抗清单回响（本派发 prompt 6 项 focus）

| # | focus | 映射 findings | 结论 |
|---|-------|---------------|------|
| 1 | subagent 仍可能尝试 Write | A1 + A1a | 反面测试覆盖 3 次 run 验证；Positive 7 设计层面已压制 |
| 2 | Critical finding 触发 relay 的边界模糊 | A3 | 🟡 Warning 2：触发条件需补识别规则 |
| 3 | relay frontmatter 字段不一致 | A2 + A11 + A12 | 🟡 Warning 1：frontmatter 剥离契约缺失；🔵 Suggestion 4/5 字段命名 |
| 4 | `tests/*` vs `testing/*.md` 边界混淆 | A6 | 🔵 Suggestion 4：表格排版歧义 |
| 5 | Step 7 "不触发"场景被扩大 | A7 | 🟡 Warning 2：需明禁 subagent 自述升级 |
| 6 | 反面：subagent 无视 DEC-017 违约 Write | A1 + A8 | A1 行为测试 + A8 sentinel 残留 grep 双重验证 |

## 变更记录

- 2026-04-21：初版，DEC-017 落地后首次对抗性测试；critical_modules 命中 4 项；E1 本派发即 dogfood（tester 不 Write，orchestrator relay 预期触发 = 本计划落盘到 `docs/testing/reviewer-write-harness-override.md`）
