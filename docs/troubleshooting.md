# 故障复盘与根因

本页区分“配置已写入”“进程已启动”“iLink 已联通”“Codex 调用成功”和“微信收到最终回复”。其中任意一层成功，都不能替代下一层证据。

## 二维码已过期

### 现象

启动窗口提示二维码已过期，扫码无法继续。

### 根因

二维码是一次性的短期登录凭据。复制旧二维码、等待过久或多个登录进程同时运行都会导致它失效。

### 修复

结束旧的登录进程，只从当前仓库的启动脚本重新生成二维码，并在有效期内完成扫码。登录成功后只保留一个 Bridge 实例。

## 找不到终端面板

### 现象

Codex 界面里看不到终端面板，无法持续观察 Bridge。

### 根因

终端面板只是交互入口，不是服务管理器。把 Bridge 绑定到它会让服务依赖 Codex 窗口和会话生命周期。

### 修复

用独立 PowerShell 做首次扫码和前台验收；验收通过后使用 scripts/register-wechat-bridge-task.ps1 注册 Windows 计划任务。服务状态用 scripts/status-wechat-bridge.ps1 检查，不依赖面板存在。

## AgentRoleToml 配置解析错误

### 现象

~~~text
Codex Exec exited with code 1
Error loading config.toml:
invalid type: string "gpt-5.6-luna", expected struct AgentRoleToml
~~~

### 根因

Bridge 使用的 @openai/codex-sdk 版本所带的旧 Codex 二进制，无法解析当前本机全局 config.toml 的新 [agents] 结构。这不是微信二维码或白名单问题。

### 修复

将 CODEX_PATH 指向已经能独立工作的当前 Codex 二进制：

~~~powershell
powershell -ExecutionPolicy Bypass -File .\start-codex-bridge.ps1 -CodexPath "C:\path\to\codex.exe"
~~~

不要为了迁就旧 SDK 改写全局 Codex 配置。正确的判断顺序是：

1. 直接运行目标 codex.exe，确认它能加载当前配置。
2. 将同一路径交给 Bridge。
3. 再执行 bun run check --backend codex 和真实微信消息验收。

## 只收到“已收到”，没有最终回复

### 现象

微信收到：

~~~text
📥 已收到，会在当前任务完成后一起处理。
~~~

### 判断

这通常表示 Bridge 已经收到后续消息，FlushGate 正在合并或任务仍在执行。它不是“服务正常完成”的充分证据，也不是单独的失联证据。

### 检查顺序

1. status-wechat-bridge.ps1 是否显示任务 Running。
2. Bridge 进程数是否为 1。
3. runtime-logs/bridge.log 是否在更新。
4. 用户状态目录 .wechat-ai-bridge/sync-buf.json 是否在更新。
5. 日志是否出现 Codex 成功结果或具体错误。
6. 必要时发送一个很短的测试问题，排除原任务本身卡住。

不要只看计划任务的返回码。计划任务可能显示“正在运行”、刚刚重启或已经退出，而真正的消息链路证据在进程、日志、游标和最终回复中。

## 联动成功后又失联

### 现象

界面曾显示“微信 Bridge 联动成功”，后来微信不再回复。

### 本次根因

最初 Bridge 运行在前台终端中。终端结束后，Bun 子进程也结束；第一次注册的 Interactive 计划任务依赖登录会话，退出终端或会话变化后任务回到 Ready，并出现 0xC000013A 一类的终止结果。

### 根本修复

使用当前用户的 S4U 计划任务，并配置：

- AtStartup 和 AtLogOn 两个触发器。
- RestartCount=999。
- RestartInterval=PT1M。
- MultipleInstances=IgnoreNew。
- 长执行时间限制。

这解决的是进程生命周期问题，而不是简单地把“启动成功”文字改得更像正常。

## 计划任务在运行，但微信仍无响应

优先确认是否有重复 Bridge。多个进程同时轮询同一个 Bot 可能造成游标竞争、重复消费或回复错乱。状态脚本的目标进程数应为 1。若超过 1，停止重复启动入口，只保留计划任务这一条正式路径。

## 何时需要重新登录

只有在 token 丢失、失效、权限撤销或 iLink 明确返回认证错误时才重新扫码。进程重启本身不等于需要重新登录；先检查本地 token 文件是否存在、任务是否指向同一仓库，再检查日志中的认证错误。不要把 token 内容写入日志或发到聊天中。
