# 项目 CLAUDE.md 接入模板

把本模板的「# 多角色工作流配置」section **复制到你项目根目录的 `CLAUDE.md`**（若还没有则新建），然后按项目实际情况填空。

- **critical_modules** 是必填 —— 决定了 tester / reviewer 是否触发
- 其他 section 可选 —— 留空则走 roundtable 的自动检测和通用兜底规则
- 改动后无需重启 Claude Code，下次 `/roundtable:workflow` 调用时自动加载

---

## 📋 完整模板（直接复制到你的 `CLAUDE.md`）

```markdown
# 多角色工作流配置

> 本 section 由 `roundtable` plugin 读取。每个项目独立填写。

## critical_modules（tester / reviewer 必触发）

<列出本项目中"改错会出大事"的模块 / 关键词。命中任一时，`/roundtable:workflow` 强制派发 tester 和 reviewer>

- <关键模块 1>
- <关键模块 2>
- <关键模块 3>

## 设计参考

<本项目对标的产品 / 框架 / 规范。影响 architect skill 做架构决策时的参考上限>

- <参考 1>
- <参考 2>

## 工具链覆盖（可选，缺省走自动检测）

<仅在 roundtable 根文件自动检测不准或项目有特殊约定时填；空缺时 roundtable 按项目根的 Cargo.toml / package.json / pyproject.toml / go.mod / Move.toml 自动识别并用默认命令。首轮 `/roundtable:workflow` 的 P0.1 脚手架阶段由 orchestrator 在 developer 完成脚手架后代填本 section —— developer 在 Resource Access 里没有本文件的 Write 权限，只在报告里建议值；orchestrator 按报告写入>

- package manager: `<如 pnpm@9.15.0 / cargo / uv / bun@1.3 / ...>`（可选）
- runtime: `<如 Node ">=20" / Python ">=3.12" / Rust 1.80+ / ...>`（可选）
- lint: `<项目 lint 命令>`
- test: `<项目 test 命令>`
- build: `<项目 build 命令>`（可选）
- dev: `<开发模式命令，如 tsx 热加载 / cargo watch>`（可选）

## 文档约定（可选，缺省走 roundtable 通用约定）

- 决策日志 `docs/decision-log.md`（追加 DEC-xxx，不删旧条目）
- 操作日志 `docs/log.md`（append-only，顶部最新）
- 变更记录写在各 doc 底部"变更记录"章节，不入 log.md
- 主题 slug 用 kebab-case 英文，贯穿 analyze → design-docs → exec-plans → testing

## 条件触发规则（可选，按项目业务写硬性约束）

<每条格式：`涉及 <条件> → <必须做 / 禁止做>`。这些规则会作为 architect / developer / tester / reviewer 的硬约束>

- <条件 → 动作 1>
- <条件 → 动作 2>

## 角色偏好（可选）

### developer 执行形态默认

- **`developer_form_default`**: `inline` | `subagent`（可选，省略默认 `subagent`）
  - `inline`：本项目 developer 角色默认在主会话内联执行，AskUserQuestion 直接可用，用户全程可见
  - `subagent`：本项目 developer 角色默认走 Task 派发子会话，context 隔离（DEC-001 D8 默认行为）
  - 适用场景：
    - 选 `inline` 的项目：小项目 / 单人开发 / 紧跟过程偏好 / 平均任务 < 20k token
    - 选 `subagent` 的项目：大型 refactor 频繁 / 多 developer 并行需求 / 团队协作 context 隔离要求
  - 注意：**仅 developer** 支持此键；tester / reviewer / dba / research 永远 subagent（per DEC-005）
  - 每次派发仍可覆盖：用户在任务描述里写 `@roundtable:developer inline` 或 `@roundtable:developer subagent` → per-dispatch 生效
```

---

## 💡 填写提示

### critical_modules 怎么选？

问自己：**如果这段代码有 bug 上生产，会不会半夜被叫醒 / 赔钱 / 道歉**？如果是 yes，列进来。

- 金额 / 账户 / 权限判断
- 并发 / 事务 / 分布式一致性
- 签名验证 / 输入校验 / 权限检查
- 性能敏感热路径（需要 benchmark 才放心）
- 外部系统集成（DB / 消息队列 / 支付 / 身份）

### 设计参考怎么写？

不只是"像谁"，**更重要的是"为什么像"**。简单一句话写清理由，架构师会参考着做决策。

示例：
- ❌ `- Stripe API`（太泛）
- ✅ `- 支付 API 对标 Stripe（idempotency key + webhook 事件模型）`

### 工具链覆盖什么时候需要？

大部分项目**不需要**填 —— roundtable 的自动检测（读项目根标识文件）够用。需要填的情况：

- 有自定义 lint 配置（如 `cargo xclippy` alias、自写的 pre-commit hook）
- 测试命令需要特殊环境变量（如 `FOO=bar pytest`）
- monorepo 根目录没有标识文件，需要手工指定
- **新项目首轮接入**：architect 决定了技术栈（pnpm / bun / cargo / uv 等）但还没装，P0.1 脚手架跑完后 orchestrator 代填具体命令和版本号，让后续 Px 的 developer / tester 能直接引用

### 谁填、何时填、怎么填？

