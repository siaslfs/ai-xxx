#!/usr/bin/env sh
# ============================================================================
# LiteLLM Proxy - Environment Configuration Script
# ============================================================================
# Usage:
#   Install (interactive, requires sudo):
#     curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.sh | sudo bash
#     wget -qO- https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.sh | sudo bash
#
#   Uninstall:
#     curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.sh | sudo bash -s -- --uninstall
#     wget -qO- https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.sh | sudo bash -s -- --uninstall
#
# Supported OS:  Linux (all major distros), macOS, WSL
# Supported Shell: bash, zsh, fish, ksh
# ============================================================================

set -e

# ─── Constants ────────────────────────────────────────────────────────────────
DEFAULT_BASE_URL="https://pool.autelrobotics.com"
SYSTEM_PROFILE_DIR="/etc/profile.d"
SYSTEM_CONFIG_FILE="${SYSTEM_PROFILE_DIR}/litellm-proxy.sh"
FISH_SYSTEM_DIR="/etc/fish/conf.d"
FISH_CONFIG_FILE="${FISH_SYSTEM_DIR}/litellm-proxy.fish"

# Marker tags used to identify our config block in shell rc files (for cleanup)
MARKER_BEGIN="# >>> LiteLLM Proxy Environment >>>"
MARKER_END="# <<< LiteLLM Proxy Environment <<<"

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

# ─── Trap: Ensure clean exit on interrupt ────────────────────────────────────
cleanup() {
    printf "\n"
    warn "操作已被用户中止，所有更改均未生效。"
    printf "\n"
    exit 1
}
trap cleanup INT TERM

# ─── Check root / sudo ──────────────────────────────────────────────────────
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "此脚本需要 root 权限，请使用 sudo 执行:"
        printf "\n"
        printf "    ${BOLD}sudo bash install.sh${RESET}\n"
        printf "    ${DIM}或${RESET}\n"
        printf "    ${BOLD}curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.sh | sudo bash${RESET}\n"
        printf "\n"
        exit 1
    fi
}

# ─── Detect Shell (for display only) ────────────────────────────────────────
detect_shell() {
    TARGET_SHELL=""
    if [ -n "$SHELL" ]; then
        TARGET_SHELL="$(basename "$SHELL")"
    elif command -v getent >/dev/null 2>&1; then
        TARGET_SHELL="$(basename "$(getent passwd "$(whoami)" | cut -d: -f7)")"
    else
        TARGET_SHELL="sh"
    fi
}

# ─── Detect user RC files (for cleaning up old config) ──────────────────────
detect_user_rc_files() {
    _user_home="${SUDO_USER:+$(eval echo ~"$SUDO_USER")}"
    [ -z "$_user_home" ] && _user_home="$HOME"

    USER_RC_FILES=""
    for _rc in \
        "$_user_home/.bashrc" \
        "$_user_home/.bash_profile" \
        "$_user_home/.zshrc" \
        "$_user_home/.zprofile" \
        "$_user_home/.profile" \
        "$_user_home/.config/fish/config.fish" \
        "$_user_home/.kshrc"; do
        if [ -f "$_rc" ] && grep -qF "$MARKER_BEGIN" "$_rc" 2>/dev/null; then
            USER_RC_FILES="$USER_RC_FILES $_rc"
        fi
    done
}

# ─── Clean old config from user RC files ─────────────────────────────────────
cleanup_user_rc() {
    for _rc in $USER_RC_FILES; do
        if [ "$(uname -s)" = "Darwin" ]; then
            sed -i '' "/$MARKER_BEGIN/,/$MARKER_END/d" "$_rc"
            sed -i '' -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$_rc" 2>/dev/null || true
        else
            sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" "$_rc"
            sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$_rc" 2>/dev/null || true
        fi
        info "已清理旧配置: $_rc"
    done
}

