---
slug: roundtable
created: 2026-04-29
status: active
---

# Roundtable — 架构总览

Claude Code plugin，把多角色 AI 工作流（analyst → architect → developer → tester → reviewer → dba）封装成一组 skills / agents / commands。**最小化设计**：去掉一切可由 CLAUDE.md 表达的规则，只保留 plugin 才能提供的能力（hook 确定性 / subagent 上下文隔离 / slash command 入口 / 跨项目分发）。

## 1. 组件清单

```
roundtable/
├── agents/                     # 4 subagents（独立上下文）
│   ├── developer.md            # 实施 + 单元测试
│   ├── tester.md               # 对抗性测试 + E2E + Playwright
│   ├── reviewer.md             # 代码 review（只读）
│   └── dba.md                  # DB schema / SQL / migration review（只读）
├── skills/                     # 2 skills（主会话，可 AskUserQuestion）
│   ├── analyst/SKILL.md        # 调研 / 六问 / 事实层
│   └── architect/SKILL.md      # 设计 / 决策 / 双轨产出
├── commands/                   # 3 slash commands
│   ├── workflow.md             # 多角色编排入口
│   ├── bugfix.md               # bug 修复（跳过 design 阶段）
│   └── lint.md                 # 文档健康检查 + 重建 INDEX.md
├── hooks/
│   ├── hooks.json              # SessionStart 注册
│   └── session-start           # bash：注入 docs_root + project_id
└── docs/                       # 用户产出（本仓库的 dogfood 实例）
```

总规模：约 760 行 prompt + config。

## 2. 角色边界

| 角色 | 形态 | 输入 | 输出 | 写权限 |
|------|------|------|------|--------|
| analyst | skill | 用户问题 | `analyze/<slug>.md`（事实层） | analyze/ |
| architect | skill | analyst 报告（可选）+ 用户目标 | `design-docs/<slug>.md`（中/大）+ `exec-plans/active/<slug>.md` | design-docs/, exec-plans/ |
| developer | subagent | exec-plan + 可选 design-doc | code + tests | src/, tests/, exec-plan checkbox |
| tester | subagent | exec-plan | tests + `testing/<slug>.md` | tests/, testing/ |
| reviewer | subagent | diff + design-doc + exec-plan | `reviews/<date>-<slug>.md` | reviews/（只读 src/） |
| dba | subagent | diff + design-doc | `reviews/<date>-db-<slug>.md` | reviews/（只读，禁 SQL 写） |

**Resource Access 是硬约束**：写在每个 prompt 文件的 Forbidden 列表里，subagent 收到时是 prompt 级合同。

## 3. 双轨产出（架构决策）

architect 按任务规模分流：

| 规模 | 产出 | 用户 gate 数 |
|------|------|--------------|
| small（bug fix / 单文件 / UI 微调） | 单文件 exec-plan，含 `## Solution` 小节 | 1（exec-plan 确认） |
| medium / large（新功能 / 模块变更 / 跨模块） | design-doc → 用户确认 → exec-plan → 用户确认 | 2（设计 + 计划各一道） |

为什么拆：design 是讨论态，频繁 iterate；exec-plan 是执行态，主要变化是勾 checkbox。强行合一份文件 = 两种 lifecycle 混进同一 git diff。

跨文件契约：exec-plan frontmatter `source: design-docs/<slug>.md` 链回设计文档。

## 4. Phase Matrix（workflow command 渲染）

| # | Role | Output | Optional? |
|---|------|--------|-----------|
| 1 | analyst | analyze/<slug>.md | 是（小任务） |
| 2 | architect | design-docs/<slug>.md | 是（小任务跳过） |
| 3 | user | confirm 设计 | 是（无 design-doc 时跳过） |
| 4 | architect | exec-plans/active/<slug>.md | 否 |
| 5 | user | confirm 执行计划 | 否 |
| 6 | developer | src/ + tests/ + checkbox | 否 |
| 7 | tester | testing/<slug>.md | 是 |
| 8 | reviewer | reviews/<date>-<slug>.md | 是 |
| 9 | dba | reviews/<date>-db-<slug>.md | 是（仅 DB 改动） |

