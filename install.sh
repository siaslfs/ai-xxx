#!/bin/bash
set -euo pipefail

# ============================================================================
# LiteLLM Proxy Environment Setup Script
# Supports: macOS, Linux (Ubuntu, Debian, CentOS, Arch, etc.)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/litellm-setup/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/litellm-setup/install.sh | bash -s -- \
#       --base-url http://34.81.219.7:4000 --auth-token sk-xxxxx
#
# What it does:
#   1. Sets ANTHROPIC_BASE_URL  (LiteLLM proxy address)
#   2. Sets ANTHROPIC_AUTH_TOKEN (LiteLLM virtual key, sk-...)
#   3. Persists them in your shell profile so they survive restarts
# ============================================================================

# ── Colors ───────────────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'
ACCENT='\033[38;2;114;137;218m'     # Soft blue
SUCCESS='\033[38;2;67;181;129m'     # Green
WARN='\033[38;2;250;166;26m'        # Amber
ERROR='\033[38;2;237;66;69m'        # Red
INFO='\033[38;2;88;166;255m'        # Light blue
MUTED='\033[38;2;153;153;153m'      # Gray
NC='\033[0m'                         # Reset

# ── Globals ──────────────────────────────────────────────────────────────────
ANTHROPIC_BASE_URL_VALUE=""
ANTHROPIC_AUTH_TOKEN_VALUE=""
SHELL_PROFILE=""
DRY_RUN=0
UNINSTALL=0
QUIET=0
FORCE=0

# ── Banner ───────────────────────────────────────────────────────────────────
print_banner() {
    echo ""
    echo -e "${ACCENT}${BOLD}"
    cat << 'EOF'
    ╔══════════════════════════════════════════════════════╗
    ║                                                      ║
    ║     ██╗     ██╗████████╗███████╗██╗     ██╗     ███╗ ║
    ║     ██║     ██║╚══██╔══╝██╔════╝██║     ██║     ████╗║
    ║     ██║     ██║   ██║   █████╗  ██║     ██║     ██╔██║
    ║     ██║     ██║   ██║   ██╔══╝  ██║     ██║     ██║╚█║
    ║     ███████╗██║   ██║   ███████╗███████╗███████╗██║ █║
    ║     ╚══════╝╚═╝   ╚═╝   ╚══════╝╚══════╝╚══════╝╚═╝ ║
    ║                                                      ║
    ║          LiteLLM Proxy Environment Setup             ║
    ║                                                      ║
    ╚══════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "  ${MUTED}Configure ANTHROPIC_BASE_URL & ANTHROPIC_AUTH_TOKEN${NC}"
    echo ""
}

# ── Usage ────────────────────────────────────────────────────────────────────
print_usage() {
    echo -e "${BOLD}Usage:${NC}"
    echo -e "  ${INFO}curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/litellm-setup/install.sh | bash${NC}"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo -e "  ${INFO}--base-url${NC} <url>       LiteLLM proxy address (e.g. http://34.81.219.7:4000)"
    echo -e "  ${INFO}--auth-token${NC} <token>    LiteLLM virtual key (sk-...)"
    echo -e "  ${INFO}--dry-run${NC}              Show what would be done without making changes"
    echo -e "  ${INFO}--uninstall${NC}            Remove the environment variables from shell profile"
    echo -e "  ${INFO}--quiet${NC}                Minimal output"
    echo -e "  ${INFO}--force${NC}                Overwrite existing values without prompting"
    echo -e "  ${INFO}--help${NC}                 Show this help message"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo -e "  ${MUTED}# Interactive mode (will prompt for values):${NC}"
    echo -e "  curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/litellm-setup/install.sh | bash"
    echo ""
    echo -e "  ${MUTED}# Non-interactive mode:${NC}"
    echo -e "  curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/litellm-setup/install.sh | bash -s -- \\"
    echo -e "      --base-url http://34.81.219.7:4000 --auth-token sk-your-key"
    echo ""
}

