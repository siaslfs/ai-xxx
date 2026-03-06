---
name: openclaw-deploy
description: Deploy and configure OpenClaw gateway on local or remote macOS machines. Covers model provider configuration (LiteLLM / Anthropic), optional Feishu bot binding, and multi-agent creation. Use when the user asks to install, configure, or troubleshoot OpenClaw.
---

# OpenClaw 部署与配置

在本地或远程 macOS (Mac Mini) 机器上部署 OpenClaw gateway 的完整工作流。

> **核心原则**：模型配置为必需步骤；SSH、飞书机器人、多 Agent 创建均为可选。未提供 SSH 信息时在本地执行。

## 职责分工

| 环节 | 谁做 |
|------|------|
| 创建飞书应用（开发者后台） | **用户** |
| 配置权限、事件订阅、长连接模式、发布版本 | **用户** |
| 提供 Agent ID、APP ID、APP Secret、API Key | **用户** |
| OpenClaw 模型配置、agent 创建、飞书账户绑定、API Key 写入、重启验证 | **自动化** |

## 前置条件

- 目标机器已安装 OpenClaw（通常在 `/opt/homebrew/bin/openclaw` 或 `~/.local/bin/openclaw`）
- **（可选）SSH 访问**：如需远程部署，提供 `user@host` 和密码；不提供则在本地执行
- 用户提供以下其一（**必需**）：
  - **自定义 Provider**：baseUrl、apiKey、模型 ID（用于 LiteLLM / OpenAI 兼容代理）
  - **Anthropic 直连**：Anthropic API Key、模型名称
- **（可选）飞书配置**：appId、appSecret — 用户已在飞书开发者后台完成应用创建、权限配置、事件订阅和版本发布
- **（可选）多 Agent**：每个 agent 需要 Agent ID、飞书 APP ID、APP Secret、API Key

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

# 已有 agent 列表
openclaw agents list --bindings 2>/dev/null
```

### Step 2: 模型和 API Key 配置（必需）

根据用户提供的信息选择对应模式。

#### 模式 A：自定义 Provider（推荐）

适用于 LiteLLM、OpenAI 兼容代理等自定义平台。apiKey 直接写在 `openclaw.json` 的 `models.providers` 中，**不依赖 `auth-profiles.json`，OpenClaw 升级不会覆盖**。

```python
import json

with open("/Users/<user>/.openclaw/openclaw.json") as f:
    cfg = json.load(f)

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

> **注意**：
> - `models.providers` 是正确的字段路径。不要将 `providers` 放在 `openclaw.json` 顶层，否则会报 `Unrecognized key: "providers"` 错误。
> - `"api": "openai-completions"` **必须**设置，否则 Gateway 收到消息时崩溃：`No API provider registered for api: undefined`。
> - models 数组元素必须是对象 `{"id": "...", "name": "..."}`，不是字符串。

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
> **前提**：用户已在飞书开发者后台完成以下操作：
> 1. 创建企业自建应用
> 2. 配置权限（至少 `im:message.p2p_msg:readonly`）
> 3. 事件订阅：`im.message.receive_v1`，订阅方式选「使用长连接接收事件/回调」
> 4. 发布应用版本

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

### Step 4: 创建 Agent 并绑定飞书机器人（可选，多 Agent 场景）

> 仅在用户需要创建多个 Agent 并各自绑定不同飞书机器人时执行。
> 用户提供：Agent ID、APP ID、APP Secret、API Key。
> 所有 agent 共用 Step 2 中注册的全局 LiteLLM provider。
> 对每个 agent 重复执行 4.1 ~ 4.5。

#### 4.1 停止 Gateway

```bash
kill $(lsof -ti :18789) 2>/dev/null || true
sleep 1
```

#### 4.2 添加飞书多账户

**必须用 jq 编辑 JSON，不要用 `openclaw config set`**（`config set` 会把数字型 name 如 "7" 错误解析为数字）。

```bash
cat > /tmp/_add_account.jq << 'EOF'
.channels.feishu.accounts[$aid] = {
  "appId": $appId, "appSecret": $appSecret, "name": $appName,
  "enabled": true, "connectionMode": "websocket"
}
EOF

CONFIG="$HOME/.openclaw/openclaw.json"
TMP=$(mktemp)
jq --arg aid "$AGENT_ID" \
   --arg appId "$APP_ID" \
   --arg appSecret "$APP_SECRET" \
   --arg appName "$APP_NAME" \
   -f /tmp/_add_account.jq "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"
```

> **关键**：zsh 会转义 jq filter 中的 `!=`，将 jq filter 写入文件再用 `-f` 引用可避免此问题。

#### 4.3 创建 Agent 并绑定

```bash
openclaw agents add "$AGENT_ID" \
  --workspace "$HOME/.openclaw/agents/$AGENT_ID/workspace" \
  --model "openai/$MODEL" \
  --bind "feishu:$AGENT_ID" \
  --non-interactive
```

> **关键**：model 必须用 `openai/<modelName>`，不能用 `litellm/<modelName>`。LiteLLM 代理暴露的是 OpenAI 兼容 API，provider 统一用 `openai`。

#### 4.4 复制 Workspace 模板和 models.json

