---
slug: subagent-progress-and-execution-model
source: design-docs/subagent-progress-and-execution-model.md
created: 2026-04-19
status: Test Complete
decisions: [DEC-004, DEC-005]
---

# issue #7 对抗性测试报告 — subagent 进度协议 + developer 双形态

> 本报告对 P0.1-P0.10 实施做对抗性验证。roundtable 是纯 prompt 包，无传统 unit test；所有验证通过 shell 脚本模拟 + 文档一致性审查 + 反例构造完成。
>
> **结论**：主路径（golden path）全部工作；发现 3 条实施缺陷（1 Critical Monitor pipeline 脆弱、1 Warning 模板可达 BSD 日期并发碰撞、1 Warning 漏模板 Bash fallback 守卫），其余 verdict 均为 PASS。

---

## 0. 摘要

| 维度 | Verdict 密度 | 备注 |
|------|-------------|------|
| Golden path（正常 JSONL / 正常 dispatch） | PASS | smoke 6 event 全过 |
| JSON schema 对抗 | 1 FAIL / 3 WARN / 2 PASS | jq 被单行非 JSON 击穿是 Critical |
| Monitor 启动模板 | 2 WARN / 3 PASS | BSD date fallback 碰撞 + mkdir 失败路径未处理 |
| Developer 双形态切换 | 1 WARN / 4 PASS | bugfix.md 规则 2 非对称（仅命中 subagent 值） |
| 正交性（progress / escalation / research-result） | PASS × 4 | 5 agent 的 Progress Reporting section 各 1 次 / Escalation Protocol 各 1 次 / schema 未污染 |
| Phase Matrix + 并行判定树 | PASS | §3.5.6 四条件复述与 Step 4 原文一致 |
| lint_cmd 回归 | PASS | 0 命中 |

**整体可部署信心：Medium-High**。设计意图与文档执行均落地；golden path 完全可用；critical 级缺陷集中在"单一损坏 JSONL 行杀掉整个 jq pipe"这个鲁棒性漏洞（虚警率较低但会让用户丢失后续全部 progress relay），强烈建议修复后再大规模 dogfood。

---

## 1. 对抗 checklist（完整表）

### 1.1 Progress event JSON schema 对抗

| # | Case | Setup | Expected | Actual | Verdict |
|---|------|-------|----------|--------|---------|
| 1.1 | Well-formed JSONL（baseline） | 2 条合规事件 → `jq select(.event)` | 2 条格式化输出 `[P0.1] developer phase_start — ...` | 2 条，完全匹配 §3.3 模板 | PASS |
| 1.2 | 单行非 JSON 混入 | 4 条：1 合规 + 1 纯文本 + 1 截断 JSON + 1 合规 → `jq --unbuffered -c 'select(.event) ...'` | jq 应跳过坏行，继续后续行 | **jq 在第 2 行直接 abort**（`parse error: Invalid literal at line 2`），exit code 4，后续合规行**全丢** | **FAIL (Critical)** |
| 1.2b | 实时 tail -F \| jq 被单行毒化 | 起 `tail -F` + `jq`，先 emit 1 合规 → 1 非 JSON → 2 合规 | 用户应看到 3 条合规（只丢坏行） | 用户只看到第 1 条，jq 死掉后 `tail -F` 仍写文件但 pipe 已断；后面 2 条**永久丢失** | **FAIL (Critical)** |
| 1.3 | 缺必需字段（无 phase / 无 event / 无 summary） | 三条各缺一字段 | `select(.event)` 过滤"无 event"；缺 phase/summary 应触发 jq null-concat 错误 | "缺 event" 被正确过滤（PASS）；"缺 phase" 输出 `"[] dev phase_start — no phase"`（垃圾行）；"缺 summary" 输出 `"[P0.1] dev phase_start — "` — 都 parse 成功但 UI 呈现破碎 | WARN |
| 1.4 | 超长 summary（500 字符，>120 上限） | 合法 JSON 但 summary 破 schema 建议值 | jq 可 parse；UX 层 swamp 主会话 | 500 字符全量输出（jq 无校验）；主会话 notification 被单行刷爆 | WARN |
| 1.5 | UTF-8 BOM + 空行 | 文件首有 BOM，若干空行散布于合规行间 | 理想：BOM 被剥离，空行被跳过 | jq 对 BOM **容忍**（无报错）；空行被 `select(.event)` 天然过滤 | PASS |
| 1.6 | 并发 append（两进程 × 50 行 × 128 字节） | 两 bash 子 shell 并行 `>> $F` | 100 行完整，无交错 | 100/100 完整（Linux `O_APPEND` 原子性生效） | PASS |
| 1.7 | 并发 append（两进程 × 30 行 × 5000 字节） | 两 bash 子 shell 并行，单行 >PIPE_BUF | POSIX 只保证 PIPE_BUF（4096）内原子；超出按 Linux 实现 | 60/60 完整（本 Linux kernel 更大原子段位，实测未交错）。**但 POSIX 不保证**；重负载或内核版本变化时可能交错 | WARN |

