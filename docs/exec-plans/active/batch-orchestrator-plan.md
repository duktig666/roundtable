---
slug: batch-orchestrator
source: design-docs/batch-orchestrator.md
created: 2026-04-20
status: Active
---

# Batch Orchestrator 执行计划

## 总览

| Phase | 标题 | 预估 | 前置 | 关键风险 |
|-------|------|------|------|---------|
| P0 | 骨架 + 单 issue smoke | 0.5d | DEC-016 confirm | general-purpose subagent 能否承载 inline workflow 未验证 |
| P1 | Architect skill 批改（inline_only + batch_mode 分支）| 0.3d | P0 | critical_modules 命中需 P3 tester 验证 |
| P2 | Conflict pre-check + 分组串行 | 0.5d | P0 | 正则误差 / Union-Find 边界 |
| P3 | DEC 占位符 + fan-in 重编号 | 0.5d | P0 + P1 | sed 替换范围 / sanity grep |
| P4 | 失败隔离 + 汇总报告 + TG 转发 | 0.5d | P0 | TG 消息长度 / 三层嵌套转发 |
| P5 | Dogfood E2E + tester（critical）| 0.7d | P0-P4 | rate limit / worktree 堆积 / Q7 unknown 实测 |

**总预估**：~3d。

**跨阶段约束**：
- **不改** 4 agent prompt / analyst skill / workflow.md / bugfix.md / lint.md 本体 / target CLAUDE.md
- **critical_modules 命中**：`skills/architect.md` 修改 → P5 必须派 tester
- **lint**：`grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/` 0 命中
- **DEC Supersede**：无（batch 是 append 层，不覆盖已 Accepted DEC）

## P0 骨架 + 单 issue smoke

### 目标

最小可运行 `/roundtable:batch #N` 单 issue 形态：fan-out 1 个 `general-purpose` subagent with `isolation:worktree` + `run_in_background:true`，子 agent 跑 inline analyst+architect 产出 design + DEC-NEW 占位 + draft PR。

### 任务清单

- [ ] 新建 `commands/batch.md`（骨架 + Step 0~7 占位）
- [ ] 实现 Step 0 argparse（`#N` / `--concurrency` / `--dry-run`）
- [ ] 实现 Step 1 context detection（inline Read `${CLAUDE_PLUGIN_ROOT}/skills/_detect-project-context.md`）
- [ ] 实现 Step 2 prefetch（`gh issue view <N> --json body,number,title`）
- [ ] 实现 Step 5 单 Agent dispatch（general-purpose / worktree / bg / prompt per §2.8）
- [ ] 实现 Step 5 Monitor 启动（复用 workflow.md §3.5 机制，单 dispatch_id）
- [ ] 实现 Step 6 单子 agent final message parse（PR URL + DEC-NEW uuid 提取）
- [ ] 实现 Step 7 最小汇总（1 条 PR URL）

### 成功信号

- `/roundtable:batch #23`（独立 issue）成功派 1 个子 agent
- 子 agent 产出 `docs/analyze/[slug].md` + `docs/design-docs/[slug].md` + `docs/exec-plans/active/[slug]-plan.md` + `decision-log.md` 顶部 `DEC-NEW-<uuid>` 条目
- git commit + push + gh pr create --draft 成功，返回 PR URL
- 主会话 fan-in 解析 final message 成功，输出 "✅ #23 → <PR-URL>"

### 风险与预案

- **subagents cannot spawn** 硬约束：子 agent 内 workflow 若误触 Agent tool 会失败 → 子 agent prompt 明确禁用 + architect skill `inline_only` 分支守约束
- **general-purpose 不继承 skills / plugin commands 在 worktree 的可用性未验证** → P0 第一步做最小 smoke（子 agent prompt inline 执行 `Read analyst.md + Read architect.md` 而非依赖 skill 激活）；若激活可用则简化 v2
- **worktree 路径获取**：Claude Code Agent 返回 final message 是否带 worktree path + branch —— P0 验证，失败则 `git worktree list` 扫描对比

## P1 Architect skill 批改

### 目标

architect skill 支持 orchestrator 注入的 `inline_only` / `batch_mode` 两个条件分支。

