# 推进 Sprint 流程

按 PLAN.md 逐步执行。

## 流程

```
1. 读取 PLAN.md 获取当前 Step（第一个 [ ] 或 [wip]）
   读取 HANDOVER.md（如存在）了解上下文

2. 判断 Step 类型
   |- [检查点] -> 进入检查点子流程（见下方）
   +- 无标注 -> 直接执行

3. 执行当前 Step
   |- 更新 PLAN.md Step 状态为 [wip]
   |- 机械小修主会话直接做；多步/需独立审查 -> 按 references/orchestration.md 派 subagent 执行、只读结论
   |- 遇到决策分岔 -> 追加到 LOGBOOK.md 决策记录段
   +- 发现超范围问题 -> 与用户确认后追加到 ROADMAP

4. Step 完成时
   |- 按 PLAN.md 定义的验证方式验证
   |- 更新 PLAN.md Step 状态（[wip] -> [done] 或 [skip]）
   +- 简短确认: "Step N 完成"
```

### 何时写 LOGBOOK

LOGBOOK 不需要每步都写。只在以下情况追加：
- 做了重要决策 -> 追加决策记录段
- 发现异常/关键信息 -> 追加到踩坑记录段
- 会话即将结束但 sprint 未完成 -> 整段覆盖 HANDOVER.md（独立小文件，保持短，不堆临时状态）
- （复杂编排）Step 完成且有跨 Step 契约 -> 执行进度段记指针 + 关键对接点，细节落 scratch（不抄全文）

## 检查点子流程

```
1. 汇总本阶段已完成工作
   - 从 PLAN.md 提取已完成 Step 摘要
   - 从 LOGBOOK.md 提取关键决策

2. 向用户呈现汇总 + 确认
   "本阶段已完成:
    - Step 1: XXX
    - Step 2: XXX
    关键决策: D1 选择了 X 方案
    请确认是否继续？"

3. 根据用户反馈
   |- 确认 -> Step 标记 [done]，进入下一 Step
   |- 需要调整 -> 修改 PLAN.md + 追加变更记录
   +- 触发评审 -> 与用户讨论评审方案，执行后回到确认
```
