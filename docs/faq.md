# roundtable FAQ

> 机制 / 概念 / 决策类问答沉淀。slug 级 FAQ 在各 analyst/design-docs `## FAQ` 段，与本全局 FAQ 互补。
> 由 orchestrator 按 roundtable FAQ Sink Protocol 自动追加；用户可手动编辑修订。

---

## Q: analyst/agent final message 的 created / log_entries YAML 格式由谁定义？
**提问于**：2026-04-23 session
**类别**：roundtable 机制 / Step 契约

两块 YAML + 顶部 `[project context detected]` 结构化块均为 roundtable plugin 自定义契约，非 Claude Code harness 默认：

| 输出块 | 定义位置 | 消费端 |
|--------|---------|--------|
| `[project context detected]` 结构化摘要 | `skills/_detect-project-context.md` §输出格式 | 调用方 skill/command（复用识别结果） |
| `created:` YAML | `commands/workflow.md` §Step 7 角色 report 契约 | orchestrator Step 7 phase-gate 聚合 → `{docs_root}/INDEX.md` append |
| `log_entries:` YAML | `commands/workflow.md` §Step 8 YAML 契约 | orchestrator Step 8 flush（A 类转场 / C 类过桥 / 终点 3 触发点）→ `{docs_root}/log.md` Read+Edit |

角色侧补充约束：`skills/analyst/SKILL.md` §完成后 与各 `agents/*.md` 同名段加了"Final message 输出规范"—— 唯一机读字段 = 两块 YAML；禁止 role 自写 `产出:` / `Outputs:` 自然语言清单（与 orchestrator Step 6.1 A 类 producer-pause 模板的 `产出：` 行去重，issue #29 → commit 731315c 的 dedupe 决定）。

新增 role 时必须完整实现此 3 块输出（`_detect-project-context` + `created:` + `log_entries:`），否则 orchestrator 的 INDEX/log 维护管道会丢失此 role 的产出。

---

## Q: docs/faq.md 是什么规则让 orchestrator 追加的？
**提问于**：2026-04-23 session
**类别**：roundtable 机制 / Step 0.5 FAQ Sink Protocol

规则源：`commands/workflow.md` §Step 0.5（issue #27 引入）。

触发条件（三同时成立）：
1. A 类 menu 激活期间（例如 analyst 完成后 producer-pause 菜单），用户**无 `问:` 前缀**
2. 提问命中 whitelist：
   - 专有术语 regex：`orchestrator` / `phase matrix` / `DEC-\d+` / `auto_mode` / `decision_mode` / `escalation` / `producer-pause` / `approval-gate` / `verification-chain` / `critical_modules` / `Resource Access` / `roundtable` / `roundtable:(architect\|analyst\|developer\|tester\|reviewer\|dba)` / `Step \d` / `§[0-9.a-z]+`
   - **OR** 中文通用词 `机制` / `流程` / `阶段` / `决策` / `工作流` 与上述专有术语**同句共现**
3. 未出现强制 skip 命令（`别沉淀` / `skip FAQ` / `don't FAQ` / `no faq`）

落点区分（重要）：
- **有 `问:` 前缀** → menu 循环路径；skill 回派答 FAQ；答案进 **analyst slug 级** `## FAQ`（analyst 报告内，DEC-006 §A）
- **无 `问:` 前缀**（裸问） → Step 0.5 优先；orchestrator 直接答；答案进 **global `{docs_root}/faq.md`**；**不**进入 menu 循环
- 两者互补不冲突

dedup：追加前 Read faq.md，Q 标题 lowercase + `[\s\p{P}]+` tokenize，bag-of-words Jaccard ≥0.7 判重不追加，改 ref 已有 § 锚点。

回复侧标注：sink 触发 → `📚 已追加到 {docs_root}/faq.md § Q: <标题>`；dedup 命中 → `📚 已有相关条目见 ...`。

`log_entries:` 上报：orchestrator 自造 `prefix: faq-sink` / `slug: faq-sink` 一条（prefix 已在 `docs/log.md` §前缀规范白名单）。

不触发场景：target 项目业务问题 / 调试 / 纯闲聊 / 用户明示 skip。

---

## Q: 📚 sink 回复标注由谁规定？
**提问于**：2026-04-23 session
**类别**：roundtable 机制 / Step 0.5 子契约

源：`commands/workflow.md` §Step 0.5 "回复末尾标注" 子段，issue #27 (`2ea0803 feat(workflow): FAQ sink protocol`) 引入。两种形态：

- Sink 触发 → `📚 已追加到 {docs_root}/faq.md § Q: <简化标题>`
- 去重命中 → `📚 已有相关条目见 {docs_root}/faq.md § Q: <锚点>`

作用：让用户立即可见 sink 结果。属 Step 0.5 六个子契约之一（trigger whitelist / 条目格式 / dedup / 回复标注 / `log_entries:` 上报 / A vs B 落点）。

**副观察**（dogfood）：Jaccard 算法是**标题级 token 集**，对"连环子问题"（如本 Q 与 Q2 讨论同一 Step 0.5 不同子契约）偏松，机械按规则会生成多条内容重叠的 FAQ。候选改进（future issue 范围）：增 semantic tag 或 section 归并，而非仅靠标题 Jaccard。

---

## Q: FAQ 会不会追加到 analyze / design-docs 报告末尾？
**提问于**：2026-04-23 session
**类别**：roundtable 机制 / FAQ 双层架构

会。roundtable 的 FAQ 是**双层**结构，落点取决于提问形态：

| 层 | 落点 | 触发 | 定义位置 |
|----|------|------|---------|
| slug 级 | `docs/analyze/[slug].md ## FAQ` 或 `docs/design-docs/[slug].md ## FAQ` | 用户用 `问: ...` 前缀（A 类 menu 循环路径）→ orchestrator 回派同一 skill → skill 追加到自己报告 | `skills/analyst/SKILL.md` 与 `skills/architect/SKILL.md` §输出格式 markdown template 预置 `## FAQ` 段；DEC-006 §A 菜单穷举 |
| 全局 | `docs/faq.md` | 用户无前缀裸问 roundtable 机制题（Step 0.5 优先路径）→ orchestrator 直接答并追加 | `commands/workflow.md` §Step 0.5 FAQ Sink Protocol |

两者互补不冲突（workflow.md §Step 0.5 倒数第二段明文）：A 类 `问: ...` FAQ 条目走 slug 级；非 A 类 / A 类裸问机制题走 global。

维护差异：
- slug FAQ 是**该 slug 报告的有机组成**，读报告时顺带读 FAQ 获取上下文补充；skill 自己 Write
- global faq.md 是**跨 slug 的 roundtable 机制 Q&A 池**，新人对 plugin 建立整体认知的入口；orchestrator Write

skill 自己的报告 template 在哪定义 `## FAQ` 段？—— `skills/analyst/SKILL.md` §输出格式 markdown 块结尾；`skills/architect/SKILL.md` 同位置；新建 skill 时模板沿袭。

---