**Case 1.2 / 1.2b 决策建议**：在 Monitor 模板加入 `jq` 的 `--seq` 或管道内的行级容错预处理。例如：

```bash
tail -F "$PROGRESS_PATH" 2>/dev/null | \
  while IFS= read -r line; do
    echo "$line" | jq -c 'select(.event) | "[" + .phase + "] " + .role + " " + .event + " — " + .summary' 2>/dev/null
  done
```

或使用 `jq` 的错误容忍选项（如果版本支持）：`jq -R 'fromjson? | select(.event) | ...'`（`fromjson?` 让 parse 失败返回 null 被静默）。这样单行毒化不会拖垮整个 pipe。

### 1.2 Monitor 启动模板对抗

| # | Case | Setup | Expected | Actual | Verdict |
|---|------|-------|----------|--------|---------|
| 2.1 | openssl 缺失 fallback | 使用 `date +%s%N \| sha1sum \| head -c 8` | 8 位 hex id；时间分辨率足够分散 | Linux 上 20 次密集调用全 unique（PASS 于 Linux） | PASS (Linux) |
| 2.1b | BSD/macOS 下 `date +%s%N` fallback | BSD date 上 `%N` 是字面 `N`，输入变成 `1776583457N\n` | 同一秒内多次调用碰撞（字符串恒同 → sha1sum 恒同） | 三次调用全返回 `54d5d04f`。**同秒并发 Task dispatch 在 macOS 上会生成相同 dispatch_id** | **WARN (macOS 碰撞)** |
| 2.2 | `/tmp` 只读 / mkdir 失败 | `mkdir -p` && `touch` 失败后 | 应识别并 unset PROGRESS_PATH 不 inject | 模板只 `&&` 串联，失败时 Bash 退出 0（前面 echo 已成功），`PROGRESS_PATH` 值已 echo；orchestrator 仍会 inject 一个不可写路径；subagent 首次 `>> $PROGRESS_PATH` 报错 | **WARN (未处理失败)** |
| 2.3 | jq 未安装 | 模板 `tail -F ... \| jq ...`，jq 缺失 | 应 graceful degrade（Monitor 静默） | Monitor 提示 `command not found`；主会话 notification 通道死掉；**无 fallback 分支** | WARN |
| 2.4 | `ROUNDTABLE_PROGRESS_DISABLE=1` opt-out | orchestrator 识别 env | 跳过全部 Step 3.5；subagent 收到空 progress_path → §Fallback 静默 | workflow.md §3.5.1 明写此路径；subagent 的 §Fallback clause 也覆盖；但 **subagent 的 Bash 模板是 `echo '...' >> {{progress_path}}` 原样展开，若 `{{progress_path}}` 为空串，Bash 会报 `ambiguous redirect` 错误而非静默**。subagent LLM 必须"理解 fallback"并 guard 住 Bash 调用，**模板未给 `if [ -n "..." ]` 守卫** | **WARN (模板缺 Bash guard)** |
| 2.5 | session_id fallback `$(date +%s)-$$` 撞车 | 无 CLAUDE_SESSION_ID env 时 | 同秒同 PID 碰撞可能 | 同一会话内 `$$` 稳定（PID = orchestrator 自身），`date +%s` 同秒下相同 → session_id 相同；但 DISPATCH_ID 是 openssl 随机 → 实际 filename 几乎必不同。**跨进程同秒启动才会撞**（罕见） | PASS (低碰撞) |

**Case 2.1b 建议**：fallback 改为 `date +%s%N 2>/dev/null | sha1sum | head -c 8 || $(($RANDOM * $RANDOM)) | printf ...`，或直接 `awk 'BEGIN{srand(); printf "%08x", rand()*4294967296}'` 跨平台生成 8 hex。

**Case 2.2 建议**：模板追加 `mkdir -p ... && touch ... || { echo "PROGRESS_DISABLED=1"; unset PROGRESS_PATH; }`，orchestrator 识别 `PROGRESS_DISABLED` 时跳过 Monitor + 不 inject。

