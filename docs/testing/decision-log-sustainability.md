---
slug: decision-log-sustainability
source: tester (orchestrator relay)
created: 2026-04-22
tester: tester subagent
---

# decision-log-sustainability 对抗性测试报告（DEC-025 + DEC-026）

## Scope

三类改动面对抗审计：

1. **P0 critical_modules**：`skills/architect/SKILL.md` Stage 2 三处改动
   - 新 step 8 `开立前自问（DEC-025）`（L59-L59 区块，~1 行自问句）
   - 修订 step 9 `状态默认 Provisional` 子句（L60）
   - 原 step 9/10 顺延为 step 10/11（L61-L62）
2. **P1 co-dependent**：`docs/decision-log.md` 元规则区扩容（`## 状态说明` +Provisional / `## 铁律` 4-7 / `## 开立门槛`）、`commands/lint.md` §6 L6.1-L6.5 + 统计段、`docs/INDEX.md` §决策索引 (23 DEC)
3. **Out of scope**（审计不测）：reviewer.md:L91 全读（DEC-026 决定 5 "不改"）、其他 agent prompt 本体、`commands/workflow.md` 本体（铁律 6）

总 18 cases（对抗性 13 + E2E 回归 5）。

---

## 1 对抗性 cases 覆盖清单

### A 组：architect SKILL step 8-11 措辞精度（critical_modules 直击）

| case | 目标 | 触发方式 | 预期行为 | 实测 |
|---|---|---|---|---|
| A-01 | step 8 "5 类必开 且 不踩 Red Flags" 的 AND 语义 | LLM 新决策同时命中"推翻 Accepted DEC 决定条款"（5-必开 #4）与"tester/reviewer findings 说要开"（Red Flag #6）| 设计意图：#4 允许开 + #6 stop。措辞 `且 不踩 Red Flags` 字面执行 → Red Flag #6 veto `#4` → 不开 DEC → 无法走 Refined/Supersede → 死锁 | 🔴 **C-01** Critical |
| A-02 | step 8 → step 9 短路缺失 | step 8 判 "不开 DEC" 后，step 9 仍写 "新决策 → 追加 decision-log.md" | 应有显式 short-circuit："若 step 8 判不开，跳 step 10" | 🟡 **W-01** Warning |
| A-03 | step 9 Provisional 默认强制度 | architect 新开 DEC 状态行漏写 "Provisional" | "默认 Provisional" 措辞 → LLM 在 prompt 压缩下可能降级为可选；无 lint 即时兜底（L6.3 仅管字面值白名单，不强制 Provisional 首值） | 🟡 **W-02** Warning |
| A-04 | step 11 renumber 对 Stage 3 菜单衔接 | Stage 3 `go-with-plan` / `go-without-plan` 菜单紧接 step 11（原 step 10）| SKILL L64 "阶段 3" 标题与 L71 "用户选 go-with-plan → 11. 写 exec-plan" 引用 —— L71 的 "11" 与新 step 11 "停下来请用户审阅 design-docs" 数字冲突 | 🔴 **C-02** Critical（文本矛盾） |
| A-05 | step 8 Red Flag #6 与 5-必开 #4 优先级未定义 | 同 A-01 | 设计文档 §4.0 未声明优先级表 | 见 C-01 合并 |
| A-06 | Provisional Day-0 dogfood 转正悖论 | DEC-025 自己就是 first dogfood；tester（本报告）迫出 post-fix → dogfood "失败" or "通过"？ | §4.4 状态说明写 "≥7 日 OR 首次 dogfood run 通过"；tester Critical finding 算作失败信号但 Provisional 期允许直接修订正文非 Supersede —— 定义循环 | 🟡 **W-03** Warning |

### B 组：decision-log.md §开立门槛 + 铁律

