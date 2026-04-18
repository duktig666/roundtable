---
description: Bug fix workflow. Skips design phase and routes directly through developer → (optional tester/reviewer/dba) with mandatory regression test.
argument-hint: <bug 描述 或 issue 编号>
---

# Bug Fix 工作流

你即将为以下 bug 编排修复流程：

**Bug 描述 / Issue**：$ARGUMENTS

---

## 执行前提

本命令要求项目已按 roundtable 约定组织 docs 目录。若尚未配置，先提醒用户按 plugin 仓库的 `docs/claude-md-template.md` 补齐 `target_project/CLAUDE.md` 的「# 多角色工作流配置」section。

---

## 步骤 0：项目上下文识别

激活 **`_detect-project-context` skill**（通过 `Skill` 工具），完成全部 4 步：D9 识别 + 工具链检测 + docs_root + CLAUDE.md 业务规则加载。

后续派发 developer / tester / reviewer / dba 等 agent 时，必须在 prompt 里注入识别结果。

---

## 步骤 1：定位问题

1. 如有 GitHub Issue 编号，用 `gh issue view <n>` 读取 Issue 描述和复现步骤
2. 如仅描述现象，先在对话中分析 / 探索定位可疑文件
3. 复杂定位可派发 `@roundtable:analyst` skill 协助调研（只在定位不清时；简单 bug 直接跳过）
4. **跳过 design 阶段**（bug fix 通常不需要新设计）

## 步骤 2：分析根因

- 阅读相关代码 + `git blame` 看历史
- 复杂 bug 把分析过程落盘到对话（不创建新 design-doc）
- 如果发现 bug 是设计缺陷而非实现缺陷（需要改 design-doc / 新增 DEC），**中止 bugfix 流程**，改走 `/roundtable:workflow` 走架构流程

## 步骤 3：Fix + 回归测试

派发 `@roundtable:developer` agent 实施修复，派发 prompt 里注入：
- target_project / docs_root / lint_cmd / test_cmd
- bug 描述 / 根因分析
- 明确要求：**必须补充回归测试**，确保同类 bug 不再出现
- 明确要求：Fix 不附带无关重构

## 步骤 4：验证

developer 完成后：
- 运行 `lint_cmd` 和 `test_cmd`，确保无回归
- 手动验证修复效果（如 bug 有明确复现步骤，让用户确认）

## 步骤 5：关键模块审查（按需）

- 若涉及 target_project CLAUDE.md 的 `critical_modules` 中任一关键词，派发 `@roundtable:reviewer` agent 审查
- 若涉及数据库 schema / migration / SQL 变更，派发 `@roundtable:dba` agent 审查
- Bug fix **默认不触发** tester（developer 已补回归测试）
- 仅当 bug 暴露出"边界条件未覆盖"类问题且涉及关键模块时，才补充调用 tester 加强对抗性测试

---

## 报告格式

修复完成后，向用户输出：

```markdown
## Bug 描述
[问题现象]

## 根因分析
[为什么出现]

## 修复方案
[改了什么文件 / 函数]

## 回归测试
[新增的测试文件 / 用例]

## 验证结果
[lint / test 通过情况；手动验证结果]

## 审查结论（如派发了 reviewer / dba）
[审查意见摘要]
```

---

## 执行规则

1. **跳过 design**：bug fix 不走 architect
2. **必有回归测试**：developer 必须补回归测试，不能"只改代码不加测试"
3. **不扩大范围**：Bug fix 只修该 bug，相关但无关的问题单独另开 issue / PR
4. **发现设计缺陷及时中止**：如果 bug 实际是设计错误，改走 `/roundtable:workflow` 流程重新设计
