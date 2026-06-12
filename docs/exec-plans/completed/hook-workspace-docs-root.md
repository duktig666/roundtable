---
slug: hook-workspace-docs-root
date: 2026-06-12
status: active
analysis: ../../reviews/2026-06-12-comprehensive-review.md
issue: 127
---

# Hook 双模式重写：workspace 支持 + docs_root 越界修复

## Solution（设计已与 user 确认，2026-06-12）

线上 bug：codex 下 cwd 在无 `docs/` 的 git 项目内，hook walk-up 越过 git toplevel 爬到 `~/docs`（`project_id: pm` + `docs_root: /home/ubuntu/docs`）。同时 user 常在非 git 的父级工作区（如 `/data/rsw`，下挂多个 git 子项目）启动会话，会话级单一 docs_root 是伪命题。

hook 改双模式：

- **project 模式**（cwd 在 git repo 内）：解析顺序 env `ROUNDTABLE_DOCS_ROOT` > `<git_top>/.roundtable.json` > 以 git_top 为界的 walk-up（带结构校验）。
- **workspace 模式**（cwd 不在 git repo 内）：扫一层子目录找 git 子项目，注入项目清单，docs_root 由 skills 按任务目标子项目延迟解析。

输出协议改为单条 JSON 同时含 `additionalContext` + `hookSpecificOutput` 两键，删除全部 env 探测分支（`CURSOR_PLUGIN_ROOT` / `COPILOT_CLI` 无事实来源）。

来源：[2026-06-12 全面审查报告](../../reviews/2026-06-12-comprehensive-review.md) 问题 1.1/1.2/1.3/1.4/5.1/5.2 + 「父级工作区场景」节。

## 设计决策（已定，不要重开）

- **DEC-1 双键输出**：无条件输出 `{"additionalContext":"<ctx>","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"<ctx>"}}` 单行 JSON；各 runtime 忽略不认识的键。
- **DEC-2 worktree project_id**：`git rev-parse --path-format=absolute --git-common-dir` 回推主仓根（common-dir basename 为 `.git` 时取其 dirname），project_id = 主仓根 basename。`.roundtable.json` 的 `project_id` 键可覆盖。
- **DEC-3 `.roundtable.json` 解析**：位于 `<git_top>/`，平铺 JSON，仅认 `docs_root`（相对 git_top 或绝对路径）与 `project_id` 两个字符串键。有 python3 用 `json` 模块解析，否则 sed 提取平铺字符串值（注释说明限制）。指向不存在目录 → context 加 warning 行并继续走下一级。
- **DEC-4 结构校验**：walk-up 命中的候选目录须含 `{analyze,design-docs,exec-plans,testing,reviews,bugfixes}` 之一或 `INDEX.md` 才算 `status: ok`；存在但无结构 → 仍报 docs_root 但 `status: needs-init` + note（workflow 可在确认后建骨架——建骨架本身不在本期范围）。env / config 显式指定的路径**不做**结构校验（用户显式配置即生效）。
- **DEC-5 workspace 判定**：cwd 无 git_top → 扫 `<cwd>/*/` 一层，`-e <d>/.git`（兼容 worktree/submodule 的 .git 文件）即算项目；≥1 个 → `mode: workspace`；0 个 → 仅检查 `<cwd>/docs|documentation`（不向上爬，无边界可依），无则 needs-init。父级不引入配置文件。
- **DEC-6 context 字段**：project 模式输出 `mode/docs_root/docs_root_source(env|config|walk-up)/project_id/git_top/status`；workspace 模式输出 `mode/workspace_root/projects（name 后缀 `(docs)` 标记有无）/status: ok`+ note 指示按任务解析 `<workspace_root>/<proj>/docs`。needs-init 的 note 改中性措辞 "prompt the user to set one"（不写死 AskUserQuestion，channel-aware）。
- **DEC-7 健壮性**：`cwd="$(pwd 2>/dev/null || echo "$PWD")"`；escape 函数补 `\b` `\f`；消灭行尾 `[ ... ] && ...` 模式改 `if/fi`。
- **DEC-8 范围外**：needs-init 建骨架、codex-tools 去重、lint orphan 修复、文档债清算均不做（归 PR-2/PR-3）。

## Phases

### Phase 1: hook 重写（hooks/session-start）

