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

**必须 inline 执行检测** —— `Read` `${CLAUDE_PLUGIN_ROOT}/skills/_detect-project-context.md` 并只跑 step 1（D9 识别）和 step 3（`docs_root` 检测）。Skip step 2（toolchain）和 step 4（CLAUDE.md 加载）—— `lint` 是纯文档检查，不需要业务规则，也不需要 toolchain。

不要用 `Skill` 工具去激活下划线前缀的 helper。

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

### 6. 决策状态与结构审计（DEC-025 扩）

**定位**：本节是 `decision-log.md` 元规则（门槛 + 铁律 + 状态机）的**执行层审查工具**。机械判定条款全进本节；门槛类 judgement（某 DEC 是否真属 5 类必开）留 architect / reviewer。

#### L6.1 状态流转

- 长期 **Proposed** > 30 天未决 → 告警「长期 Proposed：建议评估 Accepted / Rejected」
- **Provisional** > 30 天未转正（DEC-025 引入）→ 告警「Provisional 超期：建议评估 Accepted / Refined by / Rejected」
- **Superseded** ≥ 90 天 → 告警「归档候选（铁律 7 触发条件 1）；配合 4 触发条件人工裁决」
- Superseded 条目但未指向替代 DEC-xxx → 报错「悬空 Superseded」

#### L6.2 铁律 5 影响范围 ≤10 行

- 扫每条 DEC 的 `**影响范围**:` 段
- 段内行数（按字面换行符）> 10 → 告警「影响范围超 10 行，建议移 design-doc `## 影响文件清单`」
- **不回溯** DEC-013~020（铁律 5 声明不回溯；lint 扫描跳过 DEC-013 ≤ NNN ≤ DEC-020）

#### L6.3 状态行字面值 + ≤60 字符

- 扫每条 DEC 的 `**状态**:` 行
- 必须以 6 种字面值之一起首：`Proposed` / `Provisional` / `Accepted` / `Superseded by DEC-xxx` / `Rejected`（可并列附 `Refined by DEC-xxx`）
- "起首" 判定字符终止于第一个全角/半角括号前（遇 `（` / `(` 即停）；括号内补语不计入字面值匹配
- 状态行总字符 > 60 → 告警「状态行超 60 字符，建议附加上下文放正文」
- **不回溯**（DEC-025 决定 10 扩用）：跳过 DEC-001 ≤ NNN ≤ DEC-020 的字符数与字面值检查（含 DEC-017 Amendment）。grandfather clause 仅适用字面值/字符数；悬空引用 L6.4 仍全量扫描

#### L6.4 Refined by / Superseded by 引用完整性

- 扫所有 `Refined by DEC-NNN` / `Superseded by DEC-NNN` 引用
- 引用的 DEC-NNN 不存在于 decision-log.md → 报错「悬空引用 DEC-NNN」
- 自引用 (`DEC-NNN Refines DEC-NNN` / `DEC-NNN Superseded by DEC-NNN`) → 报错「自引用」

#### L6.5 DEC 必填字段完整

- 每条 DEC 必含 `**日期**` / `**状态**` / `**上下文**` / `**决定**` / `**相关文档**` / `**影响范围**` **6 项**
- 任一缺失 → 告警「DEC-NNN 缺字段：<清单>」
- `**备选**` / `**理由**` 非强制（有则检，无则跳）
- **实施硬约束**：扫描 code-fence 感知 —— skip 位于 ` ```markdown ` / ` ``` ` 围栏内的 `### DEC-` 行（含 template 模板 `### DEC-[编号] [标题]`）；regex 用 `DEC-\d{3}` 而非 `DEC-\w+`（避免占位符 `DEC-xxx` / `DEC-MMM` 误报，L6.4 同此规则）
- **不回溯**（grandfather）：DEC-017 Amendment 缺 `**相关文档**` 属历史格式，跳过必填字段检查（同 L6.3 不回溯）；DEC-001 ≤ NNN ≤ DEC-020 全部 grandfather

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
- 决策总数: X（Accepted: X, Provisional: X, Proposed: X, Refined by: X, Superseded: X, Rejected: X）
- 超期告警: 长期 Proposed X | Provisional 超 30 天 X | 归档候选 X
- 结构告警: 影响范围 > 10 行 X | 状态行超长 X | 缺字段 X | 悬空 Refined/Superseded X
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
