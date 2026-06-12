---
slug: comprehensive-review
date: 2026-06-12
reviewer: botB (主 agent + 2 子 agent)
scope: 全插件（hooks / skills / agents / commands / manifests / docs）+ 参考项目 mattpocock/skills 对比
---

# Roundtable 全面审查报告

触发背景：codex 下 SessionStart hook 报 `project_id: pm` 但 `docs_root: /home/ubuntu/docs` —— project_id 判定在项目级、docs_root 却落到了用户目录。本报告含该 bug 根因 + 全插件问题清单 + 可借鉴项（参考 https://github.com/mattpocock/skills ）。

## 〇、报告 bug 根因（docs_root 越界）

`hooks/session-start:17-25`：walk-up 循环从 cwd 向上找 `docs/` / `documentation/`，终止条件只有 `dir != "/"`，**不在 git toplevel 停**。pm 项目没有 `docs/`，循环越过仓库根爬到 `/home/ubuntu`，捡到无关的 `~/docs`。而 `git_top` 在第 29 行才计算（晚于循环），所以现有代码拿不到边界。

三层修法（建议合一个 PR）：

1. 把 `git rev-parse --show-toplevel` 挪到循环前，walk-up 不越过 `git_top`（无 git 时以 `$HOME` 为界）。
2. 命中目录做结构校验：候选 `docs/` 须含 7 个规范子目录之一或 `INDEX.md` 才算 ok，否则继续 / 报 `needs-init`——防止 Docusaurus 类 `docs/` 误命中。
3. `ROUNDTABLE_DOCS_ROOT` 设置了但目录不存在时（第 14 行）目前静默忽略，应在 context 里报 warning。

## 一、正确性 bug

| # | 问题 | 位置 | 严重度 |
|---|------|------|--------|
| 1.1 | docs_root walk-up 越界（见上） | session-start:17-25 | 高 |
| 1.2 | Codex 协议分支与 design-doc 自相矛盾：design-doc:294 称 Codex 注入 `CLAUDE_PLUGIN_ROOT` 可复用 Claude 分支（`hookSpecificOutput` 包裹格式），但 design-doc §R6 / tester D2 又认定 Codex 期待裸 `{"additionalContext"}`。线上实况（codex 能看到 context）反推 fallback 分支生效，即 design-doc:294 是错的。**正解**：单条 JSON 同时输出 `additionalContext` + `hookSpecificOutput` 两个键，各 runtime 忽略不认识的键，整个 if/elif/else 环境探测（连同脆弱的 env 假设）可删 | session-start:53-58 | 高 |
| 1.3 | `COPILOT_CLI` / `CURSOR_PLUGIN_ROOT` 判定无任何事实来源支撑（DEC-0010 明确 Copilot/Cursor out-of-scope，代码却有分支）；1.2 的双键方案可顺带消灭 | session-start:53,55 | 中 |
| 1.4 | worktree 下 `basename "$git_top"` 返回 worktree 目录名（如 `feat-slug-botB`）而非仓库名；本插件 closeout 官方支持 Codex App worktree，即支持场景下 project_id 必错。修法：`git rev-parse --git-common-dir` 回推主仓 | session-start:29-33 | 中 |
| 1.5 | lint 的 orphan 判定恒假：定义为「无链接 **且** 不在 INDEX」，但 rebuild 把所有 .md 都收进 INDEX，第二条件永不成立。应改为「除 INDEX.md 外无任何 doc 链接到它」 | skills/lint/SKILL.md:42 | 中 |
| 1.6 | bugfix tier 用 `git diff --numstat` LOC 判定，但定 tier 在派 developer **之前**，此时 diff 不存在。应改为预估定 tier + 返回后用真实 diff 复核升级 | skills/bugfix/SKILL.md:27-33 | 中 |
| 1.7 | hooks.json matcher `startup\|clear\|compact` vs codex manifest `*` 不一致；`"async": false` 非标准字段 | hooks/hooks.json:5 | 低 |

## 二、一致性问题

