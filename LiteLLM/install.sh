#!/usr/bin/env sh
# ============================================================================
# LiteLLM Proxy - Environment Configuration Script
# ============================================================================
# Usage:
#   Install (interactive):
#     curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.sh | bash
#     wget -qO- https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.sh | bash
#
#   Uninstall:
#     curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.sh | bash -s -- --uninstall
#     wget -qO- https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.sh | bash -s -- --uninstall
#
# Supported OS:  Linux (all major distros), macOS, WSL
# Supported Shell: bash, zsh, fish, ksh
# ============================================================================

set -e

# ─── Color & Style Definitions ──────────────────────────────────────────────
setup_colors() {
    if [ -t 1 ] && [ -n "$(tput colors 2>/dev/null)" ] && [ "$(tput colors 2>/dev/null)" -ge 8 ]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        CYAN='\033[0;36m'
        BOLD='\033[1m'
        DIM='\033[2m'
        RESET='\033[0m'
    else
        RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' RESET=''
    fi
}

# ─── Utility Functions ──────────────────────────────────────────────────────
print_banner() {
    printf "\n"
    printf "${CYAN}${BOLD}"
    printf "  ╔══════════════════════════════════════════════════════════╗\n"
    printf "  ║                                                        ║\n"
    printf "  ║          LiteLLM Proxy  Environment Setup              ║\n"
    printf "  ║                                                        ║\n"
    printf "  ╚══════════════════════════════════════════════════════════╝\n"
    printf "${RESET}\n"
}

info()    { printf "${BLUE}[INFO]${RESET}    %s\n" "$1"; }
success() { printf "${GREEN}[OK]${RESET}      %s\n" "$1"; }
warn()    { printf "${YELLOW}[WARN]${RESET}    %s\n" "$1"; }
error()   { printf "${RED}[ERROR]${RESET}   %s\n" "$1"; }
step()    { printf "\n${BOLD}${CYAN}▶ Step %s: %s${RESET}\n" "$1" "$2"; }

# Marker tags used to identify our config block in shell rc files
MARKER_BEGIN="# >>> LiteLLM Proxy Environment >>>"
MARKER_END="# <<< LiteLLM Proxy Environment <<<"

# ─── Trap: Ensure clean exit on interrupt ────────────────────────────────────
# If the user presses Ctrl+C at any point, nothing is written.
cleanup() {
    printf "\n"
    warn "操作已被用户中止，所有更改均未生效。"
    printf "\n"
    exit 1
}
trap cleanup INT TERM

# ─── Detect Shell & RC File ─────────────────────────────────────────────────
detect_shell_rc() {
    # Determine the user's login shell
    TARGET_SHELL=""
    RC_FILES=""

    # Try $SHELL first, fallback to /etc/passwd
    if [ -n "$SHELL" ]; then
        TARGET_SHELL="$(basename "$SHELL")"
    elif command -v getent >/dev/null 2>&1; then
        TARGET_SHELL="$(basename "$(getent passwd "$(whoami)" | cut -d: -f7)")"
    else
        TARGET_SHELL="sh"
    fi

    case "$TARGET_SHELL" in
        bash)
            # On macOS, bash uses .bash_profile; on Linux, .bashrc
            if [ "$(uname -s)" = "Darwin" ]; then
                RC_FILES="$HOME/.bash_profile $HOME/.bashrc"
            else
                RC_FILES="$HOME/.bashrc $HOME/.bash_profile"
            fi
            ;;
        zsh)
            RC_FILES="$HOME/.zshrc $HOME/.zprofile"
            ;;
        fish)
            RC_FILES="$HOME/.config/fish/config.fish"
            ;;
        ksh)
            RC_FILES="$HOME/.kshrc $HOME/.profile"
            ;;
        *)
            RC_FILES="$HOME/.profile"
            ;;
    esac

    # Pick the first existing file, or the first candidate if none exist
    SELECTED_RC=""
    for f in $RC_FILES; do
        if [ -f "$f" ]; then
            SELECTED_RC="$f"
            break
        fi
    done
    if [ -z "$SELECTED_RC" ]; then
        # Use the first candidate and create it
        for f in $RC_FILES; do
            SELECTED_RC="$f"
            break
        done
    fi
}

