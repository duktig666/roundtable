---
description: Multi-role AI workflow orchestrator. Selects a path among analyst / architect / developer / tester / reviewer / dba based on task size.
argument-hint: <task description>
---

# 多角色工作流

**任务**：$ARGUMENTS

---

## 执行前提

目标项目遵循 roundtable 的 docs 布局（`design-docs/` / `exec-plans/active/` / `analyze/` / `testing/` / `reviews/` / `decision-log.md` / `log.md`）。缺失子目录在首次写入时自动创建并向用户报告。

## Phase Matrix

在整个派发生命周期维护本 matrix；每次 phase 切换或用户询问进度时重新报告。

| 阶段 | 角色 | 状态 | 产出 |
|-----|------|------|-----|
| 1. Context detection | inline | ⏳/🔄/✅ | `target_project` / `docs_root` / `lint_cmd` / `test_cmd` / `critical_modules` / `design_ref` |
| 2. Research（可选） | analyst | ⏳/🔄/✅/⏩ | `{docs_root}/analyze/[slug].md` |
| 3. Design | architect | ⏳/🔄/✅ | `{docs_root}/design-docs/[slug].md`、`decision-log.md` DEC、可选 exec-plan / api-docs |
| 4. Design confirmation | 用户 | ⏳/🔄/✅ | 用户确认 |
| 5. Implementation | developer（一或多） | ⏳/🔄/✅ | `src/` / `tests/`、exec-plan checkbox（orchestrator 写入） |
| 6. Adversarial testing | tester | ⏳/🔄/✅/⏩ | 测试代码、`{docs_root}/testing/[slug].md`、escalation bug |
| 7. Review | reviewer | ⏳/🔄/✅/⏩ | 对话或 `{docs_root}/reviews/[YYYY-MM-DD]-[slug].md` |
| 8. DB review | dba | ⏳/🔄/✅/⏩ | 对话或 `{docs_root}/reviews/[YYYY-MM-DD]-db-[slug].md` |
| 9. Closeout（A）| 用户 | ⏳/🔄/✅ | 汇总 findings；用户驱动 commit / PR / amend |

图例：⏳ 待办 · 🔄 进行中 · ✅ 完成 · ⏩ skipped · — 不适用

**实时进度流（matrix 下方）**：按 DEC-004 的 `[<phase>] <role> <event> — <summary>` 格式实时出现，由 Step 3.5 启动的 `Monitor` 驱动；多个并行派发按 `dispatch_id` 交织。

---

## Step -0: Auto Mode Bootstrap

解析 `auto_mode` = `true` | `false`（默认 `false`）。优先级：CLI `--auto` > env `ROUNDTABLE_AUTO ∈ {1, true, on, yes}`（其他值 / 空串 / 未设 → 视为 false）> default。`--no-auto` 显式关闭（覆盖 env 开启）。

注入：每次 `Task` 派发 prompt prefix + 每次 skill 激活 context prefix 加一行 `auto_mode: <value>`。orchestrator 自身按 flag 选 Step 5 Escalation 与 Step 6 phase gating 的 auto / manual 分支。

`auto_mode=true` 适用：批量 dogfood / CI 非交互 / 信任型自消耗。**不适用**于初次探索陌生决策域（recommended 缺失概率高会频繁 auto-halt）。推荐搭配 `decision_mode=text` 使用（modal 下 skill 的 `AskUserQuestion` 由 runtime 执行 orchestrator 无法拦截，auto 对 skill 弹窗无效；仅对 orchestrator 层决策块生效）。

## Step -1: Decision Mode Bootstrap

解析 `decision_mode` = `modal` | `text`（默认 `modal`）。优先级：CLI `--decision=...` > env `ROUNDTABLE_DECISION_MODE` > default。

注入：每次 `Task` 派发 prompt prefix + 每次 skill 激活 context prefix 加一行 `decision_mode: <value>`。orchestrator 自身按 mode 选 Step 5 Escalation 渲染路径。

`text` 用于远程前端（Telegram / CI / 日志回放）—— `AskUserQuestion` 在非主会话前端不可响应会阻塞 workflow。

## Step 0: Project Context Detection

**inline 执行 4 步检测**：`Read` `${CLAUDE_PLUGIN_ROOT}/skills/_detect-project-context.md` 并直接按 4 步执行，结果存 session 记忆。

1. **target-project 识别（D9）**：session 记忆 → `git rev-parse --show-toplevel` → 扫描 CWD 下含 `.git/` 的子目录 → 正则匹配任务描述 → `AskUserQuestion` 兜底
2. **Toolchain detection**：扫 `Cargo.toml` / `package.json` / `pyproject.toml` / `go.mod` / `Move.toml`；推导默认 `lint_cmd` / `test_cmd`
3. **docs_root detection**：`docs/` → `documentation/` → `AskUserQuestion` 默认「创建 `docs/`」
4. **CLAUDE.md loading**：读 `# 多角色工作流配置` 的 `critical_modules` / `设计参考` / `工具链覆盖` / `条件触发规则`（CLAUDE.md 覆盖自动检测）

后续派发**必须**注入：`target_project` / `docs_root` / `primary_lang` / `lint_cmd` / `test_cmd` / `critical_modules` / `design_ref` / `slug`。绝不让 subagent 自己重跑。

**转发**：active channel 下按 Step 5b 事件类 a 转发检测结果块（`markdownv2` 结构化，DEC-022）。

## Step 0.5: FAQ Sink Protocol（issue #27；常驻规则，在 Step 0 之后激活）

> **位置说明**（C1 修复）：本 step 虽按编号紧随 Step 0，但语义上是 **session 生命期常驻规则**，而非"执行一次"的 bootstrap。`{docs_root}` / `target_project` 必须由 Step 0 先填充，本 step 在**首次用户机制提问**到达时才激活；Step 0 完成前的任何提问**延后 sink**（先回答，等 Step 0 完成后再追加）。

用户**直接提问**（非 `<escalation>` / 非 A 类菜单 `问:` / 非 skill 阶段调研）涉及 roundtable 机制时，orchestrator 回答后**自动追加** Q&A 到 `{docs_root}/faq.md`（不存在则创建 minimal header；`<project>` 字面值 = `basename(target_project)`，例如 `target_project=/path/to/myapp` → `myapp`）：

```
# <project> FAQ

> 机制 / 概念 / 决策类问答沉淀。slug 级 FAQ 在各 analyst/design-docs ## FAQ 段，与本全局 FAQ 互补。

---
```

