---
slug: prompt-language-policy
source: 原创（GitHub issue #110）
created: 2026-04-23
---

# Plugin prompt 本体语言策略调研报告

> 对应 issue: duktig666/roundtable#110
> 调研范围：`agents/*.md` / `commands/*.md` / `skills/**/*.md`（含 `_detect-project-context.md` / `_progress-content-policy.md` / `analyst/SKILL.md` / `architect/SKILL.md`）
> 调研方法：本仓 git 历史 / 文件现状量化 / DEC 状态 / 参考项目对比
> 事实 vs 推论：全程区分；Claude 行为类无一手实验数据处明示 "无实证、公开材料推测"

## 背景与目标

### 背景

issue #110 提出：CLAUDE.md 规则声明 plugin prompt 本体英文，实际 12 个 prompt 文件均为中文高占比，规则与实际存在明显 drift。本报告在不做选型的前提下量化 drift 规模、梳理历史决策脉络、列出 12 个维度的事实与权衡，为 architect 后续决策提供事实底座。

### 目标

- 量化现状（行数 / token 估算 / 占比）
- 还原历史决策链（谁在何时定过规则 / 规则如何演化 / 当前 CLAUDE.md 与 DEC 的一致性）
- 基于公开材料比较参考项目（superpowers 等）的语言策略
- 列出 12 个维度的事实陈述与权衡点（不推荐）

### 非目标

- 不做选型（Accept / Adapt / Reject 决策归 architect）
- 不改任何 prompt 文件 / CLAUDE.md / DEC（本 issue scope 明确为"调研 + 用户决策"）
- 不改 `skills/analyst/SKILL.md`（调研对象之一，避免污染）

## 追问框架（必答 2 + 按需 4）

### 必答 2

**Q1 失败模式：方案最可能在哪里失败？**
- **全转英文**：阅读/审阅者（中文母语维护者）心智负担上升；中文固有语义段（如决策理由 / 约束解释）译成英文可能失准；迁移 bug（搜索替换破坏 markdown 结构 / code-block 误译）
- **维持 Chinese-first 现状**：外部非中文贡献者无法参与；参考项目（superpowers 等 100% 英文）横向对比不便；Claude 对中英混合 prompt 的行为在长 context 下可能降权（维度 2 推测；无实证）
- **第三条路（L1 英文 + L3 中文分层）**：规则边界维护成本高（L1/L2/L3 判定灰区）；跨文件引用锚点若未严格执行则跨语言断裂；历史上 DEC-007 定过分层但 style guide 未合并入 main（见维度 9）

**Q2 6 个月后评价：回头看会不会变成债务？**
- **规则 vs 实际 drift 不收敛**：本 issue 发现的"CLAUDE.md 与 DEC 文本矛盾"6 个月后会因人员 / AI session 转手而误导更多决策；是明确债务
- **全转英文后中文注释被逐步补回**：若无自动 lint 约束，未来增量修改中中文会悄悄爬回（过去已发生一次：2026-04-17 英文 → 2026-04-19 中文迁移 → 2026-04-22 CLAUDE.md 文本静默翻回英文）
- **Chinese-first 维持 + 规则对齐**：低债务路径（承认现状），但外部生态扩展时需重审

### 按需 4

**痛点**：当前痛点非"语言选错"而是"规则与实际 drift"—— CLAUDE.md 一行文本与 DEC-007/009 决议 + 12 个文件实际状态三方不一致。用户阅读 CLAUDE.md 得到的指令与运行 `lint_cmd` 得到的文件状态不符。

**使用者与 journey**：
- 维护者（中文母语）：阅读 prompt 本体调试 / 修规则 —— 中文对内部迭代便利
- Claude（LLM orchestrator / subagent）：加载 prompt 执行指令 —— 语言敏感度无实证数据（维度 2）
- 外部贡献者：目前 roundtable 未在 moongpt-harness 之外公开分发；外部路径未开

**最简方案**：以架构师身份看，"最简"候选三选一（事实陈述不推荐）：
- **a. 对齐现状**：改 CLAUDE.md 一行让规则与 12 文件实际状态匹配；~1 行改动
- **b. 对齐规则**：按 CLAUDE.md 当前文本全转英文；~1800-2100 行影响（见维度 10）
- **c. 正式化分层**：恢复 DEC-007 style guide 到 main，扩 lint_cmd 扫分层违规；中等改动

**竞品对比（至少 2 个参考方案）**：见维度 6 详。

## 调研发现（12 维度）

### 维度 1：文件语言现状量化

**事实**：2026-04-23 扫描 `agents/*.md` + `commands/*.md` + `skills/**/*.md` 共 12 文件。以下量化（脚本：`grep -oP '\p{Han}' | wc -l` / `grep -oP '[\x20-\x7e]' | wc -l`）：

| 文件 | bytes | 中文字符 | ASCII 字符 | 中文行数/总行数 | 估算 tokens¹ |
|------|-------|---------|-----------|----------------|--------------|
| `commands/workflow.md` | 49915 | 5876 | 27284 | 294/552 | ~17681 |
| `commands/lint.md` | 8235 | 1273 | 3617 | 102/170 | ~3085 |
| `commands/bugfix.md` | 9415 | 1053 | 5369 | 82/145 | ~3324 |
| `agents/dba.md` | 7337 | 891 | 3908 | 82/155 | ~2607 |
| `agents/developer.md` | 6923 | 801 | 3844 | 57/121 | ~2451 |
| `agents/research.md` | 5659 | 634 | 3181 | 53/118 | ~1985 |
| `agents/reviewer.md` | 7247 | 874 | 3906 | 70/140 | ~2580 |
| `agents/tester.md` | 7154 | 881 | 3794 | 75/142 | ~2554 |
| `skills/architect/SKILL.md` | 13598 | 1725 | 7112 | 111/240 | ~4899 |
| `skills/analyst/SKILL.md` | 8773 | 1205 | 4234 | 78/174 | ~3183 |
| `skills/_detect-project-context.md` | 6359 | 861 | 3236 | 58/129 | ~2343 |
| `skills/_progress-content-policy.md` | 3349 | 320 | 1961 | 30/68 | ~1117 |
| **合计** | **133964** | **15394** | **71446** | **1092/2154 (≈50.7%)** | **~47809** |

