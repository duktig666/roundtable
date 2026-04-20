---
slug: tg-forwarding-expansion
source: design-docs/tg-forwarding-expansion.md + commands/workflow.md Step 5b + DEC-013 post-fix 2026-04-21
created: 2026-04-21
status: Final Review
reviewer: opus-4-7 (dispatch reviewer-#48-001)
verdict: Approve-with-caveats
---

# DEC-013 §3.1a Active Channel Forwarding 扩展 Final Review

## 0. 审查范围与依据

- **变更文件**：`commands/workflow.md`（Step 0 尾 / Step 1 尾 / 新增 Step 5b / Step 6.1 A+C 类尾注 / §Auto-pick 末尾 共 5 钩子）、`commands/bugfix.md`（Step -1 末尾 ref 段）、`docs/design-docs/tg-forwarding-expansion.md`（新建）、`docs/decision-log.md`（DEC-013 影响范围段 append-only post-fix 2026-04-21）、`docs/INDEX.md` + `docs/log.md`。
- **依据**：DEC-013（全 11 决定 + 影响范围段全部 post-fix）、DEC-010 精简与影响范围 ≤10 行约束、DEC-014 critical_modules 落盘、DEC-015 auto_mode §Auto-pick、memory `feedback_tg_reply_format` / `feedback_tg_decision_needed_codeblock` / `feedback_tg_decision_mode_text_reply`。
- **critical_modules 命中**：3/3（workflow Phase Matrix / Escalation Protocol §3.1a 文本结构 / skill-agent-command prompt 本体）→ 按 DEC-014 reviewer 必落盘，即本文件。
- **lint**：`grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/` → 0 命中 PASS。

## 1. DEC-013 Accepted 决定一致性（维度 1）

| 决定 | 审查 | 结论 |
|------|------|------|
| 决定 1 双模式 | 本扩展不涉及 modal/text 切换，只规定 text-compatible 事件转发 | 不违反 |
| 决定 3 最小改动（agent prompt 零改动）| 5 事件类全部 orchestrator-emitted；skill/agent 本体未碰 | 符合 |
| 决定 8 展现与接收解耦 | 转发仍是 orchestrator 内部动作，检测 `<channel source>` tag，不硬编码前端。Step 5b 末段显式复述此边界 | 符合 |
| 决定 9 与 DEC-002/003 正交 | 本扩展只加转发策略，未碰 Escalation JSON / research JSON | 正交保持 |
| 决定 11 dogfood | 本次 issue #48 本身即 TG-driven dogfood 触发 | 一致 |

**结论**：DEC-013 Accepted 条款无违反；扩展限定在「影响范围」段的 append-only clarification 层，未升级为新决定。

## 2. append-only clarification 正当性（维度 2）

- **先例支撑**：2026-04-20 §3.1a（issue #38）已以 post-fix append-only 方式入 DEC-013 影响范围段，本轮 §3.1a 扩展为同类性质改动（对 §3.1a 的 scope 扩展而非决定本身反转），路径正当。
- **issue #48 body 显式要求**不新开 DEC，执行一致。
- **DEC-010 决定 10「影响范围 ≤10 行」合规性**：F12 Suggestion 已标。当前 DEC-013 影响范围段合计 ~30 行（初始 ~10 + post-fix 04-20 ~5 + post-fix 04-21 ~6）。DEC-010 决定 10 原文「DEC 影响范围段 ≤10 行，超出外链 design-doc」**字面不豁免 post-fix**。本次合入**不强求结构重构**，但建议（见下 §5 Suggestion R2）在 DEC-010 脚注标注「post-fix clarification 不计入 10 行限额；累积到 3 次时必须结构拆分或外链」。

## 3. 与其他 DEC 的正交（维度 3）

逐一扫描：

| DEC | 正交性 | 备注 |
|-----|--------|------|
| DEC-004 progress schema | 未碰 event schema | 正交 |
| DEC-005 developer 双形态 | 未碰 | 正交 |
| DEC-006 phase gating A/B/C | Step 6.1 A+C 类尾注追加转发触发，不改 gating 语义 | 正交；F1 已 inline 修 |
| DEC-007 progress content policy | 未碰 | 正交 |
| DEC-008 前台 skip Monitor | 未碰 | 正交 |
| DEC-009 log batching | 未碰 | 正交 |
| DEC-010 精简心智 | Step 5b 本身 ~30 行，与精简心智存在轻度张力（详见 §4 Warning W1）| 不违反但需持续关注 |
| DEC-011 DEC 顺序 | 未涉 DEC 新增 | 正交 |
| DEC-012 dispatch mode | 未碰 | 正交 |
| DEC-014 bugfix 分层 | bugfix.md ref 正确，F6 follow-up 未阻塞；post-fix 已显式标注「事件类 b 不适用 bugfix」| 正交 |
| DEC-015 auto_mode §Auto-pick | §Auto-pick 末尾追加事件类 e 转发规则；未改 4 触发点本体 | 正交 |

**silent collision 扫描**：无。特别确认：
- DEC-009 log batching 的 Step 8 flush 触发点（A 类 pause / C 类 verification-chain / Stage 9）与本扩展 b/d 转发触发点同构但不争用（flush 是 log.md 写，转发是 reply 调用）。
- DEC-015 §Auto-pick 的 `recommended: true` 预授权心智与本扩展事件类 e 转发未冲突（转发只记录事实，不替用户决策）。

## 4. tester post-fix 实质性与 follow-up 可接受性（维度 4）

### 4.1 post-fix 已修 findings 核对

| Finding | 严重度 | inline 修复点 | 实质解决？ |
|---------|--------|---------------|-----------|
| F13 Step 5b 末段「3 处 skill-emitted」措辞偏差 | Critical | workflow.md L224 改为「`commands/workflow.md` Step 5 text 分支 / `skills/architect/SKILL.md` text 段 / `skills/analyst/SKILL.md` text 段 共 3 处 prompt 本体」| **真解决** —— 精确列出 3 路径 |
| F1 事件类 a 与 d 在 Stage 1 重叠 | Warning | workflow.md L253（Step 6.1 C 类）增加「Stage 1 Context 已由事件类 a 覆盖，不再重发 d（避免与首次 🔄 重叠）」| **真解决** —— 指定 a 胜出 |
| F2 Ordering / 批次规则 | Warning | workflow.md L226-230 新增「Ordering / 批次规则」段（c 独立 / d+e 合并 / a+Step 1 合并 / b 独立）| **真解决** —— 4 条规则覆盖组合触发 |
| F3 ≤200 字计量与截断 | Warning | workflow.md L234 新增「字 = Unicode codepoint + 超长截断优先产出路径 + 再超长退化为单行 docs/... 引用」| **真解决** —— 三级降级明确 |
| F4 纯/混合边界 | Warning | workflow.md L232 新增「格式按事件类硬绑定」段（a=围栏 / b,c,d=markdownv2 / e=单事件 md 或批量围栏）；「纯/混合」仅为回退启发式 | **真解决** —— 临场判断替换为事件类查表 |
| F5/F10 Sticky 语义 | Warning | workflow.md L236 新增「Sticky 语义」段（tag 出现一次即永久 sticky / reply 调用史是 OR 另一路径 / 多 channel 各自独立广播）| **真解决** —— 3 路径覆盖 |

**结论**：7 项 post-fix 全部实质性解决，非贴补式。修复落点精准在 Step 5b 本体，未造成下游 ripple。

### 4.2 未修 follow-up（F8/F9/F12/F14）non-blocking 评估

| Finding | 为何可作为 non-blocking | Reviewer 同意？ |
|---------|------------------------|----------------|
| F8 字节等价 vs markdownv2 混合 parse_mode | `<decision-needed>` 原规则「纯文本即可」TG 客户端兼容 parse_mode 混合；审计/回放工具适配成本低；不阻塞首要 UX | **同意** —— 建议 follow-up 时采 F8 建议方向（`<decision-needed>` 用 ``` 围栏包裹与 memory `feedback_tg_decision_needed_codeblock` 对齐），但本轮不阻塞 |
| F9 markdownv2 反引号转义验证 | 实施细节；design-doc §2.3 已展示正确转义示范；implementer 参考即可 | **同意** |
| F12 DEC-010 影响范围 ≤10 行 post-fix 豁免问题 | 当前累积 2 次 post-fix 未爆风险；累积 3 次前做结构化决策（见上 §2）| **同意** —— 建议下一次 post-fix 前先走 DEC-010 脚注补齐 |
| F14 Step 0/1 合并语义表格体现 | 已在 workflow.md L229「a + Step 1 size 判定 合并为单次围栏转发；若中途用户 FAQ 插入则 Step 1 判定另发」落地 —— F14 实际**已事实上被 F2 修复覆盖** | **同意** —— F14 可关闭 |

## 5. Reviewer 新增 findings（Tester 未覆盖）

### W1 [Warning] Step 5b 本身膨胀与 DEC-010 精简心智张力（维度 6）

**定位**：`commands/workflow.md` L206-236，Step 5b 从 issue 原计划 ~18 行膨胀到 ~31 行（加 Ordering / 硬绑定 / 计量 / Sticky 4 段 post-fix）。

**分析**：post-fix 每段单看都有必要（F2/F3/F4/F5/F10 各解决真歧义），但累积让 Step 5b 体量达到 Step 5（Escalation）级。与 DEC-010 "per-workflow token ~30 行" 心智匹配但接近上限。

**非阻塞理由**：Step 5b 是 orchestrator 全局规则的 single source of truth，内容密度高（表格 + 4 规则段 + 边界声明），压缩空间有限；强行抽 helper 会违反 DEC-010 "helper 抽取反增教训"（issue #9 已有先例）。

**建议（Non-blocking）**：未来若 Step 5b 再扩（例如新增事件类 f），必须先走 helper 抽取 vs 继续 inline 的决策点（可能要新 DEC）。本轮合入不强求。

### R1 [Suggestion] design-doc §5 测试策略未覆盖 Ordering / 计量 / Sticky 3 post-fix 新场景

**定位**：`docs/design-docs/tg-forwarding-expansion.md` §5 表，测试场景 8 项对照 issue body 6+2 验收；post-fix 新引入的 Ordering 规则（F2）/ 200-codepoint 截断（F3）/ 多 channel 广播（F5）/ Sticky 永久化（F10）均无测试场景。

**影响**：未来 runtime 验证（DEC-013 决定 11 dogfood）会漏这 4 场景。

**建议**：合入后在 design-doc §5 追加：
- S9 C handoff + auto_mode=on → 验 d+e 合并为 1 条 markdownv2 reply（F2）
- S10 developer final report 含 800 字 → 验 digest ≤200 codepoint + 优先产出路径（F3）
- S11 多 channel inbound → 验各独立广播（F5）
- S12 session 中段 `<channel>` tag 消失后仍转发（F10）

非阻塞；可次轮补。

### R2 [Suggestion] DEC-010 脚注缺 post-fix 豁免显式声明

**定位**：`docs/decision-log.md` DEC-010 决定 10（影响范围 ≤10 行）。

**问题**：本轮 DEC-013 post-fix 2026-04-21 让影响范围段累积 ~30 行，已超 10 行限额。F12 已标。

**建议**：下次 post-fix DEC-010 时（或独立 micro-fix）补脚注「post-fix clarification 追加不计入 10 行限额；累积到 3 次同一 DEC 时必须结构化拆分（外链 design-doc）或新开 DEC」。本轮不强求，但**务必**在第 3 次 post-fix 前落实。

### R3 [Suggestion] bugfix.md ref 段 F6 修复的清晰度（维度 10）

**定位**：`commands/bugfix.md` L22。

**核对**：post-fix 已写「**事件类 b（A 类 producer-pause）不适用 bugfix**（bugfix 流程无 A 类 pause）」——明确、单行、粗体标注，读者一次读懂。

**结论**：F6 真解决。但读者若不点 `docs/design-docs/tg-forwarding-expansion.md` 链接难以知道「为何 bugfix 无 A 类」—— 这一前置知识由 DEC-006 / DEC-014 明示。非阻塞。

## 6. 用户 UX 反馈满足度（维度 7）

用户 TG message_id=428 反馈「这种文本 tg 阅读效果较差」—— 对应 markdownv2 结构化要求**真正落入 prompt 本体**：
- workflow.md L212-218 表格每行「格式」列明确格式（markdownv2 粗体/bullet/反引号 vs 代码围栏）
- workflow.md L232 F4 post-fix「格式按事件类硬绑定」段确保 orchestrator 实施时不临场判断
- memory `feedback_tg_reply_format` + `feedback_tg_decision_needed_codeblock` 已 ref

**可落地性判断**：orchestrator 未来按 Step 5b 表格实施，能产出正确 markdownv2 格式。唯一风险是 LLM implementer 实际调 reply 时对 reserved char 转义不到位 —— F9 Suggestion 已提示，但未成 prompt 硬规则。**不阻塞合入**，DEC-013 决定 11 dogfood 回跑时应实测验。

## 7. 验收 6+2 对照（issue #48 body；维度 8）

| 验收点 | 对照 prompt 落点 | 结论 |
|--------|-----------------|------|
| architect 完成 → producer-pause summary 转发 TG | Step 6.1 A 类末尾「按 Step 5b 事件类 b 转发」| ✓ |
| auto_mode 4 audit 转发 TG | §Auto-pick 末尾「表内 4 auto_mode 事件在 active channel 下必须按 Step 5b 事件类 e 转发」+ 表格 e 行 | ✓ |
| Role completion digest ≤200 字 | Step 5b 事件类 c + L234 Unicode codepoint 计量段 | ✓ |
| 纯终端 session 行为不变 | Step 5b 首段「纯终端 session 不触发，行为同现状」+ §3.1a 原条款 | ✓ |
| 普通对话 / FAQ 不转发 | Step 5b L220「不转发：普通对话 / FAQ / 调试输出 / subagent 工具调用 echo」| ✓ |
| 4 agent prompt 不改 | design-doc §3.2 显式列出「不改 skills/ * 、agents/ *」；落点清单限 2 orchestrator 文件 | ✓ |
| §3.1a `<decision-needed>` 转发行为不变 | Step 5b「与 §3.1a 并存不冲突」+ workflow.md Step 5 原 §3.1a 段未改 | ✓ |
| C handoff 🔄 转发 | Step 6.1 C 类末尾「按事件类 c 独立 reply 转发 role completion digest，再按事件类 d（与同 tick 触发的 e 合并）转发」| ✓ |

**8/8 验收通过**。

## 8. 终审判定

**Verdict：Approve-with-caveats**

- **Approve 理由**：
  1. DEC-013 Accepted 决定零违反，决定 8 边界守住。
  2. tester 14 项对抗审查 7 项已 inline 真修复（非贴补），4 项 follow-up 经 reviewer 复核确 non-blocking。
  3. 落点面精准（2 orchestrator 文件 + 3 文档），skill/agent prompt 零改动，与 #38 同路径先例一致。
  4. 用户 UX 反馈 message_id=428 对应的 markdownv2 结构化要求真落入 prompt 本体，可实施。
  5. lint 0 命中；critical_modules 3/3 命中已按 DEC-014 落盘（本文件）。
  6. 8/8 验收对照通过。

- **Caveats（合入后必须跟进）**：
  1. **R1 测试场景补齐（Suggestion）**：design-doc §5 追加 4 新场景（Ordering / codepoint 截断 / 多 channel / Sticky 永久化）—— 下次派发 architect 时 inline 补。
  2. **R2 DEC-010 post-fix 豁免脚注**：第 3 次 post-fix 前必须结构化（否则 DEC-010 决定 10 字面违反）。当前 2 次属临界。
  3. **W1 Step 5b 膨胀监控**：未来若加事件类 f，先走 helper 抽取 vs inline 决策点（可能需 DEC）。
  4. **F8/F9 dogfood 实测**：DEC-013 决定 11 dogfood 回跑时实测 markdownv2 reserved char 转义 + `<decision-needed>` 混合 parse_mode 行为。

- **Reject 条件**：无触发。

## 9. Critical / Warning / Suggestion 汇总

| 严重度 | 数量 | 编号 | 阻塞？ |
|--------|------|------|--------|
| Critical | 0 | —— | —— |
| Warning（reviewer 新增）| 1 | W1（Step 5b 膨胀监控）| 不阻塞 |
| Suggestion（reviewer 新增）| 3 | R1 / R2 / R3 | 不阻塞 |
| Tester post-fix 已解决 | 7 | F13 + F1/F2/F3/F4/F5/F10 | 已修 |
| Tester follow-up | 4 | F8 / F9 / F12 / F14 | 不阻塞（F14 事实上已被 F2 覆盖）|

## 10. Escalation

无 —— 无需用户/architect 方向分叉，合入直接 closeout。

## 11. 变更记录

- 2026-04-21 初版（reviewer 终审，dispatch reviewer-#48-001，模型 opus-4-7）
