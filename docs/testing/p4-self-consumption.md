---
slug: p4-self-consumption
source: 原创（gleanforge 项目从零 build 到 MVP 的 dogfooding 实录）
created: 2026-04-18
status: Accepted
decisions: [DEC-001]
---

# P4 自消耗闭环验证观察报告

> 本轮用 `/roundtable:workflow` 在全新项目 `gleanforge`（TS 栈、AI + Web3 每日资讯聚合工具）上从零 build 到 P0 完成 + dry-run smoke 通过。以下是 plugin 作者本人 dogfooding 视角下的观察，供 plugin 优化参考。
>
> 对应 `docs/exec-plans/active/roundtable-plan.md` §P4。

---

## 1. 这一轮发生的事（数据）

| 项目 | 数据 |
|------|------|
| 总 subagent 派发 | 9 次（4 developer + 1 tester + 1 reviewer + 1 bugfix + P0.6 & P0.8 组合 + 重派 0）|
| 并行派发 | 3 次（P0.2+P0.3、tester+P0.6、bugfix+P0.7）|
| skill 主会话驻留 | 3 个（`_detect-project-context`、analyst、architect）|
| 架构决策（DEC） | 7 条，0 Superseded，1 条（DEC-006）补作用域澄清 |
| 发现的 bug | 1 P1（空集 Jaccard=1，tester 抓到 → 下一轮 bugfix 修）+ 4 P2-P4（锁定未修）|
| reviewer 分级 | Critical 0 / Warning 7（修 3 推 4）/ Suggestion 11（全推）|
| 最终测试 | 17 suites / 242 passed + 1 skipped；lint / golden / integration 全绿 |
| 产出代码 | `src/*` ≈ 30 文件；`tests/*` ≈ 20 文件；`docs/*` 完整 roundtable 结构 |

---

## 2. 工作良好的设计（保留）

1. **skill + agent 的双形态**：架构决策在 skill（主会话 AskUserQuestion 可用）做，实现在 subagent（隔离上下文）做 —— 架构决策不被子任务上下文污染，子任务不被主会话历史拖累。
2. **"决策实时 AskUserQuestion"约束**：architect skill 把决策点立刻弹窗，而不是攒到最后写文档让用户改，决策质量显著更高。
3. **critical_modules 触发 tester 规则**：去重逻辑被 CLAUDE.md 声明 critical，P0.5 developer 完成后 orchestrator 知道必须派 tester —— 规则机械可执行。
4. **exec-plan 作为 agent 间契约**：每个 developer 只做指定 phase、各自成功信号、禁触他人文件，并行时冲突为 0。
5. **tester 的"断言当前坏行为 + TODO 注释"模式**：P2-P4 未修的 bug 被锁定为回归屏障，未来任何 `dedup.ts` 改动都会命中；业务零成本的"已知限制文档化"。
6. **reviewer 的分级 + 决策一致性 + `file:line`**：每条 Warning 都能一眼定位，决策对齐逐 DEC 检查让"实现漂移"无处藏。

---

## 3. 摩擦点（建议改进）

### 🟠 Process 层

1. **并行调度策略未形成显式 skill**：`/roundtable:workflow` 的 command 文档只描述单向线性流（analyst → architect → developer → tester → reviewer），没给"何时 P0.2 + P0.3 可以并行"的判定规则。本轮靠 exec-plan 的"前置"列手工推导，缺失会给后人埋坑。**建议**：在 command 里加一段"并行派发判定树"或让 `dispatching-parallel-agents` skill 被 workflow command 主动提示。
2. **exec-plan checkbox 谁回写契约不清**：`developer.md` 说"更新阶段勾选状态"，但并行 developer 同时改同一文件会 race。本轮解法是"agent 不改 checkbox，orchestrator 代写"。**建议**：在 `developer.md` 明文写"仅按报告清单列出完成项，orchestrator 回写"，并把这条升级为**共享资源协议**（包括 `decision-log.md` / `testing/`）。
3. **`_detect-project-context` skill 是 markdown 文档而非可执行 skill**：主会话 Claude 看到时需要手工执行 4 步。**建议**：把它做成 workflow command 启动时自动注入的 preamble，所有后续 skill / agent 默认上下文都已就绪；或改名保留 `_` 前缀明确为"内部 helper"。

### 🟠 Agent 能力层