**Sink 触发**（白名单启发式；用户命令覆盖；大小写不敏感匹配）：
- **roundtable 专有术语**命中（任一）：`orchestrator` / `phase matrix` / `DEC-\d+` (regex) / `auto_mode` / `decision_mode` / `escalation` / `producer-pause` / `approval-gate` / `verification-chain` / `critical_modules` / `Resource Access` / `roundtable` / `roundtable:(architect|analyst|developer|tester|reviewer|dba)` / slug 级 DEC 名如 `DEC-015` / Step 编号如 `Step 5b` / `§3.1a`
- **中文通用词**（`机制` / `流程` / `阶段` / `决策` / `工作流`）**必须**与上述专有术语**同句**共现才触发（避免 target 项目业务语境误伤）
- 用户显式 `加入 FAQ` / `沉淀到 FAQ` / `add to FAQ` / `add faq` → 强制 sink（**前提**：该问仍属 roundtable 机制类；纯业务问题即使命令强制也拒绝并回 `此提问非 roundtable 机制类，未 sink；可改写为 mechanism 化表述`，W4）
- 用户显式 `别沉淀` / `skip FAQ` / `don't FAQ` / `no faq` → 强制跳过
- **冲突解析**：同一消息同时含强制 sink + 强制 skip 命令 → **`skip` 胜出**（保守；用户可后续手动 `加入 FAQ`）

**Sink 不触发**：target 项目代码 debug / 特定错误定位 / 用户偏好讨论 / 纯闲聊 / 一次性对话 / A 类 `问:` 前缀（走 menu 循环路径到 analyst slug FAQ，DEC-006 §A）。

**A 类 menu 激活期间裸问机制题**（用户无 `问:` 前缀）：Step 0.5 优先 —— 回答 + sink global FAQ，**不**进入 menu 循环（menu 循环专属 `问:` 前缀用户意图）。回答完 orchestrator 重 emit 原 A 类 menu（DEC-006 §A 菜单穷举）。

**去重算法**（F1 澄清）：
1. 追加前 `Read` `{docs_root}/faq.md`（若存在）
2. **Tokenize**：Q 标题 lowercase + 按 `[\s\p{P}]+` split（中英混合同款，中文按字符粒度留存，英文按空格，标点剔除）
3. **Bag-of-words Jaccard 相似度**：`|A ∩ B| / |A ∪ B|`（两个 Q 的 token 集合）
4. **≥ 0.7** → 判重复，**不追加**，改在回复末尾 ref 已有 § 锚点
5. 同义词（如 `orchestrator` vs `编排器`）不在本简化算法范围；follow-up 若误判率高可扩词典

**条目格式**：

```
## Q: <简化问题 ≤80 字符>
**提问于**：YYYY-MM-DD session
**类别**：[roundtable 机制 | Phase Matrix | DEC-xxx | ...]

<answer ≤500 字；超长引 docs/... 路径>

---
```

**回复末尾标注**：
- Sink 触发 → 加一行 `📚 已追加到 {docs_root}/faq.md § Q: <简化标题>`
- 去重命中 → `📚 已有相关条目见 {docs_root}/faq.md § Q: <锚点>`

**`log_entries:` 上报**：orchestrator 自造 `prefix: faq-sink` / `slug: faq-sink` / `files: [{docs_root}/faq.md]` / `note: Q-<简化> sunk`。新前缀 `faq-sink` 追加到 `docs/log.md` §前缀规范白名单（expected 一次性动作）。

**与 A 类 `问:` 区别**：A 类 menu 的 `问: ...` 触发 skill 回派答 FAQ 后**返回菜单循环**（DEC-006 §A），FAQ 条目走 **analyst slug 级** `## FAQ`（analyst 报告内）；本 Step 0.5 是 **非 A 类 menu 的** 直接提问，走 **global `{docs_root}/faq.md`**。两者互补不冲突。


## Step 1: 任务规模判定

| 规模 | 信号 | Pipeline |
|------|------|---------|
| **小** | Bug fix / 单文件 / UI / 文档 | `/roundtable:bugfix` 或直接 `@roundtable:developer` |
| **中** | 新功能 / 模块变更 | analyst（可选）→ architect → design-confirm → developer → tester（若涉关键）→ reviewer（可选） |
| **大** | 新模块 / 跨组件 / 架构变动 | analyst → architect → design-confirm → developer → tester → reviewer |

涉 DB 变更：developer 后派发 `@roundtable:dba`。规模模糊时 `AskUserQuestion` medium/large 两选项（每项 `rationale` + `tradeoff`）；`auto_mode=true` 见 §Auto-pick。同轮待决 ≥2 fuzzy 决策时走 §Step 4b 判定是否批量 AskUserQuestion。**转发**：active channel 下判定结果随 Step 0 context 同块转发（Step 5b 事件类 a）。

## Step 2: Tester 触发

命中注入 `critical_modules` 任一关键词 → developer 后**必须**派 tester。通用兜底（CLAUDE.md 未声明时）：金额/权限、性能热路径、并发/锁/事务、安全、外部系统集成。可选：中大任务 E2E / 前端关键交互。跳过：bug fix / UI / 文档 / 工具类。

## Step 3: Slug 与 Artifact Handoff

选 kebab-case slug 贯穿全阶段。未指定时由首个派发角色命名并在头部声明。

Artifact 链：

```
analyst   → 写 analyze/[slug].md
architect → 读 analyze/[slug].md；写 design-docs/[slug].md
            可选 exec-plans/active/[slug]-plan.md / api-docs/[slug].md
            追加 decision-log.md DEC
developer → 读 design-docs + exec-plan；写 src/ + tests/
            报告 exec-plan checkbox 更新（orchestrator 写入）
            完成时请求 orchestrator 把 exec-plan active/ → completed/
tester    → 读 src + design-docs；写 tests/
            中/大任务：写 testing/[slug].md
            业务 bug：escalate（绝不改 src/*）
reviewer  → 读 src / design-docs / decision-log
            命中 critical_modules 或 Critical 时写 reviews/[date]-[slug].md
dba       → 读 migrations / schema / src
            变更大或 Critical 时写 reviews/[date]-db-[slug].md
closeout  → 汇总 reviewer / dba findings
            用户驱动 commit / PR / amend
```

---

## Step 3.4: Dispatch Mode Selection

每次 `Task` 派发前按序评估 `run_in_background`（第一匹配胜出）：

