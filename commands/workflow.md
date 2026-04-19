---
description: Multi-role AI workflow orchestrator. Selects a path among analyst / architect / developer / tester / reviewer / dba based on task size.
argument-hint: <task description>
---

# 多角色工作流

你正在为下列任务编排多角色协作：

**任务**：$ARGUMENTS

---

## 执行前提

目标项目必须遵循 roundtable 的 docs 布局（`design-docs/`、`exec-plans/active/`、`analyze/`、`testing/`、`reviews/`、`decision-log.md`、`log.md`）。缺失的子目录在需要的角色首次写入时自动创建；orchestrator 向用户报告创建动作。

---

## Phase Matrix

在整个派发生命周期内维护本 matrix。每次 phase 切换、以及用户主动询问进度时，都要把它重新报告给用户。

| 阶段 | 角色 | 状态 | 产出 |
|-------|------|--------|-----------|
| 1. Context detection | （inline，本 command） | ⏳ / 🔄 / ✅ | `target_project`、`docs_root`、`lint_cmd`、`test_cmd`、`critical_modules`、`design_ref` |
| 2. Research（可选） | analyst skill | ⏳ / 🔄 / ✅ / ⏩ skipped | `{docs_root}/analyze/[slug].md` |
| 3. Design | architect skill | ⏳ / 🔄 / ✅ | `{docs_root}/design-docs/[slug].md`、`decision-log.md` DEC 条目，可选 `{docs_root}/exec-plans/active/[slug]-plan.md`，可选 `{docs_root}/api-docs/[slug].md` |
| 4. Design confirmation | （用户） | ⏳ / 🔄 / ✅ | 用户确认 |
| 5. Implementation | developer agent（一或多个） | ⏳ / 🔄 / ✅ | `src/` 代码、`tests/` 测试、exec-plan checkbox（由 orchestrator 基于 dev 报告写入） |
| 6. Adversarial testing | tester agent | ⏳ / 🔄 / ✅ / ⏩ skipped | 测试代码、`{docs_root}/testing/[slug].md`、通过 escalation 报出的 bug |
| 7. Review | reviewer agent | ⏳ / 🔄 / ✅ / ⏩ skipped | 对话形式反馈或 `{docs_root}/reviews/[YYYY-MM-DD]-[slug].md` |
| 8. DB review（涉及 DB 时） | dba agent | ⏳ / 🔄 / ✅ / ⏩ N/A | 对话形式反馈或 `{docs_root}/reviews/[YYYY-MM-DD]-db-[slug].md` |
| 9. Closeout | （用户） | ⏳ / 🔄 / ✅ | 汇总 findings；由用户驱动 commit / PR / amend 决策（DEC-006 producer-pause，workflow 终点） |

图例：⏳ 待办 · 🔄 进行中 · ✅ 完成 · ⏩ skipped（附原因）· — 不适用

**实时进度流（matrix 下方）**：当前活跃的 subagent 派发产生的 progress 通知按 DEC-004 的 `[<phase>] <role> <event> — <summary>` 格式实时出现在此。该流独立于 matrix 列语义，不是 matrix 的一列，而是由 Step 3.5 启动的 `Monitor` 工具驱动的 append-only 中继。每条通知来自某个 subagent `## Progress Reporting` 的 emit；多个并行派发按 `dispatch_id` 交织。

---

## Step 0: Project Context Detection

**必须 inline 执行 4 步检测** —— 不要用 `Skill` 工具去激活 `_detect-project-context`。该文件是 markdown 辅助文档，含检测流程；turn 开始时先 `Read` 它并直接按 4 步执行，结果存入 session 记忆。

4 步（详见 `skills/_detect-project-context.md`）：

1. **target-project 识别（D9）**：session 记忆 → `git rev-parse --show-toplevel` → 扫描 CWD 下含 `.git/` 的子目录 → 正则匹配任务描述 → `AskUserQuestion` 兜底。
2. **Toolchain detection**：扫描 target-project 根的 `Cargo.toml` / `package.json` / `pyproject.toml` / `go.mod` / `Move.toml`；推导默认 `lint_cmd` 和 `test_cmd`。
3. **docs_root detection**：`docs/` → `documentation/` → `AskUserQuestion` 默认「创建 `docs/`」。
4. **CLAUDE.md loading**：读取 `# 多角色工作流配置` section 的 `critical_modules`、`设计参考`、`工具链覆盖`、`条件触发规则`。CLAUDE.md 值覆盖自动检测结果。