**Case 2.4 建议**：每个 agent 的 §Progress Reporting 补一段"守卫 Bash 模板"：

```bash
if [ -n "{{progress_path}}" ] && [ -w "{{progress_path}}" ]; then
  echo '{"ts":...}' >> "{{progress_path}}"
fi
```

### 1.3 Developer form 切换规则

| # | Case | Setup | Expected | Actual | Verdict |
|---|------|-------|----------|--------|---------|
| 3.1 | 三级优先级明确性 | per-session > per-project > per-dispatch | workflow.md §6b.2 "first matching trigger wins" | 原文明确标"Evaluate in order; the first matching trigger wins"，ordering 清晰 | PASS |
| 3.2 | `@roundtable:developer inline` 识别稳定性 | 6 种大小写 / 中英混写 / 自然语言变体 | 有 marker 词列表 + "natural-language equivalents" 兜底 | 识别完全依赖 LLM 判断；恶意 prompt `"do NOT use inline, run subagent"` 中 `inline` 子串可能被误匹配；**无确定性解析器** | WARN |
| 3.3 | CLAUDE.md `developer_form_default: inline` vs 用户 per-session | user 指定 subagent 时 | per-session 胜 | §6b.2 显式描述："per-session (level 1) still overrides per-project (level 2)"，三级明确 | PASS |
| 3.4 | AskUserQuestion Option Schema 合规性 | §6b.2 example 双 Option 均含 rationale/tradeoff/recommended | 符合 DEC-002 schema（至多 1 个 recommended） | 示例 block **两个 Option 都标 `recommended: true`**，用 `#` 注释分情况；若实施者按字面照搬，违反 DEC-002 "at most 1 recommended" | WARN |
| 3.5 | tester/reviewer/dba/research 被错误声明 inline | 用户写 `@roundtable:tester inline` | 硬拒（per DEC-005） | workflow.md §6b.4 明写 "remain subagent-only"、"Ignore any user attempt to set analogous keys for the other three roles"；**纪律清楚，但无硬性 parser；仍依赖 LLM 理解** | PASS (规则明确) |
| 3.6 | bugfix.md 规则 2 非对称 | CLAUDE.md 声明 `developer_form_default: inline` 且用户无显式声明 | rule 2 应命中（inline wins） | bugfix.md 原文："if ... declares `developer_form_default: subagent`, respect the project's declaration"——**仅列出 subagent 值**；declare `inline` 时规则 2 条件落空，fall through 到规则 3（AskUserQuestion）；**与 workflow.md 非对称**。**运行结果可能仍正确**（规则 3 + bugfix inline-bias → inline），但用户声明未被"一级命中" | **WARN (规则 2 非对称)** |

**Case 3.6 建议**：bugfix.md 规则 2 改为对称写法：`if target_project CLAUDE.md declares developer_form_default (either inline or subagent), honor the declaration—this overrides the bugfix inline-bias default.`

**Resolved by DEC-009 决定 9**（2026-04-19 bugfix.md 规则 2 改对称 honor；落地点 `commands/bugfix.md` Step 3 Developer Form Selection 规则 2）

**Case 3.4 建议**：example block 改为两套不同场景的 "if small task → [inline=recommended, subagent=notRecommended]；else → 反之"，避免单 block 内两 `recommended: true`。

### 1.4 正交性（progress vs escalation vs research-result）

