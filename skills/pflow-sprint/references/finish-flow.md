# 结束 Sprint 流程

Sprint 结束有两种状态：
- **completed**: 成功标准达成
- **closed**: 未完成就结束（中断/放弃/方向变更）

## 流程

```
1. 确认结束状态
   |- completed: 逐项核对 BRIEF.md 成功标准，全部通过则继续
   +- closed: 与用户确认关闭原因（中断 / 放弃 / 方向变更）

2. 未完成工作处理（closed 时）
   检查 PLAN.md 中 [ ] 或 [wip] 的 Step:
   |- 有未完成 -> 逐条询问用户是否写入 ROADMAP
   +- 无未完成 -> 继续

3. 追加 Sprint 总结到 LOGBOOK.md
   - 状态段改为 completed / closed
   - 末尾追加 Sprint 总结（模板见 references/templates.md）
   - 总结只写: 目标与结果对照 + 后续注意事项

4. 踩坑教训提炼
   如 LOGBOOK 踩坑记录段有内容:

   a) 逐条过门禁 -- 每条踩坑必须同时通过以下三关，任一不过则淘汰:
      G1 原则级: 能否脱离具体库名/函数名/参数独立表述？不能 -> 淘汰
      G2 可迁移: 换一个模块或项目还成立吗？不成立 -> 淘汰
      G3 模式级: 描述的是可复现的思维方式还是一次修复？后者 -> 淘汰
      校准: "prompts 库 ESC 需 monkey-patch exit()" = 具体方案，淘汰
             "第三方库覆盖默认键绑定时，patch 点要追踪上游变更" = 仍太具体，淘汰
             "进程标识靠唯一 ID 文件，不靠运行时命令名匹配" = 可迁移模式，通过

   b) 存活条目按 KNOWLEDGE.md 现有表格格式起草:
      规则 -> | R-N | 范围 | 规则 | 原因 | 来源 Sprint |
      模式 -> | P-N | 模式 | 适用场景 | 备注 |
      编号接续现有最大值

   c) 向用户展示起草结果，明确标注每条通过了哪三关
   d) 用户确认 -> 追加到 ai/KNOWLEDGE.md 对应表格
      用户否决 -> 仅保留在 LOGBOOK 中

   无踩坑记录或全部淘汰 -> 跳过

5. 归档 sprint 目录
   ai/sprints/active/<name>/
     -> ai/sprints/archive/YYYY-MM-DD_<status>_<name>/

6. 更新 ROADMAP
   |- completed: 标记对应条目 [x] + 追加归档路径；新问题追加
   +- closed: 询问用户是否调整对应条目标记

7. 提交变更
   git status 查看当前状态，与用户确认提交范围后 commit

8. 生产环境同步（如适用）
   如 sprint 涉及 skill 文件变更，询问用户是否同步到 ~/.claude/skills/
```
