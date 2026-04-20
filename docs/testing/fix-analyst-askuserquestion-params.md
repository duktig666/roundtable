---
slug: fix-analyst-askuserquestion-params
source: issue #25 + 修复 diff（skills/analyst/SKILL.md、skills/architect/SKILL.md）
created: 2026-04-20
---

# analyst/architect AskUserQuestion 参数修复 测试计划

## 背景

Issue #25：`/roundtable:analyst` 在识别到"任务范围过宽"后调 `AskUserQuestion`
收窄 scope，触发 `Invalid tool parameters`。根因是 skill prompt 示例使用了
旧的虚构 schema（`{label, rationale, tradeoff, recommended}` 顶层字段），与
Claude Code 真实 `AskUserQuestion` 工具 schema 不符。真实工具只接受
`{questions: [{header, question, multiSelect, options: [{label, description}]}]}`。

修复将 `skills/analyst/SKILL.md` 与 `skills/architect/SKILL.md` 的
`§ AskUserQuestion Option Schema` 章节从"伪 JSON 示例"改写为"真实 schema +
内部字段打包进 `description` 字符串"，并在两文件的 `decision_mode = modal`
分支描述中将 `AskUserQuestion(question, options)` 替换为
`AskUserQuestion({questions: [...]})`。

## 问题复现步骤（issue #25）

1. 主会话触发 `/roundtable:analyst`（analyst skill 加载）
2. 输入极宽任务：例 "分析当前 DEX 如果要进入生产阶段还需要做什么？"
3. analyst 完成 context detection 后判定 scope 过宽，选择用
   `AskUserQuestion` 收窄报告维度
4. 旧 prompt 示例误导 skill 构造 `AskUserQuestion({label, rationale,
   tradeoff, recommended})` 样形参数
5. Claude Code 工具层校验失败 → 返回 `Invalid tool parameters` → 流程中断

## schema 对比

### 旧（错误）schema — 修复前 prompt 示例

```
AskUserQuestion({
  label: "<short>",
  rationale: "<1-2 句>",
  tradeoff: "<key cost>",
  recommended: true
})
```

顶层字段 `label` / `rationale` / `tradeoff` / `recommended` 均非工具
schema 合法字段，**必定触发** `Invalid tool parameters`。

### 新（正确）schema — 修复后 prompt 示例

```
AskUserQuestion({
  questions: [{
    header: "<≤12 char>",
    question: "<1 句完整问题>",
    multiSelect: false,
    options: [
      {label: "<≤30 char>", description: "<打包 rationale+tradeoff+★ 的 1–3 句>"},
      ...
    ]
  }]
})
```

**内部字段打包约定**（skill 推理时维护，调工具时压成字符串）：

| 内部字段 | 来源 | 打包位置 |
|---------|------|---------|
| `label` | 选项名 | `options[].label` |
| `rationale` / `fact` | 理由 / 事实 | `options[].description` 句内 `Rationale:`/`Fact:` 前缀 |
| `tradeoff` | 客观成本 | `options[].description` 句内 `Tradeoff:` 前缀 |
| `recommended` | 最多 1 个（analyst 禁用） | `options[].description` 句首 `★ Recommended:` |
| `why_recommended` | 推荐理由 | 并入 `★ Recommended:` 句 |

打包后 `description` 字段形如：
- 非推荐：`"Rationale: <...>. Tradeoff: <...>."`
- 推荐：`"★ Recommended: <why>. Rationale: <...>. Tradeoff: <...>."`

## 验收场景（手动 dogfood 验收，非自动化）

以下 4 条均需人工在真实 Claude Code 会话里触发，观察 `AskUserQuestion` 是否
成功弹窗且不再报 `Invalid tool parameters`。

### 场景 A：analyst / modal 模式（issue #25 原场景）

**前置**：`ROUNDTABLE_DECISION_MODE` 未设或为 `modal`（默认）。

1. 触发 `/roundtable:analyst`
2. 给宽命题："分析当前 DEX 如果要进入生产阶段还需要做什么？"
3. 观察 analyst 应调 `AskUserQuestion({questions: [{header, question,
   multiSelect: false, options: [{label, description}, ...]}]})` 收窄维度

**通过条件**：
- Claude Code 正常弹窗，无 `Invalid tool parameters`
- 每个 option 只含 `label` + `description` 两个字段
- `description` 字段为字符串，含 `Fact:` / `Tradeoff:` 语义标签（analyst
  禁用 `★ Recommended`）
- `questions` 数组恰好 1 项

### 场景 B：analyst / text 模式（回归 DEC-013）

**前置**：`ROUNDTABLE_DECISION_MODE=text` 或 CLI 参数等效注入。

1. 触发 `/roundtable:analyst`
2. 同上宽命题

**通过条件**：
- analyst **不调** `AskUserQuestion` 工具
- 改 emit `<decision-needed id="...">` 文本块
- options 行格式 `<letter>：<label> — <fact> / <tradeoff>`
- 无 `★ 推荐` 标记（analyst 停事实层）
- emit 后 skill 停下等用户回复