1. **用户声明**：prompt 含 `@roundtable:<role> bg|fg` / "后台派 <role>" / "前台派 <role>" 等中英文等价 → 按声明
2. **并行度**：本 assistant message 内 Task 调用数
   - 单发 → `false`（对齐 Claude Code 默认）
   - 并行批 ≥2 → 全部 `true`
3. **模糊兜底** → `AskUserQuestion` fg / bg 两选。同轮待决 ≥2 fuzzy 决策时走 §Step 4b 判定是否批量 AskUserQuestion。

前置：Step 4 并行判定必须先行，其结论是步骤 2 的输入。选完进入 §3.5.0 gate。

---

## Step 3.5: Progress Monitor Setup

每个 `run_in_background: true` 的 `Task` 派发配一次 `Monitor` 调用，让用户实时看 phase 级进度。

### 3.5.0 前台 / 后台派发 gate

**对每个 `Task` 调用独立评估**（混合并行批逐一判定）：

- **`run_in_background: true`** → 后台派发；主会话**看不到** subagent 内部。Monitor 是唯一进度通道。**进入 §3.5.1**
- **`run_in_background` 缺省 / `false`** → 前台派发；主会话阻塞等 Task 且子 agent 工具调用以缩进实时回显。Monitor 冗余。**skip 整个 Step**：不生成 `progress_path`、不启 Monitor、不注入 4 变量。Subagent 收到空 `progress_path` 按 fallback 静默降级。

Developer inline form（§6b.3）根本不发 `Task`，也不进入本 Step。

### 3.5.1 Opt-out + Bash 准备

`ROUNDTABLE_PROGRESS_DISABLE=1` → 完全 skip 本 Step（同 §3.5.0 skip 语义）。否则每次 `Task` 派发**之前**跑一次 Bash（每派发一次；不跨派发复用）：

```bash
DISPATCH_ID=$(openssl rand -hex 4 2>/dev/null || date +%s%N | sha1sum | head -c 8)
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%s)-$$}"
PROGRESS_PATH="/tmp/roundtable-progress/${SESSION_ID}-${DISPATCH_ID}.jsonl"
mkdir -p "$(dirname "$PROGRESS_PATH")" && touch "$PROGRESS_PATH"
echo "DISPATCH_ID=$DISPATCH_ID"; echo "PROGRESS_PATH=$PROGRESS_PATH"
```

`touch` 让 `tail -F` 从非空 inode 启动避免 race。

### 3.5.2 Monitor 启动

Bash 捕获 `DISPATCH_ID` / `PROGRESS_PATH` 后立即启动：

```
Monitor script: "tail -F ${PROGRESS_PATH} 2>/dev/null | jq -R --unbuffered -c 'fromjson? | select(.event) | \"[\" + .phase + \"] \" + .role + \" \" + .event + \" — \" + .summary' | awk 'BEGIN{last=\"\";n=0} {if($0==last){n++} else {if(n>1) print last\" (x\"n\")\"; else if(last!=\"\") print last; last=$0; n=1} fflush()} END{if(n>1) print last\" (x\"n\")\"; else if(last!=\"\") print last}'"
```

关键点：`tail -F` 大写（文件短暂消失不退出）；`jq --unbuffered` 逐行刷出；`-R | fromjson?` 容错单行解析错误（否则畸形行 exit 4 杀 Monitor —— 详见 `docs/testing/subagent-progress-and-execution-model.md` Case 1.2）；`select(.event)` 过滤残缺行；尾部 awk 只折叠**连续**重复行（DEC-007 §3.4 兜底，不全局 uniq）。

若 orchestrator 未加载 `Monitor` schema 需先 `ToolSearch` 取回。

### 3.5.3 4 变量注入

派发的每个 `Task` prompt 必须注入（除 Step 0 常规 context 外）：

| 变量 | 来源 |
|------|------|
| `progress_path` | `$PROGRESS_PATH` |
| `dispatch_id` | `$DISPATCH_ID` |
| `slug` | Step 3 的 slug |
| `role` | 被派发角色名 |

### 3.5.4 Lifecycle + Parallel-safety

Task 返回后 `tail -F` 空闲，默认任其自然过期（可 `MonitorStop` 显式停）。Progress 文件依赖 OS tmpfiles 清理（DEC-004 §3.5），plugin 不 gc。并行派发 4 条件天然满足（独立 DISPATCH_ID → 独立 PROGRESS_PATH → 独立 Monitor）。

---

## Step 4: 并行派发判定树

下列条件**全部**成立才可并行（任一失败则串行）：

1. **PREREQ MET** — 两候选 exec-plan 前置均已就绪
2. **PATH DISJOINT** — 写入文件集合不相交
3. **SUCCESS-SIGNAL INDEPENDENT** — 各有独立成功信号
4. **RESOURCE SAFE** — 不触发 rate limit / lockfile / 共享工具单 writer 约束

**默认串行。** 仅 4 条全满足 **且**加速效果显著（>30%）才升并行。并行时同一 assistant message 内发全部 Task 调用。

**Exec-plan checkbox 写入保持串行**：即便并行派发，orchestrator 依然代写 checkbox 避免对 exec-plan markdown 的 race。

## Step 4b: Decision Parallelism Judgment

适用范围 = orchestrator 顶层 fuzzy 决策（Size / Dispatch mode / Developer form 三点）。**Step 4 = Task 派发并行；Step 4b = 决策并行**，两者正交。不含 architect skill 阶段 1 单问 / subagent escalation / B 类 design-confirm / A 类 producer-pause 菜单（DEC-013 §3.1.1 / DEC-006 保留串行）。

下列 4 条件**全部**成立才可把 2+ 决策合并为单次 `AskUserQuestion({questions: [...]})` 调用（任一失败则串行）：

| 条件 | 语义 |
|------|------|
| 1. INPUT INDEPENDENT | 决策 A 的输入不依赖决策 B 的答 |
| 2. OPTION SPACE DISJOINT | 决策 A 的 option 集合与 B 不重叠语义（不是同一决策的拆问） |
| 3. RESPONSE PARSABLE SEPARATELY | 用户回复能 per-question 解析（label 唯一不跨问歧义） |
| 4. NO HIDDEN ORDER LOCK | 没有「决策 A 答了才揭示 B 选项」的动态生成依赖 |

**默认串行。** 仅 4 条件全满足**且**同轮待决 ≥2 才升并行。

**上限**：`max_concurrent_decisions = 3`（硬编码常量；先保守，需要时改到 4 或 5）。**溢出行为**：同轮待决 > 3 时前 3 合并批量，第 4+ 串行续跑下一批（避免 split 3+1 / 全串行 / drop 丢决策的歧义）。

