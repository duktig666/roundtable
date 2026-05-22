---
slug: codex-compatibility
created: 2026-05-21
source: design-docs/codex-compatibility.md
status: tester-report
---

# roundtable Codex 兼容 — 测试报告

## Scope

原报告验收 developer 完成的 20 个 step 改造（P1-P6），并把 P0 全段（P0.1/P0.2/P0.3）+ P1.3 标为 ⏩ deferred。2026-05-22 的 Codex CLI retest 补跑了部分 P0.2，但 Codex App 与完整交互链路仍 deferred。

**本会话能做**：

- JSON manifest 合法性 + 字段 / 长度 / 路径前缀验证
- skill / agent / command frontmatter 合法性
- hooks/session-start bash 脚本可跑 + stdout schema 检查
- 跨文件交叉引用一致性（commands 薄壳指向、references/ 链接、AGENTS.md 内容）
- 实施 vs DEC-0001..DEC-0010 逐条对照
- 实施 vs design-doc §Architecture 目标文件树对照
- 文档完整性

**本会话不能做**（→ deferred）：

- 重启 Claude Code session 实测 `/roundtable:workflow <task>` 触发语法
- Codex App 实测 Path A handoff

## 2026-05-22 Codex 0.133 Retest

本节覆盖原报告里 P0.2 的关键假设，基于分支 `fix/codex-runtime-compat` 在 Codex CLI v0.133.0 下重跑：

- `python3 /home/ubuntu/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py .` 通过；`.codex-plugin/plugin.json` 不再内联 `hooks`，Codex hook discovery 改用仓库根目录 `hooks.json`。
- 临时 `CODEX_HOME` 本地安装能完成，plugin cache 中能看到 root `hooks.json` 与 `hooks/session-start`。
- `hooks/session-start` 单独运行会输出合法 `{"additionalContext":"Roundtable context:..."}`；设置 `CLAUDE_PLUGIN_ROOT` 时仍输出 Claude Code 的 `hookSpecificOutput.additionalContext`。
- 严格 nonce smoke test 显示：在 `codex exec --ephemeral --dangerously-bypass-hook-trust` 路径里，SessionStart hook 的 `additionalContext` 没有可靠进入模型上下文。当前设计必须把 hook 当优化项，并保留询问 `docs_root` 的 fallback。
- Codex subagent 文档已更新为当前工具 schema：`spawn_agent(agent_type="worker", message=...)` 返回 agent id，后续用 `wait_agent(targets=[id])` 与 `close_agent(target=id)`；Codex 不会自动把 `agents/*.md` 注册成自定义 subagent，orchestrator 需要读取并嵌入 role prompt。

## Results

### A. JSON / manifest 合法

| 项 | 状态 | 说明 |
|----|------|------|
| A1 `.codex-plugin/plugin.json` JSON valid + 字段齐全 | ✅ | python3 json.load 通过；含 name/version/description/author/homepage/repository/license/keywords/skills/interface；interface 含 displayName/shortDescription/longDescription/developerName/category/capabilities/defaultPrompt/brandColor/screenshots；不含 Codex validator 不接受的 inline `hooks` |
| A2 `.claude-plugin/plugin.json` JSON valid + version 0.0.7 | ✅ | json.load OK；version = "0.0.7" |
| A3 `.claude-plugin/marketplace.json` JSON valid + version 0.0.7 | ✅ | json.load OK；plugins[0].version = "0.0.7" |
| A4 defaultPrompt 每条 ≤128 字符 | ✅ | 实测 len 分别为 40 / 30 / 24 字符 |
| A5 skills 路径以 `./` 开头 | ✅ | `skills` = `./skills/`；未声明 unsupported `composerIcon` / `logo` 字段 |

### B. skill / agent / command frontmatter