### 场景 C：architect / modal 模式

**前置**：`ROUNDTABLE_DECISION_MODE` 默认 modal。

1. 触发 `/roundtable:architect`
2. 给需要选型的任务：例 "为 X 模块设计持久化层"
3. architect 在阶段 1 对存储层决策点弹窗

**通过条件**：
- 弹窗成功，无 `Invalid tool parameters`
- `questions[0].header` ≤ 12 字符
- 每个 option 只有 `label` + `description`
- 若有推荐，恰好 1 个 option 的 `description` 以 `★ Recommended:` 开头
- 选项内部互斥且在 scope 内

### 场景 D：architect / text 模式

**前置**：`ROUNDTABLE_DECISION_MODE=text`。

1. 同 C 任务

**通过条件**：
- architect 不调 `AskUserQuestion`
- emit `<decision-needed>`；options 行 `<letter>（★ 推荐）：<label> —
  <rationale> / <tradeoff>`
- 至多 1 个 option 带 `★ 推荐`
- 多决策串行 emit（一次一个），每次 emit 后 pause

## 对抗性分析

尝试构造能让修复后的 schema 仍然触发 `Invalid tool parameters` 的反例：

| 反例构造 | 是否能让新 prompt 触发错误 | 分析 |
|---------|--------------------------|------|
| prompt 示例被 LLM 照搬、多加一层 wrapper | ❌ | 修复后示例顶层就是 `{questions: [...]}`，照搬即合法 |
| LLM 把 `rationale` / `tradeoff` 误作顶层 option 字段 | ⚠️ 低概率 | 修复文案显式 "不要引入非 schema 字段" + 打包示例用字符串拼接，不给伪 JSON 诱导 |
| `multiSelect` 误传 string | ❌ | 示例写的 `multiSelect: false`（裸 boolean），无歧义 |
| `questions` 传单 object 非数组 | ⚠️ 低概率 | 示例以 `questions: [{...}]` 明示数组；文案两处都写 "`questions` 数组只 1 项" 强化数组语义 |
| `header` 超 12 字符 / `label` 超 30 字符 | ❌ | 长度约束是工具验证的软限，不会抛 `Invalid tool parameters`（最坏是截断或 warning） |
| 省略 `options` / `label` / `description` 必填字段 | ⚠️ 低概率 | 示例完整展示必填字段；但若 skill 匆忙构造仍可能漏 `description`，建议未来文档补"字段完整性 checklist" |

**结论**：修复显著收窄了 schema 偏差面，已覆盖 issue #25 根因。**未发现可以
击穿新 prompt 的反例**。剩余低概率风险项（`rationale` 顶层误写 /
`questions` 非数组 / 字段漏填）皆需在 LLM 严重忽略示例时才出现，属"阅读
理解"失败而非 prompt 设计漏洞。

## 回归扫描建议（lint 扩展）

未来为 `lint_cmd` 追加下列 pattern，在 `skills/` + `agents/` + `commands/`
目录扫描（docs/ 目录允许叙述性残留，不扫）：

```
# 裸 AskUserQuestion(question, options) 调用伪代码
grep -rnE 'AskUserQuestion\s*\(\s*question\s*[:,]' skills/ agents/ commands/

# 顶层伪字段（option 内部字段误升顶层）
grep -rnE '^\s*(rationale|tradeoff|why_recommended):\s' skills/ agents/ commands/
grep -rnE '^\s*recommended:\s*(true|false)' skills/ agents/ commands/

# questions 非数组（单 object 漏掉 [] 包装）
grep -rnE 'AskUserQuestion\s*\(\s*\{\s*questions:\s*\{' skills/ agents/ commands/
```

全部 0 命中方可合入。

## 已执行的静态回归检查结果（2026-04-20）

| 检查项 | 命中 | 结论 |
|--------|------|------|
| `AskUserQuestion(question[:,]` 裸调用（skills/agents/commands） | 0 | ✅ |
| 顶层 `rationale:` / `tradeoff:` / `recommended:` 字段（skills/agents/commands） | 0 | ✅ |
| `questions: {` 非数组 | 0 | ✅ |
| docs/ 残留 `AskUserQuestion(question, options)` 叙述 | 4（design-docs/decision-mode-switch.md × 2、testing/decision-mode-switch.md × 2） | ⚠️ 允许（设计文档对 modal 行为的叙述，合法） |

## 开放问题

- 真实 Claude Code `AskUserQuestion` schema 的 canonical 定义来源（本次修复
  参照 plugin host SDK 实际表现；若后续 Claude Code 升级扩展字段，需回头
  补测）
- 是否在 plugin host 层加一层 schema validator 在出错前给 hint（属优化
  议题，不阻塞本次修复）

## 变更记录

- 2026-04-20：初稿（tester 针对 issue #25 修复 inline 验证）
