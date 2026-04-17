# roundtable 5 分钟上手

**目标**：装好 plugin → 给你的项目加配置 → 第一次跑 `/roundtable:workflow`。

---

## 1. 装 plugin（30 秒）

在 Claude Code 会话里：

```
/plugin marketplace add duktig666/roundtable
/plugin install roundtable@roundtable --scope user
```

**零弹窗**，秒装完。装完你就有了这些命令和角色：

- `/roundtable:workflow <任务>` — 多角色编排入口
- `/roundtable:bugfix <bug>` — Bug 修复工作流
- `/roundtable:lint` — 文档健康检查
- `@roundtable:architect` / `@roundtable:analyst`（skill，交互式）
- `@roundtable:developer` / `@roundtable:tester` / `@roundtable:reviewer` / `@roundtable:dba`（agent，自主执行）

---

## 2. 给你的项目加配置（2 分钟）

在**项目根目录**打开（或新建）`CLAUDE.md`，追加：

```markdown
# 多角色工作流配置

## critical_modules（tester / reviewer 必触发）

- <列 1-3 个项目里"改错会出大事"的模块或关键词>

## 设计参考

- <项目对标的产品 / 框架，写一行即可>
```

**最少只填这两个 section** 即可跑。如果不知道填什么：

- `critical_modules` — 想想你项目里哪些代码改错了会半夜被叫醒、会赔钱、会道歉
- `设计参考` — 项目的主要对标对象，空着不填也行（architect 会用通用设计方法）

完整模板和填写提示见 `docs/claude-md-template.md`。典型项目示例见 `examples/*-snippet.md`。

---

## 3. 第一次跑（2 分钟）

在 workspace 根或者项目目录启动 Claude Code：

```bash
cd <your-project>     # 或 cd <your-workspace>
claude
```

然后在会话里：

```
/roundtable:workflow 设计一个 XXX 功能
```

### 会发生什么（第一次跑）

1. **目标项目识别** —— 如果你从 workspace 根启动，roundtable 会 AskUserQuestion 让你选 target_project；如果你在项目内启动，它用 `git rev-parse` 直接识别。**一次点选，session 内记住**
2. **工具链自动检测** —— 读你项目根的 `Cargo.toml` / `package.json` 等，推断 lint / test 命令
3. **加载你的 CLAUDE.md** —— 读刚才配置的「# 多角色工作流配置」section
4. **架构师激活** —— architect skill 开始做设计，遇到决策点**弹窗让你选 A/B/C**（AskUserQuestion）
5. **落盘文档** —— 设计确认后写到 `<project>/docs/design-docs/<slug>.md`
6. **编排后续角色** —— 按任务规模调用 developer / tester / reviewer / dba

**每个阶段之间都会等你确认**，不自动推进到下一步。

---

## 4. 文档产出（workflow 跑完后你会看到）

你的项目下多出这些目录（如果本来没有，roundtable 会创建）：

```
<project>/docs/
├── analyze/              ← analyst 的调研报告（如调用）
├── design-docs/          ← architect 的设计文档
├── exec-plans/
│   ├── active/           ← 进行中的执行计划
│   └── completed/        ← 已完成归档
├── testing/plans/        ← tester 的测试计划
├── reviews/              ← reviewer/dba 的关键审查落盘
├── decision-log.md       ← DEC-xxx 决策注册表
└── log.md                ← 设计层文档时间索引
```

每个主题用一个 **slug**（kebab-case 英文，如 `user-auth`）串联 `analyze/user-auth.md` → `design-docs/user-auth.md` → `exec-plans/active/user-auth-plan.md`。

---

## 5. 常见首次使用问题

**Q: 我在 workspace 根启动 Claude Code，但它不识别子项目**
A: 确认子项目是 git 仓库（有 `.git/` 目录）。roundtable 的 D9 识别机制扫的是一级子目录里的 `.git/`。非 git 目录不会被列入候选。

**Q: 工具链自动检测错了 / 没检测到**
A: 在项目 CLAUDE.md 的「## 工具链覆盖」section 手动声明 lint / test 命令。CLAUDE.md 的值**覆盖**自动检测。

**Q: Architect 没弹决策窗口，只是文字问"你觉得呢"**
A: Architect 的设计明确要求用 AskUserQuestion 工具。如果没弹窗，可能是 AskUserQuestion 工具当前不可用（MCP 连接问题）。重启 Claude Code 试试。

**Q: 我项目原本有 `.claude/agents/` 自建的 agent 定义，会冲突吗？**
A: 会。Claude Code 的合并规则是 project level > user level（plugin 装在 user scope）。本地同名 agent 会覆盖 plugin 的版本。迁移方案见 `docs/migration-from-local.md`。

**Q: 我想先试试 roundtable 但不改主 CLAUDE.md**
A: 可以建 `CLAUDE-local.md` 或 `CLAUDE.local.md`（gitignored）放配置，Claude Code 会把所有 CLAUDE.md 自动合并加载。

---

## 6. 下一步

- 看 `docs/design-docs/roundtable.md`（§0 决策总览）了解 plugin 架构
- 看 `docs/exec-plans/active/roundtable-plan.md` 看路线图
- 有问题提 GitHub Issue

要实际开发新功能时，直接 `/roundtable:workflow <任务描述>` 起流程即可。
