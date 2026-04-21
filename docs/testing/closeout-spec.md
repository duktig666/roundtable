---
slug: closeout-spec
source: docs/design-docs/closeout-spec.md
created: 2026-04-21
---

# Stage 9 Closeout 结构化流程 测试计划

> critical_modules 命中 3/3（skill/agent/command prompt 本体 + Phase Matrix + Escalation Protocol）→ tester 必落盘。
> 本项目无代码，全量由 dogfood E2E 覆盖。

## 1. 当前覆盖现状

- 本批 #48/#30/#29/#23/#27 5 个 PR 在 Stage 9 的实际走法已"隐式"规范化（commit msg + PR body 模板一致），但 prompt 本体**从未**明文约束；下一轮 orchestrator LLM 漂移风险客观存在
- closeout-spec 落点 `commands/workflow.md` Step 6.1 A 类 Stage 9 变体 + §Auto-pick 例外 + `commands/bugfix.md` ref + `docs/design-docs/closeout-spec.md`
- developer / tester 无代码改动；测试路径全为 workflow 级 E2E + orchestrator LLM 行为观察

## 2. 新增测试场景

### 2.1 对抗性（高优先，合并 review 清单 1/2/3/6）

- [ ] **A1 scope 白名单边界**：设计 §2.1 列 `workflow | bugfix | architect | analyst | developer | tester | reviewer | dba | prompts | ci | deps | release 或 slug`。对于 **target 项目（非 roundtable 自身）** 如 dex-sui 的 commit，scope 是 `dex-sui` 还是本白名单之一？期望：spec 明示"本 spec 是 roundtable **自身**约定，target 项目 CLAUDE.md 可 override"（设计 §1.3 已写但 Step 6.1 变体文本未回链） → **Warning W-1 建议在变体段补一句"target 项目 scope 以其 CLAUDE.md 为准"**
- [ ] **A2 `调: commit scope=bugfix` fuzzy parse**：orchestrator LLM 解析 `scope=bugfix` vs `scope: bugfix` vs 中文"scope 改成 bugfix" 的鲁棒性 → 期望：workflow.md Step 5 text 分支已声明 "fuzzy 解析 ... 歧义按 §3.6 层级澄清"，**Closeout 变体沿用**（隐式）。**Suggestion S-1**：变体段末补一行"`调:` 解析规则沿用 Step 5 text 分支 fuzzy + §3.6 澄清"以 explicit
- [ ] **A3 PR body 模板字段来源**：`Quality gates` 的 `tester: Critical/Warning/Suggestion/Positive 计数` 来自何处？当前无 `log_entries` schema 声明该计数字段，orchestrator 须从 tester final message prose 提取 → **Warning W-2**：模板字段缺机读源声明；短期可接受（LLM prose extraction），长期需与 DEC-004 事件 schema 或 log_entries 扩展对齐
- [ ] **A4 follow-up issues 去重**：本 PR 已 inline post-fix 了部分 Warning（例 DEC-006 §A 多轮 post-fix）。closeout bundle 的 follow-up 是全量列还是排除"已 inline 修"？→ **Warning W-3**：设计 §2.3 未明示；建议加一条"已在本 PR 内 post-fix 的 finding 不入 follow-up issue 清单；由 orchestrator 对照 `git diff` vs reviewer finding 位置判定"，否则 orchestrator LLM 容易重复 open 已解 issue
- [ ] **A5 memory 硬边界 vs 现行自动 merge 观测**：用户 msg #441 "都自动 pr merge 不要阻塞"已被当作"显式授权一批 PR 的自动 merge"覆盖 `feedback_no_auto_pr`。closeout-spec 在 auto_mode 下继续 pause 等 `go-all` → **与现行用户显式授权范式一致**（临时覆盖不入 memory 常态）。期望：变体文本明示"用户可在 session 内说 '都自动 pr merge' 临时覆盖；memory 仍是硬默认"。**Suggestion S-2**：补一行即可
- [ ] **A6 bugfix.md 继承 Stage 9 空 section**：bugfix 无 tester/reviewer/dba 强制 → follow-up issues section 空；bundle 仍 emit 3 section 但 (3) 为空占位 → 期望：空时 orchestrator emit `3. follow-up issues: （无 non-blocking findings，skip）`。**Suggestion S-3**：bugfix.md L113 ref 补一行"section 可为空时 orchestrator 输出 skip 占位"
- [ ] **A7 `skip-pr` 只 commit push 的状态**：用户 `skip-pr` 后 branch 有 commit 但无 PR；若下次用户又手动补 commit 再手动 `gh pr create` 会是同 branch 混合历史 → **Warning W-4**：应 emit 警示"branch 现有 N 个 commit 未 PR，是否下次 closeout 合并入同一 PR？"；当前 spec 未覆盖
- [ ] **A8 bundle emit 与 Step 5b TG 转发归类**：Step 5b 表列事件类 b = A 类 producer-pause；closeout bundle 3 section 属于 "A 类 pause 的第二段"（首段是 Stage 9 菜单 = b，bundle = 未归类）→ **Critical C-1**：Step 5b 事件类归属歧义；建议 closeout bundle 归为事件类 b 的"二段扩展"或新增 `b2` 子类；同时需注意 markdownv2 编码下 commit msg / PR body 的反引号与转义**可能超 4096 字符**（TG 单消息上限），应声明"bundle 若 >3500 chars 自动拆 2-3 reply，分别 a) commit msg b) PR body c) issues draft"。
- [ ] **A9 符合 DEC-006 §A 菜单穷举原则**：Stage 9 变体菜单（`go / 问 / 调 / 停`）+ bundle 后菜单（`go-all / go-commit / go-pr / go-issues / skip-pr / skip-issues / 调 / 停`）均穷举；✅ **Positive P-1**