后续派发的任何角色都**必须**在 prompt 里注入以下检测输出：
- `target_project`（绝对路径）
- `docs_root`
- `primary_lang`、`lint_cmd`、`test_cmd`
- `critical_modules`（数组）
- `design_ref`（数组，供 architect / analyst 使用）
- `slug`（一旦分配）

绝不让 subagent 自己重跑检测。

---

## Step 1: 任务规模判定

读完任务描述 + 目标项目 `CLAUDE.md` 后决定。

| 规模 | 信号 | Pipeline |
|------|--------|----------|
| **小** | Bug fix、单文件微调、UI 样式、文档编辑 | 建议走 `/roundtable:bugfix` 或直接 `@roundtable:developer` |
| **中** | 新功能、模块变更、局部业务逻辑 | analyst（可选）→ architect → design-confirm → developer → tester（若涉及 critical）→ reviewer（可选） |
| **大** | 新模块、跨组件、架构性变动 | analyst → architect → design-confirm → developer → tester → reviewer |

涉及 DB 的变更（schema / migration / SQL）：developer 之后再派发 `@roundtable:dba`。

规模模糊时，按 architect 的 Option Schema 用 `AskUserQuestion` 弹出 medium / large 两选项，每项含 `rationale` + `tradeoff`。

---

## Step 2: Tester 触发规则

从注入的 CLAUDE.md 摘要里读 `critical_modules`。任务命中任一列出的模块或关键词时，**developer 之后必须派发 tester**。

通用兜底（CLAUDE.md 未声明 `critical_modules` 时）：
- 资金 / 账户 / 权限判断
- 性能敏感热路径（benchmark gated）
- 并发 / 锁 / 事务边界
- 安全相关（签名验证 / 输入校验 / 权限检查）
- 外部系统集成（DB / 消息队列 / 支付 / 身份）

可选触发 tester：中大型功能的 E2E 场景、前端关键交互流。

跳过 tester：bug fix（developer 已补回归）、UI 样式、文档更新、非关键工具类。

---

## Step 3: Slug 与 Artifact Handoff

选一个 kebab-case slug 贯穿所有阶段。用户未指定时，由首个派发的角色命名，并在输出头部声明。

Artifact 链条：

```
analyst   → 写 {docs_root}/analyze/[slug].md
architect → 读 analyze/[slug].md
            写 design-docs/[slug].md
            可选：exec-plans/active/[slug]-plan.md
            可选：api-docs/[slug].md
            追加 decision-log.md 的 DEC 条目
developer → 读 design-docs/[slug].md + exec-plans/active/[slug]-plan.md
            写 src/ 和 tests/
            向 orchestrator 报告 exec-plan checkbox 更新；由 orchestrator 写入
            功能全部完成时：请求 orchestrator 把 exec-plan 从
            active/ 移动到 completed/
tester    → 读 src/ 和 design-docs/[slug].md
            写 tests/（对抗性 / E2E / benchmark）
            中 / 大任务：写 testing/[slug].md
            业务 bug：escalate（绝不改 src/*）
reviewer  → 读 src / design-docs / decision-log
            默认：对话形式的 findings
            命中 critical_modules 或出现 Critical findings 时
            写 reviews/[YYYY-MM-DD]-[slug].md
dba       → 读 migrations / schema / src
            默认：对话形式的 findings
            变更较大或出现 Critical 时
            写 reviews/[YYYY-MM-DD]-db-[slug].md
closeout  → 汇总 reviewer / dba 输出中的 findings
            不产出新文件
            由用户驱动 commit / PR / amend 决策（DEC-006 A producer-pause）
```

---

## Step 3.5: Progress Monitor Setup（DEC-004；触发规则由 DEC-008 修订）

