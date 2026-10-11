# lvsea-codex-bridge

通过微信私聊调用本机 Codex 的可复现 Windows Bridge。

实际链路：

~~~text
微信私聊 -> 腾讯 iLink Bot -> 本地 wechat-ai-bridge
        -> Codex SDK/CLI -> 本机工作目录 -> 微信回复
~~~

这个仓库基于 [AliceLJY/wechat-ai-bridge](https://github.com/AliceLJY/wechat-ai-bridge)，保留上游的微信 iLink、会话管理、文件传输和后端适配能力，并补充了本机实际跑通时用到的 Codex 路径修复、Windows 常驻任务、状态检查、故障定位和验收记录。

它不是 OpenAI、微信或腾讯的官方项目，也不保证任何账号、模型或平台长期可用。请只在你有权使用的账号和工作目录上运行。

## 先看结论

- 微信只需要私聊 iLink Bot，不需要公网 IP 或额外穿透。
- shared.allowedUserIds 必须填写精确的 iLink from_user_id，不能填昵称、微信号或猜测值。
- 首次登录扫码必须在有效期内完成；二维码过期后重新启动登录流程即可。
- Codex 的关键是让 Bridge 使用当前可用的 codex.exe，不要让旧 SDK 内置二进制解析新的全局 config.toml。
- 长期运行不要依赖 Codex 的终端窗口。使用仓库内的 S4U 计划任务脚本，任务名称默认为 Codex-WeChat-Bridge。
- config.json、令牌、SQLite、同步游标、下载文件和运行日志均是本机私有数据，已经加入忽略规则，不能提交。

## 快速开始

### 前置条件

- Windows 10/11
- Bun 1.3.9 或更高版本
- 已安装并登录 Codex CLI 或 Codex Desktop，且本机存在可执行的 codex.exe
- 可以使用微信 iLink Bot，并能访问 iLink 和所选模型服务
- 一个只给本地 Bridge 使用的工作目录

### 安装和配置

~~~powershell
git clone https://github.com/lhylvsea/lvsea-codex-bridge.git
cd lvsea-codex-bridge
bun install
bun run bootstrap --backend codex
~~~

编辑生成的 config.json：

~~~json
{
  "shared": {
    "cwd": "D:\\Workspaces\\wechat-bridge-work",
    "allowedUserIds": ["replace-with-verified-from_user_id"],
    "defaultVerboseLevel": 1,
    "executor": "direct",
    "tasksDb": "",
    "rateLimitMaxRequests": 10,
    "rateLimitWindowMs": 60000,
    "idleTimeoutMs": 1800000,
    "resetOnIdleMs": 0
  },
  "backends": {
    "codex": {
      "enabled": true,
      "sessionsDb": "sessions-codex.db",
      "model": ""
    }
  }
}
~~~

shared.cwd 必须是已经存在的目录。完整的脱敏模板见 [docs/config.example.json](docs/config.example.json)。

### 确认 Codex 路径

优先把路径作为启动参数传入。当前本机验证过的路径是 C:\Codex\app\resources\codex.exe，其他机器不要照抄，改成自己的实际路径。

~~~powershell
powershell -ExecutionPolicy Bypass -File .\start-codex-bridge.ps1 -CodexPath "C:\path\to\codex.exe"
~~~

启动脚本按以下顺序找可执行文件：命令行中的参数、环境变量、系统 PATH、常见安装目录、当前验证过的 Codex Desktop 路径。找不到时会直接报出修复提示，不会静默使用未知二进制。

### 首次扫码和白名单

先执行前台验收：

~~~powershell
powershell -ExecutionPolicy Bypass -File .\start-codex-bridge.ps1 -CodexPath "C:\path\to\codex.exe"
~~~

首次运行会在当前窗口显示二维码。用微信扫码，成功后令牌保存在用户目录的 .wechat-ai-bridge/token.json，不会写入仓库。

如果还没有真实的 from_user_id，先不要把昵称或微信号当作白名单。用本地启动日志确认精确 ID，写入本机 config.json 的 shared.allowedUserIds 后，重新执行：

~~~powershell
bun run check --backend codex
~~~

白名单为空、格式错误或工作目录不存在时，检查必须失败。检查通过后，从微信私聊发送一条短消息，确认能收到回复。

### 安装为常驻服务

前台验收成功后，在仓库根目录执行：

~~~powershell
powershell -ExecutionPolicy Bypass -File .\scripts\register-wechat-bridge-task.ps1 -CodexPath "C:\path\to\codex.exe"
~~~

脚本注册两个触发器：系统启动和当前用户登录；运行身份使用当前 Windows 用户的 S4U，不保存密码；异常退出后最多每分钟重启一次，重复启动时忽略新实例。

只读检查：

~~~powershell
powershell -ExecutionPolicy Bypass -File .\scripts\status-wechat-bridge.ps1
~~~

完整的启动、停止、重启、日志和验收步骤见：

- [中文快速开始](docs/quick-start.zh-CN.md)
- [故障复盘与根因](docs/troubleshooting.md)
- [常驻运维手册](docs/operations.md)
- [验收证据](docs/validation.md)

## 常用命令

~~~powershell
# 静态语法检查
bun run check:syntax

# 单元测试
bun test

# 检查当前本机配置和 Codex 前置条件
bun run check --backend codex

# 查看服务状态，不读取令牌
powershell -ExecutionPolicy Bypass -File .\scripts\status-wechat-bridge.ps1

# 手动重启计划任务
Stop-ScheduledTask -TaskName "Codex-WeChat-Bridge"
Start-ScheduledTask -TaskName "Codex-WeChat-Bridge"
~~~

## 安全边界

- 只处理精确匹配白名单的 iLink 发起者。
- Bridge 不是沙箱。Codex 获得的文件和进程权限取决于本机 Codex 配置及 Windows 用户权限。
- 不要提交 config.json、.wechat-ai-bridge/token.json、*.db、files/、runtime-logs/ 或包含用户消息的临时文件。
- 不要把真实 from_user_id、bot token、API key、OAuth 文件或完整运行日志写进 Issue、README 或截图。
- 不要为解决 SDK 兼容性去修改全局 C:\Users\your-user\.codex\config.toml。优先使用 CODEX_PATH 指向当前可用的 Codex 二进制。
- 当前项目面向微信私聊；不要假设群聊、跨账号复用、外网部署或重启后登录状态一定可用。
- gemini 后端在上游代码中已禁用，不要为了“多一个后端”绕过该限制。

## 上游与许可证

核心实现来自 [AliceLJY/wechat-ai-bridge](https://github.com/AliceLJY/wechat-ai-bridge)，本仓库保留其 MIT 许可证和来源说明。新增的 Windows 启动与运维材料同样按 MIT 许可证发布，详见 [LICENSE](LICENSE)。
