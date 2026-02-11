# ai-xxx

内部 AI 基础设施工具集。

## 项目结构

```
ai-xxx/
├── LiteLLM/                # LiteLLM Proxy 部署 & 客户端配置
│   ├── docker-compose.yml  # Docker Compose 部署文件
│   ├── config.yaml         # LiteLLM Proxy 配置
│   ├── prometheus.yml      # Prometheus 监控配置
│   ├── .env.example        # 环境变量模板
│   ├── install.sh          # macOS / Linux 客户端安装脚本
│   ├── install.ps1         # Windows 客户端安装脚本
│   └── README.md           # 详细文档
├── main.go                 # Webhook 回调服务 (Go)
├── go.mod
└── prompt                  # 项目初始化提示词
```

## LiteLLM Proxy

LiteLLM Proxy 的服务端部署配置与客户端环境变量一键安装脚本。

详细文档见 **[LiteLLM/README.md](LiteLLM/README.md)**

### 快速开始 — 客户端配置

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.ps1 | iex
```

**Windows (CMD):**

```cmd
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.ps1 | iex"
```

### 卸载

```bash
# macOS / Linux
curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.sh | bash -s -- --uninstall
```

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

## Webhook 服务

基于 Go 的 Webhook 回调接收服务，用于接收和记录 HTTP 回调请求。

| 端点 | 说明 |
|------|------|
| `GET /` | 服务信息 |
| `POST /api/callback` | Webhook 回调接收 |
| `GET /health` | 健康检查 |

```bash
# 构建 & 运行
go build -o webhook && ./webhook
```

## 许可证

MIT
