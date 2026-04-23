---
slug: prompt-reference-density-audit
source: design-docs/prompt-reference-density-audit.md
created: 2026-04-23
---

# Runtime Prompt 引用密度回归审计测试报告

## 总结

DEC-029 enforcement（`scripts/ref-density-check.sh` + baseline + CLAUDE.md lint_cmd 追加）对抗性测试 19 case 全跑；16 PASS，核心脚本路径鲁棒，regex / baseline / CLI 等 edge case 无 regression；发现 **1 个 Critical**（CLAUDE.md §工具链 lint_cmd 复合命令 `&&` 使用方向反了，enforcement 路径在清洁状态下不可达）+ **3 个 Warning**（line-count 计数法使 1 行 N ref 可绕过、新文件 1-2 ref 不纳入 per-file 检查、baseline 重复行静默吞错误）+ **2 个 Suggestion**（CWD 依赖未在脚本头文档化、grep `\b` word-boundary 对 `#nn` 误差）。Critical 项须 developer 复工修 CLAUDE.md 行 40。

## 测试范围

- scripts/ref-density-check.sh 全部分支（happy / per-file fail / total fail / --update-baseline / baseline missing / 新文件 / 路径空格）
- baseline 文件格式容错（追空行 / 行序反转 / 字段缺失 / 重复 path）
- grep regex 正则 edge case（# 作为 markdown heading 符号、§x.y.z、DEC-xxx placeholder）
- CLAUDE.md lint_cmd 复合命令语义
- CLAUDE.md §条件触发规则 γ 描述与 DEC-029 post-fix 对齐度
- workflow.md / bugfix.md / architect SKILL.md 清理后规则完整性

## Case 明细