| case | 目标 | 触发方式 | 预期行为 | 实测 |
|---|---|---|---|---|
| B-01 | Red Flag "影响了 3 个文件" 与 5-必开 #3 "引入新依赖" 冲突 | 多依赖改动自然 touch 多文件 | Red Flag 表示 touch file 数不是门槛；5-必开 #3 引入依赖是门槛。二者不冲突但 LLM 需推理"本改动命中 #3 所以不是 '影响 3 文件所以开'" —— 表达层歧义 | 🔵 **S-01** Suggestion |
| B-02 | 铁律 4 "clarification 不开新 DEC" 边界模糊 | tester W-level finding 要求措辞修订 vs 真的识别出架构新 tradeoff | §4.1 写 "仅当引入新 tradeoff / 新备选评估 / 跨 DEC 语义重构时才开新 DEC" —— 但"tradeoff"由谁判定？architect 自己判、reviewer 判、or tester 反馈？门槛判定缺流程归属 | 🟡 **W-04** Warning |
| B-03 | "post-fix clarification" 定义边界 | `## 开立门槛` 路由表把 clarification → 铁律 4；铁律 4 限制 "tester/reviewer findings"；tester 本次发现 A-04 文本矛盾（renumber side-effect）—— 走 clarification 还是 Supersede？| 无明确判例；易走滑坡 | 并入 W-04 |
| B-04 | Provisional 冷却窗 OR 逻辑极端路径 | Day 0 dogfood 通过 → 立即 Accepted；Day 8 发现需修订 → 按 post-fix 走铁律 4 inline append | 表面合法，但 Day 0 → Day 8 时间跨度相对初版仅 8 天内出现修订 —— "冷却"并未发生 | 🔵 **S-02** Suggestion（冷却期语义弱化） |
| B-05 | 铁律 7 "本轮立规不执行"的触发窗 | L6.1 "Superseded ≥ 90 天" 告警触发但无归档执行机制 | lint 只出告警，不自动归档；人工季度审查未定归属（orchestrator? architect?） | 🔵 **S-03** Suggestion |

### C 组：lint L6.1-L6.5（机械判定执行层）

| case | 目标 | 触发方式 | 预期行为 | 实测 |
|---|---|---|---|---|
| C-01 | **L6.3 不回溯 clause 缺失** | 扫 DEC-002/004/009 现有状态行 | DEC-002 状态 153 chars / DEC-004 96 chars / DEC-009 144 chars。首次 lint 运行必报 3 条 Critical-level 字符数告警。L6.2 有 "不回溯 DEC-013~020" skip，L6.3 无对应 clause | 🔴 **C-03** Critical |
| C-02 | **L6.3 字面值白名单 DEC-009 "部分 Superseded"** | DEC-009 状态行实际起首为 `部分 Superseded by DEC-010` | L6.3 白名单明确 `Superseded by DEC-xxx`；`部分 Superseded` 不是枚举字面值。即使 prefix-match 也不通过（起首非 "Superseded"）| 🔴 **C-04** Critical（并入 C-03，双重违规） |
| C-03 | **L6.3 prefix vs full-match 措辞** | DEC-020 状态行 `Accepted（Refines DEC-016 §3.3，非 Supersede）` | L6.3 措辞 "必须以 6 种字面值之一**起首**"——prefix-match 语义；但"≤60 字符"又是 full 长度；双 semantics 混合 → DEC-020（42 chars）OK，DEC-017-Amend（40 chars）OK。但措辞歧义未测试场景：L6.3 检查器应明确 prefix 判定终止在哪个字符（括号前 or 整行）| 🟡 **W-05** Warning |
| C-04 | **L6.5 自扫描 format 模板行 L10** | L8 开始 ` ```markdown ` 围栏；L10 内容 `### DEC-[编号] [标题]` | 若 lint 实施用原始行 regex `^### DEC-` 扫描且无 code-fence 感知，L10 误判为 DEC 条目 → 6 字段全缺 → 每轮 lint 1 条误报 | 🔴 **C-05** Critical |
| C-05 | L6.4 `Superseded by DEC-xxx` 占位 | 占位符 `DEC-xxx` 是文本变量而非真实编号 | 状态说明表 L28 / 铁律表 L51 的 `xxx` 均在代码示例/表格上下文；若 regex `Refined by DEC-\d{3}` 则不误报；若 regex `Refined by DEC-\w+` 则 `DEC-xxx` / `DEC-MMM` 误报 | 🟡 **W-06** Warning（实施决定项） |
| C-06 | L6.5 DEC-017 Amendment 字段完整度 | DEC-017 Amendment 实际字段：日期 / 状态 / 上下文 / 决定 / 影响范围 | 少 `**相关文档**` —— L6.5 告警命中 | 🟡 **W-07** Warning（实证违规）|
| C-07 | L6.2 "按字面换行符" 行数统计方法 | DEC-025 影响范围段：一行长句 `A；B；C；D；E`（分号分隔 5 项）| 字面换行符=1 → L6.2 通过。但设计意图是"影响项数 > 10"而非"字面行数"—— 语义错位 | 🔵 **S-04** Suggestion（语义精度） |

### D 组：INDEX.md §决策索引