**失败处理**：用户回复 per-question 解析；匹配失败 / 模糊 / cancel 的 decision 单独降级重问，不回滚已答决策（ref design-doc §3.2）。**跨问聚合回复**（`都选推荐` / `all A` / `都 go`）：(a) `都选推荐` / `都按推荐` / `all recommended` → 每 question 独立匹配 recommended label，任一 question 缺 recommended 则整句走 §3.6 歧义澄清；(b) `都 A` / `all A` 仅当每 question 都存在 A label 且不跨问歧义时批量解析，否则降级逐问重问。**歧义重问上限 = 3（DEC-021 Refines DEC-016 §3.2）**：per-question 降级后走 `docs/design-docs/decision-mode-switch.md` §3.6 层级澄清，orchestrator **每 question 独立计数**歧义重问轮次；第 1-3 轮按 §3.6 层级澄清（不变）；**第 4 轮**开始 orchestrator emit 审计行 `🔴 halt: q<n> ambiguity retry exhausted after 3 rounds`（`<n>` = batch 内 question 1-based 索引，与 fallback 块 id `batch-<slug>-<n>-q<m>` 的 `<m>` 对齐），停止该 question 的 `AskUserQuestion` / `<decision-needed>` 重问，skill-level fallback 交回主会话等用户**自由文本**（非弹窗）继续；其他已答 / 未耗尽的 question 不受影响，沿用 D3=A per-decision 语义。计数器 session 内维护，跨 session 不持久化。审计行按 §Step 5b 事件类 e 规则（markdownv2 粗体单条 reply）转发 active channel。

**Text mode 批量形态**（`decision_mode=text`）：批量决策渲染为多个 `<decision-needed id="batch-<slug>-<n>">` 块同一 response emit（终端 stdout），每块独立 id，用户一次回复含 N 个答（ref §3.4）。**`batch_id` 格式 = `batch-<slug>-<n>`**：`<slug>` 为当前 workflow slug（Step 3），`<n>` 为十进制单调递增整数从 1 起，每次新批量决策 +1（跨 session 不持久化，session 内唯一）；详见 `docs/design-docs/parallel-decisions.md` §3.4。**Active channel 转发**（DEC-018）：每块独立 pretty markdownv2 reply（语义等价；保留 `id` / `question` / `option label` 三字段），不合并单 payload；raw YAML 不转发。**与 DEC-013 §3.1.1 正交**：§3.1.1 "多块串行 emit" 保留于 Step 5 subagent escalation 与 architect skill 阶段 1 跨决策；§Step 4b 的 "多块同 response emit" 仅作用于本节枚举的 orchestrator 顶层 fuzzy 决策三点。**不可**把 §3.4 倒灌回 escalation 场景。

**Auto_mode**：批量 decision 所有 question 全部含 `recommended: true` → 合并单 auto-pick 审计行（Step 6.9 §Auto-pick batch 行 + Step 5b 事件类 e 批量围栏）；任一缺 recommended → 整组降级 halt。**runtime cancel 不受 auto 控制**：用户在 modal 里部分 cancel，走 D3=A per-decision 路径（已答推进，cancel 的单独重问）。

**Auto-halt text-mode fallback 渲染**（DEC-020；`decision_mode=text` + `auto_mode=true` + batch 任一缺 recommended）：
- **Render 顺序 audit-first**：orchestrator 先 emit `🔴 auto-halt batch-<id>: no recommended option at [q_k, ...]` 审计行，后 emit N 个 fallback `<decision-needed>` 块（DEC-013 §3.1.1 多块串行语义）
- **转发 fan-out 1 audit + N blocks**：active channel sticky 下，audit 行按 §Step 5b 事件类 e 规则单条 `markdownv2` 粗体 reply；N 个 `<decision-needed>` 块按 §3.1a（DEC-018 pretty 松弛）逐块独立 pretty markdownv2 reply，保留 `id` / `question` / `option label` 三字段不改写。共 `1 + N` reply，不合并单 payload
- **Fallback 块 id 格式**：`batch-<slug>-<n>-q<m>`（hyphen-suffix 保 batch id 根部；`<m>` = batch 内 question 1-based 索引；`batch-<slug>-<n>-` 可单 grep 拉齐整组）

## Step 5: Subagent Escalation

agent 的 final report 出现 `<escalation>` block 时 orchestrator 必须：

1. **Parse** JSON（`type` / `question` / `context` / `options` / `remaining_work`）
2. **`auto_mode=true` 时先走 §Auto-pick 通用规则**（优先于 decision_mode 判定）：命中 recommended → auto-pick 注入重派；无 recommended → auto-halt fallback 步骤 3
3. **按 `decision_mode` 分支**：
   - `modal` → 调 `AskUserQuestion` 带 options；每选项 description 含 `rationale` + `tradeoff`；`recommended: true` 用 `★` 标记附 `why_recommended`
   - `text` → 渲染 `<decision-needed id="esc-<slug>-<n>">` 块到对话流（canonical schema 见 design-doc §3.1）；options 行 `<letter>（★ 推荐）：<label> — <rationale> / <tradeoff>`（无推荐省 `（★ 推荐）`）；渲染前校验 option 必填字段，缺失时用 `(未提供)` 占位不静默丢弃；**多 escalation 串行 emit**（§3.1.1）；emit 后 pause 等用户自由文本回复；orchestrator LLM fuzzy 解析（`A` / `选 A` / `go with A` / `选 B 但加 X` 皆可），歧义按 §3.6 层级澄清
     - **Active channel forwarding**（DEC-013 §3.1a，DEC-018 松弛为语义等价）：若本 session inbound prompt 含 `<channel source="<plugin>:<name>" chat_id="..." ...>` 标签，或该 channel 的 reply 工具在本 session 内曾调用过（sticky 语义，不按轮次窗口衰减），每次 emit `<decision-needed>` 块**必须**同步调该 channel reply 工具转发**语义等价**的 pretty 渲染——人类可读 markdownv2 结构化（粗体 question 标题 / A-B-C option 行含 `★` 推荐标识 / rationale / tradeoff 缩进 bullet / 末尾小字 id footer 作 debug 锚点），保留 `id` / `question` / `option label` 三字段不改写（防 LLM 漂移）。**不再转发 raw YAML 块**——终端 stdout 仍 emit 原 `<decision-needed>` YAML 供 orchestrator fuzzy parse 与日志回放，TG/remote channel 只收 pretty 渲染。检测不到远程 channel（纯终端 session）→ 不调 reply，行为与现状一致。只在 emit `<decision-needed>` 时触发，普通对话 / phase summary / FAQ 不在本规则范围（out of scope，另议）。