| # | 问题 | 位置 | 严重度 |
|---|------|------|--------|
| 2.1 | exec-plan「谁移到 completed/」三方互斥：developer.md:29 说 developer 移；workflow SKILL:136 说 orchestrator 在 go-commit 后移；插件 CLAUDE.md 说 user 移。developer 提前移会让 tester/reviewer 拿到失效路径。建议统一为 orchestrator closeout 后移 | 三处 | 高 |
| 2.2 | bugfix 流程不产 exec-plan，但 developer agent 输入强依赖 exec-plan path（勾 checkbox、移 completed/）；bugfix/references/codex-tools.md:9,16 还写着传 exec-plan path。修法：bugfix 加 mini exec-plan（与根 CLAUDE.md「小任务也写 exec-plan」更对齐），或 developer.md 加无-exec-plan 模式 | agents/developer.md:13,25,28 | 高 |
| 2.3 | NEED-DECISION 协议三种口径（workflow 有 TG 分支 + Change Log 落点；bugfix 只有 AskUserQuestion；CLAUDE.md 第三种）。应收敛成 canonical 一段，其余引用 | 三处 | 中 |
| 2.4 | 元数据全面过时：CLAUDE.md 说 2 skills（实际 5）；两份 plugin.json 写「2 skills, 3 commands」（codex 下根本无 commands）；README「~760 lines」实测 1131；README 表与同文件 Codex 节自相矛盾 | 多处 | 中 |
| 2.5 | CONTRIBUTING.md 引用已删除的 `docs/log.md`、`docs/decision-log.md`（v0.0.5 已删）和不存在的文件路径 | CONTRIBUTING.md:35-45 | 中 |
| 2.6 | dogfood 欠账：本仓库自己没有 docs/INDEX.md；codex-compatibility exec-plan 全勾完仍躺 active/；2026-05-21 reviewer 报告的 W3/W4/W5 至今未修 | docs/ | 低 |
| 2.7 | reviewer 输入要求 diff/git range，但 workflow 派发参数没列 | agents/reviewer.md:16 vs workflow SKILL:69 | 低 |

## 三、跨平台问题

| # | 问题 | 严重度 |
|---|------|--------|
| 3.1 | codex 工具映射表重复维护 7 处（5 份 references/codex-tools.md + developer/tester 的 Runtime Note）。建议 workflow 那份做 canonical 全表，其余砍成差异条目 + 一行指针 | 中 |
| 3.2 | Codex hook 协议的 P0.1/P0.2/P0.3 验证层层 deferred 从未闭环（v0.0.7-rc1 已发），现实已撞上 1.2 协议歧义 + docs_root bug。建议列为 0.0.7 正式版硬门槛 | 中 |
| 3.3 | AGENTS.md 一行指针「Codex 会去读 CLAUDE.md」是推断非事实；且 CLAUDE.md 本身内容过时（2.4） | 低 |
| 3.4 | `documentation/` 备选目录名只活在 hook 里，所有文档零提及 | 低 |

## 四、可优化项

1. **`.roundtable.json` 项目级配置**（中价值）：hook 优先读 `<git_top>/.roundtable.json`（`{"docs_root": "docs", "project_id": "pm"}`），其次 env，最后 walk-up。同时是越界 bug 的正解路径 + monorepo 多 docs_root 口子 + TG/bot 场景（env 难注入）的解。
2. **needs-init 引导**：三个入口行为不一致（workflow 问、bugfix 没提、lint 直接 abort）；无任何角色负责创建 7 目录骨架——建议 workflow Step 1 确认后 `mkdir -p` + 写空 INDEX.md；hook note 写死 AskUserQuestion 与自家 channel-aware 规则（TG 下不调）矛盾。
3. **lint 细节**：broken-link 未定义相对路径基准/是否跳外链；stale 检测对未 commit 文件 `git log` 返回空串行为未定义（建议 fallback `stat`）；`[⏩]` 非标 checkbox 在 fully-checked 判定下属灰区。
4. **hook 输出增强**：context 加 `git_top:` 行（skills 可自查 docs_root 是否越出仓库，对越界 bug 是廉价运行时护栏）+ `docs_root_source: env|config|walk-up`。
5. **健壮性**：`set -euo pipefail` 下 cwd 被删（worktree prune 后）时 `pwd` 失败 → hook 零输出无提示；escape_for_json 不覆盖 `\b`/`\f` 等控制字符会产出非法 JSON（有 python3 时一行 `json.dumps` 替换）。
6. **发布卫生**：0.0.7-rc1 挂 22 天，清完文档债出正式版。