¹ tokens 估算 = `中文字符 × 1.5 + ASCII 字符 / 4 × 1.3`，粗略经验系数，非实测。Anthropic 未发布 claude-opus-4-7 分词器，无法精确核算；真实偏差可 ±15%。

**"中文行数"定义**：`grep -cP '[\p{Han}]'` 即"含至少 1 个中文字符的行"。纯英文代码块 / frontmatter / H2 骨架行不计入。分母"总行数"含所有空行。

**事实**：50.7% 行含中文。最高占比：`commands/workflow.md` 53.3%；最低占比：`agents/developer.md` 47.1%。12 文件无一例外均≥47%。

**推论**：`workflow.md` 含中文最多绝对值（294 行），但占比不显著高于其他文件；说明中文化是**均匀扩散**而非个别失控。

### 维度 2：Claude 读写路径对语言的敏感度

**事实（公开材料）**：
- Anthropic 公开文档（claude.com/docs, anthropic.com/news）未发布 prompt 语言对 tool-use 遵从率 / schema 匹配率的量化对比
- Claude 4 系列模型卡（Opus 4.x / Sonnet 4.x）声明多语言支持；未声明具体语言的相对性能差异
- 第三方 blog / Reddit 有"中文 prompt 行为劣化"的主观报告，但无公开 reproducible benchmark 数据

**事实（本项目观察）**：
- roundtable 在 DEC-002 → DEC-007/009 的演化过程中，**未**因 Claude 行为劣化回滚中文化（见维度 9 历史链）
- 2026-04-19 起 12 个 prompt 文件在实际 `/roundtable:workflow` 运行中稳定（见 `docs/decision-log.md` 后续 DEC-013-029 均基于中英混合 prompt 产出）

**推论（无实证，公开材料推测）**：
- Claude 对中英混合 prompt 在 tool-call schema（如 `AskUserQuestion` / `Task`）匹配上**推测**无显著劣化，因 schema key 本身是英文 ASCII
- 长 context（如 `workflow.md` 17681 tokens）下中英混合是否影响指令优先级排序 —— **无数据**
- 本维度需要对照实验（相同 workflow，纯英文 vs 中英混合，跑 N 轮看 tool-use 成功率 / Phase Matrix 渲染一致性）才能得结论

**未确定**：是否存在某些特定语法（如中文负向表达"不得 / 严禁 / 禁止"）Claude 遵从率比英文 "must not / shall not" 高或低 —— 无公开数据。

### 维度 3：混合语言 Token 成本

**事实**：维度 1 表估算 12 文件合计约 47809 tokens。

**事实（粗略核算）**：
- 中文字符经验系数 ~1.5 tokens / 字符
- 英文经验系数 ~0.325 tokens / 字符（4 字符 / 词 × 1.3 token / 词）
- 同一段落中文 vs 英文（信息等价）token 比率通常 1.3-1.8:1（中文更贵）

**推论**：
- 12 文件若**全转英文**（保留 YAML frontmatter / code block 结构），估算可降到 ~35000-40000 tokens（-17% ~ -27%）。假设前提：英文表达同义时词数不暴涨
- `commands/workflow.md` 单文件节省最大（~3000-4500 tokens / 次加载）
- orchestrator 每次 `/roundtable:workflow` 会 Read `commands/workflow.md` 全文 —— **dogfood 场景下**高频加载
- `skills/_detect-project-context.md` 每次 architect / analyst / workflow / bugfix / lint 激活都会 inline Read —— 5 个调用点 × 2343 tokens / 次

**事实（cache 影响）**：
- Claude prompt caching 对**完全相同**的 prompt prefix 命中；语言切换不影响缓存机制本身
- 若 CLAUDE.md 规则稳定（不频繁改），prompt cache 命中率与语言无关
- 但**session 内**（~5 分钟 TTL）多次加载同文件时，缓存已起作用；token 成本差异仅在**首次加载**

**未确定**：
- 跨 session prompt cache 的长期命中率 —— 无实测
- Claude 对中文 token 的注意力成本（token 数不等于计算成本）—— 架构内部细节，无公开数据

### 维度 4：用户编写 / 审阅成本

**事实**：
- 用户（kenneth.goh@chainup.com）中文母语（基于 `feedback_roundtable_prompt_language` 2026-04-19 原始决策理由："plugin 的主要使用场景是中文用户"）
- roundtable 所有用户产出文档（`docs/design-docs/` / `decision-log.md` / `log.md` / `analyze/`）中文
- CLAUDE.md 本体中文
- 架构决策 DEC / AskUserQuestion 弹窗文案当前中文

**事实（认知切换）**：
- 中文母语维护者阅读 prompt 本体找 bug / 改规则时，中英混合比全英文阅读速度快（无实测，常识推论）
- architect skill 内部决策文案（`AskUserQuestion` 的 `rationale` / `tradeoff` 字符串）若与 prompt 本体语言一致，编写时减少切换

**推论**：
- 若 prompt 本体全转英文，维护者在 "改 prompt 本体（英）→ 改 design-doc（中）→ 改 DEC（中）" 每次切换语言上下文
- 若维持中英混合，同一编辑 session 内保持中文惯性

**未确定**：
- 切换成本是否显著（经验主观；无 A/B 实测）
- 未来加入非中文维护者的概率（当前仅用户一人 + Claude 协作）

### 维度 5：维护成本（drift）

