---
slug: codex-compatibility
created: 2026-05-20
---

# roundtable 实现 Codex 兼容性 — 调研

## Background & Goals

roundtable 当前是 Claude Code 专属 plugin（v0.0.6）：

- `.claude-plugin/{plugin.json,marketplace.json}` 清单
- `skills/{analyst,architect}/SKILL.md` 主会话 Skill
- `agents/{developer,tester,reviewer,dba}.md` subagent
- `commands/{workflow,bugfix,lint}.md` slash command
- `hooks/{hooks.json,session-start}` SessionStart hook（已部分跨 runtime — 见 Findings §D.4）
- 依赖 Claude Code 工具：`Skill` / `Agent` / `AskUserQuestion` / `TodoWrite` / `Read/Write/Edit/Bash/Grep/Glob` / `mcp__plugin_telegram_telegram__reply|edit_message`

**目标**：让 `/roundtable:workflow`、`/roundtable:bugfix`、`/roundtable:lint` 三条流程及四个 subagent 在以下 runtime 都能运行：

- Claude Code（保持兼容，不退化）
- Codex CLI（OpenAI codex `npm i -g @openai/codex` / `brew install --cask codex`）
- Codex App（macOS desktop，sandbox + App-managed worktree）

**非目标**：本次不覆盖 Cursor / Gemini CLI / Copilot CLI / OpenCode（superpowers 已支持，可后续 follow-up）。

## Findings

### A. obra/superpowers 的多 runtime 兼容实现（行业标杆）

#### A.1 同仓多 manifest 共存

```
superpowers/
├── .claude-plugin/{plugin.json, marketplace.json, hooks.json}
├── .codex-plugin/plugin.json
├── .cursor-plugin/plugin.json          # hooks 内联在 plugin.json
├── .opencode/{plugins/, INSTALL.md}
├── gemini-extension.json               # 顶层独立文件
├── CLAUDE.md
├── AGENTS.md                           # 内容仅一行 "CLAUDE.md"（文本指针）
├── GEMINI.md                           # 内容是 @./ 引用列表（文本指针）
├── skills/<name>/
│   ├── SKILL.md                        # 主体写 Claude 工具名
│   └── references/
│       ├── codex-tools.md              # Codex 工具映射 + 环境检测
│       ├── copilot-tools.md
│       └── gemini-tools.md
├── hooks/
│   ├── session-start                   # bash，多 runtime 输出自适应
│   └── (no hooks.json — Claude 版的在 .claude-plugin/)
└── scripts/sync-to-codex-plugin.sh
```

`.codex-plugin/plugin.json` vs `.claude-plugin/plugin.json` 差异（superpowers 实测）：

| 字段 | `.claude-plugin/plugin.json` | `.codex-plugin/plugin.json` |
|---|---|---|
| name/version/description/author/license | ✓ | ✓ |
| keywords | ✓（6 项） | ✓（7 项，多 `subagent-driven-development`） |
| `skills` 字段 | 隐式（plugin 聚合 `skills/` 下所有 SKILL.md） | `"./skills/"` 显式路径 |
| `interface` 块 | — | displayName/shortDescription/longDescription/developerName/category/capabilities/defaultPrompt/brandColor/composerIcon/logo/screenshots/websiteURL/privacyPolicyURL/termsOfServiceURL |

Codex 的 `interface` 块是 Codex App UI 必须的（市场展示用），CLI 不读。两份 manifest 都是独立文件，不互为 symlink。

#### A.2 项目记忆文件用「文本指针」串起来

GitHub API 查 mode 字段：

- `AGENTS.md` — type=file, symlink_target=null, size=7574 bytes 但**实际内容仅 1 行**：`CLAUDE.md`
- `GEMINI.md` — type=file, symlink_target=null，内容是两行 `@./` 引用：

```
@./skills/using-superpowers/SKILL.md
@./skills/using-superpowers/references/gemini-tools.md
```

即并非 git symlink（mode `120000`），而是 **plain file 包含相对路径文本**。各 runtime 各自负责把这种文本当指针处理（Gemini CLI 支持 `@./` import 语法；Codex 不支持 `@import`，所以 AGENTS.md 用单行内容 `CLAUDE.md` 似乎只是占位——`AGENTS.md` 7574 字节但内容一行说明可能是 git 历史包含过更多内容，需进一步验证；本机文件系统检查更准确）。

注：Codex 官方 doc 明确 `AGENTS.md` **不支持 `@import` / file include**（来源 `developers.openai.com/codex/guides/agents-md`）；Codex 仅做多目录拼接 + override 文件机制。

#### A.3 Per-skill `references/<platform>-tools.md` 工具名映射

`skills/using-superpowers/references/codex-tools.md` 完整映射表：

| Skill references | Codex equivalent |
|-----------------|------------------|
| `Task` tool (dispatch subagent) | `spawn_agent` |
| Multiple `Task` calls (parallel) | Multiple `spawn_agent` calls |
| Task returns result | `wait_agent` |
| Task completes automatically | `close_agent` to free slot |
| `TodoWrite` (task tracking) | `update_plan` |
| `Skill` tool (invoke a skill) | Skills load natively — just follow the instructions |
| `Read`, `Write`, `Edit` (files) | Use your native file tools |
| `Bash` (run commands) | Use your native shell tools |

附加内容：

- `multi_agent` feature 启用指令（`~/.codex/config.toml` `[features] multi_agent = true`）— 注：superpowers 文档建议显式开启，但 Codex 官方 `config-reference` 列默认值 `true`，可能不同 build 不同；需进一步验证
- 环境检测代码（`GIT_DIR` vs `GIT_COMMON` + `BRANCH`）— 见 §A.5
- Codex App finishing 模式（detached HEAD → 输出 handoff payload 而非 4-option menu）— 见 §A.7

`copilot-tools.md` 工具映射（节录）：

| Skill references | Copilot CLI equivalent |
|---|---|
| `Read` | `view` |
| `Write` | `create` |
| `Edit` | `edit` |
| `Bash` | `bash`（额外 `async: true` 持久 PTY） |
| `Task` | `task` with `agent_type: "general-purpose"` or `"explore"` |
| `TodoWrite` | `sql`（内置 todos 表） |
| — | `store_memory` 跨会话持久化 |
| — | `report_intent` 更新 UI status line |

`gemini-tools.md` 工具映射（节录）：

| Skill references | Gemini CLI equivalent |
|---|---|
| `Task` | `@agent-name`（e.g. `@generalist`） |
| 多个 `Task` 并行 | 同一 prompt 中多个 `@agent-name` |
| `Skill` | `activate_skill` |
| `WebSearch` | `google_web_search` |

#### A.4 SessionStart hook 多 runtime 自适应

