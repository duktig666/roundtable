---
slug: faq-sink-protocol
source: 原创（issue #27）
created: 2026-04-21
status: Draft
decisions: []
---

# FAQ 沉淀协议 设计文档

## 1. 背景与目标

### 1.1 背景

issue #27（P2 bug）：用户在 roundtable session 直接问系统机制（如"orchestrator 是什么？机制说明下"），orchestrator 当场完整回答但**未沉淀**到 FAQ。每次新会话需重新解释；知识无法积累。

### 1.2 目标

1. orchestrator 在回答**机制类 / 概念类 / 决策类**问题后，**自动追加** Q&A 到 `{docs_root}/faq.md`
2. 在回复末尾显式告知用户"已追加到 `docs/faq.md`"
3. 新会话通过 `{docs_root}/faq.md` 复用积累的知识（类似 CLAUDE.md 加载后作为 context）

### 1.3 非目标

- 不沉淀：用户项目代码 debug / 特定错误定位 / 一次性对话
- 不改 analyst 的 `## FAQ` section 机制（analyst slug 级 FAQ 与本 global FAQ 互补，不合并）
- 不改 design-docs 的 `## 5. 讨论 FAQ`（slug 级，同样互补）
- 不自动 load `{docs_root}/faq.md` 到 session（避免大量历史 FAQ 污染每次 session context；用户可手动 `/roundtable:workflow 参考 docs/faq.md: Q xxx` 显式引用）

## 2. 关键决策与权衡

### 2.1 D1：FAQ 落点

**选择**：**`{docs_root}/faq.md`**（target 项目根目录级）

备选：
- `docs/faq.md`（plugin 仓库级）—— 不可取：对 target 项目无用
- analyst / architect slug 级 `## FAQ` 扩展 —— 对非 slug 绑定问题无位置
- target `CLAUDE.md` 扩 FAQ section —— 污染 CLAUDE.md，违反"只写多角色工作流配置"边界

### 2.2 D2：触发判定

**选择**：orchestrator **启发式 + 白名单**触发

- **触发**：提问涉及 plugin 机制 / Phase Matrix / DEC / auto_mode / decision_mode / escalation / workflow stage / Resource Access / critical_modules / roundtable 术语
- **不触发**：target 项目代码 debug、一次性错误定位、用户自身偏好讨论、纯闲聊
- 用户显式命令 `加入 FAQ` / `沉淀到 FAQ` → 强制触发（覆盖启发式）
- 用户显式 `别沉淀` / `skip FAQ` → 强制跳过

### 2.3 D3：Q&A 格式

```markdown
## Q: <用户原问，≤80 字符简化>

**提问于**：2026-04-21 session
**类别**：[roundtable 机制 | Phase Matrix | DEC-013 | auto_mode | ...]

<orchestrator 回答，≤500 字；超长引 `docs/design-docs/...` 路径>

---
```

### 2.4 D4：去重（Bag-of-words Jaccard）

orchestrator 追加前 `Read` `{docs_root}/faq.md`（若存在），按 `commands/workflow.md` Step 0.5 去重算法：Q 标题 lowercase + `[\s\p{P}]+` split + bag-of-words Jaccard 相似度 `|A∩B| / |A∪B|` ≥ 0.7 → 判重不追加，回复末尾 ref 已有 § 锚点。同义词（中英 / 缩略）不在简化算法范围，follow-up 词典。

## 3. 技术实现

### 3.1 `commands/workflow.md` 顶部新增 Step 0.2: FAQ Sink Protocol

```
## Step 0.2: FAQ Sink Protocol（issue #27）

用户直接提问（非 `<escalation>` / 非 A 类菜单 `问:` / 非 skill 阶段调研）涉及 roundtable 机制 / Phase Matrix / DEC / auto_mode / decision_mode / escalation / workflow stage / Resource Access / critical_modules / 术语时，orchestrator 回答后**自动追加** Q&A 到 `{docs_root}/faq.md`（不存在则创建含 minimal header：`# <project> FAQ\n\n> 机制 / 概念 / 决策类问答沉淀。slug 级 FAQ 在各 analyst/design-docs ## FAQ 段。\n\n---\n`）。

**Sink 条件**（白名单触发；用户命令可覆盖）：
- 提问关键词命中 roundtable 术语 / plugin 机制 / DEC / 阶段名
- 用户显式 `加入 FAQ` / `沉淀到 FAQ` → 强制沉淀
- 用户显式 `别沉淀` / `skip FAQ` → 跳过

