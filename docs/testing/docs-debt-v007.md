---
slug: docs-debt-v007
date: 2026-06-12
issue: 131
verdict: 1 Major / 3 Minor / 2 Info — Major 修复后可发 v0.0.7
---

# docs-debt-v007 — Test Plan（release 前对抗核查）

> 范围：branch `feat/docs-debt-v007-botB`（fdaf2a2 + ff41eeb）vs main（946f075）。merge 后直接打 tag v0.0.7，按发布门槛从严核查。src 只读。

## Coverage

| # | 攻击面 | 方法 | 结论 |
|---|--------|------|------|
| 1a | 三 manifest 版本一致 + JSON 有效 | `python3 json.load` × 3 + grep version | ✅ 全部 `0.0.7`，JSON 有效 |
| 1b | CHANGELOG [0.0.7] 收纳 PR-1/2/3 全部用户可见变更 | 逐 hunk 对照 `git diff a91f3a4..492833e`（PR-1）、`492833e..946f075`（PR-2）、`main...HEAD`（PR-3） | ⚠️ 1 处漏报（F2）+ 1 处 Info（F5），其余全覆盖；`12 cases / 49 assertions` 声明与实际运行输出一致 |
| 1c | rc1~rc3 及更早历史节一字未改 | `git diff main...HEAD -- CHANGELOG.md` 过滤删除行 | ✅ 零删除行，纯新增（header + 2 条 #131 entry） |
| 1d | 空 [Unreleased] 占位格式 | 目检 | ✅ 符合 Keep a Changelog |
| 2a | 全仓 "2 skills"/"两个 skill"/"2 个 skill" | `grep -rni` *.md/*.json | ✅ 仅存于允许例外（reviews/testing 报告、completed exec-plan、analyze/design-docs 历史叙述、本 exec-plan 引述） |
| 2b | 全仓 rc 引用 / 旧版本号 | `grep -rn "0.0.7-rc"`、`0.0.[1-6]` in JSON | ✅ rc 仅在 CHANGELOG 历史节与报告类文档；JSON 零旧版本 |
| 2c | README 双语对称性 | 逐 hunk 对照 en/zh diff | ✅ intro / 表格 command→skill ×3 / 新增薄壳段 / Layout 树均等价 |
| 3 | INDEX.md 真实性 | 7 目录 `find` 13 文件 vs INDEX 13 条逐一比对（路径 / frontmatter slug / 首个 H1） | ✅ 工作区层面 1:1；❌ git tree 层面 active 条目指向未提交文件（F1）；本 PR 后续报告致 INDEX 立即过期（F6） |
| 4 | 死链全仓（本 PR 改过的 9 文件） | 提取全部相对 `[]()` 链接逐一 resolve | ✅ 零断链；inline-code 路径引用发现 2 处指向已删除目录（F4） |
| 5 | W5 改名后 "Step 0" 残留 | `grep -rn "Step 0"` 全仓 | ✅ skills/agents/commands/hooks/README 零残留；命中仅历史报告与 CHANGELOG 0.0.1 节（语义不同） |
| 6 | 行为不变性 | `git diff main...HEAD -- skills/ agents/ hooks/ tests/ commands/` 逐 hunk + 两套 hook 测试复跑 | ✅ 唯一 hunk = `### Step 0: Detect environment` → `### Environment detection`；`session-start.test.sh` 49 passed / 0 failed；`STRICT=1 session-start.adversarial.test.sh` 301 passed / 0 failed / 0 known-bug |
| 7 | usage/roundtable 与 hook 实际输出自洽 | 对照 `hooks/session-start` L205-231 字段构造 | ✅ prose 描述（env→config→walk-up、workspace_root+projects、双键单行 JSON）与实现一致；❌ roundtable.md 示例块仍是旧单模式格式（F3） |

hook 实际字段（实测）：project 模式 `mode / docs_root / docs_root_source(env|config|walk-up, 可选) / project_id / git_top / status (+warning/note)`；workspace 模式 `mode / workspace_root / projects / status`。README「Context fields」声明与之完全一致。

## New Cases (Adversarial / E2E / Benchmark)

本 PR 为纯文档 + 版本 bump，无新增可执行面；未新增测试文件。复跑既有两套 hook 套件作回归（见 Coverage #6），并以 `git ls-files` / `git show HEAD:docs/INDEX.md` 做了 tree-level 完整性核查（工作区目检会漏掉 F1，这是本次新增的核查维度）。

## Found Bugs / Gaps

### F1 — Major（发布阻断）：exec-plan 未提交，已提交的 INDEX.md 指向 tree 中不存在的文件

- 证据：`git status` → `?? docs/exec-plans/active/`；`git ls-files docs/exec-plans/` 仅 3 个 completed；而 `git show HEAD:docs/INDEX.md` 含 `- [docs-debt-v007](exec-plans/active/docs-debt-v007.md)`
- 影响：merge + tag 后，v0.0.7 发布树里 INDEX.md 有断链（lint Step 3 定义的 Critical）；且本 PR 自己的 exec-plan（issue #131 审计链）不在仓库里——dogfood 清算文档债的 PR 自己欠了文档债
- 处置：merge 前 `git add docs/exec-plans/active/docs-debt-v007.md` 补提交（内容零改动，仅入库）。tester 不代为提交（exec-plan 文件归 orchestrator/developer 职责）

### F2 — Minor：CHANGELOG [0.0.7] Added 漏报对抗测试套件

- 证据：CHANGELOG.md:15 仅列 `tests/session-start.test.sh`（12 cases / 49 assertions——该数字已实测核实）；`tests/session-start.adversarial.test.sh`（PR-1 commit 43d270a，657 行 / 实测 301 assertions）全 CHANGELOG 零提及
- 矛盾点：CLAUDE.md:14 写明 "two hook test suites"，release notes 只交代了一套
- 处置：CHANGELOG.md:15 追加一个从句即可

### F3 — Minor：docs/roundtable.md 示例 context 块仍是 #127 之前的旧格式

- 证据：docs/roundtable.md:100-104 示例块只有 `docs_root / project_id / status` 三字段；缺 `mode:` 与 `git_top:`——而紧邻其上的 :95-97 prose 正是本 PR 改成双模式的（双模式下 `mode` 必出现）
- 影响：读者按示例核对注入上下文会对不上实际输出
- 处置：示例块补 `mode: project` 与 `git_top:` 两行（或注明节选）

### F4 — Minor：两处现行表述仍指向 v0.0.5 已删除的 `docs/_archive/`

- 证据：docs/usage.md:148（FAQ「旧版 design-docs / decision-log 在哪？」答 `docs/_archive/`）、docs/roundtable.md:136（「v0.0.4 老 docs 在 `docs/_archive/`」）；磁盘上 `docs/_archive` 不存在，CHANGELOG v0.0.5 Removed 节与 Migration note（"now removed; references will 404"）均确认已删
- 矛盾点：本 PR 刚把 CLAUDE.md Layout 里的 `docs/_archive/` 行删掉，却留下这两处同病灶；两文件均为本 PR 改过的文件，且 FAQ/限制是现在时表述、非历史叙述（不受 DEC-4「历史性叙述不动」豁免）
- 处置：两处答案改为「已从工作树移除，git history 保留（见 CHANGELOG v0.0.5）」

### F5 — Info：CHANGELOG 未单独提及 closeout 清扫扩展

- CHANGELOG.md:25 收纳了 exec-plan 生命周期单一 owner，但 cf347cc 新增的「closeout 时顺带清扫 active/ 里遗留的全勾 exec-plan」（workflow SKILL Step 5）未显式出现。可视为被 :25 涵盖；从严口径下记一笔，不要求改

### F6 — Info（结构性）：INDEX.md 在本 PR 收尾时必然过期

- 本报告（docs/testing/docs-debt-v007.md）及后续 reviewer 报告提交后即不在 INDEX 内；INDEX 由 lint 生成、约定禁手改，tester 不动它
- 处置建议：tester/reviewer 报告全部落地后、merge 打 tag 前，由 orchestrator 跑一次 `/roundtable:lint`（或等价重建）出最后一个 INDEX 重建 commit——该 commit 可一并携带 F1 的 `git add`（及 F2/F3/F4 的一句话修补，若采纳）

## 核查统计

- 文件：9 个改动文件全链接 resolve；13 个 docs 文件 vs INDEX 13 条目 1:1 比对（slug + H1 + 路径）
- diff：3 个 PR 区间逐 hunk 对照 CHANGELOG，零虚报、1 漏报（F2）
- grep 扫描：4 类口径（skills 计数 / rc / 旧版本 / Step 0）全仓零活性残留
- 测试：两套 hook 套件复跑 350 assertions 全绿（49 + 301），行为不变性成立
