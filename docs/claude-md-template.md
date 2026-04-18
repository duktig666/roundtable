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

<仅在 roundtable 根文件自动检测不准或项目有特殊约定时填；空缺时 roundtable 按项目根的 Cargo.toml / package.json / pyproject.toml / go.mod / Move.toml 自动识别并用默认命令>

- lint: `<项目 lint 命令>`
- test: `<项目 test 命令>`
- build: `<项目 build 命令>`（可选）

## 文档约定（可选，缺省走 roundtable 通用约定）

- 决策日志 `docs/decision-log.md`（追加 DEC-xxx，不删旧条目）
- 操作日志 `docs/log.md`（append-only，顶部最新）
- 变更记录写在各 doc 底部"变更记录"章节，不入 log.md
- 主题 slug 用 kebab-case 英文，贯穿 analyze → design-docs → exec-plans → testing

## 条件触发规则（可选，按项目业务写硬性约束）

<每条格式：`涉及 <条件> → <必须做 / 禁止做>`。这些规则会作为 architect / developer / tester / reviewer 的硬约束>

- <条件 → 动作 1>
- <条件 → 动作 2>
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
