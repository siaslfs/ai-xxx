#!/bin/bash
# =============================================================
# OpenClaw One-Click Installer
# 
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/openclaw-installer/install.sh | bash
#   
#   # 或者指定 API Key:
#   curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/openclaw-installer/install.sh | ANTHROPIC_API_KEY=sk-ant-xxx bash
#
# 流程: 装Node → 装Claude Code → Claude Code自动装OpenClaw → 卸载Claude Code
# =============================================================

set -euo pipefail

# ---- 颜色 ----
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}  [✓]${NC} $*"; }
warn() { echo -e "${YELLOW}  [!]${NC} $*"; }
err()  { echo -e "${RED}  [✗]${NC} $*"; exit 1; }
step() { echo -e "\n${BLUE}==>${NC} ${BLUE}$*${NC}"; }

# ---- Banner ----
echo ""
echo -e "${GREEN}   ██████╗ ██████╗ ███████╗███╗   ██╗ ██████╗██╗      █████╗ ██╗    ██╗${NC}"
echo -e "${GREEN}  ██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██║     ██╔══██╗██║    ██║${NC}"
echo -e "${GREEN}  ██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║     ██║     ███████║██║ █╗ ██║${NC}"
echo -e "${GREEN}  ██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║     ██║     ██╔══██║██║███╗██║${NC}"
echo -e "${GREEN}  ╚██████╔╝██║     ███████╗██║ ╚████║╚██████╗███████╗██║  ██║╚███╔███╔╝${NC}"
echo -e "${GREEN}   ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚══════╝╚═╝  ╚═╝ ╚══╝╚══╝${NC}"
echo ""
echo -e "  ${BLUE}One-Click Installer${NC} — Powered by Claude Code"
echo ""

# ---- 系统检测 ----
step "检测系统环境"

OS="$(uname -s)"
ARCH="$(uname -m)"

case "${OS}" in
  Darwin) log "macOS $(sw_vers -productVersion 2>/dev/null || echo 'unknown')" ;;
  Linux)  log "Linux $(uname -r)" ;;
  *)      err "不支持的系统: ${OS}" ;;
esac

case "${ARCH}" in
  arm64|aarch64) log "架构: ARM64" ;;
  x86_64)        log "架构: x86_64" ;;
  *)             err "不支持的架构: ${ARCH}" ;;
esac

# 检查 git
command -v git &>/dev/null || err "需要 git，请先安装"
log "Git $(git --version | awk '{print $3}')"

# 检查 curl
command -v curl &>/dev/null || err "需要 curl，请先安装"

# ---- API Key ----
step "配置 Anthropic API Key"

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo ""
  echo -e "  请输入你的 Anthropic API Key (sk-ant-xxx):"
  echo -e "  ${YELLOW}(获取地址: https://console.anthropic.com/settings/keys)${NC}"
  echo ""
  read -rsp "  API Key: " ANTHROPIC_API_KEY
  echo ""
  
  if [ -z "${ANTHROPIC_API_KEY}" ]; then
    err "API Key 不能为空"
  fi
fi

# 验证 Key 格式
if [[ ! "${ANTHROPIC_API_KEY}" =~ ^sk-ant- ]]; then
  warn "API Key 格式看起来不对（应以 sk-ant- 开头），继续尝试..."
fi

export ANTHROPIC_API_KEY
log "API Key 已配置"

# ---- Node.js ----
step "安装 Node.js"

NODE_REQUIRED="22"

if command -v node &>/dev/null; then
  NODE_VER=$(node -v | tr -d 'v' | cut -d. -f1)
  if [ "${NODE_VER}" -ge "${NODE_REQUIRED}" ]; then
    log "Node.js $(node -v) 已安装，跳过"
  else
    warn "Node.js $(node -v) 版本过低，需要 >= ${NODE_REQUIRED}"
    NEED_NODE=1
  fi
else
  NEED_NODE=1
fi