每个 `run_in_background: true` 的 `Task` 派发都配一次 `Monitor` 调用，让用户在主会话实时看到 phase 级进度。**本 Step 在每次这类后台 `Task` 派发前执行**（developer subagent / tester / reviewer / dba / research fan-out），与上方 Phase Matrix 的列语义相互独立。

**工具说明**：下方反引号里的 `Monitor` 是 Claude Code 原生工具（v2.1.98+）。orchestrator 如未加载其 schema，必须先 `ToolSearch` 取回 `Monitor` 的 schema 再执行本 Step。`Monitor` 把后台进程的 stdout 行以 notification 形式流回主会话。

### 3.5.0 前台 / 后台派发 gate（DEC-008）

在执行下方任何子步骤前，先检查即将发起的 `Task` 调用的 `run_in_background` 参数。**此 gate 对每个 `Task` 调用独立评估** —— 混合并行批（例如同一 assistant message 里 1 个前台 + 2 个后台 `Task` 调用）按调用逐一判定，最终产出 2 个 `progress_path` / 2 个 Monitor 实例，而非 3 个。

- **`run_in_background: true`**（后台派发）—— 主会话**不**阻塞，**完全看不到** subagent 的中间工具调用。Monitor 是唯一的 phase 级进度通道。**对该调用执行下方其余子步骤。**
- **`run_in_background` 缺省 / `false`**（前台派发，Claude Code 当前默认）—— 主会话阻塞等 Task 结果，且子 agent 每次 Bash/Read/Edit/Write 工具调用都以缩进形式实时回显到主会话输出。Monitor 在这种情况下是重复信号。**对该调用 skip 整个 Step**：不生成 `progress_path`、不跑 §3.5.2 的 Bash 准备、不启动 §3.5.3 的 Monitor、不向派发 prompt 注入 §3.5.4 的 4 个 progress 变量。Subagent 收到空 `progress_path` 时按各自 `## Progress Reporting` fallback 条款静默降级为「no emit」。

Rationale：DEC-004 §3.1 motivation（"orchestrator LLM 对 subagent 内部系统性不可见"）只对后台派发严格成立；前台派发下缩进工具流就是主要观察通道，Monitor 沦为冗余第二路信号。详见 DEC-008 与 `docs/design-docs/subagent-progress-and-execution-model.md` §3.8。

注：Developer inline form（§6b.3）是另一条 skip 路径 —— 它根本不发起 `Task`，也就不会进入本 Step。§3.5.0 严格只作用于走 `Task` 派发的 subagent。

### 3.5.1 Opt-out check

读取环境变量 `ROUNDTABLE_PROGRESS_DISABLE`。若其值为 `1`，则完全 skip 本 Step：不生成 `progress_path`、不启动 `Monitor`、不向派发 prompt 注入 4 个 progress 变量。Subagent 收到空 `progress_path` 时按各自 `## Progress Reporting` fallback 条款静默降级为「no emit」（符合 DEC-004 §3.2「missed emit degrades to silent, not worse than current」）。

### 3.5.2 Per-dispatch Bash preparation

每次 `Task` 派发**之前**执行下面这段 Bash（每个派发一次 Bash 调用，**不要**跨派发复用路径）：

```bash
# 8-hex dispatch_id（优先 openssl；无 openssl 时回落到 ts+nanos 的 sha1）
DISPATCH_ID=$(openssl rand -hex 4 2>/dev/null || date +%s%N | sha1sum | head -c 8)

# session_id：优先用 Claude Code 注入的环境变量；回落到 unix ts + pid 保证唯一
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%s)-$$}"

# 进度文件路径；每次派发一个文件，并行派发之间天然不相交
PROGRESS_PATH="/tmp/roundtable-progress/${SESSION_ID}-${DISPATCH_ID}.jsonl"

# 创建目录并 touch 文件，让 `tail -F` 从干净状态开始
mkdir -p "$(dirname "$PROGRESS_PATH")" && touch "$PROGRESS_PATH"

# 导出变量供后续步骤注入
echo "DISPATCH_ID=$DISPATCH_ID"
echo "PROGRESS_PATH=$PROGRESS_PATH"
```

从 Bash 输出里捕获 `DISPATCH_ID` 和 `PROGRESS_PATH`；Step 3.5.3 和 3.5.4 都要用。