| # | Case | Setup | Expected | Actual | Verdict |
|---|------|-------|----------|--------|---------|
| 4.1 | tester "phase_blocked 先于 escalation" | §Ordering discipline | 3 步：write test → emit phase_blocked → write escalation | tester.md §Ordering discipline 明写 3 步顺序，且带理由"Monitor sees the blocker BEFORE the final message parse begins" | PASS |
| 4.2 | reviewer Critical 级 ordering | §Critical-finding ordering | phase_blocked 先，review report + escalation 后 | reviewer.md §Critical-finding ordering 明写 MUST 顺序 1-2 步 | PASS |
| 4.3 | research progress 与 `<research-result>` 正交 | §Orthogonality | 两通道独立 | research.md §Orthogonality 有 channel/carrier/cardinality 三列表格，明确声明"two channels are independent and do not trigger each other" | PASS |
| 4.4 | dba "phase_blocked 先于 escalation" | 通用约定 | 同 tester/reviewer | dba.md §Progress Reporting 行 99：`"emit BEFORE writing the <escalation> block"`，但**无专门 subsection 讲 ordering discipline**（不如 tester/reviewer 清晰）；不过文字条款在位 | PASS (但较简略) |
| 4.5 | 每个 agent 的 Progress Reporting section 出现次数 | grep `^## Progress Reporting` | 各 1 次 | developer=1, tester=1, reviewer=1, dba=1, research=1 | PASS |
| 4.6 | Escalation Protocol section 未被污染 | grep `^## Escalation Protocol` | 各 1 次（research 用 Abort Criteria） | developer=1, tester=1, reviewer=1, dba=1, research Abort=1 | PASS |
| 4.7 | 5 agent 的 escalation JSON schema 一致 | diff 4 agents 的 block | fields 完全一致 | type / question / context / options[label,rationale,tradeoff,recommended] / remaining_work 完全相同（措辞小异不影响 schema） | PASS |
| 4.8 | 双通道独立性（同 dispatch progress + escalation） | 假设 subagent emit 5 progress lines + 1 final message 含 escalation | Monitor 走 /tmp 文件 stream；orchestrator parse final message 走 Task return；互不干扰 | 两通道物理隔离：progress → 临时文件；escalation → final message JSON block；**无共享 parser / 共享状态**；§3.6 正交矩阵明确 | PASS |

### 1.5 Phase Matrix + 并行判定树

| # | Case | Setup | Expected | Actual | Verdict |
|---|------|-------|----------|--------|---------|
| 5.1 | Step 3.5 插入不破坏 Step 4 四条件 | Step 4 原文（PREREQ MET / PATH DISJOINT / SUCCESS-SIGNAL INDEPENDENT / RESOURCE SAFE） | 四条件逐字保留 | Step 4 保留完整四条件；§3.5.6 复述与 Step 4 语义一致 | PASS |
| 5.2 | 并行 N 个 subagent 的 progress_path disjoint | 每 dispatch 独立 dispatch_id / session_id 组合 | filename 天然 disjoint | `/tmp/roundtable-progress/${SESSION_ID}-${DISPATCH_ID}.jsonl` 按 dispatch_id 8 hex 命名，openssl 随机，碰撞概率 1/2³² ≈ 安全 | PASS |
| 5.3 | Phase Matrix 引用 progress stream | grep "Real-time progress stream" | 新增一段说明"非矩阵列，是 append-only relay" | workflow.md 行 37 有完整描述 | PASS |
| 5.4 | Step 编号连续性 | grep `^## Step` | Step 0 → 1 → 2 → 3 → 3.5 → 4 → 5 → 6 → 6b → 7（新增 3.5 / 6b 是合理小数编号） | 与 Step 列表匹配；语义合理 | PASS |
| 5.5 | §3.5.6 四条件复述 vs Step 4 原文一致性 | 逐条对比 | 同义 | §3.5.6 的 PREREQ MET / PATH DISJOINT / SUCCESS-SIGNAL INDEPENDENT / RESOURCE SAFE 逐条对应 Step 4 | PASS |

### 1.6 lint + 自 dogfood smoke

| # | Case | Setup | Expected | Actual | Verdict |
|---|------|-------|----------|--------|---------|
| 6.1 | lint_cmd 0 命中 | `grep -rnE "gleanforge\|dex-sui\|dex-ui\|\bvault/\|\bllm/" skills/ agents/ commands/` | 0 | 0 命中 | PASS |
| 6.2 | End-to-end Monitor 管道 smoke | 起 tail -F + jq；subagent emit 6 合规 event | 6 条格式化行输出到 monitor stdout | 6/6 行；格式 `[P0.1] developer phase_start — starting P0.1` 完全符合 §3.3 | PASS |
| 6.3 | 3 event 密度范围（§3.1 "3-10 expected"） | 单 dispatch emit 6 event | 在 3-10 区间 | smoke emit 6（3 start + 3 complete），合规 | PASS |

---

## 2. 发现的 bug / 缺陷（结构化）

### 2.1 CRITICAL — 单行损坏 JSONL 击穿 Monitor pipe（Case 1.2 / 1.2b）

- **影响**：subagent 在并发 append / 或意外 emit 非 JSON 调试输出后，整个 dispatch 的后续 progress relay **永久丢失**（jq 进程 exit 4，`tail -F` 继续写文件但数据无下游消费）。
- **触发条件**：
  - subagent LLM 误把 stderr / debug print 写进 progress_path（比如 `echo "hello" >> $PROGRESS_PATH`）
  - 两进程并发 append 超 PIPE_BUF 的极端负载（POSIX 允许交错）
  - 磁盘满、write 被截断