### 任务清单

- [ ] 读 `skills/architect.md` §3.5 Research Fan-out 段，加 `inline_only: true` 禁 DEC-003 fan-out 分支（~5 行）
- [ ] 读 §decision-log 条目顺序约定段，加 `batch_mode: true` 用 `DEC-NEW-$(openssl rand -hex 4)` 占位符分支（~5 行）
- [ ] 不改其他规则 / 不改 `skills/analyst.md` / 不改 4 agent
- [ ] 本地 smoke：主会话模式跑 `/roundtable:workflow <minor issue>` 验证不注入 flag 时行为不变（regression）
- [ ] 子 agent 模式 smoke：注入 `inline_only: true`，architect 跑设计不派 research subagent

### 成功信号

- `skills/architect.md` diff ≤15 行新增
- 主会话 regression 通过（无 flag 时 DEC-003 fan-out 正常 + DEC 递增正常）
- batch 子 agent 模式下 architect 跑完不派 Task + 写的 DEC ID 是 `DEC-NEW-<8 hex>`

### 风险与预案

- **critical_modules 命中**（`skills/architect.md`）：P5 强制派 tester 验证所有分支
- **条件分支复杂度累积**：若未来 v2 再加分支，需评估是否抽 helper；v1 严格 inline 分支（≤15 行）对齐 DEC-010 精简

## P2 Conflict pre-check + 分组串行

### 目标

多 issue 场景：扫 body → Union-Find 分组 → 组内串行 + 组间并行。

### 任务清单

- [ ] Step 3 正则抽取：`\bDEC-\d+\b` / `(?:skills|agents|commands)/[\w-]+\.md` / `docs/design-docs/[\w-]+\.md`（扩粒度）
- [ ] Union-Find 实现（Bash 难；用 `python3 -c "..."` inline）
- [ ] Step 4 plan emit：表格呈现"组 / 组内 issue / 并发占用 / 预估耗时"
- [ ] Step 5 调度器：FIFO + 组约束（同组 1 running，其他排队；组间按 --concurrency 并发）
- [ ] 多 Agent single-message 并行 dispatch 实测
- [ ] Monitor 多 dispatch_id 交织（DEC-004 §3.5 已符合）
- [ ] （可选）`--no-preheck` flag 强制全并行

### 成功信号

- `/roundtable:batch #A #B #C` 其中 #A/#B 共享 `DEC-005` token → 分 2 组：{A,B} 串 / {C} 独
- 实际派发：#A done → #B start；#C 与 #A 同时 start
- 终端 Monitor 输出 3 个 dispatch_id 交织可读

### 风险与预案

- **Bash 实现 Union-Find 难** → 用 `python3 -c` 内嵌
- **正则假阳**（body 引用但不改）→ 文档诚实标注 + `--no-preheck` 兜底
- **Plan emit 在 auto_mode=true 下仍需 producer-pause？** → batch 命令本身默认 **manual**（用户要求"不是 auto"），`--auto-plan` 可覆盖（v2）

## P3 DEC 占位符 + fan-in 重编号

### 目标

主会话 fan-in 阶段按完成时序把 `DEC-NEW-<uuid>` 重编号为连续整数。

### 任务清单

- [ ] Step 6 final message parse：提取 DEC-NEW uuid 列表 + worktree path
- [ ] `current_max = max(...)` 读主 branch `decision-log.md`
- [ ] 按完成时序 sort 子 agent
- [ ] sed 替换跨多文件类型（`decision-log.md` / `design-docs/*.md` / `exec-plans/**/*.md` / `log.md` / `INDEX.md` / `testing/*.md` / `reviews/*.md` / `bugfixes/*.md`）
- [ ] sanity `grep -r "DEC-NEW-[a-f0-9]{8}" <worktree>/docs/` 必须 0 命中
- [ ] PR body 追加 "DEC renumber map" section
- [ ] 重编号失败（sanity 非 0）→ 该 subagent 终态降级 🔴 #5（Crash），worktree 保留
- [ ] 单 issue workflow 路径行为不变回归测试

### 成功信号

