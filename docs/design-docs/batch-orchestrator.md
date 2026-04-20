---
slug: batch-orchestrator
source: docs/analyze/batch-orchestrator.md + Claude Code 官方文档 + DEC-003 并行 research Q4/Q5/Q7
created: 2026-04-20
status: Draft
decisions: [DEC-016]
---

# Batch Orchestrator 设计文档（`/roundtable:batch`）

> issue #43 架构方案。基于 analyst 深度分析（9 维度 + 7 开放问题）+ 3 路并行 research 的事实层结果制定。**重大发现**：Claude Code 官方约束 "Subagents cannot spawn other subagents" 迫使本设计放弃"主会话派 batch subagent → 子 agent 跑完整 workflow"的初始架构，改为**设计阶段批量 + 实施阶段主会话**的分段模型。

## 1. 背景与目标（含非目标）

### 1.1 背景

`/roundtable:workflow` 当前绑定单 issue / 单会话。积压多个 P2/P3 dogfood issue 的场景（roundtable 自身递归 dogfood）交互成本线性放大。

**前置依赖**（已合入）：
- #33 DEC-015 auto mode（单链路非交互）
- #38 DEC-013 §3.1a `<decision-needed>` TG 转发
- 新开 #48（P1 phase summary / producer-pause 扩展 TG 转发，与本 issue 强耦合但独立实施）

**analyst 发现的核心约束**：

| 约束 | 来源 | 对设计的影响 |
|------|------|-------------|
| Subagents cannot spawn other subagents | Claude Code 官方文档 | 🔴 **颠覆性**：batch 子 agent 无法在内部调 Agent tool 派 developer/tester/reviewer/dba subagent |
| AskUserQuestion 在 bg subagent tool call fails but subagent continues | 官方文档 | 🟡 子 agent 强制 `decision_mode=text` |
| SendMessage 仅 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 可用 | 官方文档 | 🔴 不能用 SendMessage relay 用户决策回子 agent（非 experimental） |
| MCP tools 不自动继承 | 官方文档 | 🟡 子 agent 若需 TG reply 须显式 `mcpServers` 声明 |
| Opus Tier 3 concurrency=5 实测触发 429 | GitHub issue #44481 | 🟡 默认并发 ≤3 合理 |
| Subagents don't inherit skills | 官方文档 | 🟡 子 agent 若需 analyst/architect skill 须显式 `skills:` 字段列出 |

**核心发现 "subagents cannot spawn"** 意味着：batch 子 agent 跑 `/roundtable:workflow` 时，workflow 内部派发 `developer` / `tester` / `reviewer` / `dba` subagent 的步骤会**失败**。这是对 issue #43 原始架构提议（"每个子 agent 跑 `/roundtable:workflow <N> --auto`"）的**否决证据**。

### 1.2 目标（基于约束重新定义）

**v1 MVP**：`/roundtable:batch` **只做设计阶段**（analyst + architect 两个 skill，均 inline 形态）+ commit + push + 开 PR。

**v2 Future**：扩展到实施阶段（需先完成 tester/reviewer/dba 的 inline 形态 —— DEC-005 follow-up）或等 Claude Code 放宽嵌套约束 / agent teams 稳定。

**UX 流**：

```
用户在 TG 触发:
  /roundtable:batch #A #B #C

→ 主会话 fan-out 3 个 batch subagent (isolation:worktree, run_in_background:true)
  每个 subagent 跑 inline-only 设计 workflow:
    Step 0: context detection
    Step 2: analyst (skill inline)
    Step 3: architect (skill inline, 无 DEC-003 research fan-out — 约束兼容)
    Step 4: commit + push + open draft PR
    Step 5: final message 返回 PR URL

→ 主会话 fan-in:
  汇总 3 个 PR URL
  用户 TG 收到 3 条 PR 链接
  用户在 GitHub 按 PR 逐个 review 设计
  批准后用户在主会话跑 `/roundtable:workflow #A` 继续实施（developer/tester/reviewer）
  或 reject 后 TG 反馈，batch 子 agent 根据 feedback 重新设计（需第二轮 batch）
```

**为什么不是全阶段 batch**：参见 §4.2 D2 决策。

### 1.3 非目标

- **v1 不覆盖实施阶段**（developer/tester/reviewer/dba），见 D2
- **不做 issue 依赖图自动推导**（issue #43 原文非目标，沿用）
- **不做跨 issue context 共享**（每子 agent 独立冷启动）
- **不改 4 agent prompt**（developer/tester/reviewer/dba 本体零改动）
- **不抬 target CLAUDE.md**（对齐 DEC-011/012/013/015 "批量调度是 orchestrator 内部策略"边界）
- **不启用 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`**（用 SendMessage relay 决策是 v2 议题）
- **不豁免 critical_modules**（设计阶段不会命中 tester 触发，实施阶段由主会话 workflow 处理）
- **不做 PR 依赖图自动合并**（所有 PR 以 main 为 base，merge order 由用户决定）

## 2. 业务逻辑

### 2.1 命令签名

```
/roundtable:batch <issue-refs> [--concurrency N] [--dry-run]

issue-refs:   一或多个 issue 编号，如 #27 #29 #40（可省略 #）
--concurrency N: 并发上限，默认 3（Opus）/ 5（Sonnet）
--dry-run:    只做 prefetch + 冲突预检 + 调度计划输出，不 fan-out
```

**注**：v1 不支持 `--scope=impl`（实施阶段批量，v2 议题）。

### 2.2 执行流程（6 阶段）

