---
slug: tg-forwarding-expansion
source: 原创（issue #48）
created: 2026-04-21
status: Draft
decisions: [DEC-013 §3.1a append-only clarification]
---

# DEC-013 §3.1a Active Channel Forwarding 事件范围扩展 设计文档

## 1. 背景与目标

### 1.1 背景

DEC-013 §3.1a（2026-04-20 post-fix，issue #38）把 `<decision-needed>` 块强制转发到 active inbound channel（TG/CI），解决 modal 阻塞。但 §3.1a 明确限定：

> 只在 emit `<decision-needed>` 时触发，普通对话 / phase summary / FAQ 不在本规则范围（out of scope，另议）

2026-04-20 issue #43 auto-mode 跑 architect，设计全程在终端，TG 用户完全不知在跑什么 / 是否完成 / 设计是什么。用户反馈「又没回复我」。

**核心 UX 断层**：TG 驱动 `/roundtable:workflow` 下以下事件对用户完全不可见 ——

1. **A 类 producer-pause summary**（analyst / architect / Stage 9 Closeout）—— 用户 `go` / `调` / `停` 的唯一信息源
2. **Role completion final report**（developer / tester / reviewer / dba）—— 产出清单 + findings
3. **C 类 phase transition handoff**（`🔄 X 完成 → dispatching Y`）—— 阶段交接实时进度
4. **auto_mode audit trail**（`🟢 auto-go` / `🟢 auto-accept` / `🟢 auto-pick` / `🔴 auto-halt`）—— 事后追溯
5. **Step 0 context detection + size judgment summary** —— 开场确认

本 issue 扩展 §3.1a 转发语义到「用户参与 / 知情必需」事件类，scope 与 #38 正交，不 supersede。

### 1.2 目标

- 以 orchestrator inline 规则扩展 §3.1a，新增 5 类事件强制 channel 转发
- **零 agent / skill prompt 改动**，沿用 DEC-013 决定 8「展现与接收解耦」边界
- 转发节流（避免 TG 刷屏）
- DEC-013 §3.1a 的 `<decision-needed>` 转发行为不变（两类规则并存）

### 1.3 非目标

- 不改 DEC-013 决定 8 —— 仍是 orchestrator 侧检测 channel tag，不硬编码前端
- 不动 4 agent prompt（沿用 DEC-013 最小改动面 + DEC-009 log.md batching 同款最小触及）
- 不抬 target CLAUDE.md —— 事件类转发是 orchestrator 内部策略
- 不做跨 plugin 通用转发抽象（YAGNI）
- 不扩 §3.1a 到普通对话 / FAQ / 调试输出（显式划界，避免刷屏）

## 2. 关键决策与权衡

### 2.1 D1：落点范围 —— orchestrator-only vs 4 文件

**选择**：**orchestrator-only**（`commands/workflow.md` + `commands/bugfix.md`）

**备选**：

| 方案 | 描述 | 评分 |
|------|------|------|
| **A. orchestrator-only ★** | 只改 2 orchestrator 文件；skill prompt 零改动 | **46** |
| B. 4 文件（issue 原文） | workflow + bugfix + architect + analyst 各加 forwarding 段 | 33 |

**理由**：5 个新事件类**全部是 orchestrator-emitted**：
- (a) context summary → orchestrator inline Step 0
- (b) producer-pause 3 行模板 → orchestrator 在 skill 返回后框定
- (c) role completion digest → orchestrator 读取 subagent final message 并数字化
- (d) C 类 🔄 handoff → orchestrator verification-chain 自动推进点
- (e) auto_mode audit trail → orchestrator §Auto-pick 规则触发点

architect.md / analyst.md 的现 §3.1a forwarding 规则仍只管 skill 自身 emit 的 `<decision-needed>` 块（skill-emitted 事件），与新 5 类正交。因此 skill prompt **无需改动**。

量化评分（0-10）：

| 维度 | A ★ | B |
|------|-----|---|
| 改动最小 | 9 | 5 |
| critical_modules 触及面 | 8 | 5 |
| 架构一致性（§3.1a 决定 8） | 10 | 7 |
| 可测试性 | 9 | 8 |
| 维护成本 | 10 | 8 |
| **合计** | **46** | **33** |

### 2.2 D2：DEC 处理方式 —— append-only clarification