| # | Case | 操作 | Expected | Actual | 判定 |
|---|------|------|----------|--------|------|
| T1 | Happy path 裸跑 | `bash scripts/ref-density-check.sh` | exit 0 | exit 0 | PASS |
| T2 | 单文件 3 行独立 DEC 追加（agents/tester.md） | `tail << EOF <!-- DEC-777 -->\n<!-- DEC-778 -->\n<!-- DEC-779 -->` | exit 1 + `FAIL: agents/tester.md ... +3` | exit 1，stderr 精确匹配 `FAIL: agents/tester.md DEC/§/issue# ref +3（baseline 2 → current 5）` | PASS |
| T2' | 单行多 DEC 追加 `DEC-777 DEC-778 DEC-779` 同一行 | expected exit 1 | exit 0 | **WARNING**：`grep -cE` 行计数制，1 行 N 个 ref 只计 1 次；per-file 阈值 `>=3` 可被"同行多 ref"绕过 |
| T3 | total 净增 ≥10（6 文件各 +2） | agents/tester/dba/reviewer + commands/bugfix/lint + skills/analyst/SKILL 各追 2 行 DEC | exit 1 + 合计 ≥10 提示 | exit 1，stderr 精确匹配 `FAIL: skills+agents+commands 合计 DEC/§/issue# ref 净增 12 ≥ 10` | PASS |
| T4 | --update-baseline 等价更新 | +3 DEC → `--update-baseline` → 再裸跑 | update exit 0；重跑 exit 0；baseline 写入新水位 | update exit 0；重跑 exit 0；`agents/developer.md` 行由 `0 0 0` 更新为 `3 0 0` | PASS |
| T5 | baseline 缺失 | `mv scripts/ref-density.baseline .bak` | exit 2 + `ERROR: ... missing` | exit 2，stderr `ERROR: scripts/ref-density.baseline missing; run with --update-baseline` | PASS |
| T6 | 新文件 baseline 未记录 + 2 DEC ref | 创建 `skills/foo-t6.md` 含 2 `<!-- DEC-xxx -->` 行 | baseline fallback=0；delta=2 < 3 per-file 阈值 → exit 0 或进 total 累加 | exit 0；2 ref 进 total_delta 累加但未触发 10 阈值 | PASS（**Warning**：1-2 ref 新文件 silent bypass） |
| T6b | 新文件 + 3 DEC ref | 同 T6 但 3 行 | exit 1 per-file | exit 1，`FAIL: skills/foo-t6b.md DEC/§/issue# ref +3（baseline 0 → current 3）` | PASS |
| T7 | find 顺序稳定性 | 循环跑 `find sort` 3 次取 md5 | 3 次一致 | `b22857837f5f82ae2d21c8725d9ec503` × 3 | PASS |
| T8 | workflow.md re-emit 规则（A/B/C 三类 phase gating）删减后完整性 | 读 line 384/386/388 核对规则可读 | 三行均有完整 "Phase Matrix re-emit" 说明 + orchestrator 义务描述；DEC-024 仅 line 20 anchor 一次 | 全三行完整保留：A 类（384）「必须终端渲染 9 行 matrix」 / B 类（386）「emit AskUserQuestion 之前必须」 / C 类（388）「emit `🔄 X → Y` handoff 前必须」 | PASS |
| T8b | workflow.md §Step 7 Relay Write 契约 | 读 line 479+ | DEC-017 anchor 保 line 479；触发条件清晰 | line 479 「**Orchestrator Relay Write（主路径；DEC-017）**」+ 490/491/493 详规；触发条件完整 | PASS |
| T9 | CLAUDE.md line 58 γ 与 DEC-029 post-fix 对齐 | diff CLAUDE.md γ vs decision-log.md DEC-029 post-fix 文本 | "规则主体首次出现" + 3 跳过场景（负面排除子句 / 一笔带过括注 / 表格注解处）1:1 | 完全对齐：CLAUDE.md line 58 "规则主体首次出现（skip 负面排除子句 / 一笔带过括注 / 表格注解处）" = decision-log.md line 134 post-fix "规则主体首次 ... 跳过负面排除子句 / 一笔带过括注 / 表格注解处" | PASS |
| T9b | CLAUDE.md lint_cmd 追 `&& scripts/ref-density-check.sh` 后 shell 实测 | 从 roundtable root 直跑 `grep -rnE "..." skills/ agents/ commands/ && scripts/ref-density-check.sh` | 清洁状态 grep 0 命中 → ref-density 被跑 → exit 0 | **grep 0 命中时 exit 1（因 grep 找不到匹配）→ `&&` 短路 → ref-density 未跑 → 复合命令 exit 1**；**非零命中时 grep exit 0 → 复合命令跑 ref-density，只有此路径才执行 density 检查** | **CRITICAL FAIL** |
| T10a | baseline 末尾追空行 | `echo "" >> baseline` 后裸跑 | tolerate 或明确报错 | exit 0（read 循环跳过空行） | PASS |
| T10b | baseline 行序反转 | `sort -r baseline` | grep -F 精确匹配不依赖行序 → exit 0 | exit 0 | PASS |
| T10c | baseline 某行字段缺失（2 col 而非 4） | 手工改 `agents/reviewer.md\t1` | awk 把 missing 当空串→0，或明确报错 | exit 0（awk `$2+$3+$4` = `1+""+""` = 1） | PASS |
| T10d | baseline 重复 path 行 | 追加第 2 条 `agents/reviewer.md\t1` 同 path | 明确报错或取首行 | **stderr 打印 `line 40: 1\n1: syntax error in expression` 但 exit 0 静默吞错误** | **WARNING** |
| T11a | `# heading #2` 误伤检查 | `grep -cE "issue #[0-9]+\|\bfixes #[0-9]+\|\b#[0-9]{2,}\b"` on "# heading #2" | 0 匹配（`#2` < 2 位+`\b` 前 space 非 word-boundary） | 0 匹配 | PASS |
| T11b | `§3.1.2` / `§3.1` / `§3` 形态 | grep `§[0-9]` | 每行 1 match（line-count） | 1 / 1 / 1 | PASS |
| T11c | `\b#[0-9]{2,}\b` word boundary 语义 | 测 `PR#42` / `thing#42` | 匹配（# 前 word-char→\b 生效） | 匹配 | PASS（**Suggestion**：孤立 `#99`（空格前缀）不匹配此 alternative，但 `issue #99` 分支覆盖；语义 ok 但文档模糊） |
| T12 | lint_cmd 复合命令实测 | 见 T9b | ↓ | **见 T9b Critical** | — |
| T13 | CWD 非 roundtable root 跑脚本 | `cd /tmp && bash /abs/path/scripts/ref-density-check.sh` | 明确报错 or 使用 script 相对路径 | `find: 'skills': No such file or directory` + exit 1（与 per-file fail 同 exit code，易误判） | **SUGGESTION**：脚本头无 `cd "$(dirname "$0")/.."` 锚定，相对路径基于调用 CWD；文档未明示须从 repo root 跑 |
| T14 | 深层子目录 .md 文件 | `mkdir skills/architect/sub; touch foo.md` | find 递归收录 | 收录；0 ref → exit 0 | PASS |
| T15 | 路径含空格 | `mkdir "skills/test space"; touch foo.md` 3 DEC | exit 1 per-file | exit 1，`FAIL: skills/test space/foo.md ... +3` | PASS |
| T16 | DEC-xxx placeholder 不误报 | `grep -cE "DEC-[0-9]+"` on `DEC-xxx` | 0 匹配 | 0 | PASS |
| T17 | Fenced code block 内 DEC ref 计数 | workflow.md / architect SKILL 检查 | 与实际规则位置一致（γ 首处锚点） | SKILL 3 处均在规则主体首处（line 43 DEC-003 / 59 DEC-025 / 85 DEC-013）；无 code block 误伤 | PASS |
| T18 | baseline 合计校验 | `awk sum` baseline | 31 / 20 / 3 → 54 | 31 / 20 / 3 → 54，与 developer 3 轮汇报一致 | PASS |
| T19 | per-file 边界 delta=2 | agents/developer.md +2 DEC | 不触发 per-file `>=3`；total<10 → exit 0 | exit 0 | PASS |