| 阶段 | 主会话动作 | 关键产出 |
|-----|----------|---------|
| 1. Parse | 解析 argv（issue-refs / flags） | 参数校验 |
| 2. Prefetch | `gh issue view <N> --json body,number,title` 对每个 issue | issue metadata 表 |
| 3. Conflict pre-check | 正则扫 `DEC-\d+` / `(?:skills\|agents\|commands)/[\w-]+\.md` + 扩 `docs/design-docs/[\w-]+\.md` | 分组计划（连通分量 → 同组串行） |
| 4. Plan confirm | producer-pause：emit 调度计划 summary；用户 `go` / `调` 后进 Step 5；`--dry-run` 在此终止 | 用户确认 |
| 5. Fan-out + Monitor | 按并发上限批次派发 `Agent(subagent_type="general-purpose", isolation:"worktree", run_in_background:true, prompt:<batch-worker-prompt>)`；每 subagent 独立 DISPATCH_ID + Monitor | 每 issue 一个 worktree + branch + WIP |
| 6. Fan-in + Report | 等全部 Agent 返回；扫 final message：分类 ✅/🟡/🔴；DEC 占位符重编号（见 §2.5）；push + 开 draft PR；TG emit 汇总报告 | 终点 producer-pause |

### 2.3 冲突预检启发式（扩展 analyst §3.5 基础上）

**抽取 token**：

| Token 类别 | 正则 | 来源 |
|-----------|------|------|
| DEC 引用 | `\bDEC-\d+\b` | issue body / comments |
| Prompt 文件路径 | `(?:skills\|agents\|commands)/[\w-]+\.md` | 同上 |
| Design-doc slug | `docs/design-docs/([\w-]+)\.md` 或 ``[slug]`` 引用 | 同上（扩粒度，提升真阳率） |

**分组算法**：

1. 节点 = issue；边 = 至少共享 1 个 token
2. Union-Find → 连通分量 = 冲突组
3. 同组内 issue **串行**（按 issue 编号升序）；组间**并行**（受并发上限约束）

**真阳率改善**（相对 analyst §3.5 抽样）：

| 粒度 | 真阳率（11 issue 抽样） | 假阴性残余 |
|-----|----------------------|-----------|
| 仅 DEC + skills/agents/commands 路径 | 54.5% | UI/FAQ/跨角色 bug 类仍漏 |
| + docs/design-docs slug 扩展 | 估算 65-70% | 症状级描述仍漏 |

**诚实面**：即使扩粒度，启发式仍有 30%+ 假阴性。worktree 隔离作为**合并期代价**的兜底（PR rebase 冲突用户手动解）。

### 2.4 失败终态模型（8 类）

| # | 终态 | 触发 | worktree 状态 | 检测 | 处理 |
|---|------|------|--------------|------|------|
| 1 | ✅ Design-success | Final message 含 PR URL + 无 `<decision-needed>` 残留 | 保留（push 完成） | 正则 PR URL | 加入 ✅ 清单 |
| 2 | 🟡 Decision-pending | Final message 含 `<decision-needed id="...">` 未决 | 保留 | 正则 `<decision-needed` | 主会话 TG emit decision block，等用户回复；回复后**启动 v2 relay**（未实现）或用户 `cd <worktree>` 手动续跑 |
| 3 | 🟡 Auto-halt no recommended | Final message 含 `🔴 auto-halt` 标记 | 保留 | 正则审计行 | 同 #2 |
| 4 | 🔴 Skill AskUserQuestion failure | Final message 含 tool failure 迹象 + `<decision-needed>` 缺失 | 可能部分 | 无 tool call 但有 half-done output | 报告用户 + `cd <path>` 重跑 |
| 5 | 🔴 Subagent crash / maxTurns | Agent tool 报错或 final message 被截断 | 可能无变更→自动回收；可能部分变更→保留 | Agent 返回错 | 报告 + 可选重派 |
| 6 | 🔴 Conflict pre-check grouping trap | 用户 `--no-preheck` 强制并行但实际冲突 | 保留（两 worktree 各有变更） | PR push 时冲突 | 报告 + 手动 rebase |
| 7 | 🔴 Main session 中断 | 用户 Ctrl-C 或退出 | bg subagent 继续跑完但 result 失联 | 无自动检测 | 用户手动 `git worktree list` 查状态 |
| 8 | 🔴 API rate limit 429 | 并发超 Tier 上限 | 可能半成 | Anthropic error response | 主会话收集并报告；可选 降 concurrency 重派 |

**报告顺序**：✅ → 🟡（可恢复）→ 🔴（需人工处理），人工注意力从高价值到最需处理排列。

### 2.5 DEC 编号竞争处理（方案 B：post-hoc renumber）

**占位符协议**：

- 子 agent 写 DEC 时使用 `DEC-NEW-<uuid8>` 作为 ID
- uuid8 = `openssl rand -hex 4`（8 hex 字符；碰撞概率 ≤ 1/4B）
- 占位符出现在：`decision-log.md` 新条目标题 / `design-docs/*.md` frontmatter `decisions:` / `exec-plans/**/*.md` 引用 / `log_entries:` YAML `note`

**重编号算法**（主会话 fan-in 阶段）：

```python
# pseudocode
current_max = max(parse_dec_id(line) for line in decision_log if line.startswith('### DEC-'))
completed_subagents = sort_by_completion_time(successful_subagents)
for i, subagent in enumerate(completed_subagents):
    new_id = current_max + 1 + i
    placeholder_uuid = extract_placeholder_from_worktree(subagent.worktree)
    sed_replace(
        files=scan_worktree(subagent.worktree, patterns=['docs/**/*.md']),
        from_pattern=f'DEC-NEW-{placeholder_uuid}',
        to=f'DEC-{new_id:03d}'
    )
# sanity
for wt in worktrees:
    assert `grep -r "DEC-NEW-" {wt}/docs/` returns 0 matches
```

**replace scope**：`docs/decision-log.md` / `docs/design-docs/` / `docs/exec-plans/` / `docs/testing/` / `docs/reviews/` / `docs/bugfixes/` / `docs/INDEX.md` / `docs/log.md`。**不扫** prompt 本体（skills/agents/commands）—— DEC 占位符不会出现那里（architect 只改 docs）。

**sanity fail 处理**：若残留 `DEC-NEW-` 命中，abort renumber，该 subagent 终态转 🔴 #5，worktree 保留供人工处理。

**为什么不是方案 A 中心锁**：