### 2.2 E2E dogfood 场景

- [ ] **E1 workflow 正常闭环 → `go`**：验证 bundle 3 section emit 顺序、格式、与 Stage 9 菜单之间的 pause 点清晰
- [ ] **E2 `go-all`**：commit + push + `gh pr create` + `gh issue create` 循环的错误恢复（例如 push 失败后 issue 创建是否继续）→ spec 未声明部分失败行为 → **Suggestion S-4**
- [ ] **E3 `go-commit skip-pr`**：branch 状态、log.md 落条（prefix `decide` 或 `fix`？spec 未说）→ **Suggestion S-5**
- [ ] **E4 `调: commit scope=prompts`**：orchestrator 重生成 commit msg 保留 PR body / issues section 不变
- [ ] **E5 `停`**：不动 git；local 修改保留 → log.md 是否仍 flush Stage 1-8 entries？设计未说；按 DEC-009 Step 8 触发点 1 "Stage 9 Closeout 之前" flush → `停` 发生在 flush **之后**（bundle 已 emit 说明 pause 触发 = flush 已执行）→ ✅ P-2
- [ ] **E6 auto_mode=on**：orchestrator auto-推进 bundle 生成但 pause 等 `go-all`；audit 事件类 e emit `🟢 auto-go closeout bundle ✅`（或应 emit `🔴 auto-halt: memory hard boundary`？）→ **Warning W-5**：设计 §3.1 文本写"memory 硬边界优先于 §Auto-pick"，但未明确 audit event 用 go 还是 halt。建议用 `🟢 auto-go <bundle-emit>` + `🔴 auto-halt: closeout-execute awaits user (memory hard boundary)` 两事件，让 TG 观察者明白"bundle 已 auto 起草但 execute 仍需用户"
- [ ] **E7 bugfix Stage 9**：同款 bundle 流程；验证 follow-up issues section 空时 skip 占位（见 A6）

### 2.3 Benchmark

- N/A（prompt 本体 workflow 协议，无 perf path）

## 3. 发现的潜在问题（反馈 developer / orchestrator）

见 §2 的 W-1/W-2/W-3/W-4/W-5、S-1/S-2/S-3/S-4/S-5、C-1、P-1/P-2。合入本文件即完整清单。

## 4. 变更记录

- 2026-04-21 初版（issue #26 P2 对抗审查）
