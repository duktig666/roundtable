---
slug: orchestrator-preflight-hardening
source: analyze/orchestrator-preflight-hardening.md
created: 2026-04-22
status: Draft
decisions: []
---

# Orchestrator Pre-flight Hardening 设计文档

## 1. 背景与目标

issue #89 L2：把 `commands/workflow.md` 里两条隐式 LLM 规则（§Step -0/-1 auto_mode / decision_mode 解析 与 §Step 6 rule 4 角色形态）下沉为 **可执行 Bash echo** + **结构化表格**，消除 #84 暴露的 cold-start 误判（auto_mode 源错判 / analyst 被当 subagent 派）。

**非目标**：不碰 Phase Matrix stages / Step 4 并行判定 / Step 5b 事件类 b/d/e（#88 领地）。不引入 SessionStart hook（L3，非本 issue）。

## 2. L2a：§Step -0 / §Step -1 Bash Pre-flight Echo

### 2.1 块位置

紧随 §Step -1 prose 末尾（`workflow.md:54` 之后）追加一块 Bash，而非另开 §Step -0.5 —— 前例 §3.5.1 已证明 Bash 块作为 step 内嵌子块无节号成本。新增 prose 一行说明 "orchestrator 每次 `/roundtable:workflow` 入口**首先跑本块**并把 stdout 连同 §Step 0 context 结果合入事件类 a 转发"。

### 2.2 Bash 块模板

