---
name: openclaw-deploy
description: Deploy and configure OpenClaw gateway on local or remote macOS machines. Model provider configuration is required; SSH access and Feishu bot setup are optional. Use when the user asks to install, configure, or troubleshoot OpenClaw.
---

# OpenClaw 部署与配置

在本地或远程 macOS (Mac Mini) 机器上部署 OpenClaw gateway 的完整工作流。

> **核心原则**：模型配置为必需步骤，飞书机器人和健康监控为可选扩展。未提供 SSH 信息时在本地执行。

## 前置条件

- 目标机器已安装 OpenClaw（通常在 `/opt/homebrew/bin/openclaw` 或 `~/.local/bin/openclaw`）
- **（可选）SSH 访问**：如需远程部署，提供 `user@host` 和密码（`sshpass -p '<password>' ssh -o PreferredAuthentications=password,keyboard-interactive user@host`）；不提供则在本地执行
- 用户提供以下其一（**必需**）：
  - **自定义 Provider**：baseUrl、apiKey、模型 ID（用于 LiteLLM / OpenAI 兼容代理）
  - **Anthropic 直连**：Anthropic API Key、模型名称
- **（可选）飞书配置**：appId、appSecret — 提供后才配置飞书机器人

## 部署流程

### Step 1: 环境探测

如果用户提供了 SSH 信息，通过 SSH 连接目标机器执行；否则在本地直接执行：

```bash
# 系统信息
uname -a

# OpenClaw 进程
ps aux | grep openclaw | grep -v grep

# 安装路径
which openclaw 2>/dev/null || find /opt/homebrew/bin /usr/local/bin ~/.local/bin -name "openclaw" 2>/dev/null

# 配置文件
cat ~/.openclaw/openclaw.json

# launchctl 服务
launchctl list | grep claw
ls ~/Library/LaunchAgents/*claw* 2>/dev/null

# auth 配置
cat ~/.openclaw/agents/main/agent/auth-profiles.json 2>/dev/null
```

### Step 2: 模型和 API Key 配置（必需）

根据用户提供的信息选择对应模式。

#### 模式 A：自定义 Provider（推荐）

适用于 LiteLLM、OpenAI 兼容代理等自定义平台。apiKey 直接写在 `openclaw.json` 的 `models.providers` 中，**不依赖 `auth-profiles.json`，OpenClaw 升级不会覆盖**。

```python
import json

with open("/Users/<user>/.openclaw/openclaw.json") as f:
    cfg = json.load(f)

# 自定义 provider
cfg["models"] = {
    "providers": {
        "<PROVIDER_ID>": {
            "baseUrl": "<BASE_URL>",
            "apiKey": "<API_KEY>",
            "api": "openai-completions",
            "models": [
                {
                    "id": "<MODEL_ID>",
                    "name": "<MODEL_DISPLAY_NAME>",
                    "reasoning": True,
                    "input": ["text"]
                }
            ]
        }
    }
}

# 默认模型（2026.3.x 新格式）
cfg["agents"]["defaults"]["model"] = {
    "primary": "<PROVIDER_ID>/<MODEL_ID>"
}

with open("/Users/<user>/.openclaw/openclaw.json", "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
```

**示例**（LiteLLM 平台）：
- `PROVIDER_ID`: `custom-api-autelrobotics-com`
- `BASE_URL`: `https://pool.autelrobotics.com`
- `MODEL_ID`: `claude-opus-4-6`

> **注意**：`models.providers` 是正确的字段路径。不要将 `providers` 放在 `openclaw.json` 顶层，否则会报 `Unrecognized key: "providers"` 错误。

#### 模式 B：Anthropic 直连（兼容旧版）

适用于直接使用 Anthropic API Key 的场景。需要同时配置 `auth-profiles.json` 和 plist 环境变量以兼容不同 OpenClaw 版本。

**修改模型**：

```python
cfg["agents"]["defaults"]["model"] = {"primary": "anthropic/claude-opus-4-6"}
```

**创建 auth-profiles.json**：

```bash
mkdir -p ~/.openclaw/agents/main/agent
```

```python
import json

auth = {
    "anthropic:manual": {
        "id": "anthropic:manual",
        "provider": "anthropic",
        "apiKey": "<ANTHROPIC_API_KEY>",
        "createdAt": "<ISO_TIMESTAMP>",
        "source": "manual"
    }
}

with open("/Users/<user>/.openclaw/agents/main/agent/auth-profiles.json", "w") as f:
    json.dump(auth, f, indent=2)
```

**同时在 launchctl plist 中添加环境变量**（兼容不同 OpenClaw 版本）：

```python
import plistlib

plist_path = "/Users/<user>/Library/LaunchAgents/ai.openclaw.gateway.plist"
with open(plist_path, "rb") as f:
    plist = plistlib.load(f)

env = plist.get("EnvironmentVariables", {})
env["ANTHROPIC_API_KEY"] = "<ANTHROPIC_API_KEY>"
plist["EnvironmentVariables"] = env

with open(plist_path, "wb") as f:
    plistlib.dump(plist, f)
```