| 项 | 状态 | 说明 |
|----|------|------|
| B1 5 个 SKILL.md 各自含 `name` + `description` | ✅ | workflow / bugfix / lint / analyst / architect 全有 |
| B2 frontmatter `name` 与目录名一致 | ✅ | name=workflow↔skills/workflow/、bugfix↔skills/bugfix/、lint↔skills/lint/、analyst↔skills/analyst/、architect↔skills/architect/ |
| B3 4 个 agent frontmatter `tools:` 未动（DEC-0003）| ✅ | developer/tester: `Read, Grep, Glob, Bash, Write, Edit`；reviewer/dba: `Read, Grep, Glob, Bash` — 与 v0.0.6 一致 |
| B4 3 个 commands 薄壳含 `Skill(skill: "roundtable:<name>", args: ...)` | ✅ | workflow.md / bugfix.md / lint.md 各含正确 `Skill(...)` 引用，name 与对应 skill 一致 |

### C. 跨文件引用一致

| 项 | 状态 | 说明 |
|----|------|------|
| C1 commands/workflow.md → roundtable:workflow skill 存在 | ✅ | skills/workflow/SKILL.md exists |
| C2 commands/bugfix.md → roundtable:bugfix skill 存在 | ✅ | skills/bugfix/SKILL.md exists |
| C3 commands/lint.md → roundtable:lint skill 存在 | ✅ | skills/lint/SKILL.md exists |
| C4 5 份 references/codex-tools.md 存在 | ✅ | workflow(109L) / bugfix(43L) / lint(17L) / analyst(35L) / architect(65L) |
| C5 AGENTS.md 内容 = `CLAUDE.md` 单行 | ⚠️ | xxd 显示 10 字节：`CLAUDE.md\n`（含一个尾换行）。技术上 `CLAUDE.md` 后跟 LF 是 POSIX 文本文件惯例；功能等价。如要严格「单字面字符串无换行」可改 9 字节，但 superpowers AGENTS.md 同样含尾换行，行业惯例 pass |
| C6 CHANGELOG.md v0.0.7 entry 含 Added/Changed/Notes | ✅ | 三节齐全，覆盖 `.codex-plugin/` / AGENTS.md / references/ / SKILL.md Step 5 / README / CONTRIBUTING / commands 薄壳 / `.claude-plugin/` bump / reviewer/dba prose / developer+tester Codex Runtime Note / Notes 含 DEC-0003 + TG 可选 + P0 deferred |
| C7 README.md + README-zh.md 含 Codex 安装 + troubleshooting | ✅ | 两文件都含 `### Codex CLI` / `### Codex App` / `### Codex troubleshooting` 节；中英对齐 |
| C8 CONTRIBUTING.md 含 Codex 本地测试 + AGENTS.md 说明 | ✅ | 含 `## Codex 本地测试` checklist 节 + `## AGENTS.md` 说明节 + `.codex-plugin/plugin.json JSON 合法` checklist 项 |

### D. hooks/session-start 兼容性

| 项 | 状态 | 说明 |
|----|------|------|
| D1 bash 脚本可执行 | ✅ | `bash hooks/session-start </dev/null` 退出码 0，输出合法 JSON |
| D2 stdout 含 `additionalContext` 字段 | ✅ | fallback 分支输出 `{"additionalContext":"Roundtable context:\\ndocs_root: ...\\nproject_id: ...\\nstatus: ok"}`；脚本输出合法，但 Codex CLI `exec` 是否注入模型上下文需 runtime 实测 |
| D3 `hooks/hooks.json` schema 未破坏 | ✅ | Claude Code 用的 `hooks/hooks.json` JSON valid；`SessionStart` matcher 仍在；command 仍用 `${CLAUDE_PLUGIN_ROOT}` |
| D4 Codex root `hooks.json` schema | ✅ / ⚠️ | 仓库根 `hooks.json` JSON valid，`SessionStart` command 用 `${PLUGIN_ROOT}/hooks/session-start`；`.codex-plugin/plugin.json` 不再含 inline `hooks`，避免 Codex manifest validation 失败。Codex CLI v0.133 `exec` nonce test 未看到 `additionalContext` 进模型，因此 hook 注入仍按 runtime caveat 处理 |

### E. workflow skill Step 0 + Path A handoff

