# ai-xxx

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Go Version](https://img.shields.io/badge/Go-1.21-00ADD8?logo=go)](https://go.dev/)

> 内部 AI 基础设施工具集 - 提供 LiteLLM Proxy 统一代理、Webhook 回调服务和 Mac 开发环境快速配置

## 📋 目录

- [项目简介](#项目简介)
- [项目结构](#项目结构)
- [LiteLLM Proxy](#litellm-proxy)
  - [快速开始 — 客户端配置](#快速开始--客户端配置)
  - [卸载](#卸载)
- [Webhook 服务](#webhook-服务)
- [Mac 开发环境配置](#mac-开发环境配置)
- [问题反馈](#问题反馈)
- [许可证](#许可证)

## 项目简介

本工具集为团队提供以下核心能力：

- **🔌 LiteLLM Proxy**：统一 AI 模型访问代理，支持服务端部署与客户端一键配置
- **📡 Webhook 服务**：轻量级 HTTP 回调接收服务，用于调试和日志记录
- **🖥️ Mac 环境配置**：快速安装常用开发工具（Claude Code、Chrome、Feishu 等）

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
├── mac-setup/              # macOS 开发环境快速配置
│   └── install.sh          # 自动安装脚本
├── main.go                 # Webhook 回调服务 (Go)
├── go.mod                  # Go 模块依赖
└── prompt                  # 项目初始化提示词
```

---

## LiteLLM Proxy

LiteLLM Proxy 提供统一的 AI 模型访问代理，支持服务端 Docker 部署和客户端环境变量一键配置。

📖 **详细文档**：[LiteLLM/README.md](LiteLLM/README.md)

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

---

## Webhook 服务

基于 Go 的轻量级 Webhook 回调接收服务，用于接收、记录和调试 HTTP 回调请求。

### API 端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/` | GET | 服务信息和版本 |
| `/api/callback` | POST | Webhook 回调接收（记录详细日志） |
| `/health` | GET | 健康检查 |

### 快速开始

```bash
# 构建
go build -o webhook

# 运行（默认端口 8080）
./webhook

# 测试
curl http://localhost:8080/health
```

### 功能特性

- ✅ 详细请求日志（Headers、Query、Body）
- ✅ JSON 自动解析和格式化输出
- ✅ 健康检查端点
- ✅ 请求信息完整回显

---

## Mac 开发环境配置

快速为 macOS 配置常用开发工具的一键安装脚本。

### 安装内容

- **Claude Code**：AI 代码助手（含自动 API Key 配置）
- **Google Chrome**：现代浏览器
- **飞书（Feishu）**：团队协作工具

### 使用方法

```bash
# 执行自动安装脚本
bash mac-setup/install.sh
```

脚本会自动：
1. 检测并安装 Homebrew（如未安装）
2. 下载并安装各工具的最新版本
3. 配置 Claude Code API Key（可选）

---

## 问题反馈

如遇到问题或有改进建议，请通过以下方式反馈：

- 📧 联系团队成员
- 🐛 提交 Issue（如仓库开放）

---

## 许可证

[MIT License](LICENSE)