> **注意**：修改 plist 后需要用 `plutil -convert xml1` 确保格式正确，再重新加载 launchctl 服务。

### Step 3: 飞书机器人配置（可选）

> 仅在用户提供了飞书 appId 和 appSecret 时执行此步骤，否则跳过。

向 `~/.openclaw/openclaw.json` 写入飞书 channel 配置：

```python
import json

with open("/Users/<user>/.openclaw/openclaw.json") as f:
    cfg = json.load(f)

cfg["channels"] = {
    "feishu": {
        "enabled": True,
        "connectionMode": "websocket",
        "dmPolicy": "open",
        "groupPolicy": "open",
        "streaming": True,
        "accounts": {
            "default": {
                "appId": "<APP_ID>",
                "appSecret": "<APP_SECRET>"
            }
        }
    }
}

with open("/Users/<user>/.openclaw/openclaw.json", "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
```

**注意**：每个飞书 App 的 WebSocket 长连接只能被一个 OpenClaw 实例持有。如果多台机器使用同一个 appId，消息只会被其中一台收到。每台机器必须使用不同的飞书 App。

### Step 4: 飞书权限配置（可选，仅配置了飞书时需要）

> 仅在执行了 Step 3 后才需要此步骤。

部署后如果出现 `permission error resolving sender name` 或消息无响应，需要客户在飞书开发者后台配置权限。

**将 [feishu-scopes.json](feishu-scopes.json) 的内容发给客户**，并告知：

1. 进入飞书开发者后台 → 对应应用 → 「权限管理」
2. 将 `tenant` 列表中的权限全部添加到「应用权限」
3. 将 `user` 列表中的权限全部添加到「用户权限」
4. 进入「事件与回调」→ 订阅方式 → 选择「使用长连接接收事件/回调」
5. 添加事件订阅：`im.message.receive_v1`（接收消息）
6. 发布应用新版本使权限生效

### Step 5: 保活配置

检查 launchctl plist 是否已配置 `KeepAlive` 和 `RunAtLoad`：

```bash
# 检查 plist 是否存在
ls ~/Library/LaunchAgents/ai.openclaw.gateway.plist

# 检查服务是否已加载
launchctl list | grep ai.openclaw.gateway
```

**如果服务未加载**：

```bash
launchctl load -w ~/Library/LaunchAgents/ai.openclaw.gateway.plist
```

**如果 plist 不存在**：需要先通过 `openclaw service install` 安装，或由用户手动创建。

**重启 OpenClaw**（修改配置后）：

```bash
# 推荐: bootout + bootstrap（最可靠）
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/ai.openclaw.gateway.plist 2>/dev/null
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/ai.openclaw.gateway.plist

# 备选1: kill 后 launchctl 自动重启
PID=$(pgrep -f "openclaw-gateway\|openclaw gateway" | head -1)
kill -9 $PID

# 备选2: kickstart
launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway
```

### Step 6: 健康监控（可选，仅配置了飞书时推荐）

> 仅在配置了飞书机器人且网络不稳定的环境下推荐部署。

部署 [healthcheck.sh](healthcheck.sh) 到目标机器：

```bash
# 部署脚本
scp healthcheck.sh user@host:~/.openclaw/healthcheck.sh
ssh user@host 'chmod +x ~/.openclaw/healthcheck.sh'

# 配置 crontab
ssh user@host '(crontab -l 2>/dev/null; echo "*/5 * * * * /Users/<user>/.openclaw/healthcheck.sh") | crontab -'
```

监控逻辑：每 5 分钟检查日志，如果 reconnect >= 3 且无正常活动，curl 测试网络通则 kill 进程触发 launchctl 自动重启。

### 验证清单

部署完成后确认以下日志输出：

```
agent model: <provider>/<model>                 # 模型正确（如 custom-api-autelrobotics-com/claude-opus-4-6）
```

如果配置了飞书，还需确认：

```
feishu configured, enabled automatically        # 飞书插件自动启用
feishu[default]: bot open_id resolved: ou_xxx   # open_id 非 unknown
[ws] ws client ready                            # WebSocket 连接成功
event-dispatch is ready                         # 事件分发就绪
```

如果出现以下错误，按对应方案处理：

| 错误 | 原因 | 解决 |
|------|------|------|
| `No API key found for provider "anthropic"` | auth-profiles.json 缺失或格式不对 | 推荐改用模式 A（models.providers），或重新创建 auth-profiles.json + plist 环境变量 |
| `Unrecognized key: "providers"` | `providers` 放在了 openclaw.json 顶层 | 移到 `models.providers` 下（正确路径） |
| `timeout of 10000ms exceeded` + 持续 reconnect | 网络不通或进程卡死 | curl 测试网络；如通则 kill 重启 |
| `permission error resolving sender name` | 飞书 App 缺少 contact 权限 | 发 feishu-scopes.json 给客户配置（仅飞书） |
| `bot open_id resolved: unknown` | 飞书 API 超时 | 检查网络，重启进程（仅飞书） |
| `Auth providers (OAuth + API keys): - none` | 未配置任何 auth | 模式 A 无需额外 auth（apiKey 在 provider 配置中）；模式 B 检查 auth-profiles.json |