**Sink 不触发**：target 项目代码 debug / 一次性错误 / 用户偏好讨论 / 闲聊。

**去重**：追加前 Read 已有 faq.md，≥70% 词重叠的 Q 不重复追加，改在回复末尾 ref 已有 § 锚点。

**条目格式**：
```
## Q: <简化问题 ≤80 字符>
**提问于**：YYYY-MM-DD session
**类别**：[roundtable 机制 | Phase Matrix | DEC-xxx | ...]

<answer ≤500 字；超长引 docs/...>

---
```

**回复末尾标注**：Sink 触发 → 加一行 `📚 已追加到 {docs_root}/faq.md § Q: <简化标题>`；去重命中 → `📚 已有相关条目见 {docs_root}/faq.md § Q: <锚点>`。

**`log_entries:` 上报**：orchestrator 自造 `prefix: faq-sink` / `slug: faq-sink` / `files: [{docs_root}/faq.md]` / `note: Q-<简化> sunk`（新前缀 `faq-sink` 追加到 `docs/log.md` §前缀规范；正文以 `commands/workflow.md` Step 0.5 为权威）。
```

### 3.2 `commands/bugfix.md` 继承

bugfix.md Step -1 末尾加 1 行 ref：`**FAQ sink**：沿用 workflow.md Step 0.2`。

### 3.3 落点清单

| 文件 | 改动 |
|------|------|
| `commands/workflow.md` | 新增 Step 0.2 FAQ Sink Protocol（~15 行） |
| `commands/bugfix.md` | Step -1 末尾 +1 行 ref |
| `docs/design-docs/faq-sink-protocol.md` | 新建本文件 |
| `docs/faq.md` | 新建 minimal header（首轮 dogfood 时被 sink 填充） |
| `docs/INDEX.md` / `docs/log.md` | 同步 |

**不改**：5 agent / 2 skill（FAQ sink 纯 orchestrator 动作）/ DEC / target CLAUDE.md 边界。

## 4. 影响范围

- 运行时：TG/terminal session 提问 roundtable 机制类问题后，orchestrator 多 1 次 Edit faq.md，延迟 ~1s
- 与 DEC-006 §A producer-pause `问: ...`：不冲突 —— A 类 `问:` 是 phase-end menu 子选项（skill 回派回答 + FAQ 追加到 analyst slug 级 FAQ），本协议是 **非 A 类 menu 的** 直接提问

## 5. 测试策略

| 场景 | 期望 |
|------|------|
| 用户问 "orchestrator 是什么" | 回答 + sink 到 `docs/faq.md` + 回复末尾 📚 |
| 用户问 "我这段代码 bug 在哪" | 回答 + **不** sink |
| 用户重复问已在 FAQ 的机制问题 | 回答 + 去重命中提示 |
| 用户 `加入 FAQ` 显式命令 | 强制 sink 即使启发式未命中 |
| 用户 `skip FAQ` 显式命令 | 跳过 |
| `{docs_root}/faq.md` 不存在 | orchestrator 创建 minimal header + 追加 |
| bugfix session 同款问题 | 沿用 workflow Step 0.2 行为 |

## 6. 变更记录

- 2026-04-21 初版（issue #27，Draft）
- 2026-04-21 post-fix（tester F1 High + F2 High + F3/F4/F5/F6 Medium 合并 inline）：
  - F1（70% dedupe 算法）：明示 Jaccard bag-of-words，token 按 `[\s\p{P}]+` split，中英混合同款
  - F2（`<project>` 填充）：orchestrator 用 `basename(target_project)` 填充
  - F3（A 类 menu 裸问）：Step 0.2 优先，机制类裸问走 global FAQ sink + 回 menu，不进 `问:` 循环
  - F4（log prefix）：新增 `faq-sink` 前缀到 `docs/log.md` §前缀规范
  - F5（命令识别）：大小写不敏感 + `skip` vs `add` 冲突时 `skip` 胜
  - F6（白名单漂移）：中文通用词（机制 / 流程 / 阶段 / 决策 / 工作流）**必须与 roundtable 专有术语同句共现**才触发
  - F7-F11 Low 归 follow-up（design-doc §3.3 `{docs_root}` vs `docs` 已在 §3.3 原文就用 `{docs_root}`，F7 属 tester 读错 / GFM slug link / 并发锁 / TG 转发 / faq.md 归档策略）
