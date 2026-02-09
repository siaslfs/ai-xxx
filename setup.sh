#!/bin/bash
# ============================================================================
# LiteLLM Proxy — Universal Installer Entry Point
#
# This script auto-detects the operating system and dispatches to the
# appropriate platform-specific installer.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/setup.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/siaslfs/ai-xxx/main/setup.sh | bash -s -- --base-url http://... --auth-token sk-...
# ============================================================================

set -euo pipefail

REMOTE_BASE="https://raw.githubusercontent.com/siaslfs/ai-xxx/main"

detect_platform() {
    local os=""
    os="$(uname -s 2>/dev/null || echo "Unknown")"
    case "$os" in
        Darwin|Linux)
            echo "unix"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "windows-shell"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

main() {
    local platform=""
    platform="$(detect_platform)"

    case "$platform" in
        unix)
            # Download and run the shell installer
            if command -v curl &>/dev/null; then
                curl -fsSL "${REMOTE_BASE}/install.sh" | bash -s -- "$@"
            elif command -v wget &>/dev/null; then
                wget -qO- "${REMOTE_BASE}/install.sh" | bash -s -- "$@"
            else
                echo "Error: curl or wget is required." >&2
                exit 1
            fi
            ;;
        windows-shell)
            echo ""
            echo "  Detected Windows environment (Git Bash / MSYS / Cygwin)."
            echo ""
            echo "  You can run the shell version here, or use PowerShell for native Windows support:"
            echo "    powershell -ExecutionPolicy Bypass -Command \"irm ${REMOTE_BASE}/install.ps1 | iex\""
            echo ""
            echo "  Proceeding with shell-based setup..."
            echo ""
            if command -v curl &>/dev/null; then
                curl -fsSL "${REMOTE_BASE}/install.sh" | bash -s -- "$@"
            elif command -v wget &>/dev/null; then
                wget -qO- "${REMOTE_BASE}/install.sh" | bash -s -- "$@"
            else
                echo "Error: curl or wget is required." >&2
                exit 1
            fi
            ;;
        *)
            echo "Error: Unsupported platform: $(uname -s 2>/dev/null || echo 'Unknown')" >&2
            echo "Supported: macOS, Linux, Windows (Git Bash/WSL/PowerShell)" >&2
            exit 1
            ;;
    esac
}

main "$@"
