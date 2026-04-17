# 示例：TypeScript + React 前端项目

本示例给你一个**典型 TS + React 前端**（如交易前端、Dashboard、SaaS Web App）的 `# 多角色工作流配置` section。

---

## 📋 直接抄这段

```markdown
# 多角色工作流配置

## critical_modules（tester / reviewer 必触发）

- 认证 / 授权（登录、token 存储、session 管理）
- 支付 / 交易下单（涉及金额、订单提交）
- 金额显示 / 精度计算（避免 JS number 精度坑）
- 全局状态管理核心 reducer / store
- 安全敏感组件（密码输入、敏感数据展示）
- 性能敏感页面（首屏 / 长列表 / 实时更新）

## 设计参考

- UI / UX 参考 <你项目对标的产品，如 Linear / Notion / Stripe Dashboard>
- 组件库约定：<自建 / shadcn / MUI / AntD 等>
- 状态管理：<Redux Toolkit / Zustand / Jotai 等>

## 工具链覆盖（可选）

<通常不用填 — roundtable 读 package.json 的 scripts.lint / scripts.test。仅在需要时填：>

- lint: `pnpm lint`（或 `npm run lint` / `yarn lint`，视 package manager）
- test: `pnpm test`（或 `pnpm test --watch=false` 若 CI 环境不接受交互）
- build: `pnpm build`

## 文档约定

- 决策日志 `docs/decision-log.md`
- 操作日志 `docs/log.md`
- 主题 slug 用 kebab-case 英文（如 `order-panel`、`user-profile-edit`）

## 条件触发规则

- 涉及金额显示 → **禁止 Number**，使用 `BigNumber` / `bignumber.js` / `decimal.js`；格式化用项目的统一工具函数
- 涉及用户输入 → 必须经过 zod / yup / io-ts 校验
- 新增 API 调用 → 必须有对应的 loading / error / empty 三态处理
- **不使用 `any`** —— 真需要 escape hatch 用 `unknown` + 类型窄化
- 新增 React 组件 → 必须导出默认 props 类型定义（为 Storybook / 其他引用提供）
- CSS 用 Tailwind（或项目约定的方案），不手写 className 字符串拼接
- Git commit message 用英文，格式 `type: short description`
```

---

## 💡 典型项目变化点

| 项目类型 | critical_modules 重点 |
|---------|----------------------|
| 电商前端 | 购物车 / 结账流 / 订单提交 / 金额计算 / 优惠券应用 |
| SaaS Dashboard | 租户切换 / 权限判断 / Billing / 数据导出 |
| 交易前端 | 下单 / 撤单 / 资金显示 / 实时行情 / WebSocket 重连 |
| Admin / CMS | 权限层级 / 危险操作（删除 / 批量）/ 数据导入导出 |

| 栈组合 | 设计参考怎么写 |
|-------|---------------|
| Next.js + Server Components | App Router 模式对标 Vercel 官方示例；SSR/CSR 分工参考 ... |
| Vite + React | 纯 SPA，UI 对标 XXX，状态管理用 Zustand |
| Remix | Loader/Action 模式参考官方文档 |

---

## 🧪 验证配置生效

```
/roundtable:workflow 设计一个登录表单组件
```

观察：
- architect 引用"设计参考"里的 UI 方案
- 派发 developer 时，lint 命令是你项目的（如 `pnpm lint`）
- 提到金额时 tester 被触发
- reviewer 在审查时注意"不使用 any" / "必须三态处理" 等条件触发规则

---

## ⚠️ TS 项目特别注意

1. **monorepo 场景**：如果是 pnpm workspace / turborepo，roundtable 的 D9 识别只扫一级子目录的 `.git/`。如果 `apps/web/` `apps/admin/` 不是独立 git 仓库，roundtable 会把根当作 target_project。此时 `docs_root` 统一在根的 `docs/`，每个 app 的规则靠条件触发规则区分。
2. **JS 精度坑**：金额 / 时间戳这些**一定要加**"禁止 Number"条件触发规则。JS 默认 `0.1 + 0.2 !== 0.3`，没这条规则 developer 很容易写出 bug。
3. **package manager**：不同 pm（npm / pnpm / yarn / bun）的 lint/test 命令不同。roundtable 读 `package.json` 的 `scripts.lint` 字段，所以先确认你的 scripts 定义正确。