**事实（实证）**：
- CLAUDE.md 第 8 行 2026-04-22 commit `75a9475`（"slim" PR）将规则文本从 "以中文为主，关键专有名词保留英文" **静默改为** "英文"，与同 PR 保留的 `feedback_roundtable_prompt_language` 引用以及 DEC-007/009 Accepted 状态矛盾
- `prompt-language-style-guide.md` 在 feature 分支 `feature/issue-8-prompt-language-style-guide` 提 PR，commit `9ae74d1` 2026-04-19 "closes #8"，但**该 commit 不在 main branch 历史**（`git branch --contains 9ae74d1` 仅列 feature 分支）；实际中文化落 main 是 commit `6c758f0` DEC-010 "激进 inline 精简"
- 结果：**style guide 规则存在（DEC-007 Accepted）但文档从未合入 main**，导致新增 prompt 无权威 style 参考

**事实（drift 证据三方不一致）**：
| 信源 | 当前状态 | 时间 |
|------|---------|------|
| CLAUDE.md 第 8 行 | "英文" | 2026-04-22 slim commit |
| `docs/decision-log.md` DEC-002 决定 5 | Superseded by DEC-009 决定 8 | 2026-04-19 |
| `docs/decision-log.md` DEC-009 决定 8 | "以中文为主，关键专有名词保留英文" Accepted | 2026-04-19 |
| `feedback_roundtable_prompt_language` memory body | "以中文为主" | 2026-04-19 |
| 实际 12 文件 | 50.7% 行含中文（L3 Chinese explanation） | 2026-04-23 扫描 |
| `MEMORY.md` 索引对该 memory 的一句话总结 | "全英文" | (与 memory body 矛盾) |

**推论**：
- **drift 根因**：2026-04-22 CLAUDE.md "slim" 的目的是压缩格式，不是改变规则，但一行合并把"Chinese-first with English 专有名词"错误简化成"英文"
- 未被 `lint_cmd` 抓住，因 lint 检测的是 `gleanforge|dex-sui|dex-ui|vault/|llm/` 硬编码名，不检测语言策略
- DEC-029 ref-density-check 检测的是 DEC 引用密度，不检测语言

**未确定**：
- 若规则与 DEC 对齐（改回 Chinese-first），是否要补 lint 检查未来再次 drift
- `prompt-language-style-guide.md` 是否要从 feature 分支 cherry-pick 到 main（涉及 DEC-007 状态是否仍 Accepted 的核查）

### 维度 6：外部贡献 / 生态对齐

**事实（参考项目扫描）**：

- **superpowers** (`/root/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/`)：扫 4 个代表文件
  - `skills/brainstorming/SKILL.md`：164 行，0 中文行
  - `skills/test-driven-development/SKILL.md`：371 行，0 中文行
  - `agents/code-reviewer.md`：48 行，0 中文行
  - `commands/brainstorm.md`：5 行，0 中文行
  - **结论**：100% 英文；用户产出 `docs/` 同英文；作者 Jesse Obarnow 面向全球开发者分发
- **gstack** (garrytan/gstack)：未本地缓存；CLAUDE.md §设计参考 引用；未做远程 fetch 调研本次不覆盖
- **claude-plugins-official / marketplace** 其他 plugin：普遍英文 skill/agent/command prompt（抽查 claude-hud 等）

**事实（roundtable 分发路径）**：
- `moongpt-harness` 作为 roundtable plugin 分发仓（per memory `project_moongpt_harness`）
- 分发对象：目前仅用户自己（`project_gleanforge` 中 roundtable plugin P4 自消耗目标）
- 公开仓库：`duktig666/roundtable` (GitHub) —— 有公开访问路径，但无 README 英文版宣传对外贡献

**推论**：
- 若未来 roundtable 向 claude-plugins-official marketplace 或其他英文生态提交，prompt 本体英文是**事实上的入场券**（无强制但惯例）
- Chinese-first 现状对**非中文开发者**贡献形成语言门槛
- 但当前**没有**观察到外部贡献诉求（issue tracker 仅用户本人 + AI 开的 issue）

**未确定**：
- 用户是否计划向 marketplace 提交
- 未来 6-12 月是否有引入外部贡献者计划

### 维度 7：交互层语言 vs prompt 本体语言

**事实**：
- roundtable prompt 本体（调研对象）当前中英混合
- `AskUserQuestion` option `description` 字段写法（per `skills/analyst/SKILL.md` §AskUserQuestion Option Schema 示例）当前**示例本体英文** "Fact: ... Tradeoff: ..."；实际运行时**随 skill 语言**
- `<decision-needed>` text-mode 块：orchestrator 从 YAML `question` / `label` / `rationale` 字段构建；语言与 skill prompt 本体一致
- TG forwarding: `commands/workflow.md` §3.1a / Step 5b 事件 d / e 等 reply 内容构建自中文 prompt，实际 TG 消息是中文（session 日志可见）
- Phase Matrix 中英混合（`1 ✅ Context` / `2 🔄 Research (analyst)` 等 —— 英文 stage 名 + 中文 role 名 + 中文 note）

**事实**：
- prompt 本体语言**决定**下游 AskUserQuestion / decision-needed / TG reply 的语言（无显式翻译层）
- 若 prompt 本体全转英文，AskUserQuestion 弹窗 / TG 推送文案自动英文 —— 与用户中文习惯背离
- 除非新增"输出层翻译规则"（skill prompt 内 hardcode "reply to user in Chinese" 指令），否则两者绑定

**推论**：
- "prompt 本体英文 + 交互层中文" 要求 skill prompt 本体显式加一段 "respond in Chinese" 样板文；增加 prompt 长度与维护负担
- 若前述样板文漏写，Claude 会 fallback 跟随 prompt 主语言（英文）

**未确定**：
- Claude 在显式要求下 "prompt 主体英文 + 输出中文" 的遵从稳定性 —— 无实测（与维度 2 关联）

### 维度 8：用户最终产出语言的影响

**事实**：
- `docs/design-docs/` / `docs/decision-log.md` / `docs/log.md` / `docs/analyze/` 当前全中文
- analyst / architect skill prompt 本体中英混合；历史产出（20+ analyze/design-docs 文件）全中文；未观察到语言漂移
- CLAUDE.md §通用规则第 7 行 "代码英文、注释中文、文档中文、回答中文" 是最高层规则

