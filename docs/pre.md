# 功能
## 核心设计
- 定义多角色Agent: analyst -> architect -> developer -> tester -> reviewer -> dba(可选)
- 定义Workflow编排多角色，按照工作流方式执行(Phase Matrix机制根据需求派发)
- 多项目自动定位 doc_root，工作流自动输入输出文档
- bug类任务使用bugfix流程，lint检查和规范文档
- 参考llm-wiki思想 decision-log.md记录关键架构决策，log.md记录文件变更，INDEX.md维护doc文档索引
- analyst借鉴gstack进行六问检验（后优化为2必须4按需），提高分析调研质量

## 补充设计
- developer要进行单元测试，tester进行e2e测试，前端需要Playwright测试ui和交互。
- analyst和architect 从agent改为skill 需要用户决策时进行AskUserQuestion弹窗
- analyst和architect 完成后等待用户提问，问题已FAQ形成追加到文末，确认后进入下一阶段。方案和文档变更加入当前文档。
- architect需要进行 架构设计->用户FAQ->用户确认->编写执行计划->用户确认 下一阶段developer实施。
- analyst和architect 需要用户决策的问题及时提出（终端采用AskUserQuestion），优化项：无依赖决策一次AskUserQuestion多项决策（尽可能降低调用次数，减少人干预的时间）

# 现状问题分析
## 文档设计
decision-log.md 的设计
1. 无论怎样的决策都会写入，会迅速膨胀
2. 格式太过臃肿，什么选项理由都记，太多。现在更像是决策日志。初心是希望记关键架构决策（用最简洁的话记最关键的内容）
3. decision-log 对设计进行约束是否合理？
log.md记录文档变更感觉没有什么价值
docs/faq.md 没有必要这个文档和机制
INDEX.md 是否有必要在每次新文档生成都去写？如果lint执行后去维护是不是更好，频繁些降低效率和消耗更多token。

## AskUserQuestion
AskUserQuestion调用的设计是否是有必要的，虽然我很是喜欢，但是为了tg的兼容性 agents skills commands 等都做了很多冗余的设计。

## 自动定位文档路径
自动定位文档路径需要提前注入，现在的注入方式是否合理。

## agents skills commands
1. subagent 和 inline 的设计，在agents多次提到是否有用。
2. agents skills commands当前设计太过臃肿
3. 我正在考虑全面重构Roundtable，所以agents skills commands有没有必要用全英文去写。
4. agents是否合理 ，是否需要skills化

---

接下来我要重构roundtable,# 功能部分介绍了我的需求，# 现状问题分析部分是现在有很多的问题
1. 考虑全面将agents skills commands英文化
2. agents skills commands 太过臃肿，考虑极简设计，减少token消耗
3. log.md 没必要就删除
4. decision-log.md 是否有必要，有必要就极简存储并只存非常重点内容，当然也可以不要这个机制

执行计划输出到 roundtable/docs/exec-plans/active
方案输出到 roundtable/docs/design-docs

重点：忘掉过去的设计，我要全面重新重构。 设计太过臃肿，太耗费token。