- 子 agent crash 后号段空洞（审计不好看）
- 需跨子 agent 锁保护并发 workflow 调用
- 子 agent 超限写（意外多 DEC）号段不够

**为什么不是方案 C 主会话统一写**：

- 违反 DEC-001 D8 Resource Access（architect 是 decision-log 权威作者）
- 语义断裂：DEC 是 architect 决策载体，剥夺核心职责

### 2.6 Worktree 生命周期

**沿用 Claude Code 原生**：
- 有变更 → worktree 保留，路径 + branch 由 Claude Code 维护并在 subagent final message 报告
- 无变更 → 自动清理

**不做**：强制保留 / 强制回收 / plugin 层追踪清理。

**人工 inspect 路径**：主会话汇总报告里每个 🟡/🔴 终态都带 worktree path；用户 `cd <path>` 直接查看。

**诚实面磁盘成本**（analyst §3.7）：
- roundtable repo ~20MB，3 并发保留 = ~60MB
- 50 次 dogfood 无清理 = ~1GB
- 阈值：≥100 worktree 或 >5GB 是 `git worktree prune` 的时点
- plugin 不自动 prune，用户负责

### 2.7 并发控制

**默认值**：
- Opus 4.7 → **3**（GitHub #44481 实测 5 agent 在 Max plan 即 429）
- Sonnet 4.6 → **5**（Tier 3 ITPM/OTPM 安全带较足）
- 不自动探测 tier，按主会话当前 model 默认

**`--concurrency N` 覆盖**：实际上限 = min(N, issue 数)。

**调度策略**：FIFO + 冲突组约束；同组最多 1 running，其他排队；组间按并发上限 fan-out。不做优先级重排（v1 简单）。

**rate limit 处理**：
- 检测 429 → 当前批次标 🔴 #8
- 不自动重试（避免雪崩）
- 主会话报告 + 建议用户降 concurrency 重跑

### 2.8 子 agent prompt 模板

```
# Batch worker for issue #<N>

上下文：
- 你是 /roundtable:batch 主会话 fan-out 的 batch-worker
- 运行在 isolation=worktree 的独立 git worktree 中
- 运行在 run_in_background=true 的 bg 模式
- 单 session 内禁止派发其他 subagent（Claude Code 官方约束）
- 因此本 workflow 是 inline-only 设计阶段版

任务：为 issue #<N> 产出完整设计并开 draft PR

强制配置：
- auto_mode: true（architect recommended 自动采纳）
- decision_mode: text（AskUserQuestion 在 bg 会 fail，必须走 <decision-needed>）
- 跳过 Stage 5 developer（subagent 无法嵌套派发）
- 跳过 Stage 6/7/8 tester/reviewer/dba（同上）
- Stage 3 architect 内的 DEC-003 parallel research fan-out 禁用（subagent 约束）—— 改为串行 WebFetch/WebSearch

执行步骤（inline only）:
1. Context detection（inline Read _detect-project-context.md）
2. gh issue view <N> 读取需求
3. Analyst skill inline：产出 docs/analyze/<slug>.md
4. Architect skill inline：产出 docs/design-docs/<slug>.md + DEC-NEW-<uuid> + exec-plan/<slug>-plan.md
   - DEC 用占位符 `DEC-NEW-$(openssl rand -hex 4)`
   - 遇决策点：有 recommended → auto-accept；无 → emit <decision-needed> 到 final message（自然 turn 结束）
5. Git:
   - 已在 worktree 的独立 branch（Claude Code 创建）
   - git add docs/ && git commit -m "..."
   - git push -u origin <branch>
   - gh pr create --draft --title "feat(<slug>): design for #<N>" --body "..."
6. Final message 必含：
   - PR URL
   - DEC 占位符 uuid 列表（供主会话重编号定位）
   - <decision-needed> 块（若 auto-halt）
   - 如 lint 失败：详情
```

**关键 prompt 注入**：

| 变量 | 来源 |
|------|------|
| `target_project` | 固定 `/data/rsw/roundtable`（或 target detection） |
| `docs_root` | `docs/` |
| `issue_number` | argv |
| `auto_mode` | `true`（batch 硬编码） |
| `decision_mode` | `text`（硬编码） |
| `inline_only` | `true`（batch 专属标志；Architect skill 识别后禁 DEC-003 fan-out） |
| `dispatch_id` | `$DISPATCH_ID` |
| `progress_path` | `$PROGRESS_PATH`（可选，`run_in_background=true` 下 Monitor 走 tail） |

## 3. 技术实现

### 3.1 命令结构（新 `commands/batch.md` ~300 行）

```markdown
---
description: Batch dispatcher — design-phase only. Fan-out /roundtable:workflow design-stage across multiple issues in parallel worktrees.
argument-hint: <issue-refs> [--concurrency N] [--dry-run]
---

# Batch 设计工作流

**任务**：$ARGUMENTS

## Step 0: Parse
解析 issue-refs / --concurrency / --dry-run / 其他 passthrough flag

## Step 1: Context detection
inline Read ${CLAUDE_PLUGIN_ROOT}/skills/_detect-project-context.md

## Step 2: Prefetch issue bodies
for each issue: gh issue view <N> --json body,number,title

## Step 3: Conflict pre-check
正则扫 DEC / path / design-doc slug token；Union-Find 分组

## Step 4: Plan emit
producer-pause：emit 调度计划（表格：组 / 并发 / 预估耗时）
用户 `go` 后进 Step 5；`--dry-run` 在此终止

## Step 5: Fan-out + Monitor
按 batch 派发 Agent(subagent_type="general-purpose",
                   isolation:"worktree",
                   run_in_background:true,
                   prompt: §2.8 模板)
每 subagent 独立 DISPATCH_ID → 独立 Monitor

## Step 6: Fan-in + DEC renumber
等全部 Agent 返回（Claude Code notify）
扫 final message：分类 8 终态
对 ✅ 子 agent：读 worktree，执行 §2.5 重编号算法
sanity grep 验证

## Step 7: Report
汇总 markdown（✅→🟡→🔴）
TG 转发（若 inbound 含 channel tag；#48 实施后自动，否则主会话手动）
```