- **反馈通道**：本 bug 不是"业务代码 bug"——它是 **Monitor 模板（commands/workflow.md §3.5.3）本身的鲁棒性缺陷**。tester 职责范围是"发现并上报"，修正归属是 developer（但由用户 / orchestrator 决策是否修）。
- **推荐修法**：把 `jq --unbuffered -c 'select(.event) | ...'` 改为容错版本：
  - 方案 A：`while IFS= read -r line` 外层循环，单行试 parse 失败则忽略
  - 方案 B：`jq -R 'fromjson? | select(.event) | ...'`（`-R` 让 jq 读 raw string，`fromjson?` 让 parse 失败返回 null 被静默）
- **复现**：`/tmp/roundtable-tester-p7/case1b/progress.jsonl` 配合本报告脚本

### 2.2 WARNING — macOS BSD date fallback 同秒碰撞（Case 2.1b）

- **影响**：无 openssl 环境（如某些最小化 macOS / Docker image），同秒并发 dispatch 得到相同 dispatch_id，filename 碰撞，progress 交错到同一文件，多 Monitor tail 会读到别 dispatch 的 event。
- **触发条件**：`openssl` 不可用 + `CLAUDE_SESSION_ID` 未注入 + 两个 Task 在同一 unix 秒 dispatch。
- **推荐修法**：fallback 改用 `$(awk 'BEGIN{srand(); printf "%08x", rand()*4294967296}')` 或 `cat /dev/urandom | tr -dc 'a-f0-9' | head -c 8`（跨平台可用）。

### 2.3 WARNING — mkdir 失败路径未处理（Case 2.2）

- **影响**：`/tmp` readonly / 磁盘满 时，`mkdir -p && touch` 失败，但模板已 echo 出一个不可写的 `PROGRESS_PATH`。orchestrator 仍会 inject；subagent 首次 `>> $PROGRESS_PATH` Bash 报错（非 graceful）。
- **推荐修法**：模板末尾追加 `|| { unset PROGRESS_PATH; echo "PROGRESS_DISABLED=1"; }`，orchestrator 识别后跳过 Monitor + 不 inject progress_path 变量。

### 2.4 WARNING — 各 agent Bash emit 模板缺"空值守卫"（Case 2.4）

- **影响**：`ROUNDTABLE_PROGRESS_DISABLE=1` 或 orchestrator 跳过 inject 时，subagent 仍按模板 `echo '...' >> {{progress_path}}`，但 `{{progress_path}}` 展开为空串，Bash 返回 `ambiguous redirect` 错误。依赖 subagent LLM 自觉识别 §Fallback 条款并 skip——不 robust。
- **推荐修法**：在各 agent 的 §Progress Reporting 示例 Bash 前补一行守卫：`if [ -n "{{progress_path}}" ] && [ -w "{{progress_path}}" ]; then echo '...' >> "{{progress_path}}"; fi`

### 2.5 WARNING — AskUserQuestion Option Schema 示例两 recommended（Case 3.4）

- **影响**：workflow.md §6b.2 example 展示 Option A 和 Option B 都有 `recommended: true`（`#` 注释分 case）。按字面实施违反 DEC-002 "at most 1 recommended"。
- **推荐修法**：example block 拆成 "case 1：small task 时" / "case 2：非 small 时" 两小段，各只一个 recommended。

### 2.6 WARNING — bugfix.md 规则 2 非对称（Case 3.6）

- **影响**：bugfix.md rule 2 仅描述 `developer_form_default: subagent` 的 respect 路径；`inline` 声明落空规则 2 进入规则 3（AskUserQuestion）。用户会困惑"我都声明 inline 了为什么还问我"。运行结果碰巧正确（规则 3 + inline-bias 大概率选 inline），但**语义不规整**。
- **推荐修法**：rule 2 改为 `if target_project CLAUDE.md declares developer_form_default (either inline or subagent), honor the declaration — this overrides the bugfix inline-bias default.`
- **Resolved by DEC-009 决定 9**（2026-04-19 bugfix.md 改对称 honor）

---

## 3. 信心评级

**整体实施信心：Medium-High**。

- **High confidence** 区：
  - 5 个 agent 的 §Progress Reporting / §Escalation Protocol schema 一致性 / 正交性纪律（case 4.x 全 PASS）
  - Phase Matrix 未被破坏、Step 4 四条件保留、§3.5.6 复述与原文对齐
  - Golden path smoke 6 event 通过；lint 0 命中
  - 并行 dispatch 的 progress_path 天然 disjoint
  - 5 agent 的 Escalation JSON schema 未被 Progress Reporting 新增污染

