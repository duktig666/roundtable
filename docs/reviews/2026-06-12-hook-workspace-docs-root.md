---
slug: hook-workspace-docs-root
date: 2026-06-12
role: reviewer
issue: 127
source: exec-plans/active/hook-workspace-docs-root.md
---

# hook-workspace-docs-root — Code Review（2026-06-12）

审查范围：`git diff main...HEAD`（4 commits：ebdaa56 / 4476e36 / 43d270a / 0b570dd），对照 exec-plan DEC-1~DEC-8 与测试报告 `testing/hook-workspace-docs-root.md`。两套测试本机复跑全绿（44 + 301 断言，`STRICT=1` 下 0 known-bug）。

## 结论：NEEDS-CHANGES

MAJOR-1 一条修掉即可 merge（一行改动 + 一个回归 case）；minor 均可随本 PR 顺手修或归 follow-up。

## Major

### MAJOR-1：symlink 路径下 walk-up 边界失效，#127 越界 bug 可复现回归

- `hooks/session-start:21`（根因）+ `hooks/session-start:139`（失效的边界比较）

`cwd` 取自 `pwd`（逻辑路径，含 symlink），而 `git_top` 来自 `git rev-parse --show-toplevel`（git 返回物理路径）。当 cwd 路径中含任何 symlink 时两者永不相等，walk-up 的终止条件 `[ "$dir" = "$git_top" ]` 永不触发，循环一路爬到 `/` —— 这正是本 PR 要消灭的越界行为。复现（已实测）：

```bash
t=$(mktemp -d)
mkdir -p "$t/real/proj/src" "$t/real/docs/design-docs"
git -C "$t/real/proj" init -q
ln -s "$t/real" "$t/link"
(cd "$t/link/proj" && bash hooks/session-start)
# → docs_root: <t>/link/docs（repo 外的父级 docs！）, status: ok, git_top: <t>/real/proj
```

触发条件现实存在：macOS 上 `/tmp → /private/tmp`、用户惯用 symlink 工作目录；Claude Code/Codex 子进程继承 shell 的逻辑 `PWD`，bash 启动时校验 inode 一致即沿用逻辑路径。与 exec-plan「绝不越过 repo 边界」的核心目标直接冲突（exec-plan Solution 节 + DEC-7）。

修法：`hooks/session-start:21` 改 `cwd="$(pwd -P 2>/dev/null || pwd 2>/dev/null || echo "$PWD")"`，统一为物理路径（GAP-1 的相对路径归一化同时受益）。DEC-7 原文规定的 `pwd || echo $PWD` 本身留了这个洞，属于 spec 缺陷而非实现偷懒——但 #127 的边界目标优先级高于 DEC-7 字面。

佐证：两套测试 harness 的 `new_tmp` 都用 `pwd -P` 并注释「消除符号链接，避免与 git rev-parse 物理路径不一致」（`tests/session-start.test.sh:27`、`tests/session-start.adversarial.test.sh:34`）——问题已被意识到，却只在测试侧归一化，把洞留在了被测对象里。修复时请补一个 symlinked-cwd 越界回归 case（上面的复现即可直接转 case）。

## Minor

### MINOR-1：README/CHANGELOG 写 "seven roundtable dirs"，代码只校验六个

- `hooks/session-start:27`（`analyze design-docs exec-plans testing reviews bugfixes`，共 6 个）
- `README.md:148` / `README-zh.md:148` / `CHANGELOG.md:17` 均写 "seven"/「七个」

DEC-4 列的就是这 6 个（无 `prd`），实现与 DEC-4 一致；文档数错了。改文档为 six/六个（或在 DEC 层面决定把 `prd/` 加进 `has_structure`，但那要改 exec-plan，不建议本 PR 扩）。

### MINOR-2：workflow 声称 lint 引用 canonical 规则，lint 实际未引用

- `skills/workflow/SKILL.md:18`："This paragraph is the canonical workspace-resolution rule — `bugfix` and `lint` reference it."
- `skills/bugfix/SKILL.md:15` 确实引用了 ✓；`skills/lint/SKILL.md:13` 是自含的内联规则（列清单让用户选一个），无任何指向 workflow Step 1 的引用
- `CHANGELOG.md:11` 重复了同样的说法

lint 的行为本身符合 exec-plan 2.3（列项目清单、不默认全量）✓，只是交叉引用声明不实。要么 lint Step 1 加半句 "（canonical rule: workflow Step 1）"，要么 workflow/CHANGELOG 改成只说 bugfix references it。

### MINOR-3：git < 2.31 时 DEC-2 worktree project_id 静默降级

- `hooks/session-start:74`：`--path-format=absolute` 是 git 2.31+ 选项，老 git 整条命令失败，fallback `echo "$git_top/.git"` 使 linked worktree 的 project_id 退化为 worktree 目录名（DEC-2 要的是主仓名）。降级安全不崩，可接受；如要彻底，可用无版本要求的 `git rev-parse --git-common-dir` 再手动绝对化。记录在案即可。

### MINOR-4：测试套件本身不可在 macOS 系统 bash 3.2 下运行

