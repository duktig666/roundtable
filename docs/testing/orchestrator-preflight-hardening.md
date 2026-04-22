---
slug: orchestrator-preflight-hardening
source: tester (inline, orchestrator-driven)
created: 2026-04-22
tester: tester inline（subagent dispatch tool unavailable in this session）
---

# orchestrator-preflight-hardening 对抗性测试矩阵（issue #89）

## Scope

审计 `commands/workflow.md` 4 处改动（critical_modules 命中 "skill/agent/command prompt 本体"）：

1. **§Step -1 末尾**：Pre-flight Bash echo 块 + 4 段输入源纪律 prose
2. **§Step 3 起首**：7 角色形态映射表 + 1 句 prose
3. **§Step 6 rule 4 删除**：原 2 行角色形态 bullet 删除；rule 5-9 顺延为 4-8
4. **§Step 5b 事件类表 a 行**：事件列与来源列 scope 扩展

测试类型：markdown 静态测试矩阵（roundtable 为 doc/plugin 仓库，无执行测试 runner；约定与 `docs/testing/decision-log-sustainability.md` 同）。

总 13 cases：5 设计层 handoff 场景（design-doc §6）+ 3 对抗（orchestrator 提纲）+ 5 回归。

---

## 1 设计层 handoff 场景（design-doc §6.1-§6.5）

### T1：env 全 unset + 无 CLI flag（baseline 默认）

- **前置**：`ROUNDTABLE_AUTO` 未设 / `ROUNDTABLE_DECISION_MODE` 未设 / `$ARGUMENTS="xx 任务描述"`
- **跑 §Step -1 Bash**：stdout 应含 3 行
  ```
  PREFLIGHT raw_args=xx 任务描述
  PREFLIGHT raw_env ROUNDTABLE_AUTO=<unset> ROUNDTABLE_DECISION_MODE=<unset>
  PREFLIGHT note: Claude Code Auto Mode != roundtable auto_mode (see feedback_roundtable_auto_mode_source)
  ```
- **orchestrator 补两行**：
  ```
  PREFLIGHT resolved auto_mode=false (source=default)
  PREFLIGHT resolved decision_mode=modal (source=default)
  ```
- **active channel 转发**：raw 全默认 → 不独立转发 PREFLIGHT 段；resolved 2 行作 bullet 合入事件类 a 首块（§Step -1 末段约定）
- **判定**：resolved 行 source=default；channel 无独立 PREFLIGHT reply

### T2：`ROUNDTABLE_AUTO=true` 设置 + 其他默认

- **前置**：`export ROUNDTABLE_AUTO=true`；env decision 未设；`$ARGUMENTS` 无 `--auto` / `--decision`
- **raw_env 行**：`PREFLIGHT raw_env ROUNDTABLE_AUTO=true ROUNDTABLE_DECISION_MODE=<unset>`
- **orchestrator 补行**：`PREFLIGHT resolved auto_mode=true (source=env)` / `PREFLIGHT resolved decision_mode=modal (source=default)`
- **判定**：env 源优先级正确（§Step -0 CLI > env > default；CLI 缺省时 env 胜出）
- **active channel 转发**：raw_env 非全默认 → 独立 PREFLIGHT 段合入事件类 a 首块 reply

### T3：CLI `--auto` + env 全 unset

- **前置**：`$ARGUMENTS="--auto 我的任务"`；两 env 均 unset
- **raw_args 行**：`PREFLIGHT raw_args=--auto 我的任务`（含 `--auto` 字面 token）
- **orchestrator 补行**：`PREFLIGHT resolved auto_mode=true (source=cli)`（LLM 层解算；shell 不能算，见输入源纪律段）
- **判定**：source=cli；LLM 补行非 shell 直算
- **关键**：此 case 验证 resolved 行的 LLM 解算路径（F3 OQ1 结论），不是 shell eval

### T4：§Step 3 起首表格存在性 + §Step 6 rule 4 删除