### 3.2 `skills/architect.md` 批改（**critical_modules 命中**）

**新增 `inline_only` 条件分支**（~12 行）：

在 §阶段 1 探索决策 §3.5 Research Fan-out 段加入：

```
**注**：orchestrator 注入 `inline_only: true` 时（batch 子 agent 场景），**禁用** DEC-003 parallel research fan-out —— batch 子 agent 无法嵌套派发 subagent（Claude Code 官方约束）。改走串行 WebFetch/WebSearch 自研或直接基于已有事实决策。
```

在 §decision-log 条目顺序约定段加入：

```
**注**：orchestrator 注入 `batch_mode: true` 时，DEC 编号用占位符 `DEC-NEW-$(openssl rand -hex 4)` 而非递增整数。主会话 fan-in 阶段按完成时序重编号。
```

**不改** architect skill 的其他规则 —— inline_only + batch_mode 两个条件分支是最小新增面。

### 3.3 Monitor 交织（沿用 DEC-004）

每子 agent 独立 `DISPATCH_ID` → 独立 `PROGRESS_PATH` → 独立 `Monitor` → 并行安全（workflow.md §3.5.4 已验证）。

Progress event `summary` 加 issue-ref 前缀：`[architect@#27] reading analyst report` → 用户一眼认出来源。

### 3.4 数据流图

```
TG 用户:
  /roundtable:batch #27 #29 #40
        │
        ▼
[主会话 /roundtable:batch]
  ├ Step 1: context detection
  ├ Step 2: prefetch × 3 (gh CLI)
  ├ Step 3: conflict preheck
  │    └── groups = [{#27}, {#29, #40}]  // #29/#40 假设共享 DEC token
  ├ Step 4: producer-pause → user "go"
  ├ Step 5: fan-out batch 1:
  │   ├─ Agent(#27, bg, isolation:worktree) ──> worktree-A
  │   └─ Agent(#29, bg, isolation:worktree) ──> worktree-B  [#40 queued]
  │                                                    │
  │       worktree-A:                         worktree-B:
  │       ├ context                           ├ context
  │       ├ analyst skill inline              ├ analyst skill inline
  │       ├ architect skill inline            ├ architect skill inline
  │       │  (DEC-NEW-aaa, inline_only)       │  (DEC-NEW-bbb, inline_only)
  │       ├ commit+push+PR                    ├ commit+push+PR
  │       └ final message (含 PR URL)         └ final message
  │             │                                    │
  │             ▼                                    ▼
  │      notify 主会话                          notify 主会话
  ├ fan-in 批次 1；派 #40
  │   └─ Agent(#40, bg) ──> worktree-C (uses arch from #29 lessons? 否，独立)
  │             │
  │             ▼
  │      notify 主会话
  ├ Step 6: fan-in all → parse final messages
  │   - DEC-NEW-aaa → DEC-017 (by completion time)
  │   - DEC-NEW-bbb → DEC-018
  │   - DEC-NEW-ccc → DEC-019
  │   - sed 替换 3 个 worktree
  │   - sanity grep 0 命中
  └ Step 7: emit 汇总：
        ✅ #27 → PR#101 (DEC-017)
        ✅ #29 → PR#102 (DEC-018)
        ✅ #40 → PR#103 (DEC-019)
```

### 3.5 与现有 DEC 对接

| DEC | 对接 |
|-----|------|
| DEC-001 4 agent + D1-D9 | 不动；batch 不增加 agent，只改 command + architect skill |
| DEC-001 D8 Resource Access | 沿用；architect 在 batch 子 agent 内仍写 decision-log（用占位符） |
| DEC-002 Escalation JSON | 正交；v1 不涉实施阶段，tester/reviewer/dba 不触发 |
| DEC-003 parallel research | **在 batch 子 agent 内禁用**（Claude Code 约束），主会话模式沿用 |
| DEC-004 progress event schema | 独立 DISPATCH_ID 已符合 |
| DEC-005 developer 双形态 | 不改；v1 不涉 developer |
| DEC-006 phase gating | batch 层本身：Step 4 = A 类 producer-pause / Step 5 = C 类 verification-chain / Step 7 = A 类；**不新增类别** |
| DEC-007 progress content policy | 不改 |
| DEC-008 Step 3.5 bg/fg gate | 全部 batch 子 agent 走 bg（fan-out 天然≥2） |
| DEC-009 轻量化 | 新增 `commands/batch.md` + architect 2 条件分支，总增 ~312 行；不抽新 helper（DEC-010 精简心智守约） |
| DEC-011 DEC 顺序（最新在前） | 重编号后仍满足（按 fan-in 完成序分配在当前 MAX 之上置顶） |
| DEC-013 decision_mode | 子 agent 硬编码 `--decision=text` |
| DEC-015 auto_mode | 子 agent 硬编码 `--auto`；batch 本身 Step 4 是否支持 `--auto`？**v1 支持**（consistent with 单 issue） |

**不 supersede 任何 Accepted DEC**。

### 3.6 TG 转发链路（诚实面）

依赖 #48 实施状态：

| #48 状态 | batch 层 TG 体验 |
|---------|-----------------|
| 未实施 | 主会话 Step 4 plan confirm / Step 7 汇总 / 子 agent final message digest 都需 batch 命令**显式调 TG reply 工具**（手动转发，与现状 workflow 一致） |
| 已实施 | 自动转发（DEC-013 §3.1a 扩展的事件类生效），batch 命令零改动 |

batch v1 **不依赖** #48 —— 命令层内嵌手动转发逻辑。#48 实施后可删除该手动逻辑（未来重构）。

**三层嵌套转发限制**（research Q7 发现）：
- TG 用户 → 主会话（inbound 含 `<channel>`） → batch subagent（**inbound 是主会话构造的 prompt，不含 `<channel>` 标签**，sticky 语义不成立）
- 子 agent 不知道如何 TG reply；即便主会话 prompt 注入 `chat_id`，DEC-013 §3.1a 的检测条件仍不命中
- **设计决策**：子 agent **不负责** TG 转发；主会话 fan-in 后统一转发汇总到 TG。`<decision-needed>` bubble 到 final message 后由主会话 relay

