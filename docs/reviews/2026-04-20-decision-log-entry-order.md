# 审查：DEC-011 decision-log 条目顺序约定传导

- **日期**: 2026-04-20
- **审查者**: reviewer（roundtable plugin, subagent）
- **范围**: issue #18 / DEC-011 实施（5 文件：`skills/architect/SKILL.md` + `docs/claude-md-template.md` + `docs/decision-log.md` + `docs/design-docs/decision-log-entry-order.md` + `docs/INDEX.md`）
- **结果**: **Approve with 1 Warning**（0 Critical / 1 Warning / 3 Suggestion）
- **触发归档**: 命中 `critical_modules` 首条（`skills/architect/SKILL.md` prompt 本体）

## Critical

（无）

## Warning

### W-01 锚点规则对"仅 Minimal header 无 DEC"状态缺 fallback 条款

- **位置**: `skills/architect/SKILL.md:171`
- **现状**: 新增小节仅声明 "锚点 = 第一个 `### DEC-` 行；在其之前插入新条目"
- **问题**: "仅 header 无 DEC" 状态下无锚点可定位；architect 严格按 SKILL.md 执行时首次写入 DEC-001 会卡
- **对照**: design-doc `docs/design-docs/decision-log-entry-order.md:§2` 表有完整 3 状态分支，但 SKILL.md（architect 运行时规则的权威源）只有一条硬规则
- **建议**: 在 L171 同 bullet 内加一句："若文件仅含 Minimal header 无 DEC 条目，新 DEC 追加于 `---` 分隔符之后"

## Suggestion

### S-01 初始化触发条件表述不完全对齐

- **位置**: `skills/architect/SKILL.md:19` 与 `:59`
- **现状**: 两处均表述为"文件不存在时先写 Minimal header"
- **对照**: 同文件 L172（§新增小节）与 `docs/design-docs/decision-log-entry-order.md:§2` 均用"不存在或为空"
- **建议**: L19 / L59 括号内改为"文件不存在或为空时先写 Minimal header"

### S-02 §完成后 首个 bullet 可独立可读性

- **位置**: `skills/architect/SKILL.md:165`
- **现状**: 使用间接引用 "遵循下面 'decision-log 条目顺序约定'"
- **对照**: L19 / L59 均直接内嵌 "置顶 / 最新在前" 关键短语
- **建议**: L165 括号内首位加 "置顶 / 最新在前；" 前缀，让该 bullet 独立可读不强依赖下文

### S-03 DEC-011 条目内引用的 SKILL.md 行号是 PR 前快照

- **位置**: `docs/decision-log.md:85`
- **现状**: "L19 Resource Access / L59 §阶段 2 第 8 步 / L165 §完成后" 引用的是 PR 落地前的行号
- **说明**: PR merge 后行号会略变（+12 行）；DEC 条目是历史快照属于正常，无需改
- **建议**: 无 action；仅备注

## 决策一致性

- **DEC-002**（Resource Access 权限声明 / architect 是 decision-log 唯一 Writer）：一致。DEC-011 决定 7 显式 honor
- **DEC-006**（phase gating taxonomy）：一致。不涉及
- **DEC-009 决定 10**（新 DEC 影响范围 ≤ 10 行）：一致。DEC-011 影响范围段 7 行
- **DEC-010**（revert helper 抽取 / inline 精简）：一致。无新 helper 引入
- **roundtable 自家 decision-log L4 约定**（新条目追加顶部）：已传导到目标项目规则层
- **DEC-011 自身 dogfood**：一致。L80 置顶（DEC-010 L104 之前），`---` 分隔符正确

## Positive

- ✅ Minimal header 模板结构合法（H1 + 2 行 blockquote + `---`），与 roundtable 自家 L1-L4 的核心"顺序约定"声明对齐（roundtable 自家多一行"记录 X 项目所有关键设计和技术决策"是项目专有描述，Minimal 合理裁剪）
- ✅ DEC-011 六段齐全、备选 5 条拒绝理由充分
- ✅ template L46 与 L47 语义对称（"新条目置顶，最新在前" vs "append-only，顶部最新"）
- ✅ lint 0 命中（`grep -rnE "gleanforge|dex-sui|dex-ui|\bvault/|\bllm/" skills/ agents/ commands/` 全部 no matches）
- ✅ DEC-011 dogfood 闭环（自身置顶，自我践约）
- ✅ 4 处 SKILL.md 修订点（L19 / L59 / L165 / §新增小节）语义一致，共同承载同一条约束

## 总结

**可合并**。核心语义正确、改动面小、dogfood 自闭环、与既有 DEC 无冲突。

合并前**建议**处理 W-01（1 行补丁，消除 architect 首次写 DEC-001 的 runbook 歧义）。S-01 / S-02 属可读性优化，可随 W-01 一起 ship，也可后续 lightweight follow-up。