- **Medium confidence** 区：
  - Monitor pipeline 鲁棒性（Case 1.2 FAIL）——单损坏行拖垮 jq 导致后续 relay 全丢；dogfood 多轮后**必会**触发（任何时候 subagent 一次 debug print 意外写进 progress_path 都会中招）
  - Bash 模板跨平台兼容（Case 2.1b）——macOS 同秒碰撞在真实用户上会遇到，但碰撞频率低
  - 各 agent Bash emit 模板缺守卫（Case 2.4）——opt-out 路径依赖 LLM 自觉；新模型 / 新提示变体下可能回归

- **Low confidence** 区：
  - 无（没有发现让协议根本不工作的硬缺陷）

**建议**：

1. **合并前强烈建议修复 Case 1.2 Monitor pipeline 脆弱**（30 分钟工作量，改一行 jq 命令）
2. Case 2.1b / 2.2 / 2.4 / 3.4 / 3.6 归为 P2，下一轮 dogfood 捎带修
3. P4-style 自消耗 dogfood 走一轮，观察 Monitor stream 是否出现 "进度突然停止但 subagent 仍在跑" 情形（Case 1.2 的真实世界触发信号）

---

## 4. 待 escalation 的发现

<escalation>
{
  "type": "bug",
  "question": "是否授权立即修复 Monitor pipe 单行毒化 bug（Case 1.2，Critical）？",
  "context": "测试发现 commands/workflow.md §3.5.3 的 `tail -F $PROGRESS_PATH | jq --unbuffered -c 'select(.event) | ...'` 在遇到单行非 JSON 时，jq 立即 abort（exit 4）导致整个 pipe 关闭；tail 继续写文件但数据无下游消费。subagent 后续所有合规 progress event 永久丢失。触发场景：subagent 意外把 debug print 写进 progress_path、并发写入极端负载下行交错、磁盘满截断写。已在 /tmp/roundtable-tester-p7/case1b/ 写有可复现的 shell 脚本（无测试代码落盘，因 roundtable 是纯 prompt 包无测试框架）。tester 不修 src/*（即使这里 src 是 commands/workflow.md 也同样不自行改），需要用户 / orchestrator / developer 拍板。",
  "options": [
    {
      "label": "立即修：改 jq 为容错版本（推荐）",
      "rationale": "30 分钟工作量；单行改动（把 `jq --unbuffered -c 'select(.event) | ...'` 改为 `jq -R --unbuffered -c 'fromjson? | select(.event) | ...'`，或外层 while read 循环 + 独立 jq 调用）；消除 Critical 级鲁棒性缺陷。",
      "tradeoff": "需要重新 dogfood 验证容错 jq 版本不引入其他回归（如性能 / Monitor 启动延迟）；涉及 commands/workflow.md + commands/bugfix.md 两处模板。",
      "recommended": true
    },
    {
      "label": "推迟：标记为 known limitation，P4 dogfood 再看",
      "rationale": "本轮实施已完成 P0.1-P0.10；本 bug 触发需要特定场景（subagent LLM 误写 debug、并发重负载）；不阻塞 golden path。可在 P5+ dogfood 观察真实触发频率再决定。",
      "tradeoff": "用户侧体验：若 dogfood 首轮就遇到，progress 突然中断无任何告警，debug 困难；违背 DEC-004 north-star '用户感知进度对整个流程的掌控'。",
      "recommended": false
    }
  ],
  "remaining_work": "若选'立即修'：建议先 developer 改 jq template（inline form 跑最合适，单文件改 + 用户全程可见）；改完后 tester 再跑 smoke 验证 6 event 仍通过 + 毒化行不再拖垮 pipe。若选'推迟'：本 testing 报告先落盘，等 P5 dogfood 反馈。其他 Warning（Case 2.1b / 2.2 / 2.4 / 3.4 / 3.6）独立排期，不阻塞本 escalation。"
}
</escalation>

---

## 5. 变更记录

- 2026-04-19 创建 —— issue #7 P0.1-P0.10 实施对抗性测试，30+ case 覆盖 6 个维度（JSON schema / Monitor 启动 / form 切换 / 正交性 / Phase Matrix / lint+smoke）；发现 1 Critical + 5 Warning；产出 1 `<escalation>` 等待用户决策修 or 推