4. **用户回答后**（或 auto-pick 注入后）：决策事实注入 prompt 重派**同一个** agent，scope 限 `remaining_work`
5. **绝不替用户决策**；agent 未给 recommended 时不擅自选（auto_mode 下走 auto-halt 路径，见 §Auto-pick）

Parsing 规则：每派发最多 1 个 block（多个说明 scope 粗糙，拆任务）；格式错回传 agent 重 emit 不转给用户；区分 **escalation**（继续未阻塞工作）vs **abort**（停下修派发）。

## Step 5b: Phase & Audit Forwarding

**触发条件**（与 §3.1a sticky 语义同）：session inbound prompt 含 `<channel source="<plugin>:<name>" chat_id="..." ...>` 标签 OR 该 channel reply 工具在本 session 内曾调用过 → orchestrator 对以下 5 类事件**必须**同步调 channel reply 工具转发。纯终端 session 不触发，行为同现状。

**转发事件类**（与 §3.1a `<decision-needed>` 转发规则**并存不冲突**）：

| 类 | 事件 | 来源 | 格式 |
|---|------|------|------|
| a | Step 0 context detection 结果 + Step 1 size/pipeline 判定 | orchestrator Step 0/1 | `markdownv2` 结构化：粗体标题 + 反引号字段值 + bullet 清单（DEC-022） |
| b | A 类 producer-pause 3 行 summary（`✅ <role> 完成 / 产出 / go \| 调 \| 问 \| 停`）| Step 6.1 A 类 | `markdownv2`：粗体标题 + 反引号路径 + 反引号操作词 |
| b-9 | **Stage 9 Closeout bundle 特例**：3 section `=== commit message === / === PR body === / === follow-up issues ===` 可 >3500 字符 | Step 6.1 A 类 Stage 9 变体 | ``` 围栏零转义整体包裹；若 >3500 chars 拆 2-3 reply（commit 独立 / PR body 独立 / issues 独立），避免超 TG Bot API 4096 字符上限 |
| c | Role completion final report digest（≤200 字；超长引 `docs/...` 路径，全文不转发）| 角色 subagent/inline 返回后 orchestrator 提取 | `markdownv2`：粗体标题 + bullet 产出清单 + 可选 findings |
| d | C 类 verification-chain 交接一行（`🔄 X 完成 → dispatching Y (critical_modules hit: [...])`）| Step 6.1 C 类 | `markdownv2`：粗体角色名 + 反引号 critical_modules |
| e | auto_mode 4 audit 事件（`🟢 auto-go` / `🟢 auto-accept` / `🟢 auto-pick` / `🔴 auto-halt`）| §Auto-pick 触发点 | `markdownv2` 单行 或 多事件 ``` 批量围栏。batch auto-pick 事件合并单 ``` 围栏；非 batch 单事件仍 markdownv2 粗体。**DEC-020 auto-halt text fallback**：batch 缺 recommended 触发 auto-halt 时，audit 行 markdownv2 单行 reply 先发，随后 N 个 `<decision-needed id="batch-<slug>-<n>-q<m>">` 块按 §3.1a 逐块独立 pretty markdownv2 reply（共 `1 + N` reply，不合并）。|

**不转发**：普通对话 / FAQ / 调试输出 / subagent 工具调用 echo / 用户无决策价值的内部状态。

**格式原则**（TG 可读性增强）：纯 YAML / 纯键值批量 → ``` 代码围栏零转义；混合 prose + 字段 → `markdownv2` 结构化（粗体标题 / 反引号包裹路径与字段 / bullet 清单）。

**与 DEC-013 决定 8 边界**：转发仍是 orchestrator 内部动作，不硬编码前端。不改 skill/agent prompt 本体（§3.1a 原有 forwarding 规则 —— `commands/workflow.md` Step 5 text 分支 / `skills/architect/SKILL.md` text 段 / `skills/analyst/SKILL.md` text 段 共 3 处 prompt 本体 —— 继续生效）。详见 `docs/design-docs/tg-forwarding-expansion.md`。

**Ordering / 批次规则**（F2 澄清）：同一 transition 可同时触发多事件（如 C handoff 时 c+d，若 `auto_mode=true` 再叠 e）。规则：
- 事件类 c（digest）**独立 reply**（信息密度高，粗体标题 + bullet 不能被其他事件冲散）
- 事件类 d + e 若同 tick 触发 → 合并一条 `markdownv2` reply（首行 auto audit，第二行 `🔄` handoff）
- 事件类 a + Step 1 size 判定 **合并为单次** `markdownv2` reply 转发（若中途用户 FAQ 插入则 Step 1 判定另发）
- 事件类 b 独立（A 类 producer-pause 3 行模板自成一体）

**格式按事件类硬绑定**（F4 澄清）：以表格格式列为准（a=b=c=d=markdownv2 结构化 / b-9=围栏长文本拆包 / e=单事件 markdownv2 或批量围栏）。「纯 YAML vs 混合 prose」仅为回退启发式，事件类已明定时无需临场判断。

**字 = Unicode codepoint**（F3 澄清）：`len(s)` 计数，非字节、非汉字。超长截断优先保留 **产出路径清单**（反引号路径 + 1 句描述），其次 findings；若仍 >200 → 仅转发 `详见 <docs_root>/...` 单行引用。

**Sticky 语义**（F5/F10 澄清）：`<channel>` tag 出现**一次**即永久 sticky（全生命周期，不随轮次衰减）；reply 工具调用史是 OR 的另一路径而非唯一；多 channel 并存各自独立 sticky，事件广播到所有已 sticky 的 channel。

## Step 6: 执行规则

**1. Phase gating 分类** —— 每个 transition 归入 A / B / C 之一，完整 rationale 见 `{docs_root}/design-docs/phase-transition-rhythm.md`。