# ── Helpers ──────────────────────────────────────────────────────────────────
log_info()    { [[ "$QUIET" == "1" ]] && return; echo -e "${INFO}i${NC} $*"; }
log_success() { echo -e "${SUCCESS}✓${NC} $*"; }
log_warn()    { echo -e "${WARN}!${NC} $*"; }
log_error()   { echo -e "${ERROR}✗${NC} $*"; }
log_step()    { [[ "$QUIET" == "1" ]] && return; echo -e "${ACCENT}→${NC} $*"; }

is_promptable() {
    [[ -t 0 ]] && [[ -t 1 ]]
}

prompt_value() {
    local prompt_text="$1"
    local default_value="${2:-}"
    local result=""

    if [[ -n "$default_value" ]]; then
        echo -en "${BOLD}${prompt_text}${NC} ${MUTED}[${default_value}]${NC}: " >&2
    else
        echo -en "${BOLD}${prompt_text}${NC}: " >&2
    fi

    if is_promptable; then
        read -r result </dev/tty
    else
        read -r result
    fi

    if [[ -z "$result" && -n "$default_value" ]]; then
        result="$default_value"
    fi

    echo "$result"
}

prompt_confirm() {
    local prompt_text="$1"
    local default="${2:-y}"
    local yn_hint="Y/n"
    [[ "$default" == "n" ]] && yn_hint="y/N"

    echo -en "${BOLD}${prompt_text}${NC} ${MUTED}[${yn_hint}]${NC}: " >&2
    local reply=""
    if is_promptable; then
        read -r reply </dev/tty
    else
        read -r reply
    fi
    reply="${reply:-$default}"

    case "$reply" in
        [Yy]*) return 0 ;;
        *)     return 1 ;;
    esac
}

# ── OS / Shell Detection ────────────────────────────────────────────────────
detect_os() {
    local os=""
    os="$(uname -s 2>/dev/null || echo "Unknown")"
    case "$os" in
        Darwin)  echo "macOS" ;;
        Linux)   echo "Linux" ;;
        MINGW*|MSYS*|CYGWIN*)  echo "Windows" ;;
        *)       echo "$os" ;;
    esac
}

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "${NAME:-Unknown}"
    elif [[ -f /etc/lsb-release ]]; then
        # shellcheck disable=SC1091
        . /etc/lsb-release
        echo "${DISTRIB_ID:-Unknown}"
    elif command -v lsb_release &>/dev/null; then
        lsb_release -si
    else
        echo "Unknown"
    fi
}

detect_shell_profile() {
    local current_shell=""
    current_shell="$(basename "${SHELL:-/bin/bash}")"

    case "$current_shell" in
        zsh)
            if [[ -f "$HOME/.zshrc" ]]; then
                echo "$HOME/.zshrc"
            else
                echo "$HOME/.zprofile"
            fi
            ;;
        bash)
            if [[ "$(detect_os)" == "macOS" ]]; then
                # macOS uses .bash_profile by default for login shells
                if [[ -f "$HOME/.bash_profile" ]]; then
                    echo "$HOME/.bash_profile"
                elif [[ -f "$HOME/.bashrc" ]]; then
                    echo "$HOME/.bashrc"
                else
                    echo "$HOME/.bash_profile"
                fi
            else
                if [[ -f "$HOME/.bashrc" ]]; then
                    echo "$HOME/.bashrc"
                elif [[ -f "$HOME/.bash_profile" ]]; then
                    echo "$HOME/.bash_profile"
                else
                    echo "$HOME/.bashrc"
                fi
            fi
            ;;
        fish)
            echo "$HOME/.config/fish/config.fish"
            ;;
        *)
            # Fallback: try common profiles
            if [[ -f "$HOME/.profile" ]]; then
                echo "$HOME/.profile"
            elif [[ -f "$HOME/.bashrc" ]]; then
                echo "$HOME/.bashrc"
            else
                echo "$HOME/.profile"
            fi
            ;;
    esac
}