## 4. 关键决策与权衡

### 4.1 D1 命令形态：新独立命令 vs 扩展 workflow.md

| 维度 (0-10) | A. 新 `commands/batch.md` ★ | B. `workflow --batch` 扩展 |
|-------------|---------------------------|--------------------------|
| 架构一致性 | **9**（batch 有独立 Phase Matrix 与 workflow 单 issue 心智解耦） | 5（workflow 承担双心智） |
| 可读性 | **9**（slash command 语义清晰） | 6 |
| 实现复杂度 | **7**（新 ~300 行） | 5（workflow.md 357 → ~500 行） |
| DEC-010 精简 | **8**（单 issue workflow 调用零 batch 负担） | 5（workflow.md 被迫加载 batch 段） |
| critical_modules 命中面 | 7（新增 1 个 command 文件） | **8**（同一文件命中面不增） |
| 用户心智 | **8**（独立 entry） | 6（命令一个但模式二） |
| **合计** | **48** | 35 |

**决定**：新 `commands/batch.md`（方案 A）。

**失败模式**：
- (1) workflow.md 演化 → batch 未跟进 → 语义漂移（analyst §2 必答 2 #1）；缓解：设计评审时明确"batch 是 workflow 设计阶段子集"，演化同步审计
- (2) 用户混淆两命令 → 缓解：文档清晰+ README 对比表

### 4.2 D2 Batch scope：设计阶段 only vs 全阶段 ⚠️ 重大决策

| 选项 | 实现复杂度 | v1 可用 | UX 完整性 | DEC-001 兼容 | **合计 (40 满)** |
|------|-----------|--------|----------|-------------|---------------|
| A. 设计阶段 only（v1 MVP）★ | **9** | **10** | 7（无实施） | **10** | **36** |
| B. 全阶段（含 developer/tester/...） | 2（需 tester/reviewer/dba inline 形态） | 2 | **10** | 3（违反 DEC-001 4 agent 边界） | 17 |
| C. 全阶段 + EXPERIMENTAL_AGENT_TEAMS | 4（实验标志 + 未稳定） | 5 | 9 | 7 | 25 |
| D. 分段 `--scope=design/impl` 双模式 | 6 | 7 | 8 | 8 | 29 |

**决定**：A（设计阶段 only，v1 MVP）。

**why_recommended**：
- Claude Code 硬约束 "subagents cannot spawn" 使 B/C/D 都需要大规模改造
- 用户已明确"设计先于实施，PR 先 review 再实施"的意图，A 完美对齐
- A 可快速落地验证 batch 机制正确性，B/C/D 可作 v2+ 议题
- DEC-001 D1-D9 4 agent 边界零触达 —— 不需要 Supersede 流程

**v2 议题列表**：
- 扩展 tester/reviewer/dba 到 inline 形态（DEC-005 follow-up）
- 或 agent teams 稳定后评估 C
- 或 `--scope=impl` 分段模式（实施阶段在主会话直接跑 workflow，batch 不涉及）

**失败模式**：
- (1) 用户期望 batch 产出完整 PR 含实现 → 缓解：命令 `description` + TG 报告明确声明"v1 设计阶段 only"
- (2) 设计阶段产出质量不足 → 缓解：沿用 analyst + architect 深度调研流程（"加大力度"模式）

### 4.3 D3 DEC 编号竞争：post-hoc renumber（方案 B）

| 维度 (0-10) | A 中心锁 | B post-hoc ★ | C 主会话统一写 |
|-------------|---------|-------------|---------------|
| 实现复杂度 | 6 | **9** | 3 |
| 容错（子 agent crash）| 5 | **9**（占位符自然丢弃） | 5 |
| DEC-001 D8 兼容 | **10** | **10** | 3（违反）|
| 号码预告性 | **9** | 5（fan-in 后才知） | 7 |
| sanity 检查 | 7 | **8**（grep 验证） | 5 |
| **合计** | 37 | **41** | 23 |

**决定**：B。**why_recommended**：crash 容错 + DEC-001 兼容 + 实现简单 的综合最优。

**失败模式**：
- (1) sed 假阳性替换（UUID 巧合出现在代码示例）→ 缓解：碰撞概率 ≤1/4B，正则严格边界 `\bDEC-NEW-[a-f0-9]{8}\b`
- (2) 重编号漏文件 → 缓解：sanity `grep -r "DEC-NEW-" docs/` 必须 0 命中

### 4.4 D4 冲突预检：启发式 + 扩 design-doc slug

| 选项 | 真阳率 | 实现 | 合计 (30 满) |
|------|--------|------|-------------|
| A. 无预检 | N/A | **10**（零代码） | 20 |
| B. DEC + prompt 路径 | 54.5% | 9 | 22 |
| C. B + design-doc slug 扩展 ★ | ~65-70%（估算） | 8 | **27** |
| D. AST 级依赖分析 | ~90% | 2（工程量大）| 18 |

**决定**：C。**why_recommended**：增加 `docs/design-docs/[slug].md` 粒度在不显著提升复杂度的前提下改善真阳率。

**失败模式**：
- (1) 启发式假阴性（症状级 issue）→ 缓解：worktree 隔离是合并期兜底；文档诚实标注
- (2) 假阳性导致过度串行 → 缓解：未来可加 `--no-preheck` flag 强制并行

### 4.5 D5 Worktree 生命周期：沿用原生 ★

**决定**：不覆盖 Claude Code 默认（有变更保留 / 无变更回收）。

**why_recommended**：原生已符合"失败保留供 inspect / 成功自动清理"心智；plugin 层追踪 worktree path + 清理策略复杂度不成比例。

