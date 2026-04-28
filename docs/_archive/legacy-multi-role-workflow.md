# DEX 多角色 AI 协作工作流方案

> 位置：仓库根目录 `multi-role-workflow.md`
> 实现：`.claude/agents/` + `.claude/commands/`
> 使用指南：`.claude/README.md`

## 背景

DEX 项目技术跨度大（Rust 引擎、TypeScript 前端、Move 合约、PostgreSQL 索引），涉及资金安全。单一 AI 助手的问题：思维模式混淆、缺少质量关卡、架构决策越权。

## 方案设计

通过 Claude Code 原生 **subagent** 机制定义 6 个角色，每个角色有独立的系统提示、工具权限、模型、持久记忆。角色之间通过**文件系统约定**传递成果。

## 角色定义

| 角色 | 职责 | 工具权限 | 输入 | 输出 |
|------|------|---------|------|------|
| **analyst** | 调研、竞品分析、FAQ 互动 | 只读 + Web | 调研主题 | `docs/analyze/[slug].md` |
| **architect** | 系统设计、接口定义、技术选型 | 只写 docs/ | analyze 报告 | `docs/design-docs/[slug].md` + 按需 exec-plan |
| **developer** | 按设计实现、TDD 基础测试 | 全工具 | design-docs | 代码 + 测试 |
| **tester** | 对抗性测试、E2E、benchmark | 只写测试 | 代码 + design-docs | `tests/adversarial_*.rs` + `benches/` |
| **reviewer** | 代码审查（只读） | 只读 | 代码 + design-docs | 审查意见 |
| **dba** | Schema/SQL 审查（只读） | 只读 | migrations + 代码 | 优化建议 |

**关键约定**：
- architect **架构决策必须等用户确认**（plan-then-write）
- developer 中大型任务 **plan-then-code**（先出计划等确认）
- tester 中大型任务 **plan-then-test**
- analyst 分析前执行**六问追问框架**
- architect 关键决策需**量化评分**（0-10，7 个维度）
- 首要对标 Hyperliquid，dYdX 仅辅助参考

## 成果传递

```
analyst   → docs/analyze/[slug].md
              ↓
architect → docs/design-docs/[slug].md + exec-plans/（按需）
              ↓
developer → 代码 + 基础测试
              ↓
tester    → 对抗性测试 + E2E + benchmark（关键模块必触发）
              ↓
reviewer  → 审查意见（关键审查落盘到 docs/reviews/）
```

### 命名约定

使用统一的 **主题 slug**（kebab-case 英文，如 `funding-rate`）贯穿所有阶段。用户指定或首个 agent 命名。

### 落盘规则

| 角色 | 默认 | 何时必须落盘 |
|------|------|------------|
| analyst | 落盘 | — |
| architect | 落盘 | exec-plan 按需 |
| developer | 代码 | — |
| tester | 测试代码 | 中大型功能额外落盘 `docs/testing/plans/` |
| reviewer | 对话输出 | 资金/撮合/清算 或 Critical 问题 |
| dba | 对话输出 | 大表 schema 变更 或 Critical 问题 |

### 测试职责分层

| 测试类型 | 负责 |
|---------|------|
| 单元测试、TDD 验收 | **developer** |
| 对抗性边界 | **tester**（关键模块必触发：撮合、清算、资金、风控、Keeper、热路径） |
| E2E / benchmark | **tester** |
| 覆盖度审查 | **reviewer** |

## 项目知识管理

受 [Karpathy LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) 启发。

### decision-log.md（项目大脑）

`docs/decision-log.md` — 关键决策注册表（DEC-xxx）。Proposed → Accepted → Superseded。不删旧条目，冲突报 diff 等用户裁决。

### log.md（操作日志）

`docs/log.md` — append-only 文档变更日志。记录文档层面变更（非代码，代码用 git log）。

### 谁维护什么

| Agent | 读 decision-log | 写 decision-log | 写 log.md |
|-------|-----------------|-----------------|-----------|
| analyst | — | — | ✅ |
| **architect** | ✅ 必读 | ✅ 有新决策时 | ✅ |
| developer | — | — | — |
| tester | — | — | ⚠️ 仅测试计划落盘时 |
| **reviewer** | ✅ 对照审查 | — | ⚠️ 仅关键审查 |
| dba | — | — | ⚠️ 仅关键审查 |

### /lint

7 项检查（不修改文件）：决策一致性、过时检测、孤儿文档、断链、事实推论混淆、决策状态审计、log.md 完整性。

### 知识分层

```
可控度高 ←————————→ 低
decision-log > log.md > design-docs > claude-mem
```

## 设计决策记录

### 为什么用 subagent 而非 agent teams

工作流是**流水线**（分析→设计→实现→审查），不需要并行讨论。Agent teams 实验性 + token 成本高。未来需要并行研究时再考虑。

### 为什么保留独立 tester

developer 写自己的测试偏向 happy path；reviewer 只审不动手。DEX 关键模块（撮合、清算、资金）需要专门的对抗性测试，是独立工程任务。tester 按触发条件调用，非关键模块跳过以控制成本。

### 为什么不是每个 agent 都读 decision-log

控制 token 开销。只有做决策的（architect）和验证决策的（reviewer）需要读。其他角色跟着 design-docs 走。

## Commands

- `/workflow` — 完整开发流程
- `/bugfix` — Bug 修复流程
- `/lint` — 文档健康检查

## 文件清单

```
.claude/
├── agents/         analyst, architect, developer, tester, reviewer, dba
├── commands/       workflow, bugfix, lint
└── README.md       使用指南

dex-sui/
├── .claude/rules/  sui-architecture, rust-conventions
└── docs/
    ├── decision-log.md
    ├── log.md
    ├── analyze/
    └── reviews/
```

## 后续演进

1. **当前**：6 角色 + 3 command + 知识管理
2. **中期**：按需新增 security-auditor（DeFi 安全审查）
3. **长期**：agent teams 并行研究；PostToolUse hook 自动检查 log.md

## 参考

- [Claude Code Sub-agents](https://code.claude.com/docs/zh-CN/sub-agents)
- [Claude Code Agent Teams](https://code.claude.com/docs/zh-CN/agent-teams)
- [Karpathy LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
- [claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice)
