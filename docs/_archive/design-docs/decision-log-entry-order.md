---
slug: decision-log-entry-order
source: 原创（issue #18）
created: 2026-04-20
status: Accepted
decisions: [DEC-011]
---

# decision-log 条目顺序约定传导 设计文档

## 1. 背景与目标

### 背景

roundtable 自家 `docs/decision-log.md` L4 声明：

> 新条目追加在顶部（最新在前）。

但该约定**未传导到被 architect 写入的目标项目** `decision-log.md`。某目标项目（memo CLI demo）走 `/roundtable:workflow` 后呈现为 DEC-001 在上、DEC-002 在下的**升序**（与约定相反）。

### 根因

1. `skills/architect/SKILL.md` 的 Resource Access（L19）与 §阶段 2 第 8 步（L59）、§完成后（L165）只说"追加 `decision-log.md`（DEC-xxx 编号递增）"，未规定**追加位置**
2. `docs/claude-md-template.md:46` 只说"追加 DEC-xxx，不删旧条目"，与 L47 `log.md（append-only，顶部最新）` 的"顶部最新"**不对称**
3. 目标项目首次由 architect 创建的 `decision-log.md` 无 header 声明约定，architect 默认走 Edit/Write 追加到文件末尾

### 目标

1. 在 `skills/architect/SKILL.md` 明确 DEC 追加**置于文件顶部**（紧跟 H1 + meta 引言之后、第一个 `### DEC-` 条目之前）
2. `docs/claude-md-template.md` §文档约定 补一句"新条目置顶，最新在前"，与 `log.md` 行对称
3. architect 首次创建目标项目 `decision-log.md` 时写入 **Minimal header**（3 行：title + "新条目追加在顶部（最新在前）" + "本文件是项目知识的权威来源。"），把约定固化到文件自身

### 非目标

- 不改已有用户项目既有 DEC 条目顺序（用户可自行 reorder 或保持现状）
- 不改 roundtable 自身 `docs/decision-log.md`（它本就合规）
- 不引入"完整 meta section"（条目格式表 / 状态说明 / 铁律表）—— 避免每个目标项目都重复 ~36 行模板

## 2. 业务逻辑

### 写入流程（architect 角度）

```
architect 决定写新 DEC-xxx
  ├─ target decision-log.md 存在？
  │   ├─ 是 → 定位第一个 `### DEC-` 行 → 在其之前插入新 DEC（含 `\n---\n\n` 分隔符）
  │   └─ 否 → 先写 Minimal header（3 行）+ `\n---\n\n` → 再写第一个 DEC
  └─ 已 Accepted DEC 原文不改
```

### Minimal header 模板

```markdown
# <项目名> 决策日志

> 新条目追加在顶部（最新在前）。
> 本文件是项目知识的权威来源。

---
```

### 插入锚点规则（Anchor）

通用锚点：**第一个 `### DEC-` 行**。这个锚点在 3 种状态下都能定位：

| 文件状态 | 锚点行为 |
|---------|---------|
| 空文件 / 不存在 | 无 `### DEC-`，按 "否" 分支走 header 初始化 |
| 仅 Minimal header（DEC-001 还没写） | 无 `### DEC-`，先写第一个 DEC（header 下面）|
| 已有 N 个 DEC | 第一个 `### DEC-` 即最新的，在其之前插入新 DEC |

## 3. 技术实现

### 改动清单

| 文件 | 改动 | 行数 |
|------|------|------|
| `skills/architect/SKILL.md` | L19 Resource Access Write 行 + L59 §阶段 2 第 8 步 + L165 §完成后 —— 各自后面补"（置顶 / 最新在前；无文件则先写 Minimal header）"；在 §完成后 新增一小节 "decision-log 条目顺序约定" 详述 Minimal header 模板与锚点规则 | +12 行 |
| `docs/claude-md-template.md` | L46 补"新条目置顶，最新在前" | +1 字段 |
| `docs/decision-log.md`（本项目 dogfood）| 追加 DEC-011 **置顶**（DEC-010 之前） | +1 条目 |

**不改**：

- 5 个 agent prompt（不触碰 decision-log）
- `commands/workflow.md` / `commands/bugfix.md`（不直写 decision-log）
- 其他 skill（analyst / 等）
- `CLAUDE.md` §critical_modules / §条件触发规则（本约定属 architect 内部规则，不抬到业务规则层）

### SKILL.md §完成后 新增小节草稿

```markdown
### decision-log 条目顺序约定

- **位置**：新 DEC 置于**顶部**（最新在前）。锚点 = 目标文件第一个 `### DEC-` 行；在其之前插入新条目（含 `\n---\n\n` 分隔符）
- **初始化**：若目标 `{docs_root}/decision-log.md` 不存在，先写 Minimal header 再写第一个 DEC：

  ```markdown
  # <项目名> 决策日志

  > 新条目追加在顶部（最新在前）。
  > 本文件是项目知识的权威来源。

  ---
  ```

- **不回溯**：已有用户项目既有 DEC 顺序保持不动；本约定仅影响新写入
```

## 4. 关键决策与权衡

### 决策 1：Header 策略 = Minimal（3 行引言）

| 维度 (0-10) | Minimal ★ | Full (~36 行) | No header |
|------------|-----------|---------------|-----------|
| 用户一眼可见约定 | **9** | 9 | 2 |
| 目标项目 meta 开销 | **9** | 4 | 10 |
| 与 roundtable 自家一致性 | 7 | **10** | 5 |
| 未来手改违约风险 | **8** | 8 | 3 |
| 实施复杂度 | **9** | 7 | 10 |
| 维护成本（规则漂移） | **9** | 6 | 8 |
| **合计** | **51** | 44 | 38 |

- **选择**：Minimal
- **理由**：成本最低、直接解决 issue #18 根因 3（目标项目 decision-log 无约定 header），不把 roundtable 自家 meta 抬到每个目标项目
- **备选拒绝**：
  - **Full**：每个目标项目都复制 ~36 行模板开销；目标项目维护者可能认为 meta 过厚
  - **No header**：目标项目用户打开 decision-log 看不到约定声明；未来手改（非 architect 路径）容易违约

### 决策 2：插入锚点 = "第一个 `### DEC-` 行"

- **选择**：用"第一个 `### DEC-` 行"作通用锚点，在其之前插入
- **备选**：
  - 固定偏移（如"第 6 行之后"）：脆弱，header 行数变动即破
  - 显式 sentinel 注释（`<!-- new DEC goes below this line -->`）：引入新约定成本；本项目 dogfood 文件也要改
- **理由**："第一个 `### DEC-` 行"对所有状态（空/仅 header/已有 N 条）都能定位，规则单一无边界情况

## 5. 变更记录

- 2026-04-20：初稿（issue #18）