## 五、从 mattpocock/skills 可借鉴项（按价值排序）

1. **静态配置落盘 + 动态注入叠加**（最有价值）：它的 setup skill 把配置写到 `docs/agents/` + CLAUDE.md 摘要块（静态、跨平台、可 diff），roundtable 的 hook 是动态注入（零配置、Claude Code 专属）。两者叠加：hook 失效/非 Claude 平台时回退读静态配置文件——直接解决跨平台 + 本次 bug。与上面第 1 条 `.roundtable.json` 是同一方案。
2. **description 触发词工程**：每个 description 写 "Use when user says X / mentions Y"（用户原话短语）。roundtable 的 description 是名词列举，自动激活准确率低。最便宜的改进。
3. **硬/软依赖分级**（其 ADR-0001）：缺 docs_root 就出错的角色（developer/lint）写显式 setup 指针；可降级的（analyst 直接回贴结果）静默降级。当前 roundtable 所有角色一刀切依赖 hook。
4. **Phase gate**：phase 切换处加可验证的产物存在性 gate（如 exec-plan 缺 `source:` frontmatter 不得进 developer），比 Phase Matrix 表情符号约束力强。
5. **PreToolUse 硬拦**：reviewer/dba 的「只读 src」目前纯 prompt 软约束；可照抄其 `block-dangerous-git.sh` 模式做 PreToolUse hook（拦 Edit/Write 到 src/），随 plugin 分发。
6. **WRONG/RIGHT 反模式对照**：给 developer/reviewer 各加最常见违规的对照段（反例对 LLM 约束力强于正面规则）。
7. **AI 产出署名**：文档 frontmatter 加 `generated-by: roundtable:<role>`，便于 lint 与溯源。
8. **`docs/out-of-scope/`**：被否决的方案独立成清单（当前散在 DEC- 编号里），防后续 agent 重复提案。
9. **SKILL.md ≤100 行 + references 单层不嵌套**：写进 CONTRIBUTING.md。
10. **manifest 一致性检查并入 lint**：plugin.json / marketplace.json / README / CHANGELOG 四方同步作为 `/roundtable:lint` 检查项（治 2.4 类问题的长效药）。

## 补充：父级工作区场景（user 2026-06-12 提出）

user 常在非 git 的父级目录（如 `/data/rsw`，下挂 8 个 git 子项目、7 个有自己的 `docs/`）启动 claude/codex。会话级单一 docs_root 在此场景是伪命题——docs_root 应跟任务目标子项目走。hook 改双模式：

- **project 模式**（cwd 在 git repo 内）：`.roundtable.json`（git_top 下）> env > 以 git_top 为界的 walk-up（带结构校验）。
- **workspace 模式**（cwd 不在 git repo 内）：扫一层子目录找 git 子项目，注入 `mode: workspace` + `workspace_root` + 项目清单（name + 有无 docs/）；note 指示 skills 按任务目标子项目延迟解析 `<proj>/docs`，推断不出才问。skills 侧 workflow/bugfix Step 1 配套：解析后把 `<proj>/docs` 带进所有角色派发参数；lint 在 workspace 模式让用户指定项目，不默认全量。
- 父级不放配置文件（扫 `*/.git` 足够；排除目录等需求出现再加）。
- 该设计同时覆盖原 bug：cwd 在无 docs/ 的 git 项目内时，bounded walk-up 正确报 needs-init 而非爬到 `~/docs`。

## 建议执行顺序

1. **PR-1（hook 修复，治本次 bug）**：1.1 越界 + 1.2 双键输出（顺带删 1.3 分支）+ 1.4 worktree project_id + 五.1 的 `.roundtable.json` 回退链 + **双模式 workspace 支持（见上节）**。
2. **PR-2（流程一致性）**：2.1 exec-plan 生命周期统一 + 2.2 bugfix mini exec-plan + 2.3 NEED-DECISION canonical 化。
3. **PR-3（文档债清算 + 0.0.7 正式版）**：2.4/2.5/2.6 + W3/W4/W5 遗留 + 3.4。
4. **0.0.8 方向**：3.1 codex-tools 去重、借鉴项 2/3/4/5。
