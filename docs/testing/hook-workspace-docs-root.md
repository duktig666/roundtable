---
slug: hook-workspace-docs-root
date: 2026-06-12
role: tester
issue: 127
source: exec-plans/active/hook-workspace-docs-root.md
---

# hook-workspace-docs-root — 测试报告（对抗）

被测对象：`hooks/session-start`（双模式重写）+ `hooks/hooks.json` / `.codex-plugin/plugin.json` 声明。

测试文件：

- `tests/session-start.test.sh` — developer 自带，11 case / 44 断言，全绿（回归确认）
- `tests/session-start.adversarial.test.sh` — 本次新增对抗套件，**297 断言通过 / 0 失败 / 2 known-bug**（`STRICT=1` 时 known-bug 计入失败、exit 1）

每个 case 均强制校验输出契约：退出码 0、stdout 单行非空、stderr 静默、合法 JSON、双键 context 一致、`hookEventName: SessionStart`。

## Coverage（覆盖矩阵）

| 组 | 攻击面 | case | 结果 |
|----|--------|------|------|
| A1–A10 | 敌意路径名：空格 / 中文 / 单引号 / `$VAR` / `$(…)` / 反引号 / `*` / `[…]` / 双引号 / 反斜杠，project_id 与 docs_root 必须字面输出且无副作用 | 10 | 全过，无注入 |
| A11 | 目录名含换行 → `\n` 转义后 JSON 合法 | 1 | 过 |
| A12 | 目录名含 `\x0b`（vertical tab）等未覆盖控制字符 | 1 | **KNOWN-BUG-1** |
| B1–B15 | `.roundtable.json`：非法 JSON、值为数组/数字/null/空串、嵌套同名键、空文件、chmod 000、10k 超长值、转义引号、project_id 带引号、`../` 逃逸、config 是目录、`$(…)` 注入载荷、值含换行 | 15 | 全过（B12 逃逸为 DEC-3 显式信任语义，特征化） |
| C1–C5 | `ROUNDTABLE_DOCS_ROOT`：相对路径、尾斜杠、指向文件、空串、含空格 | 5 | 过（C1 见 GAP-1） |
| D0–D5 | sed fallback（PATH 藏掉 python3）：平铺提取、嵌套键误取、walk-up/needs-init、workspace 模式、破损 JSON 仍提取 | 6 | 过（D2/D5 为退化语义特征化，见 GAP-2） |
| E1–E4 | workspace：50 子项目全量枚举、`-` 开头 / 字面 `*` / 空格 / 中文子目录、`.git` 文件（submodule 形态）、悬空与有效 symlink、根目录名含 glob 字符 | 4 组 | 全过 |
| F1–F4 | git 环境异常：GIT_DIR 污染、GIT_WORK_TREE 单独污染、bare repo、git 不在 PATH | 4 | F1 **KNOWN-BUG-2**，其余过 |
| W1–W6 | walk-up 补充：仅 `documentation/`、同级结构优先、docs 是文件、边界内 fallback 不越界（比 T2 强）、就近结构化目录优先、幂等性 | 6 | 全过 |
| G1–G2 | hooks.json 与 codex plugin.json 声明、可执行位 | 2 | 过（声明分叉见 INFO-1） |

## New Cases (Adversarial / E2E / Benchmark)

新增 `tests/session-start.adversarial.test.sh`，独立可跑：

```
bash tests/session-start.adversarial.test.sh          # known-bug 不计失败
STRICT=1 bash tests/session-start.adversarial.test.sh # known-bug 计失败（修复验证用）
```

## Found Bugs / Gaps（按严重度）

### BUG-1（低，契约破坏）：未覆盖的控制字符产生非法 JSON，hook 哑火

`escape_for_json` 只转义 `\n \r \t \b \f`，其余 <0x20 控制字符（如 `\x0b`、`\x1b`）随路径名原样进入 JSON 字符串 → 严格 JSON 解析器拒绝 → SessionStart 输出整体不可用，所有角色拿不到 context。触发概率低（需目录名含控制字符），但违反「hook 任何情况下不得哑火」契约。

复现：