### 3.5.3 启动 Monitor

Bash 准备完成后立即启动 `Monitor`：

```
Monitor script: "tail -F ${PROGRESS_PATH} 2>/dev/null | jq -R --unbuffered -c 'fromjson? | select(.event) | \"[\" + .phase + \"] \" + .role + \" \" + .event + \" — \" + .summary' | awk 'BEGIN{last=\"\";n=0} {if($0==last){n++} else {if(n>1) print last\" (x\"n\")\"; else if(last!=\"\") print last; last=$0; n=1} fflush()} END{if(n>1) print last\" (x\"n\")\"; else if(last!=\"\") print last}'"
```

注意事项：
- `tail -F`（大写 F）在文件短暂不存在时不会退出，文件被 truncate 时会重新打开。
- `jq --unbuffered` 破解 pipe 缓冲，使每个 JSONL 行作为独立 notification 刷出。没有 `--unbuffered` 时，jq 可能批处理行、让用户可见的中继延迟数秒。
- **`-R` + `fromjson?`（必需的容错）**：`-R` 按 raw string 读每行，`fromjson?` 尝试解析；`?` 吞掉单行解析错误，使不可解析的输入（乱码 debug 输出、磁盘压力下的截断写、并发交织）被静默跳过，而不是整个 pipe 中止。没有它，单个畸形行就会让 jq 以 exit 4 退出、静默杀掉 Monitor，后续事件全部丢失。失效模式详见 `docs/testing/subagent-progress-and-execution-model.md` Case 1.2 / 1.2b。
- `select(.event)` 进一步过滤掉「JSON 合法但缺 `event` 字段」的残缺行。
- **awk consecutive-collapse 过滤（DEC-007 §3.4 底层保障）**：尾部 awk 只折叠**连续**相同行（不是全局 uniq）；防范源端飘移，同时不会误伤「被其他事件分隔的重复 phase 标签」这一合法情形。当一段 ≥2 行的连续相同内容结束时，emit `<line> (xN)`；每次 print 后 `fflush()` 保留逐行交付给 Claude Code Monitor 的语义（与上游 `--unbuffered` 意图一致）。DEC-007 的源端 content policy（写在各 agent 的 `## Progress Reporting → Content Policy`）是主防线；awk 层是廉价的安全网。
- 格式化后的输出即 Phase Matrix 下方所说的「实时进度流」行。

### 3.5.4 向 Task prompt 注入 4 个变量

Step 3.5.3 之后派发的每个 `Task` 调用**必须**在 subagent prompt 里注入以下 4 个变量（在 Step 0 的常规 context 变量之外）：

| 变量 | 来源 | subagent 用途 |
|------|------|----------------|
| `progress_path` | Step 3.5.2 的 `$PROGRESS_PATH` | 在每个 phase 边界 `Bash echo '{...}' >> {{progress_path}}` |
| `dispatch_id` | Step 3.5.2 的 `$DISPATCH_ID` | 作为 `dispatch_id` JSON 字段出现在每条 emit |
| `slug` | Step 3（Slug + Artifact Handoff） | 作为 `slug` JSON 字段 |
| `role` | 被派发的 subagent 角色（`developer` / `tester` / `reviewer` / `dba` / `research`） | 作为 `role` JSON 字段 |

subagent 的 `## Progress Reporting` section 处理 emit 格式；orchestrator 只负责注入这 4 个变量。

### 3.5.5 生命周期与清理

- `Monitor` 在派发期间后台运行。`Task` 调用返回后 `tail -F` 空闲（无新写入）；Monitor 实例可让其自然过期，或者在 orchestrator 即将派发下一个 subagent 希望保持干净通道时用 `MonitorStop` 显式停掉。默认策略：任其自然过期。
- Progress 文件累积在 `/tmp/roundtable-progress/`；依赖 OS tmpfiles.d 清理（DEC-004 §3.5）。Plugin 本身不做 gc。

### 3.5.6 并行派发安全性

按 DEC-004 §3.7 和 DEC-002 §4 并行派发规则，每个并行 `Task` 都有自己的 `DISPATCH_ID` → 自己的 `PROGRESS_PATH` → 自己的 `Monitor`。并行判定树的 4 个条件全部成立：