`hooks/session-start` 是单一 bash 脚本，按环境变量分支输出不同 JSON schema。逻辑（来自 roundtable 同款实现，参 §D.4）：

- `CURSOR_PLUGIN_ROOT` 设 → 输出 `{"additional_context":...}`
- `CLAUDE_PLUGIN_ROOT` 设 + `COPILOT_CLI` 未设 → 输出 `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":...}}`
- 其它 → 输出 `{"additionalContext":...}`

环境变量 `PLUGIN_ROOT`（Codex 注入）/ `CLAUDE_PLUGIN_ROOT`（Codex legacy 兼容） / `CURSOR_PLUGIN_ROOT`（Cursor） / `COPILOT_CLI`（GitHub Copilot CLI）—— 每 runtime 各管各的环境名。

#### A.5 只读 git 环境检测（用于跨 runtime 降级）

`skills/using-git-worktrees/SKILL.md` Step 0 + `skills/finishing-a-development-branch/SKILL.md` Step 1.5 + Step 5 都用：

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

派生信号：

- `GIT_DIR != GIT_COMMON` → 已在 linked worktree（Codex App / Claude Agent / 用户手建）— 跳过创建
- `BRANCH` 为空 → detached HEAD（无法 push/PR/branch）

`pwd -P` 解析 symlink（macOS `/tmp` → `/private/tmp`）和相对路径（`git-common-dir` 在普通 repo 返回相对路径 `.git`，linked worktree 返回绝对路径）。

为什么用 `git-dir != git-common-dir` 而不是 `git rev-parse --show-toplevel`：submodule 下后者会假阳性（superpowers 在 spec 文档明确说明）。

#### A.6 `sync-to-codex-plugin.sh` 自动镜像策略

- **同步目标**：`prime-radiant-inc/openai-codex-plugins` 仓库 `plugins/superpowers/` 路径
- **EXCLUDES** 列表（rsync 排除清单）—— Claude 专属 / 项目根 ceremony 文件全部不进 Codex 镜像：

```
"/.claude/" "/.claude-plugin/" "/.codex/" "/.cursor-plugin/" "/.git/"
"/.gitattributes" "/.github/" "/.gitignore" "/.opencode/" "/.version-bump.json"
"/.worktrees/" ".DS_Store"
"/AGENTS.md" "/CHANGELOG.md" "/CLAUDE.md" "/GEMINI.md" "/RELEASE-NOTES.md"
"/gemini-extension.json" "/package.json"
"/commands/" "/docs/" "/hooks/" "/lib/" "/scripts/" "/tests/" "/tmp/"
```

- **Bootstrap 模式** `--bootstrap` flag：首次创建 `plugins/superpowers/` 目录（不要求 base branch 已有该目录）
- **保留 destination 自有 metadata**：`copy_preserved_destination_metadata()` 函数从目标仓 rsync 回 `*/agents/openai.yaml` 文件（OpenAI 平台维护的 UI 元数据，不被 upstream 覆盖）
- **Deterministic**：同 upstream SHA 跑两次 → PR diff 完全相同（自验机制）
- **分支命名**：`sync/superpowers-<short-sha>-<timestamp>` 或 `bootstrap/superpowers-<short-sha>-<timestamp>`
- **commit message** 含 upstream commit SHA + version 号
- **测试**：`tests/codex-plugin-sync/test-sync-to-codex-plugin.sh`（600+ 行 fixture-based 测试，覆盖 preview/bootstrap/dirty/no-op/missing-manifest/convergence/mixed-ignored）

#### A.7 Codex App finishing 模式（detached HEAD 降级）

`skills/finishing-a-development-branch/SKILL.md` Step 1.5 决策矩阵：

| Linked Worktree? | Detached HEAD? | Environment | Action |
|---|---|---|---|
| No | No | Claude Code / Codex CLI / normal git | Full skill behavior（4-option menu） |
| Yes | Yes | Codex App (workspace-write) | Path A：跳过 menu，输出 handoff payload + 数据丢失警告 |
| Yes | No | Codex App (Full access) 或 手建 worktree | Path B：跳过 worktree 创建，full finishing flow |
| No | Yes | 异常（manual detached HEAD） | Path C：照常创建 + warn |

Codex App 实测沙箱（2026-03-23）：

| 操作 | workspace-write sandbox | Full access |
|---|---|---|
| `git add` / `git commit` / `git status/diff/log` | ✓ | ✓ |
| `git checkout -b` | ✗（不能写 `.git/refs/heads/`） | ✓ |
| `git push` | ✗（网络 + `.git/refs/remotes/`） | ✓ |
| `gh pr create` | ✗（网络） | ✓ |

`network_access = true` 配置在 macOS 上**静默失败**（superpowers 实测，issue openai/codex#10390）。

Path A 在 Codex App 下的应对：agent commit 完所有改动 + 输出 handoff payload（commit SHA / 建议 branch name / 建议 PR title body），让用户走 App 原生「Create branch」/「Hand off to local」按钮完成。

#### A.8 时间线（CHANGELOG）

| 版本 | 日期 | 关键变更 |
|---|---|---|
| v5.0.2 | 2026-03-11 | 移除 vendored node_modules，brainstorm server 零依赖 |
| v5.0.3 | 2026-03-15 | Cursor support（`hooks/hooks-cursor.json`） |
| v5.0.6 | 2026-03-24 | Codex App 兼容（codex-tools 加 named agent dispatch + env detection + finishing；spec PRI-823） |
| v5.1.0 | 2026-04-30 | `sync-to-codex-plugin.sh` mirror 工具 |

约 **2 个月**从首次 Cursor 跨 runtime → Codex App 完整支持 → 自动 mirror 工具。

#### A.9 README 安装说明区分 8 个 harness

README quickstart 明确列出 8 个 harness 独立安装：

```markdown
### Claude Code
### Codex CLI
### Codex App
### Factory Droid
### Gemini CLI
### OpenCode
### Cursor
### GitHub Copilot CLI
```

每个 harness 有独立 plugin marketplace / registry / git URL。同一 upstream，分别安装。

#### A.10 `prime-radiant-inc/openai-codex-plugins` 镜像产物

```
plugins/superpowers/
├── .codex-plugin/plugin.json
├── CODE_OF_CONDUCT.md / LICENSE / README.md
├── agents/
├── assets/
└── skills/
```

无 `commands/` / `docs/` / `hooks/` / `scripts/` / `tests/`（被 sync EXCLUDES 排除）。

仓库性质：**`prime-radiant-inc` 非 OpenAI 官方账户**，但许多 plugin 的 `repository` 字段填 `https://github.com/openai/plugins`（404，OpenAI 内部仓的 mirror）。该仓 100+ plugins，公开 curated 集；OpenAI 内部还有非公开 `openai/plugins` 仓。

