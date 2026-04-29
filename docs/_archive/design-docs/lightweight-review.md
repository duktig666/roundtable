---
slug: lightweight-review
source: analyze/lightweight-review.md
created: 2026-04-19
status: Draft
decisions: [DEC-009]
description: issue #9 轻量化重构 —— 4 helper 抽取 + log.md closeout 批处理 + README/CLAUDE.md 瘦身；预估省 ~600 行（22-25%）
---

# roundtable 轻量化重构 设计文档

> slug: `lightweight-review` | 状态: Draft | 参考: [analyze/lightweight-review.md](../analyze/lightweight-review.md) / [issue #9](https://github.com/duktig666/roundtable/issues/9)

## 1. 背景与目标（含非目标）

### 目标

- **A. Prompt 瘦身 20-25%**：抽取 4 个共享 helper（DEC-009 §2.1），回填 5 agent / 2 skill / 2 command。
- **B. log.md closeout 批处理**：agent prompt 去除 append 模板（~180 行省），orchestrator 在 Stage 9 / producer-pause 转场做 flush。
- **C+D. README/CLAUDE.md 结构重塑**：§设计思想合并到 §设计原则；CLAUDE.md § 设计参考 + 5 URL 删；README §致谢/§贡献/§许可证 删。

### 非目标

- 不改 DEC-001 D1-D9 / DEC-002 / DEC-003 Accepted 条款
- 不变 DEC-004 progress event JSON schema、不扩 event 枚举
- 不破坏 `lint_cmd` 硬编码扫描 0 命中
- 功能前后等价：不删任何 role / command / escalation / progress 行为

## 2. 技术实现

### 2.1 4 个新 shared helper（命名遵循 `_` 前缀 plugin 内部 include-only 约定）

| Helper 路径 | 抽自 | 保留在原文件的内容 |
|---|---|---|
| `skills/_resource-access.md` | 5 agent + 2 skill 的 `## Resource Access` 表头 + 末尾"除非…授权否则禁用 git"段 | **role-specific rows**（每个角色 Read / Write / Report / Forbidden 具体值）继续写在 agent/skill 本体 |
| `skills/_escalation-protocol.md` | 4 agent 的 `## Escalation Protocol` 引言 + JSON schema body + 3 条通用规则 + "Escalation vs Abort"段 | **typical triggers**（developer 的"设计未覆盖分叉"/tester 的"bug-found"/reviewer 的"Critical borderline"/dba 的"migration 策略分叉"）继续写在 agent 本体 |
| `skills/_progress-reporting.md` | 5 agent 的 `## Progress Reporting` 注入变量段 + emit 模板（3 种 event） + Granularity + Fallback + "与 Escalation 正交" + Content Policy ref | **role-specific phase tag 表**（developer 用 P0.n / tester 用 scope-review / reviewer 用 analyzing / dba 用 schema-read / research 不 emit）+ **Ordering discipline**（tester 的 bug-found 先 emit / reviewer 的 Critical 先 emit）继续写在 agent 本体 + **Content Policy 示例**（每角色 1-2 条合规样例）继续写在 agent 本体 |
| `commands/_progress-monitor-setup.md` | `commands/workflow.md` Step 3.5.2 Bash 准备 + Step 3.5.3 Monitor jq pipeline + Step 3.5.4 4 变量注入表 + Step 3.5.5 生命周期 + Step 3.5.6 并行安全性 | workflow.md 保留：§3.5.0 前台/后台 gate（DEC-008）+ §3.5.1 env opt-out + 一行 "详见 `commands/_progress-monitor-setup.md`" ref |

**引用模式**：沿用 `_detect-project-context.md` / `_progress-content-policy.md` 既定范式 —— **调用方 `Read` 后 inline 执行**（不使用 Claude Code `Skill` 工具激活）。不发明新机制。

### 2.2 log.md closeout 批处理协议

#### 2.2.1 agent 侧契约（5 个角色同步变）

**前**：每 agent 结尾"完成后"段含 6-7 行 Markdown append 模板（`## [前缀] | [slug] | [日期]` ...）；agent 用 Edit 工具直接 append 到 `docs/log.md` 顶部。

**后**：agent **不直接写 log.md**。Final message（或 skill in-session final output）在 `created:` section 同级新增 `log_entries:` section：

```
log_entries:
  - prefix: analyze | design | decide | exec-plan | review | test-plan | lint | fix
    slug: [slug]
    files: [docs/analyze/[slug].md, ...]
    note: [一句话]
```

orchestrator 按相同 merge 原则（同一 agent 同一轮多产出合并为一条）聚合并在 flush 时间写入。

#### 2.2.2 orchestrator 侧 flush 协议（workflow.md + bugfix.md 补丁）

**新增 Step 8: log.md Batching**（与 Step 7 Index Maintenance 同源，shared-resource 转发模式）。

Flush 触发点：
1. **Stage 9 Closeout**（A 类 producer-pause）之前 —— **终点 flush**；覆盖 Stage 1-8 累积的 log_entries。
2. **每次 A 类 producer-pause 转场之前**（analyst ✅ / architect ✅ / Stage 9）—— **best-effort pause-point flush**；降低跨 session 中断时的未落盘回归（若用户此时 ctrl+C 退出，至少已完成阶段的 log 已落）。
3. **每次 C 类 verification-chain 交接之前** —— 沿用 Step 7 "过桥条款"同规则，orchestrator 在发出 "🔄 X 完成 → dispatching Y" 前先 flush 本 phase 累积的 log_entries。

Flush 实现（单次 Read + Edit）：
1. **Collect**：agent final message 的 `log_entries:` YAML block → orchestrator 解析到内存 queue
2. **Merge**：同一轮（自上次 flush 以来）同 agent 的多 entry 合并成一条，`files:` union
3. **Edit**：`Read` `{docs_root}/log.md` 头部前缀规范后的 `---` 分隔符；在第一个 `---` 和 `## 前缀规范` 之间按倒序 append 合并条目（新最上，沿用现有铁律）

#### 2.2.3 跨 session abort 语义的退化声明

本设计**接受**：用户在某 A 类 producer-pause 之间直接退出 Claude Code（未说"停"、未进入下一轮 prompt）→ 未落盘的 log_entries 永久丢失。缓解机制：pause-point flush 在每个 A 类边界清空 queue，所以实际丢失窗口仅限于"最近一段未 pause 的 C 类链"（通常只有 developer→tester→reviewer 那段）。

### 2.3 README / CLAUDE.md 结构重塑

#### 2.3.1 README.md

**§设计原则**（现有 5 条）扩至 **7 条**，融入 issue #9 §D 的 5 点 a-e（去重）：

1. 零配置安装 *(不变)*
2. **自动组织流程 + 文档化每阶段 I/O** *(合并 issue a + b + 原"plan-then-execute"部分表述)*
3. 决策逐点弹窗 *(不变)*
4. 交互式 role 用 skill，自主执行 role 用 agent *(不变；已覆盖 issue d)*
5. **关键决策落 decision-log / 文档变更入 log.md / 索引入 INDEX.md（参考 llm-wiki 分层）** *(新增；issue c)*
6. **Analyst 借鉴 gstack 六问检验**（原"致谢"中语义，上升为设计原则）*(新增；issue e)*
7. 多项目原生支持 *(现 #5 顺延)*

**移除**的章节：
- `## 致谢` —— 语义迁入 §设计原则 #5 #6
- `## 贡献` —— CONTRIBUTING.md 独立，README 不需再述
- `## 许可证` —— LICENSE 文件即可，README 不需再述
- **不新增** `## 对标参考` / `## 设计思想` 独立章节

#### 2.3.2 CLAUDE.md 的 `## 设计参考`

**全删**（5 URL + 引言）。用户决策：对标信息 lineage 价值低于每次 workflow 加载 CLAUDE.md 的 token 成本；已在 `docs/design-docs/roundtable.md` D1-D9 评分表存档，决策层面够用。

### 2.4 critical_modules 扩写

`CLAUDE.md ## critical_modules` 第 1 条"Skill / agent / command prompt 文件本体"扩写：

> Skill / agent / command prompt 文件本体 **含 `skills/_*.md` 与 `commands/_*.md` 共享 helper**：任何 bug 会传播到所有下游 `/roundtable:workflow` 调用

`docs/claude-md-template.md` 同步。

## 3. 关键决策与权衡

### 3.1 决策：helper 抽取粒度 = Aggressive 3 + workflow Step 3.5 helper

| 维度 (0-10) | Aggressive 3+1 ★ | Moderate 2 | Conservative 1 | Skip |
|---|---|---|---|---|
| issue 目标达成 | **9** | 6 | 3 | 1 |
| 未来维护成本 | **8**（改规则一处生效） | 6 | 4 | 4 |
| 集成风险 | 6（4 helper 同时落） | **7** | **8** | **10** |
| 新贡献者首读门槛 | 5（要追 4 层 include） | **7** | **8** | **9** |
| critical_modules fan-out 面积 | 5（+4 新文件纳入） | 6 | **7** | **9** |
| **合计** | **33** | 32 | 30 | 33 |

Aggressive 与 Skip 并列最高分，但 Skip 完全不达 issue 目标，所以**选 Aggressive**。新贡献者门槛用 `docs/INDEX.md` 中 `skills/` helper 清单显式列出（决策 3.4）缓解。

### 3.2 决策：log.md 改 Full closeout batching（含 pause-point flush）

Tradeoff 接受：跨 session 中断时未落盘窗口（仅限最后一段未 pause 的 C 类链，通常 3 个 agent ≈ dev→tester→reviewer）。

理由：
- agent prompt 净省 ~180 行，与 helper 抽取协同达成 issue §A 目标
- 与 Step 7 INDEX.md batching 同构（orchestrator 统筹 shared resource），心智统一
- pause-point flush 覆盖 97%+ 常见场景（每个 A 类 pause 自然清空 queue）

### 3.3 决策：README 结构 = §设计思想合并到 §设计原则；删致谢/贡献/许可证

用户决策（非 analyst recommend）：
- 拒绝 README 新增 §对标参考 独立章节
- 拒绝 CLAUDE.md 保留 5 URL（比 issue #9 §C 原方案更激进 —— issue 说"迁到 README"，用户说"删"）
- 移除 README §致谢 + §贡献 + §许可证 —— 依赖 LICENSE / CONTRIBUTING.md 各自文件存在

### 3.4 决策：5 个新 helper 全部纳入 critical_modules

Helper 改动 fan-out 到 5 agent，比单 agent prompt 改动更 critical；tester/reviewer 走完整工作流的开销可接受（每次 helper 改动频率远低于 agent 本体）。

## 4. 技术实现细节

### 4.1 helper 文件骨架

每个 `_*.md` 顶部用标准 frontmatter + 1-2 句 description + 使用契约：

```markdown
---
name: _escalation-protocol
description: Shared Escalation Protocol JSON schema + rules for subagent → orchestrator decision relay. Plugin-internal include-only; referenced by developer/tester/reviewer/dba agents.
---

# Escalation Protocol（shared helper）

> **引用方式**：调用方 agent 在 `## Escalation Protocol` section 以 "详见 `skills/_escalation-protocol.md`，本角色典型触发点..." 格式引用。不使用 Claude Code `Skill` 工具激活。

<现有 JSON schema body + 规则 + Escalation vs Abort 段抽过来>
```

### 4.2 agent 本体改写样板（以 developer.md 为例）

现状 `## Escalation Protocol` 段（~40 行）改为：

```markdown
## Escalation Protocol

详见 `skills/_escalation-protocol.md`（JSON schema + 通用规则）。

**Developer 专属典型触发点**：
- 设计文档未覆盖具体实现分叉
- 实现过程发现契约不符 / 设计漂移
- 需要新依赖（exec-plan 未声明）
- 重叠的 exec-plan 任务 scope 模糊
```

净省 35 行/文件 × 4 agent = 140 行。Resource Access / Progress Reporting 同模式。

### 4.3 workflow.md Step 3.5 改写

`commands/workflow.md` Step 3.5 整段（~120 行）压到：

```markdown
## Step 3.5: Progress Monitor Setup（DEC-004；触发规则 DEC-008 修订）

### 3.5.0 前台 / 后台派发 gate（DEC-008）

<保留完整 gate 内容 ~30 行>

### 3.5.1 Opt-out check

<保留 env var 检查 ~5 行>

### 3.5.2 执行

满足 gate 且 env 未 opt-out → `Read` `commands/_progress-monitor-setup.md` 并按其中 §Bash-preparation / §Monitor-launch / §Variable-injection / §Lifecycle / §Parallel-safety 5 节依序执行。
```

净省 ~85 行。

## 5. DEC 审计（user 扩展 scope）

按用户要求"DEC 的也需要审查，全面瘦身 DEC 的部分设计可能也有问题"，对 DEC-001 ~ DEC-008 做**设计问题**（非 prompt 层重复）审查。审查结论：

### 5.1 确认的 DEC 层问题

| 问题 | DEC | 严重度 | 归因 | 处置 |
|---|---|---|---|---|
| **"prompt 文件本体统一英文" 决定被 silently overridden** —— 2026-04-19 改回"中文为主"通过 feedback 约定（见 `feedback_roundtable_prompt_language`），决策日志无 Superseded 条目 | DEC-002 决定 5 | 🔴 Critical（违反 decision-log 铁律 #2 "冲突报 diff"） | 反转决策走了 memory feedback 而非 decision-log | **DEC-009 决定 8**：正式 Superseded DEC-002 决定 5；DEC-002 状态行追加标注 |
| **bugfix.md 规则 2 非对称** —— 仅 honor `developer_form_default: subagent`，`inline` 声明落空进入 AskUserQuestion（已在 `docs/testing/...` case 3.6 WARN + `docs/reviews/2026-04-19-...-subagent-progress-...` 记录但未修复） | DEC-005 落地 | 🟡 Warning（DEC 本身设计对称，实施 bug） | Review follow-through 遗漏 | **DEC-009 决定 9**：修 `commands/bugfix.md` 规则 2 为对称 honor（`inline` 或 `subagent` 均生效） |
| **DEC 影响范围段行数递增**（DEC-001: 1 行 → DEC-008: 20+ 行详细文件清单）—— architect 每轮都要读 decision-log，长"影响范围"增加上下文消费 | 累积习惯 | 🔵 Suggestion（可演化的规范，不紧急） | 没有明确的 DEC metadata 长度预算 | **DEC-009 决定 10**：新增 DEC 纪律 —— 影响范围段 ≤10 行；超出部分 extraction 到 `design-docs/[slug].md ## 影响文件清单` 段外链 |

### 5.2 审阅过但未判定为问题的 DEC

| DEC | 审视点 | 结论 |
|---|---|---|
| **DEC-001 D8 role→form 单射** | 被 DEC-003（research 正交）+ DEC-005（developer 双形态正交）两次补强 —— 初始设计是否过强？ | **非问题**。正交补强比 Superseded 更稳健；D8 作为 baseline 仍准确。不动 |
| **DEC-003 research.md 226 行** | 使用频次低（architect 决策 3+ 候选时才派发） | **非过度**。Abort Criteria + Return Schema + null recommend 硬纪律是必要契约；DEC-009 P0.2 按同模式抽 Resource Access / escalation 后 research.md 预估降至 ~180 行 |
| **DEC-005 三级触发器** | per-session / per-project / per-dispatch 三级是否复杂？ | **非过度**。grep 证实 per-project `developer_form_default` 实测有用且被测试覆盖；唯一问题是 bugfix.md 实施 bug（见 5.1 行 2），不是设计复杂 |
| **DEC-006 Step 6 规则 1（~60 行）** | 三类 + 7 条映射 + rationale 是否冗长？ | **非过度**。rationale 已外链到 `design-docs/phase-transition-rhythm.md`，Step 6 本体只含必要约束。DEC-009 P0.3 不改 Step 6 |
| **DEC-007 §1 "≥50% 新 context" gate** | LLM 不感知自身 context 大小，自查难度高 | **可容忍**。该条件是 3 OR 之一（文件写 OR 子里程碑 OR ≥50% context），两条客观条件覆盖 90%+ 场景；最后一条兜底不严格达成也不破坏整体规则。不改 |
| **DEC-008 §3.5.0 gate 30 行** | 是否 verbose？ | **必要**。前台/后台判定、混合批例外、fallback 静默 skip —— 每点都必要；压缩会产生歧义 |

### 5.3 DEC-009 scope 扩展

基于 5.1 发现，DEC-009 "决定" 段新增 3 条（见 `decision-log.md` DEC-009 决定 8-10）；exec-plan 新增 **P0.7 DEC 修正**。

## 6. 讨论 FAQ

（待用户/reviewer 追问补充）

## 7. 待确认项

- [ ] `commands/bugfix.md` 是否也需同步 log batching 改造？（bugfix 只有 developer→reviewer 两阶段，flush 点更少；需实现期确认）
- [ ] `skills/_resource-access.md` 是否应附一个"典型 rows 模板"示例，让新 agent 贡献者复制改写？
- [ ] 老的 DEC-002/004/007 的 "影响范围" 段是否需补丁"部分内容已迁至 helper"的 note？决策倾向 **否** —— DEC 是决策记录不是索引，helper 位置由 design-doc 维护即可。
- [ ] DEC-009 决定 10 的"新增 DEC 影响范围 ≤10 行" 纪律是否回溯要求现有 DEC-001~DEC-008 改写？决策倾向 **否** —— append-only 纪律优先；新纪律只约束 DEC-010+。

## 8. 变更记录

- 2026-04-19 创建（issue #9 / DEC-009 Proposed）
- 2026-04-19 user 扩展 scope 加入 DEC 审计 → 新增 §5 + DEC-009 决定 8/9/10 + exec-plan P0.7
- 2026-04-19 tester+reviewer 终审 W-01 修复：design-doc §5/§7/§8 的 DEC-009 决定编号 7/8/9 → 8/9/10（与 decision-log 权威对齐）
- 2026-04-19 DEC-010 反转 DEC-009 决定 1（4 helper 抽取）—— 新增 §9 反转复盘 + §10 DEC-010 执行路线

## 9. DEC-010 反转复盘（2026-04-19 post-DEC-009 closeout）

### 9.1 DEC-009 决定 1 为什么被反转

DEC-009 Accepted 后 closeout 阶段用户反馈"越加越多"。复盘发现 analyst / architect 估算 token 节省时**只算单 agent 文件前后行数差**（-346 行），未算**每次 subagent 派发还要 Read N 个 helper**（+300 /派发）。

真实账（单次典型 `/roundtable:workflow` = orchestrator + 3 subagent）：
- **DEC-009 前** ~1540 行运行期负载
- **DEC-009 后** ~1800 行（反**增 17%**）
- tree 总行 2708 → 2791（+83）

issue #9 原始目标"Token 成本：每次会话加载长 prompt 耗 context"未达成，反向。

### 9.2 方向 B 为什么胜出

| 方向 | tree 省 | 单 workflow 负载省 | SSOT 维护性 | 决策 |
|------|--------|-----------------|-----------|------|
| A：保 helper + 双端精简（helper 447→200 + agent 更薄） | ~400 | ~350 | 保留 | 拒绝（收益只 B 的一半） |
| **B：删 helper + 激进 inline 精简**（本 DEC-010） | **~900（32%）** | **~700（39%）** | 4 模式重复落多处 | **采纳** |
| C：只维护性修正不瘦身（接受 +83 重启讨论） | 0 | 0 | 保留 | 拒绝（用户明确否决） |

用户 north star 是 **token 成本**不是 SSOT；4 重复模式（Resource Access / Escalation JSON / Progress emit / Monitor setup）本质稳定（近半年只有 DEC-007 / DEC-008 触及），漂移风险可接受。`lint_cmd` 可扩展扫描检测模式漂移作 SSOT 损失的兜底。

### 9.3 DEC-009 仍保留的 9 条收益

DEC-010 仅 supersede 决定 1；DEC-009 其余全部保留：log.md closeout batching（#2）/ README 合并（#3）/ CLAUDE.md 删 §设计参考（#4）/ critical_modules 扩写（#5，helper 清单从 4 个减到 2 个）/ 既定 `_` 前缀范式（#6）/ DEC-002 #5 Superseded（#8）/ bugfix.md 规则 2 对称修（#9）/ 新 DEC 影响范围 ≤10 行纪律（#10）。

## 10. DEC-010 执行路线

见 `docs/exec-plans/active/lightweight-review-revert-plan.md`（P1.1 删 4 helper → P1.2 重新 inline 5 agent → P1.3 inline 2 skill → P1.4 精简 2 command → P1.5 CLAUDE.md / INDEX.md / template / design-docs 同步）。

**保留的 role-specific 纪律**（即便激进精简也必须保留）：
- developer Execution Form（DEC-005 dual-form）
- tester bug-found Ordering discipline
- reviewer Critical-finding Ordering discipline
- dba 审查重点 4 类（Schema / SQL / Migration / Index）
- research Abort Criteria + Return Schema（`recommend_for: null` 硬导）
- architect Research Fan-out（DEC-003，≤4 扇出 + 同 assistant message 并行）
- analyst 追问框架必答 2 + 按需 4；AskUserQuestion **无 `recommended`** 字段

**验收**：lint_cmd 0 命中；tree 总行 2791 → ~1900；role-specific 纪律逐项人工复查保留。