# ─── Check if already installed ─────────────────────────────────────────────
is_installed() {
    [ -f "$SYSTEM_CONFIG_FILE" ] && return 0
    [ -f "$FISH_CONFIG_FILE" ] && return 0
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

# ─── Write config to system files ───────────────────────────────────────────
write_config() {
    _auth_token="$1"

    # Write /etc/profile.d/litellm-proxy.sh (bash/zsh/ksh/sh)
    mkdir -p "$SYSTEM_PROFILE_DIR"
    cat > "$SYSTEM_CONFIG_FILE" <<EOF
$MARKER_BEGIN
# Managed by LiteLLM Proxy install script — DO NOT EDIT MANUALLY
export ANTHROPIC_BASE_URL=$DEFAULT_BASE_URL
export ANTHROPIC_AUTH_TOKEN=$_auth_token
export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1
$MARKER_END
EOF
    chmod 644 "$SYSTEM_CONFIG_FILE"

    # Write fish system config if fish is installed
    if command -v fish >/dev/null 2>&1; then
        mkdir -p "$FISH_SYSTEM_DIR"
        cat > "$FISH_CONFIG_FILE" <<EOF
$MARKER_BEGIN
# Managed by LiteLLM Proxy install script — DO NOT EDIT MANUALLY
set -gx ANTHROPIC_BASE_URL $DEFAULT_BASE_URL
set -gx ANTHROPIC_AUTH_TOKEN $_auth_token
set -gx CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS 1
$MARKER_END
EOF
        chmod 644 "$FISH_CONFIG_FILE"
    fi
}

# ─── Remove system config files ─────────────────────────────────────────────
remove_config() {
    [ -f "$SYSTEM_CONFIG_FILE" ] && rm -f "$SYSTEM_CONFIG_FILE"
    [ -f "$FISH_CONFIG_FILE" ] && rm -f "$FISH_CONFIG_FILE"
}

# ─── Uninstall Flow ─────────────────────────────────────────────────────────
do_uninstall() {
    print_banner
    printf "${BOLD}${RED}  ⚙  卸载模式${RESET}\n"
    printf "  ${DIM}────────────────────────────────────────────${RESET}\n\n"

    check_root
    detect_shell

    info "检测到 Shell: ${BOLD}$TARGET_SHELL${RESET}"
    printf "\n"

    if ! is_installed; then
        # Also check user RC files
        detect_user_rc_files
        if [ -z "$USER_RC_FILES" ]; then
            warn "未检测到 LiteLLM Proxy 的环境配置，无需卸载。"
            printf "\n"
            exit 0
        else
            info "未检测到系统级配置，但在用户 RC 文件中发现旧配置。"
        fi
    fi

    # Show what will be removed
    printf "  ${YELLOW}以下系统配置文件将被删除:${RESET}\n\n"

    if [ -f "$SYSTEM_CONFIG_FILE" ]; then
        printf "  ${DIM}┌──────────────────────────────────────────────┐${RESET}\n"
        while IFS= read -r line; do
            printf "  ${DIM}│${RESET} %s\n" "$line"
        done < "$SYSTEM_CONFIG_FILE"
        printf "  ${DIM}└──────────────────────────────────────────────┘${RESET}\n"
        printf "  ${DIM}文件: %s${RESET}\n\n" "$SYSTEM_CONFIG_FILE"
    fi

    if [ -f "$FISH_CONFIG_FILE" ]; then
        printf "  ${DIM}┌──────────────────────────────────────────────┐${RESET}\n"
        while IFS= read -r line; do
            printf "  ${DIM}│${RESET} %s\n" "$line"
        done < "$FISH_CONFIG_FILE"
        printf "  ${DIM}└──────────────────────────────────────────────┘${RESET}\n"
        printf "  ${DIM}文件: %s${RESET}\n\n" "$FISH_CONFIG_FILE"
    fi

    # Check for old user RC configs
    detect_user_rc_files
    if [ -n "$USER_RC_FILES" ]; then
        printf "  ${YELLOW}同时将清理以下用户配置文件中的旧配置:${RESET}\n"
        for _rc in $USER_RC_FILES; do
            printf "    - %s\n" "$_rc"
        done
        printf "\n"
    fi

    printf "${BOLD}${YELLOW}确认卸载? 此操作不可撤销。${RESET}\n"
    printf "请输入 ${BOLD}yes${RESET} 确认卸载: "
    read -r _confirm

    if [ "$_confirm" != "yes" ]; then
        warn "卸载已取消，未做任何更改。"
        printf "\n"
        exit 0
    fi

    # Perform removal
    remove_config

    # Clean user RC files if any
    if [ -n "$USER_RC_FILES" ]; then
        cleanup_user_rc
    fi

    printf "\n"
    success "LiteLLM Proxy 环境变量已成功移除！"
    printf "\n"
    info "新终端将自动生效。当前终端请手动执行:"
    printf "\n"
    printf "    ${BOLD}unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS${RESET}\n"
    printf "\n"
    success "卸载完成！"
    printf "\n"
}

# ─── Install Flow ───────────────────────────────────────────────────────────
do_install() {
    print_banner
    printf "${BOLD}${GREEN}  ⚙  安装模式${RESET}\n"
    printf "  ${DIM}────────────────────────────────────────────${RESET}\n\n"

    check_root

    # ── Step 1: Environment Detection ──
    step "1/3" "环境检测"

    detect_shell

    # Detect OS
    OS_NAME="$(uname -s)"
    OS_ARCH="$(uname -m)"
    case "$OS_NAME" in
        Linux*)   OS_DISPLAY="Linux" ;;
        Darwin*)  OS_DISPLAY="macOS" ;;
        CYGWIN*|MINGW*|MSYS*) OS_DISPLAY="Windows (WSL/Git Bash)" ;;
        *)        OS_DISPLAY="$OS_NAME" ;;
    esac

    info "操作系统:     ${BOLD}$OS_DISPLAY ($OS_ARCH)${RESET}"
    info "Shell 类型:   ${BOLD}$TARGET_SHELL${RESET}"
    info "系统配置目录: ${BOLD}$SYSTEM_PROFILE_DIR${RESET}"
    info "BASE_URL:     ${BOLD}$DEFAULT_BASE_URL${RESET} (内置)"

    if is_installed; then
        printf "\n"
        warn "检测到已有 LiteLLM Proxy 系统级配置，继续安装将覆盖旧配置。"
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

    # Check for old user-level config
    detect_user_rc_files
    if [ -n "$USER_RC_FILES" ]; then
        printf "\n"
        warn "检测到用户 RC 文件中存在旧版配置，安装完成后将自动清理:"
        for _rc in $USER_RC_FILES; do
            printf "    - %s\n" "$_rc"
        done
    fi

    # ── Step 2: Input AUTH_TOKEN ──
    step "2/3" "配置 ANTHROPIC_AUTH_TOKEN"

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

    # ── Step 3: Confirm & Write ──
    step "3/3" "确认并写入系统配置"

    printf "\n"
    printf "  ${BOLD}请确认以下配置信息:${RESET}\n\n"
    printf "  ┌──────────────────────────────────────────────────────────────┐\n"
    printf "  │  ${BOLD}ANTHROPIC_BASE_URL${RESET}                  = %-20s │\n" "$DEFAULT_BASE_URL"
    printf "  │  ${BOLD}ANTHROPIC_AUTH_TOKEN${RESET}                 = %-20s │\n" "$MASKED_TOKEN"
    printf "  │  ${BOLD}CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS${RESET} = %-20s │\n" "1"
    printf "  │                                                              │\n"
    printf "  │  ${DIM}写入文件: %-48s${RESET} │\n" "$SYSTEM_CONFIG_FILE"
    printf "  └──────────────────────────────────────────────────────────────┘\n"
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
    write_config "$INPUT_AUTH_TOKEN"

    # Clean up old user RC configs
    if [ -n "$USER_RC_FILES" ]; then
        printf "\n"
        cleanup_user_rc
    fi

    # Export to current session
    export ANTHROPIC_BASE_URL=$DEFAULT_BASE_URL
    export ANTHROPIC_AUTH_TOKEN=$INPUT_AUTH_TOKEN
    export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1

    printf "\n"
    printf "  ${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}\n"
    printf "  ${GREEN}${BOLD}║                                                        ║${RESET}\n"
    printf "  ${GREEN}${BOLD}║        ✅  安装成功！配置已写入系统目录。                ║${RESET}\n"
    printf "  ${GREEN}${BOLD}║                                                        ║${RESET}\n"
    printf "  ${GREEN}${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}\n"
    printf "\n"
    info "新打开的终端将自动加载以上环境变量，无需手动 source。"
    printf "\n"
    info "卸载方式:"
    printf "\n"
    printf "    ${BOLD}sudo bash install.sh --uninstall${RESET}\n"
    printf "    ${DIM}或${RESET}\n"
    printf "    ${BOLD}curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.sh | sudo bash -s -- --uninstall${RESET}\n"
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
            printf "    ${BOLD}安装 (交互式，需要 sudo):${RESET}\n"
            printf "      sudo bash install.sh\n"
            printf "      curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.sh | sudo bash\n\n"
            printf "    ${BOLD}卸载:${RESET}\n"
            printf "      sudo bash install.sh --uninstall\n"
            printf "      curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.sh | sudo bash -s -- --uninstall\n\n"
            printf "    ${BOLD}帮助:${RESET}\n"
            printf "      bash install.sh --help\n\n"
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

    exit 0
}

main "$@"