- **grep 表格**：`grep -n "^| \`analyst\`" commands/workflow.md` 应 1 命中（且位于 §Step 3 范围）
- **表格行数**：7 角色行（analyst / architect / developer / tester / reviewer / dba / research）
- **§Step 6 原 rule 4 消失**：`grep -nE "^\*\*4\. 角色形态" commands/workflow.md` 应 0 命中
- **残留语句检查**：`grep -nE "architect.*analyst.*skill.*AskUserQuestion" commands/workflow.md` 应 0 命中（原 rule 4 bullet 已彻底搬家）
- **后续规则数字**：§Step 6 现为 1-8（原 1-9）；`grep -nE "^\*\*9\." commands/workflow.md` 应 0 命中

### T5：§Step 5b 事件类 a 行扩展 + Ordering 段未动

- **grep 事件列**：`grep "Step -0/-1 pre-flight echo" commands/workflow.md` 应 1 命中（位于事件类表 a 行）
- **来源列更新**：`grep "orchestrator Step -0/-1/0/1" commands/workflow.md` 应 1 命中
- **Ordering 段**：`grep "事件类 a + Step 1 size 判定 \\*\\*合并为单次\\*\\*" commands/workflow.md` 应 1 命中（wording 未动，自然吸收 pre-flight）
- **格式列不变**：事件类 a 格式列仍为 `markdownv2` 结构化，DEC-022 不变

---

## 2 对抗性 cases（orchestrator 提纲）

### A1：env 值含前后空格

- **前置**：`export ROUNDTABLE_AUTO=" true "`（含空白）
- **Bash raw_env 行**：`PREFLIGHT raw_env ROUNDTABLE_AUTO= true  ROUNDTABLE_DECISION_MODE=<unset>`（字面保留空格——`${var:-default}` 语义等价替换）
- **orchestrator LLM 解算**：`ROUNDTABLE_AUTO ∈ {1, true, on, yes}` 判定（§Step -0 原规则）。`" true "` 严格字面不匹配 `true`。
  - **保守判定**：`resolved auto_mode=false (source=env)` —— 值不在白名单视为 false
  - **宽松判定**：trim 后匹配 `true` → `auto_mode=true` —— 但 §Step -0 原文无 trim 契约
- **推荐行为**：遵循 §Step -0 严格字面匹配 → `auto_mode=false`；raw_env 行显式保留空白供 debug 时肉眼发现
- **结论**：Bash echo 的**价值**正体现于此——若无 echo，用户看不到 `ROUNDTABLE_AUTO` 被设了含空格的值。**非测试失败**，是设计特性

### A2：CLI flag 与 env 冲突

- **前置**：`export ROUNDTABLE_AUTO=true` + `$ARGUMENTS="--no-auto 任务"`
- **Bash raw 行**：raw_env 显示 `ROUNDTABLE_AUTO=true`；raw_args 显示 `--no-auto`
- **orchestrator 解算**：§Step -0 原文 "`--no-auto` 显式关闭（覆盖 env 开启）"；`resolved auto_mode=false (source=--no-auto)` 或 `source=cli`
- **判定**：resolved 行 source 字段应明示 CLI 胜出；用户可从 raw_env + raw_args 两行即刻看出冲突实况
- **关键**：source 字段值当明确区分 `cli` / `env` / `default` / `--no-auto`（§Step -1 末段模板已含 4 值）

### A3：`$ARGUMENTS` 多行输入

- **前置**：`$ARGUMENTS` 含 `\n`（如粘贴多段任务描述）
- **Bash raw_args 行**：`echo "PREFLIGHT raw_args=$RAW_ARGS"` 会把 newline 渲染为**终端换行**，stdout 可能出现多行：
  ```
  PREFLIGHT raw_args=第一行任务
  第二行上下文
  ```
- **用户观察**：raw_args "溢出" 到多行 —— 视觉上仍可读（前缀 `PREFLIGHT raw_args=` 仍可 grep 锚定第一行）
- **active channel 转发**：markdownv2 结构化 reply 的 bullet 清单会把多行合为一条反引号字段（TG 转发层；DEC-022 格式 + DEC-018 pretty）。原始多行保留终端 stdout
- **判定**：不建议 quote `$RAW_ARGS` 为单行（`tr '\n' ' '`）—— 那会擦掉结构；当前实现保留原貌更利 debug。**非测试失败**