- **A. producer-pause** —— 阶段以用户可消费产物结尾。Orchestrator 给 summary 并**停下不调用任何工具**等用户下一条；**菜单穷举 + 禁止 silent default**：
  ```
  ✅ <role> 完成。
  产出：
  - <path1> — <desc>
  请阅读后告诉我：
    `go`（或 role-specific 变体；见下）
    `问: <具体疑问>`（回答后回到本菜单，可多轮）
    `调: <扩展或收窄 scope>`
    `停`
  ```
  **用户驱动**：
  - `go` / `继续`：推进下一阶段（architect 变体见下）
  - `问: ...`：orchestrator 回派**同一** skill 回答 FAQ，skill 返回后 orchestrator **重新 emit** 本菜单等用户下一条（**Q&A 循环**直到 `go` / `调` / `停`；单轮不足以覆盖用户充分澄清的信息价值）
  - `调: ...`：以扩展 scope 重派
  - `停`：中止

  **architect 阶段变体**（Stage 3 完成后，Stage 4 B 类 gate 之前）：`go` **必须拆**两条可见 option，属 **exec-plan 产出决定**，与 Stage 4 Accept/Modify/Reject B 类决策**正交**：
  - `go-with-plan` **★ 推荐（recommended: true）**：写 `exec-plans/active/[slug]-plan.md` 后进入 Stage 4（Stage 4 B 类 Accept/Modify/Reject 照常）
  - `go-without-plan: <理由>`：跳过 exec-plan 直接进入 Stage 4；理由必填 1-2 句（典型：bug fix / UI 微调 / 决策全在 DEC 已闭合 / 任务足够小），orchestrator 落盘到 `log.md` 条目（prefix `decide`；**不**回写 architect 已 Accepted 的 design-doc 以免违反 architect Resource Access Write 边界）
  - fuzzy 降级：用户只输 `go` → orchestrator 按 Step 1 size 判定：**size=中/大** → 保守默认 `go-with-plan`；**size=小** → `AskUserQuestion` 二选（不直接降级，避免掩盖用户 skip 意图）

  **Stage 9 Closeout 变体**（A 类终点，无 producer skill；issue #26 + #30）：

  用户 `问: ...` 由 orchestrator 直接回答（查 design-doc / DEC / review / testing artifacts），非 skill 回派；循环同上。

  **Closeout bundle 协议**：用户 `go` 触发 orchestrator emit **closeout bundle**（3 section）：
  1. **commit message 建议**（Conventional Commits 格式 `<type>(<scope>): <summary> (#N)` + body + `Fixes #N` footer + `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`）
  2. **PR body 草稿**（Summary / Fix / Quality gates `lint / tester / reviewer / critical_modules` / Follow-ups / `Fixes #N` / Claude Code footer）
  3. **follow-up issues 草稿**（从 tester/reviewer/dba final message 提取 non-blocking Warning+Suggestion；英文 title ≤70 + P2 for Warning / P3 for Suggestion + body 自动 ref 本 PR 与源 finding）

  bundle emit 后**再次 pause** 等用户：
  - `go-all`：执行全部（git commit + push + gh pr create + gh issue create 循环）
  - `go-commit` / `go-pr` / `go-issues`：分别执行
  - `skip-pr` / `skip-issues`：精细跳过
  - `调: ...`：修改某 section（如 `调: commit scope=bugfix`）
  - `停`：中止保留本地修改不 commit

  **memory `feedback_no_auto_push` / `feedback_no_auto_pr` 硬边界**：只在用户显式 `go-*` 时执行 git/gh 操作；`auto_mode=true` **不**授权跳过本 closeout pause —— auto_mode 下仍需用户说 `go` / `go-all`（memory 硬边界优先于 §Auto-pick）。详见 `docs/design-docs/closeout-spec.md`。

  **Q&A 循环边界**：每轮 skill 回派仅回答 FAQ 不重跑 Phase 0 context detection（session 记忆复用）；软上限 5 轮后 orchestrator 提示"已 5 轮 FAQ，是否 `go` / `调` / `停`？"（不强制截断，仅提醒）；skill 每轮 `log_entries:` 上报由 orchestrator Step 8 **合并**（同 slug 同 prefix `analyze` 跨轮 union files / append notes）。

  **菜单穷举原则**：列全可能动作；"跳过某产出" = deliberate choice 必须显式说理 + 落盘；禁止 silent default。**转发**：active channel 下按 Step 5b 事件类 b 转发（`markdownv2` 结构化）。

- **B. approval-gate** —— 强方向性锁。**唯一** B 类是 Design confirmation（Stage 4）。按 Option Schema 调 `AskUserQuestion`（Accept / Modify ... / Reject），每选项带 `rationale` + `tradeoff` + 可选 `recommended`。

- **C. verification-chain** —— 内部交接自动推进，emit 一行 `🔄 X 完成 → dispatching Y (critical_modules hit: [...])`。`critical_modules` 驱动的强制派发仍属 C（CLAUDE.md 已预授权）。Critical findings / `<escalation>` / lint+test 失败立即打断走 Step 5。**发 C 类交接前必须扫 final message `<escalation>` 标签**；存在则暂停自动推进走 Step 5。**转发**：active channel 下先按 Step 5b 事件类 c 独立 reply 转发 role completion digest（≤200 Unicode codepoints），再按事件类 d（与同 tick 触发的 e 合并）转发。Stage 1 Context 已由事件类 a 覆盖，不再重发 d（避免与首次 `🔄` 重叠）。

`auto_mode=true` 下 A / B / 内部决策点行为改走 §Auto-pick 通用规则（C 类不受影响）。

**Phase Matrix → category 映射**：1 Context = C；2 Research / 3 Design / 9 Closeout = **A**；4 Design confirmation = **B**；5-8 Implementation / Adversarial / Review / DB = C。

**2. In-phase 决策**：运行中的 skill 遇决策点**立即** `AskUserQuestion`，不批量攒问。

**3. plan-then-execute**：architect 三阶段；developer / tester 中大任务编码前输出计划让用户确认。

**4. 角色形态**：
- `architect` / `analyst` = **skill**（主会话；`AskUserQuestion` 可用）
- `developer` / `tester` / `reviewer` / `dba` = **agent**（subagent；`AskUserQuestion` 不可用）

**5. developer 完成后**：跑 `lint_cmd` + `test_cmd`；失败报告用户，不静默重派修复。

**6. Tester 发现业务 bug**：tester 写复现测试 + `<escalation>` 上报，不改 src；orchestrator 报告用户，用户决定派 bug-fix（典型 `/roundtable:bugfix`）。

**7. Escalation**：见 Step 5。

**8. 不自动 git**：`commit` / `push` / `branch` / `tag` / `reset` / `stash` / `git add` 只在用户显式要求时执行。

**9. §Auto-pick 通用规则**（`auto_mode=true` 下 A/B/内部决策点唯一权威规范）：

