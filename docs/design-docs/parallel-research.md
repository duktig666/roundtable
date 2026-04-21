---
slug: parallel-research
source: analyze/parallel-research.md
created: 2026-04-19
status: Accepted
decisions: [DEC-003]
---

# Parallel Research Subagent Dispatch 设计文档

> slug: `parallel-research` | 状态: Accepted | 参考: [issue #2](https://github.com/duktig666/roundtable/issues/2) · [analyze/parallel-research.md](../analyze/parallel-research.md) · [DEC-001 D8](../decision-log.md) · [DEC-002](../decision-log.md) · [DEC-003](../decision-log.md)

## 1. 背景与目标（含非目标）

### 背景

gleanforge P4 自消耗（2026-04-18）§3 friction #8：architect skill 在架构决策需要评估 3+ 备选方案时，只能串行 `WebFetch`，导致：

- **速度**：3 候选 × 每个 1 次 fetch = 至少 3 次串行网络往返；实际决策常需要每候选多次 fetch
- **Context 污染**：所有 fetch 结果累积到主会话 context，长决策消耗大量 token
- **广度 truncation**：architect 为节省 token 可能主动 truncate 研究，导致决策基于不完整信息

DEC-002 识别此为 top 3 改进之一的延伸问题，明确标注 "架构级改动，放独立 DEC 追"（留 issue #2）。

### 目标

赋予 architect skill 以下能力：

- 在识别关键决策点后，若某决策有 2-4 个候选且每个需要非平凡外部研究，**并行**派发 research subagent
- 每个 research subagent 针对 ONE option 做事实层调研，返回结构化 JSON
- architect 合成 N 个 JSON，映射到单次 `AskUserQuestion` 的 option 字段
- 失败任一 → partial success，不阻塞决策

### 非目标

- **不替代 analyst skill**：analyst 仍是用户触发的独立调研角色，做整体领域分析；research 是 architect 内部子任务，做单 option 深挖
- **不做跨 option 综合**：综合 / 对比是 architect 合成时做，research worker 不越界
- **不改 user-facing workflow**：用户仍通过 `/roundtable:workflow` 或 architect skill 直接激活；research 对用户透明
- **不影响 DEC-001 D8 role→form 映射**：D8 保持冻结，DEC-003 正交补充 skill → Task 能力

## 2. 业务逻辑（核心流程）

```
architect skill (main session)
│
├── 阶段 1.1  识别决策点 D（有 N 个候选 opt_1..opt_N, 2 ≤ N ≤ 4）
│
├── 阶段 1.2  判断是否需要 fan-out
│            ├── 每候选需要 ≥ 1 次非平凡外部 research → YES, dispatch
│            └── 候选都在 architect 已有 context 内可决 → NO, 直接阶段 1.3
│
├── 阶段 1.3  Fan-out (one message, N parallel Task calls)
│            │
│            ├── Task(research, {option_label: opt_1, scope: s_1, ...})
│            ├── Task(research, {option_label: opt_2, scope: s_2, ...})
│            ├── ...
│            └── Task(research, {option_label: opt_N, scope: s_N, ...})
│
├── 阶段 1.4  接收 N 个返回（各 <research-result> JSON 或 <research-abort>）
│            │
│            ├── 全部 success → 阶段 1.5
│            ├── K/N abort (scope too vague) → 修正 scope 重派这 K 个，最多 1 轮
│            │                                  (第二轮仍 abort 则进入 partial success)
│            └── K/N timeout / exception → partial success：失败 option 在弹窗里打 ☠️
│
├── 阶段 1.5  合成 → AskUserQuestion
│            │
│            对每个 opt_i:
│              option_i.label = opt_i.option_label
│              option_i.rationale = 合成自 opt_i.key_facts[] 前 2-3 条
│              option_i.tradeoff = 合成自 opt_i.tradeoffs[] 前 1-2 条
│              option_i.recommended = architect 自己判断（research 禁推荐）
│              option_i.unknowns (注释 / 或☠️) = 来自 opt_i.unknowns[]
│
└── 用户回答 → 继续阶段 1 下一个决策点或进入阶段 2
```

## 3. 技术实现

### 3.1 新 role：`agents/research.md`

- **name**: `research`
- **description**: 标明"architect-dispatched only, NOT user-triggered"避免 auto-delegation 冲突
- **tools**: `Read, Grep, Glob, WebFetch, WebSearch`（禁 Bash / Write / Edit / git）
- **model**: 继承主会话模型（2026-04-21 更新：原 pin `sonnet` 已移除，改由用户通过 `/model` 或 `settings.json` 统一控制；初衷"事实聚合成本优先"仍成立，用户自行取舍）

### 3.2 上下文注入约定

architect 在 `Task` 派发 prompt 里必须包含：

```
Required injected variables:
- target_project      : absolute path
- docs_root           : relative path
- option_label        : exact option name (e.g., "SQLite (better-sqlite3)")
- scope               : specific question (e.g., "Safe for concurrent reads with WAL? Upper row-count limit?")
- related_facts       : facts already known (from analyst report or session memory)
- critical_modules    : from CLAUDE.md (as scope constraint)
- design_ref          : from CLAUDE.md (as scope ceiling)
```

### 3.3 返回 schema：`<research-result>` JSON block

```json
{
  "option_label": "<echo of injected option_label>",
  "scope": "<echo of injected scope>",
  "key_facts": [
    { "fact": "<one-sentence factual statement>", "source": "<URL | file:line | training-data-estimate>" }
  ],
  "tradeoffs": [
    "<objective cost / risk, one line>"
  ],
  "unknowns": [
    "<what could not be verified and why>"
  ],
  "recommend_for": null
}
```

- `recommend_for` **硬导为 null** —— research 绝不推荐
- `source` 字段不可空；`training-data-estimate` 标记必须伴随 `unknowns[]` 同步备注

### 3.4 Abort 机制

替代 `<escalation>` JSON；scope 决策属 architect，不路由给用户。格式：

```json
{
  "option_label": "<...>",
  "reason": "scope-vague | scope-too-broad | context-missing | sources-unreachable",
  "detail": "<what specifically>",
  "suggested_narrower_scope": "<re-dispatch prompt or null>"
}
```

architect 收到 abort 后：
- 若 `suggested_narrower_scope` 非 null → 修正 scope 一次重派（最多 1 轮）
- 若 null 或重派仍 abort → 该 option 从弹窗 option 列表移除（或保留并标 ☠️ "调研失败"）

### 3.5 Architect skill 侧改动（见 `skills/architect.md` §阶段 1.5）

新增 `#### 3.5 Research Fan-out（可选）`：

- 触发条件（2 ≤ N ≤ 4；每候选需外部 research）
- 派发规则（one message 多 Task calls；required injection fields）
- 合成规则（key_facts → rationale；tradeoffs → tradeoff；architect 自定 recommended）
- 失败处理（重派 1 轮 → partial success → ☠️ 标记）

### 3.6 并行安全（映射 workflow.md §4 四条）

| 条件 | research 默认满足状态 |
|------|---------------------|
| PREREQ MET | architect 在决策点识别后派发，前置完成 |
| PATH DISJOINT | research 不写任何文件 → 天然满足 |
| SUCCESS-SIGNAL INDEPENDENT | 每个 `<research-result>` 独立有效 |
| RESOURCE SAFE | ≤ 4 扇出硬上限 + 短生命周期 → token 预算可控 |

## 4. 关键决策与权衡

7 条决策的量化对比（不打分，只列代价 / 收益维度）。DEC-003 条目承载完整"备选 / 理由"，这里给出执行层权衡。

### 4.1 Role 归属（新独立 agent vs dual-mode vs inline）

| 维度 | agents/research.md（选） | analyst dual-mode | architect inline |
|------|----------------------|-----------------|----------------|
| 新文件 | +1 | 0 | 0 |
| D8 单射兼容 | ✅ | ❌ 破坏 | ✅ |
| 独立 Resource Access 可审 | ✅ | ❌ 两档混合 | ❌ 无独立 |
| 未来扩展其他 research worker | 加文件 | 同 role 里分裂 | 模板复制到 architect 各处 |
| auto-delegation 歧义 | 低（明写 "not user-triggered"） | 高（同 role 两模式） | N/A（无独立 role） |

### 4.2 DEC-001 D8 处理（补充 vs 改写 vs Superseded）

补充（选）：D8 的 role→form 单射正确，新能力（skill → Task）是正交维度。DEC-003 记新规则，DEC-001 保持历史冻结（append-only 纪律）。

### 4.3 Tool set 宽度

5 工具（Read / Grep / Glob / WebFetch / WebSearch）选定。Bash 排除 —— 研究任务用不到 shell，引入 Bash 增加"读 shell 命令可被误用"风险面。

### 4.4 扇出上限 4

与 `AskUserQuestion` 的 `maxItems: 4` 对齐。5+ 候选通常说明 architect 决策粒度过粗；强制先做粗筛再 research。

### 4.5 返回 JSON 而非 prose

与 DEC-002 已确立的 agent→orchestrator JSON 范式（`<escalation>`）一致。N 个 prose 合成时 architect 要做 text parsing，易丢事实；JSON 字段直接映射 AskUserQuestion option。

### 4.6 Abort 而非 escalation

避免 "research → orchestrator → architect (skill on orchestrator)" 的 reentrant；scope 决策本属 architect，不经用户。abort 是 "派发方 prompt 不够好" 的强反馈信号。

### 4.7 Partial success

失败 option 标 ☠️ 带进弹窗。用户可选择排除或接受不完整信息决策 —— 用户拍板能力 > 完整性。strict all-or-nothing 会在上游持续故障时无限重派 → 卡住。

## 5. 讨论 FAQ

（尚无追问。真实使用中若发现 schema 不够表达，可用新 DEC 扩展 `<research-result>` 字段而不破坏兼容性）

## 6. 变更记录

- 2026-04-19 创建：7 条决策锁定（DEC-003）；对应 analyze/parallel-research.md 12 个事实层开放问题的 architect 收敛

## 7. 待确认项

- [ ] architect skill `tools:` frontmatter 显式化 —— 目前不声明（继承主会话工具），后续如需限制工具集，显式 `tools: Read, ..., Task`
- [ ] 实施 PR —— 新增 agents/research.md、skills/architect.md 改动、DEC-003 落地（本文档完成后单独 PR）
- [ ] 首次真实使用观察 —— 下次 architect 遇到 3+ 候选决策时验证流程、合成质量、失败处理
