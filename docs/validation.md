# 验收证据

## 验收层次

| 层次 | 命令或动作 | 通过证据 |
| --- | --- | --- |
| 依赖 | bun install | 依赖安装完成 |
| 语法 | bun run check:syntax | 所有 JavaScript 文件通过 |
| 测试 | bun test | 无失败测试 |
| 配置 | bun run check --backend codex | 输出 [check] ok |
| 任务 | status-wechat-bridge.ps1 | 任务 Running，进程数为 1 |
| 活性 | 检查日志和用户状态目录的 .wechat-ai-bridge/sync-buf.json | 两者都有近期更新时间 |
| 端到端 | 微信发送真实私聊 | 收到 Codex 最终回复 |

配置检查不能证明 iLink 已联通；任务 Running 不能证明 Codex 调用成功；一条“已收到”不能证明最终回复已经完成。交付时应按层记录证据。

## 本次本机验收记录

本记录对应本仓库整理前的同一份工作目录，时间为 2026-10-11：

- bun run check:syntax 通过，检查 42 个 JavaScript 文件。
- bun test 通过，33 个通过、2 个跳过、0 个失败。
- bun run check --backend codex 通过。
- Windows 计划任务 Codex-WeChat-Bridge 使用 S4U 身份运行，设置了启动、登录、异常重启和单实例约束。
- 任务处于 Running，Bridge 进程数为 1。
- 同步游标持续更新，日志出现 Codex ok。
- 从微信发送真实消息后，用户确认收到正常回复。

## 本次踩坑对应的验证

### Codex 配置错误

验证的不是“把错误文字隐藏”，而是让 Bridge 使用当前 codex.exe 后再次完成真实 Codex 调用。全局 config.toml 没有被改写。

### 常驻恢复

验证的不是某一次启动返回码，而是计划任务、实际 Bun 进程、同步游标、日志和微信最终回复同时存在。计划任务的返回码只作为辅助信息。

### 敏感信息排除

发布前应检查：

~~~powershell
git status --short --untracked-files=all
git diff --check
git ls-files config.json runtime-logs files
~~~

以下内容不能进入提交：

- config.json
- .wechat-ai-bridge/token.json
- *.db、*.db-shm、*.db-wal
- files/
- runtime-logs/
- 真实白名单 ID、bot token、API key、OAuth 文件

## 尚未替代的验证

本记录证明了当前 Windows 会话下的真实收发和计划任务常驻。它不自动等价于所有机器的重启后验收、锁屏/注销策略、不同 Windows 账号、不同 Codex 版本、不同 iLink 账号或不同模型服务都能通过。迁移到新机器时，必须重新执行本页的配置、任务和端到端步骤。
