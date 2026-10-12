# pflow — Claude Project Flow

一套轻量的 AI 协作项目管理框架，为个人开发者与 Claude Code 协同工作设计。

> A lightweight project-flow framework for solo developers working with Claude Code. Four skills that give any project a persistent, file-based memory — so a fresh session can always pick up where the last one left off.

## 核心理念：文件即记忆

所有项目状态、迭代进度、设计决策都持久化在本地文件里，不依赖任何会话上下文。会话中断、上下文爆炸、几个月后回来接手——新会话读几个文件就能继续。

## 解决什么问题

- 会话中断或上下文爆炸后，新会话无法接手
- 项目迭代缺记录，几个月后不知道当初为什么这么做
- 个人项目缺少系统性的变更追踪和文档管理
- 现有协作框架对个人小项目过于复杂

## 四个 skill

| Skill | 作用 | 何时用 |
| --- | --- | --- |
| `/pflow-init` | 初始化项目工作区（生成 `CLAUDE.md` 与 `ai/` 结构） | 新项目，或已有项目首次接入 |
| `/pflow-spec` | 设计方案阶段：需求 → 对话设计 → 冻结 spec | 复杂需求动手前的可选前置 |
| `/pflow-sprint` | Sprint 生命周期管理（创建 / 推进 / 结束），含编排节奏（交接分层 / 检查点） | 多步骤、需跨会话的变更 |
| `/dispatch` | 通用派活：派不派、派活单、回报验真、独立审查与验收、修复与刹车、长任务托管 | 准备派任何 subagent 之前；可脱离 pflow 单独使用 |

装好后，既可以直接输入 `/pflow-init` 等命令触发，也会在你描述对应意图（如「初始化项目」「先理一下方案」「开个 sprint」「派几个 agent 去做」）时自动触发。

## 安装

把四个 skill 复制到 Claude Code 的 skills 目录即可。

个人级（所有项目都能用）：

```bash
git clone https://github.com/a809384377/pflow.git
cp -r pflow/skills/* ~/.claude/skills/
```

项目级（只在某个项目里可用）：

```bash
cp -r pflow/skills/* <你的项目>/.claude/skills/
```

新开一个会话后生效。

## 快速上手

1. 在项目根目录触发 `/pflow-init`，生成 `CLAUDE.md` 和 `ai/` 工作区。
2. 复杂需求先用 `/pflow-spec` 出一份冻结的设计方案；简单改动直接跳过。
3. 开始干活时用 `/pflow-sprint` 起一个 sprint，全程的进度、决策、交接都落在文件里；需要派 subagent 时会按 `/dispatch` 的做法派活、审查、验收。
4. 会话中断也不怕——新会话按 `ai/` 里的文件接着干。

## 工作区结构（运行 `/pflow-init` 后）

```
CLAUDE.md              # 项目入口，约定会话开始读哪些文件
ai/
  PROJECT.md           # 项目全貌
  ROADMAP.md           # 待办池
  KNOWLEDGE.md         # 跨 sprint 沉淀的规则与模式
  sprints/
    active/<name>/     # 进行中的 sprint（简报 / 计划 / 进度日志 + 产物）
    archive/           # 已完成的 sprint
  pm/                  # 产品流程产物（需求、设计稿、demo、评审），按需创建
  tech-design/         # 结构真相体系（架构文档 + 代码地图 + 校验脚本），可选启用
  scratch/             # 跨 sprint 临时工作区
  cache/               # 机器产物（gitignored）
```

已有 pflow 项目重新运行 `/pflow-init` 会按新结构迁移；历史项目可以用它补建结构真相文件。

## 许可证

[MIT](./LICENSE)
