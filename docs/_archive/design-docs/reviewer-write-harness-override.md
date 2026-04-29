---
slug: reviewer-write-harness-override
source: issue #59
created: 2026-04-21
status: Draft
decisions: [DEC-017]
---

# Reviewer/Tester/DBA 落盘契约反转：orchestrator relay 升主路径

## 1. 背景与目标

### 1.1 问题

`agents/{reviewer,tester,dba}.md` §输出落盘声明了"Write 权限明示 — 绝对优先"段，期望压过 Claude Code subagent runtime 的通用 system prompt（`Do NOT Write report/summary/findings/analysis .md files`）。实测失败：

| # | 场景 | 结果 |
|---|------|------|
| 1 | issue #27 FAQ sink dogfood | reviewer 未落盘，orchestrator Step 7 兜底代写 |
| 2 | issue #23 fix 自审 | 同上 |
| 3 | issue #28 DEC-016 dogfood | reviewer final message 明示 "harness-level override ... This is explicit and overrides"，未落盘 |

PR #53 的 prompt-layer 加强措辞（"absolute precedence"）无法压过 Claude Code base system prompt。

### 1.2 目标

- 消除 reviewer/tester/dba 的 Write 失败模式
- Step 7 "orchestrator 兜底 Write" 从边界 case 提升为主路径
- 简化 3 agent prompt 的落盘段（去掉已失效的"绝对优先"措辞和 denial sentinel 协议）
- DEC-006 §critical_modules 命中 → 必落盘契约仍成立，但"落盘执行者"改为 orchestrator

### 1.3 非目标

- 不改 DEC-006 Phase Gating A/B/C 三分
- 不改 critical_modules 触发机制
- 不改 Write artifact 的内容模板（仍 `## Critical / Warning / Suggestion / 总结`）
- 不触碰 architect/analyst/developer skill 的 Write 路径（这些角色的 Write 实测正常）

## 2. 核心设计

### 2.1 契约反转

| 层 | 旧（DEC-006 默认 / PR #53 增强） | 新（本 DEC-017） |
|---|---|---|
| reviewer subagent 职责 | 尝试 Write `{docs_root}/reviews/...`，失败则 emit sentinel | **不尝试 Write**；完整报告放 final message |
| tester subagent 职责 | 同上，路径 `{docs_root}/testing/...` | 同上 |
| dba subagent 职责 | 同上，路径 `{docs_root}/reviews/...-db-...` | 同上 |
| orchestrator Step 7 | **兜底**代写（当 subagent 声称 Write denied 或未落盘） | **主路径**代写（critical_modules 命中 / Critical findings 触发时必代写） |
| Resource Access Write 列 | `{docs_root}/reviews/...` / `{docs_root}/testing/...` | **移除** reviewer/tester/dba Write 列（仅保留 tester 的 `tests/*` 代码路径） |

### 2.2 Final message 契约

reviewer/tester/dba 在 final message 按现有模板输出完整报告（`## Critical / Warning / Suggestion / 总结`），不带 frontmatter。orchestrator 按下列规则落盘：

| 字段 | orchestrator 填充来源 |
|------|----------------------|
| path | reviewer: `{docs_root}/reviews/[YYYY-MM-DD]-[slug].md`<br>tester: `{docs_root}/testing/[slug].md`<br>dba: `{docs_root}/reviews/[YYYY-MM-DD]-db-[slug].md` |
| frontmatter `slug` / `source` / `created` / `reviewer` | orchestrator 已知注入变量 |
| body | subagent final message 去除工具调用 / 进度行 / `log_entries:` / `<escalation>` 之外的正文 |
| `created:` YAML | orchestrator 自造（path + description = 报告 `## 总结` 首句） |
| `log_entries:` YAML | orchestrator 自造，`prefix: review` / `test-plan` / `review`，`note` 末尾 `(orchestrator relay)` |

### 2.3 触发条件保持不变

sub-agent final message 出现下列任一情况，orchestrator 走 relay 主路径：

1. 命中 `critical_modules`（CLAUDE.md 声明的关键词）
2. 发现 🔴 Critical finding（严重度标记）
3. 用户派发 prompt 明示要求归档

其他场景仍是"对话返回 + 不落盘"（DEC-006 §reviewer 默认不落盘纪律保留）。

### 2.4 sentinel 协议废除

`Write {path} denied by runtime` 字符串协议整段删除。subagent 既然不 Write，就没有 denial 事件可上报。

## 3. 变更面

### 3.1 agent prompt 改动（prompt 本体 = critical_modules 命中）

| 文件 | 改动 |
|------|------|
| `agents/reviewer.md` | §Resource Access Write 列改为 `—`（不再含 `{docs_root}/reviews/...`）；§输出落盘整段重写：去掉"Write 权限明示 — 绝对优先"+ denial sentinel；改为"final message 完整报告由 orchestrator relay 落盘，见 commands/workflow.md §Step 7" |
| `agents/tester.md` | §Resource Access Write 列保留 `tests/*`，移除 `{docs_root}/testing/[slug].md`；§输出落盘同款重写 |
| `agents/dba.md` | §Resource Access Write 列改为 `—`；§输出落盘同款重写 |

