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
| 9. Closeout | 用户 | ⏳/🔄/✅ | 汇总 findings；用户驱动 commit / PR / amend（DEC-006 producer-pause 终点） |

图例：⏳ 待办 · 🔄 进行中 · ✅ 完成 · ⏩ skipped · — 不适用

**实时进度流（matrix 下方）**：按 DEC-004 的 `[<phase>] <role> <event> — <summary>` 格式实时出现，由 Step 3.5 启动的 `Monitor` 驱动；多个并行派发按 `dispatch_id` 交织。

---

## Step 0: Project Context Detection

**inline 执行 4 步检测**：`Read` `${CLAUDE_PLUGIN_ROOT}/skills/_detect-project-context.md` 并直接按 4 步执行，结果存 session 记忆。

1. **target-project 识别（D9）**：session 记忆 → `git rev-parse --show-toplevel` → 扫描 CWD 下含 `.git/` 的子目录 → 正则匹配任务描述 → `AskUserQuestion` 兜底
2. **Toolchain detection**：扫 `Cargo.toml` / `package.json` / `pyproject.toml` / `go.mod` / `Move.toml`；推导默认 `lint_cmd` / `test_cmd`
3. **docs_root detection**：`docs/` → `documentation/` → `AskUserQuestion` 默认「创建 `docs/`」
4. **CLAUDE.md loading**：读 `# 多角色工作流配置` 的 `critical_modules` / `设计参考` / `工具链覆盖` / `条件触发规则`（CLAUDE.md 覆盖自动检测）

后续派发**必须**注入：`target_project` / `docs_root` / `primary_lang` / `lint_cmd` / `test_cmd` / `critical_modules` / `design_ref` / `slug`。绝不让 subagent 自己重跑。

## Step 1: 任务规模判定

| 规模 | 信号 | Pipeline |
|------|------|---------|
| **小** | Bug fix / 单文件 / UI / 文档 | `/roundtable:bugfix` 或直接 `@roundtable:developer` |
| **中** | 新功能 / 模块变更 | analyst（可选）→ architect → design-confirm → developer → tester（若涉关键）→ reviewer（可选） |
| **大** | 新模块 / 跨组件 / 架构变动 | analyst → architect → design-confirm → developer → tester → reviewer |

涉 DB 变更：developer 后派发 `@roundtable:dba`。规模模糊时 `AskUserQuestion` medium/large 两选项（每项 `rationale` + `tradeoff`）。

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
            用户驱动 commit / PR / amend（DEC-006 A producer-pause）
