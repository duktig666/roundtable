---
slug: case-study-rewrite
created: 2026-04-29
status: reference
---

# 案例研究：用 roundtable 重构 roundtable 自己

这是一个真实的双轨制 dogfood 案例：用 roundtable 自带的工作流，重构 roundtable plugin 本身。展示了 plugin 生成的 design-doc + exec-plan 在实战中长什么样，以及为什么"最初的设计经常需要在第二轮调整"——双轨制就是为这种 lifecycle mismatch 准备的。

## 1. 问题陈述（背景）

v0.0.4 的 roundtable plugin 已经积累严重 token 浪费与跨文件重复样板：

- `agents/` 5 个 + `skills/` 2 个 + `commands/` 3 个 = **2200+ 行 prompt**
- `decision-log.md` 882 行、`log.md` 766 行、`workflow.md` 567 行
- 每个 agent 都重复 Execution Form / Resource Access / Escalation / Progress 四套表
- 双模式（subagent / inline）+ 双决策模式（modal / text）+ 双 FAQ 路径，复杂度叠加
- design-doc / decision-log / log / faq / INDEX **五重文档机制**相互引用

目标：抛掉历史包袱，按"最少代码解决问题"基线重写，token 用量下降 ≥60%。

## 2. 第一轮设计（PR #118）— 激进简化

经 architect skill 做了 13 项决策（每项 `AskUserQuestion` 弹窗用户确认），第一轮重写的关键决策：

| # | 决策 | 理由 |
|---|------|------|
| 1 | analyst/architect = skill（主会话）；developer/tester/reviewer/dba = subagent（独立上下文）| skill 需要 AskUserQuestion；subagent 隔离长任务上下文 |
| 2 | 删除 `decision-log.md` 机制 | 决策直接写进对应 exec-plan，跟随归档 |
| 3 | 删除 `log.md` / `faq.md`；`INDEX.md` 改由 lint 重建 | 减少跨文件维护负担 |
| 4 | SessionStart hook 注入 `docs_root` | 取代每个 command 内联的 4 步检测 |
| 5 | 取消 subagent / inline 双模式；4 个 agent 全 subagent | 减少切换逻辑 |
| 6 | 取消 progress / escalation JSON schema | subagent 返回文本里印 `[NEED-DECISION]` 即可 |
| 7 | **整个删除 `design-docs/` 机制** | architect 一份 exec-plan 含设计 + 步骤 |

第一轮成果：

| 项 | v0.0.4 | v0.0.5 第一轮 | Δ |
|---|---|---|---|
| agents 总行数 | 676 | 199 | **-71%** |
| skills | 414 | 168 | **-59%** |
| commands | 882 | 241 | **-73%** |
| **总 prompt+config** | **~2200** | **~793** | **-64%** |

## 3. dogfood 暴露的问题（PR #119）— 双轨制纠偏

第一轮 merge 后的实际使用暴露一个问题：

> "design-doc 和 exec-plan 拆分的好处是方案和计划隔离，方案还要不断调整，确认好方案后再写计划会更好，减少频繁改动项。合在一起文件少。哪个更好？"

观察到的 lifecycle mismatch：

- **design 是讨论态** —— 频繁被推翻 / 重审 / 因新发现而修改
- **exec-plan 是执行态** —— 一旦写就稳定，主要变化是勾 checkbox

强行合一份文件 = 两种 lifecycle 混进同一 git diff，每次改方案 plan 跟着抖，diff 噪声大且语义不清。

第二轮决策（PR #119）—— **双轨制**：

| 任务规模 | 产出 | 用户 gate 数 |
|---------|------|--------------|
| small（bug fix / 单文件 / UI 微调） | 单文件 exec-plan，含 `## Solution` 小节 | 1 |
| medium / large（新功能 / 模块变更） | design-doc → 用户确认 → exec-plan → 用户确认 | 2 |

跨文件契约：exec-plan frontmatter `source: design-docs/<slug>.md` 链回设计文档。

**还顺手做了 i18n 修正**：plugin prompt 不再硬编码中文 section 名，输出语言交给项目 CLAUDE.md 决定（声明 `文档中文` → LLM 自动翻译）。

## 4. 最终成果

5 个 PR、6 个 commit 落地：

| PR | 主题 |
|---|------|
| #118 | 激进简化（agents 重写 / skills 重写 / commands 重写 / docs 归档 / CLAUDE.md slim） |
| #119 | 双轨制 + 语言无关 |
| #120 | `.gitkeep` 清理 |
| #121 | 文档刷新（架构总览 / usage / READMEs） |

最终代码体量：

```
agents/         199 行（4 个 subagent）
skills/         168 行（analyst + architect）
commands/       241 行（workflow + bugfix + lint）
hooks/           59 行（session-start）
CLAUDE.md        42 行
docs/usage.md   154 行
docs/roundtable.md 139 行
README.md       133 行
README-zh.md    133 行
```

总 prompt+config 约 800 行（vs 旧 2200+ = -64%）。

## 5. 经验教训

1. **第一轮经常过度简化** —— 砍东西容易，恢复要付二次成本。重要机制（如双轨制）的删除决策应当用更高门槛，宁可保留再观察一轮。
2. **lifecycle mismatch 是拆分的硬理由** —— 任何"讨论态 + 执行态"混在同一 artifact 都会出问题。这种拆分不是 ceremony，是去除 git diff 噪声。
3. **plugin 必须 language-neutral** —— 输出语言由项目 CLAUDE.md 决定，plugin 自身不该硬编码。
4. **dogfood 是必要的** —— 重构后立刻在实际项目里跑过一轮，才能发现"理论上简化了但实际不好用"的边界。
5. **`AskUserQuestion` 的批量化值得做** —— 单决策弹窗体验好，但同轮 ≥2 个独立决策应批量减少打断（见 architect SKILL §workflow §4）。

## 6. 复用价值

类似的 plugin / framework / 内部工具重构都可参考这套方法：

- **第一轮**：由 architect skill 主导，激进简化（删一切可由 CLAUDE.md / project config 表达的规则）
- **dogfood 1-2 周**：用真实任务跑，记录摩擦点
- **第二轮**：把摩擦点修回（不一定恢复全量）；引入"门槛"概念决定何时回退简化

不要担心"反复"，反复本身就是 architect 流程的一部分（exec-plan `## Change Log` 就是干这个的）。