1. **PREREQ MET** —— progress 文件只 append，无需任何预先状态。
2. **PATH DISJOINT** —— 按派发的文件名（`${SESSION_ID}-${DISPATCH_ID}.jsonl`）保证不相交。
3. **SUCCESS-SIGNAL INDEPENDENT** —— 每个 `Monitor` 监视独立文件；其 notification 归属唯一 `dispatch_id`。
4. **RESOURCE SAFE** —— `/tmp/roundtable-progress/` 无共享锁；并发 `tail -F` 不同文件在 OS 层面安全。

因此，并行派发在用户的进度流里产生交织 notification，每条都带 `role` 前缀和 `phase` 标签 —— `dispatch_id` 在底层 JSONL 里保留用于 debug / audit，但默认格式不渲染。

---

## Step 4: 并行派发判定树

当下列条件**全部**成立时，orchestrator **可以**并行派发多个 subagent；任一条件失败则串行派发。

1. **PREREQ MET** —— 两个候选的 exec-plan `前置` 均已就绪（前置阶段完成或产物已在位）。
2. **PATH DISJOINT** —— 候选写入的文件集合不相交（例如一个阶段写 `moduleA/`、另一个写 `moduleB/`，路径无重叠）。
3. **SUCCESS-SIGNAL INDEPENDENT** —— 每个候选有各自独立的成功信号（lint / test checkpoint），不依赖对方产出。
4. **RESOURCE SAFE** —— 合并的并行工作不会触发 rate limit、lockfile 或共享工具的 single-writer 约束（例如测试 DB 同一时刻只能一个进程持有）。

默认策略：串行。仅当 4 条规则全部满足**且**加速效果显著（预期时间节省 > 30%）时升级为并行。

并行派发时：在同一 assistant message 里发出所有 Task 调用，让它们并发运行。

**Exec-plan checkbox 写入保持串行。**即便并行派发，orchestrator 依然负责把 checkbox 写回 plan 文件。Developer 在 final message 报告已完成项，orchestrator 来更新文件。这避免了对共享 exec-plan markdown 的 race。

---

## Step 5: Subagent Escalation 处理

Subagent 在 Task sandbox 内无法调用 `AskUserQuestion`。当 agent 的 final report 出现 `<escalation>` block 时，orchestrator **必须**：

1. **Parse** JSON block（`type` / `question` / `context` / `options` / `remaining_work`）。
2. **调用 `AskUserQuestion`** 带上这些 options。每个选项 description 携带 `rationale` + `tradeoff`。`recommended: true` 的选项用 `★` 标记并附 `why_recommended` 原因。
3. **用户回答后**：用决策事实注入 prompt 重新派发**同一个** agent，scope 限定为 escalation 里列出的 `remaining_work`。
4. **绝不替用户决策。** 如果 agent 未给出 recommended option，不要擅自选 —— 把决策直接转给用户。

Parsing 规则：
- 每个派发最多一个 `<escalation>` block。出现多个说明派发 scope 粗糙；拆任务。
- 若 block 格式不对（缺必填字段），把错误回传给 agent 要求重新给出修正后的 block；**先不要**转给用户。
- 区分 **escalation**（预期用户输入；同时继续未阻塞的工作）与 **abort**（缺前置条件；停下并修派发）。

block 格式见各 agent 的 `## Escalation Protocol` section。

---

## Step 6: 执行规则