- [x] 1.1 git 上下文前置：git_top + DEC-2 worktree-safe project_id
- [x] 1.2 project 模式解析链：env（无效则 warning 继续）→ `.roundtable.json`（DEC-3）→ bounded walk-up（终止条件 `dir` 越出 git_top 即停，含 git_top 自身；`docs/` 优先 `documentation/`；DEC-4 结构校验）
- [x] 1.3 workspace 模式（DEC-5/DEC-6）
- [x] 1.4 双键输出 + 删 env 探测分支（DEC-1），escape 补 `\b\f`，DEC-7 健壮性
- [x] 1.5 hooks.json：matcher 保持 `startup|clear|compact`，删除非标 `"async"` 字段

### Phase 2: skills/docs 配套

- [x] 2.1 `skills/workflow/SKILL.md` Step 1 重写：识别 `mode: workspace` → 从任务描述/issue/涉及文件推断目标子项目，推断不出按 channel-aware 规则问用户；解析出 `docs_root=<workspace_root>/<proj>/docs` 后带入所有角色派发参数。此段为 canonical，供 bugfix/lint 引用
- [x] 2.2 `skills/bugfix/SKILL.md` Step 1：加一行引用 workflow Step 1 的 workspace 解析规则
- [x] 2.3 `skills/lint/SKILL.md` Step 1：`mode: workspace` 且未传路径参数 → 列项目清单让用户选一个，不默认全量
- [x] 2.4 `README.md`：文档化 `.roundtable.json`、workspace 模式、`ROUNDTABLE_DOCS_ROOT`、双键输出协议（替换原 hook 行为描述，README-zh 同步）
- [x] 2.5 `CHANGELOG.md` [Unreleased] 加条目

### Phase 3: 单测（developer 自带）

- [x] 3.1 新建 `tests/session-start.test.sh`：纯 bash 测试 harness（mktemp -d 造 fixture，python3 校验 JSON 与断言字段），覆盖：
  - project 模式命中 `docs/`（含结构）→ ok / source=walk-up
  - **越界回归**：git 项目无 docs/、父级有 `docs/` → 不越界，needs-init（本 bug 的复现测试，先红后绿）
  - docs/ 存在但无结构 → needs-init + docs_root 仍报
  - env 有效 / env 指向不存在目录 → warning + 降级
  - `.roundtable.json` 相对与绝对路径 → source=config；project_id 覆盖
  - workspace 模式：非 git 父级 + 2 个 git 子项目（一个有 docs 一个没有）→ 清单正确
  - 非 git 且无子项目 → needs-init
  - `git worktree add` 场景 → project_id = 主仓名
  - 所有 case 输出均为合法 JSON 且双键齐备
- [x] 3.2 全部测试通过（`bash tests/session-start.test.sh` exit 0）

## Verification

- `bash tests/session-start.test.sh` 全绿
- 手动：在 `/data/rsw`（workspace）、`/data/rsw/roundtable`（project）、`/data/rsw/dex-ui`（git 无 docs，需 needs-init 不得报 `/data/rsw/docs` 或 `~/docs`）三处跑 hook 验证输出

## Change Log

- 2026-06-12 user 确认 PR-1 范围与双模式设计（含「父级工作区」补充）
- 2026-06-12 tester 发现 BUG-1（escape 未覆盖全部 C0 控制字符）/ BUG-2（GIT_DIR 污染误判 project 模式）/ GAP-1（ROUNDTABLE_DOCS_ROOT 相对路径透传），已修复；两套测试全绿（STRICT=1 含 known-bug 转正）
- 2026-06-12 reviewer NEEDS-CHANGES（reviews/2026-06-12-hook-workspace-docs-root.md）：MAJOR-1 symlink cwd 致 walk-up 边界失效（DEC-7 spec 的逻辑路径洞，#127 边界目标优先于 DEC-7 字面）→ cwd 改 `pwd -P` 物理路径 + T9 symlink 越界回归 case（先红后绿已验证）；MINOR-1 README×2/CHANGELOG/hook 注释 "seven/七" 改 six/六（与 DEC-4 六目录一致）；MINOR-2 取改动更小方案——lint Step 1 加 canonical 引用（workflow Step 1）；MINOR-4 测试侧硬编码 `/usr/bin/bash` 改 `"$BASH"`，`${var@Q}` 替换代价大改为文件头声明需 bash ≥4.4（hook 本体 bash 3.2 兼容不动）。MINOR-3/MINOR-5 reviewer 定级可接受，不修。修后两套测试全绿（49 + 301，STRICT=1 0 known-bug）
