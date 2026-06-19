---
name: pflow-init
description: 当用户要在新目录或已有项目中搭建项目工作区时使用。初始化根 CLAUDE.md 与 ai/ 目录（含 PROJECT.md、ROADMAP.md、KNOWLEDGE.md、sprints/、scratch/、cache/）等框架文件。支持已有 pflow 项目从旧结构迁移到新 ai/ 收纳结构。即使用户说"初始化项目"、"搭建工作区"、"加入迭代框架"等类似表达，都应触发此 skill。
---

# /pflow-init — 项目工作区初始化

为项目搭建基于「文件即记忆」理念的工作区结构。除 CLAUDE.md 外的所有 AI 协作产物收纳到 ai/。支持新项目、已有项目、旧版 pflow 项目迁移三种场景。初始化完成后，使用 `/pflow-sprint` 进行 sprint 管理。

## 路径检测

```
调用 /pflow-init
      │
      ├── 已有 ai/PROJECT.md ─────────▶ "项目已初始化"（用户坚持则增量补全）
      ├── 旧版结构（根 PROJECT.md 且存在 ai/sprints/）──▶ Migrate 路径
      ├── 空目录 / 仅有 .git ─────────▶ 新项目路径
      └── 有文件 ──────────────────────▶ 已有项目适配路径
```

---

## 新项目路径

```
1. 收集项目信息
   用户可一次性描述，也可逐步对话。需要了解：
   - 项目名称
   - 一句话描述
   - 主要工具和技术（如 "Next.js + PostgreSQL" 或 "nginx + certbot"）
   - （可选）部署方式
   - （可选）第一个 sprint 方向

2. 生成项目文件
   your-project/
   ├── CLAUDE.md              ← 核心规则 + 入口地图（见模板，唯一保留在根的产物）
   ├── .gitignore             ← 含 ai/cache/、.playwright-mcp/
   └── ai/                    ← 全部 AI 协作产物
       ├── PROJECT.md         ← 项目信息（见模板）
       ├── ROADMAP.md         ← 待办池（见模板）
       ├── KNOWLEDGE.md       ← 规则 + 模式（见模板）
       ├── sprints/
       │   ├── active/        ← sprint 三件套 + artifacts/（由 /pflow-sprint 创建）
       │   └── archive/
       ├── scratch/           ← 跨 sprint 临时工作区（PoC、测试样本）
       └── cache/             ← 机器产物（gitignored）

3. Git 初始化
   ├── 已有 .git ──▶ 跳过
   └── 没有 .git ──▶ git init + .gitignore + 提交 "chore: initialize project workspace"
   .gitignore 根据项目工具和技术生成合适的内容，并包含 ai/cache/、.playwright-mcp/、.DS_Store。

4. 输出文件结构树，提示使用 /pflow-sprint 开始第一个 sprint
```

---

## 已有项目适配路径

### 核心原则

```
绝不删除现有文件    绝不覆盖现有内容    绝不移动现有源码目录
```

### 流程

```
1. 分析现有项目（只读）
   读取可识别的项目配置文件（package.json、Cargo.toml、go.mod、Dockerfile 等）
   读取 README.md、目录结构、git log -15、已有 CLAUDE.md
   检测现有版本号（优先级: 配置文件 > git tag > README 中的版本声明）

2. 向用户汇报分析结果，确认或修正
   "分析完成:
    - 项目名: <推断>
    - 工具与技术: <推断>
    - 主要目录: <列出>
    - 已有 CLAUDE.md: 是/否
    - 检测到版本: <版本> → 规范化为 <v三段版本号> / 未检测到 → v0.1.0
    有需要修正的吗？"

   版本规范化规则:
   ├── "3.1" 或 "v3.1"        → v3.1.0
   ├── "1" 或 "v1"            → v1.0.0
   ├── "3.1.2" 或 "v3.1.2"   → v3.1.2（已符合）
   ├── 非 semver（如 "2024.03"）→ 告知用户，协商确定起始版本
   └── 未检测到               → v0.1.0

3. 外部产出物检测
   如果用户描述中提到产出物在项目目录之外的位置（如 ~/.claude/skills/xxx、
   /opt/xxx、远程服务器路径等），或当前目录是新建的空工作区而要迭代的目标
   在别处：
   ├── 询问用户："目标文件在 <外部路径>，是否将源文件复制到项目的 src/ 下
   │    作为开发基线？（推荐：项目目录作为开发环境，外部位置作为生产环境）"
   ├── 用户同意 ──▶ 复制到 src/，保留原始目录结构
   │    └── 在 CLAUDE.md 中自动生成「开发与部署规则」段落（见模板）
   └── 用户拒绝 ──▶ 跳过，在 ai/PROJECT.md 中记录外部路径供参考

4. 生成框架文件（已存在则跳过）
   ai/
   ├── PROJECT.md
   ├── ROADMAP.md
   ├── KNOWLEDGE.md
   ├── sprints/active/ + archive/
   ├── scratch/
   └── cache/

5. 处理 CLAUDE.md
   ├── 不存在 ──▶ 创建完整版
   └── 已有 ──▶ 展示追加内容（项目入口指引），用户确认后追加

6. 处理 .gitignore
   不存在则按 §新项目路径 标准创建；存在则追加缺失行（ai/cache/、.playwright-mcp/、.DS_Store）

7. 在 ai/PROJECT.md 中记录已有文档文件的位置和用途

8. 提交
   ├── 有 git ──▶ 只 add 新增的框架文件（含 src/ 如有）
   └── 无 git ──▶ git init，首次提交只含框架文件
   提交信息: "chore: adopt pflow project framework"

9. 输出总结（[新增] / [追加] / [未改动] 分栏展示）
```

