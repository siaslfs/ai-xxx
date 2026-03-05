#!/bin/bash
# =============================================================
# Claude Code + Node.js One-Click Installer
# 
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/openclaw-installer/install.sh | bash
#   
#   # 指定 API Key:
#   curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/openclaw-installer/install.sh | ANTHROPIC_API_KEY=sk-ant-xxx bash
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
echo -e "${BLUE}   ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗${NC}"
echo -e "${BLUE}  ██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝${NC}"
echo -e "${BLUE}  ██║     ██║     ███████║██║   ██║██║  ██║█████╗  ${NC}"
echo -e "${BLUE}  ██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝  ${NC}"
echo -e "${BLUE}  ╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗${NC}"
echo -e "${BLUE}   ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝${NC}"
echo -e "  ${BLUE}Claude Code Installer${NC}"
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

command -v curl &>/dev/null || err "需要 curl，请先安装"

# ---- Node.js ----
step "安装 Node.js"

NODE_REQUIRED="22"
NEED_NODE=0

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

if [ "${NEED_NODE}" = "1" ]; then
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
    echo '# Node.js' >> "${SHELL_RC}"
    echo 'export PATH="$HOME/local/node/bin:$PATH"' >> "${SHELL_RC}"
  fi
  
  log "Node.js $(node -v) 安装完成"
fi

command -v npm &>/dev/null || err "npm 不可用"

# ---- Claude Code ----
step "安装 Claude Code"

npm install -g @anthropic-ai/claude-code 2>&1 | tail -1
CLAUDE_VER=$(claude --version 2>/dev/null || echo "unknown")
log "Claude Code ${CLAUDE_VER}"

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

# 写入 shell 配置持久化
SHELL_RC="$HOME/.zshrc"
[ -f "$HOME/.bashrc" ] && [ ! -f "$HOME/.zshrc" ] && SHELL_RC="$HOME/.bashrc"

if ! grep -q 'ANTHROPIC_API_KEY' "${SHELL_RC}" 2>/dev/null; then
  echo '' >> "${SHELL_RC}"
  echo '# Anthropic API Key' >> "${SHELL_RC}"
  echo "export ANTHROPIC_API_KEY=\"${ANTHROPIC_API_KEY}\"" >> "${SHELL_RC}"
fi

export ANTHROPIC_API_KEY
log "API Key 已配置并写入 ${SHELL_RC}"

# ---- 完成 ----
echo ""
echo -e "${GREEN}  ╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}  ║   🎉 Claude Code 安装成功！          ║${NC}"
echo -e "${GREEN}  ╚══════════════════════════════════════╝${NC}"
echo ""
echo -e "  使用: ${BLUE}claude${NC}"
echo -e "  版本: ${BLUE}claude --version${NC}"
echo ""
echo -e "  ${YELLOW}请重新打开终端或运行: source ${SHELL_RC}${NC}"
echo ""
