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

## docs | P3 用户文档 + 模板 + onboarding | 2026-04-17
- 操作者: Claude + 用户
- 影响文件: docs/claude-md-template.md (139 行), docs/onboarding.md (125 行), docs/migration-from-local.md (139 行), examples/rust-backend-snippet.md (80 行), examples/ts-frontend-snippet.md (89 行), examples/python-datapipeline-snippet.md (93 行), docs/INDEX.md（更新链接）
- 说明: P3 用户向文档完成。claude-md-template.md 是核心（完整模板 + 填写提示 + FAQ + 最小可用示例）；onboarding.md 5 分钟上手手册；migration-from-local.md 给已有本地 `.claude/` 的项目的迁移 runbook；3 个 examples 片段覆盖 Rust 后端 / TS 前端 / Python 数据管道典型场景

## feat | P2 批量通用化剩余 5 角色 + 2 命令 | 2026-04-17
- 操作者: Claude + 用户
- 影响文件: skills/analyst.md (新建 157 行), agents/developer.md (163 行), agents/tester.md (163 行), agents/reviewer.md (130 行), agents/dba.md (134 行), commands/bugfix.md (97 行), commands/lint.md (106 行)
- 说明: 基于 P1 已验证的机制批量通用化。skill 形态：analyst（六问框架 + 研究澄清 AskUserQuestion）。agent 形态（subagent 隔离 + AskUserQuestion 不可用，需调度方注入上下文变量）：developer（plan-then-code + 自动工具链检测）、tester（对抗性 + benchmark + critical_modules 触发）、reviewer（决策一致性审查 + 按 critical_modules 落盘）、dba（schema/SQL/迁移审查，支持 PG/MySQL/SQLite/等多种 DB 类型自动识别）。command：bugfix（跳过 design，强制回归测试）、lint（8 项文档健康检查，纯只读报告）。全部 7 个新文件通过硬编码 grep 扫描 0 命中

## verify | P1 POC 方式 A 端到端通过 | 2026-04-17
- 操作者: 用户（Claude Code 真实会话）+ Claude
- 影响文件: docs/exec-plans/active/roundtable-plan.md（勾选方式 A 验收项）
- 说明: `claude --plugin-dir` 从 workspace 根启动；`/roundtable:workflow` 命令被识别；architect skill 激活；**D9 目标项目识别 AskUserQuestion 原生弹窗触发且可点选** —— 证明零 userConfig + Skill 形态 + AskUserQuestion 机制在 Claude Code 端到端可工作。方式 B（子项目内启动 git rev-parse 短路）及 design-doc 落盘路径 / CLAUDE.md 加载验证，待下一轮真实设计任务时观察

## feat | P1 POC：architect skill + workflow command | 2026-04-17
- 操作者: Claude + 用户
- 影响文件: skills/architect.md（新建，242 行）, commands/workflow.md（新建，118 行）
- 说明: P1 首批通用化产出 —— `skills/architect.md` 包含项目上下文识别（D9 + 工具链检测 + CLAUDE.md 加载）、三阶段工作流、AskUserQuestion 强制规则、design-doc / exec-plan / api-doc 模板；`commands/workflow.md` 实现规模判断 + 编排逻辑（skill 用 Skill 工具激活、agent 用 Task 派发时注入 target_project 上下文）；零业务术语硬编码，全部走占位符 + 运行时检测 / CLAUDE.md 声明

## design | roundtable (含 DEC-001 + exec-plan) | 2026-04-17
- 操作者: Claude (architect) + 用户
- 影响文件: docs/design-docs/roundtable.md, docs/decision-log.md, docs/exec-plans/active/roundtable-plan.md
- 说明: roundtable plugin 初始设计文档落盘；确认 D1-D9 九项关键决策并记入 DEC-001；产出 P0-P6 六阶段实施计划