## Critical

### C1: CLAUDE.md §工具链 lint_cmd 使用 `&&` 连接语义反了（enforcement 洞）

**位置**：CLAUDE.md line 40

当前：
```
lint_cmd：`grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/ && scripts/ref-density-check.sh`
```

**复现**（从 roundtable root）：
```
$ grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/ && scripts/ref-density-check.sh
$ echo "exit=$?"
exit=1
```

**根因**：`grep` 当没找到匹配（= 清洁状态，desired）时 exit 1；`&&` 短路使 `scripts/ref-density-check.sh` 在清洁状态下**永不执行**。意图是两个检查都要做，实际成了"只有在 hardcoded 漏出时才跑 density 检查"，enforcement 洞开。

**双向都错**：
- 清洁状态（grep 0 match → exit 1）→ ref-density 不跑 → 复合 exit 1（误报 lint 失败 + 真检查跳过）
- 脏状态 grep 命中 + density 实际超阈 → grep exit 0、ref-density exit 1 → 复合 exit 1（但此时用户只看到 grep 污染，density 消息可能被忽略）

DEC-029 决定 4 原文："追加到 CLAUDE.md §工具链 `lint_cmd` 清单（不替换原 hardcode 扫）" + DEC-029 决定 7 "`lint_cmd` 追 `&& scripts/ref-density-check.sh`"。两个 lint 检查本意是**都跑且独立报告**，不是"取决于前者"。

