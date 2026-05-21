---
slug: codex-compatibility
created: 2026-05-21
source: design-docs/codex-compatibility.md
reviewer: roundtable-reviewer
status: review-report
---

# roundtable Codex 兼容 — Reviewer 报告

## Scope

针对 developer 在 P1–P6（共 20 个 step）完成的所有改动做代码 review，覆盖 20 个新建/修改的文件：

- `.codex-plugin/plugin.json`（新）
- `.claude-plugin/plugin.json` / `marketplace.json`（修，版本号）
- `AGENTS.md`（新）
- `agents/{developer,tester,reviewer,dba}.md`（修，正文新增 Codex 段）
- `skills/{workflow,bugfix,lint}/SKILL.md` + 各自 `references/codex-tools.md`（新）
- `skills/{analyst,architect}/references/codex-tools.md`（新）
- `commands/{workflow,bugfix,lint}.md`（重写为薄壳）
- `README.md` / `README-zh.md` / `CONTRIBUTING.md` / `CHANGELOG.md`（修）

reviewer 工作约束：strict read-only。本次仅做了 `Read` / `Grep` / `Bash`（python 验 JSON、bash 跑 hook、grep 跨文件一致性）；没有任何 `Write` / `Edit` / `apply_patch` / `git` 写操作；唯一可写产物 = 本报告。

## Findings

### Critical

无。所有 JSON 合法；hook 可执行；薄壳改写无残留旧 Phase Matrix；reviewer / dba prose 加强后禁写约束齐全；Manifest schema 合规；DEC-0001..0010 全部落地。release 不被 block。

### Warning

- **W1 — `.codex-plugin/plugin.json:46-47` 引用了不存在的 asset 文件**：`composerIcon` 指向 `./assets/icon.svg`，`logo` 指向 `./assets/logo.png`，但 `assets/` 目录是空的（`ls assets/` 无文件）。exec-plan P1.1 已标注「可临时占位，发版前完善」，但当前 manifest 引用的是不存在的路径。
  - 影响：Codex App 装 plugin 时 UI 加载图标会 404；Codex CLI 不读 interface 块，无影响
  - 建议：发 v0.0.7 release 前补 `assets/icon.svg` + `assets/logo.png`（或临时把字段从 manifest 删掉，等资源齐再加）

- **W2 — `.codex-plugin/plugin.json:24` hook 事件名大小写不确定**：当前用 camelCase `sessionStart`。analyst §C.5 doc 节列 `SessionStart`（PascalCase）+ JSON 示例 `"PreToolUse": [...]`，但同节 TS schema 列 `"sessionStart" | "preToolUse" | ...`（camelCase）。两种写法 doc 都出现，未明确哪种是 Codex runtime 实际接受的事件键。
  - 影响：若 Codex 实际只认 `SessionStart`（PascalCase），当前 manifest 的 hook 不会触发，SessionStart 注入的 Roundtable context 会缺失，所有 skill 无法读 `docs_root`
  - 建议：tester phase 真跑 Codex 时优先验证此点；如果不工作，第一时间改为 `"SessionStart"` PascalCase；analyst 没确凿事实就选哪种都是赌

- **W3 — `README.md:7` 行数声明陈旧**：仍写 `~760 lines of prompt+config total`，但 P2 迁完 + references 加完后实际是 ~1040 行（`wc -l` 实测）。
  - 影响：用户感知不准；不影响功能
  - 建议：改为 `~1040 lines` 或直接删除具体数字（避免后续 drift）

- **W4 — `CONTRIBUTING.md:37-45` 含已废弃的"三件套"段落**：列 `docs/log.md` + `docs/decision-log.md`，但 v0.0.5 CHANGELOG 明确这两个 mechanism 已 removed。pre-existing 过时内容（不是本次回归），但 P6.2 重写 CONTRIBUTING 时未顺手清理。
  - 影响：新贡献者读到会按废弃 mechanism 工作
  - 建议：单开 follow-up issue 修；不属于 codex-compatibility scope（Surgical Changes 原则允许保留）