# ─── Check if already installed ─────────────────────────────────────────────
is_installed() {
    if [ -f "$SELECTED_RC" ] && grep -qF "$MARKER_BEGIN" "$SELECTED_RC" 2>/dev/null; then
        return 0
    fi
    return 1
}

# ─── Mask token for display ─────────────────────────────────────────────────
mask_token() {
    _token="$1"
    _len=${#_token}
    if [ "$_len" -le 8 ]; then
        printf "%s" "********"
    else
        _prefix=$(printf "%s" "$_token" | cut -c1-4)
        _suffix=$(printf "%s" "$_token" | cut -c$((_len - 3))-)
        printf "%s****%s" "$_prefix" "$_suffix"
    fi
}

# ─── Write config to RC file ────────────────────────────────────────────────
write_config() {
    _base_url="$1"
    _auth_token="$2"
    _rc_file="$3"

    # Ensure the directory exists
    _dir="$(dirname "$_rc_file")"
    if [ ! -d "$_dir" ]; then
        mkdir -p "$_dir"
    fi

    # If already installed, remove old block first
    if is_installed; then
        remove_config "$_rc_file"
    fi

    # Determine export syntax based on shell type
    if echo "$_rc_file" | grep -q "fish"; then
        cat >> "$_rc_file" <<EOF

$MARKER_BEGIN
# Managed by LiteLLM Proxy install script — DO NOT EDIT MANUALLY
set -gx ANTHROPIC_BASE_URL "$_base_url"
set -gx ANTHROPIC_AUTH_TOKEN "$_auth_token"
$MARKER_END
EOF
    else
        cat >> "$_rc_file" <<EOF

$MARKER_BEGIN
# Managed by LiteLLM Proxy install script — DO NOT EDIT MANUALLY
export ANTHROPIC_BASE_URL="$_base_url"
export ANTHROPIC_AUTH_TOKEN="$_auth_token"
$MARKER_END
EOF
    fi
}

# ─── Remove config from RC file ─────────────────────────────────────────────
remove_config() {
    _rc_file="$1"

    if [ ! -f "$_rc_file" ]; then
        return 0
    fi

    # Use sed to remove the block between markers (inclusive)
    # macOS sed requires slightly different syntax
    if [ "$(uname -s)" = "Darwin" ]; then
        sed -i '' "/$MARKER_BEGIN/,/$MARKER_END/d" "$_rc_file"
    else
        sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" "$_rc_file"
    fi

    # Clean up any trailing blank lines left behind
    if [ "$(uname -s)" = "Darwin" ]; then
        sed -i '' -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$_rc_file" 2>/dev/null || true
    else
        sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$_rc_file" 2>/dev/null || true
    fi
}

# ─── Uninstall Flow ─────────────────────────────────────────────────────────
do_uninstall() {
    print_banner
    printf "${BOLD}${RED}  ⚙  卸载模式${RESET}\n"
    printf "  ${DIM}────────────────────────────────────────────${RESET}\n\n"

    detect_shell_rc

    info "检测到 Shell: ${BOLD}$TARGET_SHELL${RESET}"
    info "配置文件路径: ${BOLD}$SELECTED_RC${RESET}"
    printf "\n"

    if ! is_installed; then
        warn "未检测到 LiteLLM Proxy 的环境配置，无需卸载。"
        printf "\n"
        exit 0
    fi

    # Show what will be removed
    printf "  ${YELLOW}以下内容将从 ${BOLD}$SELECTED_RC${RESET}${YELLOW} 中移除:${RESET}\n\n"
    printf "  ${DIM}┌──────────────────────────────────────────────┐${RESET}\n"
    sed -n "/$MARKER_BEGIN/,/$MARKER_END/p" "$SELECTED_RC" | while IFS= read -r line; do
        printf "  ${DIM}│${RESET} %s\n" "$line"
    done
    printf "  ${DIM}└──────────────────────────────────────────────┘${RESET}\n\n"

    printf "${BOLD}${YELLOW}确认卸载? 此操作不可撤销。${RESET}\n"
    printf "请输入 ${BOLD}yes${RESET} 确认卸载: "
    read -r _confirm

    if [ "$_confirm" != "yes" ]; then
        warn "卸载已取消，未做任何更改。"
        printf "\n"
        exit 0
    fi

    # Perform removal
    remove_config "$SELECTED_RC"

    printf "\n"
    success "LiteLLM Proxy 环境变量已成功移除！"
    printf "\n"
    info "请执行以下命令使更改生效，或重新打开终端:"
    printf "\n"
    printf "    ${BOLD}source %s${RESET}\n" "$SELECTED_RC"
    printf "\n"
    # Also unset from current session
    unset ANTHROPIC_BASE_URL 2>/dev/null || true
    unset ANTHROPIC_AUTH_TOKEN 2>/dev/null || true
    success "卸载完成！"
    printf "\n"
}

# ─── Install Flow ───────────────────────────────────────────────────────────
do_install() {
    print_banner
    printf "${BOLD}${GREEN}  ⚙  安装模式${RESET}\n"
    printf "  ${DIM}────────────────────────────────────────────${RESET}\n\n"

    # ── Step 1: Environment Detection ──
    step "1/4" "环境检测"

    detect_shell_rc

    # Detect OS
    OS_NAME="$(uname -s)"
    OS_ARCH="$(uname -m)"
    case "$OS_NAME" in
        Linux*)   OS_DISPLAY="Linux" ;;
        Darwin*)  OS_DISPLAY="macOS" ;;
        CYGWIN*|MINGW*|MSYS*) OS_DISPLAY="Windows (WSL/Git Bash)" ;;
        *)        OS_DISPLAY="$OS_NAME" ;;
    esac

    info "操作系统:   ${BOLD}$OS_DISPLAY ($OS_ARCH)${RESET}"
    info "Shell 类型: ${BOLD}$TARGET_SHELL${RESET}"
    info "配置文件:   ${BOLD}$SELECTED_RC${RESET}"

    if is_installed; then
        printf "\n"
        warn "检测到已有 LiteLLM Proxy 配置，继续安装将覆盖旧配置。"
        printf "是否继续? [y/N]: "
        read -r _overwrite
        case "$_overwrite" in
            [yY]|[yY][eE][sS]) ;;
            *)
                warn "安装已取消。"
                printf "\n"
                exit 0
                ;;
        esac
    fi

    # ── Step 2: Input BASE_URL ──
    step "2/4" "配置 ANTHROPIC_BASE_URL"

    printf "\n"
    printf "  ${DIM}LiteLLM 远程服务器地址 (需包含 http:// 或 https:// 前缀)${RESET}\n"
    printf "  ${DIM}示例: http://34.81.219.7:4000${RESET}\n\n"

    printf "  请输入 ANTHROPIC_BASE_URL: "
    read -r INPUT_BASE_URL

    # Validate input
    if [ -z "$INPUT_BASE_URL" ]; then
        error "BASE_URL 不能为空，安装中止。"
        printf "\n"
        exit 1
    fi

    # Check for http:// or https:// prefix
    case "$INPUT_BASE_URL" in
        http://*|https://*)
            ;;
        *)
            warn "输入的地址缺少 http:// 或 https:// 前缀。"
            printf "  是否自动添加 ${BOLD}http://${RESET} 前缀? [Y/n]: "
            read -r _add_prefix
            case "$_add_prefix" in
                [nN]|[nN][oO])
                    error "请输入包含协议前缀的完整地址，安装中止。"
                    printf "\n"
                    exit 1
                    ;;
                *)
                    INPUT_BASE_URL="http://$INPUT_BASE_URL"
                    info "已自动补全为: ${BOLD}$INPUT_BASE_URL${RESET}"
                    ;;
            esac
            ;;
    esac

    success "ANTHROPIC_BASE_URL 已设置"

    # ── Step 3: Input AUTH_TOKEN ──
    step "3/4" "配置 ANTHROPIC_AUTH_TOKEN"

    printf "\n"
    printf "  ${DIM}LiteLLM 的 Virtual Key (以 sk- 开头)${RESET}\n\n"

    # Read token without echo for security
    printf "  请输入 ANTHROPIC_AUTH_TOKEN: "
    stty -echo 2>/dev/null || true
    read -r INPUT_AUTH_TOKEN
    stty echo 2>/dev/null || true
    printf "\n"

    if [ -z "$INPUT_AUTH_TOKEN" ]; then
        error "AUTH_TOKEN 不能为空，安装中止。"
        printf "\n"
        exit 1
    fi

    # Validate sk- prefix
    case "$INPUT_AUTH_TOKEN" in
        sk-*)
            ;;
        *)
            warn "输入的 Token 不以 sk- 开头，请确认是否正确。"
            printf "  是否继续使用该 Token? [y/N]: "
            read -r _continue_token
            case "$_continue_token" in
                [yY]|[yY][eE][sS]) ;;
                *)
                    error "安装中止。"
                    printf "\n"
                    exit 1
                    ;;
            esac
            ;;
    esac

    MASKED_TOKEN="$(mask_token "$INPUT_AUTH_TOKEN")"
    success "ANTHROPIC_AUTH_TOKEN 已设置"

    # ── Step 4: Confirm & Write ──
    step "4/4" "确认并写入配置"

    printf "\n"
    printf "  ${BOLD}请确认以下配置信息:${RESET}\n\n"
    printf "  ┌──────────────────────────────────────────────────────────┐\n"
    printf "  │  ${BOLD}ANTHROPIC_BASE_URL${RESET}   = %-36s │\n" "$INPUT_BASE_URL"
    printf "  │  ${BOLD}ANTHROPIC_AUTH_TOKEN${RESET}  = %-36s │\n" "$MASKED_TOKEN"
    printf "  │                                                        │\n"
    printf "  │  ${DIM}写入文件: %-44s${RESET} │\n" "$SELECTED_RC"
    printf "  └──────────────────────────────────────────────────────────┘\n"
    printf "\n"

    printf "  ${BOLD}${YELLOW}确认写入以上配置? [y/N]:${RESET} "
    read -r _final_confirm

    case "$_final_confirm" in
        [yY]|[yY][eE][sS])
            ;;
        *)
            warn "安装已取消，所有更改均未生效。"
            printf "\n"
            exit 0
            ;;
    esac

    # Perform the write
    write_config "$INPUT_BASE_URL" "$INPUT_AUTH_TOKEN" "$SELECTED_RC"

    printf "\n"
    printf "  ${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}\n"
    printf "  ${GREEN}${BOLD}║                                                        ║${RESET}\n"
    printf "  ${GREEN}${BOLD}║        ✅  安装成功！配置已写入完成。                    ║${RESET}\n"
    printf "  ${GREEN}${BOLD}║                                                        ║${RESET}\n"
    printf "  ${GREEN}${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}\n"
    printf "\n"
    info "请执行以下命令使配置立即生效，或重新打开终端:"
    printf "\n"
    printf "    ${BOLD}source %s${RESET}\n" "$SELECTED_RC"
    printf "\n"
    info "卸载方式:"
    printf "\n"
    printf "    ${BOLD}curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.sh | bash -s -- --uninstall${RESET}\n"
    printf "\n"
    success "全部完成！"
    printf "\n"
}

# ─── Main Entry Point ───────────────────────────────────────────────────────
main() {
    setup_colors

    # Check if stdin is a terminal (needed for interactive input)
    # When piped via curl | bash, we need to read from /dev/tty
    if [ ! -t 0 ]; then
        # Redirect stdin from /dev/tty for interactive input
        exec < /dev/tty
    fi

    # Parse arguments
    case "${1:-}" in
        --uninstall|-u|uninstall)
            do_uninstall
            ;;
        --help|-h|help)
            print_banner
            printf "  ${BOLD}用法:${RESET}\n\n"
            printf "    ${BOLD}安装 (交互式):${RESET}\n"
            printf "      curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.sh | bash\n\n"
            printf "    ${BOLD}卸载:${RESET}\n"
            printf "      curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.sh | bash -s -- --uninstall\n\n"
            printf "    ${BOLD}帮助:${RESET}\n"
            printf "      curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.sh | bash -s -- --help\n\n"
            ;;
        ""|--install|-i|install)
            do_install
            ;;
        *)
            error "未知参数: $1"
            printf "  使用 ${BOLD}--help${RESET} 查看帮助信息。\n\n"
            exit 1
            ;;
    esac
}

main "$@"