1. **Phase gating 分类（DEC-006）**：每个 phase transition 归入三类之一；gating 行为由类别决定。

   - **A. producer-pause** —— phase 以用户可消费产物作为结尾。阶段：Research（analyst）/ Design（architect Draft）/ Closeout（Stage 9）。Orchestrator 给出 3 行 summary 并**停下，不再调用任何工具**，等待用户下一条消息：
     ```
     ✅ <role> 完成。
     产出：
     - <path1> — <desc>
     - <path2> — <desc>
     请阅读后告诉我：`go` / `调范围: ...` / 问题
     ```
     用户通过自由文本驱动推进：`go` / `继续` 推进；`问: …` 留在 FAQ（orchestrator 直接回答，或按该角色惯例追加到 artifact 的 FAQ section）；`调: …` 在同一 slug 下以扩展的 scope 重新派发同一角色；`停` 中止 workflow，Phase Matrix 停留在当前阶段。

   - **B. approval-gate** —— 强方向性锁。**唯一**的 B 类 transition 是 Design confirmation（Stage 4）。Orchestrator **必须**按 Option Schema（`feedback_askuserquestion_options`）调用 `AskUserQuestion` 给出选项：Accept / Modify <具体部分> / Reject / 等等。每个选项带 `rationale` + `tradeoff` + 可选的 `recommended`。用户选择决定是推进到 Implementation、重新派发 architect，还是 abort。

   - **C. verification-chain** —— 内部机器 / AI 交接，无用户决策点。阶段：context-detect → analyst、design-confirm accepted → developer、developer → tester、tester → reviewer、reviewer → closeout、dba → closeout。Orchestrator **自动推进**，emit 一行交接提示（如 `🔄 developer 完成 → dispatching tester (critical_modules hit: [...])`）。`critical_modules` 驱动的强制 tester / reviewer 派发仍属 C 类（机械性动作，CLAUDE.md 已预先授权；交接提示中加注 `(critical_modules hit: ...)` 以保持透明）。Critical findings / `<escalation>` block / lint+test 失败依然按 Step 5 和 Step 6 第 5–6 条立即打断。在发出 C 类交接提示前，orchestrator **必须**扫描 subagent final message 中的 `<escalation>` 标签；若存在则暂停自动推进，走 Step 5。

   **Phase Matrix → category 映射**：

   | 阶段 | 角色 | 类别 |
   |---|---|---|
   | 1. Context detection | inline | C |
   | 2. Research | analyst | A |
   | 3. Design | architect | A |
   | 4. Design confirmation | user | **B** |
   | 5. Implementation | developer | C |
   | 6. Adversarial testing | tester | C |
   | 7. Review | reviewer | C |
   | 8. DB review | dba | C |
   | 9. Closeout | user | A |

   完整 rationale 见 `{docs_root}/design-docs/phase-transition-rhythm.md` 和 DEC-006。

2. **In-phase 决策**：正在运行的 skill 遇到用户决策点时，**立即**按该 skill 的 `## AskUserQuestion Option Schema` 调用 `AskUserQuestion`。不要把决策攒起来批量问。

3. **plan-then-execute**：
   - **architect**：三阶段流（explore → land design-docs → 可选 exec-plan）。见 `skills/architect.md`。
   - **developer**：中 / 大任务在编码前输出实现计划让用户确认（小任务可跳过）。
   - **tester**：中 / 大任务在编码前输出测试计划让用户确认（小任务可跳过）。

4. **角色形态**：
   - `architect` / `analyst` 是 **skill**（主会话；可用 `AskUserQuestion`）—— 通过 `Skill` 工具激活。
   - `developer` / `tester` / `reviewer` / `dba` 是 **agent**（subagent 隔离；`AskUserQuestion` 不可用）—— 通过 `Task` 工具派发；每次派发 prompt 都注入 `target_project` / `docs_root` / `lint_cmd` / `test_cmd` / `critical_modules` / `slug` / `primary_lang`。

5. **developer 完成后**：对目标项目跑 `lint_cmd` 和 `test_cmd`。失败时向用户报告；orchestrator **不**静默重派修复。

6. **Tester 发现业务 bug**：tester 写复现测试、通过 `<escalation>` 上报，**不**修业务代码。Orchestrator 把 bug 报告给用户，由用户决定是否派发 bug-fix 子派发（典型通过 `/roundtable:bugfix`）。

7. **处理 escalation**：见 Step 5。

8. **不自动执行 git 操作**：`git commit` / `push` / `branch` / `tag` / `reset` / `stash` 只在用户显式要求时执行。默认：所有改动留在 working tree。Staging（`git add`）同样由用户触发。

---

## Step 6b: Developer Form Selection（DEC-005）

按 DEC-005，`developer` 角色支持两种执行形态：`subagent`（DEC-001 D8 默认）和 `inline`（在主会话 inline 执行 `agents/developer.md`）。`tester` / `reviewer` / `dba` / `research` 保持 subagent-only（DEC-005 明确不把 dual-form 推广给它们）。本 Step 在每次 developer 派发**之前**执行。