| 项 | 状态 | 说明 |
|----|------|------|
| E1 含 `GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)` 字面行 | ✅ | SKILL.md:81 |
| E2 含决策矩阵表格（3 组合）| ✅ | SKILL.md:92-97 含 4 行表格（Linked × Detached HEAD 完全枚举：No/No → Standard；Yes/Yes → Path A；Yes/No → Standard Codex App Full access；No/Yes → Standard with warning）。比验收清单要求的 3 组合更完整 |
| E3 Path A handoff payload 完整模板 | ✅ | SKILL.md:99-121 含 commit SHA / 建议 branch name / 建议 PR title / 建议 PR body / Codex App native button 提示（Create branch / Hand off to local）|
| E4 4-option closeout menu 保留在 Standard 分支 | ✅ | SKILL.md:123-136 标 `### Standard closeout (other paths)`，含 `go-commit` / `go-pr` / `go-all` / `modify` / `stop` 5 选项（实测 5 项含 modify/stop，比 4-option 更细，覆盖范围更广）|

### F. agent prose 加强

| 项 | 状态 | 说明 |
|----|------|------|
| F1 reviewer.md 含 apply_patch 禁止 + read-only prose | ✅ | reviewer.md:62 「In Codex runtime where the `tools:` frontmatter is not enforced, you MUST NOT call `apply_patch` or any shell command that mutates files (e.g., `sed -i`, `mv`, `rm`, `tee`, `>` redirect). Read-only operations only: `cat`, `rg`, `find`, `git log/diff/show/blame`.」 |
| F2 dba.md 含 apply_patch 禁止 + SQL writes 禁止 | ✅ | dba.md:55-57 禁 `apply_patch` + 显式列出 INSERT/UPDATE/DELETE/ALTER/DROP/TRUNCATE/MERGE/REPLACE + 限制 `psql/mysql/MCP DB tool` 渠道；SELECT/EXPLAIN/SHOW only |
| F3 developer + tester 含 `## Codex Runtime Note` 节 | ✅ | 两文件各有 Read→cat/rg、Grep→rg、Glob→find/rg --files、Bash→shell、Write/Edit→apply_patch 映射表 |

### G. references/codex-tools.md 内容质量

| 项 | 状态 | 说明 |
|----|------|------|
| G1 5 份 references 含工具映射表 | ✅ | 每份都有 `\| Claude Code \| Codex \| Notes \|` 三列表格 |
| G2 workflow + bugfix references 含 `multi_agent` troubleshooting 段 | ✅ | workflow:80-88 + bugfix:37-39 |
| G3 workflow + analyst + architect references 含 TG MCP 章节（Codex 可选 + 终端降级）| ✅ | workflow:62-75 详写；analyst:18 引用；architect:18 引用，都明确 `TG MCP optional under Codex` + 终端降级语义 |
| G4 references 无明显事实错误 | ✅ | 已按当前 Codex tool schema 更新：`spawn_agent(agent_type=..., message=...)`、`wait_agent(targets=[id])`、`close_agent(target=id)`、`request_user_input(questions=[...])`；并注明 Codex 需读取并嵌入 `agents/<role>.md` |

### H. DEC 逐条核验

| DEC | 状态 | 实施核对 |
|-----|------|---------|
| DEC-0001 同仓多 manifest | ✅ | `.claude-plugin/` + `.codex-plugin/` 共存于 roundtable 单仓根；无新仓 |
| DEC-0002 commands→skills + commands 薄壳 safe default | ✅ | skills/{workflow,bugfix,lint}/SKILL.md 创建；commands/{workflow,bugfix,lint}.md 保留为薄壳一行 Skill 引用（按 P0.1 deferral 的 safe default 路径）|
| DEC-0003 frontmatter `tools:` 保留 + prose 加强 | ✅ | 4 个 agent frontmatter 未动；reviewer/dba/developer/tester 都补了 prose |
| DEC-0004 AGENTS.md 单行 `CLAUDE.md` | ✅ | 10 字节 `CLAUDE.md\n`，符合 superpowers 实证路径 |
| DEC-0005 不开新仓 - README 指 github.com/duktig666/roundtable | ✅ | README + README-zh 都用 `codex plugin add github.com/duktig666/roundtable`；无 mirror repo |
| DEC-0006 不做 sync 脚本 | ✅ | `scripts/` 目录不存在；无 sync-to-codex-plugin.sh |
| DEC-0007 closeout Step 0 + Path A | ✅ | 同 E1-E4 |
| DEC-0008 TG channel-aware 不变 + Codex 终端降级 | ✅ | workflow/SKILL.md `## Step 2 ## Channel broadcast` 段保留 channel-aware；references/codex-tools.md 写 TG MCP optional |
| DEC-0009 multi_agent README 软提示 | ✅ | README + README-zh + workflow references 都列 troubleshooting；无强制 prereq |
| DEC-0010 仅 Codex | ✅ | `.cursor-plugin/` / `.opencode/` / `gemini-extension.json` / `GEMINI.md` 均不存在 |

