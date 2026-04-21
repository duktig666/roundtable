---
slug: reviewer-write-harness-override
source: design-docs/reviewer-write-harness-override.md
created: 2026-04-21
completed: 2026-04-21
status: Completed
---

# reviewer-write-harness-override 执行计划

## 总览

| Phase | 标题 | 预估 | 前置 | 关键风险 |
|-------|------|------|------|---------|
| P0 | 3 agent prompt 落盘契约反转 | 30min | DEC-017 | Resource Access 列改错导致角色权限越位 |
| P1 | workflow.md Step 7 主路径化 | 20min | P0 | 触发条件表述失准 |
| P2 | testing/reviewer-write-permission.md 追加 post-fix 注记 | 10min | P1 | findings close 误判 |
| P3 | lint + dogfood 验证 | 15min | P2 | critical_modules 触发路径不通 |

## P0 3 agent prompt 落盘契约反转

### 目标

`agents/{reviewer,tester,dba}.md` §Resource Access + §输出落盘 整体重写为 relay 主路径协议。

### 任务清单

- [x] **reviewer.md**：Resource Access Write 列改为 `—`；§输出落盘整段重写为 "final message 完整报告由 orchestrator relay 落盘，见 commands/workflow.md §Step 7"；删除 "Write 权限明示 — 绝对优先" 段与 `Write {path} denied by runtime` sentinel 语句
- [x] **tester.md**：Resource Access Write 列保留 `tests/*`，移除 `{docs_root}/testing/[slug].md` 条目；§输出落盘同款重写；保留对抗测试模板正文
- [x] **dba.md**：Resource Access Write 列改为 `—`；§输出落盘同款重写；保留 Schema/SQL/Migration 审查正文
- [x] **统一措辞**：三文件用同款"relay 落盘说明段"模板，引用 `commands/workflow.md §Step 7` 作为权威出处

### 成功信号

- 三文件 §Resource Access Write 列符合 DEC-017 决定 3
- 三文件 §输出落盘整段不再含 "Write 权限明示" / "绝对优先" / "denied by runtime" 字样
- lint_cmd `grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/` 0 命中

### 风险与预案

- **Write 列改错可能让 reviewer 无法 Read lint 命令**：仅改 Write 列，Read 列不动；明示 `lint_cmd` 执行权限保留
- **sentinel 删除引发 orchestrator parse 错误**：Step 7 同步改（P1），两侧同步更新

## P1 workflow.md Step 7 主路径化

### 目标

`commands/workflow.md` §Step 7 末段 `Orchestrator 兜底 Write` 升主路径。

### 任务清单

- [x] 标题 `**Orchestrator 兜底 Write**` → `**Orchestrator Relay Write（主路径）**`
- [x] 触发条件重写：从 "subagent 声称 `Write <path> denied by runtime` 或直接返回对话不落盘" 改为 "reviewer/tester/dba 命中 critical_modules OR Critical finding OR 用户要求归档"
- [x] sub-bullet 1（Content 源）：保留，措辞调整为 "subagent final message 正文 = 报告主体，orchestrator 补 frontmatter"
- [x] sub-bullet 2（log_entries 归因）：`note` 末尾 `(orchestrator relay due to subagent Write failure)` → `(orchestrator relay)`；文件失败归因删除
- [x] sub-bullet 3（INDEX.md description fallback）：保留，改从 `## 总结` 首句提取
- [x] sub-bullet 4（不兜底）：更新为 "非 critical_modules 且无 Critical finding → subagent 对话返回即可，orchestrator 不 relay"

### 成功信号

- Step 7 末段读起来像"主路径 contract"而非"边界 case 兜底"
- 触发条件与 DEC-017 决定 2 一字对齐
- 无残留 `Write <path> denied by runtime` 引用

### 风险与预案

- **既有 "兜底" 术语在其他 prompt 文件被引用**：grep `兜底 Write` / `Orchestrator 兜底` 全仓库核对，统一替换或加括号备注

## P2 testing/reviewer-write-permission.md 追加 post-fix 注记

### 目标

在现有 testing 文档尾部追加 §post-fix 2026-04-21 close F1/F2/F3 findings。

### 任务清单

- [x] 底部 §变更记录 追加条目：`2026-04-21 post-fix（DEC-017 relay 主路径化）：F1 LLM 偏差抗性 / F2 denial 信号格式 / F3 双通道 三项 findings 事实消解（subagent 不 Write 即无 denial 事件 / 无 sentinel / 无双通道）`
- [x] §对抗清单回响表对应行改 `🟡 Warning` → `✅ resolved (DEC-017)`

### 成功信号

- F1/F2/F3 标为 resolved
- §变更记录追加一行指向 DEC-017

### 风险与预案

- 无

## P3 lint + dogfood 验证

### 目标

lint 0 命中 + 本会话 Stage 5/6/7（developer/tester/reviewer）实跑一次验证 relay 主路径。

### 任务清单

- [x] 执行 `grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/` → 0 输出
- [x] 附加 lint：`grep -nE "Write 权限明示|denied by runtime|绝对优先" agents/ commands/ -r` → 0 输出（developer 本轮已清）
- [x] 本 workflow Stage 6 tester 派发时观察：tester subagent 不尝试 Write，final message 完整 testing 报告，orchestrator relay 落盘 `docs/testing/reviewer-write-harness-override.md` ✅ E1 dogfood 验证通过 (tester tool calls: Read/Grep/Bash only, Write=0)
- [x] 本 workflow Stage 7 reviewer 派发时观察：reviewer subagent 不尝试 Write，final message 完整 review 报告（critical_modules 命中），orchestrator relay 落盘 `docs/reviews/2026-04-21-reviewer-write-harness-override.md` ✅ E2 dogfood 验证通过 (reviewer tool calls: Read/Grep/Bash only, Write=0)
- [x] 记录 relay 成功率：tester + reviewer **2/2 dogfood 通过**，DEC-017 relay 主路径契约生效

### 成功信号

- relay 2/2 成功（tester + reviewer）
- 落盘文件 frontmatter / body 结构与 DEC-017 §2.2 一致
- Step 8 log.md flush 后 `log_entries` 含 `(orchestrator relay)` 注

### 风险与预案

- **subagent 仍尝试 Write 说明 prompt 改动未触达 LLM 决策逻辑**：检查 Resource Access Write 列是否确实清空；若清空仍 Write → 可能 runtime 缓存 prompt，需 `/reload-plugins`

## 变更记录

- 2026-04-21：初版，issue #59 方向 C 实施计划