### B. mattpocock/skills 反例

仅 `.claude-plugin/plugin.json`，**未做任何 Codex 适配**：

- 无 `.codex-plugin/`
- 无 `AGENTS.md` / `GEMINI.md`
- 无 `skills/<x>/references/codex-tools.md`
- 无 sync 脚本
- 95.4k★ 但单 runtime

仅作反例确认：不能从 mattpocock 学跨 runtime。

### C. Codex 平台事实（来自 `openai/codex` 仓 + `developers.openai.com/codex`）

#### C.1 Plugin manifest schema（`codex-rs/core-plugins/src/manifest.rs`）

顶层字段（serde camelCase）：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `name` | string | 默认空（fallback 用目录名） | kebab-case |
| `version` | string\|null | 否 | trim |
| `description` | string\|null | 否 | |
| `keywords` | string[] | 否 | |
| `skills` | string\|null | 否 | 必须 `./xxx` 形式 |
| `mcpServers` | string\|null | 否 | 指向 `.mcp.json` |
| `apps` | string\|null | 否 | 指向 `.app.json` |
| `hooks` | string / string[] / inline obj / inline obj[] | 否 | 4 种形态 |
| `interface` | object | 否 | UI 元数据 |

`interface` 子字段：`displayName` / `shortDescription` / `longDescription` / `developerName` / `category` / `capabilities`（已见值 `Read`/`Write`/`Interactive`）/ `websiteURL` / `privacyPolicyURL` / `termsOfServiceURL` / `defaultPrompt`（≤3 条，每条 ≤128 字符）/ `brandColor`（hex）/ `composerIcon` / `logo` / `screenshots`。

路径硬约束：`skills`/`mcpServers`/`apps`/`hooks` 必须以 `./` 开头，不允许 `..`，否则 manifest warn 后忽略。

#### C.2 `.claude-plugin/` fallback（Codex 主动兼容 Claude Code 写法）

源码 `manifest.rs` 有常量：

```rust
const ALTERNATE_PLUGIN_MANIFEST_RELATIVE_PATH: &str = ".claude-plugin/plugin.json";
```

Codex 在没找到 `.codex-plugin/plugin.json` 时会 fallback 到 `.claude-plugin/plugin.json`。即：**仅有 `.claude-plugin/` 的 plugin 也能被 Codex 装上**，但加载行为按 Codex 自己 schema 解读。

实际意义：roundtable 当前的 `.claude-plugin/plugin.json` 在 Codex 下可能能装，但缺 `interface` 块、缺 `skills` 路径声明、`hooks` schema 不同 — 不会真正可用。需要 `.codex-plugin/plugin.json` 独立维护。

#### C.3 AGENTS.md 加载机制

搜索路径与优先级（`developers.openai.com/codex/guides/agents-md`）：

1. **Global**：`$CODEX_HOME/AGENTS.override.md` → `$CODEX_HOME/AGENTS.md`（`CODEX_HOME` 默认 `~/.codex`）
2. **Project**：从仓库 root 沿目录树到 cwd，每层 `AGENTS.override.md` → `AGENTS.md` → `project_doc_fallback_filenames`，每个目录最多 1 个文件
3. **Merge**：root → cwd 顺序拼接，blank line 分隔；靠后的（更接近 cwd）override 靠前的

关键 config：

| key | 默认 |
|---|---|
| `project_doc_max_bytes` | 32 KiB |
| `project_doc_fallback_filenames` | 数组 |
| `CODEX_HOME` (env) | `~/.codex` |
| `model_instructions_file` | unset |
| `[features].child_agents_md` | — |

行为：

- 空文件跳过
- 到达 byte 限制即停止追加
- 无缓存，每次 run 重建
- **没有 `@import` / 文件 include 语法**（与 Claude Code `@<path>` import 不同）

#### C.4 MCP server 配置

- 主配置：`~/.codex/config.toml` `[mcp_servers.<id>]` section
- 项目级：`<repo>/.codex/config.toml`（trusted projects only）
- Plugin bundled：`<plugin>/.mcp.json`（通过 manifest `mcpServers` 字段指向）
- 语法：**TOML**（不是 JSON）

stdio server schema：

```toml
[mcp_servers.my-server]
command = "mcp-binary"
args = ["--stdio"]
cwd = "/path"
env = { KEY = "value" }
env_vars = ["FORWARDED"]
experimental_environment = "local"     # "local" | "remote"
enabled = true
required = false
startup_timeout_sec = 10
tool_timeout_sec = 60
enabled_tools = ["repos/list"]
disabled_tools = []
default_tools_approval_mode = "auto"   # auto | prompt | approve
```

HTTP server schema 多一组 OAuth / header 字段（略）。

工具命名约定：**官方 doc 未明确列出 `mcp__<server>__<tool>` 格式**。`codex-rs/codex-mcp/src/mcp_connection_manager.rs` 是实现源（未深读）。需本地 `codex` 跑起来看 `/mcp` 实际暴露名验证。

管理命令：`codex mcp add <name> -- <command>` / `codex mcp login <name>` / TUI 内 `/mcp` 列已连接 server。

#### C.5 Hook 机制

配置文件位置（优先级高 → 低）：

1. `~/.codex/hooks.json`
2. `~/.codex/config.toml` inline `[hooks]`
3. `<repo>/.codex/hooks.json`（trusted layer）
4. `<repo>/.codex/config.toml`
5. Plugin bundled：`<plugin>/hooks/hooks.json` 或 manifest 指定路径（要求 `[features].plugin_hooks = true`）

事件名（TS schema `HookEventName.ts` 直读）：

```ts
"preToolUse" | "permissionRequest" | "postToolUse"
| "preCompact" | "postCompact"
| "sessionStart" | "userPromptSubmit"
| "subagentStart" | "stop"
```

doc 页面列：`SessionStart` / `PreToolUse` / `PermissionRequest` / `PostToolUse` / `UserPromptSubmit` / `Stop`（**未列**：`preCompact` / `postCompact` / `subagentStart`，但源码有）。

Handler 类型（TS schema `ConfiguredHookHandler.ts`）：

```ts
{ type: "command", command: string, commandWindows: string|null,
  timeoutSec: bigint|null, async: boolean, statusMessage: string|null }
| { type: "prompt" }
| { type: "agent" }
```

doc 注：「只 `type: 'command'` 实现，prompt/agent parse 但 skip」。

