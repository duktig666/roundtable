---
slug: prompt-reference-density-audit
source: analyze/prompt-reference-density-audit.md
created: 2026-04-23
status: Draft
decisions: [DEC-029]
---

# Runtime Prompt 引用密度回归审计设计文档

## 1. 背景与目标（含非目标）

### 1.1 背景

- issue #22（2026-04-20 闭环）第一轮精简 + 方法论确立（baseline → architect 三选项 → cut）
- issue #100（2026-04-22 merged）只加 CLAUDE.md §条件触发规则 预防条，**未做存量清理**
- issue #99（本 issue）第二轮：2026-04-23 baseline DEC 83 / § 41 / issue# 5 / 详见 12，post-#22 commit 净增 +54
- 热点 `commands/workflow.md` 独占 DEC 41% / § 54% / issue# 60%
- DEC-010 北极星 "token 成本 > SSOT" 本 issue 同源延续（新 lever = runtime prompt DEC ref 密度）

### 1.2 目标

- 存量清理命中 #22 验收门槛：DEC ref 降 ≥60% / 单次 workflow 加载 token 降 ≥8%
- 白名单边界可 grep 验证，消除主观争议
- 回归预防加 enforcement 程序硬阻，不靠人工纪律

### 1.3 非目标

- 不动 `docs/` 下任何文件的 DEC ref（读者需溯源，per #22 明确）
- 不改 DEC 正文（仅精简其在 runtime prompt 的 inline 括注数量）
- 不引入 `.github/workflows/` CI（保 #100 VCS 中立方向）
- 不触发 FAQ 架构评估（orthogonal issue #107）
- 不做方案 D 彻底重构（超 scope，未来独立 issue）

## 2. 业务逻辑（清理与验证流程）

### 2.1 清理流程

```
开发者 / developer subagent
  → Read 目标 runtime prompt 文件
  → 按 DEC-029 决定 3 白名单判定每个 DEC/§/issue# ref
  → 同 DEC 单文件出现 ≥2 次时，保留全文第一次出现位置（字面顺序）
  → 删除后续重复括注
  → 保留跨文档 `详见 docs/xxx` 跳转 + src/tests/scripts/hooks file:line
  → 运行 scripts/ref-density-check.sh 对比 baseline
  → pass → 提交 PR
  → fail → 按提示调整或重建 baseline（需 architect sign-off）
```

### 2.2 预防流程

```
后续任意 PR 修改 runtime prompt 本体
  → 本地 CLAUDE.md §工具链 lint_cmd 现在包含 scripts/ref-density-check.sh
  → 开发者 commit 前跑 lint_cmd
  → 超绝对量阈值 → exit 1 提示"开 follow-up audit issue 或更新 baseline"
  → reviewer 在 PR review 时也可复跑
```

## 3. 技术实现

### 3.1 清理清单（按热点优先级）

#### 3.1.1 Title 标签层（5 处全删）

| 文件:行 | 原文 | 清理后 |
|---------|------|--------|
| `commands/lint.md:65` | `### 6. 决策状态与结构审计（DEC-025 扩）` | `### 6. 决策状态与结构审计` |
| `agents/dba.md:146` | `## 输出落盘（orchestrator relay 主路径；DEC-017）` | `## 输出落盘（orchestrator relay 主路径）` |
| `agents/reviewer.md:128` | `## 输出落盘（orchestrator relay 主路径；DEC-017）` | `## 输出落盘（orchestrator relay 主路径）` |
| `commands/bugfix.md:57` | `### Tier 判定（D1 双轴 + LOC；DEC-014）` | `### Tier 判定（D1 双轴 + LOC）` |
| `commands/bugfix.md:100` | `### Postmortem 硬约束（Tier 2，含 orchestrator 执行锚点；DEC-014 C1）` | `### Postmortem 硬约束（Tier 2，含 orchestrator 执行锚点）` |

#### 3.1.2 commands/workflow.md 热点（42 命中收敛）

DEC-024 10 处 → 2 处：
- 保 `line 20`（Phase Matrix intro 首次出现位置）
- 保 `line 314`（Step 5b 事件类 b 表格行，第一个"尾段随附 Matrix 快照"规则出处）
- 删 `line 20` 内第二次 `（DEC-024，不新增事件类）`
- 删 line 317 / 318 / 384 / 386 / 388 / 545 / 547 的 `（DEC-024）` 后续重复括注

DEC-013 §3.1.1 3 处 → 1 处：保首处（line 281），删后续。

DEC-013 §3.1a 3 处 → 1 处：保首处，删后续。

DEC-006 5 处 → 2 处：保首处 + B 类 verification-chain 交接行首处；删其他重复。

DEC-018 3 处 → 1 处：保首处（line 281 inline），删后续。

DEC-017 3 处 → 1 处：保首处（§Step 7 Orchestrator Relay Write 段首），删后续。

DEC-023 §3.3 / §3.4 / §6b 等 5 处 → 2 处：保 §Step 6b 首处说明 + §Step 6b 三级切换切换规则出处；删其他。