### 6b.1 默认形态

**默认 = `subagent`**（保留 DEC-001 D8 的 role→form 映射）。切到 `inline` 需要 §6b.2 三个触发条件之一命中。

### 6b.2 三级切换触发器（DEC-005 §3.4.2）

按顺序评估；第一个匹配的触发器胜出。

1. **Per-session（用户 prompt）** —— 用户当前任务描述、或本 session 内早期消息明确要求 inline：
   - 关键短语：`@roundtable:developer inline`、`developer 用 inline`、`this developer task inline`，或 orchestrator 能识别的等价自然语言。
   - 效果：本派发强制 `form = inline`。不走 AskUserQuestion。

2. **Per-project（target CLAUDE.md）** —— 读取 `# 多角色工作流配置` section（Step 0 已解析）里的可选 key：
   ```markdown
   developer_form_default: inline    # 或：subagent
   ```
   若存在，用其值作为 baseline。若缺失，baseline 保持 `subagent`。Per-session（level 1）仍然覆盖 per-project（level 2）。

3. **Per-dispatch（AskUserQuestion）** —— 前两条都不适用时，派发前调用 `AskUserQuestion`。按 architect 的 Option Schema 构造选项（`rationale` + `tradeoff` + `recommended`）。用「小任务信号」启发式选 recommended：
   - **小任务标志**（满足任一即可）：单文件改动、bug hotfix、预估 wall time < 2 min、预估总 token < 20k、严格限于一个模块内。
   - 命中小任务标志 → `inline` 选项设 `recommended: true`。
   - 否则 → `subagent` 选项设 `recommended: true`。

   选项示例 payload：
   ```
   Option A: inline
     rationale: "Small task (1 file, bug hotfix) — inline keeps decisions visible and AskUserQuestion available."
     tradeoff:  "Pollutes main-session context with developer's reads/edits."
     recommended: true   # 命中小任务标志时
   Option B: subagent
     rationale: "Isolates developer's context and enables parallel dispatch."
     tradeoff:  "Progress only via phase-level events (DEC-004); interactive decisions gated through <escalation>."
     recommended: true   # 任务不小时
   ```
   用户回答是最终决定；orchestrator 绝不覆盖用户选择。

### 6b.3 执行路径

`form` 决定后：

**Form = `inline`**（小 / 单文件 / hotfix 路径）：
- Orchestrator `Read` `agents/developer.md` 并**在主会话中**执行其指令（与 `architect` 和 `analyst` skill 相同机制）。
- `AskUserQuestion` 对 developer 流直接可用 —— 无需 `<escalation>` 间接路径。
- 本派发**不**执行 Step 3.5（无 `progress_path`、无 `Monitor`、不注入 4 变量）。主会话直接观察 developer 流；progress 中继是冗余。
- Resource Access 约束与 subagent 形态一致（`agents/developer.md` Resource Access matrix 原样适用；见 DEC-005 decision #7）。
- 不需要 `<escalation>` block；决策通过 inline 的 `AskUserQuestion` 完成。

**Form = `subagent`**（默认路径）：
- 先执行 Step 3.5（Progress Monitor Setup）。
- 用 `Task` 派发，subagent prompt 中带上 4 个 progress 注入变量以及 Step 0 的常规 context。
- Developer 的 `## Progress Reporting` section 处理 phase 边界 emit；`<escalation>` 按 Step 5 处理用户决策点。

### 6b.4 tester / reviewer / dba / research 保持 subagent-only

按 DEC-005，**不要**给 `tester`、`reviewer`、`dba`、`research` 提供 inline 形态：
- 它们的 context 体量大（对抗性测试套件 / 全仓审查 / 跨 schema DB 分析 / fan-out 调研），inline 执行会污染或耗尽主会话 context。
- 这 4 个角色永远走 `Task` 派发，永远从 Step 3.5 接收 4 个 progress 变量。
- CLAUDE.md 里的 `developer_form_default` 键**只**对 developer 生效。用户尝试给其他三个角色设同类 key 要忽略 —— 这是 DEC-005 边界。

