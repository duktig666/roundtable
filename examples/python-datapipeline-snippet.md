# 示例：Python 数据管道 / ML 项目

本示例给你一个**典型 Python 数据管道、ETL、ML Pipeline 或数据分析**项目的 `# 多角色工作流配置` section。

---

## 📋 直接抄这段

```markdown
# 多角色工作流配置

## critical_modules（tester / reviewer 必触发）

- 数据入库 / schema 写入（去重、幂等、upsert 逻辑）
- 金额 / 计量单位换算（精度、单位一致性）
- 数据校验 / 清洗规则（脏数据过滤、异常值处理）
- Pipeline 幂等性 / 断点续跑机制
- 涉及外部 API 限流 / 重试 / 背压的代码
- 模型推理热路径（批量预测、GPU 使用）

## 设计参考

- Pipeline 编排：<对标 Airflow / Prefect / Dagster>
- 数据校验：<对标 Great Expectations / Pandera>
- ML 实验跟踪：<对标 MLflow / Weights & Biases>

## 工具链覆盖（可选）

<通常不用填 — roundtable 读 pyproject.toml 默认用 `ruff check` 和 `pytest`。仅在需要时填：>

- lint: `ruff check . && mypy .`（如要同时跑 type check）
- test: `pytest -v --cov=src`（如要带覆盖率）
- format: `ruff format`

## 文档约定

- 决策日志 `docs/decision-log.md`
- 操作日志 `docs/log.md`
- 主题 slug 用 kebab-case 英文（如 `etl-user-events`、`feature-store-migration`）

## 条件触发规则

- 金额 / 计量单位 → 使用 `Decimal`，**禁止 float**（浮点累积误差在财务场景会放大）
- 数据结构 → **必须用 `pydantic` / `dataclass` / `TypedDict`**，不用裸 dict 传递
- SQL 构造 → **禁止字符串拼接**，使用参数化查询（防 SQL 注入）
- 新增 pipeline task → 必须有幂等性保证（基于 idempotency key 或 upsert）
- 外部 API 调用 → 必须有超时 / 重试 / 熔断
- DataFrame 操作 → 优先 vectorized，避免 row-wise `.apply()` 除非必要
- 测试数据 → 用 factory（如 `factory_boy`）或 fixtures，不 hardcode
- Git commit message 用英文，格式 `type: short description`
```

---

## 💡 按项目子类型调整

| 子类型 | critical_modules 重点 |
|-------|----------------------|
| ETL 数据入库 | 幂等性 / 去重 / schema 演进 / 数据质量校验 |
| 实时流处理 | 窗口聚合 / 水位线 / 状态存储 / exactly-once 语义 |
| ML 训练 | 训练数据 split / 模型超参固定 / 指标计算 / 实验复现 |
| ML 推理 | 批量推理优化 / GPU 内存管理 / 异常样本兜底 |
| 数据分析 / BI | 指标定义一致性 / 时区处理 / 缺失值策略 |

| 工具栈 | 设计参考怎么写 |
|-------|---------------|
| Airflow-based | DAG 设计对标 Airflow 官方最佳实践；Operator 复用 provider 包 |
| Spark / PySpark | 分区策略参考 ...；序列化用 parquet / delta lake |
| FastAPI + ML | API 设计参考 ...；模型加载用 lazy load |
| Jupyter 探索 → 工程化 | 对标 cookiecutter-data-science 目录结构 |

---

## 🧪 验证配置生效

```
/roundtable:workflow 设计一个从 S3 读日志、聚合小时级指标、写入数据仓库的 pipeline
```

观察：
- architect 的决策引用你声明的 Pipeline 编排参考（如 "按你声明的 Airflow 对标"）
- tester 被触发（涉及"数据入库 / 幂等性"关键词）
- developer 跑的 lint 是 `ruff check`（来自 pyproject.toml）
- reviewer 会对照"禁止 float" / "必须 pydantic" 规则检查代码

---

## ⚠️ Python 项目特别注意

1. **精度陷阱**：财务 / 计量相关**必须用 `Decimal`**。`float` 在累积 / 比较场景会产生误差，`1.1 + 2.2 == 3.3` 是 `False`。
2. **Mutable default argument**：这个 Python 经典坑，developer 应该知道；但 reviewer 要额外盯（`def f(x=[])` 这种）。
3. **ENV 管理**：pipeline 项目常有多套环境（dev / staging / prod），写清 `.env.example` 模板和 `.env` 加载机制；CLAUDE.md 可以加一条条件触发规则 "涉及新 env var → 更新 .env.example 并在 README 记录"。
4. **monorepo 场景**：pyproject.toml 可能在子目录（如 `services/ingest/pyproject.toml`）。roundtable 的工具链检测默认扫 target_project **根**，如果实际在子目录，需 CLAUDE.md 显式覆盖。
