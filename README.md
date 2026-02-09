# LiteLLM Proxy Environment Setup

一键配置 `ANTHROPIC_BASE_URL` 和 `ANTHROPIC_AUTH_TOKEN` 环境变量的跨平台安装脚本。

## 快速开始

### macOS / Linux / Ubuntu

```bash
# 交互模式（会提示输入）
curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/litellm-setup/install.sh | bash

# 非交互模式（直接传参）
curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/litellm-setup/install.sh | bash -s -- \
    --base-url http://34.81.219.7:4000 \
    --auth-token sk-your-key-here
```

### Windows (PowerShell)

```powershell
# 交互模式
irm https://raw.githubusercontent.com/siaslfs/ai-xxx/main/litellm-setup/install.ps1 | iex

# 非交互模式
.\install.ps1 -BaseUrl "http://34.81.219.7:4000" -AuthToken "sk-your-key-here"

# 系统级别（需要管理员权限）
.\install.ps1 -Scope Machine -BaseUrl "http://34.81.219.7:4000" -AuthToken "sk-your-key-here"
```

### Windows (CMD)

```cmd
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/siaslfs/ai-xxx/main/litellm-setup/install.ps1 | iex"
```

## 文件说明

| 文件 | 平台 | 说明 |
|------|------|------|
| `install.sh` | macOS / Linux / Ubuntu | Bash 安装脚本，支持 zsh、bash、fish |
| `install.ps1` | Windows | PowerShell 安装脚本，支持 User 和 Machine 作用域 |
| `setup.sh` | 通用入口 | 自动检测平台并分发到对应脚本 |

## 功能特性

**交互式引导**：在未提供参数时，脚本会以友好的交互界面逐步引导用户输入配置值，并提供默认值供快速确认。

**输入验证**：脚本会自动验证 Base URL 是否以 `http://` 或 `https://` 开头，并检查 Auth Token 是否符合 `sk-` 前缀的约定格式。

**连接测试**：配置完成前，脚本会自动尝试连接 LiteLLM 代理服务器的 `/health` 端点，验证服务可达性。

**持久化存储**：环境变量会被写入对应的 Shell 配置文件（如 `.bashrc`、`.zshrc`、PowerShell Profile），确保重启终端后仍然生效。

**安全备份**：在修改任何配置文件之前，脚本会自动创建带时间戳的备份文件，防止意外覆盖。

**Token 脱敏**：在所有输出和摘要中，Auth Token 仅显示前 7 位和后 4 位，中间以 `...` 替代。

## Shell 参数（install.sh）

| 参数 | 说明 |
|------|------|
| `--base-url <url>` | LiteLLM 代理地址，如 `http://34.81.219.7:4000` |
| `--auth-token <token>` | LiteLLM Virtual Key，如 `sk-xxxxx` |
| `--dry-run` | 仅显示将要执行的操作，不实际修改 |
| `--uninstall` | 从 Shell 配置文件中移除环境变量 |
| `--force` | 跳过覆盖确认，直接写入 |
| `--quiet` | 静默模式，减少输出 |
| `--help` | 显示帮助信息 |

## PowerShell 参数（install.ps1）

| 参数 | 说明 |
|------|------|
| `-BaseUrl <url>` | LiteLLM 代理地址 |
| `-AuthToken <token>` | LiteLLM Virtual Key |
| `-Scope <User\|Machine>` | 环境变量作用域，默认 `User` |
| `-DryRun` | 仅显示将要执行的操作 |
| `-Uninstall` | 移除环境变量 |
| `-Force` | 跳过覆盖确认 |
| `-Quiet` | 静默模式 |
| `-Help` | 显示帮助信息 |

## 环境变量说明

脚本配置的两个环境变量用于将 Anthropic API 请求透明代理到 LiteLLM 服务器：

| 变量名 | 用途 | 示例值 |
|--------|------|--------|
| `ANTHROPIC_BASE_URL` | LiteLLM 代理服务器的 HTTP 地址 | `http://34.81.219.7:4000` |
| `ANTHROPIC_AUTH_TOKEN` | LiteLLM 分配的 Virtual Key | `sk-1234567890abcdef` |

## Shell 配置文件检测逻辑

脚本会根据当前使用的 Shell 自动选择正确的配置文件：

| Shell | macOS | Linux |
|-------|-------|-------|
| zsh | `~/.zshrc` | `~/.zshrc` |
| bash | `~/.bash_profile` | `~/.bashrc` |
| fish | `~/.config/fish/config.fish` | `~/.config/fish/config.fish` |
| 其他 | `~/.profile` | `~/.profile` |

## 卸载

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/litellm-setup/install.sh | bash -s -- --uninstall
```

### Windows

```powershell
.\install.ps1 -Uninstall
```

## 项目结构

```
litellm-setup/
├── install.sh      # macOS / Linux / Ubuntu 安装脚本
├── install.ps1     # Windows PowerShell 安装脚本
├── setup.sh        # 通用入口脚本（自动检测平台）
└── README.md       # 使用文档
```

## 许可证

MIT