| 触发点 | 事件（`auto_mode=on` 后缀省略） | 条件 |
|--------|---------|------|
| A 类 producer-pause（Stage 2/3/9）| `🟢 auto-go <role> ✅` | 无条件，不 pause 自动推进（Step 8 触发点 2 的 flush 照常）|
| B 类 approval-gate（Stage 4）| `🟢 auto-accept <role> design (recommended: <label>)` | options 含 `recommended: true` |
| Step 5 Subagent Escalation / Step 1 规模 / Step 6b per-dispatch form | `🟢 auto-pick <context> (why: <why_recommended>)` | 同上；`<context>` 为 `letter <label>` / `size=X` / `form=Y` 等 |
| §Step 4b 批量 orchestrator 决策 | `🟢 auto-pick batch <batch_id>: [<q1_label>, <q2_label>, ...]`（`<batch_id>` 格式见 §Step 4b `batch-<slug>-<n>`）| 所有 question 全部含 `recommended: true` |
| 以上任一决策点无 `recommended` | `🔴 auto-halt: no recommended option at <decision_id>` | fallback 沿用 `auto_mode=false` 原渲染（按 `decision_mode` 走 modal `AskUserQuestion` / text `<decision-needed>`）|
| C 类 verification-chain | —— | `auto_mode` 不影响；本就自动推进；critical_modules 派发 / tester hard regression / lint+test failure 打断保持 |

`recommended: true` 即 agent/skill 在设计阶段的**预授权**，auto-pick 沿用预授权不等同替用户挑（与 Step 5 步骤 5 "绝不替用户决策" 自洽）。

**批量决策「全或全无」**：§Step 4b 批量 auto-pick 要求 batch 内所有 question 全部含 `recommended: true`；任一缺 recommended → 整组 auto-halt（拒混合 auto-pick/halt，审计一致）。

**Stage 9 Closeout bundle 例外**：`auto_mode=true` 下 A 类 auto-go 规则**不适用** Stage 9 Closeout 的 git/gh 执行动作（commit / push / PR create / issue create）—— memory `feedback_no_auto_push` / `feedback_no_auto_pr` 是硬边界，优先于 §Auto-pick；仍需用户显式 `go` / `go-all` 才执行。auto_mode 只 auto-推进 **bundle 生成**（即 orchestrator 自动起草 commit msg / PR body / issue drafts），不 auto-执行。

**转发**：表内 4 auto_mode 事件在 active channel 下**必须**按 Step 5b 事件类 e 转发（单事件 `markdownv2` 粗体 emoji，多事件批量 ``` 围栏）。

---

## Step 6b: Developer Form Selection

Developer 支持 `subagent`（默认）和 `inline`。tester/reviewer/dba/research 保持 subagent-only。本 Step 在每次 developer 派发**之前**执行。

**三级切换**（按序评估，第一个匹配胜出）：

1. **Per-session（用户 prompt）**：`@roundtable:developer inline`、`developer 用 inline` 等 → 强制 `form = inline`
2. **Per-project（target CLAUDE.md）**：`# 多角色工作流配置` 里的可选 `developer_form_default: inline | subagent` 作为 baseline（per-session 仍覆盖）
3. **Per-dispatch（AskUserQuestion）**：前两条都不适用时，按 architect Option Schema 调 `AskUserQuestion`。小任务启发式（单文件 / bug hotfix / wall time <2min / token <20k / 单模块内）命中 → `inline` = recommended；否则 → `subagent` = recommended。用户回答即最终。`auto_mode=true` 见 §Auto-pick。同轮待决 ≥2 fuzzy 决策时走 §Step 4b 判定是否批量 AskUserQuestion。

**执行路径**：

- **Form = `inline`**：orchestrator `Read` `agents/developer.md` 在主会话执行（同 architect/analyst 机制）；`AskUserQuestion` 直接可用；**skip Step 3.5**（无 progress）；Resource Access 约束与 subagent 一致。
- **Form = `subagent`**：先执行 Step 3.5；`Task` 派发带 4 progress 变量。

**audit trail**：form 解析为 `inline` 时在 phase-gate summary 加一行 `Developer dispatched inline (trigger: <per-session | per-project | per-dispatch>)`。

**tester / reviewer / dba / research**：CLAUDE.md 里 `developer_form_default` **只**对 developer 生效，其他角色的同类 key 忽略（DEC-005 边界 —— 对抗性 / 审查 / DB fan-out 的大 context 永远走 `Task`）。

---

## Step 7: Index Maintenance（批量）

角色在 `{docs_root}/`（`analyze/` / `design-docs/` / `exec-plans/` / `api-docs/` / `testing/` / `reviews/` / `bugfixes/`）创建新 artifact 时，`{docs_root}/INDEX.md` 维护归 orchestrator（shared-resource 转发）。

**Batching**：不每次 subagent 返回就更新；phase 内累积，**每个 phase gate 一次** Edit（或 workflow 结束）。

**DEC-006 C 链过桥**：C 类无 phase-gate summary；orchestrator 在每次 C→C 交接提示**之前**执行 Step 7（单次 Read + Edit）。下一个 A 类 / Stage 9 终点 flush 覆盖剩余。

**步骤**：
1. **Collect**：角色 final report 在 `created:` section 列出新建文件
2. **Aggregate**：phase 内累积所有 `created[]` 路径
3. **Sync + Edit**：phase-gate 前 `Read` 一次 `INDEX.md`，按类别识别并 append 到对应 `### <category>` subsection（不存在则创建），一次 `Edit` 覆盖全部
4. **Report**：summary 加「INDEX.md updated with N new entries」

**条目格式**：`- [<file>](<rel-path>) — <one-line description>`（来源：frontmatter `description:` → report `description:` → 引言首句）

**角色 report 契约**：
```
created:
  - path: {docs_root}/design-docs/feature-x.md
    description: Feature X design
```

**单一产出字段原则**：`created:` 是 final report **新建文件**清单的**唯一机读源**；`log_entries.files[]` 可额外包含 **修改**文件（两者互补非冗余：`created[]` → INDEX.md / `log_entries.files[]` → log.md），不要求字面 equal。Step 6.1 A 类模板的 `产出：` 行**归 orchestrator 生成**（基于 `created[].path` + `description`）；角色**禁止**在 final message 自写 `产出:` / `Outputs:` 自然语言文件清单（避免与 orchestrator 侧重复）。`tests/*` / `src/*` 代码文件不进 `created:`（INDEX.md 只识 `docs/` 6 类），归 git log。

Fallback：`/roundtable:lint` 周期性审计 orphan。**角色从不自行编辑 `INDEX.md`**。

**Orchestrator Relay Write（主路径；DEC-017；触发与 frontmatter 规则收紧 DEC-019）**：reviewer / tester / dba 不 Write 归档 .md；orchestrator 按触发条件**代写**对应 artifact。