**失败模式**：
- (1) 长期堆积磁盘 → 缓解：报告 + 文档引导用户 `git worktree prune`
- (2) 用户不知道 worktree 在哪 → 缓解：汇总报告中每个 🟡/🔴 都附 worktree path

### 4.6 D6 并发默认：model-aware ★

| 选项 | 合计 (20 满) |
|------|------------|
| A. 固定 3 | 14 |
| B. 固定 5 | 10（Opus 高风险） |
| C. model-aware（Opus 3 / Sonnet 5）★ | **18** |

**决定**：C。**why_recommended**：基于 research Q5 的 GitHub issue #44481 实测（Opus Max plan 5 agents 即 429）+ Tier 3 ITPM 估算。

**失败模式**：
- (1) model 探测失败 → 缓解：默认退化为 Opus 3（保守）
- (2) tier 更高的用户被保守值限制 → 缓解：`--concurrency N` 显式覆盖

### 4.7 D7 Subagent type：`general-purpose`（Candidate A）★

| 维度 (0-10) | A. general-purpose ★ | B. CLI-defined ephemeral | C. plugin batch-worker |
|-------------|---------------------|--------------------------|------------------------|
| 可用性（能否在 plugin command 内派发）| **10** | 0（需 session 启动 --agents 参数） | **10** |
| skills 继承 | 5（需 prompt 注入 skill 内容）| 5（同前） | **9**（skills: 字段显式预加载）|
| permissionMode 支持 | **9**（继承主会话） | **9** | 3（plugin 不支持 permissionMode）|
| DEC-001 D1-D9 边界 | **10**（不增 agent） | **10** | 5（新增 agent 触达 4 agent 边界）|
| MCP 继承 | **8**（默认继承所有工具）| **8** | 5（plugin 不支持 mcpServers 覆盖）|
| 维护成本 | **9**（零新文件）| 不可用 | 6（新 batch-worker.md） |
| **合计** | **51** | 32 | 38 |

**决定**：A。**why_recommended**：Candidate B 根本不可用（plugin command runtime 无法动态注册）；Candidate C 的 skills 预加载优势不抵 permissionMode 受限 + 新增 agent 触达 DEC-001 边界。

**失败模式**：
- (1) general-purpose 不继承 skills → 缓解：子 agent prompt **内嵌 inline 完整 workflow 步骤**（不依赖激活 skills）；或 batch-worker prompt 模板中 Read skill 文件 inline
- (2) CLAUDE.md / plugin commands 是否在 worktree subagent 内可用未明 → 缓解：prompt 显式 inline 所有必要内容

### 4.8 D8 Stage 4 Design confirmation 在 bg subagent 行为：text + auto + recommended → auto-accept；否则 emit `<decision-needed>` bubble

**决定**：沿用 DEC-015 auto + DEC-013 text 组合语义。

- **路径 A（95% 场景）**：architect 设计带 recommended → auto-accept → 子 agent 继续到 PR 阶段 → ✅ 终态
- **路径 B（fallback）**：recommended 缺失 → auto-halt → emit `<decision-needed>` 到 final message → 子 agent current turn 结束 → batch 主会话 parse → 🟡 Decision-pending 终态 → TG relay 给用户

**why_recommended**：复用现有 DEC-013/015 机制，不发明新行为。

**失败模式**：
- (1) bg subagent text mode pause 是否等同 final turn 完成（research Q7 unknown）→ 缓解：实测前按"等同 final turn"假设；v1 P4 dogfood 会验证
- (2) 用户在 TG 回复决策后如何 relay 回子 agent → 缓解：v1 **不自动 relay**；用户需 `cd <worktree>` 手动续跑（SendMessage 需要 EXPERIMENTAL flag，v2 议题）

### 4.9 D9 MCP TG forwarding 跨三层

**决定**：子 agent **不负责** TG 转发；主会话 fan-in 后由 batch 命令显式调 reply 工具汇总转发。

**why_recommended**：
- 子 agent inbound prompt 不含 `<channel>` 标签（由主会话构造），DEC-013 §3.1a sticky 语义不成立
- 主会话一层转发避免三层嵌套协议不明确的复杂度
- 汇总单条 TG 消息比 N 个子 agent 分散 reply 更适合用户 review

**失败模式**：
- (1) 子 agent 中途 `<decision-needed>` 用户长时间不知 → 缓解：progress event 偶尔 emit 到 TG（Monitor 输出 TG 转发，#48 的 part）
- (2) 汇总消息超 TG 4096 char 限制 → 缓解：按终态分多条发（✅ / 🟡 / 🔴 各一条）

### 4.10 D10 失败终态数：8 类（扩 analyst 3 类）

**决定**：8 类（参见 §2.4 表）。

**why_recommended**：穷举覆盖所有可观察终态，每类都有检测 + 处理规则；未来新模式（例如 v2 实施阶段）可追加。

## 5. 讨论 FAQ

### 5.1 为何不等 Claude Code 放开 "subagents cannot spawn"？

不可预期时间表；同时"设计阶段 only"本身就是有价值的 MVP（用户已明确 PR-first review 流程）。等 Claude Code 放开后再扩 v2。

### 5.2 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 为什么不在 v1 启用？

Research Q7 发现 SendMessage 是 experimental，且 agent teams 有多项 known limitations（session resumption / shutdown / nested teams 等）。v1 以稳定为先；v2 议题评估。

### 5.3 为什么不用 GitHub Actions 做 batch？

analyst §2 竞品对比：GH Actions 在 Claude Code session 外，`<decision-needed>` 无法 bubble 到 TG；用户 tie-break 要切 GH UI。与本设计"TG 驱动 dogfood"目标不符。

### 5.4 主会话中断（Ctrl-C）后 bg subagent 会怎样？

subagent 继续跑到自然结束，result 失联。用户手动 `git worktree list` 查物理状态 / `cd <path>` 查 branch + commit 接续。v2 可考虑主会话中断时显式 `Agent cancel`（如 Claude Code 提供）。

### 5.5 DEC 重编号后 `DEC-NEW-<uuid>` 映射在哪记录？