- `tests/session-start.test.sh:68`（及多处）/ `tests/session-start.adversarial.test.sh:78`（及多处）：`${var@Q}` 是 bash 4.4+ 特性
- `tests/session-start.adversarial.test.sh:67,387`：硬编码 `/usr/bin/bash`（macOS 为 `/bin/bash`，NixOS 亦无此路径）

测试是开发侧资产，CI/Linux 跑没问题，故仅 minor。**hook 本体已逐特性核对**：`printf -v`（3.1+）、`${s//pat/rep}`、`$'\n'` 于模式与替换位、`${var%$'\n'}`、`shopt nullglob`、`break 2`、heredoc、无数组/`declare -A`/`mapfile`/`@Q` —— bash 3.2 兼容 ✓。C0 转义循环的替换串含 `\u00XX` 反斜杠，在双引号上下文中各版本（含 5.2 patsub_replacement）均按字面保留，无版本分叉。

### MINOR-5：workspace 项目清单分隔符可被目录名伪造

- `hooks/session-start:169-173`：清单用 `, ` 拼接，子目录名本身含 `, `（如 `evil, fake (docs)`）会伪造出不存在的清单条目。消费方是 LLM 展示层、无执行语义，建议级；如要修可对 name 中的 `,` 做标注或改行分隔。

## DEC 符合度核对

| DEC | 结论 |
|-----|------|
| DEC-1 双键输出 | ✓ `hooks/session-start:253` 单行双键，两份 context 一致（测试逐 case 断言）；env 探测分支已全删 |
| DEC-2 worktree project_id | ✓ `:74-79` common-dir 回推 + config 覆盖（T8/D1）；老 git 降级见 MINOR-3 |
| DEC-3 config 解析 | ✓ python3 优先 / sed 退化（限制有注释，D2/D5 特征化）；不存在目录 → warning 继续 ✓ |
| DEC-4 结构校验 | ✓ env/config 不校验、walk-up 校验、无结构报 needs-init 仍给 docs_root；目录集 6 个与 DEC-4 一致（文档数字错，见 MINOR-1） |
| DEC-5 workspace 判定 | ✓ `-e .git` 兼容 gitfile（E2）、0 项目仅查 cwd 不向上爬（`:183-199`） |
| DEC-6 context 字段 | ✓ 两模式字段齐；needs-init note 用中性 "prompt the user" 措辞 ✓ |
| DEC-7 健壮性 | 字面 ✓（pwd 回退、`\b\f`、无行尾 `&&` 模式），但 spec 本身的逻辑路径洞见 MAJOR-1 |
| DEC-8 范围外 | ✓ 未见建骨架/codex-tools/lint orphan 等越界实现 |

walk-up 解析链优先级（env > config > walk-up）、env 失效降级、config project_id 独立于 docs_root 生效，均与 exec-plan 1.2 一致。

## 双消费端契约

- Claude Code：`hookSpecificOutput.hookEventName: "SessionStart"` + `additionalContext` 符合 schema；多出的顶层键被忽略 ✓
- Codex：顶层裸 `additionalContext` ✓
- 退出码 0 / stdout 单行 / stderr 静默由对抗套件逐 case 强校验 ✓
- `hooks/hooks.json` 仅删非标 `async`、matcher 保持，符合 1.5 ✓（codex plugin.json 的 matcher `*` 分叉为存量问题，测试报告 INFO-1 已记，DEC-8 范围外）

## 测试质量

- 断言真实：contains/not-contains 均带具体 needle，contract 检查非恒真；T2/W4 是真越界回归（构造父级带结构 docs 并断言 not-contains）✓
- known-bug 机制：BUG-1/BUG-2 修复后 A12/F1 自动转绿，实测 `STRICT=1` 0 known-bug ✓
- fixture 清理：两套各自 `trap cleanup EXIT` + chmod 恢复（B7）✓；互不共享状态、可独立运行 ✓
- 缺口：无 symlinked-cwd case（被 `new_tmp` 的 `pwd -P` 主动规避，归 MAJOR-1）；`/tmp/pwned` 哨兵若宿主机预存在同名文件会假阳性失败（极次要）

## Surgical Changes

diff 中 11 个文件全部可追溯到 #127：hook 重写、hooks.json 删 async、3 个 skill Step 1、README×2 同节、CHANGELOG Unreleased、两套测试、测试报告。无夹带重构、无无关格式改动 ✓。

## 问题清单汇总

| 级别 | 编号 | 一句话 |
|------|------|--------|
| major | MAJOR-1 | symlink cwd 下 walk-up 边界失效，#127 越界可复现（`pwd -P` 一行修） |
| minor | MINOR-1 | 文档 "seven dirs" vs 代码六个 |
| minor | MINOR-2 | lint 未引用 canonical 规则，workflow/CHANGELOG 声明不实 |
| minor | MINOR-3 | git<2.31 worktree project_id 静默降级 |
| minor | MINOR-4 | 测试套件用 `${@Q}`/硬编码 `/usr/bin/bash`，macOS bash 3.2 跑不了 |
| minor | MINOR-5 | workspace 清单 `, ` 分隔可被目录名伪造（建议级） |