4. **subagent 没有 AskUserQuestion**：tester 发现 P1 bug 只能文字建议，developer 遇到设计漂移（如 Entry.externalId contract bug）也只能"反馈给 orchestrator 让主会话问"。小调整（DEC-006 作用域澄清、Entry 加字段）本可以 agent 内完成，但当前需要回主会话 relay。**建议**：为 agent 增加"结构化请求调度方决策"协议，orchestrator 把 agent 的 "我要问 A/B" 直接转成 `AskUserQuestion`。
5. **agent 间共享"已装依赖 / 已定约束"缺上下文**：每次 developer dispatch 都要手动重复"`execa` / `zod` / `gray-matter` / `js-yaml` / `nock` 已装；不引新依赖"，因为每个 agent 是 fresh context。**建议**：让 workflow command 在 session 级维护一份"项目约束小抄"（已装依赖、`lint_cmd`、`critical_modules`、current phase），每次 agent dispatch 自动注入。

### 🟠 约束层

6. **"不 git commit"默认行为未写进 agent 定义**：用户在 memory 里有 `feedback_no_auto_push`，但 agent 不会读用户 memory。每次都要在 prompt 加这条。**建议**：`developer` / `tester` / `reviewer` 默认"只对 working tree 操作、不 git 动作"，除非 orchestrator 显式授权。
7. **`log.md` 与 `vault/log.md` 区分混乱**：tester 没写 log.md（orchestrator 补的），developer 有时写有时不写。design-doc 层面有 `docs/log.md`（架构级）和 `vault/log.md`（业务级）两份，角色职责边界没给。**建议**：`developer.md` / `tester.md` / `reviewer.md` 明确"谁写哪份 log、什么 op 前缀"的表格。

### 🟠 skill 内容层

8. **architect skill 不能派 parallel subagent 做专题调研**：DEC-002 / DEC-004 / DEC-005 的决策可能需要更深的外部 research，但 architect 是主会话 skill，`WebFetch` 是串行的。如果 architect 能派 parallel analyst subagent 做"每项决策对应的竞品调研"，决策质量会再升一档。**建议**：architect 在探索阶段可以派短 lived subagent 做 option research。
9. **工具链覆盖 section 回填时机隐性**：P0.1 必须回填 `CLAUDE.md` 的「工具链覆盖」section，本轮在 prompt 里明写。但 `developer.md` 本身没讲"谁、何时、以什么格式回填"。**建议**：在 `claude-md-template.md` 里给出"首个 P0 developer 回填此 section"的标注 + 回填样板。

---

## 4. 给 roundtable 的 3 条最高优先级改进

1. **共享资源协议**：把 `exec-plan.md` / `log.md` / `decision-log.md` / `testing/` 的读写权限表升级为一等公民文档，所有 agent 在 prompt 开头看到"不编辑 X、只读 Y、报告 Z"列表。当前靠 orchestrator 逐次 prompt 注入，易遗漏。
2. **agent → orchestrator 请求决策协议**：让 subagent 能够用结构化 JSON 请求（"我遇到问题 P，选项 A/B/C"），orchestrator 自动转 `AskUserQuestion` 并把答案回注。消除"tester 发现 bug 要 relay"的摩擦。
3. **workflow command 启动 checklist 化**：当前 `/roundtable:workflow` 只描述 5 步，应该做成可点选的"已完成 / 在进行 / 待启动"矩阵（可视化显示阶段位置 + 每阶段可派的 agent），避免 orchestrator 状态错位。

---

## 5. 本轮未做（按用户明确的推迟清单）

- 真实网络 + 真实 LLM smoke（`r.jina.ai` 本机超时、opencli 不可用；等用户切换有网环境）
- W3 / W5 / W6 / W7 四条 Warning + 11 条 Suggestion
- tester P2-P4 对抗性 bug（NFC / NFD、ZWSP、pickWinner tie、URL path case、markdown fence）
- 仓库首次 git commit（整个 repo 仍 `??` 未 tracked，等用户主动）
- `<!-- examples -->` 块真实 before/after 样例（首次真 smoke 后补）

---

## 6. 结论

roundtable plugin 的核心编排能力（skill+agent 双形态、critical_module 触发 tester、exec-plan 共享契约、分级 review）**经得起从零到 MVP 的端到端使用**；最主要的摩擦来自"subagent 通信封闭性"与"共享资源协议隐式"两条线。**这两条都是可演进的增量优化，不需要推翻架构**。

---

## 变更记录

- 2026-04-18 创建：gleanforge P4 自消耗闭环首轮完整报告
