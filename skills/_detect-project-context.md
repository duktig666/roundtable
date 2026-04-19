---
name: _detect-project-context
description: Internal helper skill. Detects target_project (via D9 algorithm), toolchain, docs_root, and loads the target project's CLAUDE.md multi-role workflow configuration. Called by architect/analyst skills and by workflow/bugfix/lint commands. Not intended for direct user invocation (underscore prefix = internal).
---

# 项目上下文识别（shared helper）

本 skill 是被其他 skill / command 引用的**内部共享逻辑**。执行完毕后把结果输出到主会话 context（及 session 记忆），调用方继续自己的任务。

不要在响应用户普通任务时直接激活本 skill。

> **Activation note**：调用方（commands `workflow` / `bugfix` / `lint`，skills `architect` / `analyst`）应在主会话中 **`Read` 本文件并 inline 执行 4 步**，不要通过 `Skill` 工具激活。下划线前缀表示"内部 helper，不是终端用户 skill" —— P4 dogfooding 期间观察到，某些 Claude Code 版本对下划线前缀 skill 的 `Skill` 激活会失败。Inline 执行安全、确定性强，且把检测结果保留在活跃 session 记忆中供后续派发复用。

---

## Resource Access

| 操作 | 范围 |
|------|------|
| Read | `target_project/CLAUDE.md`、项目根标识文件（`Cargo.toml` / `package.json` / `pyproject.toml` / `go.mod` / `Move.toml`）、候选 `{docs_root}/` 目录 |
| Write | — |
| Report to caller | 结构化 context 摘要（`target_project`、`primary_lang`、`lint_cmd`、`test_cmd`、`docs_root`、`claude_md` 元数据包含 `critical_modules` / `design_ref` / `toolchain_override`） |
| Forbidden | 一切写入、git 操作、设计 / 代码修改 |

纯检测 helper。从不修改文件。

---

## 执行流程

按下列 4 步顺序执行。每一步允许调用方传参跳过（见"参数"章节）。

### 1. 目标项目识别（D9）

按优先级尝试：

1. **session 记忆里已有 `target_project`** → 若用户本轮任务没要求切换，直接复用，跳到第 2 步
2. **`git rev-parse --show-toplevel`**（在当前工作目录执行）：
   - 成功 → 结果作为 `target_project`，写入 session 记忆
   - 失败（当前目录非 git）→ 继续下一步
3. **扫描 CWD 下含 `.git/` 的一级子目录**，得到候选池：
   ```bash
   find . -maxdepth 2 -type d -name ".git" 2>/dev/null | sed 's|/.git$||' | sed 's|^\./||'
   ```
4. **正则匹配用户任务描述**里候选池里的项目名：
   - 唯一命中 → 用它；仍用 AskUserQuestion 二次确认（避免歧义）
   - 多命中 → AskUserQuestion 从命中项选
   - 零命中 → AskUserQuestion 从全集选
5. **用户显式切换**（"切到 X" / "改做 X 的 xxx"）→ 清空 session 记忆重跑第 2 步

确定 `target_project` 后存入 session 记忆。

### 2. 工具链检测（基于 target_project 根）

扫描 `target_project/` 根目录的标识文件：

| 命中文件 | 推定 | 默认 lint_cmd | 默认 test_cmd |
|---------|------|---------------|---------------|
| `Cargo.toml` | Rust | `cargo clippy --all-targets -- -D warnings` | `cargo test` 或 `cargo nextest run`（若可用） |
| `package.json` | JS/TS | 读 scripts.lint；回落 `pnpm lint` / `npm run lint` | 读 scripts.test；回落 `pnpm test` / `npm test` |
| `pyproject.toml` | Python | `ruff check` | `pytest` |
| `go.mod` | Go | `go vet ./...` | `go test ./...` |
| `Move.toml` | Move | `sui move build` | `sui move test` |
| 多文件并存 | 混合 | 按用户任务涉及的文件判断 | 同上 |

结果存入 session 记忆：`primary_lang`、`lint_cmd`、`test_cmd`。

### 3. 文档根目录检测（docs_root）

| 情况 | 行动 |
|------|------|
| `target_project/docs/` 存在 | `docs_root = "docs"` |
| `target_project/documentation/` 存在 | `docs_root = "documentation"` |
| 都不存在 | AskUserQuestion "我要创建 `target_project/docs/` 作为文档根，确认吗？" |

### 4. 加载 CLAUDE.md 业务规则

读取 `target_project/CLAUDE.md` 的「# 多角色工作流配置」section：

- **critical_modules** → 存入 session 记忆；决定后续是否触发 tester / reviewer
- **设计参考** → 存入 session 记忆；给 architect 做设计决策时用
- **工具链覆盖**（可选）→ 若声明了 `lint` / `test`，**覆盖**第 2 步的检测值
- **条件触发规则**（可选）→ 作为所有角色的硬约束
- **文档约定**（可选）→ 覆盖默认约定

**若 CLAUDE.md 没有此 section**：在对话里提醒调用方"该项目未包含多角色工作流配置 section，本次将只依赖自动检测；建议参考 plugin 的 `docs/claude-md-template.md` 补充"。

---

## 参数（由调用方声明）

调用方激活本 skill 时，可以声明哪些步骤要做 / 跳过。常见组合：

| 调用方 | 需要的步骤 |
|-------|-----------|
| architect / workflow / bugfix | 全部 4 步 |
| analyst | 1 + 3 + 4（不需要工具链；analyst 不跑 lint/test） |
| lint | 1 + 3 （只需要 target_project + docs_root；lint 是纯文档检查） |

调用方可在激活本 skill 时说明"跳过工具链检测 / 跳过 CLAUDE.md 加载"等，本 skill 遵循。

---

## 输出格式

完成后在对话里明确输出 **结构化摘要**，便于调用方引用：

```
[project context detected]
  target_project: <absolute path>
  primary_lang:   <rust | typescript | python | go | move | mixed | n/a>
  lint_cmd:       <cmd or "(not needed for this task)">
  test_cmd:       <cmd or "(not needed for this task)">
  docs_root:      <docs | documentation | other>
  claude_md:      <loaded | missing>
    critical_modules: [...]
    design_ref:       [...]
    toolchain_override: <yes | no>
```

然后把执行权交回调用方（architect / analyst / workflow command 等）继续自己的逻辑。

---

## 边界

- **只做识别，不做任何设计 / 编码 / 审查工作**
- 若第 1 步需要 AskUserQuestion 弹窗，弹完回到第 2 步继续；不把决策逻辑暴露给调用方
- 失败时（如整个 CWD 下没有 git 子目录、用户取消 AskUserQuestion）→ 报告具体失败原因，由调用方决定是否中止
