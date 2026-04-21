---
slug: closeout-spec
source: docs/design-docs/closeout-spec.md + workflow.md Step 6.1 Stage 9 变体
created: 2026-04-21
reviewer: tester+reviewer merged review (对抗审查)
verdict: Approve-with-caveats
---

# Stage 9 Closeout 结构化流程 审查（issue #26 P2）

## 判定

**Approve-with-caveats** —— 设计方向正确，与 DEC-006 §A 三分法、DEC-015 §Auto-pick、memory `feedback_no_auto_*` 硬边界全部一致，无需阻塞合并。但存在 **1 Critical 形式问题 + 5 Warning + 5 Suggestion**，其中 Critical 与 W-2/W-3/W-5 应在本 PR 内 post-fix 或开 follow-up issue，其他可延后。

## 决策一致性审查

| 维度 | 结论 |
|------|------|
| DEC-006 §A 三分法保持 | ✅ Stage 9 仍为 A 类 producer-pause；变体是 append-only clarification |
| DEC-006 §A 菜单穷举 + 禁止 silent default（#30 post-fix）| ✅ `go / 问 / 调 / 停` + bundle 后 `go-all / go-commit / go-pr / go-issues / skip-pr / skip-issues / 调 / 停` 穷举 |
| DEC-015 §Auto-pick recommended 预授权心智 | ✅ 新增"Stage 9 Closeout bundle 例外"段是**收窄**而非**扩张**，不破坏预授权心智 |
| memory `feedback_no_auto_push` / `feedback_no_auto_pr` | ✅ 硬边界明示"优先于 §Auto-pick"；auto_mode 只 auto-推进 bundle 生成 |
| DEC-009 Step 8 log.md flush 触发点 1（Stage 9 之前）| ✅ 不冲突；bundle emit 在 flush 之后发生 |
| Step 5b TG forwarding 事件类 b | ⚠️ **Critical C-1**：bundle 3 section 在事件类表格中归属未明确（见下） |
| lint_cmd `gleanforge\|dex-sui\|dex-ui\|vault/\|llm/` | ✅ 0 命中 |
| critical_modules 命中 | 3/3 命中 → tester 必落盘 ✅ 已产出 `docs/testing/closeout-spec.md` |
| 对 DEC-001 D1-D9 / DEC-002 / DEC-004 / DEC-005 / DEC-013 无 Superseded 风险 | ✅ |

## Findings

### Critical