- 两 batch 子 agent 各加 1 DEC；fan-in 后主 branch decision-log 置顶 `DEC-017` + `DEC-018`
- 所有 cross-ref 同步更新（`design-docs/*.md` frontmatter `decisions:` 字段 / `log.md` fix-rootcause entry 等）
- sanity grep 0 命中
- 单 issue workflow 仍走 MAX+1 递增

### 风险与预案

- **sed 假阳性替换**（UUID 巧合在代码示例）→ 严格正则 `\bDEC-NEW-[a-f0-9]{8}\b`
- **漏文件类型** → sanity grep 捕获
- **重编号中断**（sed 跑一半挂了）→ sanity fail 终态 🔴 #5 + worktree 保留供人工

## P4 失败隔离 + 汇总报告 + TG 转发

### 目标

收集 8 类终态，汇总 markdown 输出 + TG 转发。

### 任务清单

- [ ] Step 6 final-message 分类器（8 类：正则匹配 PR URL / `<decision-needed>` / `🔴 auto-halt` / tester `<escalation>` / lint/test fail / Crash / 中断 / 429）
- [ ] Step 7 汇总 markdown 渲染（按 ✅→🟡→🔴 排序；每 🟡/🔴 附 worktree path）
- [ ] Step 7 TG 转发（#48 未实施时本命令内嵌显式 reply 调用）
- [ ] 长消息分段（>4096 char → 多条 TG reply）
- [ ] DEC renumber map section 附加到 TG 汇总

### 成功信号

3 issue batch 中 2 success / 1 🟡（recommended 缺失 + decision-pending）→ 最终报告完整 3 类清单 + worktree 可达 + TG 收到。

### 风险与预案

- **TG 消息长度** → 分段；汇总 summary ≤1000 char，详情在 PR body
- **三层嵌套转发**：子 agent `<decision-needed>` 不会自动 TG 转发（§3.6） → 主会话 fan-in 后统一转发
- **#48 未实施的手动转发耦合** → 明确标记（注释 / 文档）"#48 实施后可移除"

## P5 Dogfood E2E + tester（critical_modules 触发）

### 目标

roundtable repo 自身跑 `/roundtable:batch #A #B #C` 验证端到端；派 tester 覆盖 architect skill 修改（critical_modules 命中）。

### 任务清单

- [ ] 选 3 个独立 low-risk issue 作 smoke（analyst §3.10 建议 {#23, #20, #27}，虽非 design-only 场景但可测 batch 机制）
- [ ] 或选 design-only 适合的 issue（暂无，可新建 P3 micro-issue 做 smoke）
- [ ] 派 `tester` subagent 覆盖 `skills/architect.md` 2 条件分支（critical_modules 命中）
  - 测：无 flag 场景 regression
  - 测：`inline_only=true` 禁 DEC-003 fan-out
  - 测：`batch_mode=true` 用 DEC-NEW 占位
- [ ] 测 batch_worker prompt 的 subagents-cannot-spawn 约束在实际 subagent 中是否如预期
- [ ] 记录 Q7 unknown 实测结果（bg subagent text pause 终态、CLAUDE.md 继承、MCP 继承、maxTurns 默认）→ 回填 design-doc §7 待确认项
- [ ] 补 `docs/testing/batch-orchestrator.md`（tester 专属）
- [ ] 观察 Monitor 交织输出；记录 UX 痛点

### 成功信号

- 3 issue batch 并行成功（或识别真实 conflict 串行化）
- PR URL 齐全 + DEC 重编号正确 + TG 汇总可读
- tester regression 无红
- Q7 unknown 至少 3/4 项有实测数据回填

### 风险与预案

- **API rate limit 429** → `--concurrency 2` 保守；观察 headers
- **worktree 堆积占盘** → test 完 `git worktree prune`
- **design-only 场景无适合 issue** → 新建 P3 micro-issue 或用 dry-run + mock 子 agent 替代

## 变更记录

| 日期 | 版本 | 变更 | 作者 |
|------|------|------|------|
| 2026-04-20 | v1 | 初版 P0-P5；加 P1 architect skill 批改独立阶段；P5 critical_modules tester 触发 | architect |