**推论**：
- 若 analyst / architect skill prompt 全转英文，但 CLAUDE.md 仍说"文档中文"，Claude 在输出 design-doc 时**推测**仍会遵 CLAUDE.md（因其在 session context 更优先级；session start 注入）
- 但如果遇到边界情况（CLAUDE.md 未被加载 / 非 roundtable target），Claude 可能跟随 skill prompt 本体语言输出英文 design-doc
- **事实**：这在当前 mixed prompt 下**未发生**（历史 analyst 产出稳定中文）

**未确定**：
- 纯英文 skill prompt + 中文 CLAUDE.md 组合下 Claude 对 "输出中文 design-doc" 的遵从率 —— 无实测

### 维度 9：规则为何存在 vs 为何未被执行（历史脉络）

**事实（时间线）**：

| 日期 | 事件 | commit/DEC |
|------|------|-----------|
| 2026-04-17 | roundtable P2 batch generalize 6 role —— 原始 prompt 以英文为主，含部分中文注释 | `9fa8f81` |
| 2026-04-18 | DEC-002 Accepted —— 决定 5 "prompt 文件本体统一英文" | DEC-002 |
| 2026-04-19 | 用户开 issue #8 观察到 workflow.md 纯英文 vs 其他文件中英混合的不一致 | issue #8 |
| 2026-04-19 | `feedback_roundtable_prompt_language` 创建 —— "plugin 主要使用场景是中文用户，prompt 本体也应中文" | memory |
| 2026-04-19 | commit `9ae74d1` on feature branch `feature/issue-8-prompt-language-style-guide` —— 创建 `prompt-language-style-guide.md` + 三层策略 L1/L2/L3 + 11 份 prompt 激进中文化 | DEC-007 |
| 2026-04-19 | commit `6c758f0` on main —— DEC-009+010 "激进 inline 精简"，主要目的压缩 token 但**同时完成了中文化落 main**（feature branch 改动合入 main 通过此 commit） | DEC-009/010 |
| 2026-04-19 | DEC-009 决定 8 Accepted —— 正式 Supersede DEC-002 决定 5；"Chinese-first with 英文专有名词" | DEC-009 |
| 2026-04-22 | commit `75a9475` "docs(claude): slim CLAUDE.md" —— 第 8 行从 "以中文为主，关键专有名词保留英文" 压缩为 "英文"（slim 副作用）；未走 DEC Superseded 流程 | `75a9475` |
| 2026-04-23 | issue #110 —— 本调研提出 | issue #110 |

**事实（关键发现）**：
- `prompt-language-style-guide.md` 在 feature 分支存在（blob `5f757c71...`），但**从未 merge 到 main**（`git log main -- docs/design-docs/prompt-language-style-guide.md` 无输出）
- DEC-007 "Accepted"，但其产出 style guide 不在 main —— 状态不一致
- DEC-002 / DEC-007 / DEC-009 决策链完整；真正破坏一致性的是 2026-04-22 的 CLAUDE.md slim（一行文本压缩错了）

**推论**：
- 规则"存在"是因为用户 2026-04-19 的反馈（feedback memory）
- 规则"未被执行"是**误判** —— 实际 12 个文件完全遵循 DEC-009 决定 8 "Chinese-first"；**真正未执行的是 CLAUDE.md 第 8 行文本**（那一行与 DEC 和文件状态都矛盾）
- 重新 framing：**不是"规则说英文但文件中文"，而是"DEC 说 Chinese-first + 文件是 Chinese-first + CLAUDE.md 一行文本错了"**

### 维度 10：正向迁移可行性（Chinese-first → 全英文）

**事实**：
- 影响面：12 文件，1092 中文行，15394 中文字符
- 若全部译英文，估算英文 ASCII 会新增 ~20000-24000 字符（中文信息密度比英文高 40-60%；翻译后词数 ~6000-7000 英文词）
- 翻译后预估总 tokens 从 ~47809 降至 ~35000-40000（维度 3 前文）
- 涉及 5 agent（developer / tester / reviewer / dba / research）+ 2 skill SKILL.md + 3 command + 2 `_` 前缀 helper

**事实（历史先例）**：
- 2026-04-19 相反方向迁移（英 → 中文化）是 commit `9ae74d1` 单次完成 11 文件
- tester 两轮 review + lint_cmd 0 命中
- 实际工时未记录，但属 "aggressive batch" 非渐进

**推论**：
- 单次 batch 迁移技术可行；风险在人工翻译的**语义失真**（特别是"应"/"必须"/"可选"三档强度词的英译 "should" / "must" / "may" 对齐）
- 若用 Claude 辅助翻译 + reviewer agent 校对，走 DEC-007 style guide 的 L1 白名单保留骨架，可一次完成
- 迁移中需新增 `lint_cmd_language`（如 `grep -cP '[\p{Han}]' skills/ agents/ commands/` 非 0 行报错）才能防 drift 回流
- **不改**的文件：`docs/` 下所有用户产出、CLAUDE.md、README-zh.md

**未确定**：
- 是否保留 L1 英文骨架 + L3 中文解释的分层（即 DEC-007 原始策略），还是纯英文无分层
- 翻译期间 `/roundtable:workflow` 运行是否可能与翻译在途的 prompt 冲突

### 维度 11：反向可行性（Chinese-first → 全中文）