DEC-005 2 处 → 1 处；DEC-003 2 处 → 1 处；DEC-007 §3.4 / DEC-004 §3.5 等单处保留。

#### 3.1.3 其他文件

| 文件 | 策略 |
|------|------|
| `commands/bugfix.md`（8 DEC）| title 2 处删（§3.1.1），行内重复 DEC-014 保首处删 4 处 |
| `agents/tester.md`（7 DEC）| 重复 DEC-017 保首处删 ~4 处 |
| `skills/_progress-content-policy.md`（6 DEC）| 保 DEC-004 / DEC-007 schema 出处各 1，删重复 |
| `skills/architect/SKILL.md`（6 DEC + 1 issue#）| title `### 阶段 3：exec-plan（...；issue #30）` 删 issue 标签；DEC-025 5 类必开保 1，删重复 |
| `agents/dba.md` / `agents/reviewer.md`（各 6 DEC）| title 删（上表）+ 行内重复 DEC-017 保首处 |
| `skills/analyst/SKILL.md`（4 DEC + 1 issue#）| issue #30 行内保 |
| `commands/lint.md`（4 DEC）| title 1 处删（上表）+ 行内重复 DEC-025/026 保首处 |
| `agents/research.md`（2 DEC）| 保留（已极简） |
| `agents/developer.md` / `skills/_detect-project-context.md` | 0 命中，不动 |

#### 3.1.4 预期清理后水位

| 类型 | 清理前 | 清理后（预期） | 降幅 |
|------|-------|---------------|------|
| DEC 总 | 83 | ~33 | -60% ✓ 命中 #22 门槛 |
| § 总 | 41 | ~17 | -59% |
| issue# 总 | 5 | 3 | -40%（title 3 处删） |
| 详见 | 12 | 12 | 0（全白名单） |
| workflow.md DEC | 34 | ≤14 | -59% |

### 3.2 白名单判定规则（DEC-029 决定 3 固化）

**允许的 runtime prompt ref 形态**：

| 类 | 形态 | 示例 |
|---|------|------|
| α | 跨文档跳转 | `详见 docs/design-docs/orchestrator-bootstrap-hardening.md` / `docs/testing/subagent-progress-and-execution-model.md Case 1.2` |
| β | 源码位置 `file:line` | `src/lib.rs:42` / `tests/foo_test.rs:10` / `scripts/preflight.sh:5` / `hooks/session-start:12` |
| γ | "首处锚点"：同 DEC 在单文件全文第一次字面出现 | `commands/workflow.md:20 Phase Matrix 渲染 locus = orchestrator（DEC-024，与 tg-forwarding-expansion.md §D1 ...）` |

**禁止的形态**：

| 类 | 形态 | 处理 |
|---|------|------|
| δ | runtime prompt 本体 inline 复刻 DEC 全文段落（>1 句引文） | 改为 `详见 docs/decision-log.md §DEC-xxx` 跳转 |
| ε | 无 `docs/` 路径前缀的裸 `§y.z` 跨文件引用 | 加 `docs/xxx.md` 路径前缀改为 α 类 |
| ζ | 同 DEC 单文件第 2+ 次重复括注 | 删 |
| η | title 标签 DEC/issue ref（`### X（DEC-xxx）` 或 `## Y（issue #nn）`） | 删括注部分，保 title 自身 |

### 3.3 scripts/ref-density-check.sh 脚本设计

```bash
#!/usr/bin/env bash
# DEC-029: runtime prompt DEC/§/issue# 引用密度回归检查
# Usage: scripts/ref-density-check.sh [--update-baseline]
# Exit: 0 pass / 1 fail（超阈需 audit issue）/ 2 script error

set -euo pipefail
BASELINE="scripts/ref-density.baseline"
ROOTS=(skills agents commands)

# per-file census: DEC § issue#
count() {
  local f=$1
  local dec sec iss
  dec=$(grep -cE "DEC-[0-9]+" "$f" || true)
  sec=$(grep -cE "§[0-9]" "$f" || true)
  iss=$(grep -cE "issue #[0-9]+|\bfixes #[0-9]+|\b#[0-9]{2,}\b" "$f" || true)
  printf "%s\t%d\t%d\t%d\n" "$f" "$dec" "$sec" "$iss"
}

# collect
current=$(for root in "${ROOTS[@]}"; do
  find "$root" -name '*.md' -not -path '*/node_modules/*'
done | sort | while read -r f; do count "$f"; done)

if [[ ${1:-} == "--update-baseline" ]]; then
  printf "%s\n" "$current" > "$BASELINE"
  echo "baseline updated: $BASELINE"
  exit 0
fi

[[ ! -f "$BASELINE" ]] && { echo "ERROR: $BASELINE missing; run with --update-baseline" >&2; exit 2; }

# diff check: per-file 新增 ≥3 或 total 净增 ≥10
fail=0
total_delta=0
while IFS=$'\t' read -r f dec sec iss; do
  b=$(grep -F "$f	" "$BASELINE" || echo "$f	0	0	0")
  b_total=$(echo "$b" | awk -F'\t' '{print $2+$3+$4}')
  c_total=$((dec + sec + iss))
  delta=$((c_total - b_total))
  total_delta=$((total_delta + delta))
  if (( delta >= 3 )); then
    echo "FAIL: $f DEC/§/issue# ref +$delta（baseline $b_total → current $c_total）" >&2
    fail=1
  fi
done <<< "$current"

if (( total_delta >= 10 )); then
  echo "FAIL: skills+agents+commands 合计 DEC/§/issue# ref 净增 $total_delta ≥ 10" >&2
  fail=1
fi

(( fail == 1 )) && echo "→ 开 follow-up audit issue 走 #22 方法论；或 architect sign-off 后 --update-baseline 重锁" >&2
exit $fail
```

