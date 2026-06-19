---
name: pflow-sprint
description: Sprint 生命周期管理。当用户要做多步骤项目变更时使用。管理 sprint 的创建、推进、结束。单文件修改/配置调整/明确的 bug 修复不需要 sprint，直接改即可。用户主动说"开 sprint"或工作涉及 3+ 步骤、需要设计决策、预期跨会话时建议开 sprint。
---

# /pflow-sprint -- Sprint 生命周期管理

## 何时需要 Sprint

Sprint 适用于需要计划的多步骤工作。以下场景直接改 + commit：
- 单文件修改、配置调整、文档更新
- 明确的 bug 修复（原因和方案都清楚）
- 用户明确说"直接改"

以下场景建议 sprint（用户可拒绝）：
- 3 步以上的多步骤工作
- 需要设计决策的变更
- 预期跨会话的工作
- 用户主动要求

## Sprint 文件

每个 sprint 是 `ai/sprints/active/<name>/` 下的核心三件套 + 产物目录（跨会话交接时再加 HANDOVER.md）：

| 文件 | 职责 |
|------|------|
| BRIEF.md | 目标、成功标准、范围（创建后不改） |
| PLAN.md | 步骤 + 内联状态标记（单一进度真相源） |
| LOGBOOK.md | 决策记录 + 踩坑记录（按需写） |
| HANDOVER.md | 跨会话交接的当前快照（仅跨会话时才建，独立小文件） |
| artifacts/ | demo/截图/脚本等非文档产物 |

### PLAN.md 内联状态

```markdown
## Step 1: 设计数据结构 [done]
## Step 2: 实现核心逻辑 [wip]
## Step 3: 编写测试 [ ]
## Step 4: 阶段审核 [检查点] [ ]
```

标记：`[ ]` pending / `[wip]` in-progress / `[done]` completed / `[skip]` skipped

### 检查点

`[检查点]` 标记的 Step：到达时汇总已完成工作 + 决策，与用户确认后再继续。适合放在结构性大改动、不可逆操作前、跨阶段交接处。详见 `references/progress-flow.md`。

---

## 会话启动行为

项目存在活跃 sprint 时：

```
1. 读取 ai/PROJECT.md
2. 读取 ai/KNOWLEDGE.md（如存在）
3. 读取活跃 sprint 的 PLAN.md + HANDOVER.md（如存在）
4. 输出简要状态：
   "当前项目: xxx
    活跃 sprint: server-migration [Step 3/5]"
5. 等待用户指示
```

无活跃 sprint 时不主动提示。

---

## 操作路由

| 操作 | 触发条件 | 流程文件 |
|------|---------|---------|
| **创建** | 无活跃 sprint + 用户要做多步骤变更 | `references/create-flow.md` |
| **推进** | 有活跃 sprint + 执行 Step | `references/progress-flow.md` |
| **结束** | 成功标准达成 或 未完成就结束 | `references/finish-flow.md` |

---

## 编排执行（复杂 sprint 按需）

Step 涉及多步实现、跨多文件、或需要独立对抗审查时，主会话不亲自下场，而是派 subagent 执行、派独立 agent 审查，自己只读结论、把控节奏——把上下文留给编排。机制（三角分工 / 派活模板 / 交接分层 / 段末检查点 / 运行形态）见 `references/orchestration.md`，需要时再读。

机械小修（缺文件、改文案、改常量、单文件明确改动）主会话直接做，不必编排——简单工作不该被流程拖慢。

---

## 计划调整规则

- **调整计划**（改步骤、改顺序、增删 Step）：直接修改 PLAN.md，顶部追加变更记录
- **调整目标**（成功标准或范围根本变化）：关闭当前 sprint，新建 sprint

变更记录格式：
```markdown
## 计划变更记录
- [YYYY-MM-DD] <变更内容> -- 原因: <为什么>
```

---

## ROADMAP 回写规则

所有写入都需用户确认；标注来源 `<- sprint-name`。

| 触发点 | 操作 |
|--------|------|
| create 后有延期工作 | 询问是否写入 ROADMAP |
| progress 中发现超范围问题 | 询问是否写入 ROADMAP |
| finish(closed) 有未完成 Step | 逐条询问是否写入 ROADMAP |
| finish(completed) 发现新问题 | 追加到 ROADMAP |

## 文件模板

创建或结束 sprint 时，读取 `references/templates.md` 获取模板。