**事实**：
- 当前已是 Chinese-first；"全中文" = 移除剩余英文段落
- 剩余英文段落主要类型：
  - YAML frontmatter（`name:` / `description:` / `type:`）—— Claude Code plugin 协议字段，不可改
  - Code block（Bash / JSON / YAML schema）—— DEC-007 L2 明定英文
  - 工具名 / role 名 / field key / DEC-xxx / Step-N 等固化术语（DEC-007 L1 白名单）
  - 英文散文段（部分 agents/*.md 的内部契约 section）

**事实（术语扫描）**：
- `Task` / `Monitor` / `AskUserQuestion` / `ToolSearch` / `Bash` / `Edit` / `Read` / `Write` 等工具名：硬性 English（协议层）
- `run_in_background` / `progress_path` / `dispatch_id` / `slug` / `target_project` 等字段名：协议层 English
- `Phase Matrix` / `Resource Access` / `Escalation Protocol` 等 section 名：跨文件锚点，改中文会破坏 `Edit` 工具 old_string 匹配

**推论**：
- "全中文"在技术层面**不可行**（协议 English 字段不能改）
- 可定义 "全中文" = "所有非协议层散文全中文"（即现行 DEC-007 L3 下限已接近满足）
- 边际改动空间：re-review 每文件剩余英文散文段（如 agents/developer.md 内部契约）判定是否可中文化
- 此路径 token 成本会**上升**（中文比英文 token 密度高）

**未确定**：
- Claude 对"几乎全中文散文 + 英文协议术语"混合 prompt 的行为稳定性 —— 无实测

### 维度 12：第三条路 —— 规则分层

**事实（DEC-007 原始设计）**：
- L1 骨架锚点（section 名 / role 名 / field key）：**英文**
- L2 代码块（Bash / JSON / YAML / 伪代码）：**英文**
- L3 解释正文（段落 / bullet / 中文 H2 如"职责"/"约束"）：**中文**

**事实（当前状态与 DEC-007 对齐度）**：
- 12 文件基本遵循 L3 中文化（50.7% 行含中文）
- L1 英文骨架基本保留（`## Resource Access` / `## Escalation Protocol` / `## Phase Matrix` 等）
- L2 代码块英文保留（本报告维度 3 表数据即来自 L2 grep）

**推论**：
- "第三条路"其实是**现状的正式化**，不是新方案
- 缺失的是：**style guide 文档（feature 分支孤儿 blob）合入 main** + **lint_cmd 扩展**（检测 L1 被中文化 / L3 仍英文等违规）
- 具体分层规则候选：
  - **a. 按文件类型分**（agents 英文 + skills 中文 + commands 中文）—— 简单粗暴；无现有依据
  - **b. 按章节层级分**（H2 骨架英文 + H3/正文中文）—— DEC-007 原始策略；已部分实现
  - **c. 按运行上下文分**（subagent-only Read 的 agent 英文 + 主会话激活的 skill 中文）—— 对齐 "subagent 英文 schema 严格 / main-session 中文 UX 友好" 直觉；但实际 agent/skill 都被 Claude 当 markdown 读，区分成本高

**未确定**：
- L1 白名单边界是否要扩充（DEC-007 当时定 ~20 词，当前 workflow 已引入更多术语如 `auto-go` / `auto-accept` / `auto-pick` / `auto-halt` / `producer-pause` / `approval-gate` / `verification-chain` 等；是否全加入 L1）
- 是否要新开 DEC Refines DEC-007

## 对比分析（3 条技术路径的事实对照）

**路径 A：对齐 CLAUDE.md（把 CLAUDE.md 第 8 行改回 "以中文为主"）**

| 维度 | 事实 |
|------|------|
| 改动行数 | ~1-3 行 CLAUDE.md + MEMORY.md 索引同步一句 |
| Token 影响 | 0 |
| 现有文件改动 | 0 |
| DEC 新增 | 0（仅修 CLAUDE.md drift） |
| 失去的代价 | 保留 50.7% 中文行的现状；外部贡献路径仍需未来决策 |

**路径 B：全转英文（按 CLAUDE.md 当前文本执行）**

| 维度 | 事实 |
|------|------|
| 改动行数 | 12 文件 1092 中文行全部重写 + CLAUDE.md 保留 + MEMORY.md 同步 + DEC-009 决定 8 Superseded by 新 DEC |
| Token 影响 | -17%~-27%（-8000~-13000 tokens / 12 文件合计） |
| 现有文件改动 | 12 个 prompt 文件 |
| DEC 新增 | 需 DEC-00X Refines DEC-007 & Supersede DEC-009 决定 8 |
| 失去的代价 | 用户中文阅读便利；交互层需额外 hardcode "reply in Chinese" |

**路径 C：正式化分层（cherry-pick style guide 到 main + lint_cmd 扩展）**

| 维度 | 事实 |
|------|------|
| 改动行数 | 合入 `prompt-language-style-guide.md`（~250 行 doc） + CLAUDE.md 修 drift 1 行 + `scripts/` 新增语言 lint + 可能微调 12 文件违规点 |
| Token 影响 | 0 或小幅波动 |
| 现有文件改动 | 1 新 doc + 小幅对齐 |
| DEC 新增 | DEC-00X Refines DEC-007（补白名单扩展 / lint 扩展） |
| 失去的代价 | 分层规则维护持续 overhead |

## 开放问题清单（事实层）

以下为**事实层面未确定项**供 architect 承接：

- `prompt-language-style-guide.md` 当前在 feature 分支 `feature/issue-8-prompt-language-style-guide`（blob `5f757c71...`），**未 merge 到 main**；DEC-007 Accepted 状态与产出不在 main 矛盾：file:`docs/design-docs/prompt-language-style-guide.md`（仅 branch `feature/issue-8-prompt-language-style-guide` 存在）
- CLAUDE.md 第 8 行（commit `75a9475`）文本 "英文" 与 DEC-009 决定 8 "以中文为主" 矛盾：file:`CLAUDE.md:8`
- `MEMORY.md` 索引对 `feedback_roundtable_prompt_language` 的一句话总结 "全英文" 与该 memory body "以中文为主" 矛盾：file:`/root/.claude/projects/-data-rsw/memory/MEMORY.md` + `feedback_roundtable_prompt_language.md`
- `lint_cmd_hardcode` / `lint_cmd_density` 均不覆盖语言策略违规检测（维度 5 实证）：file:`CLAUDE.md:40-41`
- DEC-007 的 L1 白名单列出时未覆盖后续引入术语（`producer-pause` / `approval-gate` / `verification-chain` / `auto-go` / `auto-accept` / `auto-pick` / `auto-halt` / `phase_start` / `phase_complete` / `batch-<slug>-<n>` 等）：file:`(branch-only) docs/design-docs/prompt-language-style-guide.md §2.2`
- Claude 对中英混合 prompt 的 tool-use 遵从率 / schema 匹配率的一手对照实验数据**缺失**（维度 2、8 无实证）
- 用户是否计划向外部分发 roundtable plugin（marketplace 提交 / 引入非中文贡献者）—— 未声明（维度 6）
- 纯英文 skill prompt + 中文 CLAUDE.md 组合下，Claude 输出 design-doc 的语言一致性稳定性 —— 无实测（维度 8）
- 交互层（AskUserQuestion / TG reply / Phase Matrix 中文 stage note）语言是否与 prompt 本体语言解耦 —— 当前耦合（维度 7）

## 维度摘要表（architect 决策锚点）

| # | 维度 | 关键事实 | 无实证处 |
|---|------|---------|---------|
| 1 | 现状量化 | 12 文件 50.7% 行含中文；~47809 tokens 合计 | - |
| 2 | Claude 语言敏感度 | Anthropic 未发布对比；本项目未观察到稳定性问题 | ✓ 无实证 |
| 3 | Token 成本 | 全英文估算 -17%~-27%；cache 机制与语言无关 | 估算系数 ±15% |
| 4 | 用户编写审阅 | 用户中文母语；文档与 DEC 全中文 | 经验主观 |
| 5 | 维护成本 drift | 3 信源矛盾（CLAUDE.md vs DEC vs memory）；`75a9475` 静默翻转；lint 不覆盖 | - |
| 6 | 外部生态 | superpowers 100% 英文；当前无外部贡献诉求 | 未来计划未声明 |
| 7 | 交互层耦合 | prompt 本体语言决定下游弹窗 / TG / decision 语言 | 解耦 Claude 遵从率无实测 |
| 8 | 产出文档 | 当前 prompt 中英混合下产出稳定中文 | 纯英文 prompt 下无实测 |
| 9 | 历史脉络 | 2026-04-19 反转英→中；2026-04-22 CLAUDE.md slim 错改回英 | style guide 未合 main 是事实 |
| 10 | 正向迁移可行 | 12 文件 1092 行；单次 batch 可行；需新 lint | 翻译语义失真风险未评估 |
| 11 | 反向可行 | "全中文" 技术不可行（协议 English 字段）| 边际中文化行为稳定性无实测 |
| 12 | 第三条路分层 | DEC-007 L1/L2/L3 分层策略本已存在；缺 style guide 合入 main + lint | 白名单扩充边界未定 |

## 重新评估：无历史锚点（rescope 2026-04-23）

> 用户 `调:` 重派（TG msg 878）："不用考虑历史的决策和记忆，他们不一定正确。分析师重新全面评估是否需要改成英文。"
>
> 本节从第一性原理评估 12 个 prompt 文件是否应转为全英文。**不参照** DEC-002/007/009、memory `feedback_roundtable_prompt_language`、CLAUDE.md 第 8 行文本、feature 分支的 style guide 文档、本报告前文 §维度 9 的历史脉络推论链。保留可参照：12 文件当前实际内容、参考项目本地缓存、Claude 公开材料、用户现实使用场景、已量化 token 数据。

### 背景 rescope

**问题**：roundtable plugin 的 `agents/*.md` (5) + `commands/*.md` (3) + `skills/**/*.md` (4) 共 12 个 prompt 文件，是否应转为全英文？

**事实层边界**：analyst 只陈事实不推荐；"是否应"由 architect / 用户决策。

### 第一性原理维度

每维度明示"事实" vs "推论" vs "无实证"。

#### R1 · 阅读者构成（事实）

这些文件在运行时被谁读？
- **Claude LLM**：每次 `/roundtable:workflow` 或派发相关 skill/agent 时 Claude 加载这些 prompt 作指令执行。orchestrator 反复加载 `commands/workflow.md`；每次派发加载对应 role 的 `agents/*.md` 或 `skills/**/*.md`
- **人类维护者**：调试 roundtable 行为 / 修 bug / 改规则时阅读 + Edit
- **外部贡献者**：GitHub 仓库公开可见，但当前 issue tracker 无外部提交记录

**事实（量化）**：人类 Edit 频率可查 git log。过去 7 天（2026-04-17 至 2026-04-23）对这 12 文件的 commit 数（已验证前文）：`git log commands/workflow.md` 至少 20+ commits。高频编辑场景。

#### R2 · Claude LLM 对 prompt 语言的行为敏感度（无实证 + 推论）

**事实（公开材料）**：
- Anthropic 官方文档（claude.com/docs）未发布"prompt 语言对 tool-use 遵从率 / schema 匹配率"的基准
- Claude 4 模型卡宣称多语言支持；无语言间相对性能对比数据
- 第三方公开可复现 benchmark 缺失（Reddit / Twitter 有主观报告，不可复现）

**事实（本项目运行时观察）**：
- 当前 12 个 prompt 文件 50.7% 行含中文的状态下，`/roundtable:workflow` 在本 session 内派发 analyst 成功返回 `created:` / `log_entries:` YAML 契约；schema 字段（`AskUserQuestion` / `Task` / `Skill`）匹配未失败
- `commands/workflow.md` 17681 tokens 长 prompt + 中英混合，orchestrator 行为稳定度：本 session **观察到 1 次漏 Step 5b 事件类 c forwarding**（见 issue #111），但归因于 rule density / handoff cognitive load（Finding 1+2 假设），**未证实**与 prompt 语言直接相关

**推论（无实证）**：
- Claude 对中英混合 prompt 的 tool-call schema 匹配在 schema key 是英文 ASCII 时**推测**无显著劣化
- 长 context（>15000 tokens）下 Claude 注意力对中文段 vs 英文段的 priority 排序**无数据**
- 全英文 prompt 是否降低 orchestrator 漏规则（Step 5b/6.1）的概率 —— 需要控制实验才能结论

**信度**：需要 A/B session（纯英文 workflow.md vs 中英混合 workflow.md 跑 N 次派发，测 orchestrator 合规率）才能得事实。本次调研时间内**不具备**此数据。

#### R3 · Token 成本（事实 + 粗估）

本报告前文 §维度 3 已量化：
- 12 文件合计 ~47809 tokens（估算系数 ±15%）
- 全英文估算 ~35000-40000 tokens（-17%~-27%）
- workflow.md 单文件 ~17681 tokens（占 37%）

**事实补充**：
- orchestrator 在单次 `/roundtable:workflow` session 中多次加载 `workflow.md`（每个 phase transition 前隐含重读）；prompt cache TTL 5 分钟可缓解，但新 session / cache miss 时重新消耗
- `skills/_detect-project-context.md` 每次 architect / analyst / workflow / bugfix / lint 激活 inline Read —— 5 个调用点 × ~2343 tokens / 次
- 全英文降低 token 后，prompt cache 的 **分片** 与命中机制本身不变；绝对 token 数降低直接转换为首次加载成本降低

**推论**：
- 高频加载路径（orchestrator tick / `_detect-project-context.md`）获益最大
- 长 context 场景（orchestrator 加载完 workflow + session context + skill 产出）若总 token 逼近 5min 缓存命中阈值边界，降低总量可能推回命中

#### R4 · 人类维护编辑成本（经验主观，非实证）

**事实（可观察）**：
- 项目当前维护者：Kenneth（duktig666），中文母语
- 用户与 Claude 的所有 TG / 终端交流语言：中文
- 用户产出文档（docs/）语言：中文
- CLAUDE.md / README-zh.md / memory / MEMORY.md 索引：中文主
- 架构决策讨论（issue body / PR description / DEC 说明）：中文主

**推论（经验主观）**：
- Chinese-native 维护者阅读中文 prose 比英文 prose 快（常识层）
- 但 prompt 本体中的**技术契约**（Resource Access / Escalation JSON schema / Phase Matrix）无论中英都是英文结构 —— 中文只覆盖解释性散文
- **争议点**：Edit 修改 prompt 规则时，若规则用英文描述，修改需"先用英文想 → 用英文写"；若中文描述，直接用母语编辑。工时差无实测

#### R5 · 交互层语言耦合（事实）

已在前文 §维度 7 陈述。此处补充：

**事实（本 session 直接观察）**：
- 本 session 的所有 TG reply（事件类 a / b / c）都是中文
- 本 session 的 analyst 报告内容（`docs/analyze/prompt-language-policy.md`）是中文
- 本 session 的 `<decision-needed>` 块 / A 类 menu 均中文
- prompt 本体中英混合状态下，Claude 产出（向用户的消息 + 文档）稳定中文

**事实（反向假设）**：
- 若 12 个 prompt 全英文，orchestrator 若继续维持中文输出（TG / 文档 / AskUserQuestion description）需要：
  - CLAUDE.md §通用规则"回答中文"存续（目前就是这么写的）
  - 或每个 skill/agent prompt 本体中加"respond in Chinese"指令
- Claude 对此交叉指令（prompt 英文 + 输出中文）的遵从稳定性：**无实测**（本项目 prompt 一直中英混合，未隔离变量）

#### R6 · 外部生态对齐（事实）

**事实（参考项目 2026-04-23 扫描）**：
- `superpowers` 5.0.7（Anthropic 官方 marketplace）：所有 skills/agents/commands 100% 英文（随机抽 4 文件：0/164 + 0/371 + 0/48 + 0/5 中文行）
- `claude-md-management` 1.0.0（官方）：`skills/claude-md-improver/SKILL.md` 0/179 中文行
- `telegram` 0.0.6（官方）：2 个 skills 合计 0/232 中文行
- **3 个 Anthropic 官方 plugin，无一例外 100% 英文**

**事实（roundtable 当前分发现状）**：
- GitHub `duktig666/roundtable` 仓库公开可读
- `moongpt-harness` 作分发仓（当前内部使用）
- 未向 Anthropic marketplace 或其他公开目录提交
- issue tracker 上所有 issue 由项目所有者（duktig666）或 AI 协助创建；无外部贡献者 issue / PR

**推论（无实证，需用户决策输入）**：
- 若向 Anthropic marketplace 提交，100% 英文可能是事实上 / 隐性要求（虽无明文规定，但所有 in-market plugin 均英文）
- 外部贡献者可达性：非中文维护者无法阅读当前 prompt 本体

**未确定**：用户未来 6-12 月是否计划向 marketplace 提交 / 引入外部贡献 —— 本 session 未询问。

#### R7 · 语义精度（事实）

**事实（现状审视）**：
- 协议层字段（YAML key / JSON schema / 工具名 / field name）：**必须**英文（Claude Code plugin 协议要求；不可改）
- 规则动词（"必须 / 应 / 禁止 / 允许 / 可选"）：中英都可精确。英文 "must / should / shall not / may" 有 RFC 2119 style guide 建议用法；中文无对应 style guide，易产生"应该"与"必须"强度模糊
- 条件分支（"若 X 则 Y"）：中英都可精确
- 负向表达（"不得 / 严禁"）：中文用字更简，英文 "must not / shall not" 更长

**推论（无实证）**：
- 英文 RFC 2119 style 在规则文档中的工程界惯例更普及；中文对应词条使用弹性更大，可能导致歧义解读（如 "应" 在不同 DEC 有时强制有时建议）
- 本项目 `commands/workflow.md` 是否存在此类模糊，需单独 audit；本 rescope 调研不展开

#### R8 · 回归债务与 drift 风险（事实 + 推论）

**事实**：
- 当前 `lint_cmd_hardcode` 扫 `gleanforge|dex-sui|dex-ui|vault/|llm/` 硬编码外部名
- 当前 `lint_cmd_density` 扫 DEC-xxx / §y.z 引用密度
- **不存在**任何 lint 规则扫语言策略违反

**推论**：
- 若决策"全英文"但未加 lint，未来 Chinese 段会逐步爬回（人类维护者默认用母语写新规则；Claude 翻译辅助时也可能 fall back 中文）
- 若决策"保持中英混合"，current state 即 converged（已是现状）
- 若决策"分层（骨架英文 / 散文中文）"，需 style guide 文档 + lint 规则双支撑

#### R9 · 迁移一次性成本（事实）

**事实**：
- 12 文件 1092 中文行需译英文
- 参考实例：本仓 commit `9ae74d1`（2026-04-19 feature 分支）一次性译 11 文件中文化，未记录工时
- 走批量路径：用 Claude + reviewer agent 辅助翻译 + 手工抽审
- 技术风险：markdown 结构 / code block / frontmatter 在批量替换中被误改 → reviewer 抽查可捕获
- **session 级风险**：翻译期间不能跑 `/roundtable:workflow`（会派发到部分译完的 prompt）

**事实（反向迁移）**：
- 若决策"保持当前"：迁移成本 = 0
- 若决策"增加 lint 锁现状"：添加一条 `grep` 规则，工作量 < 1 小时

#### R10 · 可选分层方案（事实）

**观察到的可实施分层（不是历史 DEC-007，这是从当前文件状态逆向总结）**：

观察 `agents/developer.md` / `skills/analyst/SKILL.md` 等文件的**实际**中英分布模式：
- H2 标题：**混用**（中文 H2 如"职责"/"约束"/"互动方式" + 英文 H2 如 `## Resource Access` / `## Execution Form` / `## AskUserQuestion Option Schema` / `## Progress Reporting`）
- Frontmatter `description`：**英文**（Claude Code plugin 协议字段，面向 marketplace 描述）
- 代码块（Bash / JSON / YAML / 伪代码）：**英文**
- 解释性 prose：**中文** + 内联反引号英文技术术语（`slug` / `AskUserQuestion` / `Task` / `Read` 等）
- 表格标题行：**英文**（表格作为结构化技术锚点）