**选择**：**append-only clarification to DEC-013**（不新开 DEC）

**理由**：
- issue #48 body 显式要求「不新开 DEC（append-only clarification）」
- 先例：2026-04-20 §3.1a 本身（issue #38）即以 post-fix append-only 方式落入 DEC-013 决定 8 下
- 不改 DEC-013 任何 Accepted 决定；只在「影响范围」段 post-fix 2026-04-21 追加一段
- DEC-013 决定 8 边界不动：转发仍是 orchestrator 内部动作，不硬编码前端

### 2.3 D3：节流、digest 长度与 TG 可读性

**选择**：按 issue 默认 + **TG 可读性增强**（2026-04-21 用户反馈 message_id=428「这种文本 tg 阅读效果较差」）

- **C 类 handoff**（d）：单行，`markdownv2` 粗体主语 + 代码字段，如 `🔄 *architect* 完成 → 派发 *developer* \(critical\_modules hit: \`workflow Phase Matrix\`\)`
- **Role completion digest**（c）：orchestrator 自行生成 ≤200 字 digest；`markdownv2` 结构化 —— 粗体标题行 + bullet 产出清单（每行 1 个路径 + 1 句描述）+ 可选 findings 块；超长引 `docs/...` 路径不转发全文（TG Bot API 上限 4096 字符，防御性留余量）
- **auto_mode audit**（e）：单行，`🟢`/`🔴` emoji + 粗体事件类型 + `(why: ...)` 尾注
- **A 类 producer-pause summary**（b）：3 行模板；**标题行粗体** + 产出路径用反引号包裹 + 操作 `go` / `调` / `问` / `停` 用反引号标记
- **Step 0 context summary**（a）：结构化块放 ``` 代码围栏内零转义（key\: value 格式）；Step 1 size + slug 同块内 `---` 分隔

**统一原则**：纯 YAML / 纯键值表 → 代码围栏；混合 prose + 字段 → markdownv2 结构化（粗体 / 反引号 / bullet）。遵守 memory `feedback_tg_reply_format` + `feedback_tg_decision_needed_codeblock`。

### 2.4 D4：auto_mode audit 全 4 事件转发

**选择**：全转发（`auto-go` / `auto-accept` / `auto-pick` / `auto-halt`）

**理由**：用户 TG-driven workflow 下对 auto_mode 决策完全不可见；事后需追溯「为什么走了 A 分支而非 B」。4 事件逐一转发成本低，价值高。

## 3. 技术实现

### 3.1 Forwarding 规则扩展（§3.1a 之外新增一段）

`commands/workflow.md` Step 5/6 相关段 + Step -0（auto_mode 注入）+ Step 0（context）+ Step 3（phase gating）追加统一 forwarding 段：

```
**Phase & audit forwarding（DEC-013 §3.1a 扩展，issue #48）**：
若 session inbound prompt 含 `<channel source="...">` 标签，或该 channel reply 工具在本 session 内曾被调用过（sticky 语义，与 §3.1a 同），orchestrator 必须同步调该 channel reply 工具转发以下事件（与 `<decision-needed>` 转发规则并存）：

(a) Step 0 context detection 结果块 + Step 1 size judgment 一行
(b) A 类 producer-pause 3 行 summary（`✅ <role> 完成。产出：... 请阅读后告诉我：go / 调 / 问 / 停`）
(c) Role completion final report ≤200 字 digest（orchestrator 从 subagent final message 提取产出清单 + 关键 findings；超长引 `docs/...` 路径）
(d) C 类 verification-chain 交接一行（`🔄 X 完成 → dispatching Y (critical_modules hit: [...])`）
(e) auto_mode audit 4 事件（`🟢 auto-go` / `🟢 auto-accept` / `🟢 auto-pick` / `🔴 auto-halt`）

**不转发**：普通对话 / FAQ / 调试输出 / 子 agent 内部工具调用 echo / 用户无决策价值的内部状态

**格式**（用户反馈增强 2026-04-21）：遵守 memory `feedback_tg_decision_needed_codeblock` + `feedback_tg_reply_format`：
- 纯 YAML / 纯键值表（Step 0 context / audit 多行批量）→ ``` 代码围栏零转义
- 混合 prose + 字段（A 类 summary / C handoff / role digest / 单行 audit）→ `markdownv2` 结构化（粗体标题 / 反引号路径 / bullet 清单）
- 目的：避免 TG 纯文本阅读效果差（issue #48 TG session message_id=428 反馈）

纯终端 session（无 channel tag）→ 不调 reply，行为同现状。
```

