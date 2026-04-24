---
slug: lint-cmd-multifield-propagation
tier: 2
source: issue #108
created: 2026-04-24
---

# lint_cmd_* 多字段契约传导面覆盖 Postmortem

## 1. 根因

DEC-029 决定 7 的 post-fix 2026-04-23（tester C1 finding）把 CLAUDE.md §工具链 `lint_cmd` 单字段拆为 `lint_cmd_hardcode` + `lint_cmd_density` 多字段以解 `&&` 短路 enforcement 洞；同时 `skills/_detect-project-context.md` §4 正文追加多字段兼容说明。但**下游传导面未同步扩**：

- 输出模板（`skills/_detect-project-context.md` L112）仍渲染 singular `lint_cmd`
- 5 处注入清单（workflow.md / bugfix.md / developer.md L22+L87 / reviewer.md）仍列 singular `lint_cmd`

**本质**：DEC-029 契约修订是"源头 + 检测层"改；"注入面 + agent 消费层"属同契约下游应同步扩的传导，落盘时被 issue #99 scope 边界截断（#99 scope 以 enforcement 为主，扩展面交 follow-up 即 #108）。reviewer W-R03（`docs/reviews/2026-04-23-prompt-reference-density-audit.md`）在 #99 审查阶段已 flag，本 issue 是其实施承接。

## 2. 复现

在 roundtable 本仓跑 `/roundtable:workflow` 或 `/roundtable:bugfix` 的递归 dogfood 场景：

1. CLAUDE.md §工具链声明 `lint_cmd_hardcode: <cmd>` + `lint_cmd_density: <cmd>` 多字段（本仓现状）
2. orchestrator Step 0 读取 CLAUDE.md 成功（`_detect-project-context.md` §4 多字段分支已实现）
3. orchestrator 派发 developer / reviewer subagent 时，按 `commands/workflow.md:69` / `commands/bugfix.md:30` 注入清单的 singular `lint_cmd` 规则，prompt prefix 只注入 singular 字段
4. subagent 收到的 context 不含 `lint_cmd_hardcode` / `lint_cmd_density`，`scripts/ref-density-check.sh` enforcement 在 subagent 侧无法自动跑
5. 实际影响：critical_modules 改动场景下 subagent lint 阶段 enforcement 断层，需 orchestrator 在 subagent 返回后补跑（增加 round-trip 成本 + 依赖 orchestrator 记得补）

## 3. 修复

α 方向（3-field lineup）per issue #108 architect decision `<decision-needed id="lint-cmd-multifield-propagation-1">` user=A：

| 文件 | 改动 |
|------|------|
| `skills/_detect-project-context.md` L112 | 输出模板 singular `lint_cmd` 扩为 3 字段（`lint_cmd_hardcode` / `lint_cmd_density` / `lint_cmd` singular fallback）|
| `commands/workflow.md` L69 | "必须注入" 清单扩 3 字段 + 括注 "三字段任一存在即合法，调用方遍历跑各非空字段并独立判 exit code" |
| `commands/bugfix.md` L30 | 同上 |
| `agents/developer.md` L22 | 「必需的上下文注入」扩 3 字段 |
| `agents/developer.md` L87 | §约束 `使用注入的 lint_cmd / test_cmd` 扩 3 字段 |
| `agents/reviewer.md` L24 | 「必需的上下文注入」扩 3 字段（`可选` 语义保留）|

**不改**：
- DEC-029 正文（契约源头；本 fix 是传导承接）
- 其他 agent prompt（tester / dba / research：issue AC 未列入 5 调用点，scope 保守）
- CLAUDE.md §工具链（契约源头已 DEC-029 post-fix 定稿）
- `skills/_detect-project-context.md` §4 detection 逻辑（已多字段兼容）
- back-compat：外部 target CLAUDE.md 单 `lint_cmd` 配置仍合法（第 3 字段 fallback 语义保留）

## 4. 验证

- `lint_cmd_hardcode` exit 1（无命中）/ `lint_cmd_density` exit 0（无密度回归）双通过
- grep audit：5 调用点均含 `lint_cmd_hardcode` + `lint_cmd_density` + singular `lint_cmd` 三字段 ✓
- back-compat：α 方向显式保 singular `lint_cmd` 作 fallback 字段，未破坏现有 target 项目配置
- dogfood（本 session 后续派发）验证：本 bugfix 的 reviewer inline 派发时 orchestrator 注入三字段完整 ✓（inline form skip Step 3.5 但 context prefix 注入同规）

## 5. Follow-ups

- P3 后续：若 issue AC 外的调用点（如 tester / dba 的 prompt context 注入清单）亦发现 singular→multi-field 扩展需求，单独 issue 处理，不在本 fix scope
- 若未来引入第 3 类 lint（如 `lint_cmd_security`），按 α 方向扩 3→4 字段；若扩展频率高，届时考虑 β（generic Record）Refines DEC-029
- `docs/reviews/2026-04-23-prompt-reference-density-audit.md` W-R03 本 issue 关闭后可标 resolved
