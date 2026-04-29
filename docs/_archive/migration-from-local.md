# 从项目本地 `.claude/` 迁移到 roundtable plugin

如果你的项目**原本**在 `<project>/.claude/agents/`、`<project>/.claude/commands/` 下定义了自建的 agent / command，本文档介绍迁移路径。

---

## 为什么要迁移

| 自建本地 | roundtable plugin |
|---------|-------------------|
| 只在这一个项目可用 | 所有项目共享 |
| 更新要改多份（每项目一份） | 一次更新全局生效 |
| 无标准约定 | 统一的 design-docs / decision-log / log.md 三件套 |
| 不含 AskUserQuestion 强制规则 | architect 决策强制弹窗 |

---

## ⚠️ Claude Code 的合并规则

**本地 `.claude/` 会覆盖 plugin**。所以迁移前如果你不清理本地，plugin 装了也不生效 —— 会是最难排查的问题之一。

合并优先级（后者覆盖前者）：
```
plugin (~/.claude/plugins/)  <  user (~/.claude/)  <  project (<project>/.claude/)  <  local settings
```

---

## 迁移 runbook

### 步骤 1：备份本地定义

```bash
cd <project>

# 备份（不删），以便回滚
git mv .claude/agents/   .claude/agents.backup/
git mv .claude/commands/ .claude/commands.backup/
git commit -m "chore: backup local .claude/agents/ and commands/ before roundtable migration"
```

**为什么先备份不直接删**：一旦 plugin 行为不如旧的本地定义，回滚成本最低。

### 步骤 2：安装 roundtable plugin

```
/plugin marketplace add duktig666/roundtable
/plugin install roundtable@roundtable --scope user
```

### 步骤 3：在 CLAUDE.md 加配置 section

把本地 agent / command 里的**业务规则**提炼成 CLAUDE.md 的 `# 多角色工作流配置` section。

参考 `docs/claude-md-template.md`。核心是：

- 把本地 `architect.md` 里"首要对标 XXX、参考 YYY" → CLAUDE.md `## 设计参考`
- 把本地 `tester.md` 里"撮合引擎/清算/资金必触发" → CLAUDE.md `## critical_modules`
- 把本地 `developer.md` 里 `cargo xclippy` 等工具链命令 → 不用写，roundtable 自动检测；如需覆盖写 `## 工具链覆盖`
- 把条件触发规则（"涉及金额禁浮点" 等）→ CLAUDE.md `## 条件触发规则`

### 步骤 4：回归测试

跑一次代表性的 `/roundtable:workflow` 任务，对比行为与旧本地版是否一致：

**核对清单**：
- [ ] design-doc 落盘路径正确（`<project>/docs/design-docs/<slug>.md`）
- [ ] decision-log 追加新 DEC 条目（如有决策）
- [ ] log.md 有合并条目（architect 一轮多产出只记一条）
- [ ] architect 决策点用 AskUserQuestion **弹窗**（不是文字问）
- [ ] developer 跑的 lint / test 命令正确
- [ ] tester 被触发（如涉及 CLAUDE.md 声明的 critical_modules）
- [ ] reviewer 关键审查落盘到 `docs/reviews/`（如涉及关键模块）

### 步骤 5：删除备份

所有测试通过后：

```bash
rm -rf .claude/agents.backup/ .claude/commands.backup/
git add -A && git commit -m "chore: remove local agents.backup/ and commands.backup/ after roundtable migration"
```

---

## 如果迁移出现回归

**症状 A：plugin agent 被本地 `.claude/agents/xxx.md` 覆盖**
- 验证：`ls <project>/.claude/agents/` 有同名文件吗？
- 修复：同步骤 1，把 `agents/` 移到 `agents.backup/`

**症状 B：roundtable 自动检测的工具链命令不对**
- 验证：`/roundtable:workflow` 跑完 developer 阶段时，lint 命令是否符合预期
- 修复：在 CLAUDE.md 加 `## 工具链覆盖` section 显式声明

**症状 C：critical_modules 没识别**
- 验证：涉及关键代码时 `/roundtable:workflow` 是否派发了 tester
- 修复：确认 CLAUDE.md `## critical_modules` 里的关键词能命中任务描述

**症状 D：AskUserQuestion 没弹窗**
- 验证：architect 是否在 skill 形态下运行（不是通过 `@architect` 派发到 subagent）
- 修复：通过 `/roundtable:workflow` 进入（workflow command 会激活 skill）；避免直接 `@roundtable:architect` 当 agent 派发

---

## 常见坑

### 坑 1：忘了备份 `.claude/commands/`
很多项目有自建的本地 commands（如 `/my-project:deploy`），这些**不属于** roundtable 通用化范围 —— roundtable 只替换 analyst / architect / developer / tester / reviewer / dba 这 6 个角色相关的 `.claude/commands/{workflow,bugfix,lint}.md`。

所以步骤 1 里 `git mv .claude/commands/ .claude/commands.backup/` 后，记得**把项目自己的 command 文件再挑回来**放到 `.claude/commands/` 下（除了 workflow.md / bugfix.md / lint.md）：

```bash
mkdir -p .claude/commands
cd .claude/commands.backup
for f in *.md; do
  # 跳过会被 roundtable plugin 覆盖的
  case "$f" in
    workflow.md|bugfix.md|lint.md) continue ;;
  esac
  mv "$f" ../commands/
done
```

### 坑 2：本地 CLAUDE.md 已经写过类似规则
有些项目原本 CLAUDE.md 已经有"关键模块"、"触发规则"等。迁移时**把那些段落统一收拢到 `# 多角色工作流配置` section 下**，避免规则散落多处 agent 查找时优先级混乱。

### 坑 3：多人协作中某些成员忘了装 plugin
一旦你提交了 backup 改动，其他没装 plugin 的团队成员跑 `/workflow` 会找不到命令。同步提醒大家 `/plugin install roundtable@roundtable --scope user`，或把安装命令写到项目 README 的"上手"章节。

---

## 迁移成功信号

- ✅ `.claude/agents/` 下只剩项目特有的（或空）
- ✅ `.claude/commands/` 下只剩项目特有的命令（workflow.md / bugfix.md / lint.md 不再存在）
- ✅ 项目 CLAUDE.md 有完整的 `# 多角色工作流配置` section
- ✅ `/roundtable:workflow` 能端到端跑完一个代表性任务
- ✅ `.claude/agents.backup/` `.claude/commands.backup/` 已删除