JSON schema 示例（Codex 接受）：

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "^Bash$",
      "hooks": [{
        "type": "command",
        "command": "/path/to/script",
        "timeout": 600,
        "async": false,
        "statusMessage": "Checking Bash"
      }]
    }]
  }
}
```

注入环境变量：

- `PLUGIN_ROOT` — 已安装 plugin 目录
- `PLUGIN_DATA` — plugin 可写数据目录
- `CLAUDE_PLUGIN_ROOT` / `CLAUDE_PLUGIN_DATA` — **legacy 兼容名**（Codex 主动复用 Claude 变量名，roundtable 现有 `${CLAUDE_PLUGIN_ROOT}` 引用在 Codex 下也能解出来）

stdin payload：`session_id` / `cwd` / `hook_event_name` / `model` / `permission_mode`（`default|acceptEdits|plan|dontAsk|bypassPermissions`）/ `transcript_path`；turn-scoped 加 `turn_id` / `tool_name` / `tool_input` / `tool_use_id`。

stdout 响应：

```json
{
  "continue": false,
  "stopReason": "...",
  "systemMessage": "...",
  "suppressOutput": false,
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "...",
    "updatedInput": { ... },
    "additionalContext": "..."
  }
}
```

exit codes：`0` + JSON → 用响应；`0` + 无输出 → 隐式成功；`2` + stderr → blocking；非零 → warn 但继续。

#### C.6 spawn_agent / wait_agent / close_agent + multi_agent feature

源：`codex-rs/core/src/tools/handlers/multi_agents_spec.rs` + `developers.openai.com/codex/subagents`。

feature flag（`~/.codex/config.toml`）：

```toml
[features]
multi_agent = true       # 默认 true（config-reference 列）
child_agents_md = ...    # 子 agent 是否收 AGENTS.md 额外指导
plugin_hooks = false     # 控制 plugin bundled hooks 是否启用
```

注：`config-reference` 列 `multi_agent` 默认 `true`，superpowers `codex-tools.md` 建议显式开启 — **可能不同版本 default 不同，需进一步验证**。

工具（v1 namespace `multi_agent_v1`）：

- **`spawn_agent`**：`task_name`（v2 required）+ `message`（required）+ optional `model` / `service_tier` / `agent_type`。返回 agent id + nickname。子 agent 继承当前 model。
- **`wait_agent`**：等任一 agent 完成，可设 timeout。
- **`close_agent`**：释放 slot。
- **`resume_agent`**：参数 `id`，恢复已关闭 agent。
- **`send_input`**（v1）/ **`send_message`** / **`followup_task`**（v2）：向已有 agent 发消息，`interrupt: true` 立刻打断，false（默认）排队。
- **`spawn_agents_on_csv`** + **`report_agent_job_result`**：批量 CSV 任务。

全局配额：

| key | 默认 |
|---|---|
| `agents.max_threads` | 6 |
| `agents.max_depth` | 1 |
| `agents.job_max_runtime_seconds` | 1800 |

命名 agent role（`config.toml`）：

```toml
[agents.<name>]
description = "..."
nickname_candidates = ["..."]
config_file = "./relative.toml"
# 自定义 agent 文件: name/description/developer_instructions (必填);
# optional: model/model_reasoning_effort/sandbox_mode/mcp_servers/skills.config
```

内置 3 个 agent：`default` / `worker` / `explorer`。

隔离 / 共享行为（重要）：

- **Sandbox**：「子 agent 继承父 sandbox policy」— 继承，不独立
- **Filesystem**：**共享父进程文件系统**（无独立 worktree）— 与 Claude Code Agent 工具行为一致
- **Context**：独立 LLM context（spawn 时 message 是 prompt；wait 才拿结果）
- **结果回传**：orchestration 聚合，wait_agent 返回 final message
- **限制**：max_threads=6 / max_depth=1 / job timeout 1800s

#### C.7 内置工具差异（粒度差异大）

Codex 内置工具（`codex-rs/core/src/tools/handlers/`）：

| Codex 工具 | Claude Code 对应 |
|---|---|
| `apply_patch` | `Edit` / `Write`（**patch 形式**，不是直接写文件） |
| `shell` (`shell_command`) | `Bash` |
| `unified_exec` (`exec_command` / `write_stdin`) | `Bash` 长 PTY 形式 |
| `update_plan` | `TodoWrite`（schema 极简：只 step + status，最多 1 个 in_progress） |
| `request_user_input` | `AskUserQuestion`（schema 几乎对应） |
| `request_permissions` | （隐式 approval） |
| `request_plugin_install` | 无 |
| `mcp` / `mcp_resource` 系 | `mcp__*` |
| `tool_search` | `ToolSearch` |
| `view_image` | 多模态读图 |
| `create_goal` / `get_goal` / `update_goal` | 无 |
| `spawn_agent` / `wait_agent` / `close_agent` / `resume_agent` / `send_input` / `send_message` / `followup_task` | `Task` |
| `spawn_agents_on_csv` / `report_agent_job_result` | 无 |

**关键差异**：Codex **没有独立的 `Read` / `Write` / `Edit` / `Glob` / `Grep` 工具**。读文件 / glob / grep 都用 `shell`，写文件用 `apply_patch`（unified diff 格式）。

对 roundtable 的影响：subagent frontmatter 的 `tools: Read, Grep, Glob, Bash, Write, Edit` 在 Codex 下不能字面照搬；要么映射到 `shell`+`apply_patch`，要么不写 tools 字段让 runtime 默认。

#### C.8 `request_user_input`（AskUserQuestion 等价）

`codex-rs/core/src/tools/handlers/request_user_input_spec.rs`：

```json
{
  "questions": [{
    "id": "snake_case_id",
    "header": "≤12 chars",
    "question": "single sentence",
    "options": [{
      "label": "1-5 words",
      "description": "1 sentence impact/tradeoff"
    }]
  }]
}
```

约束：

- 推荐 1 个，不超 3 个 question
- 每 question 2-3 个 option，互斥
- 推荐项放第一并 label 后缀 `"(Recommended)"`
- 不要自加 "Other"，client 会自动加 free-form

与 Claude Code `AskUserQuestion` 几乎 1:1 对应（结构化选项 UI）。**这意味着 roundtable 的 AskUserQuestion 调用在 Codex 下可以无损映射到 `request_user_input`，不需要降级为纯 prompt 自由问答**。

#### C.9 `update_plan`（TodoWrite 等价）

```json
{
  "explanation": "optional string",
  "plan": [{
    "step": "string",
    "status": "pending" | "in_progress" | "completed"
  }]
}
```

至多 1 个 step 同时 `in_progress`。无 `activeForm` / 长描述字段。

#### C.10 Custom prompts deprecated（推荐改用 skills）

`~/.codex/prompts/*.md`（仅顶层 markdown）调用 `/prompts:<name>`：

```yaml
---
description: <brief>
argument-hint: [KEY=<value>]
---
```

占位符：`$1`–`$9` / `$UPPERCASE`（用 `KEY=value` 传）/ `$ARGUMENTS` / `$$` 字面 `$`。

doc 明确：「Custom prompts are deprecated. Use skills for reusable instructions that Codex can invoke explicitly or implicitly.」

对 roundtable 的影响：`commands/{workflow,bugfix,lint}.md` 不能直接对应到 Codex prompts（deprecated）。要么改用 skills 形式触发（让 Codex 自动调），要么用 skill 自带触发机制（skill description 写明使用场景，模型自决调用）。

#### C.11 Codex App vs Codex CLI

- **Codex CLI**：终端工具，`npm i -g @openai/codex` / `brew install --cask codex`
- **Codex App**：macOS desktop GUI，内置 git worktree 托管 + plugin directory
- **Codex Web**：云端 agent（chatgpt.com/codex）
- **Codex IDE Extension**：VS Code / Cursor / Windsurf

Sandbox（`sandbox_mode` 三档）：`read-only` / `workspace-write` / `danger-full-access`，`[sandbox_workspace_write]` 控制 `writable_roots` / `network_access` / `exclude_slash_tmp` / `exclude_tmpdir_env_var`。

Codex App worktree 路径 `$CODEX_HOME/worktrees/`（superpowers 实测，Codex 官方 doc 未明确，需进一步验证）。

#### C.12 现有 Codex plugin 案例（`prime-radiant-inc/openai-codex-plugins`）

100+ plugin，抽样结构：

- **superpowers**：`.codex-plugin/plugin.json`（指 `"skills": "./skills/"`）+ `agents/` + `skills/` + `assets/`
- **slack**（OpenAI 官方作者）：`.codex-plugin/plugin.json` + `.app.json` connector + `skills/` + `assets/`（**连接器型 plugin**，无 mcpServers）
- 共性：所有 plugin 必须有 `.codex-plugin/plugin.json`，大多数有 `skills/`，连 SaaS 的用 `.app.json`，极少数用 `.mcp.json`，几乎没看到 `commands/` 或 `hooks.json`

用户安装：App 内 Plugins 目录浏览 / TUI `/plugins` 命令 / 安装到 `~/.codex/plugins/cache/$MARKETPLACE_NAME/$PLUGIN_NAME/$VERSION/`。

### D. roundtable 现状盘点（file:line）

#### D.1 配置文件清单

```
/data/rsw/roundtable/
├── .claude-plugin/{plugin.json, marketplace.json}
├── hooks/{hooks.json, session-start (bash)}
├── commands/{workflow.md, bugfix.md, lint.md}
├── agents/{developer.md, tester.md, reviewer.md, dba.md}
├── skills/{analyst/SKILL.md, architect/SKILL.md}
├── docs/{roundtable.md, usage.md, case-study-rewrite.md, pre.md}
├── CLAUDE.md / CHANGELOG.md / CONTRIBUTING.md / LICENSE
└── README.md / README-zh.md
```

总代码量约 1613 行。无 src/ / tests/ / scripts/，纯 markdown + 1 个 bash 脚本 + 3 个 JSON。

#### D.2 Claude 专属工具引用（按 file:line）

**AskUserQuestion**：

| 文件 | 行 | 上下文 |
|---|---|---|
| `skills/analyst/SKILL.md:49` | 范围模糊时一次询问（TG 模式下用 reply） |
| `skills/architect/SKILL.md:3` | frontmatter desc 写「Calls AskUserQuestion at every architectural decision point」 |
| `skills/architect/SKILL.md:72` | 每个架构决策点当场调（TG 模式下 reply） |
| `skills/architect/SKILL.md:81` | 终端模式：AskUserQuestion pack rationale into description |
| `commands/workflow.md:14` | status=needs-init 时确认 docs/ 位置 |
| `commands/workflow.md:70` | 解析 `[NEED-DECISION]` 后调（TG reply 或终端） |
| `commands/bugfix.md:41` | developer 返回 `[NEED-DECISION]` 后调 |
| `CLAUDE.md:27-28` | channel-aware 决策协议 |

**Skill 工具**：

| 文件 | 行 |
|---|---|
| `commands/workflow.md:54-55` | `Skill(skill: "roundtable:analyst" \| "roundtable:architect", args: "...")` |
| `skills/architect/SKILL.md:71` | architect 内派最多 3 个 general-purpose `Agent` |

**Agent 工具**：

| 文件 | 行 |
|---|---|
| `commands/workflow.md:67` | Phase 6-9 subagent dispatch |
| `commands/bugfix.md:36` | `Agent(subagent_type: "roundtable:developer", ...)` |

**subagent frontmatter `tools:` 字段**：

| Agent | 行 | tools 值 |
|---|---|---|
| `agents/developer.md:4` | `Read, Grep, Glob, Bash, Write, Edit` |
| `agents/tester.md:4` | `Read, Grep, Glob, Bash, Write, Edit` |
| `agents/reviewer.md:4` | `Read, Grep, Glob, Bash`（read-only） |
| `agents/dba.md:4` | `Read, Grep, Glob, Bash`（read-only + SQL 禁写） |

**MCP 工具**：

| 文件 | 行 | 内容 |
|---|---|---|
| `commands/workflow.md:20` | `mcp__plugin_telegram_telegram__reply` phase 广播 |
| `commands/workflow.md:27` | `edit_message`（in-phase）vs new `reply`（phase 完成） |
| `CLAUDE.md:28` | TG a/b/c 协议 |
| `CHANGELOG.md:20-21` | 0.0.6 channel-aware + phase-transition broadcast |

#### D.3 环境变量引用

| 变量名 | 出现位置 | 用途 |
|---|---|---|
| `CLAUDE_PLUGIN_ROOT` | `hooks/hooks.json:9` | hook command `bash "${CLAUDE_PLUGIN_ROOT}/hooks/session-start"` — **Codex legacy 兼容名，Codex 也能解** |
| `ROUNDTABLE_DOCS_ROOT` | `hooks/session-start:14` + `docs/usage.md:139` | 用户可强制设定 docs_root |

#### D.4 SessionStart hook 已部分支持多 runtime（**重要发现**）

`hooks/session-start` 脚本输出协议（lines 42-59）：

```bash
if [ -n "$CURSOR_PLUGIN_ROOT" ]; then
    # Cursor IDE schema: {"additional_context": "..."}
elif [ -n "$CLAUDE_PLUGIN_ROOT" ] && [ -z "$COPILOT_CLI" ]; then
    # Claude Code: {"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"..."}}
else
    # Fallback: {"additionalContext":"..."}
fi
```

注入字段（lines 35-40）：

| 字段名 | 来源 | 值示例 |
|---|---|---|
| `docs_root` | env var → 向上查找 docs/ | `/data/rsw/roundtable/docs` |
| `project_id` | git toplevel basename / cwd basename | `roundtable` |
| `status` | docs_root 是否找到 | `ok` / `needs-init` |
| `note` | conditional（needs-init 时） | `docs_root not found; commands should AskUserQuestion to set one.` |

**roundtable 的 hook 脚本已经检测 CURSOR_PLUGIN_ROOT / CLAUDE_PLUGIN_ROOT / COPILOT_CLI 三种 runtime**。但 **`hooks/hooks.json` 是 Claude Code 专属格式**（`SessionStart` matcher + `${CLAUDE_PLUGIN_ROOT}` 引用），Codex 不会读这个文件。

Codex 下要让 hook 生效需要：

1. 写 `.codex-plugin/plugin.json` 的 `hooks` 字段（4 种形态之一）指向 hook 文件
2. 用户开 `~/.codex/config.toml` `[features].plugin_hooks = true`
3. hook 脚本本身不用改（Codex 注入 `PLUGIN_ROOT` 同时也注入 `CLAUDE_PLUGIN_ROOT` legacy 名，脚本现有分支能命中）

但需补一个 Codex fallback 分支输出 Codex 期待的 stdout schema（`hookSpecificOutput.additionalContext` 似乎与 Codex 一致 — Codex stdout schema §C.5 已列出含 `hookSpecificOutput.additionalContext`，恰好与 Claude 写法相同，**可能可直接复用 Claude 分支**，需 e2e 验证）。

#### D.5 可跨 runtime 复用的纯方法论

可原样保留：

- **Phase Matrix** 9 阶段框架（`commands/workflow.md` §2）
- **两段式 architect**（design-doc → exec-plan）（`skills/architect/SKILL.md`）
- **Six-question 分析框架**（`skills/analyst/SKILL.md` §9 & §7）
- **`[NEED-DECISION]` 决策中继**（纯文本协议）
- **Reviewer severity 分类**（critical / warning / suggestion）
- **DBA 检查清单**

需抽离工具名：

- channel-aware 决策发送（`AskUserQuestion` / TG reply / `request_user_input`）
- subagent frontmatter `tools:` 字段（Claude 工具名 → Codex 工具粒度不同）
- `Skill(skill: ...)` / `Agent(subagent_type: ...)` 调用语法
- SessionStart hook 配置文件位置

#### D.6 当前 Marketplace 元数据

`.claude-plugin/marketplace.json`（v0.0.6）：

```json
{
  "name": "roundtable",
  "owner": "duktig666",
  "plugins": ["roundtable"]
}
```

CHANGELOG（v0.0.6 / v0.0.5 / v0.0.1）— v0.0.5 是大重写（dropped 64% prompt，language-neutral，两段式 architect），v0.0.6 加 TG channel-aware，未来需补 v0.0.7 Codex compat。

### E. 改造点详细清单（按文件级别）

#### E.1 新增文件

| 路径 | 内容 | 必要性 |
|---|---|---|
| `.codex-plugin/plugin.json` | Codex manifest（name/version/description/skills="./skills/"/hooks=指向 hooks/hooks-codex.json/interface 块带 displayName/longDescription/category="Coding"/capabilities=["Interactive","Read","Write"]/defaultPrompt=["Run the multi-role workflow on this task"]/brandColor/logo/composerIcon） | 必须 |
| `hooks/hooks-codex.json` | Codex hook schema（events=sessionStart，handler=command 指向 hooks/session-start） | 必须 |
| `AGENTS.md` | 文本指针 `CLAUDE.md`（或全量 copy CLAUDE.md，无 `@import` 时只能 copy） | 必须 |
| `skills/analyst/references/codex-tools.md` | analyst 工具映射 + AskUserQuestion → request_user_input + TG MCP 在 Codex 下的等价物 | 必须 |
| `skills/architect/references/codex-tools.md` | architect 工具映射 + Skill/Agent → spawn_agent/wait_agent | 必须 |
| `scripts/sync-to-codex-plugin.sh` | 同步到 Codex plugin marketplace（可选，可后续） | 可选 |
| `assets/` 目录（icon / logo） | Codex App UI 用 | 必须（Codex App 装时需要） |

#### E.2 改造现有文件

| 文件 | 现状 | 改造 | 风险 |
|---|---|---|---|
| `hooks/session-start` | 已检测 3 种 runtime | 加 Codex 分支（检测 `PLUGIN_ROOT` 但无 `CLAUDE_PLUGIN_ROOT` 时输出 Codex schema）；或确认现有 `hookSpecificOutput.additionalContext` 输出格式 Codex 能吃，则无需改 | 中（需 e2e 验证 Codex 是否真接受现 schema） |
| `hooks/hooks.json` | Claude Code schema，`${CLAUDE_PLUGIN_ROOT}` | 保留不动（Claude 专用）；Codex 用 `hooks/hooks-codex.json` | 低 |
| `commands/workflow.md` | Claude slash command 格式 | Codex 下 commands deprecated → 改用 skill 自动调（让 workflow 成为 skill，命名 `workflow.md` 移到 `skills/workflow/SKILL.md`） | **高** — 需重大重构 |
| `commands/bugfix.md` | 同上 | 同上 → `skills/bugfix/SKILL.md` | 高 |
| `commands/lint.md` | 同上 | 同上 → `skills/lint/SKILL.md` | 高 |
| `agents/developer.md` frontmatter `tools:` | `Read, Grep, Glob, Bash, Write, Edit` | 删除 tools 字段（让 runtime 决定），或加 platform-conditional 注释；正文工具名不变（references 表负责映射） | 中 |
| `agents/tester.md` `tools:` | 同 developer | 同上 | 中 |
| `agents/reviewer.md` `tools:` | `Read, Grep, Glob, Bash` | 同上 | 中 |
| `agents/dba.md` `tools:` | 同 reviewer | 同上 | 中 |
| `commands/workflow.md:54-55` `Skill()` 调用 | Claude Skill 工具 | 改为「invoke skill XXX」抽象表述，让 runtime 自决；或 references 表说明 Codex 下 skill 自然加载 | 中 |
| `commands/workflow.md:67` `Agent()` 调用 | Claude Agent 工具 | 改为 references 表映射到 `spawn_agent` + `wait_agent` + `close_agent`；正文用 `dispatch <role> subagent` 抽象表述 | 中 |
| `commands/workflow.md` AskUserQuestion 调用 | Claude 专属 | references 映射到 `request_user_input`（schema 一致）；TG MCP 调用映射到 Codex MCP 配置（`codex mcp add telegram`） | 低（schema 几乎一致） |
| `CLAUDE.md` | Claude 项目记忆 | 保留；新增 `AGENTS.md` 引用同一内容（或 copy） | 低 |
| `README.md` / `README-zh.md` | 仅 Claude Code 安装说明 | 加 Codex CLI / Codex App 章节（参 superpowers README 8-harness 模式） | 低 |
| `CONTRIBUTING.md` | Claude 测试清单 | 加 Codex 本地测试清单 | 低 |
| `CHANGELOG.md` | 不动 | v0.0.7 entry 描述 Codex compat | 低 |

#### E.3 Marketplace 双分发

| 操作 | 说明 |
|---|---|
| 保持 `duktig666/roundtable` Claude Code marketplace（现有） | Claude Code 用户走原路径 |
| 提交 PR 到 `prime-radiant-inc/openai-codex-plugins` | Codex App 用户能从 App 内 Plugins 目录装 |
| 或自维护 mirror 仓 `duktig666/openai-codex-plugins-roundtable` | 不走 prime-radiant，Codex CLI 用户自己 clone |

#### E.4 测试矩阵新增

| Runtime | 测试场景 |
|---|---|
| Claude Code | `/roundtable:workflow` / `/roundtable:bugfix` / `/roundtable:lint` 跑通；4 个 subagent + 2 个 skill 全派通；TG MCP 广播正常 |
| Codex CLI | `codex` 启动 + `/skills` 列出 analyst/architect；spawn_agent 派 developer subagent；request_user_input 弹选项；apply_patch 写文件 |
| Codex App | 在 App-managed worktree（detached HEAD）下走 workflow；finishing 阶段输出 handoff payload；UI 显示 plugin interface |

### F. 风险评估

#### F.1 工具粒度差异（Codex 无独立 Read/Write/Edit/Grep/Glob）

风险：subagent frontmatter `tools: Read, Grep, Glob, Bash, Write, Edit` 在 Codex 下不能字面解释。

影响：

- 删除 tools 字段 → 失去 reviewer/dba 的「read-only」硬约束（reviewer 在 Codex 下可能误用 `apply_patch` 写文件）
- 保留 tools 字段 → Codex manifest 解析时 warn 忽略（或不识别 → undefined behavior）

缓解：依靠 SKILL.md / agent.md **正文 prose** 写明约束（"reviewer MUST NOT modify any file"），不依赖 frontmatter 强制。Claude Code 仍按 frontmatter tools 字段隔离工具集。

#### F.2 commands/* deprecated（Codex 推荐 skill 形式）

风险：Codex 下 `~/.codex/prompts/*.md` 已 deprecated。`commands/workflow.md` 在 Codex 下无法作为 slash command 触发。

影响：

- 用户在 Codex 下不能输入 `/roundtable:workflow <task>` 启动流程
- 必须改用 skill 自动 invoke（model 自决调用，by description）

缓解：把 `commands/*.md` 内容迁移到 `skills/workflow/SKILL.md`（skill description 写明"启动多角色 workflow"），让 Codex 模型识别 user intent 自动调。代价：Claude Code 下用户仍能用 `/roundtable:workflow` 显式调；Codex 下变成"用户描述意图 → 模型自动调 skill"，**显式触发能力降级**。

#### F.3 Codex App sandbox 限制（git push/branch 不可用）

风险：roundtable workflow 末尾 closeout 阶段会建议 `gh pr create` / `git push`，Codex App workspace-write sandbox 下被阻断。

影响：closeout 阶段失败，用户体验差。

缓解：参 superpowers `finishing-a-development-branch` Step 1.5 模式 — 检测 `GIT_DIR != GIT_COMMON` + `BRANCH` 空 → 输出 handoff payload（commit SHA / 建议 branch name / PR title body），让用户走 App 原生 「Create branch」/「Hand off to local」按钮。需要：

- 给 workflow / bugfix 加 Step 0 环境检测（参 superpowers `using-git-worktrees` Step 0）
- 给 closeout 加 Path A 降级（参 superpowers `finishing-a-development-branch` Step 1.5）

#### F.4 AskUserQuestion 在 Codex 下保真度

风险：roundtable 重度依赖 AskUserQuestion 做架构决策 confirmation。Codex `request_user_input` schema 几乎一致（§C.8），但有微小差异：

- Codex options 限 2-3 个，Claude 限 2-4 个（roundtable 现有调用都在 2-3 个范围内，无差异）
- Codex header ≤12 字符（roundtable 现有 header 长度需 audit）
- Codex 不允许手加 "Other"（client 自动加，roundtable 现也不手加，OK）

影响：低，schema 几乎透明映射。

缓解：检查 `commands/workflow.md` + `skills/architect/SKILL.md` 所有 AskUserQuestion 调用的 header 长度是否 ≤12 字符。

#### F.5 hook 跨 runtime schema 一致性

风险：Codex hook stdout schema 含 `hookSpecificOutput.additionalContext`，与 Claude Code 一致（§C.5 + §D.4），**理论上 hooks/session-start 现有 Claude 分支输出可被 Codex 直接吃**。但未实测验证。

缓解：本地起 `codex` + 装 roundtable 跑 SessionStart，看 Codex 是否能从 stdout 解出 additionalContext 注入到模型。需要 phase 6 / phase 7 集成测试。

#### F.6 MCP 工具命名（TG 集成）

风险：Codex MCP 工具命名约定**未官方文档化**（§C.4）。roundtable 的 `mcp__plugin_telegram_telegram__reply` / `edit_message` 是 Claude Code 命名。Codex 下同 MCP server 暴露的工具名可能是 `plugin_telegram_telegram__reply` 或 `telegram_reply` 或别的。

影响：commands/workflow.md TG 广播代码在 Codex 下需要换工具名。

缓解：

- 在 `references/codex-tools.md` 留占位说明「Codex MCP tool naming TBD; verify with `codex /mcp` after install」
- 实测后补准确名称
- 或在 workflow.md 写抽象「post to telegram channel via MCP」让 runtime 自决调

#### F.7 multi_agent feature 默认值版本飘移

风险：`multi_agent` 在 config-reference 默认 `true`，superpowers 文档建议显式开启。不同 Codex build 默认可能不同。

影响：用户装 roundtable 后 spawn_agent 失败（feature 未启用）。

缓解：在 `references/codex-tools.md` 写明「If subagent dispatch fails, set `[features].multi_agent = true` in `~/.codex/config.toml`」；安装文档加 prerequisite 节。

#### F.8 sync 脚本维护成本

风险：sync-to-codex-plugin.sh 每次 upstream 改动都要跑 sync；EXCLUDES 列表偏移会漏文件或多传 Claude 专属文件。

缓解：

- 仿 superpowers 写测试脚本 `tests/codex-plugin-sync/test-sync-to-codex-plugin.sh`
- deterministic 保证（同 SHA 跑两次 diff 一致）
- 或暂不做自动 sync，手动 PR 提交到 prime-radiant 仓
- 或不进 prime-radiant，自维护 mirror 仓

## Comparison（候选方案对比，事实层）

### 方案 A：同仓多 manifest（superpowers 模式）

- 结构：roundtable/ 下加 `.codex-plugin/` + `AGENTS.md` + `hooks/hooks-codex.json` + 每 skill 加 `references/codex-tools.md`
- 迁移：commands/* → skills/*（Codex deprecated commands）；subagent tools frontmatter 删除或改注释；hook 脚本可能无需改
- 跨 runtime 入口：Claude Code 走 `/plugin install`；Codex 走 `codex plugin install` 或 prime-radiant 仓
- 维护：upstream 单仓，多 runtime 装；改一处影响所有；测试矩阵跨 runtime
- 复用：纯方法论部分（Phase Matrix / 两段式 / [NEED-DECISION]）原样保留
- 风险：commands/* deprecated 必须重构；subagent tools 约束弱化（依赖 prose）
- 成本：中等。superpowers 用了约 2 个月从 Cursor 到 Codex App 完整支持

### 方案 B：拆 core/ + adapters/

- 结构：
  ```
  roundtable/
  ├── core/
  │   ├── roles/{analyst,architect,developer,tester,reviewer,dba}.md  # 纯 prose
  │   ├── workflows/{workflow,bugfix,lint}.md  # 纯方法论
  │   └── docs-conventions.md
  └── adapters/
      ├── claude-code/{.claude-plugin/,commands/,agents/,skills/,hooks/}
      ├── codex/{.codex-plugin/,skills/,hooks/,AGENTS.md}
      └── shared/scripts/
  ```
- 迁移：把现有 commands/agents/skills 改为薄壳 → 引用 core/roles/<name>.md 内容
- 跨 runtime 入口：每 adapter 独立 plugin marketplace
- 维护：core/ 改动需同步两 adapter；adapter/ 改动可独立
- 复用：core/ 完全跨 runtime
- 风险：抽象层数多；初次重构成本高；core/ 与 adapter/ 边界容易飘
- 成本：高。预估 2-3 周（vs A 1-2 周）

### 方案 C：Codex-only fork

- 结构：clone roundtable → `roundtable-codex/`，删 Claude 专属
- 迁移：删 `.claude-plugin/` / `hooks/hooks.json` / commands/ → 转 skills/，frontmatter tools 删
- 跨 runtime 入口：Claude Code 用 roundtable，Codex 用 roundtable-codex（两个独立仓）
- 维护：双仓并行，bug fix / feature 各做一遍；同步成本极高
- 复用：方法论文档需手 copy
- 风险：双仓 drift；用户认知成本（哪个仓装哪个 runtime）
- 成本：短期最低（直接砍，~3 天），长期最高（双仓 drift）

### 方案 A vs B vs C 取舍维度对照

| 维度 | A 同仓多 manifest | B core/+adapters/ | C Codex-only fork |
|---|---|---|---|
| 首次重构成本 | 中（1-2 周） | 高（2-3 周） | 低（~3 天） |
| 长期维护成本 | 中 | 中-低（清晰分层） | 极高（drift） |
| Claude Code 用户影响 | 几乎无（保留原路径） | 需重学路径 | 无（用旧仓） |
| Codex 用户体验 | 等同 Claude Code | 等同 | 等同（但仓不同） |
| 业内参考 | superpowers 实证 | 无明确范例 | mattpocock 一样（但他没做 Codex） |
| Marketplace 分发 | 双 marketplace 可选 | 双 marketplace 必须 | 双仓 |
| 后续加 Cursor/Gemini | 加一组文件即可 | 加一个 adapter | 再 fork 一份 |
| 测试矩阵 | runtime × workflow | runtime × workflow | 每仓独立 |

## Open Questions

留给 architect 决策（fact layer 已穷尽，下面是需要拍板的取舍点）：

1. **三方案取舍**：A vs B vs C
2. **commands/* 重构策略**：
   - 选项 1：commands/* → skills/*（保留 Claude `/roundtable:workflow` 显式触发能力？skill 也能 explicit invoke）
   - 选项 2：commands/* 在 Claude 保留，Codex 下 skills/workflow/SKILL.md 镜像同内容
   - 选项 3：commands/* 在 Claude 保留，Codex 下完全靠 skill auto-invoke（用户描述意图）
3. **subagent tools frontmatter**：
   - 选项 1：删除 `tools:` 字段，纯靠 prose 约束
   - 选项 2：保留 Claude 用，Codex 下加 platform conditional 注释（runtime 自行处理）
   - 选项 3：把 `tools:` 改为 platform-agnostic 抽象（如 `permissions: read-only`），各 runtime adapter 翻译
4. **AGENTS.md 内容**：
   - 选项 1：文本指针 `CLAUDE.md`（占位，依赖 user 知道去看 CLAUDE.md）
   - 选项 2：全量 copy CLAUDE.md（保持同步成本）
   - 选项 3：CLAUDE.md 作为 source，写 build/sync 脚本生成 AGENTS.md
5. **是否提交 PR 到 `prime-radiant-inc/openai-codex-plugins`**：
   - 选项 1：提交（用户从 Codex App 内置 Plugins 装，曝光高）
   - 选项 2：自维护 mirror 仓 `duktig666/roundtable-codex-mirror`（无平台审核，但用户需手动 add）
   - 选项 3：不做 marketplace 提交，用户直接 git clone + `codex plugin add`
6. **是否要 `scripts/sync-to-codex-plugin.sh` 自动化**：
   - 选项 1：仿 superpowers 写完整 sync 脚本 + 测试
   - 选项 2：手动 PR 提交，每次发版手 copy
   - 选项 3：不进 prime-radiant，无需 sync
7. **Codex App finishing 模式接入位置**：
   - workflow.md Step 5 closeout 加 Step 0 环境检测 + Path A handoff payload？
   - 或在 developer subagent 收尾时检测？
   - 或写独立 skill `finishing-roundtable-workflow` 复用 superpowers 模式？
8. **TG MCP 在 Codex 下的兼容方案**：
   - 实测 Codex MCP 工具命名约定后写明
   - 或抽象表述「post to TG via MCP」让 runtime 自决
   - 或在 Codex 下 TG 广播降级为「输出到终端，让用户手转」
9. **`multi_agent` feature 启用方式**：
   - 安装文档要求用户预先 `[features] multi_agent = true`
   - 或 hook session-start 检测后报错提示
   - 或不要求（赌默认值是 true，但版本飘移风险）
10. **是否同步支持 Cursor / Gemini CLI / Copilot CLI**：本次仅 Codex，还是顺手把 superpowers 已支持的全做了？

## FAQ

（首次报告，暂无 follow-up，留 placeholder）