```bash
t=$(mktemp -d); repo="$t/ev"$'\x0b'"il"; mkdir -p "$repo/docs/analyze"
git -C "$repo" init -q
(cd "$repo" && bash hooks/session-start) | python3 -c 'import json,sys; json.loads(sys.stdin.read())'
# json.decoder.JSONDecodeError: Invalid control character
```

测试：A12（KNOWN-BUG 标记，修复后自动转绿）。建议修法：escape 函数兜底把 <0x20 其余字符替换为 `\u00XX` 或直接剔除。

### BUG-2（中，环境污染误判）：继承的 GIT_DIR 使非 git cwd 误报 project 模式

hook 不清洗 `GIT_DIR` / `GIT_WORK_TREE`。父进程环境若带 `GIT_DIR`（脚本/CI/工具常见导出），git 会把任意 cwd 当作该仓的 worktree 顶层：`git rev-parse --show-toplevel` 返回 cwd 本身 → hook 报 `mode: project`、`git_top: <非 git 的 cwd>`、`project_id: <外部仓名>`，与 #127 要修的「注入错误上下文」同类。

复现：

```bash
t=$(mktemp -d); mkdir -p "$t/foreign" "$t/plain"; git -C "$t/foreign" init -q
(cd "$t/plain" && GIT_DIR="$t/foreign/.git" bash hooks/session-start)
# → "mode: project ... project_id: foreign ... git_top: <plain>"，实际 plain 不是 git 仓
```

测试：F1（KNOWN-BUG 标记）。建议修法：hook 开头 `unset GIT_DIR GIT_WORK_TREE`（hook 语义始终基于 cwd 物理位置，按 cwd 探测不应受调用方 env 影响）。注：`GIT_WORK_TREE` 单独污染（F2）git 自身会报错退出，hook 安全降级，无此问题。

### GAP-1（低）：`ROUNDTABLE_DOCS_ROOT` 相对路径原样透传

`ROUNDTABLE_DOCS_ROOT=docs` 时 `-d` 按 hook 进程 cwd 判真，context 输出 `docs_root: docs`（相对路径）。消费方（subagent / skill）cwd 不同时解析会落空。建议在接受时归一化为绝对路径（`cd && pwd` 或前缀 `$cwd/`）。测试：C1（特征化，记录现状）。尾斜杠（C2）原样保留，纯外观，不重要。

### GAP-2（信息，已在代码注释声明）：sed fallback 会误取嵌套同名键

无 python3 环境下 `{"nested": {"docs_root": "evil"}}` 被 sed 提取出 `evil`；若该路径恰好存在则以 `status: ok` 误报（D2 实测）。破损 JSON 中的合法形态键值行也会被提取（D5）。DEC-3 注释已声明此限制，维持现状可接受；若要收紧可在 README `.roundtable.json` 一节明示「无 python3 时仅支持平铺单层」。

### INFO-1：hooks.json 与 .codex-plugin/plugin.json 的 hook 声明分叉

- matcher：`startup|clear|compact`（hooks.json） vs `*`（codex）
- codex 侧保留 `"async": false`（exec-plan 1.5 只从 hooks.json 删了非标 `async`）
- codex 侧直接 exec 脚本（无 `bash` 前缀）——依赖可执行位，已验证 `rwxr-xr-x`（G2）

两份声明指向同一脚本（G1 过）。分叉可能是 #124 codex schema 故意为之；若非故意，建议下个 codex 相关 PR 顺手对齐。不阻塞本 PR。

### INFO-2：config `../` 逃逸 repo 被信任

`{"docs_root": "../outside"}` 解析为 `<git_top>/../outside` 且 `status: ok`（B12）。符合 DEC-3/DEC-4「显式配置即生效」语义，按设计放行；记录在案以防后续误判为越界 bug。

## 结论

walk-up 边界（#127 核心修复）、敌意路径转义、配置畸形输入、sed 降级、workspace 扫描、输出契约均稳健；发现 2 个真实 bug（BUG-1 低 / BUG-2 中）已留失败复现断言（KNOWN-BUG 标记，`STRICT=1` 可见红），2 个 gap + 2 条信息项供后续决策。