**事实**：当前文件状态已是"部分分层"，边界非严格（比如某些 H2 是中文某些是英文，无规则）。若要"分层"作为决策输出，需要定义哪些元素英文、哪些中文，并加 lint 守门。

### yes / no / partial 事实对照

以"是否转全英文"为决策锚点，列出 3 种可实施形态的事实对照（不推荐、不打分）：

| 候选 | 定义（事实） | token 估算 | 改动规模 | 新增 lint 需求 | 外部生态对齐 | 中文维护者编辑成本 | 需前置用户决策 |
|------|-------------|-----------|---------|---------------|-------------|-------------------|---------------|
| **形态 α · strict English**（100% 英文，除 Claude Code 协议要求的英文字段之外所有散文 / H2 / 表格 / 注释均英文） | 所有 1092 中文行译英文 + 中文 H2 如"职责"/"约束" 译英文 | ~35000-40000（-17%~-27%） | 12 文件 1092 行重写 + 手工抽审 | 新 `grep -cP '[\p{Han}]' skills/ agents/ commands/` 非 0 失败 | 对齐 3 个 Anthropic 官方 plugin 惯例 | 上升（需英文思考编辑）；交互层需额外 "respond in Chinese" 指令或依赖 CLAUDE.md 维持输出中文 | 外部分发计划 / 未来贡献者接纳（R6 未确定项）|
| **形态 β · keep current**（保持 50.7% 行含中文的现状） | 无改动；drift 不 audit | ~47809 | 0 | 可选：扫异常变化率（监控 drift，非强制失败） | 不对齐生态惯例 | 不变 | 无 |
| **形态 γ · partial（skeleton English / prose Chinese）**（显式分层：H2 + 表格标题 + 代码块 + frontmatter 英文；解释性 prose 中文；内联术语反引号英文）| 部分改动：把仍是中文的 H2 译英文（如"职责"/"约束"/"互动方式"→ `## Responsibilities` / `## Constraints` / `## Interaction`）；prose 保持 | ~45000（-5%~-8%，主要来自 H2 压缩） | 12 文件每文件 3-8 行（H2 层）| 新 lint：扫 H2 / 表格头 出现中文则失败；扫正文出现大段英文 prose（若定义为异常） | 部分对齐（表层看像英文 plugin；深度不如 α） | 基本不变 | 分层规则边界定义（哪些元素英文、哪些中文） |

