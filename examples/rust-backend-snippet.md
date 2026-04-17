# 示例：Rust 后端服务 / CLI 项目

本示例给你一个**典型 Rust 后端项目**（如 Web API、CLI 工具、区块链节点）的 `# 多角色工作流配置` section。直接复制到你项目的 `CLAUDE.md`，然后按项目实际情况改几个字段。

---

## 📋 直接抄这段

```markdown
# 多角色工作流配置

## critical_modules（tester / reviewer 必触发）

- 认证 / 授权 / 签名验证（任何涉及 JWT、API key、签名、权限判断的代码）
- 金额计算 / 账户余额 / 账单生成（精度、并发、溢出风险）
- 支付 / 退款 / 结算相关路径
- 数据库 migration（表结构、索引、约束变更）
- 并发热路径（使用 `tokio::sync`、锁、channel 的代码）
- 性能敏感代码（需要 benchmark 验证的热函数）

## 设计参考

- API 设计参考 <你项目对标的产品>，重点对齐 <某个特性>
- 错误处理参考 <某个 Rust 生态标准>（如 `thiserror` / `anyhow` 风格）
- 并发模型参考 <某个开源项目>

## 工具链覆盖（可选）

<通常不用填 — roundtable 读 Cargo.toml 自动用 `cargo clippy --all-targets -- -D warnings` 和 `cargo test`。仅在以下情况填：>

- lint: `cargo xclippy`（如有自定义 clippy alias）
- test: `SUI_SKIP_SIMTESTS=1 cargo nextest run`（如有特殊环境变量需求）

## 文档约定

- 决策日志 `docs/decision-log.md`（DEC-xxx 递增，不删旧条目）
- 操作日志 `docs/log.md`（append-only）
- 主题 slug 用 kebab-case 英文

## 条件触发规则

- 涉及金额 / 精度计算 → **禁止浮点运算**，使用定点整数（如 `u128` 表示纳级精度）；测试必须用真实精度值，不用 toy 数值
- 异步测试必须用 `#[tokio::test]`，不用 `#[test]`
- **不允许禁用测试** —— 所有测试必须通过；禁止 `#[ignore]` 绕过
- **不允许 `#[allow(dead_code)]` / `#[allow(unused)]`** —— 修根因
- 完成开发后必须跑 `cargo xclippy`
- 修改 `migrations/` → 必须运行 `diesel migration run` 验证
- 新增 crate → 更新项目的 ARCHITECTURE.md 或 crate 清单
- 涉及安全敏感操作（签名、权限、资产）→ 查阅 `docs/SECURITY.md`
- Git commit message 用英文，格式 `type: short description`（type: feat/fix/docs/refactor/chore/test）
```

---

## 💡 填写时要调整的点

1. **critical_modules** —— 按项目实际业务改：
   - 如果是 Web API 项目：加入 "CORS / session 处理 / SQL 构造"
   - 如果是区块链节点：加入 "共识 / 状态机 / P2P 消息"
   - 如果是 CLI 工具：通常只需保留金额 / 签名 / 权限相关
2. **设计参考** —— 具体写对标谁 / 参考什么框架 / 为什么参考
3. **条件触发规则** —— 按项目语言 / 栈 / 业务的硬约束写，没有就删
4. **工具链覆盖** —— 如果你的 `Cargo.toml` 没用任何特殊 alias，整个 section 可以省略

---

## 🧪 验证配置是否生效

填完 CLAUDE.md 后，运行：

```
/roundtable:workflow 设计一个简单的 health check endpoint
```

观察：
- architect skill 的决策引用是否**提到**了你的"设计参考"（比如说 "根据你声明的 XXX 对标"）
- 如果任务涉及金额（testset 里加 "涉及金额计算"），**tester 应该被触发**
- developer 跑的 lint/test 命令**匹配你项目的 Cargo.toml**（或你的覆盖声明）

这三项都符合说明配置生效了。