### 3.2 workflow.md 改动

`commands/workflow.md` §Step 7 末段：
- 标题 `Orchestrator 兜底 Write` → `Orchestrator Relay Write`（主路径）
- 触发条件从"subagent 声称 Write denied"改为"critical_modules 命中 OR Critical finding OR 用户要求归档"
- 4 sub-bullet 保持结构但精简：content 源 / log_entries 归因 / INDEX description / 不触发场景

### 3.3 decision-log 改动

追加 DEC-017（置顶）：本 pivot 决策 + Refines DEC-006（非 Superseded —— DEC-006 Phase Gating 仍完整有效，只是"落盘执行者"在 reviewer/tester/dba 链收归 orchestrator）。

### 3.4 docs/testing/reviewer-write-permission.md

老 testing 报告（issue #23 fix 时产出）里的 F1/F2/F3 findings（LLM 偏差抗性 / denial 信号 / 双通道）本 DEC 落地后**事实上消解**：subagent 不 Write 就没有 denial、没有稳定性问题、没有 sentinel vs escalation 双通道。追加一段 §post-fix 2026-04-21 注记 close 这些 findings。

## 4. 关键决策与权衡

量化评分见 §4.1。核心权衡：

- **心智负担**：relay 主路径让 orchestrator 承担更多逻辑（代写 + 自造 log_entries + 自造 created）。但 Step 7 兜底 contract 已经存在并 3/3 工作，主路径化等于把 edge case 收编为 happy path，整体复杂度**下降**（删除 denial sentinel / 移除 prompt 层"绝对优先"失效措辞）。
- **reviewer/tester/dba 失去 Write 授权**：表面像"降权"，实际是把"错误配置的权限"撤掉。PR #53 的 Write 授权在 runtime 下就是无效的，保留只是文档和实现不符。
- **与 DEC-006 的关系**：DEC-006 §4 "critical_modules 机械触发归 C" 和 §5 "reviewer 完成归 C" 都只规定 phase gating 类别，不规定"subagent 必须自己 Write"。本 DEC 是实现契约细化，非 Supersede。

### 4.1 量化评分

| 维度 (0-10) | A Prompt 加强 | B Harness frontmatter | **C Relay 主路径 ★** | D Status quo |
|---|---|---|---|---|
| 实际可行性（已验证） | 2（3 次失败） | 3（未验证支持） | **10**（3/3 已工作） | 8（事实上 work） |
| 文档与实现一致性 | 4 | 6 | **9** | 3 |
| 心智负担 | 5 | 4 | **8**（去冗余） | 6 |
| 改动面 | 6 | 2 | **6** | 10 |
| 未来可演进性 | 5 | 7 | **8** | 4 |
| 审计可追溯 | 5 | 5 | **9**（log_entries 统一 relay 注） | 4 |
| **合计** | 27 | 27 | **50** | 35 |

## 5. 讨论 FAQ

### Q1: reviewer/tester/dba 失去 Write 授权后，如果用户手工派发时要求"归档本次对话"怎么办？

走 relay 主路径。subagent final message 里响应用户归档请求，orchestrator 识别用户请求或 subagent 的 `archive_request: true` 信号并代写。触发路径同 Critical finding。

### Q2: orchestrator 代写失败（文件系统权限问题）怎么办？

orchestrator 是主会话，Write 工具在主会话 runtime 下无"Do NOT Write report/..." 基 prompt 限制（实测 architect/analyst/developer 都能正常 Write）。残余风险是 filesystem 层权限，走常规 error handling 路径（final message 报告用户 + 保留 subagent final message 原文供人工落盘）。

### Q3: 本 pivot 是否意味着以后所有 subagent 都不能 Write 归档类 .md？

否。本 pivot 仅作用于 reviewer/tester/dba 的 `{docs_root}/reviews/` 和 `{docs_root}/testing/` 归档路径。tester 的 `tests/*` 代码路径、developer 的 `src/*` + `tests/*`、architect/analyst skill 的 `{docs_root}/design-docs/` 等路径不变（实测正常）。边界在"subagent 落盘 .md 报告"这一场景。

### Q4: DEC-006 §critical_modules 必落盘契约现在由谁保证？

仍由 orchestrator Step 7 保证。critical_modules 命中是 orchestrator 在 C 类 handoff 时已知的事实（CLAUDE.md 预授权 + subagent final message 返回），orchestrator 自行判定是否触发 relay 主路径。subagent 层面无需再声明落盘义务。

### Q5: 为什么不直接让 reviewer/tester/dba 改成 skill（主会话形态）？

skill 主会话形态会撑爆 context（DEC-005 已禁止 tester/reviewer/dba 扩展 inline 形态）。relay 主路径保留 subagent 隔离优势，只改"落盘执行者"。

## 6. 变更记录

- 2026-04-21：初版，issue #59 修复方向 C 落地

## 7. 待确认项

- 无（决策已单轮闭合；implementation 交 developer）