if [ "${NEED_NODE:-0}" = "1" ]; then
  # 确定下载 URL
  NODE_VER_FULL="22.16.0"
  case "${OS}-${ARCH}" in
    Darwin-arm64)   NODE_PKG="node-v${NODE_VER_FULL}-darwin-arm64" ;;
    Darwin-x86_64)  NODE_PKG="node-v${NODE_VER_FULL}-darwin-x64" ;;
    Linux-x86_64)   NODE_PKG="node-v${NODE_VER_FULL}-linux-x64" ;;
    Linux-aarch64)  NODE_PKG="node-v${NODE_VER_FULL}-linux-arm64" ;;
    Linux-arm64)    NODE_PKG="node-v${NODE_VER_FULL}-linux-arm64" ;;
    *) err "不支持: ${OS}-${ARCH}" ;;
  esac

  NODE_URL="https://nodejs.org/dist/v${NODE_VER_FULL}/${NODE_PKG}.tar.gz"
  
  log "下载 Node.js ${NODE_VER_FULL}..."
  curl -fsSL "${NODE_URL}" -o /tmp/node.tar.gz
  
  mkdir -p ~/local
  tar xzf /tmp/node.tar.gz -C ~/local/
  rm -f ~/local/node
  ln -sf ~/local/${NODE_PKG} ~/local/node
  rm -f /tmp/node.tar.gz
  
  export PATH="$HOME/local/node/bin:$PATH"
  
  # 写入 shell 配置
  SHELL_RC="$HOME/.zshrc"
  [ -f "$HOME/.bashrc" ] && [ ! -f "$HOME/.zshrc" ] && SHELL_RC="$HOME/.bashrc"
  
  if ! grep -q 'local/node/bin' "${SHELL_RC}" 2>/dev/null; then
    echo '' >> "${SHELL_RC}"
    echo '# Node.js (installed by OpenClaw)' >> "${SHELL_RC}"
    echo 'export PATH="$HOME/local/node/bin:$PATH"' >> "${SHELL_RC}"
  fi
  
  log "Node.js $(node -v) 安装完成"
fi

# 确保 npm 可用
command -v npm &>/dev/null || err "npm 不可用"

# ---- pnpm ----
if ! command -v pnpm &>/dev/null; then
  log "安装 pnpm..."
  npm install -g pnpm 2>&1 | tail -1
fi
log "pnpm $(pnpm -v)"

# ---- Claude Code ----
step "安装 Claude Code"

npm install -g @anthropic-ai/claude-code 2>&1 | tail -1
CLAUDE_VER=$(claude --version 2>/dev/null || echo "unknown")
log "Claude Code ${CLAUDE_VER} 已安装"

# ---- 用 Claude Code 安装 OpenClaw ----
step "通过 Claude Code 自动安装 OpenClaw"

warn "这可能需要 5-15 分钟，请耐心等待..."
echo ""

DEPLOY_TASK='你是一个自动化部署助手。请在这台机器上安装和配置 OpenClaw。严格按步骤执行，不要跳过任何步骤。

## 步骤 1: 克隆仓库
```bash
cd ~
git clone https://github.com/openclaw/openclaw.git
cd ~/openclaw
git checkout main
```

## 步骤 2: 安装依赖并构建
```bash
cd ~/openclaw
pnpm install
pnpm build
```
如果 pnpm install 报错，尝试 `pnpm install --no-frozen-lockfile`

## 步骤 3: 配置 PATH
```bash
SHELL_RC="$HOME/.zshrc"
[ -f "$HOME/.bashrc" ] && [ ! -f "$HOME/.zshrc" ] && SHELL_RC="$HOME/.bashrc"

if ! grep -q "openclaw/bin" "${SHELL_RC}" 2>/dev/null; then
  echo "" >> "${SHELL_RC}"
  echo "# OpenClaw" >> "${SHELL_RC}"
  echo "export PATH=\"\$HOME/openclaw/bin:\$PATH\"" >> "${SHELL_RC}"
fi
export PATH="$HOME/openclaw/bin:$PATH"
```

