---
slug: faq-sink-protocol
source: docs/design-docs/faq-sink-protocol.md
created: 2026-04-21
reviewer: tester (adversarial)
---

# FAQ Sink Protocol 测试计划

## 1. 当前覆盖现状

- design-doc §5 列 7 场景（用户常见路径）
- 无自动化测试（纯 orchestrator prompt 行为，靠 dogfood session 验证）
- `lint_cmd` 已覆盖硬编码扫描（0 命中）

## 2. 规格模糊点（发现的潜在问题）

下列 F-n 编号即 findings，final message 统一呼应。

### F1 [High]：70% 词重叠去重算法未指定

**位置**：`commands/workflow.md` Step 0.2 "去重" / design-doc §2.4。

**问题**：仅说 "≥70% 词重叠"，未指定：
- tokenization（whitespace split / 语素切分 / n-gram？）
- 中英混合处理（`orchestrator` vs `编排器` 视为同词？）
- 是否去停用词（"是" / "什么" / "的"）
- stemming / case-folding（`DEC-013` vs `dec013`）
- 集合算子（Jaccard / containment / cosine）

**风险**：不同 session orchestrator 实现漂移；两轮同问一次判重复一次判新增，FAQ 冗余或漏沉淀。

**建议**：明文指定 "按 whitespace + 标点 split，lower-case，去中英停用词（最小白名单），Jaccard ≥0.7" 或直接降级为 "`Read` FAQ 后由 orchestrator LLM 判断近似问题"（不定阈值，但约定语义 dedupe）。后者更实际。

### F2 [High]：`<project>` 填充规则未定义

**位置**：Step 0.2 "`# <project> FAQ`" minimal header 模板 / design-doc §3.1。

**问题**：不存在 faq.md 时 orchestrator 创建 header，`<project>` 由谁填？
- `target_project` basename？（dogfood 下是 `roundtable`，填出 `# roundtable FAQ` 合理）
- CLAUDE.md 首行 `# <name>`？（不稳定，名字不一定是 project name）
- 未定义 → 字面留 `<project>` 字符串（已 dogfood faq.md 手写头部绕过，但协议本身未闭合）

**风险**：orchestrator 首次创建时可能写字面 `# <project> FAQ`，后续轮次难以修正。

**建议**：明文 "取 `target_project` basename 作为 `<project>`"。

### F3 [Medium]：白名单关键词与 A 类 menu `问:` 边界漂移

**位置**：Step 0.2 "与 A 类 `问:` 区别" 段 / design-doc §4。

**问题**：用户在 A 类 producer-pause 菜单阶段**不**用 `问:` 前缀直接问机制类问题 —— 走 Step 0.2 还是走 menu 循环？
- 现规则：Step 0.2 触发条件是"非 A 类菜单 `问:`"，言外之意 A 类 menu 阶段的直接提问 **也** 走 Step 0.2
- 但 DEC-006 §A 明确"菜单穷举 + 禁止 silent default"—— 用户未用 `问:` 前缀时 orchestrator 应提示菜单而非直接答

**冲突**：A 类 menu 下用户裸问"auto_mode 啥意思"，orchestrator 应：(a) 按菜单穷举原则回"请用 `问: ...`"，还是 (b) 按 Step 0.2 直接答 + sink？

**建议**：在 Step 0.2 增加一句 "A 类 producer-pause 菜单激活期间裸问仍走 menu；`问:` 前缀触发 analyst slug 级 FAQ，Step 0.2 只覆盖菜单未激活的直接提问"，或明确 Step 0.2 覆盖一切非 `问:` 裸问（含 menu 内）。两条路都可接受，关键是消歧。

### F4 [Medium]：`log_entries.prefix = analyze` 语义过载

**位置**：Step 0.2 "`log_entries:` 上报" / design-doc §3.1。