---

## Migrate 路径（旧版 pflow → 新 ai/ 收纳）

适用于已经采用过 pflow 但 PROJECT.md / ROADMAP.md 仍在根目录、或缺少 scratch/cache 子目录的项目。

```
1. 干跑诊断
   "检测到旧版 pflow 结构，建议迁移到 ai/ 统一收纳：
    - 根目录 PROJECT.md       → ai/PROJECT.md
    - 根目录 ROADMAP.md       → ai/ROADMAP.md
    - 根目录 skill-test-workspace/ 或类似 PoC 目录 → ai/scratch/<原名>/（如有）
    - CLAUDE.md 项目入口段 / 目录约定段需更新
    - .gitignore 需追加 ai/cache/、.playwright-mcp/

    历史归档 ai/sprints/archive/ 内的路径引用保留原样（历史快照）。
    用户文档中的 PROJECT.md / ROADMAP.md 引用仅报告不自动改。
    继续？[y/N]"

2. 用户确认后执行
   ├── git mv 现有文件到 ai/ 对应位置
   ├── 创建 ai/scratch/、ai/cache/（如不存在）
   ├── 改写 CLAUDE.md（diff 预览 → 确认 → 写入）：项目入口段 + 目录约定段（见模板）
   ├── 追加 .gitignore（保留原内容）
   └── 全文 grep `\bPROJECT\.md\b` / `\bROADMAP\.md\b` 在用户文档（不含 src/skills、不含 ai/sprints/archive/）中的引用，
       列出报告供用户自行修订

3. 提交
   "chore: migrate to ai/ unified workspace"

4. 输出迁移摘要 + 待用户处理的引用清单
```

用户拒绝迁移时，旧结构继续可用；后续如需触发，重新调用 /pflow-init 即可。

---

## 生成模板

### CLAUDE.md 模板

```markdown
# 项目约定

## 项目入口
AI 协作产物收纳在 ai/。会话开始按序读：
1. ai/PROJECT.md -- 项目全貌
2. ai/ROADMAP.md -- 待办池
3. ai/KNOWLEDGE.md -- 跨 Sprint 沉淀的规则与模式
4. ai/sprints/active/ -- 是否有进行中的 sprint

## 关键命令
- /pflow-init -- 项目初始化
- /pflow-spec -- 设计方案阶段（复杂需求执行前先出 spec，可跳过）
- /pflow-sprint -- Sprint 生命周期管理
- <项目特有命令，无则删除本段>
```

> **当步骤 3 复制了外部产出物时**，在 CLAUDE.md 模板中追加以下段落：

```markdown
## 开发与部署规则
- 所有代码修改在 src/ 中进行，src/ 是版本化的开发副本
- 生产环境为 <外部路径>，从 src/ 部署
- Sprint 完成时必须：1) src/ 变更已 commit  2) 用户确认后同步到生产环境
- 部署命令：cp -R src/* <外部路径>/
```

### ai/PROJECT.md 模板

```markdown
# <项目名>

## 是什么
<一句话描述>

## 工具与技术
- <列出>

## 项目结构
- ai/ -- AI 协作产物（本文件、ROADMAP、KNOWLEDGE、sprints、scratch、cache）
- <src/ / docs/ / 等项目自有目录，按实际补充>

## 当前版本
v0.1.0 -- 初始版本
```

### ai/ROADMAP.md 模板

```markdown
# Roadmap

## 高优先级
- [ ] <明确的需求或必须解决的问题>

## 待解决的问题
- [ ] <已知但方案未定的问题，sprint 时再讨论具体方案>

## 想法/以后再说
- [ ] <灵感、优化点、非紧急事项>
```

ai/ROADMAP.md 是项目的待办池，sprint 从中取任务。条目可以是明确的需求，也可以是模糊的问题。用 checkbox 标记状态：`[ ]` 待做、`[-]` 进行中、`[x]` 已完成。完成时追加归档路径：`- [x] 需求描述 → ai/sprints/archive/YYYY-MM-DD_completed_<name>/`

从 sprint 流程写入的条目可标注来源：`- [ ] 需求描述 ← sprint-name`。来源标注为可选，手动添加的条目不需要。

对于已有项目，额外包含：
```markdown
## 已有文档
- README.md — <用途>
```

### ai/KNOWLEDGE.md 模板

```markdown
# 项目知识库

## 规则
| # | 范围 | 规则 | 原因 | 来源 Sprint |
|---|------|------|------|------------|

## 模式
| # | 模式 | 适用场景 | 备注 |
|---|------|---------|------|
```

Sprint 结束时，踩坑教训经用户确认后直接写入本文件的规则表。新 Sprint 创建时读取相关条目作为计划参考。