| 问题 | 回答 |
|------|------|
| **谁填** | **orchestrator**（主会话 Claude）。developer 在 `Resource Access` 里对 `CLAUDE.md` 没有 Write 权限，只在完成脚手架后的报告里建议值，由 orchestrator 写入 |
| **何时填** | 首轮 `/roundtable:workflow` 的 **P0.1 脚手架阶段完成后**，进入 P0.2 前；这时 `package.json` / `Cargo.toml` / `pyproject.toml` 刚就位，工具链命令已确定 |
| **为什么走 orchestrator** | 并行 dispatch 时多个 developer 可能同时想改 `CLAUDE.md`，由 orchestrator 串行化避免 race（同 `exec-plan` checkbox 的回写纪律）|
| **后续变更** | 加 `ESLint` / 换 `biome` 等会改 lint_cmd 的时候；也由 orchestrator 代写 |

### 回填样板

两个典型场景的 "工具链覆盖" 完成态：

**TS + pnpm + vitest（绿地项目典型）**：

```markdown
## 工具链覆盖

> 由 P0.1 脚手架阶段回填（2026-04-18）。DEC-003 确定：pnpm + Node 20+ + TypeScript strict ESM + vitest + tsx。

- package manager: `pnpm@9.15.0`
- runtime: Node `>=20`（`engines` 与 cli.ts 双重校验）
- lint: `pnpm lint`（当前指向 `tsc --noEmit`；ESLint 配置在 P0.8 前补齐）
- test: `pnpm test`（指向 `vitest run`，`passWithNoTests: true`）
- build: `pnpm build`（`tsc` 产出 `dist/cli.js`）
- dev: `pnpm dev`（`tsx src/cli.ts`，不 bundle）
```

**Rust + cargo + nextest（服务端典型）**：

```markdown
## 工具链覆盖

> 由 P0.1 脚手架阶段回填。DEC-002 确定：Rust 1.80+ / cargo workspace / nextest 并行跑测试。

- package manager: cargo（workspace root `Cargo.toml`）
- runtime: Rust `1.80+`（`rust-toolchain.toml` pinned）
- lint: `cargo clippy --workspace --all-targets -- -D warnings`
- test: `cargo nextest run --workspace`（CI fallback `cargo test` 若 nextest 不可用）
- build: `cargo build --release --workspace`
- dev: `cargo watch -x check -x test`（本地）

### 条件触发规则用来干嘛？

作为"硬约束"传给所有角色（architect / developer / tester / reviewer）。示例：

- `涉及金额计算 → 禁止浮点，使用定点整数`
- `涉及用户密码 → 必须经过 bcrypt / argon2，禁止 MD5/SHA1`
- `修改 migrations/ → 必须运行 <迁移命令> 验证`
- `新增 API endpoint → 必须更新 docs/api-docs/ 对应文件`

---

## 🧪 最小可用示例（任何项目起步都够用）

如果你第一次接入，嫌上面模板太长，这个**最小版本**也能工作：

```markdown
# 多角色工作流配置

## critical_modules（tester / reviewer 必触发）

- <一个关键模块或关键词>

## 设计参考

- <项目对标的一个产品 / 框架>
```

只填这两 section 也能跑。随项目成熟度提升再补其他 section。

---

## 📖 典型项目的填法示例

见 `examples/` 目录下按语言 / 场景分类的示例片段：

- `examples/rust-backend-snippet.md`（Rust 后端服务 / CLI）
- `examples/ts-frontend-snippet.md`（TypeScript + React 前端）
- `examples/python-datapipeline-snippet.md`（Python 数据管道）

---

## ❓ 常见问题

**Q: 我的项目已经有 `CLAUDE.md` 了，怎么办？**
A: 把本模板的 `# 多角色工作流配置` section 追加到文件末尾即可，不要覆盖你已有的内容。roundtable 只读这个 section，不干扰其他内容。

**Q: 我团队多人协作，配置怎么共享？**
A: `CLAUDE.md` 是 git 管控的，commit 进项目，所有人 pull 下来就有同一套配置。个人临时覆盖可以放 `CLAUDE-local.md` / `CLAUDE.local.md`（gitignored，本仓库 `.gitignore` 里已经有）。

**Q: 不同子项目（如 monorepo）critical_modules 不同怎么办？**
A: roundtable 的 D9 目标项目识别会识别到具体子项目，读那个子项目的 `CLAUDE.md`。所以每个子项目单独写自己的 section 即可。

**Q: critical_modules 留空会怎么样？**
A: 所有 role 会走"通用兜底规则"（金额 / 权限 / 并发 / 安全相关自动视为关键）。对新项目够用，但精准度不如你自己列。

**Q: `developer_form_default` 放 `CLAUDE.md` 不是违反 DEC-001 D2「零 userConfig」吗？**
A: 不违反。DEC-001 D2 禁止的是 plugin **元协议配置**（如 agent 调度、Resource Access、Escalation schema 等 plugin 内部行为），这些必须硬编码在 prompt 本体。而 `developer_form_default` 是**业务偏好**——"本项目开发者想不想看到 developer 的中间过程"是项目级选择，和 `critical_modules` / `设计参考` / `工具链覆盖` 同属一类，放 `CLAUDE.md` 合规。

**Q: 完全不写 `角色偏好` section 会怎样？**
A: 零影响，等价于当前默认行为——developer 走 subagent 派发（DEC-001 D8）。只有明确想切 `inline` 或显式声明保持 `subagent` 时才填。