- **W5 — `skills/workflow/SKILL.md:76` Step 5 子节命名「Step 0」有点歧义**：`## Step 5: Closeout` 下面又开了 `### Step 0: Detect environment`，Step 5 内部含 Step 0 是反直觉的（这是 developer 引用 superpowers `using-git-worktrees` Step 0 模式直接套过来的）。
  - 影响：模型读 prompt 时可能困惑「Step 0 是 Step 5 的子步骤还是平级 Step」
  - 建议：改成 `### Step 5.0: Detect environment` 或 `### 5a Detect environment`；不 block release

### Suggestion

- **S1 — `agents/reviewer.md:62` Codex 禁写 prose 是混排** （`## Forbidden` bullets 后接段落 prose，没小标题分隔）。可读性稍差但功能没问题。建议未来加 `### Codex runtime note` 小标题（与 developer.md/tester.md 风格对齐）。

- **S2 — `agents/dba.md:55-57` 同 S1**：Codex 禁写 prose 是 bullets 接在 Forbidden 节末尾，没小标题。功能上等价，但与 developer.md/tester.md 的 `## Codex Runtime Note` 风格不一致。

- **S3 — `skills/workflow/references/codex-tools.md:75` 表述「workflow degrades to terminal mode automatically」**：「自动降级」语义靠 channel-aware 检测；但 workflow SKILL.md Step 2 只检测 `plugin:telegram:telegram` 这个具体 MCP server 名，没说怎么 detect Codex 侧 TG MCP。tester phase 实测时需补 Codex 下 TG MCP 工具名识别逻辑。analyst R2/F.6 已标 deferred follow-up，不算遗漏。

- **S4 — 跨文件 `Codex Runtime Note` 命名漂移**：developer.md / tester.md 用 `## Codex Runtime Note`（H2），reviewer.md / dba.md 直接在 `## Forbidden` 段末尾混入；analyst/architect 的 references 用 `## Boundaries unchanged`。可以未来统一一个标题模板。

