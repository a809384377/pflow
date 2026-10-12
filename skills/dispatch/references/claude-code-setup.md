# Claude Code 环境配置

把 dispatch 的并发、嵌套、默认模型约定变成系统层的硬上限。配置一次即可，派活时不用读本文件。

在 `~/.claude/settings.json`（对所有项目生效）或项目的 `.claude/settings.json` 的 `env` 里加入：

```json
{
  "env": {
    "CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH": "1",
    "CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS": "3",
    "CLAUDE_CODE_SUBAGENT_MODEL": "opus"
  }
}
```

| 变量 | 作用 |
|---|---|
| `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1` | subagent 不能再派 subagent |
| `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=3` | 同时运行的 subagent 最多 3 个 |
| `CLAUDE_CODE_SUBAGENT_MODEL=opus` | 派活时没写模型档位，就用 opus 兜底 |

提示词里的约定只是请求，模型可能忽略；写进配置后由系统强制执行。
