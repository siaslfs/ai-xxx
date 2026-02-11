# LiteLLM Proxy

LiteLLM Proxy 的部署配置与客户端环境变量一键安装脚本。

## 目录结构

```
LiteLLM/
├── docker-compose.yml   # Docker Compose 部署文件 (LiteLLM + Prometheus)
├── config.yaml          # LiteLLM Proxy 配置文件
├── prometheus.yml       # Prometheus 监控配置
├── .env.example         # 环境变量模板 (需复制为 .env 并填写真实值)
├── install.sh           # macOS / Linux 客户端环境变量安装脚本
├── install.ps1          # Windows PowerShell 客户端环境变量安装脚本
└── README.md
```

## 一、服务端部署

### 前置要求

- Docker & Docker Compose
- PostgreSQL 数据库（外部或自行部署）

### 部署步骤

```bash
# 1. 进入目录
cd LiteLLM

# 2. 复制环境变量模板并填写真实配置
cp .env.example .env
vi .env

# 3. 启动服务
docker compose up -d

# 4. 查看服务状态
docker compose ps

# 5. 查看日志
docker compose logs -f litellm
```

### 服务端口

| 服务 | 端口 | 说明 |
|------|------|------|
| LiteLLM Proxy | 4000 | API 代理服务 & 管理后台 |
| Prometheus | 9090 | 监控指标采集 |

### 环境变量说明

| 变量 | 必填 | 说明 |
|------|------|------|
| `LITELLM_MASTER_KEY` | Yes | 管理密钥，必须以 `sk-` 开头 |
| `LITELLM_SALT_KEY` | Yes | 数据库加密盐值 |
| `UI_USERNAME` | Yes | 管理后台用户名 |
| `UI_PASSWORD` | Yes | 管理后台密码 |
| `DATABASE_URL` | Yes | PostgreSQL 连接地址 |
| `ANTHROPIC_API_KEY` | Yes | Anthropic API Key |
| `STORE_MODEL_IN_DB` | No | 是否通过管理后台配置模型（默认 `true`） |

## 二、客户端配置

安装脚本会将 `ANTHROPIC_BASE_URL` 和 `ANTHROPIC_AUTH_TOKEN` 环境变量写入终端配置，使 Claude Code 等工具自动通过 LiteLLM Proxy 发起请求。

### macOS / Linux

```bash
# 安装（交互式引导）
curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.sh | bash

# 卸载
curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.sh | bash -s -- --uninstall

# 帮助
curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.sh | bash -s -- --help
```

**支持的 Shell**: bash, zsh, fish, ksh

**配置文件检测逻辑**:

| Shell | macOS | Linux |
|-------|-------|-------|
| bash | `~/.bash_profile` | `~/.bashrc` |
| zsh | `~/.zshrc` | `~/.zshrc` |
| fish | `~/.config/fish/config.fish` | `~/.config/fish/config.fish` |
| ksh | `~/.kshrc` | `~/.kshrc` |

### Windows (PowerShell)

```powershell
# 安装（交互式引导）
irm https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.ps1 | iex

# 或下载后本地执行
powershell -ExecutionPolicy Bypass -File install.ps1

# 卸载
powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall

# 帮助
powershell -ExecutionPolicy Bypass -File install.ps1 -Help
```

### Windows (CMD)

```cmd
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.ps1 | iex"
```

### 客户端环境变量说明

| 变量 | 用途 | 示例值 |
|------|------|--------|
| `ANTHROPIC_BASE_URL` | LiteLLM Proxy 服务器地址 | `http://34.81.219.7:4000` |
| `ANTHROPIC_AUTH_TOKEN` | LiteLLM 分配的 Virtual Key | `sk-1234567890abcdef` |

### 安装脚本功能

- 交互式引导输入配置值
- 自动检测 URL 协议前缀，缺失时提示补全
- Token 隐藏输入（不回显）
- Token 脱敏显示（仅展示首尾各 4 位）
- 写入前确认，支持覆盖已有配置
- 支持一键卸载

## 三、验证

```bash
# 检查环境变量是否生效
echo $ANTHROPIC_BASE_URL
echo $ANTHROPIC_AUTH_TOKEN

# 测试代理连通性
curl $ANTHROPIC_BASE_URL/health/liveliness
```

## 许可证

MIT