- **S5 — `CHANGELOG.md:14` v0.0.7 entry 未明示 BREAKING CHANGE**：commands/* → skills/* 迁移技术上是兼容（薄壳保留 `/roundtable:<name>` 入口），但 P0.1 验证 deferred to tester，若 Claude `/<plugin>:<skill>` syntax 不工作 + 用户依赖薄壳来 dispatch，运行时行为变化。建议在 v0.0.7 entry 加一条 `### Note on backwards compatibility`，写明「commands/*.md 现已是薄壳；canonical body 在 skills/<name>/SKILL.md；如 Claude 用户从未配置自定义薄壳，无感」。

## DEC Conformance Matrix

| DEC | 决策 | 实施位置 | 一致 |
|---|---|---|---|
| 0001 | 同仓多 manifest（方案 A） | 根目录 `.claude-plugin/` + `.codex-plugin/` 共存；core 共享 | ✅ |
| 0002 | commands/* 迁 skills/*，删 commands/ | `skills/{workflow,bugfix,lint}/SKILL.md` 新建；`commands/*` 改薄壳（exec-plan Change Log 已记 in-flight 修订：safe default 保留薄壳）| ✅（含修订）|
| 0003 | subagent tools frontmatter Claude 保留，Codex 靠 prose | 4 个 agent frontmatter `tools:` 字段不动；reviewer.md L62 + dba.md L55-57 加 Codex 禁写 prose；developer/tester 加 Codex Runtime Note | ✅ |
| 0004 | AGENTS.md 文本指针 `CLAUDE.md` | `AGENTS.md` 内容仅一行 `CLAUDE.md` | ✅ |
| 0005 | 单仓直装，不开 mirror | README.md L37-38 + README-zh.md L37-38 `codex plugin add github.com/duktig666/roundtable`；无 mirror 仓引用 | ✅ |
| 0006 | 不写 sync 脚本 | 仓内无 `scripts/sync-to-codex-plugin.sh`；无 `tests/codex-plugin-sync/` | ✅ |
| 0007 | workflow Step 5 closeout 加环境检测 + Path A handoff | `skills/workflow/SKILL.md:76-121`（Step 0 探测 + 4-row decision matrix + Path A handoff payload 4 字段：commit SHA / branch name / PR title / PR body）；Standard closeout L123-136 4-option menu 保留 | ✅ |
| 0008 | TG MCP Claude 用，Codex 自动降级终端 | `skills/workflow/references/codex-tools.md:62-75` TG MCP 章节明确 optional + 终端降级；README L51 troubleshooting 提及 `codex mcp add telegram` | ✅ |
| 0009 | multi_agent README 软提示 | README L49 + README-zh.md L49 + 三个 `references/codex-tools.md` troubleshooting 段均含 `[features].multi_agent = true` 软提示；无 hooks/session-start 强制检测 | ✅ |
| 0010 | 仅 Codex，其他 runtime follow-up | 仓内无 `.cursor-plugin/` / `.opencode/` / `gemini-extension.json` / `GEMINI.md`；CHANGELOG L40 明示 「Cursor / Gemini CLI / Copilot CLI / OpenCode adapters are explicit follow-ups」 | ✅ |

10/10 一致。DEC-0002 的 in-flight 修订（commands/* 保留薄壳）已正确记入 exec-plan Change Log（L177）。

## Cross-File Consistency

### README ↔ design-doc 安装路径

- README.md L37-38 + README-zh.md L37-38 写 `codex plugin add github.com/duktig666/roundtable` — 与 design-doc DEC-0005 「单仓直装」+ §Acceptance Criteria 完全一致 ✅
- README L11-15 Claude Code marketplace 安装路径完整保留 — 与 DEC-0005「Claude 用户安装路径不变」一致 ✅

### CHANGELOG ↔ design-doc DEC 列表

- CHANGELOG v0.0.7 entry（L14-41）覆盖到 DEC-0001(`.codex-plugin/`+`.claude-plugin/`) / DEC-0002(skills 迁移) / DEC-0003(prose 加强) / DEC-0004(AGENTS.md) / DEC-0005(`codex plugin add`) / DEC-0007(Path A handoff) / DEC-0008(TG MCP 可选 + 终端降级) / DEC-0009(`multi_agent` 软提示) / DEC-0010(其他 runtime follow-up)
- DEC-0006（不写 sync 脚本）未在 CHANGELOG 显式提及，但属于「未做」清单，合理省略
- 缺：未明示 BREAKING CHANGE 提示（参 Warning S5）

### references/codex-tools.md ↔ analyst §C.7 工具映射

- `Read` → `cat`/`rg`/`head`/`tail`（shell）：5 个 references 文件全部一致 ✅
- `Write`/`Edit` → `apply_patch`：全部一致 ✅
- `Grep` → `rg`：全部一致 ✅
- `Glob` → `find` / `rg --files`：全部一致 ✅
- `Bash` → `shell`：全部一致 ✅
- `Skill` → 自然加载 / 描述意图：workflow + architect references 都覆盖 ✅
- `Agent` → `spawn_agent` + `wait_agent` + `close_agent`：workflow / bugfix / architect references 都覆盖 ✅
- `AskUserQuestion` → `request_user_input`：全部一致 ✅
- `TodoWrite` → `update_plan`：只有 workflow references 写了（L13）；其他 skill 未用 TodoWrite，无需补 ✅
- `WebFetch` / `WebSearch` → `web.run`：仅 analyst references 写了（L13-14），符合 analyst 是唯一用 WebFetch/WebSearch 的 skill ✅

跨 5 个 references 文件，工具映射高度一致，无矛盾。

### agent prose ↔ frontmatter tools

- developer.md / tester.md：frontmatter `tools: Read, Grep, Glob, Bash, Write, Edit`；正文 Codex Runtime Note 列等价映射（Read→cat/rg；Write/Edit→apply_patch；Bash→shell）— 一致 ✅
- reviewer.md：frontmatter `tools: Read, Grep, Glob, Bash`（无 Write/Edit）；正文 L62 加 Codex 禁写 prose 明确 「MUST NOT call apply_patch or any shell command that mutates files」 — 一致 ✅
- dba.md：frontmatter `tools: Read, Grep, Glob, Bash`；正文 L55-57 同时禁 apply_patch + 禁 SQL writes（INSERT/UPDATE/DELETE/ALTER/DROP/TRUNCATE/MERGE/REPLACE 全列） — 一致 ✅

任务规格要求 dba SQL 禁写覆盖 8 个动词，实测全到位（MERGE / REPLACE 等扩展也覆盖）。

## Manifest Schema Compliance

针对 `.codex-plugin/plugin.json` 与 analyst §C.1 列出的 Codex schema 逐字段对照：

| 字段 | analyst §C.1 要求 | 实施值 | 合规 |
|---|---|---|---|
| `name` | string，kebab-case，默认空则用目录名 | `"roundtable"` | ✅ |
| `version` | string\|null | `"0.0.7"` | ✅ |
| `description` | string\|null | 完整描述 | ✅ |
| `keywords` | string[] | 8 项 | ✅ |
| `skills` | 必须 `./xxx` | `"./skills/"` | ✅ |
| `hooks` | string / string[] / inline obj / inline obj[] 4 种形态之一 | inline obj（含 `sessionStart` key） | ✅（但事件名大小写存疑，见 W2） |
| `interface.displayName` | string | `"Roundtable"` | ✅ |
| `interface.shortDescription` | string | "Multi-role AI development workflow…" | ✅ |
| `interface.longDescription` | string | 完整描述 | ✅ |
| `interface.developerName` | string | `"duktig666"` | ✅ |
| `interface.category` | string | `"Coding"` | ✅ |
| `interface.capabilities` | string[]（已见值 Read/Write/Interactive） | `["Interactive", "Read", "Write"]` | ✅ |
| `interface.defaultPrompt` | ≤3 条，每条 ≤128 字符 | 3 条（40 / 30 / 24 字符），全在 limit 内 | ✅ |
| `interface.brandColor` | hex | `"#3B82F6"` | ✅ |
| `interface.composerIcon` | path `./...` | `"./assets/icon.svg"` | ✅ 路径合规但文件不存在（见 W1）|
| `interface.logo` | path `./...` | `"./assets/logo.png"` | ✅ 路径合规但文件不存在（见 W1）|
| `interface.screenshots` | string[] | `[]` | ✅（空数组合法）|

路径硬约束（`./` 开头、不含 `..`）：所有 path 字段均 `./` 开头 ✅。

`.claude-plugin/plugin.json` 现状：仅含 `name / version / description / author / homepage / repository / license`，无 Codex 专用字段（`interface` / `skills` / `hooks`）—— Claude Code schema 干净，未 cross-contaminate ✅。

## hook 行为验证（read-only）

- `python3 -c "import json; json.load(open('.codex-plugin/plugin.json'))"` → no error ✅
- `python3 -c "import json; json.load(open('.claude-plugin/plugin.json'))"` → no error ✅
- `python3 -c "import json; json.load(open('.claude-plugin/marketplace.json'))"` → no error ✅
- `python3 -c "import json; json.load(open('hooks/hooks.json'))"` → no error ✅
- `bash hooks/session-start <<< '{"hook_event_name":"SessionStart"}'` → 输出 `{"additionalContext":"Roundtable context:\ndocs_root: /data/rsw/roundtable/docs\nproject_id: roundtable\nstatus: ok"}` ✅（fallback 分支，因测试 env 无 CURSOR_PLUGIN_ROOT / CLAUDE_PLUGIN_ROOT；该 fallback 字段名与 Codex 期待的 `additionalContext` 一致，符合 analyst §C.5）

## Risks 覆盖

design-doc §Risks & Mitigations R1-R7 实施侧覆盖情况：

- **R1（Claude `/<plugin>:<skill>` syntax）**：commands/* 保留薄壳 = exec-plan P2.5 in-flight safe default 应对；P0.1 deferred to tester phase ✅
- **R2（Codex MCP TG 命名）**：references/codex-tools.md TG MCP 章节留占位说明，写明用 `codex /mcp` 查 ✅
- **R3（multi_agent 版本飘移）**：README + references troubleshooting 软提示 ✅
- **R4（Codex subagent filesystem 共享）**：P0.3 deferred to tester phase；exec-plan Change Log 已记 ✅
- **R5（plugin_hooks feature 未启用）**：README L50 + workflow references troubleshooting L93 软提示 ✅
- **R6（SessionStart hook stdout schema）**：现 hook 脚本三分支 fallback 覆盖 Cursor/Claude/Codex；P0.2 deferred to tester ✅
- **R7（Claude 用户 muscle memory）**：commands/* 薄壳保留 `/roundtable:<name>` 入口；CHANGELOG note 部分覆盖，但未明示 BREAKING（见 Warning S5）⚠️

实施未引入设计文档未列的新 risk。

deferred-to-user 三项（P0.1 / P0.2 / P0.3）皆属「本会话无法验证」性质（无法重启 Claude / 无 Codex 安装），exec-plan Change Log L177 已显式记，移交 tester phase 是合理的 — 不算 developer 偷懒。

## Surgical Changes 合规

- 4 个 agent 文件 frontmatter `tools:` 完全未动（DEC-0003 要求）✅
- analyst/architect SKILL.md 完全未动（grep 验证 AskUserQuestion + channel-aware 段保留原样）✅
- `.claude-plugin/plugin.json` 仅 version 字段从 0.0.6 → 0.0.7，无功能改动 ✅
- 3 个 commands 文件改为 12 行薄壳（旧 Phase Matrix 等内容已迁 skills/）— 范围最小化 ✅
- hooks/session-start 完全未改动（mtime: Apr 29，未触）— exec-plan P1.3 ⏩ skipped 合理 ✅
- 未引入额外抽象层（无 `permissions: read-only` 跨 runtime 抽象字段；无 build/sync 脚本；无 adapters/ 层）— 符合 DEC-0002/0003/0006 决策 ✅

唯一可商榷：CONTRIBUTING.md 的"三件套"段落 P6.2 没顺手清理。但根 CLAUDE.md「不重构没坏的」+ Surgical Changes 边界允许 — 单提 Suggestion，不算回归。

## Conclusion

**Overall: approve-with-warnings**

逻辑串：
- 10 个 DEC 全部一致落地；in-flight 修订（commands/* 薄壳）有 Change Log 记录
- Manifest schema 合规；JSON 全部合法；hook 可执行
- Cross-file 一致性高（5 个 references 工具映射统一；agent prose ↔ frontmatter 一致）
- Surgical Changes 良好（agents frontmatter 不动；analyst/architect SKILL 不动；session-start 不动）
- reviewer / dba 禁写 prose 加强力度足够；dba SQL 禁写覆盖完整
- workflow Step 5 环境探测 + Path A handoff 4 字段齐全
- 三项 P0 pre-flight 合理 defer 到 tester phase（本会话无法验）

Warnings 阻挡的是「release polish」不是「functional release」：
- W1（assets 占位）发版前必补
- W2（hook 事件名大小写）tester 实测时优先校验
- W3（README 行数声明）顺手改即可
- W4 / W5 / Suggestion 都是非阻塞

后续建议：

1. **tester phase 优先级**：先验 W2（hook 事件名 case），再验 P0.1（Claude skill 触发）/ P0.2（hook stdout 在 Codex 下被读到）/ P0.3（spawn_agent filesystem 共享）
2. **assets 资源**：发 v0.0.7 release 前补 `assets/icon.svg` + `assets/logo.png`（即使 placeholder）
3. **README 行数**：发版前同步更新
4. **CONTRIBUTING 三件套段落**：单开 cleanup follow-up issue
5. **CHANGELOG migration note**：补一条 backwards compatibility 说明
