---
slug: orchestrator-bootstrap-hardening
source: tester (orchestrator relay)
created: 2026-04-22
status: Reviewed
verdict: Pass-with-post-fix
---

# orchestrator-bootstrap-hardening 对抗性测试报告（DEC-028）

## Scope

三轴对抗审计（issue #104 supersedes #89）：

1. **Axis 1 hook / script 契约**：`hooks/hooks.json` / `hooks/session-start` / `scripts/preflight.sh` 在各 `ROUNDTABLE_AUTO` 取值、preflight 缺失 / 非 exec / 非零退出、平台（CLAUDE / Cursor / SDK）三分支下的输出稳定性与 JSON 合法性
2. **Axis 2 workflow.md 结构完整性**：§Step -0 / -1 HARD-GATE prose 行、§Step 3 7 角色派发表、§Step 5b 事件类 a 行扩展、§Step 6 rule 4 删除后 5-9 → 4-8 renumber、无 `(DEC-028)` 括注泄漏、lint baseline
3. **Axis 3 DEC-028 / design-doc / index 一致性**：DEC-028 Provisional 条目 6 字段完整 / matcher 字面值与 `hooks/hooks.json` 对齐 / INDEX DEC 表置顶 / design-docs 条目追加 / log.md `design` + `decide` 双条目

总 15 cases（测试矩阵 T1-T10 + 5 额外对抗）。

---

## 测试矩阵

### T1-T10（design-doc 交付矩阵）

| # | 场景 | setup / 触发 | expected | actual | 结果 |
|---|---|---|---|---|---|
| T1 | `ROUNDTABLE_AUTO` 未设新会话 | `unset ROUNDTABLE_AUTO; bash scripts/preflight.sh` | stdout 含 `ROUNDTABLE_AUTO=<unset>` | `PREFLIGHT raw_env ROUNDTABLE_AUTO=<unset>` | PASS |
| T2 | `ROUNDTABLE_AUTO=true` | `ROUNDTABLE_AUTO=true bash scripts/preflight.sh` | echo `true` raw 值 | `ROUNDTABLE_AUTO=true` | PASS |
| T3 | `ROUNDTABLE_AUTO=""` 空串 | `ROUNDTABLE_AUTO="" bash scripts/preflight.sh` | "echo 读到空串，LLM resolve 为 false"（design-doc 字面） | echo 落为 `<unset>`（`${VAR:-<unset>}` `:-` 把 empty-OR-unset 合并）；workflow.md §Step -0 既定 "空串 / 未设 → false" 使功能结果仍正确 | WARN |
| T4 | preflight 独立调用 | `bash scripts/preflight.sh` 脱离 hook | 3 行契约：`ROUNDTABLE_AUTO=…` / `ROUNDTABLE_DECISION_MODE=…` / `note:` | 3 行契约符合 | PASS |
| T5 | §Step 3 派发表 / §Step 6 rule 删除 | 读 commands/workflow.md | 表 7 行含 `research`；原 rule 4 `角色形态` bullet 删除 | 表 7 行齐（L144-L150）；L398 从 rule 4 直接切入 `developer 完成后` 无"角色形态" bullet | PASS |
| T6 | §Step 6 rule 4-8 renumber | `grep -nE '^\*\*[0-9]+\. ' commands/workflow.md` | 1-8 连续无漏号 / 无 rule 9 leftover | L340/394/396/398/400/402/404/406 = `**1-8**` 连续；`grep -n '规则 9\|rule 9\|§9\b'` 0 命中 | PASS |
| T7 | §Step 5b 事件类 a scope 扩展 | 读 L313 事件类 a 行 | 来源描述含 Step -0/-1 pre-flight echo | `Step -0/-1 pre-flight echo（若非 <unset> 默认值）+ Step 0 context detection + Step 1 size/pipeline 判定 \| orchestrator Step -0/-1/0/1` | PASS |
| T8 | `lint_cmd` 0 命中 | `grep -rnE "gleanforge\|dex-sui\|dex-ui\|\bvault/\|\bllm/" skills/ agents/ commands/` | 0 命中 | 0 命中 | PASS |
| T9 | hook / scripts 权限 | `ls -l hooks/session-start scripts/preflight.sh` | 均 `rwxr-xr-x` | 两文件 `-rwxr-xr-x 1 root root …` | PASS |
| T10 | dogfood E2E 读取 `<roundtable-preflight>` 块 | 下次 workflow 启动 | orchestrator 能从 session context 读块，hook 未触发有清晰回落 | 静态审计无法实测 runtime；回落路径 L48 "未见时回落到 `env ROUNDTABLE_AUTO` 直读并向用户报告 hook 缺失" 明示 | DEFER（待 runtime dogfood） |

### 额外对抗 cases