### 3.2 落点清单

| 文件 | 改动 |
|------|------|
| `commands/workflow.md` | Step 5 现 §3.1a forwarding 注释追加指向本扩展段；新增「Phase & audit forwarding」小节（~15 行）置于 Step 6 之前 |
| `commands/bugfix.md` | 已 ref `workflow.md` 的 forwarding 规则；追加 1 行 ref 扩展段即可 |
| `docs/decision-log.md` | DEC-013 影响范围段末尾 post-fix 2026-04-21（issue #48）追加 ~3 行 |
| `docs/INDEX.md` | design-docs/ 新增本文件条目 |

**不改**：
- `skills/architect/SKILL.md` / `skills/analyst/SKILL.md`（skill-emitted `<decision-needed>` 已由 §3.1a 覆盖）
- 4 agent prompt（developer / tester / reviewer / dba）—— role completion digest 由 orchestrator 侧生成，不需 agent prompt 改动
- DEC-013 任何 Accepted 决定
- target CLAUDE.md 业务规则边界

### 3.3 Sticky Channel 语义（复用 §3.1a）

`<channel source="...">` 一旦在本 session 检测到 OR reply 工具被调用过 → 所有后续 5 类事件强制转发，不按轮次衰减。纯终端 session 从未触发。

### 3.4 与现有转发规则关系

| 事件 | 规则归属 | 触发点 |
|------|---------|--------|
| `<decision-needed>` block | DEC-013 §3.1a（现行） | Step 5 Escalation / skill in-phase 决策 |
| 5 新类（context / producer-pause / role digest / C handoff / auto audit） | 本扩展 | Step 0 / A 类 gate / 角色返回 / C 类 transition / auto_mode §Auto-pick |
| 普通对话 / FAQ / 调试 echo | **不转发** | —— |

两类规则**并存不冲突**：`<decision-needed>` 独立强制转发；5 新类独立强制转发；普通 text 默认不转发。

## 4. 影响文件清单

新建：
- `docs/design-docs/tg-forwarding-expansion.md`（本文件）

修改：
- `commands/workflow.md`（+~18 行：Phase & audit forwarding 小节）
- `commands/bugfix.md`（+~2 行：ref）
- `docs/decision-log.md`（DEC-013 影响范围段末尾 post-fix 追加 ~3 行）
- `docs/INDEX.md`（design-docs + 本条）
- `docs/log.md`（Step 8 flush by orchestrator）

**不改**：skills/ * 、agents/ *、CLAUDE.md、DEC-013 任何 Accepted 决定、Phase Matrix、Step 4 并行判定树、critical_modules 机械触发、Option Schema、Progress Event schema。

## 5. 测试策略

按 issue 验收 6 + 2 项 + 回归：

| 场景 | 期望 |
|------|------|
| TG-driven + architect 完成 | TG 收到 producer-pause 3 行 summary |
| TG-driven + auto_mode=on | TG 收到 `🟢 auto-go` / `🟢 auto-accept` / `🟢 auto-pick` 4 事件 |
| TG-driven + auto_mode + halt | TG 收到 `🔴 auto-halt: no recommended option at <id>` |
| TG-driven + developer/tester/reviewer 完成 | TG 收到 ≤200 字 digest |
| 纯终端 session | 无 reply 调用；行为同现状 |
| 普通对话 / FAQ / 调试 | **不**触发 forwarding |
| `<decision-needed>` 块（§3.1a） | 行为不变（继续转发） |
| C 类 handoff 🔄 | TG 收到一行 |

### 5.1 critical_modules 命中

- `commands/workflow.md` —— Phase Matrix 邻近区域改动
- Escalation Protocol（含 §3.1a 文本结构）—— 格式改错会让所有下游 `/roundtable:workflow` 调用行为漂移

→ tester 必触发。

## 6. 变更记录

- 2026-04-21 初版（issue #48，Draft）

## 7. 待确认项

无阻塞项；auto_mode 下全决策已 auto-pick recommended。