**问题**：`analyze` 前缀按 `docs/log.md` 前缀规范专指 analyst 产出的研究报告 / `docs/analyze/*.md` 条目。FAQ sink 挂 `analyze` prefix 导致：
- `log.md` 扫描 `analyze` 前缀的读者会误以为存在 analyst session
- slug `faq-sink` 与 analyst slug 共用命名空间，未来 analyst 也做 FAQ 研究时碰撞

**建议**：二选一：
- (a) 新增前缀 `faq-sink` 到 `docs/log.md` §前缀规范 白名单
- (b) 复用 `decide` 前缀（orchestrator 自身动作，贴近"决策 / 元操作"语义，虽也过载但好于 analyze）

推荐 (a)；workflow.md Step 8 YAML 契约列表里也要加。**当前实现未动 log.md §前缀规范**，会触发 lint 告警（若 lint 扫 prefix enum）。

### F5 [Medium]：用户命令识别的中英 / 大小写 / 部分匹配

**位置**：Step 0.2 "用户显式 `加入 FAQ` / `沉淀到 FAQ` / `add to FAQ`" / `别沉淀` / `skip FAQ` / `don't FAQ`。

**问题**：
- `add` 单字（如 "add that to the doc"）是否触发？现规则字面匹配 `add to FAQ` 短语应不触发，但 orchestrator LLM fuzzy 可能激进
- 大小写（`Skip FAQ` / `SKIP FAQ`）未明示不敏感
- 中英混排（`加入 faq`、`add 到 FAQ`、`沉淀一下 faq`）边界模糊
- 反例："不要总是加入 FAQ" —— 同时含 `加入 FAQ` 和 `不要`，冲突时取哪个？

**建议**：明文 "大小写不敏感；两类命令共存时 skip 优先（conservative safer default）；fuzzy 判断但不过激，短语级而非单词级匹配"。

### F6 [Medium]：白名单关键词覆盖漂移

**位置**：Step 0.2 "提问关键词命中" 列表。

**问题**：列出 9 个英文术语 + 5 个中文词。边界 case：
- `stage` / `阶段` 命中"阶段"一词，但"我这个阶段要做什么"（询问自己业务的阶段）会误触发
- `DEC-xxx` 命中，但 "DEC-013 的 option schema 怎么写" 与 "请帮我决定 X" 都含 "决"字语义不等
- 未列：`dispatch` / `Task` / `Monitor` / `subagent` / `Resource Access`（实际列了）/ `lint_cmd` / `test_cmd` / `docs_root` / `target_project` / `slug` / `exec-plan` / `artifact`
- 中文"机制"太宽，"降低延迟的机制是什么"（业务问题）会误触

**风险**：假阳（业务问题被沉淀污染 FAQ）+ 假阴（plugin 术语未在列表漏沉淀）。

**建议**：规则改"白名单启发式 + LLM 语义判断兜底"，显式说"上下文是 roundtable plugin 机制 / workflow orchestration / DEC / Phase Matrix / agent-skill 架构 等，**target 项目业务语义不算**"；keyword 列表仅作 hint 非硬判。

### F7 [Low]：`{docs_root}` 跨项目一致性

**位置**：Step 0.2 路径引用 `{docs_root}/faq.md`。

**问题**：target 项目 docs_root 可能是 `documentation/` 而非 `docs/`。Step 0 Context Detection 已归一化到 `{docs_root}` 变量，但 design-doc §3.3 落点清单写死 `docs/faq.md`，跨项目 dogfood 时矛盾。

**建议**：design-doc §3.3 改 `{docs_root}/faq.md`。

### F8 [Low]：去重 ref 锚点格式不稳

**位置**：Step 0.2 "回复末尾标注" —— `📚 已有相关条目见 {docs_root}/faq.md § Q: <锚点>`。

**问题**：Markdown 标题锚点是 GFM slug 算法（`Q: 什么是 orchestrator` → `q-什么是-orchestrator`）；但标注里写 `§ Q: <锚点>` 是人读格式。TG 前端点击 `docs/faq.md#q-xxx` 才能跳。