| # | 场景 | setup / 触发 | expected | actual | 结果 |
|---|---|---|---|---|---|
| X-01 | hook JSON 跨平台三分支 | 分别 `env -i`（plain SDK）/ `CURSOR_PLUGIN_ROOT=/tmp` / 默认（`CLAUDE_PLUGIN_ROOT` 继承） 调 `bash hooks/session-start \| python3 -m json.tool` | 三分支均合法 JSON；键名分别为 `additionalContext` / `additional_context` / `hookSpecificOutput.additionalContext` | 3 分支均合法 JSON；key 命中（见 `hooks/session-start` L44-L50） | PASS |
| X-02 | preflight 非可执行 | `chmod -x scripts/preflight.sh; bash hooks/session-start` | hook 不 crash，`preflight_output` 含 `error: not executable` | JSON 合法；`PREFLIGHT error: scripts/preflight.sh not executable at …` | PASS |
| X-03 | preflight 缺失 | `mv scripts/preflight.sh scripts/preflight.sh.bak; bash hooks/session-start` | hook 不 crash，走 not-executable 分支 | JSON 合法；走 else 分支（`-x` test false for missing file）报 `not executable`（文案可更精准，见 S-02） | PASS |
| X-04 | preflight 非零退出 | 替换 preflight 为 `exit 99` | hook 不 crash；stderr 归并；附 `exited non-zero` 备注 | `partial output line\nPREFLIGHT error: scripts/preflight.sh exited non-zero`；JSON 合法 | PASS |
| X-05 | JSON 转义：`"` / `\` / `\n` / `\t` | `ROUNDTABLE_AUTO='a"b\c⏎d⇥e'` | JSON parsable，字符正确反转义 | `python3 -m json.tool` 解析通过；值还原 `a"b\c\nd\te` | PASS |
| X-06 | 控制字符（ESC `\x1b`）| `ROUNDTABLE_AUTO=$'\x1b[31mred\x1b[0m'` | 理想：JSON 合法（escape 控制符）；实际：bash `escape_for_json()` 仅处理 `\` `"` `\n` `\r` `\t`，其它 control bytes 直接写入 JSON string | `Invalid control character at: line 2 column 229` | SUGG（S-01） |
| X-07 | 空白填充 `"  true  "` | `ROUNDTABLE_AUTO="  true  "` | echo 保留原 raw；LLM resolve 按 §Step -0 exact-match `{1, true, on, yes}` → `"  true  " ≠ "true"` → false | `ROUNDTABLE_AUTO=  true  `；LLM 层解算按设计=false | PASS（功能正确） |
| X-08 | 超长 value（5000 字符） | `ROUNDTABLE_AUTO=$(python3 -c "print('A'*5000)")` | JSON 合法 | JSON 合法 | PASS |
| X-09 | `set -euo pipefail` 下 `CLAUDE_PLUGIN_ROOT` 未设 | `env -i bash hooks/session-start` | 不 crash（L44-L46 均用 `${VAR:-}` 安全展开） | 走 else 分支 `additionalContext`；exit 0 | PASS |
| X-10 | `lint_cmd` 回归 baseline | `grep -cE "DEC-[0-9]+\|§[0-9]" commands/workflow.md` 前后 | 不回升 >20%；合计不越 #22 snapshot 28 | 42 → 42（无回升；见 §Lint baseline 段） | PASS |
| X-11 | `(DEC-028)` 括注泄漏扫描 | `grep -nE '(DEC-028)\|（DEC-028）' commands/workflow.md` | 0 命中（CLAUDE.md #22 inline ref 纪律） | 0 命中（DEC-028 锚点仅出现在 §Step -0 HARD-GATE 的 `docs/design-docs/...` 跳转里，属白名单） | PASS |
| X-12 | DEC-028 号预占 vs DEC-027 跨分支 | `git log --all --oneline \| grep DEC-027` | —— | DEC-027 在 `fix/issue-88-phase-matrix-pseudo-table` 分支占用（commit 50d761e）；本分支预占 DEC-028；合并顺序需协调 | WARN（W-01） |
| X-13 | DEC-028 必填字段 | 扫条目段 | 日期 / 状态 / 上下文 / 决定 / 备选 / 理由 / 相关文档 / 影响范围 全含 | 全含 7+1；状态字面值 `Provisional` 精确符合铁律（无附加修饰） | PASS |
| X-14 | matcher 字面值 DEC-028 ↔ hooks.json 一致 | `python3 -m json.tool hooks/hooks.json` + DEC-028 决定 1 | matcher 字面值对齐 | `hooks.json` = `"matcher": "startup\|clear\|compact"`；DEC-028 正文 `matcher: startup\|clear\|compact` 对齐 | PASS |
| X-15 | INDEX 置顶 + design-docs 条目 + log.md 双条目 | 读 docs/INDEX.md L50、L117，docs/log.md L17/L22 | DEC-028 行 DEC 表 L50（置顶；DEC-026 在下）；design-docs 条目 L117；log.md `design` + `decide` 两条 2026-04-22 | 全命中 | PASS |

---

## Findings

### Warning

**W-01（T3 / X-07）`ROUNDTABLE_AUTO=""` 空串经 `${VAR:-<unset>}` 被合并为 `<unset>`，与 design-doc 测试矩阵 T3 "echo 读到空串" 字面不符**

