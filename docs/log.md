# 操作日志

> append-only，新条目追加在顶部（最新在前）。
> 定位：**设计层文档的时间索引**（"何时、谁、动了哪份文档"）。

## 边界

**记录**：analyst 报告、architect design-docs / api-docs / exec-plan、DEC 条目、关键 review/test-plan **落盘**、lint 发现、冲突裁决。

**不记录**：
- 代码变更、plugin agent/skill/command prompt 调整 → 归 `git log`，在 PR 描述里说清
- 文档内措辞/排版/小修订 → 归文档自己的"变更记录"章节
- 对话讨论、未落盘的审查 → 不入账

**合并原则**：同一 agent 在同一轮产出多份文档（如 architect 同时输出 design-doc + DEC + exec-plan），**合并为一条**，`影响文件` 列全部路径；不要拆成多条。

## 前缀规范

| 前缀 | 含义 | 示例 |
|------|------|------|
| `analyze` | analyst 产出新分析报告 | `analyze \| role-profile-system \| 2026-04-17` |
| `design` | architect 产出/更新设计文档 | `design \| roundtable \| 2026-04-17` |
| `decide` | 新增或变更设计决策 (DEC-xxx) | `decide \| DEC-002 \| 2026-04-17` |
| `exec-plan` | 产出或完成执行计划 | `exec-plan \| roundtable-plan completed \| 2026-04-17` |
| `review` | reviewer/dba 完成关键审查（落盘的） | `review \| xxx \| 2026-04-17` |
| `test-plan` | tester 产出测试计划 | `test-plan \| xxx \| 2026-04-17` |
| `lint` | 健康检查发现的问题及处理 | `lint \| 3 issues found \| 2026-04-17` |
| `fix` | 裁决冲突后的修复 | `fix \| DEC-xxx updated \| 2026-04-17` |
| `migrate` | 跨仓库文档迁移 | `migrate \| from dex-sui \| 2026-04-17` |

## 条目格式

```markdown
## [前缀] | [标题/slug] | [日期]
- 操作者: [agent 名 / 用户]
- 影响文件: [文件列表]
- 说明: [一句话]
```

---

## refactor | docs 目录结构对齐 plugin 规范 | 2026-04-17
- 操作者: Claude (architect)
- 影响文件: docs/design.md → docs/design-docs/roundtable.md；docs/exec-plan.md → docs/exec-plans/active/roundtable-plan.md；新建 docs/log.md、docs/INDEX.md；新建空目录 analyze/ exec-plans/completed/ testing/plans/ reviews/（含 .gitkeep）
- 说明: 按 roundtable plugin 自己推荐的"产出契约"重构 docs 目录（dogfooding），避免将来 v0.2 多 slug 时扁平结构装不下；同步更新 README.md、design-doc §3.1 目录结构、exec-plan 的 P0 任务清单里的路径引用

## migrate | from dex-sui | 2026-04-17
- 操作者: Claude (architect)
- 影响文件: docs/design.md（←来自 dex-sui/docs/design-docs/moongpt-harness-plugin.md）、docs/exec-plan.md（←来自 dex-sui/docs/exec-plans/active/moongpt-harness-plugin-plan.md）、docs/decision-log.md（DEC-001 承接自 dex-sui DEC-010）
- 说明: 多角色 AI 工作流通用化 plugin 的设计和执行计划从 dex-sui 迁入本仓库；plugin 改名 moongpt-harness → roundtable；owner chainupcloud → duktig666；Apache-2.0 许可；dex-sui 原副本删除，其 DEC-010 的"相关文档"字段改为本仓库 GitHub URL

## init | roundtable 仓库初始化 | 2026-04-17
- 操作者: 用户 + Claude
- 影响文件: .claude-plugin/plugin.json、.claude-plugin/marketplace.json、README.md、LICENSE (Apache-2.0)、CHANGELOG.md、CONTRIBUTING.md、.gitignore、skills/agents/commands/hooks/examples 的 .gitkeep、docs/decision-log.md（DEC-001）
- 说明: 建仓 github.com/duktig666/roundtable、配置 SSH（id_duktig666 + 别名 + gitconfig includeIf）、本地 clone 到 /data/rsw/roundtable/、首次 commit 骨架