**建议选项**（不自修，由 architect / developer 选）：
- 方案 A：改 `&&` 为 `;`（容错并存；语义清晰；但 lint_cmd 作为单行失败码语义不再明确——需要单独判读每段输出）
- 方案 B：拆为两条 lint_cmd 独立跑（`lint_cmd_hardcode` + `lint_cmd_density`；更改 CLAUDE.md §工具链 schema）
- 方案 C：用子 shell + 双退码合并：`( grep -rnE "..." skills/ agents/ commands/; grep_rc=$?; scripts/ref-density-check.sh; density_rc=$?; [ $grep_rc -eq 1 ] && [ $density_rc -eq 0 ] )`（最贴原意但可读性差）

## Warning

### W1: line-count 计数法使得同行多 DEC ref 可绕过 per-file 阈值

**复现**（T2'）：往任一文件追加 `<!-- DEC-701 DEC-702 DEC-703 -->` 1 行 → delta=+1 < 3 → pass。实际 3 个 ref 被计作 1。

**影响**：维护者精简时若把多个 DEC 括注合并到同一行（e.g. title 行或表格单行内），会绕过 per-file `>=3` 硬阻。γ 首处锚点语义判定仍需人工，脚本只是量化辅助。

**建议**：在 DEC-029 决定 4 附近（CLAUDE.md §条件触发规则 + scripts/ref-density-check.sh header）文档化"脚本是 line-count 启发式，非 token-count；人工 review 仍是 γ 判定主路径"。或改脚本用 `grep -oE "DEC-[0-9]+" | wc -l`（token-count），但会改变 baseline 语义需重锁。

### W2: 新文件 baseline 未记录且 1-2 ref 时静默 bypass

**复现**（T6）：`skills/foo-t6.md` 含 2 行独立 DEC ref → 脚本 fallback baseline=0 → delta=+2 < 3 per-file → exit 0；total_delta 累加 +2 但离 10 阈值还远。

**影响**：一次性 PR 添加 5 个新 skill/agent 文件每个 2 ref = +10 total ref 刚好触达总阈；+4 个文件每个 2 ref = +8 安全过。扩展 agent/skill 时可能 silent 累积密度。

**建议**：新增 agent/skill 的场景已由 CLAUDE.md §条件触发规则「新增 agent/skill」条约束，应补一句 "新建 prompt 文件完成后跑 `--update-baseline`，不得留在 fallback=0 状态"。或脚本侧增一个 warning：若 current 有但 baseline 无的文件 → stderr `WARNING: <file> not in baseline; considered baseline=0`。

### W3: baseline 重复 path 行触发静默算术错误

**复现**（T10d）：baseline 手动添加第 2 条 `agents/reviewer.md\t1` → 运行脚本 stderr 打印 `line 40: 1\n1: syntax error in expression (error token is "1")` 但 **exit 0 通过**。

**根因**：`b=$(grep -F ... BASELINE)` 在有重复时返回 2 行；`awk` 对 2 行各 print 一次 → `b_total="1\n1"`；`delta=$((c_total - b_total))` 遇多行字符串 → 算术失败；`set -e` 未兜住此 subshell 错误。

**影响**：baseline 手工编辑（例如 developer 跑 `--update-baseline` 前后追加编辑）易意外造出重复；silent 吞错误会让 enforcement 误报绿灯。`--update-baseline` 本身不会造重复（覆盖写），但 diff merge conflict 时可能。

**建议**：脚本开头加 `awk -F'\t' '{print $1}' "$BASELINE" | sort | uniq -d | grep -q . && { echo "ERROR: $BASELINE has duplicate path entries" >&2; exit 2; }`。

## Suggestion

### S1: 脚本 CWD 敏感性未文档化（T13）

脚本内用相对路径 `BASELINE="scripts/ref-density.baseline"` + `ROOTS=(skills agents commands)`。非 roundtable root 调用时：
```
$ cd /tmp && bash /path/to/scripts/ref-density-check.sh
find: 'skills': No such file or directory
find: 'agents': No such file or directory
find: 'commands': No such file or directory
exit=1
```

Exit 1 与"per-file 阈值失败"撞 code，排查时易误导。