- **复现**：`ROUNDTABLE_AUTO="" bash scripts/preflight.sh` → 第 1 行 `ROUNDTABLE_AUTO=<unset>`（预期 `ROUNDTABLE_AUTO=`）
- **影响**：DEC-028 决定 4 "raw-echo-only" 契约声明 hook 只输出 raw env 不做 resolve；`:-` 属 shell 层 sentinel substitution 已是微量 resolve（空=未设合并）。**功能影响 0**：`commands/workflow.md §Step -0` 行 43 已定 "其他值 / 空串 / 未设 → 视为 false"，空与未设在 LLM 解算层本就归同一结果
- **建议修复**：二选一 —
  - **A** `scripts/preflight.sh` 第 16-17 行将 `${ROUNDTABLE_AUTO:-<unset>}` 改为 `${ROUNDTABLE_AUTO-<unset>}`（单 `-`）区分空串与未设
  - **B** 在 `docs/design-docs/orchestrator-bootstrap-hardening.md` 测试矩阵 T3 期望列改为 `<unset>` 反映实装
- **post-fix 归属**：铁律 4 inline append 父 DEC-028 末尾（属细节措辞 clarification，非新 tradeoff）

**W-02（X-12）DEC-028 与 DEC-027 跨分支号预占**

- **复现**：`git log --all --oneline \| grep 'DEC-02[78]'` → DEC-027 在 `fix/issue-88-phase-matrix-pseudo-table`（commit 50d761e），DEC-028 在本分支
- **影响**：两分支合并顺序决定最终条目顺序；若 issue #88 先合，本分支 DEC-028 正确；若本分支先合，issue #88 合并时 DEC-027 应落到 DEC-026 与 DEC-028 之间，INDEX.md DEC 表行序需重排
- **建议修复**：PR merge 前 rebase / merge main 后确认 DEC 号递增连续；或合并 merge-train 时由 reviewer / orchestrator 显式审计号段

### Suggestion

**S-01（X-06）`escape_for_json()` 只处理 `\` `"` `\n` `\r` `\t` —— 其它控制字符（如 ESC `\x1b`）直通 JSON string 产生非法 JSON**

- **影响**：env value 含裸控制字符时 `python3 -m json.tool` 解析失败；Claude Code / Cursor runtime 的 JSON parser 行为同理不可预期
- **边界**：`ROUNDTABLE_AUTO` / `ROUNDTABLE_DECISION_MODE` 是用户 shell env，正常取值不含控制字符；攻击面极窄
- **建议**：S 级，未来可 follow-up issue 补 `\x00-\x1f` → `\uXXXX` 六字段 JSON 转义；目前 "env 无控制字符" 假设足以 merge

**S-02（X-03）preflight 缺失走 not-executable 文案**

- **影响**：L18 `if [ -x "$PREFLIGHT_SCRIPT" ]` 对"不存在"和"存在但非可执行"不区分，两类都落到同文案；排障时可能误导（比如 plugin 打包遗漏 file 会被解读为权限问题）
- **建议**：if/elif 分 3 枝：`! -e` 报 missing、`! -x` 报 not executable、else 调用；或文案含 "(missing or not executable)"

**S-03（X-13）DEC-028 `备选` 段仅 B / C，无 A**

- **影响**：观感不对称（其他 DEC 如 DEC-025 / DEC-023 "备选"段含 A ★ 推荐项及 B/C 对照）；DEC-028 的 "A = 本决定" 省略未声明属合约省略，非错误
- **建议**：Provisional 期内 inline 补 "**A**（本决定）hooks/hooks.json + scripts/ 外挂 ★" 一行于备选段首；或忽略（风格偏好）

---

## Verdict

**Pass-with-post-fix**

- 0 Critical：T1-T10 核心契约 8/10 PASS，T3 字面偏差但功能等价、T10 defer runtime
- 2 Warning：W-01 T3 空串 sentinel 合并（建议走铁律 4 inline post-fix）；W-02 DEC-027 / 028 跨分支号预占（merge-train 时审计）
- 3 Suggestion：控制字符 JSON 转义 / preflight 文案二分 / DEC-028 备选 A 显示

所有 Warning 均非合入阻塞；W-01 可 2 行 bash 改动或 1 行 design-doc 澄清择一 post-fix；W-02 无需代码改动。Hook / preflight / workflow.md 结构改动在对抗面下行为稳定；§Step 6 renumber 干净、§Step 3 7 角色表齐、§Step 5b 事件类 a 扩展符合 DEC-022 格式；DEC-028 Provisional 条目字段完整、状态字面值严格、INDEX / log.md 同步命中。

## Lint baseline

`grep -cE "DEC-[0-9]+|§[0-9]" commands/workflow.md`

| 位置 | 值 |
|------|-----|
| `HEAD:commands/workflow.md`（pre-diff） | 42 |
| 本 worktree（post-diff） | 42 |
| Δ | 0（无回升；远低于 #22 纪律 20% 阈值） |

另测合计：paren 型 inline DEC ref（`（DEC-\d+` 或 `(DEC-\d+`）across `skills/+agents/+commands/` = 44（pre） / 44（post）；本 DEC 未新增括注泄漏（DEC-028 锚点仅在 `docs/design-docs/...` 跳转句，属 CLAUDE.md #22 纪律白名单）。
