# 创建 Sprint 流程

当用户要开始多步骤的功能/修复/改进/调研时触发。

## 流程

```
1. 检查前置条件
   |- ai/PROJECT.md 不存在 -> 提示用户先运行 /pflow-init
   |- 已有活跃 sprint -> 要求先结束当前 sprint
   +- 无活跃 sprint -> 继续

2. 明确 sprint 目标
   用户可以一句话描述需求，推断并生成 BRIEF.md 草稿供确认。
   也可以逐步对话明确：目标、成功标准、范围。

   读取 ai/KNOWLEDGE.md，如有与本次目标相关的规则，在制定计划时参考。

3. 创建 sprint 文件
   ai/sprints/active/<name>/  (name: 简短英文，连字符连接)
   |- BRIEF.md      <- 填入目标和范围
   |- PLAN.md       <- 与用户共同制定，各 Step 初始状态 [ ]
   |- LOGBOOK.md    <- 初始化: 状态 active（决策/踩坑段留空）
   +- artifacts/    <- 空目录
   （HANDOVER.md 不在此创建——跨会话交接时才按需新建，见 templates.md）

   模板见 references/templates.md。

4. 询问是否开始执行 Step 1
```

## 制定计划的原则

- 每个 Step 可独立验证
- 步骤数通常 3-7 步
- 列出涉及的文件或产出物
- 结构性大改动或需要用户 review 的节点标注 `[检查点]`
- 复杂 sprint 按逻辑段组织 Step（如「地基段」「上层段」），段末放 `[检查点]`；简单 sprint 平铺即可
- 需要派 subagent 执行的 sprint：填 PLAN 的「执行编排」段并按段标注风险（决定交互式 / loop）。机制见 `references/orchestration.md`，默认值可一键带过——不派 subagent 的简单 sprint 直接删掉该段