| case | 目标 | 触发方式 | 预期行为 | 实测 |
|---|---|---|---|---|
| D-01 | 维护责任声明一致性 | DEC-026 决定 3 + INDEX.md L74 "orchestrator 维护；architect/reviewer 不直接编辑"；但本 workflow 中 DEC-025/022 条目此刻已存在于 INDEX.md（L50-L51）| architect 在 design-doc §2.3 中**给出了索引样例**（含 DEC-025/022 row），但实际应由 orchestrator 在 Step 7 flush。审计：INDEX.md L50-L51 是 architect 预写还是 orchestrator relay？无法从静态状态区分；如为 architect 直写则违反 DEC-026 决定 3 | 🟡 **W-08** Warning（审计开放） |
| D-02 | 23 行表与 decision-log.md 正文状态一致 | 抽样：DEC-009 INDEX L64 = "部分 Superseded by DEC-010（决定 1）"；decision-log.md L364 = "部分 Superseded by DEC-010（决定 1 "..."—长篇说明）" | INDEX 压缩正确但 decision-log 本文 144 chars 踩 L6.3 上限（见 C-03）| 关联 C-01 |
| D-03 | INDEX 与 decision-log.md DEC 数量对齐 | `grep -c "^### DEC-" decision-log.md` = 24（含 L10 template）；`grep -c "^\| DEC-" INDEX.md` = 23 | 23 vs 23（扣除 L10 template）对齐。但 lint 若扫 L10 → 报 24 vs 23 不一致（关联 C-05）| 依 C-05 |

### E 组：Stage 2→Stage 3 回归 / 跨 DEC 漂移

| case | 目标 | 触发方式 | 预期行为 | 实测 |
|---|---|---|---|---|
| E-01 | DEC-011 决定 1 的锚点漂移 | DEC-011 L434 字面引用 `L19 Resource Access / L59 §阶段 2 第 8 步 / L165 §完成后`；DEC-025 改动后 L59 区块变为 step 10，原 step 8 移到 step 8（自问句）| DEC-011 Accepted 文本 "第 8 步" 现指向 DEC-025 新插入的自问句而非"新决策 → 追加 decision-log.md"。语义漂移不回溯（铁律 6 保 DEC-001~020），但 git 引用链在追溯设计意图时指向错行 | 🟡 **W-09** Warning |
| E-02 | design-doc §7 待确认项未落盘 | design-doc §7 列 4 条 `[ ]` 未决项（包括"自问句插入位置"）| 当前 L59 实施选了"step 8 前插入"—— 是 §7.1 两候选之一。但 §7.3 "Provisional lint 阈值 30 天"已在 lint.md L73 写死，§7 未勾选 | 🔵 **S-05** Suggestion |
| E-03 | 铁律 6 "默认不改清单" 与 DEC-025 本体自矛盾 | 铁律 6 列 "2 skill prompt 本体（architect / analyst）"；DEC-025 决定 8 改 architect SKILL Stage 2（critical_modules 命中）| 铁律 6 允许 "仅在破例时显式声明"；DEC-025 影响范围段 L150 含 `skills/architect/SKILL.md Stage 2（+1 行自问句，**critical_modules 命中**）` —— 显式声明到位 | ✅ 通过 |
| E-04 | Provisional 状态 lint 告警与首轮 lint 冲击 | 首次 lint 运行扫 DEC-025/022（Provisional）→ 不告警（< 30 天）；扫 C-01/C-03/C-04/C-05 所列 4 类 → 4+ 条 critical-level | 系统设计意图是"机械告警非阻塞"；但首次 lint 输出 4 条 Critical（按 lint.md L122 分级）可能触发 "lint 0 命中合并" 条件失败（CLAUDE.md "跑 lint_cmd，0 命中才合并"；注：lint_cmd 定义为 grep 外部硬编码，不是 lint.md，所以此约束不直接触发，但观感冲击在）| 🔵 **S-06** Suggestion |
| E-05 | Stage 2 step 11 "停下来请用户审阅" 与 Stage 3 menu emit 时序 | 新 step 11（原 10）"停下来请用户审阅 design-docs"；Stage 3 L66 "阶段 2 结束时菜单必须显式列两条 option" | step 11 停下 vs Stage 3 菜单是并列两个停顿点？L71 "用户选 go-with-plan → 11. 写 exec-plan" 的 "11" 引用数字错位，需指向"阶段 3 step 11"而非 Stage 2 step 11 —— 全文 step 编号命名空间混淆 | 🔴 **C-06** Critical（关联 C-02）|

---

## 2 Findings 分级汇总

### 🔴 Critical（必须处理；合入前阻塞 or 显式 accept post-fix 路径）