**触发条件**（任一成立即 relay；判定源 = 派发 context 与 subagent final message 字面匹配，**不**采 subagent 自述升级）：
- reviewer / dba subagent 派发命中 `critical_modules`
- subagent final message 出现 **Critical finding**（识别规则：`## Critical` section 非空——至少一条 bullet，排除纯 `无。` / `(无)` / `(空)` 占位 **OR** 正文同段/相邻段出现 emoji `🔴` + 单词 `critical`（大小写不敏感）；纯自然语言散文引用 `critical` 不触发）
- 用户派发 prompt 明示要求归档（白名单 OR 匹配：zh `归档` / `落盘` / `sink`；en `archive`；匹配源仅限**用户 prompt 正文**，subagent 自述"应归档 / 建议归档 / 本次是关键改动"**不**触发）
- tester 触发：`critical_modules 命中 OR (size ∈ {medium, large} AND 需产出测试计划)` —— critical_modules 命中时始终 relay（无论 size）；非命中时仅在 medium/large 且有测试计划产出时 relay

**Relay contract**：
1. **Content 源**：subagent final message 正文（去除 `<escalation>` block）作为 artifact body；**若正文以 `---\n` 开头且含闭合 `\n---\n` frontmatter block，先剥离该 block 再作 body**（避免双 frontmatter）；frontmatter 由 orchestrator 补并为权威（`slug` / `source` / `created: YYYY-MM-DD` / `reviewer` 或 `tester` 字段）
2. **Path**：reviewer → `{docs_root}/reviews/[YYYY-MM-DD]-[slug].md`；tester → `{docs_root}/testing/[slug].md`；dba → `{docs_root}/reviews/[YYYY-MM-DD]-db-[slug].md`
3. **自造 `created:` YAML**：orchestrator 生成 INDEX.md 条目时使用；description 取报告 `## 总结` / `## 审查结论` 首句，缺失则用 `[slug] review/testing (orchestrator relay)`
4. **自造 `log_entries:` YAML**：`prefix: review`（或 `test-plan` for tester / `db-review` for dba，issue #67 DEC-017 修订）；`操作者: orchestrator (relay for <role>)`；`files: [relay artifact path]`；`note` 末尾加 `(orchestrator relay)`
5. **不触发**：非 critical_modules 且 subagent 判定对话返回即可的常规场景 → subagent 对话返回，orchestrator 不 relay
6. **Write 失败 UX**（fail-fast，无自动重试）：orchestrator 执行 relay Write 失败（permission / disk / path 冲突等）时，final summary 顶部明示 `⚠️ relay Write failed: <path> (<reason>)`；subagent final message 正文（已剥 frontmatter / `<escalation>`）原文附本响应末尾作 fallback；人工救场路径提示：`复制正文至 <path>`。同时 orchestrator 在 Step 8 log_entries 追加一条 `prefix: fix` / `note: relay-write-failure <path> (<reason>) (orchestrator relay)`（`files:` 留空或填目标路径），供事后审计。此条不改 INDEX.md（无成功落盘）

---

## Step 8: log.md Batching

agent / skill **不直接写 `{docs_root}/log.md`** —— 在 final message 用 `log_entries:` YAML block 上报，orchestrator 聚合并 flush。与 Step 7 同构（shared-resource 转发）。

**Flush 触发点**（3 种）：
1. **Stage 9 Closeout 之前**（终点 flush）—— 覆盖 Stage 1-8 全部
2. **每次 A 类转场之前**（producer-pause 或 `auto_mode=on` 下的 auto-go；analyst ✅ / architect ✅ / Stage 9）—— best-effort pause-point flush，降跨 session 中断风险
3. **每次 C 类 verification-chain 交接之前** —— 沿用 Step 7 过桥条款；发 "🔄 X → Y" 前单次 Read + Edit flush

**Step 7 / Step 8 同时触发时**：先 Step 7（可能新增 `reviews/...` 入 INDEX），再 Step 8（log_entries `files:` 可引用新路径）。

**Flush 步骤**（单次 Read + Edit）：
1. **Collect**：解析各 `log_entries:` YAML 入内存 queue
2. **Merge**：同 agent 同轮多 entry 合并一条；`files:` union；`note:` 取首条
3. **Read + Edit**：`Read` `{docs_root}/log.md`；定位头部 "# 操作日志" 引言与"前缀规范"之间的 `---`；按倒序 insert 合并条目块：

   ```markdown
   ## [prefix] | [slug] | [YYYY-MM-DD]
   - 操作者: [agent 名 / 用户 / orchestrator]
   - 影响文件: [path1, path2, ...]
   - 说明: [一句话]
   ```

   **`fix-rootcause` 扩展**：`analysis:` 原样缩进渲染为 `- 分析:` 多行块；`tier==2` 时追加 `- 关联 postmortem: {docs_root}/bugfixes/[slug].md` 行。
   合并取首条非空 `analysis`（不拼接）。
4. **Report**：summary 加 `log.md flushed N new entries`

**YAML 契约**（agent/skill 上报格式）：

```yaml
log_entries:
  - prefix: analyze | design | decide | exec-plan | review | test-plan | lint | fix | fix-rootcause
    slug: [slug]
    files: [docs/path/..., ...]
    note: [一句话]
    # optional: analysis (仅 fix-rootcause 前缀；多行根因+修复+复现；见 `commands/bugfix.md` 及 `docs/log.md` §条目格式)
```

一次 dispatch 可 0~N 条。前缀必在 `{docs_root}/log.md` §前缀规范 表内。

**跨 session abort 退化**：用户直接退出（未说"停"）→ 最近一段未 pause-point flush 的 C 链 log_entries 丢失；缓解靠触发点 2。详见 `docs/design-docs/lightweight-review.md` §2.2.3。

---

## 起点

1. Step 0（inline context detection）
2. Step 1（规模判定；模糊 `AskUserQuestion`）
3. 初始化 Phase Matrix（全部 ⏳）
4. 按规模 pipeline 激活 / 派发第一个角色
5. 每次 phase transition 更新 matrix 并报告
6. 从每个角色 report 累积 `created:` 路径（Step 7 phase-gate / C 过桥 / 终点 flush）
7. 从每个角色 report 累积 `log_entries:` YAML（Step 8 同 3 触发点 flush）
8. 遵守 Step 6 规则

**本 command 只做编排** —— 不自己设计 / 编码 / 审查；所有实质性工作派发给合适的角色。