**C-1** `commands/workflow.md` Step 5b 事件类表格归属歧义 — closeout bundle 的 3 section（commit msg / PR body / issues draft）emit 位置在 A 类 producer-pause 菜单**之后**。Step 5b 表列 **b = A 类 producer-pause 3 行 summary**（格式 markdownv2），但 bundle 是远超 3 行的大块输出，且含代码字段（commit msg / PR body Markdown）。
- 风险：orchestrator LLM 在 TG active channel 下按"事件类 b markdownv2"转发时，commit msg 与 PR body 的反引号 / hash / 括号会需大量 markdownv2 转义；bundle 合计大概率 >3500 Unicode codepoints（PR body 本身 ~500-1000 字 + commit body ~200 + issues 3-5 条每条 ~150）→ 触及 TG 4096 字符上限或导致单消息可读性崩坏
- **建议**：Step 5b 增补一条"Stage 9 Closeout bundle 特例"——
  - 若 bundle 总长 >3500 codepoints → 拆 2-3 条 reply：(i) commit msg `markdown` 围栏 / (ii) PR body `markdown` 围栏 / (iii) follow-up issues `markdown` 围栏
  - 内容全部走 ``` 围栏零转义（参照事件类 a 模式），而非 `markdownv2`
  - 归类建议新增子类 `b2 (Closeout bundle)` 或在 b 行追加"*bundle 模式见 Stage 9 变体*"
- 阻塞级别：**建议本 PR 内 post-fix**（1 行表脚注 + 1 段变体内补充即可）；否则首次 TG 远程跑 Stage 9 即会踩坑

### Warning（non-blocking，建议跟 follow-up issue）

**W-1** Conventional Commits scope 白名单开放项 "或 slug" 实际让 scope 无边界。对于 **target 项目非 roundtable 自身**（如 dex-sui）的 scope 来源未明。设计 §1.3 写了"target 项目 CLAUDE.md 可 override"但 Step 6.1 Stage 9 变体文本未回链。
- 建议：变体段加"（target 项目 scope 以其 CLAUDE.md 约定为准）"；或 follow-up issue: "claude-md-template.md 增补 commit scope 字段示例"。

**W-2** PR body 模板 `Quality gates.tester` 的 `Critical/Warning/Suggestion/Positive` 计数缺机读源声明 — 当前只能靠 orchestrator LLM 从 tester final message prose 提取，跨 session 一致性弱。
- 建议：短期可接受；长期建议扩展 `log_entries` YAML 支持 `verdict: {critical: N, warning: N, suggestion: N, positive: N}` 字段（已有 prefix `test-plan` / `review`）或 closeout-spec 单独定义一个 `findings_summary` block schema。
- follow-up issue 标题建议：`closeout: machine-readable findings-count schema for PR body Quality gates` P2

**W-3** follow-up issues 去重未定义 — 若本 PR 已 inline post-fix 了 reviewer 的某条 Warning（本批 #30/#23/#27 多轮 post-fix 已是此模式），closeout 仍应全量列还是排除？
- 风险：orchestrator 重复 open 已解 issue
- 建议：设计 §2.3 补一条"已在本 PR `git diff` 范围内覆盖的 finding 从 follow-up 清单剔除；判定依据 = finding 引用路径/行 是否与 diff hunk 相交"。同样可作为 follow-up issue。

**W-4** `skip-pr` 后 branch 有 commit 无 PR 的**状态漂移**风险 — 下次用户在同 branch 追加工作时 closeout 是合入同 PR 还是新开？spec 未覆盖。
- 建议：`skip-pr` 分支上 orchestrator 在下次 Stage 9 预检测本地 `git log origin/<base>..HEAD` unmerged commits >0 时 emit 警示"当前 branch 已有 N 个 unmerged commits，是否合并入本次 PR？"

**W-5** auto_mode 下的 audit 事件 emit 未明示 — "memory 硬边界优先于 §Auto-pick" 文本已写，但 audit event 是 `🟢 auto-go` 还是 `🔴 auto-halt` 未说。TG 观察者需知道"bundle 已起草但需用户执行"。
- 建议：变体段最后一句加"（audit: emit `🟢 auto-go closeout-bundle drafted` + `🔴 auto-halt: git/gh execution awaits user (memory hard boundary)` 双事件）"。

### Suggestion

**S-1** `调:` fuzzy 解析沿用 Step 5 text 分支规则，变体段可显式 ref 一行 explicit 以防 orchestrator LLM 漂移。

**S-2** "用户可在 session 内显式说『都自动 pr merge』临时覆盖 memory 硬边界"这一现行范式未写入 spec；可在 §1.2 / §2.4 补一句"临时覆盖 scope=session，不入 memory 常态"。

**S-3** bugfix.md 的 Stage 9 bundle 中 follow-up issues section 常空；bugfix.md L113 ref 建议加"section 可为空时 orchestrator emit `(无 non-blocking findings，skip)` 占位"。

**S-4** `go-all` 的部分失败恢复未定义（push 失败后 issue 是否继续创建？PR 创建失败后 issues 是否继续？）。建议声明"按依赖序严格 fail-fast；push 失败中止；PR 失败但 commit 已入，则 issues 仍 create 但 body ref 本地 commit SHA 而非 PR URL"。

**S-5** `go-commit skip-pr` / `go-commit` 后 log.md 条目 prefix 未说明。建议 `closeout` 新前缀 或复用 `decide`（与 `go-without-plan` 同归 decide）——本 Issue 的 spec 落盘已经走 `decide | DEC-006 post-fix`，保持一致即可。

### Positive

**P-1** Stage 9 变体菜单两段均穷举（go/问/调/停 + go-all/go-commit/go-pr/go-issues/skip-pr/skip-issues/调/停），严格符合 DEC-006 §A post-fix 2026-04-21。

**P-2** §Auto-pick 例外条款落点正确（§Auto-pick 末尾追加"Stage 9 Closeout bundle 例外"段），不污染 §Auto-pick 表格；心智保持"预授权 ≠ 硬操作"。

**P-3** DEC-006 影响范围 post-fix 2026-04-21 (#26) 追加走 append-only clarification 不新开 DEC，与 #30 post-fix 模式一致。

## 对抗清单覆盖回填

| 对抗项 | 映射 finding |
|-------|------------|
| 1. scope 白名单边界 | W-1 |
| 2. PR body 字段来源 | W-2 |
| 3. follow-up 去重 | W-3 |
| 4. memory 硬边界 vs auto_mode 矛盾 | S-2 + 设计文本已一致，非矛盾（用户显式授权是 session scope 临时覆盖，不入 memory 常态） |
| 5. bugfix 继承空 section | S-3 |
| 6. `调:` fuzzy parse | S-1 |
| 7. bundle 与 TG forwarding Step 5b | **C-1** |
| 8. critical_modules 命中 3/3 | ✅ 已落盘 testing/ + reviews/ |
| 9. lint 0 命中 | ✅ |
| 10. `skip-pr` branch 漂移 | W-4 |

## 建议行动

1. **本 PR 内 post-fix**（最小集）：C-1（Step 5b bundle 特例 + 变体内 ≤3500 chars 拆 reply 规则）；W-5（audit 双事件）
2. **Follow-up issues**：W-1 / W-2 / W-3 / W-4（每条独立 P2 issue）；S-1~S-5 可合并为一条 P3 "closeout-spec polish batch"
3. **不必改**：P-1 / P-2 / P-3 positive finding，验证设计方向正确