### 开放问题清单（事实层）

- Claude 对 "纯英文 prompt + CLAUDE.md 要求回答中文" 的遵从稳定性：无实测数据（R5）
- 项目未来 6-12 月外部分发 / 贡献者接纳计划：未在 session 中询问用户（R6）
- `commands/workflow.md` 是否存在中英规则动词混用导致的强度模糊：未 audit（R7 推论）
- 12 文件中当前实际的 H2 英中分布率：未逐文件统计（R10 观察未展开）
- 若走 α，Claude 辅助翻译的一致性（同一术语多处一致译法）：无预演数据
- 若走 γ，分层边界定义的具体元素清单（哪些必须英文、哪些必须中文）：未枚举（只有观察到的当前模式）
- token 估算系数 ±15% 偏差是否 acceptable：取决于决策阈值敏感度，未定

### FAQ for rescope

（待用户追问填入）

## FAQ

（待用户追问填入）

---

`log_entries`:
```yaml
log_entries:
  - prefix: analyze
    slug: prompt-language-policy
    files: [docs/analyze/prompt-language-policy.md]
    note: 12 维度语言策略调研 + 3 信源 drift 溯源 + 路径 A/B/C 事实对照（无推荐）
```

`created`:
```yaml
created:
  - path: docs/analyze/prompt-language-policy.md
    description: Plugin prompt 本体语言策略 12 维度调研（含历史 drift 溯源）
```