**建议**：脚本第 2 行加 `cd "$(dirname "$0")/.."` 锚定 repo root；或 header 注释明示 "run from repo root"。

### S2: issue# regex `\b#[0-9]{2,}\b` word-boundary 含义与 markdown 常见用法冲突（T11c）

`\b#[0-9]{2,}\b` 在 markdown 中匹配率极低（多数 `#` 前是空格，空格-# 两侧都是 non-word char → 无 word boundary）。实际有效匹配的 issue# 引用几乎全走 `issue #[0-9]+` / `\bfixes #[0-9]+` 两个 alternative，`\b#[0-9]{2,}\b` 分支更多是冗余。baseline 测算一致（workflow.md line 364 `issue #26 + #30` 只算 1 line match）。

**建议**：简化 regex 为 `issue #[0-9]+|fixes #[0-9]+|PR #[0-9]+|#[0-9]{2,}[^0-9]`（或按实际用法决）。**非阻塞**；当前语义与 baseline 锁定状态一致。

## 变更记录

- 2026-04-23：新建（tester DEC-029 对抗性测试；19 case；1 Critical + 3 Warning + 2 Suggestion）

<escalation>
{"type":"decision-request","question":"CLAUDE.md line 40 lint_cmd 的 `&&` 连接方向反了（清洁状态下 ref-density-check.sh 永不执行），修正策略需 architect/developer 选","context":"T9b/T12 实测：`grep -rnE '...' skills/ agents/ commands/ && scripts/ref-density-check.sh` 在清洁状态（grep 0 match）下 grep exit 1 → && 短路 → density 检查未跑 → 复合 exit 1。DEC-029 决定 7 意图是两个 lint 都跑且独立报告，当前实现与 decision 不一致。tester 不改业务代码（含 CLAUDE.md），故 escalate。该 bug 由 DEC-029 P3/P4 developer dispatch 引入。所有其他 16 case PASS，仅此项 Critical。","options":[{"label":"`;` 改顺序跑两段","rationale":"最小改动；两 lint 独立跑都打印各自输出。`lint_cmd` exit code 取最后段（ref-density），失去 grep 段失败信号。","tradeoff":"lint_cmd 单退码语义失落，需人工双重判读 stderr","recommended":false},{"label":"拆为 lint_cmd_hardcode + lint_cmd_density 两字段","rationale":"CLAUDE.md §工具链 schema 多一个字段；各自独立 exit code 与执行；orchestrator 跑 lint 时按字段遍历。","tradeoff":"CLAUDE.md schema 变动（影响 `_detect-project-context` / commands/lint.md 调用点）","recommended":true},{"label":"子 shell + 双退码合并表达式","rationale":"保持单行 lint_cmd；最贴 DEC-029 决定 7 原文；两个检查独立跑退码合并。","tradeoff":"可读性差；shell 表达式易手误。grep exit 1（未命中）视为成功需 invert","recommended":false}],"remaining_work":"修正后重跑 T9b/T12 验证 enforcement 路径；评估 W1/W2/W3 是否开 follow-up issue 还是 inline post-fix DEC-029（铁律 4）"}
</escalation>

created:
  - path: docs/testing/prompt-reference-density-audit.md
    description: DEC-029 + scripts/ref-density-check.sh 对抗性测试报告（19 case；1 Critical lint_cmd && 方向反 + 3 Warning line-count bypass / 新文件 silent 2-ref / baseline 重复行 silent 吞 + 2 Suggestion CWD 锚定 / regex word-boundary 冗余）

log_entries:
  - prefix: test-plan
    操作者: tester
    files: [docs/testing/prompt-reference-density-audit.md]
    note: DEC-029 enforcement 对抗性测试 19 case 全跑；CLAUDE.md line 40 lint_cmd `&&` 语义反 = Critical（ref-density-check.sh 清洁态下不可达）；1-2 ref 同行 / 新文件 / baseline 重复行 = Warning；CWD 锚定 / regex word-boundary = Suggestion
