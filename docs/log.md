# 操作日志

> append-only，新条目追加在顶部（最新在前）。
> 定位：**设计层文档的时间索引**（"何时、谁、动了哪份文档"）。

## 边界

**记录**：analyst 报告、architect design-docs / api-docs / exec-plan、DEC 条目、关键 review / test-plan **落盘**、lint 发现、冲突裁决。

**不记录**：
- 代码变更、skill/agent/command prompt 文件调整 → 归 `git log`，在 PR 描述里说清
- 文档内措辞 / 排版 / 小修订 → 归文档自己的"变更记录"章节
- 对话讨论、未落盘的审查 → 不入账

**合并原则**：同一 agent 在同一轮产出多份文档（如 architect 同时输出 design-doc + DEC + exec-plan），**合并为一条**，`影响文件` 列全部路径；不要拆成多条。

## 前缀规范

| 前缀 | 含义 | 示例 |
|------|------|------|
| `analyze` | analyst 产出新分析报告 | `analyze \| some-topic \| 2026-04-17` |
| `design` | architect 产出/更新设计文档 | `design \| roundtable \| 2026-04-17` |
| `decide` | 新增或变更设计决策 (DEC-xxx) | `decide \| DEC-001 \| 2026-04-17` |
| `exec-plan` | 产出或完成执行计划 | `exec-plan \| some-slug completed \| 2026-04-17` |
| `review` | reviewer/dba 完成关键审查（落盘的） | `review \| some-slug \| 2026-04-17` |
| `test-plan` | tester 产出测试计划 | `test-plan \| some-slug \| 2026-04-17` |
| `lint` | 健康检查发现的问题及处理 | `lint \| 3 issues found \| 2026-04-17` |
| `fix` | 裁决冲突后的修复 | `fix \| DEC-xxx updated \| 2026-04-17` |

## 条目格式

```markdown
## [前缀] | [标题/slug] | [日期]
- 操作者: [agent 名 / 用户]
- 影响文件: [文件列表]
- 说明: [一句话]
```

---

## feat | P1 POC：architect skill + workflow command | 2026-04-17
- 操作者: Claude + 用户
- 影响文件: skills/architect.md（新建，242 行）, commands/workflow.md（新建，118 行）
- 说明: P1 首批通用化产出 —— `skills/architect.md` 包含项目上下文识别（D9 + 工具链检测 + CLAUDE.md 加载）、三阶段工作流、AskUserQuestion 强制规则、design-doc / exec-plan / api-doc 模板；`commands/workflow.md` 实现规模判断 + 编排逻辑（skill 用 Skill 工具激活、agent 用 Task 派发时注入 target_project 上下文）；零业务术语硬编码，全部走占位符 + 运行时检测 / CLAUDE.md 声明

## design | roundtable (含 DEC-001 + exec-plan) | 2026-04-17
- 操作者: Claude (architect) + 用户
- 影响文件: docs/design-docs/roundtable.md, docs/decision-log.md, docs/exec-plans/active/roundtable-plan.md
- 说明: roundtable plugin 初始设计文档落盘；确认 D1-D9 九项关键决策并记入 DEC-001；产出 P0-P6 六阶段实施计划