### I. 用户实测留项（deferred-to-user）

| 项 | 状态 | 说明 |
|----|------|------|
| I1 Claude Code 重启后 `/roundtable:workflow <task>` 触发 | ⏩ | P0.1 真验证；本会话不能重启 Claude；safe default（commands 薄壳）已应用，最差只剩薄壳被解析为 Slash Command 后 Skill 调用是否生效 |
| I2 Codex CLI 装 plugin 后 `/skills` 列出 5 个 skill | ✅ / partial | 临时 `CODEX_HOME` 本地安装成功，plugin cache 中 skill 文件与 root `hooks.json` 可见；交互式 `/skills` UI 未在本报告中截图 |
| I3 Codex CLI 描述意图启动 workflow，spawn_agent 派 4 个 subagent | ⏩ | subagent 编排未跑全链路；文档已改为当前 `spawn_agent`/`wait_agent`/`close_agent` schema |
| I4 Codex 下 request_user_input 弹结构化选项 | ⏩ | 当前会话有 `request_user_input` 工具 schema，但未在 plugin workflow 中跑交互式 gate |
| I5 Codex 下 hooks/session-start 注入 context 被 skill 读到 | ⚠️ | standalone hook 输出合法；Codex CLI v0.133 `exec` nonce test 未看到 `additionalContext` 进入模型上下文，必须保留 `docs_root` fallback |
| I6 Codex App detached HEAD 下 closeout 走 Path A | ⏩ | 静态验证 E3 通过；运行时未验 |
| I7 Claude TG MCP 加载时 phase 广播 + decision prompt 走 TG reply | ⏩ | 静态 prose 未变；运行时未验 |
| I8 Codex 无 TG MCP 时 channel-aware 自动走终端 | ⏩ | 静态 references 明示；运行时未验 |
| I9 reviewer/dba 在 Codex 下不动文件（prose 约束生效）| ⏩ | 静态 F1+F2 prose 强约束；运行时不可观察 — 推荐 audit 第一次 Codex review 报告，确认无 apply_patch / mutating shell |

## Static Verification Commands

以下是本次跑过的所有命令（仅 stdout 摘录）：

### JSON 合法 + 版本

```bash
python3 -c "import json; print('codex:', json.load(open('.codex-plugin/plugin.json'))['version'])"
python3 -c "import json; print('claude:', json.load(open('.claude-plugin/plugin.json'))['version'])"
python3 -c "import json; print('marketplace:', json.load(open('.claude-plugin/marketplace.json'))['plugins'][0]['version'])"
python3 -c "import json; print('codex hooks.json valid:', bool(json.load(open('hooks.json'))))"
python3 -c "import json; print('claude hooks.json valid:', bool(json.load(open('hooks/hooks.json'))))"
```

输出：

```
codex: 0.0.7
claude: 0.0.7
marketplace: 0.0.7
codex hooks.json valid: True
claude hooks.json valid: True
```

### .codex-plugin/plugin.json 字段 / prompt 长度 / 路径

```python
import json
m = json.load(open('.codex-plugin/plugin.json'))
required = ['name','version','description','author','homepage','repository','license','keywords','skills','interface']
print("A1:", all(k in m for k in required))
for p in m['interface']['defaultPrompt']: print(f"  len={len(p)}")
print("A5:", repr(m['skills']))
```

输出：

```
A1: True
  len=40
  len=30
  len=24
A5: './skills/'
```

### session-start hook 跑

```bash
bash hooks/session-start </dev/null
CLAUDE_PLUGIN_ROOT=/tmp bash hooks/session-start </dev/null
```

输出：