PR body 由 batch 主会话统一生成，含一段：

```
DEC renumber map:
- DEC-NEW-a1b2c3d4 → DEC-017 (this PR)
```

便于审计回溯。

### 5.6 并发 3 对 dogfood 当前 open issue 足够吗？

analyst §3.10 数据：当前 11 open issue 中 7 条共享 workflow.md 路径 → 同一冲突组内必须串行；其余 {#23, #20, #27} 可并发。**首轮 batch 实际有效并行度 ≤3**，3 是甜蜜点。

## 6. 变更记录

| 日期 | 版本 | 变更 | 作者 |
|------|------|------|------|
| 2026-04-20 | v1 Draft | 初版；10 关键决策量化评分；基于 Q4/Q5/Q7 research + 官方文档"subagents cannot spawn"约束重塑架构 | architect |
| 2026-04-20 | v1.1 | PR #49 评审后补：§7.2 C1-C5 决策；§9 用户视角使用流程 / 问题解决清单 / 价值评估 / v1 推迟声明 | architect |

## 7. 待确认项

### 7.1 Research unknown（需 P5 dogfood 实测）

- [ ] batch subagent text mode pause 的 final turn 行为（Q7 unknown）—— P5 dogfood smoke 测
- [ ] CLAUDE.md / plugin commands 是否在 `isolation:worktree` subagent 内自动可用（Q4 unknown）—— 同 P5
- [ ] maxTurns 默认值 / 设计阶段完整跑所需 turn 数 —— P5
- [ ] MCP TG plugin tool 是否继承到子 agent（research 文档矛盾：一处说"默认继承所有工具含 MCP"，一处说"string references 需显式列出"）—— P5 实测

### 7.2 用户确认的实施细节（2026-04-20 PR #49 review 阶段）

- [x] **C1 D2 Scope 降级质疑** → **A. v1 落地（设计阶段 only MVP）**
  - **用户诚实反馈（关键事实）**：2026-04-20 PR #49 评审时用户明确声明 "目前实施效果，与我的期望有较大差异"。原期望是"批量 dogfood 全流程（含实施）"，v1 降级为"设计阶段 only"的价值显著低于原期望
  - **处理**：v1 按 PR #49 design 保持不变；**v1 实施被推迟**直到以下任一条件满足：(a) Claude Code 放开 subagents-cannot-spawn 约束 → 可直接做 v2 全流程；(b) 用户明确评估 design-only 价值足够愿意接受 v1 实施；(c) 出现更高价值的优先需求
  - **暂不开 v2 议题 placeholder issue**（见 C3）

- [x] **C2 P5 dogfood 首跑 issue** → **A. 新建 3 个 P3 micro-issue 做 smoke**
  - 选 {#20, #23, #27} 不匹配 design-only 场景（这些是 implementation-heavy）
  - v1 **实施时**（若决定实施）再新建 3 个 P3 专门做 smoke：例如 "docs: refine DEC-011 header initialization wording" / "docs: add FAQ section to lightweight-review design-doc" / "docs: document worktree cleanup best practices" 三类 pure-docs 场景；符合 design-only 测试目标
  - **当前 v1 推迟状态下本项暂挂起**

- [x] **C3 v2 议题占位 issue** → **不开**（用户明确拒绝）
  - 三个 v2 议题（tester/reviewer/dba inline / agent teams 评估 / `--scope=impl` 分段）保留在本 design-doc §1.2 非目标段记录；未来需要时直接从这里查
  - 理由（用户口径）：避免 issue 列表膨胀 / YAGNI

- [x] **C4 PR 合并顺序 + branch 命名** → **A. batch 汇总按冲突组排序 + Claude Code 自动 `claude/<random>`**
  - 汇总报告建议 merge 顺序：同冲突组内先完成先合；组间独立
  - branch 命名沿用 Claude Code `isolation:worktree` 原生 `claude/<random>`，不显式指定 `batch/<issue>-<slug>`（减少命名策略复杂度）

- [x] **C5 Concurrency default model-aware 探测** → **A. 读 env `CLAUDE_MODEL` / `--concurrency` flag；不探测默认 3**
  - batch 命令优先序：`--concurrency N` > env `CLAUDE_MODEL ∈ {sonnet*}` → 5 / env 含 `opus*` → 3 / default → 3（保守）
  - 永远默认 3 是 fallback；模型探测失败也走 3

## 9. 用户视角：最终使用体验与交付价值

### 9.1 使用流程（end-to-end）

**场景**：你在 TG 想批量消化 3 个 P3 issue `#A #B #C` 的设计阶段。

**Step 1 — 触发命令**：

```
TG @bot → /roundtable:batch #A #B #C
```

**Step 2 — 30 秒内 TG 收到调度计划**：

```markdown
📋 Batch Plan (3 issues, concurrency=3)

冲突预检:
  Group 1 (串行): {#A, #B} — 共享 DEC-005 token
  Group 2 (独): {#C}

调度批次:
  Batch 1: #A + #C 并行（不同组）
  Batch 2: #B (等 #A 完成；同组内串行)

预估耗时: 30-60 min
继续？回 go / 停
```

**Step 3 — 用户 `go` 后进入 30-60 分钟静默期**：

本 v1 诚实面：`<decision-needed>` 转发（DEC-013 §3.1a）仅在 emit 决策块时生效，子 agent 跑设计期间 TG 无反馈（除非命中 auto-halt fallback 或 skill 决策）。

**Step 4 — 后台实际执行**（用户不可见，供架构回溯）：

```
主会话 /roundtable:batch:
  ├ fan-out: Agent(#A, bg, worktree) + Agent(#C, bg, worktree)
  ├ 等 batch 1 完 → fan-out #B
  └ 全部完 → parse + renumber DEC + 汇总

每个 bg subagent (worktree 内):
  ├ gh issue view <N>
  ├ analyst skill inline  → docs/analyze/<slug>.md (深度分析)
  ├ architect skill inline → docs/design-docs/<slug>.md
  │                           + DEC-NEW-<uuid8> 占位
  │                           + docs/exec-plans/active/<slug>-plan.md
  ├ git commit + push + gh pr create --draft
  └ final message (含 PR URL + DEC-NEW uuid)
```

**Step 5 — 全部完成时 TG 汇总报告**：

```markdown
✅ Batch 完成 (3/3, 42 min)

✅ 已完成 (3):
  #A → PR#51 (DEC-017) branch: claude/abc123
  #B → PR#52 (DEC-018) branch: claude/def456
  #C → PR#53 (DEC-019) branch: claude/ghi789

🟡 待决策 (0)
🔴 失败 (0)

DEC renumber map:
  DEC-NEW-aaa → DEC-017 (#A)
  DEC-NEW-bbb → DEC-018 (#B)
  DEC-NEW-ccc → DEC-019 (#C)

建议 merge 顺序: #A → #B (同组串行) → #C
```

**Step 6 — 用户在 GitHub 逐 PR review 设计**：

- 认同 → Approve + merge
- 要改 → PR comment 指出，architect skill 按反馈迭代（重跑 `/roundtable:workflow <N>` 的 architect 阶段，针对单 PR 的 slug）
- 拒绝 → close PR；issue 保持 open

**Step 7 — Merged 后实施阶段（不走 batch）**：

```
TG @bot → /roundtable:workflow #A --auto
```

主会话跑完整 workflow 派发 developer / tester / reviewer subagent，产实施 commit 追加到同 branch / 同 PR。

### 9.2 解决的问题

| # | 痛点 | v1 如何解决 | 量化 |
|---|------|------------|------|
| 1 | 积压多 issue 的设计阶段串行耗时 | 并行 fan-out worktree subagent | 3 条并行 ~1-2h vs 串行 ~3-6h（3x 加速） |
| 2 | 用户 review 时机太晚（要等完整 workflow 跑完） | 设计阶段产出即 draft PR | 不用等 developer/tester，早期发现设计问题 |
| 3 | 多 issue 并发时 DEC 编号竞争 | post-hoc renumber + DEC-NEW-\<uuid\> 占位 | 零协调 / 容错 / 审计清晰 |
| 4 | 并发改同文件的 race | worktree 硬隔离 + 启发式冲突预检分组 | 假阴性兜底靠合并期 rebase |
| 5 | 分布式决策记录难追溯 | 汇总报告 DEC renumber map + PR body 映射 | PR 审计时可反查原 uuid |

### 9.3 不解决的问题（v1 诚实面）

| # | 问题 | 根因 | 缓解 |
|---|------|------|------|
| 1 | ❌ 不加速实施阶段 | Claude Code 硬约束：subagents cannot spawn subagents | v2 议题（见 §1.2）；或等 Claude Code 放宽 |
| 2 | ❌ 子 agent 跑期间 TG 零反馈 | DEC-013 §3.1a 转发不跨三层嵌套 | #48 修复后显著改善（仍非完美） |
| 3 | ❌ 启发式预检 30%+ 假阴性 | body 描述与真实改动面不一定对齐 | worktree 隔离是合并期兜底 |
| 4 | ❌ recommended 缺失子 agent 停在 worktree | 非 `EXPERIMENTAL_AGENT_TEAMS=1` 无 SendMessage | 用户 `cd <worktree>` 手动续跑 |
| 5 | ❌ 长期 worktree 堆积耗磁盘 | Claude Code 原生保留有变更 worktree | 文档引导用户 `git worktree prune` |

### 9.4 价值评估（诚实面）

**值得做的情况**：

- 当前 open 11 个 issue 里 P2/P3 积压 9 个
- 用户有"先 review 设计再实施"的 PR-first 流程偏好
- 批量设计文档产出节省 ~3-5h 首次积压消化时间

**不值得做的情况**：

- **用户期望"批量 dogfood 完整 pipeline"**：v1 不覆盖实施阶段，与原期望差距大（2026-04-20 用户原话："目前实施效果，与我的期望有较大差异"）
- Claude Code 预期短期（1-3 月）放开 subagents-cannot-spawn 约束 → 应直接做 v2 全流程
- 用户不急于消化 P2/P3 积压

### 9.5 v1 推迟决策（2026-04-20）

基于用户明确反馈"实施效果与期望差异较大"，v1 实施**暂停**。本 PR #49 保留作为设计存档；是否最终实施等待：

1. Claude Code 对 subagents-cannot-spawn 约束的动态
2. 用户对 design-only 价值的再次评估
3. 更高价值的优先需求完成后重新审视

## 8. 影响文件清单

**新增**：
- `commands/batch.md`（~300 行）
- `docs/design-docs/batch-orchestrator.md`（本文件）
- `docs/exec-plans/active/batch-orchestrator-plan.md`（实施计划）
- `docs/decision-log.md` DEC-016 置顶

**修改**：
- `skills/architect.md`：加 2 条件分支（`inline_only` 禁 DEC-003 fan-out + `batch_mode` 用 DEC-NEW 占位符），总 ~12 行

**不改**：
- `commands/workflow.md` / `commands/bugfix.md` / `commands/lint.md`
- `skills/analyst.md`
- 4 agent prompt（developer/tester/reviewer/dba）
- `skills/_detect-project-context.md` / `skills/_progress-content-policy.md`
- target CLAUDE.md 业务规则边界
- DEC-001 ~ DEC-015 任何 Accepted 条款（append-only）
- Phase Matrix / 并行判定树 / critical_modules 机械触发

**运行时新行为**：
- `/roundtable:batch` 命令入口新增
- 子 agent 强制 `auto=true + decision_mode=text + inline_only=true + batch_mode=true`
- DEC 在 batch 路径用 DEC-NEW-<uuid> 占位，fan-in 重编号
- v1 仅设计阶段；v2+ 议题扩展

**critical_modules 命中**：`skills/architect.md` 修改触发 **tester 强制派发**（设计阶段完成后，下个工作流派发）。本 PR 不含实施，tester 在后续 workflow 跑时触发。