```

---

## Step 3.4: Dispatch Mode Selection

每次 `Task` 派发前按序评估 `run_in_background`（第一匹配胜出）：

1. **用户声明**：prompt 含 `@roundtable:<role> bg|fg` / "后台派 <role>" / "前台派 <role>" 等中英文等价 → 按声明
2. **并行度**：本 assistant message 内 Task 调用数
   - 单发 → `false`（对齐 Claude Code 默认）
   - 并行批 ≥2 → 全部 `true`
3. **模糊兜底** → `AskUserQuestion` fg / bg 两选

前置：Step 4 并行判定必须先行，其结论是步骤 2 的输入。选完进入 §3.5.0 gate。

---

## Step 3.5: Progress Monitor Setup（DEC-004；触发 DEC-008）

每个 `run_in_background: true` 的 `Task` 派发配一次 `Monitor` 调用，让用户实时看 phase 级进度。

### 3.5.0 前台 / 后台派发 gate（DEC-008）

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

## Step 5: Subagent Escalation

agent 的 final report 出现 `<escalation>` block 时 orchestrator 必须：

1. **Parse** JSON（`type` / `question` / `context` / `options` / `remaining_work`）
2. **调 `AskUserQuestion`** 带 options；每选项 description 含 `rationale` + `tradeoff`；`recommended: true` 的用 `★` 标记并附 `why_recommended`
3. **用户回答后**：决策事实注入 prompt 重派**同一个** agent，scope 限 `remaining_work`
4. **绝不替用户决策**；agent 未给 recommended 时不擅自选

Parsing 规则：每派发最多 1 个 block（多个说明 scope 粗糙，拆任务）；格式错回传 agent 重 emit 不转给用户；区分 **escalation**（继续未阻塞工作）vs **abort**（停下修派发）。

## Step 6: 执行规则

**1. Phase gating 分类（DEC-006）** —— 每个 transition 归入 A / B / C 之一，完整 rationale 见 `{docs_root}/design-docs/phase-transition-rhythm.md`。

- **A. producer-pause** —— 阶段以用户可消费产物结尾。Orchestrator 给 3 行 summary 并**停下不调用任何工具**等用户下一条：
  ```
  ✅ <role> 完成。
  产出：
  - <path1> — <desc>
  请阅读后告诉我：`go` / `调范围: ...` / 问题
  ```
  用户驱动：`go`/`继续` 推进；`问: ...` 留 FAQ；`调: ...` 以扩展 scope 重派；`停` 中止。

- **B. approval-gate** —— 强方向性锁。**唯一** B 类是 Design confirmation（Stage 4）。按 Option Schema 调 `AskUserQuestion`（Accept / Modify ... / Reject），每选项带 `rationale` + `tradeoff` + 可选 `recommended`。

- **C. verification-chain** —— 内部交接自动推进，emit 一行 `🔄 X 完成 → dispatching Y (critical_modules hit: [...])`。`critical_modules` 驱动的强制派发仍属 C（CLAUDE.md 已预授权）。Critical findings / `<escalation>` / lint+test 失败立即打断走 Step 5。**发 C 类交接前必须扫 final message `<escalation>` 标签**；存在则暂停自动推进走 Step 5。

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

---

## Step 6b: Developer Form Selection（DEC-005）

Developer 支持 `subagent`（默认）和 `inline`。tester/reviewer/dba/research 保持 subagent-only。本 Step 在每次 developer 派发**之前**执行。

**三级切换**（按序评估，第一个匹配胜出）：

1. **Per-session（用户 prompt）**：`@roundtable:developer inline`、`developer 用 inline` 等 → 强制 `form = inline`
2. **Per-project（target CLAUDE.md）**：`# 多角色工作流配置` 里的可选 `developer_form_default: inline | subagent` 作为 baseline（per-session 仍覆盖）
3. **Per-dispatch（AskUserQuestion）**：前两条都不适用时，按 architect Option Schema 调 `AskUserQuestion`。小任务启发式（单文件 / bug hotfix / wall time <2min / token <20k / 单模块内）命中 → `inline` = recommended；否则 → `subagent` = recommended。用户回答即最终。

**执行路径**：

- **Form = `inline`**：orchestrator `Read` `agents/developer.md` 在主会话执行（同 architect/analyst 机制）；`AskUserQuestion` 直接可用；**skip Step 3.5**（无 progress）；Resource Access 约束与 subagent 一致。
- **Form = `subagent`**：先执行 Step 3.5；`Task` 派发带 4 progress 变量。

**audit trail**：form 解析为 `inline` 时在 phase-gate summary 加一行 `Developer dispatched inline (trigger: <per-session | per-project | per-dispatch>)`。

**tester / reviewer / dba / research**：CLAUDE.md 里 `developer_form_default` **只**对 developer 生效，其他角色的同类 key 忽略（DEC-005 边界 —— 对抗性 / 审查 / DB fan-out 的大 context 永远走 `Task`）。

---

## Step 7: Index Maintenance（批量）

角色在 `{docs_root}/`（`analyze/` / `design-docs/` / `exec-plans/` / `api-docs/` / `testing/` / `reviews/`）创建新 artifact 时，`{docs_root}/INDEX.md` 维护归 orchestrator（DEC-002 shared-resource 转发）。

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

Fallback：`/roundtable:lint` 周期性审计 orphan。**角色从不自行编辑 `INDEX.md`**。

---

## Step 8: log.md Batching（DEC-009 决定 2）

agent / skill **不直接写 `{docs_root}/log.md`** —— 在 final message 用 `log_entries:` YAML block 上报，orchestrator 聚合并 flush。与 Step 7 同构（shared-resource 转发）。

**Flush 触发点**（3 种）：
1. **Stage 9 Closeout 之前**（终点 flush）—— 覆盖 Stage 1-8 全部
2. **每次 A 类 producer-pause 转场之前**（analyst ✅ / architect ✅ / Stage 9）—— best-effort pause-point flush，降跨 session 中断风险
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
4. **Report**：summary 加 `log.md flushed N new entries`

**YAML 契约**（agent/skill 上报格式）：

```yaml
log_entries:
  - prefix: analyze | design | decide | exec-plan | review | test-plan | lint | fix
    slug: [slug]
    files: [docs/path/..., ...]
    note: [一句话]
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