**风险**：协议现状只够人读，程序/TG 跳不过去。

**建议**：可选改进 —— 标注附 markdown link `[Q: <title>](./faq.md#<gfm-slug>)`。非阻断。

### F9 [Low]：并发写 faq.md 的 race

**位置**：Step 7 / Step 8 已处理 INDEX / log.md 的并发（orchestrator 代写），faq.md 同样是 orchestrator 唯一写入者故无 race。但**两轮不同 session** 并发修改（用户多个 Claude Code 实例）可能冲突。

**建议**：不是本轮 scope，但 design-doc §4 "影响范围" 可加一句"多 session 并发 dogfood 靠 git 冲突解决，本协议不加锁"。

### F10 [Low]：📚 emoji 在 TG markdownv2 未转义

**位置**：Step 0.2 "回复末尾标注" —— `📚 已追加到 ...`。

**问题**：TG forwarding（Step 5b 事件类 a-e）已定义格式，**但 FAQ sink 标注不在 5 类转发清单**内。故 active channel 下 FAQ 标注是否同步到 TG 未规定。

**建议**：在 Step 5b 表格加第 6 行 "FAQ sink 标注 → `markdownv2` 单行"，或明确"不转发"（design-doc §4 可加注脚）。

### F11 [Low]：软上限 / 大小控制

**问题**：`docs/faq.md` 无条目数 / 文件大小上限。dogfood 数月后 faq.md 膨胀到几百 KB，新 session 加载成本 + orchestrator 每次 Read dedupe 成本线性增长。

**建议**：非本轮阻断；可加 follow-up "达到 100 条时分 faq-archive.md 按 DEC-xxx / 年月归档"。

## 3. 对抗性测试场景（人工执行）

以下测试项靠 dogfood session 跑，记录期望 vs 实际。

### 3.1 触发路径

- [ ] **P1** 裸问 "orchestrator 是什么？" → 期望：回答 + sink + 📚 标注
- [ ] **P1** 裸问 "我这段 Rust 代码 bug 在哪" → 期望：回答 + **不** sink
- [ ] **P1** 裸问 "auto_mode 怎么用？" → 期望：sink（白名单命中 `auto_mode`）
- [ ] **P1** 用户说 `加入 FAQ: 我今天心情如何` → 期望：强制 sink（命令覆盖）or orchestrator 拒绝（非机制类强制沉淀的边界，现规则未定义拒绝条件，可能被误用）
- [ ] **P1** 用户说 `skip FAQ` 后紧接问 "DEC-013 是什么" → 期望：回答 + **不** sink
- [ ] **P2** A 类 producer-pause 菜单激活中，裸问（非 `问:` 前缀）"phase matrix 状态是什么" → **F3 消歧待定**；测试观察实际 orchestrator 走哪条路
- [ ] **P2** 用 `问:` 前缀问 "roundtable 机制" → 期望：走 DEC-006 §A menu 循环 + analyst slug 级 FAQ（**不**走 Step 0.2）

### 3.2 去重路径

- [ ] **P1** 首轮问 "orchestrator 是什么" sink 后，次轮问 "orchestrator 啥意思" → 期望：命中 70% 去重 → 不追加 + 回复指向已有 § 锚点（**F1 未定义阈值算法**，可能判重也可能判新增）
- [ ] **P2** 问 "DEC-013 是什么" 首轮 sink 后，问 "decision mode 是什么" → 期望：不命中（中英不同词）但实际语义重复（**F1 风险**）
- [ ] **P3** 同一轮 session 内两次问同一问题 → orchestrator 应记忆 session 态而非只靠 faq.md Read 判重

### 3.3 边界 / 误判

