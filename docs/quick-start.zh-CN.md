# Windows 微信 Codex Bridge 快速开始

本文把一次已经真实跑通的 Windows 路径整理成可重复步骤。它不复制本机令牌、白名单、数据库或聊天内容；每台机器都必须重新完成登录、白名单和 Codex 路径确认。

## 1. 锁定运行目录

建议把项目放在 D 盘或其他稳定路径，不要放在临时下载目录。进入仓库后确认：

~~~powershell
Get-Location
Test-Path .\package.json
Test-Path .\start.js
~~~

Bridge、配置和计划任务必须指向同一份源码。不要一边从仓库 A 注册任务，一边在仓库 B 修改配置。

## 2. 安装依赖和生成配置

~~~powershell
bun install
bun run bootstrap --backend codex
~~~

如果 config.json 已存在，bootstrap 不会覆盖它。需要重建时，先备份本机配置，再显式使用 --force，不要直接删除正在运行的配置。

把 docs/config.example.json 的内容作为结构参考，至少确认：

1. shared.cwd 指向真实存在的工作目录。
2. shared.allowedUserIds 是真实、精确、经过确认的 iLink from_user_id。
3. backends.codex.enabled 为 true。
4. backends.codex.sessionsDb 和 shared.tasksDb 不指向仓库外的敏感目录，除非你明确需要。

## 3. 先解决 Codex 可执行文件

本次最关键的兼容性问题不是微信，而是 Codex SDK 调用的二进制版本与全局配置版本不匹配。

如果看到类似下面的错误：

~~~text
Error loading config.toml:
invalid type: string "gpt-5.6-luna", expected struct AgentRoleToml
~~~

不要先改全局 C:\Users\<user>\.codex\config.toml。该文件属于本机 Codex 环境，改它可能影响 Codex Desktop 和其他任务。应把 CODEX_PATH 指向当前可工作的 Codex 二进制：

~~~powershell
powershell -ExecutionPolicy Bypass -File .\start-codex-bridge.ps1 -CodexPath "C:\path\to\codex.exe"
~~~

启动脚本会把路径传给 Bridge 的 Codex 适配器，并写入运行日志的启动行。它不把路径写进 config.json，也不需要修改全局 Codex 配置。

## 4. 完成微信登录

首次前台启动会显示二维码：

~~~powershell
powershell -ExecutionPolicy Bypass -File .\start-codex-bridge.ps1 -CodexPath "C:\path\to\codex.exe"
~~~

二维码过期时，旧二维码不能继续使用。按下面顺序处理：

1. 结束当前未完成的登录进程。
2. 重新启动同一份仓库里的启动脚本。
3. 只扫描新生成的二维码，并在有效期内完成确认。
4. 看到登录成功后再继续白名单和消息验收。

成功后 token 存在用户目录的 .wechat-ai-bridge/token.json。只确认文件存在即可，不要读取或复制 token 内容。

## 5. 取得并固定白名单

Bridge 默认拒绝未知发起者。不要填昵称、微信号、备注名或猜测值。发送一条测试消息后，在本地日志中找到被拒绝的精确 from_user_id，将它写入本机 config.json 的 shared.allowedUserIds，然后重新检查：

~~~powershell
bun run check --backend codex
~~~

白名单是运行时安全边界，不能写入公共文档，也不能截图提交。

## 6. 做前台端到端验收

前台验收至少覆盖：

- 微信消息能到达本地 Bridge。
- Bridge 能调用 Codex。
- Codex 返回结果。
- Bridge 能把结果发回同一个微信私聊。
- 日志出现成功结果，而不是只有“已收到”。

“已收到，会在当前任务完成后一起处理。”表示 Bridge 收到了新的消息并正在排队或合并，不等于服务已经失联。若没有最终回复，再检查任务、进程、日志和同步游标。

## 7. 安装常驻任务

前台验收通过后，在仓库根目录运行：

~~~powershell
powershell -ExecutionPolicy Bypass -File .\scripts\register-wechat-bridge-task.ps1 -CodexPath "C:\path\to\codex.exe"
~~~

该脚本会创建或更新 Codex-WeChat-Bridge：

- 系统启动触发一次。
- 当前用户登录触发一次。
- 使用当前 Windows 用户的 S4U 身份，不保存密码。
- 异常退出后重启，最多 999 次，每次间隔 1 分钟。
- 只保留一个实例，避免重复轮询同一个 iLink Bot。

验证：

~~~powershell
powershell -ExecutionPolicy Bypass -File .\scripts\status-wechat-bridge.ps1
~~~

应看到任务为 Running、Bridge 进程数为 1，且日志和用户状态目录 .wechat-ai-bridge/sync-buf.json 有近期更新时间。计划任务的 LastTaskResult 只能作为辅助信息，不能替代真实进程、日志和消息验收。

## 8. 没有 Codex 终端面板怎么办

不需要依赖 Codex 的终端面板。可以使用独立的 Windows PowerShell 或 Windows Terminal 执行仓库脚本。常驻任务运行后，关闭启动它的窗口不应终止 Bridge；这正是从前台运行迁移到计划任务的目的。

## 9. 重新启动和停止

~~~powershell
Stop-ScheduledTask -TaskName "Codex-WeChat-Bridge"
Start-ScheduledTask -TaskName "Codex-WeChat-Bridge"
powershell -ExecutionPolicy Bypass -File .\scripts\status-wechat-bridge.ps1
~~~

修改启动脚本或 Codex 路径后必须重启任务，旧进程不会自动加载新脚本内容。