```
{"additionalContext":"Roundtable context:\ndocs_root: /home/ubuntu/rsw/pm/roundtable/docs\nproject_id: roundtable\nstatus: ok"}
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Roundtable context:\ndocs_root: /home/ubuntu/rsw/pm/roundtable/docs\nproject_id: roundtable\nstatus: ok"}}
```

Fallback 分支输出 Codex 期望的 `{"additionalContext": "..."}`，含 `CLAUDE_PLUGIN_ROOT` 时输出 Claude `{"hookSpecificOutput": ...}`。脚本 schema 对齐；Codex CLI 是否把该字段注入模型上下文仍以 runtime 实测为准，本次 v0.133 `codex exec` nonce test 未通过。

### AGENTS.md 字节级检查

```bash
xxd AGENTS.md
```

输出：`00000000: 434c 4155 4445 2e6d 640a` —— 10 字节 `CLAUDE.md\n`（尾换行）。

### DEC-0006 + DEC-0010 负面验证

```bash
ls scripts/ .cursor-plugin/ .opencode/ gemini-extension.json GEMINI.md 2>&1
```

输出：全部 `No such file or directory` — pass。

## Findings

### Critical

无。

### Warning

1. **Codex SessionStart 注入未可靠证实** —— root `hooks.json` + `hooks/session-start` 的静态 schema 已通过，但 Codex CLI v0.133 `codex exec` nonce test 未看到 `additionalContext` 进模型上下文。当前实现已把 hook 降级为优化项：workflow / bugfix 在 context 缺失时询问 `docs_root`。

design-doc §Architecture 描述的 `commands/` 目录「删除」状态被 developer 修订为「保留薄壳 safe default」，但此修订已在 exec-plan P2.5 Change Log 显式记录（2026-05-21 entry），并在 CHANGELOG v0.0.7 Changed 节 + design-doc R1 mitigation 中先行覆盖；属合规偏差，不算 warning。

### Suggestion

1. **AGENTS.md 尾换行**（C5 ⚠️）—— 当前 10 字节含 LF。若想严格对齐 superpowers 实证形态（superpowers 同样含尾换行），保持不动；若想严格匹配 design-doc DEC-0004「内容仅一行字面字符串 `CLAUDE.md`」字面，可去掉尾换行。**建议保持不动** —— POSIX 文本文件惯例 + 大部分编辑器自动加尾换行，去掉反而是反惯例。

2. **Codex hook discovery 位置** —— 当前分支使用 root `hooks.json`，`.codex-plugin/plugin.json` 不再声明 inline `hooks`。这是为了通过当前 Codex manifest validator，并与官方 plugin 形态对齐。后续需要在 Codex App / 交互式 Codex CLI 里继续验 SessionStart 是否真的触发。

3. **commands 薄壳一行 `Skill(...)`** —— developer 在 P2.5 选了「保留薄壳」safe default；这是 DEC-0002 的「不破坏 Claude Code 用户路径」的稳妥做法。若 P0.1 实测发现 Claude `/<plugin>:<skill>` 直接触发 skill 而无需 commands 薄壳，可在 v0.0.8 删 commands/ 目录。当前形态最稳。

## Deferred to User

以下项目仍需要在真实 Claude Code / Codex CLI / Codex App 交互环境里补跑；I2 已做临时本地安装 smoke test，但还缺交互式 `/skills` 截图或日志：

### I1 — Claude Code `/roundtable:workflow <task>` 触发验证

```bash
# 在装了 Claude Code 的机器上
claude --plugin-dir /data/rsw/roundtable
# session 启动后输入：
/roundtable:workflow 测试任务
```

期望：workflow skill 启动；`Roundtable context:` block 注入；render Phase Matrix。

### I2 — Codex CLI 装 plugin

```bash
# 在装了 Codex CLI 的机器上
codex plugin add github.com/duktig666/roundtable
# 启动 session
codex
# 输入：
/skills
```

期望：列表含 `workflow / bugfix / lint / analyst / architect` 5 项。

### I3 — Codex CLI workflow + subagent

```bash
codex
# 描述意图：
"run the multi-role workflow on this task: 实现一个 hello world function"
```

