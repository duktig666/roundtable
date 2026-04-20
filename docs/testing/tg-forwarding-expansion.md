---
slug: tg-forwarding-expansion
source: design-docs/tg-forwarding-expansion.md
created: 2026-04-21
status: Adversarial Review
tester: opus-4-7 (dispatch tester-#48-001)
scope: prompt-only review (static markdown, no runtime)
---

# DEC-013 §3.1a Active Channel Forwarding 扩展 对抗性 Prompt 审查

## 0. 审查范围与方法

- **审查对象**：`commands/workflow.md`（新增 Step 5b + Step 0/1/6.1/§Auto-pick 4 处钩子）、`commands/bugfix.md`（+2 行 ref）、`docs/design-docs/tg-forwarding-expansion.md`、`docs/decision-log.md` DEC-013 post-fix 2026-04-21。
- **方法**：静态语义一致性检查 / 规则冲突推演 / 回归面扫描 / TG markdownv2 格式可解析性推演。无运行时。
- **critical_modules 命中**：workflow Phase Matrix + Escalation Protocol（§3.1a 文本结构）+ skill/agent/command prompt 本体 —— 三处全中。按 DEC-014 critical_modules 1/N 即落盘要求，产出本报告。
- **lint 验证**：`grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/"` 0 命中 ✅ PASS。

## 1. 严重程度分级

- **Critical**：规则冲突 / 回归破坏 / 阻塞解析
- **Warning**：语义歧义 / 边界用例未界定 / 增加误用风险
- **Suggestion**：可读性 / 文档改进
- **Positive**：该轮修改中做得好的点

---

## 2. Findings

### F1 [Warning] 事件类 a 与 C 类 handoff（事件类 d）在 Stage 1 Context 重叠

**推断路径**：`commands/workflow.md` Step 6.1 §"Phase Matrix → category 映射"声明 `1 Context = C`。Step 5b 事件类 a 覆盖「Step 0 context detection 结果 + Step 1 size/pipeline 判定」；事件类 d 覆盖 C 类 verification-chain 🔄 handoff。Stage 1 既是 C 类 verification-chain 又会触发事件类 a 的转发 —— Step 0 完成后是否也要 emit 一行 `🔄 Stage 1 完成 → dispatching analyst/architect (critical_modules hit: ...)` 再事件类 d 转发？还是 Step 0 的 context 块本身已替代 C 类 handoff 行？

**复现推演**：TG-driven session `/roundtable:workflow <desc>`：
1. Step 0 执行 → 事件类 a 转发 context 块（围栏）
2. Step 1 size 判定 → 按文档「随 Step 0 context 同块转发」合并为 1 次 a 类
3. 但 Stage 1 是 C 类，接下来派 analyst / architect 前**应不应当**也发 `🔄 Stage 1 完成 → dispatching <next>`（事件类 d）？

现有 prompt 未显式处理首次 context → 第一个 analyst/architect 派发这一 transition 是否复用事件类 d 格式。读者可能 (A) 跳过 d（因 a 已涵盖），(B) 额外发 d（重复），(C) 把 a 与 d 合并（破坏 a 的 YAML 围栏纯度）。3 种行为都有文档依据。

**建议修复**：在 Step 5b 表格的事件类 a 尾注一行「Step 0/1 合并转发已作为首次 C→C transition 的等价事件，事件类 d **不再**追发」；或反之显式说「d 事件也包含 Stage 1→2 边界，a 仅限 detection 结果」。二选一写明。

---

### F2 [Warning] auto_mode audit ordering 与 C handoff 的批量语义未定

**推断路径**：Step 6.1 C 类末尾「同时 Step 5b 事件类 c（role completion digest ≤200 字）」——即 C transition 时要**连发**事件类 c + d 两条。若本次 C handoff 又是 `auto_mode=true` 触发 auto-go（事件类 e），文档声称「单事件 `markdownv2` 粗体 emoji，多事件批量 ``` 围栏」但未规定**组装顺序** / **是否同一 reply 调用** / **事件类 c 的 markdownv2 结构与事件类 e 的批量围栏如何共存**。

**复现推演**：architect ✅ + auto_mode=on → 按 §Auto-pick A 类发 `🟢 auto-go architect ✅`（事件类 e），同时 C 类 transition 发 digest（c）+ `🔄 handoff`（d）。3 条事件如何落到 TG？
- **方案 X**：3 条独立 reply（TG 刷屏 3 条）
- **方案 Y**：c 单独 markdownv2，d+e 合并围栏
- **方案 Z**：c+d+e 一条围栏（破坏 markdownv2 结构化收益，又违背 "纯 YAML → 围栏" 原则，因 c 含 prose）

**建议修复**：Step 5b 增补「**组合触发时的顺序与批次**」子段：(1) c 独立 reply（digest 信息密度高，粗体标题不能丢）；(2) d + e 若同 tick 触发，合并为一条 `markdownv2`（首行 `🟢 auto-go`，第二行 `🔄 handoff`）；(3) 拆分的目的是避免单条 reply 兼含 prose + 结构化 + 围栏三种混合。

---

### F3 [Warning] Role completion digest ≤200 字的计量单位与截断策略未定

**推断路径**：design-doc §2.3 与 workflow.md Step 5b 事件类 c 均写「≤200 字」，未指明：
- **字 = 中文汉字？UTF-8 codepoint？字节？** 中英混合如 "developer 完成 API schema 扩展" 在三种计量下差别显著
- **超长截断策略**：文档只说「超长引 docs/... 路径，全文不转发」—— orchestrator 如何判定「超长」？先构造全文 digest 再 `len(...) > 200` 时替换为路径？还是从一开始就只发路径？
- **digest 生成算法无规范**：agent final report → orchestrator 摘要。orchestrator 作为 LLM 摘要具非确定性；跨 session 同一输入可能得到不同 digest

**复现推演**：developer final report 含 5 个新文件 + 3 条 findings + 回归测试清单，总计 ~800 字。orchestrator 可能生成 (A) 产出 3 行 + findings 省略；(B) 产出 5 行省略 findings；(C) 只发路径列表一行。3 种结果信息差异大。

**建议修复**：Step 5b 事件类 c 补一行规范「字 = Unicode codepoint（len(s)）；超长优先保留 **产出路径清单**（每路径反引号 + 1 句描述），其次 findings；裁剪后仍 >200 则仅转发 `see <docs_root>/...`」。或挂 TODO 到 `待确认项`。

---

### F4 [Warning] "混合 prose + 字段" 与 "纯 YAML" 的边界不清

**推断路径**：Step 5b 格式原则「纯 YAML / 纯键值批量 → ``` 代码围栏；混合 prose + 字段 → markdownv2」。但中间态：
- Step 0 context 块（事件类 a）含 `target_project: X` 键值对 + "已检测到 critical_modules hit" 一行 prose —— 纯键值还是混合？
- A 类 producer-pause 3 行模板含 "✅ architect 完成" prose + `- <path>` bullet + "请阅读后告诉我: `go`" prose —— 归混合 markdownv2（文档已明确）但与 context 块风格不统一

**复现推演**：两 orchestrator 实例读同一 prompt，对同一事件可能选不同格式 → TG 渲染风格漂移，用户"阅读效果差"反馈可能再现（message_id=428 初衷即为解决此）。

**建议修复**：Step 5b 格式原则段改为**按事件类硬绑定**格式（a=围栏 / b=markdownv2 / c=markdownv2 / d=markdownv2 / e=单事件 markdownv2 或多事件围栏），不再用"纯/混合"二分让 orchestrator 临场判断。表格里已列格式列，把格式原则段删除或改为「以表格格式列为准；以下两类原则为回退判据...」。

---

### F5 [Warning] Sticky channel 语义「reply 工具在本 session 内曾调用过」跨工具与跨路径未界定

**推断路径**：Step 5b 首段复用 §3.1a sticky 语义：「session inbound prompt 含 `<channel source=...>` OR 该 channel reply 工具在本 session 内曾调用过」。边界问题：
- orchestrator 内部工具调用 `react` / `edit_message` 算"reply 工具调用"吗？TG MCP 工具集含 `reply` / `react` / `edit_message` / `download_attachment` —— 字面只 `reply` 激活 sticky？
- 用户 TG 仅 `👀 react`（未 `reply`）inbound 不带 `<channel>` tag 吗？实测需确认；若此时 orchestrator 尚未调 reply → sticky 未激活 → 事件类 a 不转发 → 用户无感知（回归 issue #48 痛点）
- 多 channel 同时 inbound（TG + CI pipe + terminal）如何处理？§3.1a 未规定；Step 5b 同样缄默

**复现推演**：TG 用户只 react 不 reply → orchestrator 读到 `<channel>` tag 则 sticky 成立（按 OR 首支）；但若 orchestrator 把 inbound 视为 "带 tag 但工具未调过" —— sticky 仍应成立，文档写的是 OR 不是 AND，**但**再次 inbound 时（同一 user 后续 react），若 session 记忆中该轮次已衰减或 tag 只在首轮存在，判据就回到「reply 工具曾调用」这支，若此时 orchestrator 从未主动 reply → 破窗。

**建议修复**：Step 5b 或 design-doc §3.3 补一行「一旦 `<channel>` tag 出现一次即永久 sticky，无视后续 inbound 是否携带 tag；reply 工具调用史是 OR 的另一路径并非唯一路径」。另加「多 channel 并存：各自独立 sticky，事件广播到所有已 sticky 的 channel」。

---

### F6 [Suggestion] bugfix.md 仅 2 行 ref 是否触达所有事件类

**推断路径**：`commands/bugfix.md` Step -1 末尾新增 1 段指向 workflow.md Step 5b。bugfix 流程实际触达的事件类：
- 事件类 a（context detection）✅ Step 0 通用
- 事件类 b（A 类 producer-pause）❌ bugfix **无 A 类 pause**（design-doc §2.3 明确 `bugfix 无 A 类 producer-pause`，log flush 退化声明）
- 事件类 c（role completion digest）✅ developer / reviewer / dba / tester 完成
- 事件类 d（C handoff 🔄）✅ 步骤 3 → 步骤 5 C 类
- 事件类 e（auto_mode audit）✅ 同 workflow

bugfix ref 一句覆盖 5 类其中 4 类可触达 —— 充分。但读者可能误认 b 也适用从而期待 bugfix 尾段发 producer-pause，UX 偏差。

**建议修复**：bugfix.md ref 段追加半行「（事件类 b A 类 producer-pause 不适用于 bugfix —— bugfix 无 A 类；其余 4 类按各自触发点适用）」消除歧义。

---

### F7 [Positive] `<decision-needed>` 与 Step 5b 并存不冲突 —— 已明示

**推断路径**：Step 5b 开篇 `**转发事件类**（与 §3.1a <decision-needed> 转发规则**并存不冲突**）` + 末段 `§3.1a 原有 3 处 skill-emitted <decision-needed> forwarding 规则继续生效` + design-doc §3.4 两规则矩阵 —— 三处明示无冲突。字节等价（§3.1a）vs markdownv2 结构化（本扩展）语义区分清楚：前者是 `<decision-needed>` 块本体不变（纯文本即可），后者是新 5 类事件走结构化，两条规则作用于不同事件载荷。

**无需修改**。但见 F8。

---

### F8 [Warning] 字节等价（§3.1a）vs markdownv2 增强（Step 5b）在边界用例可能冲突

**推断路径**：§3.1a 原文「纯文本即可，不重排、不重生成 `id`、不缩略」= 字节等价转发。若 `<decision-needed>` 块内 `options` 含反引号 / 下划线（如 `label: fix-rootcause`）—— 在 TG markdownv2 下原样 reply 会触发转义错误。§3.1a 的「纯文本即可」可解读为 TG Bot API `parse_mode=None`（无转义），但本次 Step 5b 强推 `markdownv2` 风格 —— 同一 session 中一条 reply 用 None 一条用 MarkdownV2，客户端兼容但审计日志 / 回放工具可能要 per-message 检测 parse_mode。

**复现推演**：auto_mode=on TG session emit 一次 `<decision-needed>` → §3.1a 规定纯文本字节等价（假设以 `parse_mode=None` 发）；紧接着 auto-halt → 事件类 e 要求 markdownv2 —— 2 条 reply 混合 parse_mode。

**建议修复**：Step 5b 或 design-doc 增一行「TG `<decision-needed>` 转发建议用 ``` 代码围栏整体包裹（markdownv2 下围栏内零转义，字节等价仍成立） —— 两规则在 markdownv2 parse_mode 下统一」。实质是把 §3.1a 的"纯文本即可"升级为"围栏包裹的字节等价"，与 memory `feedback_tg_decision_needed_codeblock` 对齐。

---

### F9 [Suggestion] 反引号包裹路径的 markdownv2 转义验证

**推断路径**：memory `feedback_tg_reply_format` 指出 markdownv2 反引号代码块零转义。路径含 `.` / `_` / `/`：
- `docs/design-docs/tg-forwarding-expansion.md` —— 反引号内零转义成立 ✅（Bot API 规范：`code` entity inside text，不再二次解析）
- 但**普通行内 `backtick` 与反斜杠转义** 的 MarkdownV2 规则：行内 code 的 **开闭 backtick 本身** 若出现在 prose 中需 `\`` 转义

Step 5b 事件类 d 示例 `🔄 *architect* 完成 → 派发 *developer* \(critical\_modules hit: \`workflow Phase Matrix\`\)` —— design-doc §2.3 已正确转义括号 `\(...\)` 与下划线 `critical\_modules` 并显式 `\`` 包裹 inner code。文档作者已注意，但 orchestrator LLM 实施时是否忠实复现仍是实测项。

**建议**：Step 5b 增 1 行「TG markdownv2 转义守则：prose 正文 reserved char（`_*[]()~>#+-=|{}.!`）需 `\` 前缀；反引号内零转义；详见 memory `feedback_tg_reply_format`」。不改实质行为，防 implementer 踩坑。

---

### F10 [Warning] "session 内曾调用过"与 orchestrator 子任务/multi-turn session 定义

**推断路径**：`/roundtable:workflow` 可能跨多轮（用户 `go` / `调: ...` 继续），每轮 orchestrator LLM 是同一 session 还是新启动？Claude Code plugin 内 `commands/*.md` 每次调用是否清零 session 记忆？若每轮新 session → 首轮后 sticky 失效 → 除非每轮 inbound 都带 `<channel>` tag（TG plugin 实现细节，本 plugin 无法保证）否则 §3.1a / Step 5b 失效。

**复现推演**：TG user: `/roundtable:workflow X` → session A，事件类 a 转发；orchestrator 给 architect producer-pause 并 pause 等 `go`。TG user: `go` → 新 message 到 Claude Code → 若 Claude Code 把 prompt 注入同一 orchestrator LLM session 则 sticky 继续；若新 invocation（slash command 重新解析）则 sticky 断裂。

**建议修复**：design-doc §3.3 补一句「本 plugin 假设 `/roundtable:workflow` 全生命周期为同一 orchestrator LLM session —— Claude Code plugin slash command 默认行为符合此假设（单 invocation 跨多轮用户消息保持 session state）。若 target 环境非此假设需用户每轮确保 `<channel>` tag inbound」。或显式列为**非目标**。

---

### F11 [Positive] 落点面收敛、DEC 不新开、skill prompt 零改动

**推断路径**：design-doc §3.2 落点清单明确仅 2 orchestrator 文件；§2.2 append-only clarification 不新开 DEC；5 事件类全部 orchestrator-emitted 的归因正确（已核对 Step 0 inline / Step 6.1 A/C 类 summary 模板 / §Auto-pick 表 / verification-chain 🔄 行模板位置）。合乎 DEC-010 精简 / DEC-013 决定 8 边界 / DEC-009 最小改动面心智。

**无需修改**。

---

### F12 [Suggestion] decision-log post-fix 段长度与 DEC-010 影响范围≤10 行原则

**推断路径**：DEC-013 影响范围段已承载 post-fix 2026-04-20（issue #38）+ 本次 post-fix 2026-04-21（issue #48），单段现 ~30+ 行混合初始影响 + 2 次 post-fix。DEC-010 约束「影响范围 ≤10 行」—— 字面看现况已溢出。但 post-fix 追加 clarification 是否计入 10 行限额本就存在争议（既为 post-fix 就 by-design 追加）。

**复现推演**：未来若再 1 次 post-fix（例如 §3.1b），段长还会膨胀 → DEC 可读性下降。

**建议修复**：两选项 —— (A) 维持现状（DEC-010 10 行原则 apply 到初始条目，post-fix 豁免），并在 DEC-010 脚注明文此豁免；(B) 把 2 次 post-fix 独立成 DEC-013a / DEC-013b 子条目。当前改动不强求，但累积到 3 次前应决策。

---

### F13 [Critical] Step 5b 末尾引用 §3.1a "原有 3 处 skill-emitted `<decision-needed>` forwarding 规则" —— 数量核对

**推断路径**：Step 5b 末段写「§3.1a 原有 **3 处** skill-emitted `<decision-needed>` forwarding 规则继续生效」。实际核对：
- `skills/architect/SKILL.md:79` ✅ 1 处
- `skills/analyst/SKILL.md:41` ✅ 1 处
- `commands/workflow.md` Step 5 text 分支 —— 属 **orchestrator**-emitted，非 skill-emitted

严格说 skill-emitted forwarding 规则只 **2 处**（2 个 skill 文件），第 3 处是 orchestrator 分支下的 forwarding。措辞 "3 处 skill-emitted" 偏差；DEC-013 影响范围段 2026-04-20 原文说「3 处 prompt 本体 inline 加 ~3 行（workflow Step 5 text 分支 / architect text 段 / analyst text 段）」—— 此处是 3 处 prompt 本体，而非 3 处 skill-emitted。Step 5b 误把 "3 处 prompt 本体" 转述为 "3 处 skill-emitted"。

**影响**：读者（包括 future LLM 实施者）若按 "3 处 skill-emitted" 去找第三处 skill 规则会找不到，导致误增 / 误删规则。

**建议修复**：Step 5b 末段改为「§3.1a 原有 skill + orchestrator **共 3 处** prompt 本体 forwarding 规则继续生效」或更精确「§3.1a 原有 forwarding 规则（`skills/architect/SKILL.md` + `skills/analyst/SKILL.md` + `commands/workflow.md` Step 5 text 分支）继续生效」。

---

### F14 [Suggestion] Step 5b 表格"事件类 a"合并语义未在表格中体现

**推断路径**：表格 a 行描述 "Step 0 context detection 结果 + Step 1 size/pipeline 判定"。但 workflow.md Step 0 尾 / Step 1 尾两段都分别写了"转发"提示，Step 1 尾写「判定结果随 Step 0 context 同块转发」—— 合并语义。若未来 Step 0 与 Step 1 因需要解耦（例如 context detection 结果 emit 后用户 ask FAQ 插队），合并假设破坏。

**建议修复**：Step 5b 表格 a 行格式列追加「（Step 0+1 合并为单次转发；若中途用户 FAQ 插入则 Step 1 判定单独重发）」。或列为非目标。

---

## 3. critical_modules 命中汇总（DEC-014 落盘触发）

| module | 命中点 |
|--------|-------|
| workflow Phase Matrix | Step 6.1 C 类末尾新增 c+d 转发；Phase Matrix → category 映射段不变但被 F1 指出的语义重叠 |
| Escalation Protocol JSON schema | Step 5 §3.1a 与新 Step 5b 并存 → F8 / F13 影响格式 / 数量陈述 |
| skill/agent/command prompt 本体 | `commands/workflow.md` + `commands/bugfix.md` 修改；skill 未改（符合 design §3.2） |

3/3 全中 → 本测试报告必须落盘（已落盘于本文件）。

## 4. 汇总与 go/halt 建议

| 严重度 | 数量 | finding |
|--------|------|---------|
| Critical | 1 | F13 |
| Warning | 7 | F1 / F2 / F3 / F4 / F5 / F8 / F10 |
| Suggestion | 4 | F6 / F9 / F12 / F14 |
| Positive | 2 | F7 / F11 |

- **lint**：PASS（0 命中）
- **回归面**：§3.1a `<decision-needed>` 转发与新 5 类并存无实质冲突（F7/F8），但 F13 措辞错误需修正
- **建议**：合入前修 F13（Critical，1 处措辞），同时建议合入前 batch 修 F1/F2/F3/F4（4 个 Warning 均涉语义歧义，未修会下游 orchestrator 实施漂移）。F5/F8/F10/F6/F9/F12/F14 可后续 follow-up。

## 5. Escalation

无业务代码可 escalate（本轮纯 prompt markdown）。F13 Critical 为措辞精度问题，由 architect / developer 后续 inline 修正即可，不阻塞合入的硬 block。若用户认为 Warning 组亦阻塞，可指派 architect 补丁。

## 6. 变更记录

- 2026-04-21 初版（tester 对抗性审查，dispatch tester-#48-001，模型 opus-4-7）
- 2026-04-21 post-fix（orchestrator inline，auto_mode=on）：F13 Critical + F1/F2/F3/F4/F5/F10 Warning 全修。`commands/workflow.md` Step 5b 末段改为精确列出 3 处 prompt 本体（workflow Step 5 text 分支 + architect + analyst），不再用「skill-emitted」措辞（F13）；新增「Ordering / 批次规则」子段（F2 c 独立 / d+e 合并 / a+Step 1 合并 / b 独立）、「格式按事件类硬绑定」段（F4）、「字 = Unicode codepoint + 超长截断策略」段（F3）、「Sticky 语义扩展」段（F5/F10 覆盖 tag 永久 sticky + 多 channel 广播）。Step 6.1 C 类末尾加 Stage 1 不重发 d 条款（F1）。`commands/bugfix.md` ref 段显式标注事件类 b 不适用 bugfix（F6）。F8/F9/F12/F14 为非阻塞 follow-up。