**C-01（A-01 + A-05）SKILL step 8 "且 不踩 Red Flags" AND 语义 vs Red Flag #6 "tester/reviewer findings 说要开" 的一刀切**
- **复现**：tester 本次发现 C-03（DEC-002/004/009 状态行超限）→ 属 architecturally significant 新约束变动（需扩写 L6.3 不回溯 clause），按 5-必开 #4 "细化 Accepted DEC" 应开 Refined-by DEC；但 Red Flag #6 "tester/reviewer findings 说要开" 禁止开 → 死锁
- **影响**：所有 tester/reviewer 驱动的架构级修订无法开新 DEC 也无合规 inline 落点（铁律 4 只覆盖父 DEC 已存在的场景）
- **建议修复**：SKILL step 8 措辞 + 开立门槛 §Red Flags 表同步加一句 "Red Flag #6 不 veto 5-必开 #4；findings 若独立满足 5-必开任一类，按 #4 走 Refined/Supersede；否则走铁律 4 inline"。post-fix inline 到 DEC-025 正文末尾

**C-02（A-04）+ C-06（E-05）Stage 2 step 11 与 Stage 3 L71 step 11 数字命名冲突**
- **复现**：Read SKILL.md L62-L71；L62 是 Stage 2 新 step 11 "停下来请用户审阅"；L71 "用户选 go-with-plan → 11. 写 exec-plan" 的 "11" 指向 Stage 3 的 exec-plan 写入动作 —— 同文档两个 step 11 均出现
- **影响**：LLM 按 "11" 回跳可能走错流程 —— step 11 停顿 vs step 11 exec-plan 落盘
- **建议修复**：原 L71 措辞改为 "用户选 go-with-plan → 写 exec-plan" 去掉 step 号，或把 Stage 3 exec-plan 步骤显式命名为 "Stage 3 step 12"

**C-03（C-01 + C-02）L6.3 不回溯 clause 缺失 + 不匹配 "部分 Superseded" 起首**
- **复现**：
  ```bash
  awk '/^- \*\*状态\*\*:/ { line=$0; sub(/^- \*\*状态\*\*: /, "", line); print NR, length(line), line }' docs/decision-log.md
  ```
  输出显示 L364 (DEC-009) = 144 chars 起首 `部分 Superseded`、L575 (DEC-004) = 96 chars、L628 (DEC-002) = 153 chars
- **影响**：首次 lint 运行即在 "不回溯" 的 DEC-001~020 上 emit 3 条 Critical-level 字符数告警 + 1 条字面值非白名单告警。与 DEC-025 决定 10 "DEC-001~020 不因本门槛被降级或改写" 直接冲突
- **建议修复**：L6.3 追加 "**不回溯** DEC-001~020（铁律 5 声明扩用；lint 扫描跳过这批 DEC 的状态行字符数与字面值检查）"；或白名单扩入 "部分 Superseded by DEC-xxx" 为第 7 值（但后者会污染枚举纪律）。倾向前者 + 显式 grandfather

**C-05（C-04）L6.5 扫描 format 模板 L10 误报**
- **复现**：decision-log.md L8-L19 有 ` ```markdown ` code-fence 包裹的模板；L10 `### DEC-[编号] [标题]` 若 lint 用 `^### DEC-` 裸 regex 扫描会命中
- **影响**：每次 lint 运行 emit 1 条 "DEC-[编号] 缺字段: 日期 / 状态 / 上下文 / 决定 / 相关文档 / 影响范围（全缺）" 误报
- **建议修复**：L6.1-L6.5 明文要求实施 code-fence-aware 扫描，或 lint 实施时显式 skip 匹配 `^### DEC-\[编号\]` 的模板行

### 🟡 Warning（建议 post-fix，不阻塞合入）

