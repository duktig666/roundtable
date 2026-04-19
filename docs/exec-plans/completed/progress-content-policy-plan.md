---
slug: progress-content-policy
source: design-docs/progress-content-policy.md
created: 2026-04-19
completed: 2026-04-19
status: Completed
decisions: [DEC-007]
---

# Progress Content Policy 执行计划

> 展开 `design-docs/progress-content-policy.md`；patchy scope，单 P0 完成。

## 总览

| Phase | 标题 | 预估 | 前置 | 关键风险 |
|-------|------|------|------|----------|
| P0.1 | 新建共享 policy helper | 15 min | DEC-007 | 正文质量 & 命名前缀约定清晰度 |
| P0.2 | 4 agent Progress Reporting 引用 | 20 min | P0.1 | 4 份措辞一致、位置一致 |
| P0.3 | workflow.md jq pipeline awk collapse | 10 min | — | awk 状态机语义正确 |
| P0.4 | lint_cmd + dogfood 小烟雾 | 15 min | P0.1-P0.3 | 无 |

## 跨阶段约束

- `target_project/CLAUDE.md` 的「# 多角色工作流配置」声明 `critical_modules` 命中 **"Skill / agent / command prompt 文件本体"** 和 **"Progress event JSON schema (DEC-004)"**。本 plan 强触发 tester + reviewer（由 orchestrator 处理）。
- 所有修改保持 DEC-004 event schema 原样——本 policy 是纯内容层补丁。
- `_progress-content-policy.md` 的下划线前缀约定是 plugin 隐私契约；若未来要把该前缀语义写进 CLAUDE.md 视为 DEC-001 D2 扩展（本 plan 不包含）。

## P0.1 新建共享 policy helper

### 目标

创建 `skills/_progress-content-policy.md`，内含 DEC-007 §1-5 的完整 policy 规范（代理节拍 / 去重 / 差异化内容 / 终止-失败语义 / 反例对照），作为 4 agent Progress Reporting 的 single source of truth。

### 任务清单

- [x] 创建 `skills/_progress-content-policy.md`
- [x] frontmatter: `name: _progress-content-policy` + `description` 注明 include-only 性质
- [x] 正文章节：§1 代理节拍、§2 连续去重、§3 差异化内容、§4 终止-失败信号、§5 反例/正例对照（至少 3 对）
- [x] 引用 DEC-004 §3.1–3.2（event schema 正文不重复）与 DEC-002（escalation 通道）
- [x] 正文保持 ≤ 2 KB（紧凑、可被 4 agent 快速 Read）

### 成功信号

- 文件存在，frontmatter 合法
- 正文含 4 个 policy 规则 + 反例示例
- 不重复 DEC-004 JSON schema 字段定义

### 风险与预案

- **风险**: 正文质量不足导致 4 agent 引用后仍有歧义 → **预案**: P0.4 dogfood 时以刷屏回归为验收信号

## P0.2 4 agent Progress Reporting 引用

### 目标

在 `developer.md` / `tester.md` / `reviewer.md` / `dba.md` 的 Progress Reporting section 末尾（Emit rules 之后、Fallback 之前）各加 `### Content Policy` 子节，一行引用共享 helper + 本角色特化的 1-2 个示例 summary。

### 任务清单

- [x] `agents/developer.md` 的 `## Progress Reporting` section 加 `### Content Policy` 子节
- [x] `agents/tester.md` 同上（示例用 `running case-fuzz 3/12` / `benchmark baseline captured` 等）
- [x] `agents/reviewer.md` 同上（示例用 `reviewing auth-module 2/5 files` / `critical finding drafted` 等）
- [x] `agents/dba.md` 同上（示例用 `analyzing migration 0042 locking` / `schema diff captured` 等）
- [x] 4 处 Content Policy 子节措辞与位置一致（orchestrator diff 4 文件应看到对称改动）

### 成功信号

- `grep -rn "Content Policy" agents/` 返回 4 行
- 每个 agent 的 Progress Reporting section 结构顺序为：intro → Emit rules → Content Policy → Fallback → Relation to Escalation → Refs
- lint_cmd `grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/` 仍 0 命中

### 风险与预案

- **风险**: 4 份引用漂移（措辞不一致） → **预案**: 引用 template 从 design-docs §3.3 copy，4 处完全相同
- **风险**: Content Policy 子节位置错放 → **预案**: 明确定位"Emit rules 之后、Fallback 之前"，加 section anchor check

## P0.3 workflow.md jq pipeline awk collapse

### 目标

修改 `commands/workflow.md` Step 3.5.3 的 Monitor 启动命令，在 jq 之后追加 awk 连续相同行折叠。

### 任务清单

- [x] 定位 `commands/workflow.md` Step 3.5.3 jq pipeline 原文
- [x] 替换为 design-docs §3.4 给出的 `... | awk 'BEGIN{last="";n=0} ...'` 版本
- [x] 在 pipeline 注释里补一句"awk 层仅折叠**连续**相同行（非全局 uniq）；防止源端刷屏回归"
- [x] `commands/bugfix.md` 若有同款 pipeline，同步改（本轮检查确认）

### 成功信号

- pipeline 文本与 design-docs §3.4 一致
- 注释解释清楚"连续而非全局"的语义
- lint_cmd 0 命中

### 风险与预案

- **风险**: awk BEGIN/END 语义写错导致最后一行不 flush → **预案**: P0.4 dogfood 时验证最后一条 phase_complete 必须出现
- **风险**: `bugfix.md` 有同款 pipeline 未同步 → **预案**: P0.3 实施前 `grep -rn "tail -F" commands/` 扫全

## P0.4 lint_cmd + dogfood 小烟雾

### 目标

跑一轮最小验证：lint_cmd 0 命中；触发一次子 dispatch 观察 Monitor 输出不再刷屏。

### 任务清单

- [x] 跑 `grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/` 确认 0 命中
- [x] 构造或复用一个小规模 developer dispatch（可用 roundtable 自身的 /roundtable:bugfix 做小改动）
- [x] 观察主会话 Monitor 流：每条 summary 应含子步骤 / 分数 / 里程碑之一；无连续相同 summary
- [x] 若源端失守（相同 summary 连发）验证 awk 层正确折叠为 `... x3`

### 成功信号

- lint_cmd 返回 0 匹配
- Monitor 流可读连贯，无重复刷屏
- awk collapse 正确触发

### 风险与预案

- **风险**: dogfood 中 agent 仍刷屏，说明 policy 正文不够明确 → **预案**: 回到 P0.1 改 `_progress-content-policy.md` 并重新 P0.2 同步
- **风险**: awk 没触发折叠（可能 LLM 自律到位了） → **预案**: 构造人为测试—在 `/tmp/roundtable-progress/` 手工 echo 两行相同 JSON 观察 awk 输出；如果懒得做，视为 edge case 留给后续 issue

## 变更记录

- 2026-04-19 创建 Active