期望：触发 workflow skill → analyst → architect (user gate) → exec-plan → developer subagent (spawn_agent) → tester → reviewer。Codex 下 subagent 派发应先读取 `agents/<role>.md`，再用 `spawn_agent(agent_type="worker", message="...")`，并用返回的 agent id 调 `wait_agent(targets=[id])` + `close_agent(target=id)`。

### I4 — Codex request_user_input

在 I3 流程的 design-doc / exec-plan 用户确认点观察。

期望：`request_user_input` 可用时弹结构化 options（不是 plain prompt），含 A / B / accept / modify 等 label + 每条 description；不可用时用普通聊天列出同等选项并等待用户回复。

### I5 — Codex SessionStart hook 注入

在 I3 启动 session 时，让 workflow skill 在 Step 1 输出读到的 `Roundtable context:` 内容。

期望：如果当前 Codex build 暴露 hook context，skill 报告 `docs_root` + `project_id` + `status` 与 standalone hook 输出一致（fallback 分支输出格式 `{"additionalContext": "Roundtable context:\\n..."}`）。如果 context 不可见，workflow 不应失败，而应询问一次 `docs_root`。

如果 skill 报「context not visible」：检查 `~/.codex/config.toml` 含 `[features] plugin_hooks = true`、plugin 根目录含 `hooks.json`，并确认 `hooks/session-start` 可执行。注意：本次 Codex CLI v0.133 `codex exec` nonce test 未看到 hook context 进模型，因此这一路径当前按 caveat 处理。

### I6 — Codex App Path A handoff

```bash
# 在 Codex App 装 plugin（UI 操作）
# App 会自动创建 worktree（detached HEAD）
# 在 App 内描述意图启动 workflow
# 跑完全流程后观察 closeout
```

期望：closeout 检测到 `BRANCH` 空 + `GIT_DIR != GIT_COMMON` → 输出 handoff payload（commit SHA + suggested branch / PR title / PR body）+ 提示「Create branch」/「Hand off to local」按钮，**不**渲染 4-option menu。

### I7 — Claude TG MCP 广播

```bash
# 在已配 TG MCP server 的 Claude Code session
claude --plugin-dir /data/rsw/roundtable
/roundtable:workflow <task>
```

期望：workflow 启动时 TG bot 收到 reply（Phase Matrix）；每个 phase 完成时 TG 收到新 reply（非 edit_message）；user gate 时 TG 收到 reply 含 `a) accept b) modify c) reject d) ask` 字样。

### I8 — Codex 无 TG MCP 终端降级

I3 流程默认无 TG MCP。

期望：channel-aware 检测无 `plugin:telegram:telegram` → 走 `request_user_input`（可用时）或普通聊天 fallback；不报错；不调任何 TG 工具。

### I9 — Reviewer / DBA 在 Codex 下不动文件

跑一遍 Codex workflow 跑到 reviewer / dba phase 后。

期望：reviewer 输出 review 报告至 `<docs_root>/reviews/<date>-<slug>.md`，但不 apply_patch 改任何 src 文件；dba 同理 + 不执行 SQL writes。

**audit 方法**：

```bash
# 在 reviewer / dba 完成后
cd <project>
git status         # 应只显示 docs/reviews/ 下新加的 md 文件，无 src/ 改动
git diff           # 应空
git log --oneline -5   # 不应有 reviewer / dba 名义的 commit
```

## Conclusion

**Overall status: static pass; runtime hook caveat remains**

当前分支的 Codex manifest、root `hooks.json`、Claude `hooks/hooks.json`、skill references、README / CHANGELOG 文档已按当前 Codex tool schema 修正，静态验证通过。最重要的设计调整是：Codex manifest 不再内联 `hooks`；Codex subagent 文档不再假设 `task_name` 或自动注册 `agents/*.md`；所有用户决策都描述为 runtime-specific prompt with fallback。

仍不能把 SessionStart 注入声明为“已完全跑通”：Codex CLI v0.133 的 `codex exec` nonce smoke test 未看到 `additionalContext` 进入模型上下文。因此 v0.0.7-rc2 的合理发布口径应是：hook 脚本和 discovery 文件合法，Claude 路径保持兼容，Codex 路径有 `docs_root` fallback；还需要在交互式 Codex CLI / Codex App 里继续确认 hooks、`/skills`、workflow subagent 编排和 App handoff。