风格复用 §3.5.1（```bash 围栏 + 多行 echo）；**只 echo 不赋值**，避免 session 状态外泄：

```bash
# Pre-flight: surface raw CLI/env inputs + resolved values
# Read informational only — skill runtime params (context prefix) remain authoritative.
RAW_ARGS="${ARGUMENTS:-<unset>}"
RAW_AUTO_ENV="${ROUNDTABLE_AUTO:-<unset>}"
RAW_DECISION_ENV="${ROUNDTABLE_DECISION_MODE:-<unset>}"
echo "PREFLIGHT raw_args=$RAW_ARGS"
echo "PREFLIGHT raw_env ROUNDTABLE_AUTO=$RAW_AUTO_ENV ROUNDTABLE_DECISION_MODE=$RAW_DECISION_ENV"
echo "PREFLIGHT note: Claude Code Auto Mode != roundtable auto_mode (see feedback_roundtable_auto_mode_source)"
```

Resolved 行由 orchestrator **紧随 Bash stdout** 以普通 echo 格式补两行（orchestrator 按 §Step -0/-1 优先级在 LLM 层解算后输出，非 shell 直算，避免 CLI flag 的 shell 可见性问题——见 F3 OQ1 结论）：

```
PREFLIGHT resolved auto_mode=<true|false> (source=<cli|env|default|--no-auto>)
PREFLIGHT resolved decision_mode=<modal|text> (source=<cli|env|default>)
```

### 2.3 输入源纪律（OQ1 决议）

- Bash 直读 env（`${ROUNDTABLE_AUTO:-<unset>}` / `${ROUNDTABLE_DECISION_MODE:-<unset>}`）—— 确定可 echo
- Bash 打印 `$ARGUMENTS` 原串 —— CLI flag 在此以 raw 形式可见
- Resolved 值由 orchestrator LLM 按 §Step -0 优先级（CLI > env > default，含 `--no-auto`）解算后补两行 `PREFLIGHT resolved ...`
- **权威源**：Task prompt prefix / skill context prefix 里的 `auto_mode: <v>` / `decision_mode: <v>` 注入行（§Step -0/-1 原规则）是下游角色的唯一输入；Bash echo 是**用户可见校验行**，不是下游派发的参数源——sync-check 由人/tester 眼验

## 3. L2b：7 角色 Skill/Agent 形态映射表

### 3.1 位置（C1 决议）

嵌入 §Step 3 起首，即 `workflow.md:136` 小节标题下方、"选 kebab-case slug ..." 句之前。改名 §Step 3 标题为 **"Slug、角色形态与 Artifact Handoff"**（保兼容原引用，新增一个语义 bullet）。

### 3.2 表格内容（源 `.claude/memory/feedback_skill_vs_agent_dispatch.md`）

| 角色 | 形态 | 调用方式 |
|------|------|---------|
| `analyst` | skill | `Skill(skill: "roundtable:analyst", args: "...")` |
| `architect` | skill | `Skill(skill: "roundtable:architect", args: "...")` |
| `developer` | agent / inline（见 §Step 6b） | `Agent(subagent_type: "roundtable:developer", ...)` 或 Read `agents/developer.md` 主会话执行 |
| `tester` | agent | `Agent(subagent_type: "roundtable:tester", ...)` |
| `reviewer` | agent | `Agent(subagent_type: "roundtable:reviewer", ...)` |
| `dba` | agent | `Agent(subagent_type: "roundtable:dba", ...)` |
| `research` | agent（architect 派发；见 §Step 6b） | `Agent(subagent_type: "roundtable:research", ...)` |

表后一句 prose：**派发前必查此表**；skill 形态不能用 `Agent(subagent_type: ...)` 激活（会触发 `Agent type not found`）。inline / subagent 切换细节与 research 排除见 §Step 6b。

**F5 纪律**：表与 prose 均用 §-reference（§Step 6b），不嵌 `（DEC-xxx）` 括注。

### 3.3 §Step 6 rule 4 删除计划

现址（`workflow.md:382-384`）两行 bullet 整段 **删除**（非改指针——#22 纪律禁散点重复，单一权威节落在 §Step 3）：

```
**4. 角色形态**：
- `architect` / `analyst` = **skill**（主会话；`AskUserQuestion` 可用）
- `developer` / `tester` / `reviewer` / `dba` = **agent**（subagent；`AskUserQuestion` 不可用）
```

后续规则编号 **5–9 顺延为 4–8**（rule 5 "developer 完成后" 成 rule 4，以此类推）。§Step 6b、§Step 5b、§Step 3.4、§Step 4b 对 "§Step 6 rule N" 的引用需同步重编（developer 提交前 grep `Step 6\.\?[45-9]` 校验）。

**保留不动**：§Step 6b Role Form Selection 整节（developer/tester/reviewer/dba inline ↔ subagent 三级切换与 research 排除规则）—— 本 issue 不触 form switching 纪律，只清散点重复。

## 4. §Step 5b 事件类 a scope 扩展（OQ2 决议）

`workflow.md:297` 事件类 a 当前描述 = "Step 0 context detection 结果 + Step 1 size/pipeline 判定"；**inline 改**为：

> Step -0/-1 pre-flight echo（若非 `<unset>` 默认值）+ Step 0 context detection 结果 + Step 1 size/pipeline 判定

format 列不变（`markdownv2` 结构化：粗体标题 + 反引号字段值 + bullet 清单）。同块 reply 语义不变（§Step 5b 下方 Ordering 规则 "事件类 a + Step 1 size 判定合并为单次 markdownv2 reply" 自然吸收 pre-flight）。

**转发触发时机**：orchestrator 跑完 Bash + 补完 resolved 两行后，如 active channel sticky，把 4–6 行 `PREFLIGHT ...` stdout 作为 bullet 清单段合入事件类 a 首块 reply 转发。

**若两 env 都 `<unset>` 且无 CLI flag**（即 raw 全默认）：不转发独立 PREFLIGHT 段，只让 resolved 两行作为 bullet 出现在事件类 a —— 避免噪声；终端 stdout 始终打印。

## 5. 无新 DEC（铁律 5 自检）

DEC-025 §开立门槛 5 类自检：

| 类 | 本改动 | 命中？ |
|---|-------|--------|
| 跨模块接口 | 只改 `commands/workflow.md` 单文件；§5b a scope 文字内改 | 否 |
| 改 DEC-001 D1-D9 | 不触 | 否 |
| 新依赖 | 无 | 否 |
| 推翻/细化 Accepted DEC | 不推翻；不是细化 Accepted DEC 规范语义，只是**让现有 §Step -0/-1 / §Step 6 rule 4 / §Step 5b 事件类 a 规则更机械化可观测** | 否 |
| 技术选型 / 数据模型 | 无 | 否 |

Red Flags 自检：memory `feedback_skill_vs_agent_dispatch.md`（已 L1 memory 固化）+ `feedback_roundtable_auto_mode_source.md`（已 L1 memory 固化）是本改动的真正规则源；L2 只是把这两条 memory 的纪律**回写到 prompt 本体的可观测位置**，属 "inline post-fix 父规则"。**不开新 DEC**。

## 6. 测试计划（handoff 给 developer / tester）

developer 实施后，tester 必测 5 场景（critical_modules 命中 `skill/agent/command prompt 本体`，强制派）：

1. 两 env 全 unset 无 CLI flag → `PREFLIGHT raw_env ROUNDTABLE_AUTO=<unset> ROUNDTABLE_DECISION_MODE=<unset>` + `resolved auto_mode=false (source=default)` + `resolved decision_mode=modal (source=default)`
2. `ROUNDTABLE_AUTO=true` 设置 → `resolved auto_mode=true (source=env)`
3. CLI `--auto` + env unset → raw_args 段可见 `--auto`，`resolved auto_mode=true (source=cli)`（LLM 补行）
4. §Step 3 起首表格存在且含 7 行（含 research 行），§Step 6 原 rule 4 不再出现两行 bullet，grep `架构师 \| analyst.*skill.*AskUserQuestion` 在 §Step 6 范围应 0 命中
5. §Step 5b 事件类 a 格式列文字含 "Step -0/-1 pre-flight echo"；同节 Ordering 段 wording 未动

附加回归：§Step 6 rule 5–9 重编号后，全文搜索 `rule 4` / `Step 6 rule [5-9]` 引用需指向更新后编号；lint_cmd `grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/` 0 命中。

## 7. 变更记录

- 2026-04-22：首版，基于 analyst OQ1/OQ2/C1 auto-picks 产出

---

created:
  - path: docs/design-docs/orchestrator-preflight-hardening.md
    description: "issue #89 L2 orchestrator pre-flight hardening 设计文档；L2a Bash echo 块 + L2b §Step 3 起首 7 角色形态表 + §Step 6 rule 4 删除 + §Step 5b 事件类 a scope 扩展；无新 DEC"

log_entries:
  - prefix: design
    slug: orchestrator-preflight-hardening
    files:
      - docs/design-docs/orchestrator-preflight-hardening.md
    note: "issue #89 L2 pre-flight hardening design; Bash echo template + 7-role dispatch table at §Step 3 start + §Step 6 rule 4 removal + §5b event-class a scope extension; no new DEC"