get_shell_export_syntax() {
    local current_shell=""
    current_shell="$(basename "${SHELL:-/bin/bash}")"
    local var_name="$1"
    local var_value="$2"

    case "$current_shell" in
        fish)
            echo "set -gx ${var_name} \"${var_value}\""
            ;;
        *)
            echo "export ${var_name}=\"${var_value}\""
            ;;
    esac
}

# ── Validation ───────────────────────────────────────────────────────────────
validate_base_url() {
    local url="$1"
    if [[ -z "$url" ]]; then
        log_error "Base URL cannot be empty." >&2
        return 1
    fi
    if [[ ! "$url" =~ ^https?:// ]]; then
        log_error "Base URL must start with ${INFO}http://${NC} or ${INFO}https://${NC}" >&2
        log_info  "Example: ${INFO}http://34.81.219.7:4000${NC}" >&2
        return 1
    fi
    # Remove trailing slash for consistency
    url="${url%/}"
    echo "$url"
    return 0
}

validate_auth_token() {
    local token="$1"
    if [[ -z "$token" ]]; then
        log_error "Auth token cannot be empty." >&2
        return 1
    fi
    if [[ ! "$token" =~ ^sk- ]]; then
        log_warn "Token does not start with ${INFO}sk-${NC}. Are you sure this is correct?" >&2
        if is_promptable; then
            if ! prompt_confirm "Continue anyway?"; then
                return 1
            fi
        fi
    fi
    echo "$token"
    return 0
}

# ── Check Existing Config ───────────────────────────────────────────────────
check_existing_env() {
    local var_name="$1"
    local current_value="${!var_name:-}"

    if [[ -n "$current_value" ]]; then
        return 0  # exists
    fi
    return 1  # not set
}

check_profile_has_var() {
    local profile="$1"
    local var_name="$2"

    if [[ -f "$profile" ]] && grep -q "^export ${var_name}=" "$profile" 2>/dev/null; then
        return 0
    fi
    if [[ -f "$profile" ]] && grep -q "^set -gx ${var_name} " "$profile" 2>/dev/null; then
        return 0
    fi
    return 1
}

# ── Write to Profile ────────────────────────────────────────────────────────
write_env_to_profile() {
    local profile="$1"
    local var_name="$2"
    local var_value="$3"

    local export_line=""
    export_line="$(get_shell_export_syntax "$var_name" "$var_value")"

    # Create profile if it doesn't exist
    if [[ ! -f "$profile" ]]; then
        log_step "Creating ${INFO}${profile}${NC}"
        mkdir -p "$(dirname "$profile")"
        touch "$profile"
    fi

    # Create backup
    local backup="${profile}.litellm-backup-$(date +%Y%m%d-%H%M%S)"
    cp "$profile" "$backup"
    log_info "Backup saved to ${MUTED}${backup}${NC}"

    # Remove old entry if exists (handles both export and set -gx)
    local tmp_file=""
    tmp_file="$(mktemp)"
    grep -v "^export ${var_name}=" "$profile" 2>/dev/null | \
        grep -v "^set -gx ${var_name} " > "$tmp_file" || true
    mv "$tmp_file" "$profile"

    # Append new value with a marker comment
    echo "" >> "$profile"
    echo "# [LiteLLM Proxy] Added by install script on $(date '+%Y-%m-%d %H:%M:%S')" >> "$profile"
    echo "${export_line}" >> "$profile"

    log_success "Written to ${INFO}${profile}${NC}: ${MUTED}${export_line}${NC}"
}

# ── Uninstall ────────────────────────────────────────────────────────────────
do_uninstall() {
    local profile=""
    profile="$(detect_shell_profile)"

    echo -e "${BOLD}Removing LiteLLM Proxy environment variables...${NC}"
    echo ""

    local removed=0

    for var_name in ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN; do
        if [[ -f "$profile" ]] && grep -q "${var_name}" "$profile"; then
            local backup="${profile}.litellm-backup-$(date +%Y%m%d-%H%M%S)"
            cp "$profile" "$backup"

            local tmp_file=""
            tmp_file="$(mktemp)"
            # Remove the variable line and the comment line above it
            grep -v "^export ${var_name}=" "$profile" | \
                grep -v "^set -gx ${var_name} " | \
                grep -v "# \[LiteLLM Proxy\]" > "$tmp_file" || true
            mv "$tmp_file" "$profile"

            log_success "Removed ${INFO}${var_name}${NC} from ${INFO}${profile}${NC}"
            removed=$((removed + 1))
        else
            log_info "${INFO}${var_name}${NC} not found in ${INFO}${profile}${NC}"
        fi
    done

    echo ""
    if [[ "$removed" -gt 0 ]]; then
        log_success "Cleanup complete. Restart your terminal or run:"
        echo -e "  ${INFO}source ${profile}${NC}"
    else
        log_info "Nothing to remove."
    fi
}

# ── Connectivity Test ────────────────────────────────────────────────────────
test_connection() {
    local url="$1"
    local token="$2"

    log_step "Testing connection to ${INFO}${url}${NC}..."

    local health_url="${url}/health"
    local http_code=""

    if command -v curl &>/dev/null; then
        http_code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "$health_url" 2>/dev/null || echo "000")"
    elif command -v wget &>/dev/null; then
        http_code="$(wget -q --spider --timeout=5 -S "$health_url" 2>&1 | grep 'HTTP/' | tail -1 | awk '{print $2}' || echo "000")"
    else
        log_warn "Neither curl nor wget found. Skipping connectivity test."
        return 0
    fi

    case "$http_code" in
        200)
            log_success "LiteLLM proxy is reachable and healthy."
            return 0
            ;;
        401|403)
            log_warn "LiteLLM proxy responded with ${WARN}${http_code}${NC} (auth required). This may be normal."
            return 0
            ;;
        000*)
            log_warn "Could not connect to ${INFO}${url}${NC}. The server may be down or unreachable."
            log_info "The environment variables will still be set. You can verify later."
            return 0
            ;;
        *)
            log_warn "LiteLLM proxy responded with HTTP ${WARN}${http_code}${NC}."
            log_info "The environment variables will still be set."
            return 0
            ;;
    esac
}