```bash
for f in BOOTSTRAP.md IDENTITY.md SOUL.md HEARTBEAT.md USER.md AGENTS.md TOOLS.md; do
  cp "$HOME/.openclaw/workspace/$f" "$HOME/.openclaw/agents/$AGENT_ID/workspace/$f" 2>/dev/null || true
done

mkdir -p "$HOME/.openclaw/agents/$AGENT_ID/agent"
cp "$HOME/.openclaw/agents/main/agent/models.json" \
   "$HOME/.openclaw/agents/$AGENT_ID/agent/models.json"
```

#### 4.5 写入 per-agent API Key（auth-profiles.json）

**不要用 `paste-token`**（需要 TTY 交互），直接写入文件。

```bash
AUTH_FILE="$HOME/.openclaw/agents/$AGENT_ID/agent/auth-profiles.json"
cat > "$AUTH_FILE" << AUTHEOF
{
  "version": 1,
  "profiles": {
    "openai:default": {
      "type": "api_key",
      "provider": "openai",
      "key": "$API_KEY",
      "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
    }
  }
}
AUTHEOF
chmod 600 "$AUTH_FILE"
```

> **格式要点（必须严格遵守）**：
> - 必须有 `"version": 1` 和 `"profiles": {}` 包装层
> - type 是 `"api_key"`，key 字段名是 `"key"`（不是 `"token"` 或 `"apiKey"`）
> - provider 和 profile ID 用 `openai`，不是 `litellm`

### Step 5: 保活配置

检查 launchctl plist 是否已配置 `KeepAlive` 和 `RunAtLoad`：

```bash
ls ~/Library/LaunchAgents/ai.openclaw.gateway.plist
launchctl list | grep ai.openclaw.gateway
```

**如果服务未加载**：

```bash
launchctl load -w ~/Library/LaunchAgents/ai.openclaw.gateway.plist
```

**如果 plist 不存在**：需要先通过 `openclaw service install` 安装，或由用户手动创建。

### Step 6: 重启 Gateway 并验证

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

如果执行了 Step 4（多 Agent），重启后额外验证：

```bash
openclaw agents list --bindings
openclaw channels status --probe
```

所有飞书账户应显示 `enabled, configured, running, works`。

### Step 7: 健康监控（可选）

> 仅在配置了飞书机器人且网络不稳定的环境下推荐部署。

部署 [healthcheck.sh](healthcheck.sh) 到目标机器：

```bash
scp healthcheck.sh user@host:~/.openclaw/healthcheck.sh
ssh user@host 'chmod +x ~/.openclaw/healthcheck.sh'
ssh user@host '(crontab -l 2>/dev/null; echo "*/5 * * * * /Users/<user>/.openclaw/healthcheck.sh") | crontab -'
```

监控逻辑：每 5 分钟检查日志，如果 reconnect >= 3 且无正常活动，curl 测试网络通则 kill 进程触发 launchctl 自动重启。

## 删除 Agent

如需删除某个 agent 重建，需要清理 3 处：

```bash
# 1. 删除 agent 目录
rm -rf ~/.openclaw/agents/<agentId>

# 2. 从 openclaw.json 移除 agent、binding、feishu account
cat > /tmp/_remove_agent.jq << 'JQEOF'
.agents.list = [.agents.list[] | select(.id != $aid)] |
.bindings = [.bindings[] | select(.agentId != $aid)] |
del(.channels.feishu.accounts[$aid])
JQEOF
TMP=$(mktemp)
jq --arg aid "<agentId>" -f /tmp/_remove_agent.jq ~/.openclaw/openclaw.json > "$TMP" && mv "$TMP" ~/.openclaw/openclaw.json

# 3. 重启 Gateway
```

## 验证清单

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

> **注意**：`dmPolicy: "open"` 模式下无需配对审批，用户可直接与机器人对话。如果 dmPolicy 设为 `"pairing"`，新用户首次发消息需要管理员执行 `openclaw pairing approve feishu <code>` 批准。

## 错误排查

| 错误 | 原因 | 解决 |
|------|------|------|
| `No API key found for provider "anthropic"` | auth-profiles.json 缺失或格式不对 | 推荐改用模式 A（models.providers），或重新创建 auth-profiles.json + plist 环境变量 |
| `Unrecognized key: "providers"` | `providers` 放在了 openclaw.json 顶层 | 移到 `models.providers` 下（正确路径） |
| `No API provider registered for api: undefined` | models provider 缺少 `api` 字段 | 确认设置了 `"api": "openai-completions"` |
| `timeout of 10000ms exceeded` + 持续 reconnect | 网络不通或进程卡死 | curl 测试网络；如通则 kill 重启 |
| `permission error resolving sender name` | 飞书 App 缺少 contact 权限 | 用户在飞书开发者后台开通权限并发布版本 |
| `bot open_id resolved: unknown` | 飞书 API 超时 | 检查网络，重启进程 |
| WebSocket 正常但收不到消息 | 权限未开通 | 用户需开通 `im:message.p2p_msg:readonly` 并发布版本 |
| `Auth providers (OAuth + API keys): - none` | 未配置任何 auth | 模式 A 无需额外 auth；模式 B 检查 auth-profiles.json |
| name 字段变成数字 | `openclaw config set` 类型推断错误 | 用 jq 编辑 JSON |
| auth 不匹配 | provider/profile ID 错误 | auth-profiles.json 中统一用 `openai`，不是 `litellm` |
| jq filter 中 `!=` 报语法错误 | zsh 转义 `!` | 将 jq filter 写入文件，用 `jq -f` 引用 |
| Gateway 启动后退出 | 未用 nohup 或 launchctl | 使用 launchctl 保活，或 `nohup openclaw gateway --force &` |