**baseline 文件格式**（`scripts/ref-density.baseline`）：TSV `<path>\t<dec_count>\t<sec_count>\t<iss_count>`，清理完成后由 developer 跑 `--update-baseline` 锁死。

### 3.4 CLAUDE.md 同步更新

**§工具链** `lint_cmd` 追加：

```
lint_cmd：`grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/ && scripts/ref-density-check.sh`
```

**§条件触发规则** 表内现有"改 skill/agent/command prompt 本体（行内 DEC/issue 引用纪律；#22）"条替换为指向 DEC-029 白名单 + 命令：

```
改 skill/agent/command prompt 本体 | 按 DEC-029 白名单三类（α 跨文档跳转 / β src/tests/scripts/hooks file:line / γ 首处锚点=单文件字面首次）；禁 DEC 全文复刻 / 裸 §y.z 跨文件 / 重复括注 / title 标签 ref。`scripts/ref-density-check.sh` 强制跑（已入 lint_cmd）；超阈 exit 1 触发 audit issue 或 architect sign-off 重锁 baseline
```

### 3.5 DEC-029 编号关系声明

- **Refines DEC-010**（Accepted；北极星 "token 成本 > SSOT"）：DEC-010 lever 是 helper 抽取 ↔ inline；DEC-029 lever 是 runtime prompt DEC ref 密度。同源异 lever。
- DEC-010 状态行追加 `Refined by DEC-029`（§状态说明第 6 种字面值，父 DEC 保留 Accepted）

## 4. 关键决策与权衡

### 4.1 D1：清理策略（analyst 报告 A/B/C/D 四方案）

| 维度（0-10） | B. 中道 ★ | A. 激进 | C. 保守 | D. 彻底 |
|-------------|-----------|---------|---------|---------|
| 命中 #22 门槛 60%/8% | **9** | 10 | 3 | 10 |
| Maintainer 溯源成本 | **8** | 5 | 9 | 4 |
| 改动量（一次性工作） | **7** | 6 | 9 | 3 |
| 回归预防结构性 | **7**（依赖 α₂）| 7 | 5 | 10 |
| 与 superpowers 对齐 | **6** | 8 | 3 | 10 |
| 超 #99 scope 风险 | **9**（不超）| 8 | 9 | 2（严重超） |
| **合计** | **46** | 44 | 38 | 39 |

### 4.2 D2：白名单边界（A/B/C）

| 维度（0-10） | A. 严格 ★ | B. 宽松 | C. 契约优先 |
|-------------|-----------|---------|-------------|
| grep 可验证 | **10** | 5 | 3 |
| 边界无歧义 | **9** | 5 | 4 |
| DEC SSOT 保护 | **9** | 5 | 7 |
| 执行负担 | **7** | 6 | 4（契约清单维护）|
| 与 superpowers 对齐 | **8** | 6 | 5 |
| **合计** | **43** | 27 | 23 |

### 4.3 D3：回归预防（A/B/C/D）

| 维度（0-10） | B. γ+α₂ ★ | A. γ only | C. γ+α₁ CI | D. γ+β template |
|-------------|-----------|-----------|------------|------------------|
| Enforcement 强度 | **8** | 2 | 10 | 4 |
| 不依 GitHub / VCS 中立 | **10** | 10 | 3 | 3 |
| 新基建成本 | **8**（复用 scripts/）| 10 | 4（.github/workflows/） | 5（.github/）|
| 开发者体感 | **7**（lint_cmd 整合）| 5 | 6 | 4（checklist fatigue）|
| 与 DEC-010 北极星对齐 | **9** | 6 | 7 | 5 |
| **合计** | **42** | 33 | 30 | 21 |

## 5. 讨论 FAQ

（本报告新建，尚无追问；后续追问以 `### Q: <摘要>` 格式追加）

## 6. 变更记录

- 2026-04-23：新建（Draft）

## 7. 待确认项

- scripts/ref-density-check.sh 细节（awk/grep 性能 / fnmatch 容错）在 tester adversarial case 阶段验证
- Baseline 锁定时机：exec-plan 任务完成后、scripts 集成前，由 developer 跑 `--update-baseline`（需 architect 或用户 sign-off）
- DEC-010 状态行 `Refined by DEC-029` 追加由 developer 在同 PR 同步（保状态说明一致性）

## 影响文件清单

见 DEC-029 §影响范围 + exec-plan §P1.x 细化。