## 步骤 4: 初始化 OpenClaw
```bash
export PATH="$HOME/openclaw/bin:$PATH"
openclaw init
```
如果 init 命令需要交互，尝试用默认值或按回车跳过。

## 步骤 5: 配置 Anthropic API Key
编辑 ~/.openclaw/openclaw.json，在 auth.profiles 中确保有:
```json
{
  "auth": {
    "profiles": {
      "anthropic:default": {
        "provider": "anthropic",
        "mode": "api_key"
      }
    }
  }
}
```

然后运行:
```bash
export PATH="$HOME/openclaw/bin:$PATH"
openclaw configure --section providers
```
选择 anthropic provider，输入 API key。

如果交互式配置不成功，使用 openclaw 的密钥存储命令或直接配置。

## 步骤 6: 验证
```bash
export PATH="$HOME/openclaw/bin:$PATH"
openclaw status
```

## 步骤 7: 创建完成标记
```bash
mkdir -p ~/.openclaw/workspace
echo "deployed at $(date)" > ~/.openclaw/workspace/DEPLOY_SUCCESS
```

完成后输出 DEPLOY_COMPLETE。如果任何步骤失败，输出具体错误信息。'

claude -p "${DEPLOY_TASK}" \
  --allowedTools "Bash,Read,Write,Edit" \
  --max-turns 50 \
  --output-format text \
  2>&1 | tee /tmp/openclaw-deploy.log

# ---- 验证 ----
step "验证安装结果"

PASS=0; FAIL=0

check() {
  if eval "$2" &>/dev/null; then
    log "$1"; ((PASS++))
  else
    warn "$1 — 失败"; ((FAIL++))
  fi
}

export PATH="$HOME/openclaw/bin:$HOME/local/node/bin:$PATH"

check "openclaw 目录"        "[ -d ~/openclaw ]"
check "node_modules"         "[ -d ~/openclaw/node_modules ]"
check "构建产物"             "ls ~/openclaw/packages/*/dist 2>/dev/null || ls ~/openclaw/dist 2>/dev/null"
check "配置文件"             "[ -f ~/.openclaw/openclaw.json ]"
check "openclaw 命令"        "command -v openclaw"
check "部署标记"             "[ -f ~/.openclaw/workspace/DEPLOY_SUCCESS ]"

echo ""
echo -e "  验证结果: ${GREEN}${PASS} 通过${NC}, ${RED}${FAIL} 失败${NC}"

# ---- 清理 Claude Code ----
step "清理 Claude Code"

npm uninstall -g @anthropic-ai/claude-code 2>/dev/null
rm -rf ~/.claude 2>/dev/null || true
log "Claude Code 已卸载并清理"

# ---- 完成 ----
echo ""
if [ "${FAIL}" -eq 0 ]; then
  echo -e "${GREEN}  ╔══════════════════════════════════════╗${NC}"
  echo -e "${GREEN}  ║   🎉 OpenClaw 安装成功！            ║${NC}"
  echo -e "${GREEN}  ╚══════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  启动: ${BLUE}openclaw gateway start${NC}"
  echo -e "  状态: ${BLUE}openclaw status${NC}"
  echo -e "  配置: ${BLUE}openclaw configure${NC}"
  echo ""
  echo -e "  文档: ${BLUE}https://docs.openclaw.ai${NC}"
else
  echo -e "${YELLOW}  ╔══════════════════════════════════════╗${NC}"
  echo -e "${YELLOW}  ║   ⚠️  安装可能不完整                 ║${NC}"
  echo -e "${YELLOW}  ╚══════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  查看日志: ${BLUE}cat /tmp/openclaw-deploy.log${NC}"
  echo -e "  手动完成: ${BLUE}cd ~/openclaw && pnpm build${NC}"
fi
echo ""
