#!/bin/bash
# =============================================================
# Mac 开发环境一键配置
# 
# 安装: Node.js · Claude Code · Google Chrome · 飞书
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/mac-setup/install.sh | bash
#   
#   # 带 API Key（Claude Code 免登录）:
#   curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/mac-setup/install.sh | ANTHROPIC_API_KEY=sk-ant-xxx bash
# =============================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}  [✓]${NC} $*"; }
warn() { echo -e "${YELLOW}  [!]${NC} $*"; }
err()  { echo -e "${RED}  [✗]${NC} $*"; exit 1; }
step() { echo -e "\n${BLUE}==>${NC} ${BLUE}$*${NC}"; }

echo ""
echo -e "${BLUE}  ┌──────────────────────────────────┐${NC}"
echo -e "${BLUE}  │     🖥️  Mac 开发环境一键配置      │${NC}"
echo -e "${BLUE}  │   Node · Claude · Chrome · 飞书   │${NC}"
echo -e "${BLUE}  └──────────────────────────────────┘${NC}"
echo ""

# ---- 系统检测 ----
step "检测系统环境"

OS="$(uname -s)"
ARCH="$(uname -m)"

[ "${OS}" = "Darwin" ] || err "此脚本仅支持 macOS"

log "macOS $(sw_vers -productVersion)"

case "${ARCH}" in
  arm64)  log "架构: Apple Silicon (ARM64)"; CHROME_ARCH="arm64" ;;
  x86_64) log "架构: Intel (x86_64)"; CHROME_ARCH="x86_64" ;;
  *)      err "不支持的架构: ${ARCH}" ;;
esac

command -v curl &>/dev/null || err "需要 curl"

# ---- Google Chrome ----
step "安装 Google Chrome"

if [ -d "/Applications/Google Chrome.app" ]; then
  CHROME_VER=$(/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --version 2>/dev/null | awk '{print $NF}')
  log "Google Chrome ${CHROME_VER} 已安装，跳过"
else
  log "下载 Google Chrome..."
  curl -fsSL "https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg" -o /tmp/googlechrome.dmg
  
  log "安装中..."
  hdiutil attach /tmp/googlechrome.dmg -quiet -nobrowse -mountpoint /tmp/chrome-mount
  cp -R "/tmp/chrome-mount/Google Chrome.app" /Applications/
  hdiutil detach /tmp/chrome-mount -quiet
  rm -f /tmp/googlechrome.dmg
  
  log "Google Chrome 已安装"
fi

# ---- 飞书 ----
step "安装飞书"

if [ -d "/Applications/Lark.app" ] || [ -d "/Applications/飞书.app" ] || [ -d "/Applications/Feishu.app" ]; then
  log "飞书已安装，跳过"
else
  # 尝试多个已知下载链接
  FEISHU_URLS=(
    "https://lf-flow-web-cdn.doubao.com/obj/flow-doubao/doubao/web/pkg/Feishu-mac_universal.dmg"
    "https://lf3-package.feishucdn.com/package/lark/Feishu-mac_universal.dmg"
  )
  
  DOWNLOADED=0
  for URL in "${FEISHU_URLS[@]}"; do
    log "尝试下载飞书..."
    if curl -fsSL "${URL}" -o /tmp/feishu.dmg 2>/dev/null; then
      DOWNLOADED=1
      break
    fi
  done
  
  if [ "${DOWNLOADED}" = "1" ]; then
    log "安装中..."
    hdiutil attach /tmp/feishu.dmg -quiet -nobrowse -mountpoint /tmp/feishu-mount
    
    FEISHU_APP=$(find /tmp/feishu-mount -maxdepth 1 -name "*.app" | head -1)
    if [ -n "${FEISHU_APP}" ]; then
      cp -R "${FEISHU_APP}" /Applications/
      log "飞书已安装"
    else
      warn "未找到 .app 文件，请手动安装"
    fi
    
    hdiutil detach /tmp/feishu-mount -quiet 2>/dev/null || true
    rm -f /tmp/feishu.dmg
  else
    warn "飞书自动下载失败，请手动安装: https://www.feishu.cn/download"
  fi
fi

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
  case "${ARCH}" in
    arm64)  NODE_PKG="node-v${NODE_VER_FULL}-darwin-arm64" ;;
    x86_64) NODE_PKG="node-v${NODE_VER_FULL}-darwin-x64" ;;
  esac

  log "下载 Node.js ${NODE_VER_FULL}..."
  curl -fsSL "https://nodejs.org/dist/v${NODE_VER_FULL}/${NODE_PKG}.tar.gz" -o /tmp/node.tar.gz
  
  mkdir -p ~/local
  tar xzf /tmp/node.tar.gz -C ~/local/
  rm -f ~/local/node
  ln -sf ~/local/${NODE_PKG} ~/local/node
  rm -f /tmp/node.tar.gz
  
  export PATH="$HOME/local/node/bin:$PATH"
  
  for RC in ~/.zshenv ~/.zshrc; do
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

if command -v claude &>/dev/null; then
  log "Claude Code $(claude --version 2>/dev/null) 已安装，跳过"
else
  npm install -g @anthropic-ai/claude-code 2>&1 | tail -1
  log "Claude Code $(claude --version 2>/dev/null || echo 'installed')"
fi

# ---- API Key ----
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  step "配置 Anthropic API Key"
  
  for RC in ~/.zshenv ~/.zshrc ~/.zprofile; do
    if ! grep -q 'ANTHROPIC_API_KEY' "${RC}" 2>/dev/null; then
      echo '' >> "${RC}"
      echo '# Anthropic API Key' >> "${RC}"
      echo "export ANTHROPIC_API_KEY=\"${ANTHROPIC_API_KEY}\"" >> "${RC}"
    fi
  done
  
  log "API Key 已配置（免登录）"
fi

# ---- 完成 ----
echo ""
echo -e "${GREEN}  ╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}  ║      🎉 环境配置完成！               ║${NC}"
echo -e "${GREEN}  ╚══════════════════════════════════════╝${NC}"
echo ""
echo -e "  已安装:"
echo -e "    ${BLUE}▸${NC} Google Chrome"
echo -e "    ${BLUE}▸${NC} 飞书"
echo -e "    ${BLUE}▸${NC} Node.js $(node -v 2>/dev/null || echo '')"
echo -e "    ${BLUE}▸${NC} Claude Code"
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  echo -e "    ${BLUE}▸${NC} Anthropic API Key ✓"
fi
echo ""
echo -e "  ${YELLOW}请重新打开终端使配置生效${NC}"
echo ""