# ── Parse Arguments ──────────────────────────────────────────────────────────
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --base-url)
                ANTHROPIC_BASE_URL_VALUE="$2"
                shift 2
                ;;
            --base-url=*)
                ANTHROPIC_BASE_URL_VALUE="${1#*=}"
                shift
                ;;
            --auth-token)
                ANTHROPIC_AUTH_TOKEN_VALUE="$2"
                shift 2
                ;;
            --auth-token=*)
                ANTHROPIC_AUTH_TOKEN_VALUE="${1#*=}"
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --uninstall|--remove)
                UNINSTALL=1
                shift
                ;;
            --quiet|-q)
                QUIET=1
                shift
                ;;
            --force|-f)
                FORCE=1
                shift
                ;;
            --help|-h)
                print_banner
                print_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: ${INFO}$1${NC}"
                echo ""
                print_usage
                exit 1
                ;;
        esac
    done
}

# ── Print Summary ────────────────────────────────────────────────────────────
print_summary() {
    local profile="$1"
    local base_url="$2"
    local token="$3"
    local masked_token=""

    # Mask the token for display: show first 7 chars + last 4 chars
    if [[ ${#token} -gt 11 ]]; then
        masked_token="${token:0:7}...${token: -4}"
    else
        masked_token="${token:0:3}***"
    fi

    echo ""
    echo -e "${ACCENT}${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${ACCENT}${BOLD}║              Setup Complete!                         ║${NC}"
    echo -e "${ACCENT}${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}ANTHROPIC_BASE_URL${NC}   = ${INFO}${base_url}${NC}"
    echo -e "  ${BOLD}ANTHROPIC_AUTH_TOKEN${NC}  = ${MUTED}${masked_token}${NC}"
    echo -e "  ${BOLD}Shell Profile${NC}        = ${INFO}${profile}${NC}"
    echo ""
    echo -e "  ${WARN}To activate now, run:${NC}"
    echo ""
    echo -e "    ${INFO}source ${profile}${NC}"
    echo ""
    echo -e "  ${MUTED}Or simply open a new terminal window.${NC}"
    echo ""
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    print_banner

    # ── System Info ──
    local os=""
    os="$(detect_os)"
    local distro=""
    if [[ "$os" == "Linux" ]]; then
        distro="$(detect_distro)"
        log_info "Detected OS: ${INFO}${os}${NC} (${MUTED}${distro}${NC})"
    else
        log_info "Detected OS: ${INFO}${os}${NC}"
    fi

    local current_shell=""
    current_shell="$(basename "${SHELL:-/bin/bash}")"
    log_info "Detected Shell: ${INFO}${current_shell}${NC}"

    # ── Handle Windows in Git Bash / WSL ──
    if [[ "$os" == "Windows" ]]; then
        log_warn "Detected Windows environment (Git Bash / MSYS / Cygwin)."
        log_info "For native Windows, use the PowerShell script instead:"
        echo -e "  ${INFO}irm https://raw.githubusercontent.com/siaslfs/ai-xxx/main/litellm-setup/install.ps1 | iex${NC}"
        echo ""
        if ! prompt_confirm "Continue with shell-based setup anyway?"; then
            exit 0
        fi
    fi

    # ── Uninstall ──
    if [[ "$UNINSTALL" == "1" ]]; then
        do_uninstall
        exit 0
    fi

    # ── Detect Shell Profile ──
    SHELL_PROFILE="$(detect_shell_profile)"
    log_info "Shell profile: ${INFO}${SHELL_PROFILE}${NC}"
    echo ""

    # ── Collect Base URL ──
    if [[ -z "$ANTHROPIC_BASE_URL_VALUE" ]]; then
        local existing_url="${ANTHROPIC_BASE_URL:-}"
        local default_url="${existing_url:-http://34.81.219.7:4000}"

        echo -e "${BOLD}Step 1/2: LiteLLM Proxy Address${NC}"
        echo -e "${MUTED}  The HTTP address of your LiteLLM proxy server.${NC}"
        echo -e "${MUTED}  Example: http://34.81.219.7:4000${NC}"
        echo ""

        if is_promptable; then
            ANTHROPIC_BASE_URL_VALUE="$(prompt_value "  Enter ANTHROPIC_BASE_URL" "$default_url")"
        else
            if [[ -n "$existing_url" ]]; then
                ANTHROPIC_BASE_URL_VALUE="$existing_url"
                log_info "Using existing ANTHROPIC_BASE_URL: ${INFO}${existing_url}${NC}"
            else
                log_error "No TTY available and --base-url not provided."
                log_info "Run with: ${INFO}--base-url http://your-server:4000 --auth-token sk-xxx${NC}"
                exit 1
            fi
        fi
    fi

    # Validate
    local validated_url=""
    validated_url="$(validate_base_url "$ANTHROPIC_BASE_URL_VALUE")" || exit 1
    ANTHROPIC_BASE_URL_VALUE="$validated_url"
    echo ""

    # ── Collect Auth Token ──
    if [[ -z "$ANTHROPIC_AUTH_TOKEN_VALUE" ]]; then
        local existing_token="${ANTHROPIC_AUTH_TOKEN:-}"
        local default_token="${existing_token:-}"

        echo -e "${BOLD}Step 2/2: LiteLLM Virtual Key${NC}"
        echo -e "${MUTED}  Your LiteLLM API key, usually starts with sk-${NC}"
        echo ""

        if is_promptable; then
            ANTHROPIC_AUTH_TOKEN_VALUE="$(prompt_value "  Enter ANTHROPIC_AUTH_TOKEN" "$default_token")"
        else
            if [[ -n "$existing_token" ]]; then
                ANTHROPIC_AUTH_TOKEN_VALUE="$existing_token"
                log_info "Using existing ANTHROPIC_AUTH_TOKEN."
            else
                log_error "No TTY available and --auth-token not provided."
                exit 1
            fi
        fi
    fi

    # Validate
    local validated_token=""
    validated_token="$(validate_auth_token "$ANTHROPIC_AUTH_TOKEN_VALUE")" || exit 1
    ANTHROPIC_AUTH_TOKEN_VALUE="$validated_token"
    echo ""

    # ── Check for Existing Values ──
    if [[ "$FORCE" != "1" ]]; then
        local has_existing=0
        if check_profile_has_var "$SHELL_PROFILE" "ANTHROPIC_BASE_URL"; then
            has_existing=1
            local old_url=""
            old_url="$(grep "^export ANTHROPIC_BASE_URL=" "$SHELL_PROFILE" 2>/dev/null | tail -1 | sed 's/^export ANTHROPIC_BASE_URL="//' | sed 's/"$//' || true)"
            if [[ -n "$old_url" ]]; then
                log_warn "ANTHROPIC_BASE_URL already set in profile: ${INFO}${old_url}${NC}"
            fi
        fi
        if check_profile_has_var "$SHELL_PROFILE" "ANTHROPIC_AUTH_TOKEN"; then
            has_existing=1
            log_warn "ANTHROPIC_AUTH_TOKEN already set in profile."
        fi

        if [[ "$has_existing" == "1" ]] && is_promptable; then
            echo ""
            if ! prompt_confirm "  Overwrite existing values?"; then
                log_info "Aborted. No changes made."
                exit 0
            fi
            echo ""
        fi
    fi

    # ── Dry Run ──
    if [[ "$DRY_RUN" == "1" ]]; then
        echo -e "${BOLD}Dry Run — No changes will be made:${NC}"
        echo ""
        echo -e "  Would write to: ${INFO}${SHELL_PROFILE}${NC}"
        echo -e "  $(get_shell_export_syntax "ANTHROPIC_BASE_URL" "$ANTHROPIC_BASE_URL_VALUE")"
        echo -e "  $(get_shell_export_syntax "ANTHROPIC_AUTH_TOKEN" "$ANTHROPIC_AUTH_TOKEN_VALUE")"
        echo ""
        log_success "Dry run complete."
        exit 0
    fi

    # ── Test Connectivity ──
    test_connection "$ANTHROPIC_BASE_URL_VALUE" "$ANTHROPIC_AUTH_TOKEN_VALUE"
    echo ""

    # ── Write to Profile ──
    log_step "Writing environment variables to ${INFO}${SHELL_PROFILE}${NC}..."
    echo ""

    write_env_to_profile "$SHELL_PROFILE" "ANTHROPIC_BASE_URL" "$ANTHROPIC_BASE_URL_VALUE"
    write_env_to_profile "$SHELL_PROFILE" "ANTHROPIC_AUTH_TOKEN" "$ANTHROPIC_AUTH_TOKEN_VALUE"

    # ── Also export for current session ──
    export ANTHROPIC_BASE_URL="$ANTHROPIC_BASE_URL_VALUE"
    export ANTHROPIC_AUTH_TOKEN="$ANTHROPIC_AUTH_TOKEN_VALUE"

    # ── Summary ──
    print_summary "$SHELL_PROFILE" "$ANTHROPIC_BASE_URL_VALUE" "$ANTHROPIC_AUTH_TOKEN_VALUE"
}

# ── Entry Point ──────────────────────────────────────────────────────────────
parse_args "$@"
main