- **W-01（A-02）step 8 → step 9 缺 short-circuit**：step 8 判 "不开 DEC" 后 step 9 "新决策 → 追加 decision-log.md" 措辞矛盾；建议 step 9 首句加 "（若 step 8 判不开 DEC 则跳 step 10）"
- **W-02（A-03）"状态默认 Provisional" 强制度弱**：无 lint 即时兜底；建议 L6.3 扩 "新 DEC（落盘 ≤7 日）状态必须起首 `Provisional`"
- **W-03（A-06）Day-0 dogfood 转正悖论**：Provisional OR 逻辑允许 Day-0 即 Accepted；建议 §4.4 加 "Day-0 dogfood 转正需同轮无 tester Critical finding"（与本报告 C-01~C-05 直接相关）
- **W-04（B-02 + B-03）铁律 4 "tradeoff" 判定归属模糊**：建议 §4.1 加 "tradeoff 判定由 architect 主张，reviewer 终审；若分歧升级 architect" 一句
- **W-05（C-03）L6.3 prefix vs full-match 措辞**：建议 L6.3 明确 "起首"判定字符终止于第一个全角/半角括号前
- **W-06（C-05）L6.4 `DEC-xxx` 占位符处理**：建议 L6.4 明文要求实施用 `DEC-\d{3}` regex 而非 `DEC-\w+`
- **W-07（C-06）DEC-017 Amendment 缺 `**相关文档**`**：首次 lint 运行 L6.5 告警；W-07 可 post-fix 补行，或 L6.5 对 `Amendment` 前缀 DEC 放宽
- **W-08（D-01）§决策索引 段写入归属审计开放**：INDEX.md L50-L51 当前已含 DEC-025/022；orchestrator 需 attest "本段由我在 Step 7 relay 写入，非 architect 预写"
- **W-09（E-01）DEC-011 锚点漂移到 step 8 自问句**：DEC-011 L434 字面引 "§阶段 2 第 8 步" 在 DEC-025 生效后指向错行；不回溯（铁律 6），但维护手册需注记

### 🔵 Suggestion（非必须，可 follow-up issue）

- **S-01（B-01）**：design-doc §4.0 加一行 "Red Flag #2 与 5-必开 #3 不冲突：新依赖改动可 touch 多文件，命中 #3 时不以 Red Flag #2 否决"
- **S-02（B-04）**：§4.4 Provisional OR 逻辑加"除非 Day-0 首轮跑出 Critical finding"护栏
- **S-03（B-05）**：铁律 7 "季度审查" 归属（orchestrator? architect?）另开 follow-up issue
- **S-04（C-07）**：L6.2 "按字面换行符" 在实施层加 "或按 `；` 分号分隔项数"后备统计
- **S-05（E-02）**：design-doc §7 待确认项 4 条 `[ ]` 建议 developer 在 Stage 5 落盘时更新为 `[x]` + 实施记录
- **S-06（E-04）**：首次 lint 运行若 C-01~C-05 未 post-fix，分级从 Critical 降为 Info + 一次性 baseline（避免警报疲劳）

---

## 3 Verdict

**Pass-with-post-fix**

- Critical C-01 / C-02 / C-03 / C-05 / C-06 均是可通过 inline post-fix（铁律 4 机制）在 DEC-025 / DEC-026 正文末尾 + SKILL.md 微调 + lint.md L6.3/L6.5 扩一行 克服的措辞级缺陷，**不动核心决策条款**，不触发 Supersede
- Warning W-01~W-09 非阻塞，可批合入后 follow-up
- 不建议 Block：DEC-025/022 核心结构（5 类必开 + Red Flags + Provisional + 铁律 4-7 + Refined by + 索引段）设计方向正确，失败模式均为边角执行细节

**建议下一步**：orchestrator 派 developer 做 post-fix 批处理（C-01~C-06），然后进 Stage 7 reviewer。Stage 8 合入前本 testing 报告 verdict 从 Pass-with-post-fix 升 Pass。

---

## 变更记录

- 2026-04-22 初稿 tester 对抗性审计（18 cases；5 Critical / 9 Warning / 6 Suggestion）
- 2026-04-22 post-fix developer inline 批处理完成（用户选 A 走铁律 4）：
  - **F1（解 C-01）** `skills/architect/SKILL.md` step 8：5 类必开优先短路，Red Flags 仅在 0 命中 5 类时参考；`docs/decision-log.md` DEC-025 post-fix 1 记注
  - **F2（解 C-02/C-06）** `skills/architect/SKILL.md` L71 去 "11." 数字 + L76 改 "Stage 3 最后一步"，消除跨 Stage step 命名空间冲突
  - **F3（解 C-03）** `commands/lint.md` L6.3 加不回溯 grandfather（DEC-001~020 跳过字符数+字面值检查）+ "起首判定止于括号前"
  - **F4（解 C-05）** `commands/lint.md` L6.5 加 code-fence skip + `DEC-\d{3}` regex 收紧（L6.4 同步）；DEC-017 Amendment 缺相关文档 grandfather
  - DEC-025 影响范围段后追 post-fix 5 行说明；不触发新 DEC（铁律 4 正确应用）
  - **verdict 升级**：Pass-with-post-fix → **Pass**（5 Critical 全解；9 Warning + 6 Suggestion follow-up 另议）