- [ ] **P2** 裸问 "我项目中的阶段怎么规划" → 期望：**不** sink（业务语义非 plugin `阶段`；**F6 风险**，实际可能误触）
- [ ] **P2** 裸问 "降低延迟的机制有哪些" → 同上（业务 "机制" 不应触发）
- [ ] **P2** 裸问 "add this feature to FAQ" → 期望：**不** 触发强制 sink（非命令而是功能讨论；**F5 风险**）
- [ ] **P3** 用户说 "加入 FAQ 但别沉淀" → 冲突命令，期望：skip 优先（**F5 未定义**）

### 3.4 创建路径

- [ ] **P1** 首次 session `docs/faq.md` 不存在 → orchestrator 创建 minimal header → header 中 `<project>` 实际填成什么？（**F2 未定义**）
- [ ] **P1** `{docs_root}` = `documentation/` 的 target 项目 → faq.md 创建在 `documentation/faq.md` 而非 `docs/faq.md`（**F7 design-doc §3.3 需修**）

### 3.5 Bugfix session 继承

- [ ] **P2** `/roundtable:bugfix <issue>` 期间裸问 "critical_modules 怎么判" → 期望：走 Step 0.2（bugfix.md Step -1 已 ref workflow Step 0.2）

### 3.6 log_entries 正确性

- [ ] **P1** FAQ sink 后 orchestrator 执行 Step 8 flush，log.md 追加 `## analyze | faq-sink | YYYY-MM-DD` 条目（**F4 语义过载**：若未来前缀规范严格 enum 校验，analyze + slug=faq-sink 合法但语义歧义）
- [ ] **P2** 同 session 多次 sink 合并为一条 `log_entries`（`files: union` / `note: append`）还是分多条？Step 8 "合并规则" 讲同 agent 同轮合并 —— orchestrator 自己多次触发 FAQ sink 是否算同轮？

### 3.7 Critical modules lint

- [x] lint_cmd `grep -rnE "gleanforge|dex-sui|..."` 扫描 `commands/workflow.md` Step 0.2 新增段 —— **0 命中**（手工检查确认：示例串 `我这个 phase 要跑什么` / `加入 FAQ` 等皆不在禁词表）
- [x] lint_cmd 扫描 `commands/bugfix.md` +1 行 ref —— 0 命中
- [x] lint_cmd 扫描 `docs/design-docs/faq-sink-protocol.md` / `docs/faq.md` —— 0 命中

## 4. Benchmark

不适用（纯 prompt 协议，无性能 hot path；每次 sink 成本 = 1 Read faq.md + 1 Edit，延迟 ~1s 已在 design-doc §4 声明）。

## 5. 反馈 developer / orchestrator 优先级列表

| # | Severity | Finding | 是否阻断合并 |
|---|---------|---------|------------|
| F1 | High | 70% 词重叠算法未指定 | **是**（易行为漂移） |
| F2 | High | `<project>` 填充规则未定义 | **是**（首次创建即暴露） |
| F3 | Medium | A 类 menu 裸问 vs Step 0.2 边界 | 可合并但建议同轮澄清 |
| F4 | Medium | `log_entries.prefix=analyze` 语义过载 | 可合并；follow-up 加 `faq-sink` 到前缀规范 |
| F5 | Medium | 用户命令中英 / 大小写 / 冲突 | 可合并；加一句规则 |
| F6 | Medium | 白名单关键词误触（业务 "机制" / "阶段"） | 可合并；加 "plugin 上下文" 限定语 |
| F7 | Low | design-doc §3.3 写死 `docs/faq.md` | 小修 |
| F8 | Low | 去重 ref 锚点 markdown link 化 | 非阻断 |
| F9 | Low | 多 session 并发写 race | 非阻断 |
| F10 | Low | FAQ 标注是否转发 TG 未规 | 非阻断，归 follow-up |
| F11 | Low | faq.md 膨胀归档策略 | 非阻断 |

## 6. 变更记录

- 2026-04-21 初版对抗审查（tester subagent；F1-F11 11 finding；2 High / 4 Medium / 5 Low；建议 F1+F2 合并前修复，其余可 follow-up）
