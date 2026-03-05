#!/bin/bash
# =============================================================
# Claude Code One-Click Installer
# 
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/openclaw-installer/install.sh | bash
#   
#   # 带 API Key（免登录）:
#   curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/openclaw-installer/install.sh | ANTHROPIC_API_KEY=sk-ant-xxx bash
# =============================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}  [✓]${NC} $*"; }
warn() { echo -e "${YELLOW}  [!]${NC} $*"; }
err()  { echo -e "${RED}  [✗]${NC} $*"; exit 1; }
step() { echo -e "\n${BLUE}==>${NC} ${BLUE}$*${NC}"; }

echo ""
echo -e "${BLUE}   ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗${NC}"
echo -e "${BLUE}  ██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝${NC}"
echo -e "${BLUE}  ██║     ██║     ███████║██║   ██║██║  ██║█████╗  ${NC}"
echo -e "${BLUE}  ██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝  ${NC}"
echo -e "${BLUE}  ╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗${NC}"
echo -e "${BLUE}   ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝${NC}"
echo -e "  ${BLUE}One-Click Installer${NC}"
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

NEED_NODE=0

if command -v node &>/dev/null; then
  NODE_VER=$(node -v | tr -d 'v' | cut -d. -f1)
  if [ "${NODE_VER}" -ge 18 ]; then
    log "Node.js $(node -v) 已安装，跳过"
  else
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
    Linux-aarch64|Linux-arm64) NODE_PKG="node-v${NODE_VER_FULL}-linux-arm64" ;;
    *) err "不支持: ${OS}-${ARCH}" ;;
  esac

  log "下载 Node.js ${NODE_VER_FULL}..."
  curl -fsSL "https://nodejs.org/dist/v${NODE_VER_FULL}/${NODE_PKG}.tar.gz" -o /tmp/node.tar.gz
  
  mkdir -p ~/local
  tar xzf /tmp/node.tar.gz -C ~/local/
  rm -f ~/local/node
  ln -sf ~/local/${NODE_PKG} ~/local/node
  rm -f /tmp/node.tar.gz
  
  export PATH="$HOME/local/node/bin:$PATH"
  
  # 写入所有 shell 配置文件确保 PATH 生效
  for RC in ~/.zshenv ~/.zshrc ~/.bashrc; do
    if ! grep -q 'local/node/bin' "${RC}" 2>/dev/null; then
      echo '' >> "${RC}"
      echo '# Node.js' >> "${RC}"
      echo 'export PATH="$HOME/local/node/bin:$PATH"' >> "${RC}"
    fi
  done
  
  log "Node.js $(node -v) 安装完成"
fi

command -v npm &>/dev/null || err "npm 不可用"

# ---- Claude Code ----
step "安装 Claude Code"

npm install -g @anthropic-ai/claude-code 2>&1 | tail -1
log "Claude Code $(claude --version 2>/dev/null || echo 'installed')"

# ---- API Key ----
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  step "配置 API Key"
  
  # 写入 .zshenv（所有 zsh 场景都会读，最可靠）
  for RC in ~/.zshenv ~/.zshrc ~/.zprofile; do
    if ! grep -q 'ANTHROPIC_API_KEY' "${RC}" 2>/dev/null; then
      echo '' >> "${RC}"
      echo '# Anthropic API Key' >> "${RC}"
      echo "export ANTHROPIC_API_KEY=\"${ANTHROPIC_API_KEY}\"" >> "${RC}"
    fi
  done
  
  log "API Key 已写入 shell 配置（免登录）"
fi

# ---- 完成 ----
echo ""
echo -e "${GREEN}  ╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}  ║   🎉 Claude Code 安装成功！          ║${NC}"
echo -e "${GREEN}  ╚══════════════════════════════════════╝${NC}"
echo ""
echo -e "  使用: ${BLUE}claude${NC}"
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo ""
  echo -e "  ${YELLOW}提示: 如需免登录，设置环境变量:${NC}"
  echo -e "  ${BLUE}echo 'export ANTHROPIC_API_KEY=\"sk-ant-xxx\"' >> ~/.zshenv${NC}"
fi
echo ""