### 6b.5 Form 选择的 audit trail

当 form 解析为 `inline` 时，在 phase-gate summary 里加一行：`Developer dispatched inline (trigger: <per-session | per-project | per-dispatch user choice>)`。这让用户知道本任务放宽了通常的 subagent 边界隔离。

---

## Step 7: Index Maintenance（批量）

当角色在 `{docs_root}/` 下（`analyze/` / `design-docs/` / `exec-plans/` / `api-docs/` / `testing/` / `reviews/`）创建新 artifact 时，`{docs_root}/INDEX.md` 的维护归 orchestrator。角色**不**直接编辑 `INDEX.md` —— 和 exec-plan checkbox 是同一类串行化模式（DEC-002 shared-resource protocol）。

**Batching 规则**：**不要**在每次 subagent 返回后都更新 `INDEX.md`。在 phase 内累积新文件报告，**每个 phase gate 更新一次** index（在给用户发 phase summary 之前），或者在 workflow 结束时更新。这样 token 开销被控制在"每 phase 一次 Read + Edit"，而非每 subagent 一次。

**DEC-006 C-verification-chain 过桥条款**：C 类 transition 自动推进，只有一行交接（无面向用户的 phase-gate summary）。为保持 `INDEX.md` 新鲜，orchestrator **必须**在每次 C→C 交接提示发出**之前**执行 Step 7（单次 Read + Edit）。下一个 A 类 producer-pause（包括 Stage 9 Closeout）时的最终 flush 覆盖所有仍待处理的条目。这在保持「每个边界单次 Edit」成本上限的同时，避免了长 C 链中出现 stale-index 窗口。

**步骤**：

1. **Collect**：每个角色的 final report **必须**在 `created:` section 下列出新建文件（不能只出现在散文里）。orchestrator 从每个 `Task` 结果和每个 skill 的 in-session 输出里解析。
2. **Aggregate**：在当前 phase 内累积所有并行 / 串行 subagent 的 `created[]` 路径。
3. **Sync**：向用户发 phase-gate summary 之前，`Read` 一次 `{docs_root}/INDEX.md`（文件大时用 `Grep` 找分类 section 锚点）。
4. **Update**：对每个新路径识别其类别（`analyze` / `design-docs` / `exec-plans/active` / `exec-plans/completed` / `testing` / `reviews` / `api-docs`），在对应 `### <category>` subsection 下 append 一行。若该 subsection 不存在则创建。
5. **Single Edit**：用一次 `Edit` 覆盖 phase 内所有 append。
6. **Report**：在 phase-gate summary 里加一句「`INDEX.md` updated with N new entries」。

**条目格式**：

```
- [<file>](<relative-path-from-INDEX.md>) — <one-line description>
```

description 来源优先级：artifact frontmatter 的 `description:` → 角色 report 的 `description:` 行 → artifact 引言首句。

**角色 report 契约**（`created:` section）：

```
created:
  - path: {docs_root}/design-docs/feature-x.md
    description: Feature X design (API shape + data model + rollout phases)
  - path: {docs_root}/testing/feature-x.md
    description: Adversarial / benchmark plan for feature-x (18 cases)
```

**Fallback**：`/roundtable:lint` 检测 INDEX 孤儿 / 断链，作为 Step 7 遗漏的兜底（周期性审计，不是创建时强约束）。

**Forbidden**：角色从不自行编辑 `INDEX.md` —— 写入始终由 orchestrator 按 DEC-002 转发。

---

## 起点

1. 执行 Step 0（inline，context detection）。
2. 执行 Step 1（任务规模判定）。模糊时 `AskUserQuestion`。
3. 初始化 Phase Matrix（全部 ⏳）。
4. 按规模 pipeline 激活 / 派发第一个角色。
5. 每次 phase transition 更新 matrix 并报告。
6. 从每个角色的 report 中累积 `created:` 路径；按 Step 7 在 phase gate 更新 `INDEX.md`。
7. 遵守 Step 6 的规则。

**本 command 只做编排 —— 它自己不做设计 / 编码 / 审查。所有实质性工作都派发给合适的角色。**