---

## 3 回归 cases

### R1：lint_cmd 0 命中

```
grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/
```

**预期**：无输出（exit 1 = 无命中），符合 CLAUDE.md `lint_cmd` 契约。

### R2：plugin 内部无 rule 5-9 数字引用

```
grep -rnE "Step 6 rule [5-9]|rule [5-9]" commands/ skills/ agents/
```

**预期**：无命中。plugin prompt 本体任意位置若还有残留 rule 5-9 引用则为漏改。历史 `docs/` 艺术品（`docs/analyze/...`、`docs/testing/phase-transition-rhythm.md`、`docs/design-docs/workflow-auto-execute-mode.md`、`docs/reviews/2026-04-19-phase-transition-rhythm.md`）append-only 不回溯，审计豁免。

### R3：Phase Matrix 段未动

`commands/workflow.md` `## Phase Matrix` 至 `---` 分隔符区间 git diff 应 0 行变更（#88 领地）。

### R4：§Step 5b 事件类 b/d/e 尾段未动

`| b |` / `| d |` / `| e |` 行格式列含 `*Phase*: \`…\` 单行 Matrix 快照（DEC-024）` 等措辞应保持原样。只动 a 行。

### R5：DEC-022 / DEC-024 语义不破

- DEC-022：事件类 a markdownv2 结构化不变（只扩 scope 不换格式）
- DEC-024：Phase Matrix 单行进度条在 b/d/e 尾段未动
- DEC-025 §开立门槛 5 类自检：本改动 0 命中 → 无新 DEC 正确

---

## 4 判定汇总

| 类别 | 数 | 预期 |
|------|----|------|
| 设计层 handoff | 5 | 全 Pass |
| 对抗 | 3 | A1/A2/A3 非 bug；设计特性（echo 暴露真相让用户 debug）；建议文档保持现状 |
| 回归 | 5 | 全 Pass |

**Verdict**：Pass

**Critical findings**：无

**Warnings**：
- W1（A3）：多行 `$ARGUMENTS` 对终端 stdout 视觉"溢出"是已知权衡；future 可考虑把 echo 行改 `printf "%s\n"` 或 `tr '\n' '⏎'` 单行化，但会破坏粘贴回原文的能力。**不 block 本 PR**，记录为 follow-up 观察点
- W2（R2）：历史 `docs/` 中 4 份文档仍提 Step 6 rule 5-6 —— 这些是 append-only 记录当时状态，豁免；但下一次若有人查阅这些 doc 想按旧编号找规则会对不上。**不 block 本 PR**；可在 FAQ 添一条"旧 rule 5-6 现为 rule 4-5"记注

**Suggestions**：
- S1：pre-flight Bash 块可加 `set +u` 防御 `ARGUMENTS`/`ROUNDTABLE_*` 在 strict mode 下 `unbound variable` 退出（当前 `${var:-<unset>}` 已兜底，但显式 `set +u` 更稳）—— 小改动，后续优化

---

## 变更记录

- 2026-04-22：初版，基于 design-doc §6 + orchestrator brief 对抗补充

created:
  - path: docs/testing/orchestrator-preflight-hardening.md
    description: "issue #89 L2 orchestrator pre-flight hardening 对抗性测试矩阵；5 设计层场景 + 3 对抗 + 5 回归；verdict Pass，无 Critical，2 Warning（多行 $ARGUMENTS 视觉溢出 / 历史 doc rule 编号豁免）+ 1 Suggestion"

log_entries:
  - prefix: test-plan
    slug: orchestrator-preflight-hardening
    files:
      - docs/testing/orchestrator-preflight-hardening.md
    note: "issue #89 对抗性测试矩阵 13 cases（5 handoff + 3 adversarial + 5 regression），verdict Pass；无 Critical；W1 多行 $ARGUMENTS 视觉溢出记观察 / W2 历史 docs Step 6 rule 编号豁免 append-only"