每次 phase transition 由 orchestrator re-emit 全表。状态：⏳ todo / 🔄 doing / ✅ done / ⏩ skipped。

## 5. 决策传递（subagent → 用户）

subagent 不直接调 AskUserQuestion（运行在独立上下文）。需决策时在返回文本里印一行：

```
[NEED-DECISION] <topic> | options: A) <…> B) <…> C) <…>
```

主会话（orchestrator）grep 关键字 → 调 AskUserQuestion → 把答案写入 exec-plan `## Change Log` → 重派同一 subagent 续做。

无 Monitor / 无 JSON schema / 无 escalation block —— subagent 完成后只返回简短 markdown 摘要。

## 6. SessionStart hook

bash 脚本，每次 session start / clear / compact 触发。流程：

1. 优先读 `ROUNDTABLE_DOCS_ROOT` 环境变量
2. 否则向上找最近的 `docs/` 或 `documentation/` 目录
3. 找不到 → 标 `status: needs-init`，让 command 启动时 AskUserQuestion 询问
4. 通过标准 SessionStart JSON 协议（`hookSpecificOutput.additionalContext`）注入会话——用户不可见，subagent 上下文可读

```
Roundtable context:
docs_root: /abs/path/to/docs
project_id: <slug>
status: ok
```

skill / agent / command 直接从注入上下文读取，**不再 inline 4 步检测**（这是 v0.0.5 重构相对 v0.0.4 的关键简化）。

## 7. 语言策略

- **plugin prompt 文件**（agents / skills / commands / hooks）：英文
- **用户产出文档**（docs/analyze/ 等）：由**项目自己的** CLAUDE.md 决定（如声明"文档中文"，subagent inheritance 会让 LLM 自动用中文输出）
- **plugin 模板里的 section 名**：英文（如 `## Background`, `## Solution`, `## Steps`），LLM 输出时按项目语言策略翻译

这让 plugin 对中英文项目都通用。

## 8. 关键决策

- **删除 decision-log.md / log.md / faq.md / progress JSONL / Monitor 全部辅助机制**：架构决策直接写进 exec-plan `## Key Decisions`，跟随该 exec-plan 一起从 `active/` 归档到 `completed/`；FAQ 直接追加到 analyze 或 design-doc 的 `## FAQ` 小节
- **删除 subagent / inline 双模式**：4 个 agent 全部按 subagent 派发；analyst / architect 因需要 AskUserQuestion 必须主会话，定为 skill
- **删除 decision_mode（modal/text）+ auto_mode 分支**：channel hook 自己处理远程渲染，skill 只调 AskUserQuestion
- **INDEX.md 由 lint 重建**：不每次新文档落盘都更新，降低 token 消耗

## 9. 与外部工具的边界

roundtable 提供"流程编排层"。其它两层可叠加但与 roundtable **不重叠** 才有价值：

- **superpowers**（auto-trigger 工程纪律）：建议装 `test-driven-development` / `systematic-debugging` / `verification-before-completion` 三个核心
- **gstack**（显式工具）：建议装 `/cso` / `/investigate` / `/codex` / `/careful` / `/guard`，UI 项目加 `/qa` / `/browse`

详见 docs/usage.md §与 superpowers / gstack 协同。

## 10. 风险 / 限制

- **subagent 无中间反馈**：长任务（30+ tool call）只能等返回；用户可中断但不可流式观察。如反馈迫切再加回 Monitor，但门槛是先在实战中证明缺失。
- **legacy 文档链接失效**：v0.0.4 老 docs 在 `docs/_archive/`，新工作不要再链到 `_archive/`。
- **不强制 RFC-style 评审**：design-doc 是 architect 单方产出 + 用户确认，没有多角色 review design-doc 的环节（reviewer 只 review 实现）。如需要可在 architect 之后补一道 reviewer 派发审 design-doc。

## 变更记录

- 2026-04-29 — 初版（post-rewrite v0.0.5-rc1）。基于 PR #118 + #119 的最终设计写就。
