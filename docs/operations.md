# 常驻运维手册

## 服务对象

- 计划任务：Codex-WeChat-Bridge
- 启动入口：仓库根目录的 start-codex-bridge.ps1
- 后端：Codex
- 日志：runtime-logs/bridge.log
- 同步游标：用户状态目录的 .wechat-ai-bridge/sync-buf.json
- 私有配置：仓库根目录的 config.json
- 私有令牌：用户目录的 .wechat-ai-bridge/token.json

配置、令牌、数据库、下载文件和日志都不属于 GitHub 交付物。

## 状态检查

~~~powershell
powershell -ExecutionPolicy Bypass -File .\scripts\status-wechat-bridge.ps1
~~~

状态脚本只输出任务状态、运行身份、进程数量以及日志和同步游标的更新时间，不读取 token，也不打印微信用户 ID。

健康状态至少应同时满足：

1. 任务状态为 Running。
2. Bridge 进程数为 1。
3. 日志近期有更新时间。
4. 同步游标近期有更新时间。
5. 最近一次真实微信消息有最终回复。

## 手动重启

~~~powershell
Stop-ScheduledTask -TaskName "Codex-WeChat-Bridge"
Start-ScheduledTask -TaskName "Codex-WeChat-Bridge"
powershell -ExecutionPolicy Bypass -File .\scripts\status-wechat-bridge.ps1
~~~

重启后先看日志和状态，再发送短消息。不要连续快速启动多个前台副本。

## 更新脚本或依赖

~~~powershell
Stop-ScheduledTask -TaskName "Codex-WeChat-Bridge"
bun install
bun run check:syntax
bun test
bun run check --backend codex
powershell -ExecutionPolicy Bypass -File .\scripts\register-wechat-bridge-task.ps1 -CodexPath "C:\path\to\codex.exe"
powershell -ExecutionPolicy Bypass -File .\scripts\status-wechat-bridge.ps1
~~~

重新注册任务会刷新启动脚本参数和任务设置。现有 config.json 不应被仓库更新覆盖。

## 备份和恢复

建议单独备份以下本机文件，备份位置不能放进仓库：

- config.json
- .wechat-ai-bridge/token.json
- sessions-codex.db
- tasks-codex.db

备份前只停止 Bridge，不要在进程仍写数据库时复制 WAL 文件。恢复后先做 bun run check --backend codex，再启动任务和真实消息验收。

## 退出常驻任务

临时停止：

~~~powershell
Stop-ScheduledTask -TaskName "Codex-WeChat-Bridge"
~~~

删除任务前先确认你还保留了配置和令牌备份。删除任务不会自动删除仓库文件、配置、令牌或数据库。

## 日志解读

启动行应能看到已解析的 Bun 和 Codex 路径。认证成功后应能看到 monitor 监听状态。真实消息完成后应能看到 Codex 成功结果。日志只作为本机排查材料，不能直接上传到 Issue，因为它可能包含用户输入、工作路径或内部错误详情。
