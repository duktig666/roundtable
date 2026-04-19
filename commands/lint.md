---
description: Documentation health check. Scans project docs for decision drift, obsolescence, orphans, broken links, fact/inference confusion, stale exec-plans. Outputs a report; does NOT modify files (conflicts are flagged with diffs for user adjudication).
argument-hint: [target project name or path, optional]
---

# 文档健康检查

对目标项目的 docs 目录进行健康检查，输出报告。**不直接修改任何文件**。矛盾和冲突列出 diff 等用户裁决。

**参数**：`$ARGUMENTS`（可选，用空格分隔的参数）
- 留空 → 走 D9 自动识别 target_project
- 子项目名（如 `my-project`）→ 在 CWD 下找同名含 `.git/` 的子目录作为 target_project；无匹配则 AskUserQuestion
- 绝对路径（以 `/` 开头）→ 直接用这个路径作为 target_project
- `.` → 当前工作目录作为 target_project

---

## 步骤 0：确定 target_project + docs_root

### 有参数时（快捷路径）

- **`$ARGUMENTS` 是绝对路径** → `target_project = $ARGUMENTS`，跳过 D9
- **`$ARGUMENTS` 是 `.`** → `target_project = pwd`，跳过 D9
- **`$ARGUMENTS` 是子项目名** → 扫 CWD 找同名含 `.git/` 的子目录，命中即用；零命中提示用户；多命中走 AskUserQuestion

确定 `target_project` 后，仅检测 `docs_root`（`docs/` 存在 → 用；否则 `documentation/`；都没有告知用户"该项目无文档目录"并中止）。

### 无参数时（完整 D9）

**Execute the detection inline** — `Read` `skills/_detect-project-context.md` and run steps 1 (D9 identification) and 3 (`docs_root` detection) only. Skip step 2 (toolchain) and step 4 (`CLAUDE.md` loading) — `lint` is pure documentation check and needs neither business rules nor toolchain.

Do NOT use the `Skill` tool to activate the underscore-prefixed helper.

---

## 检查项

### 1. 决策一致性
- 扫描 `target_project/{docs_root}/design-docs/` 中的方案，对照 `decision-log.md`
- 检测实现层面（代码）是否偏离已 Accepted 的决策（需读代码 + `git log`）
- 检测是否有应该记录但缺失的决策（design-docs 中的重大选择未出现在 decision-log 中）

### 2. 过时检测
- 扫描带 frontmatter 的文档，`updated` 字段超过 90 天标记为"可能过时"
- 没有 frontmatter 的文档列为"缺少元数据"

### 3. 孤儿检测
- 找出没有被 `INDEX.md` / `decision-log.md` 或其他文档引用的文件，覆盖 `commands/workflow.md` §Step 7 索引的全部类别：
  - `analyze/[slug].md`
  - `design-docs/[slug].md`
  - `exec-plans/active/[slug]-plan.md`
  - `exec-plans/completed/[slug]-plan.md`
  - `testing/[slug].md` / `testing/[slug]-<type>.md`
  - `reviews/[YYYY-MM-DD]-[slug].md` / `reviews/[YYYY-MM-DD]-db-[slug].md`
  - `api-docs/[slug].md`
- 找出 `INDEX.md` 中列出但文件已不存在的条目（断链）

### 4. 断链检查
- 扫描所有 `.md` 文件中的内部链接（`[text](path)` 和 wiki-style `[[page]]`），检测链接目标是否存在

### 5. 事实 / 推论混淆
- 抽样检查 wiki 层文档（design-docs、analyze），标注未区分事实与推论的段落
- 标准：引用外部 / 竞品行为是"事实"，据此推导的自身方案是"推论"，两者应可区分

### 6. 决策状态审计
- `decision-log.md` 中是否有长期 Proposed（超过 30 天未决）的条目
- 是否有 Superseded 条目但未指向替代 DEC-xxx

### 7. exec-plans 过期审计
- 扫描 `{docs_root}/exec-plans/active/` 下每个计划
- 检查计划中的 checkbox 完成度（`- [x]` vs `- [ ]`）
- 全部勾选完成的标记为"建议移到 completed/"
- 超过 60 天未更新（`git log`）的标记为"可能停滞"
- **输出清单等用户确认后再移动**（本命令不自动移动文件）

### 8. log.md 完整性
- 最近的 design-docs / analyze 变更是否在 log.md 中有对应条目
- 通过 `git log --since="30 days ago" -- {docs_root}/` 对比 log.md 最近条目

---

## 输出格式

```markdown
# 文档健康检查报告

> 项目: {target_project}
> 日期: YYYY-MM-DD
> 检查范围: {docs_root}/

## 🔴 Critical（必须处理）
- [问题描述] → [建议操作]

## 🟡 Warning（建议处理）
- [问题描述] → [建议操作]

## 🔵 Info（参考）
- [问题描述]

## 统计
- 文档总数: X
- 有 frontmatter: X / 缺少: X
- 决策总数: X（Accepted: X, Proposed: X, Superseded: X）
- 孤儿文档: X
- 断链: X
- active exec-plans 建议归档: X
```

---

## 铁律

- **⚠️ 矛盾不要默认覆盖** —— 列出新旧 diff，等用户裁决
- **不修改任何文件** —— 只输出报告
- **不要"自动修复"** —— 每个问题都需要人的判断

---

## 完成后

- 在 `target_project/{docs_root}/log.md` 顶部 append：
  ```markdown
  ## lint | N issues found | [日期]
  - 操作者: lint
  - 影响文件: （仅读取，无修改）
  - 说明: Critical X / Warning Y / Info Z；详见对话输出
  ```
- 若用户根据报告做了实际修复（用 architect / developer 等），那些改动由对应角色各自记 log.md；`lint` 自己的 log 只记"发现了什么"，不记"修了什么"
