# ============================================================================
# LiteLLM Proxy - Environment Configuration Script (Windows PowerShell)
# ============================================================================
# Usage:
#   Install (interactive):
#     irm https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.ps1 | iex
#
#   Uninstall:
#     irm https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.ps1 -OutFile install.ps1; .\install.ps1 -Uninstall
#
#   Help:
#     irm https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.ps1 -OutFile install.ps1; .\install.ps1 -Help
#
# Supported OS:  Windows 10/11, Windows Server 2016+
# Supported Shell: PowerShell 5.1+, PowerShell Core 7+
# ============================================================================

param(
    [switch]$Uninstall,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# ─── Constants ───────────────────────────────────────────────────────────────
$DEFAULT_BASE_URL = "https://pool.autelrobotics.com"

# ─── Color & Style Definitions ──────────────────────────────────────────────

function Write-Color {
    param(
        [string]$Text,
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White,
        [switch]$NoNewline,
        [switch]$Bold
    )
    $prev = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($NoNewline) {
        Write-Host $Text -NoNewline
    } else {
        Write-Host $Text
    }
    $Host.UI.RawUI.ForegroundColor = $prev
}

# ─── Utility Functions ──────────────────────────────────────────────────────

function Print-Banner {
    Write-Host ""
    Write-Color "  +==========================================================" -ForegroundColor Cyan
    Write-Color "  |                                                          " -ForegroundColor Cyan
    Write-Color "  |          LiteLLM Proxy  Environment Setup                " -ForegroundColor Cyan
    Write-Color "  |                          (Windows)                       " -ForegroundColor Cyan
    Write-Color "  |                                                          " -ForegroundColor Cyan
    Write-Color "  +==========================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Info    { param([string]$Msg) Write-Host "[INFO]    $Msg" -ForegroundColor Blue }
function Write-Success { param([string]$Msg) Write-Host "[OK]      $Msg" -ForegroundColor Green }
function Write-Warn    { param([string]$Msg) Write-Host "[WARN]    $Msg" -ForegroundColor Yellow }
function Write-Err     { param([string]$Msg) Write-Host "[ERROR]   $Msg" -ForegroundColor Red }

function Write-Step {
    param([string]$Number, [string]$Title)
    Write-Host ""
    Write-Color ">>> Step ${Number}: ${Title}" -ForegroundColor Cyan
}

# ─── Mask token for display ─────────────────────────────────────────────────

function Get-MaskedToken {
    param([string]$Token)
    if ($Token.Length -le 8) {
        return "********"
    }
    $prefix = $Token.Substring(0, 4)
    $suffix = $Token.Substring($Token.Length - 4)
    return "${prefix}****${suffix}"
}

# ─── Check if already installed ─────────────────────────────────────────────

function Test-Installed {
    $baseUrl = [Environment]::GetEnvironmentVariable("ANTHROPIC_BASE_URL", "User")
    $authToken = [Environment]::GetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN", "User")
    $disableBetas = [Environment]::GetEnvironmentVariable("CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS", "User")
    return (-not [string]::IsNullOrEmpty($baseUrl)) -or (-not [string]::IsNullOrEmpty($authToken)) -or (-not [string]::IsNullOrEmpty($disableBetas))
}

# ─── Get current config for display ─────────────────────────────────────────

function Get-CurrentConfig {
    return @{
        BaseUrl      = [Environment]::GetEnvironmentVariable("ANTHROPIC_BASE_URL", "User")
        AuthToken    = [Environment]::GetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN", "User")
        DisableBetas = [Environment]::GetEnvironmentVariable("CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS", "User")
    }
}

# ─── Write config (set User-level environment variables) ─────────────────────

function Write-Config {
    param(
        [string]$AuthToken
    )

    [Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", $DEFAULT_BASE_URL, "User")
    [Environment]::SetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN", $AuthToken, "User")
    [Environment]::SetEnvironmentVariable("CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS", "1", "User")

    $env:ANTHROPIC_BASE_URL = $DEFAULT_BASE_URL
    $env:ANTHROPIC_AUTH_TOKEN = $AuthToken
    $env:CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS = "1"
}

# ─── Remove config ──────────────────────────────────────────────────────────

function Remove-Config {
    [Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", $null, "User")
    [Environment]::SetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN", $null, "User")
    [Environment]::SetEnvironmentVariable("CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS", $null, "User")

    Remove-Item Env:\ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
    Remove-Item Env:\ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
    Remove-Item Env:\CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS -ErrorAction SilentlyContinue
}

# ─── Uninstall Flow ─────────────────────────────────────────────────────────

function Invoke-Uninstall {
    Print-Banner
    Write-Color "  Uninstall Mode" -ForegroundColor Red
    Write-Host "  ────────────────────────────────────────────"
    Write-Host ""

    Write-Info "Operating System: $([Environment]::OSVersion.VersionString)"
    Write-Info "PowerShell: $($PSVersionTable.PSVersion)"
    Write-Info "Storage: User-level environment variables (Registry)"
    Write-Host ""

    if (-not (Test-Installed)) {
        Write-Warn "No LiteLLM Proxy environment configuration found. Nothing to uninstall."
        Write-Host ""
        return
    }

    $config = Get-CurrentConfig
    Write-Color "  The following User-level environment variables will be removed:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  +──────────────────────────────────────────────────────────────+"
    if ($config.BaseUrl) {
        Write-Host "  |  ANTHROPIC_BASE_URL                  = $($config.BaseUrl)"
    }
    if ($config.AuthToken) {
        $masked = Get-MaskedToken -Token $config.AuthToken
        Write-Host "  |  ANTHROPIC_AUTH_TOKEN                 = $masked"
    }
    if ($config.DisableBetas) {
        Write-Host "  |  CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS = $($config.DisableBetas)"
    }
    Write-Host "  +──────────────────────────────────────────────────────────────+"
    Write-Host ""

    Write-Color "Confirm uninstall? This action cannot be undone." -ForegroundColor Yellow
    $confirm = Read-Host "Type 'yes' to confirm uninstall"

    if ($confirm -ne "yes") {
        Write-Warn "Uninstall cancelled. No changes were made."
        Write-Host ""
        return
    }

    Remove-Config

    Write-Host ""
    Write-Success "LiteLLM Proxy environment variables have been removed!"
    Write-Host ""
    Write-Info "Changes take effect in new terminal sessions immediately."
    Write-Info "Current session variables have also been cleared."
    Write-Host ""
    Write-Success "Uninstall complete!"
    Write-Host ""
}

# ─── Install Flow ───────────────────────────────────────────────────────────

function Invoke-Install {
    Print-Banner
    Write-Color "  Install Mode" -ForegroundColor Green
    Write-Host "  ────────────────────────────────────────────"
    Write-Host ""

    # ── Step 1: Environment Detection ──
    Write-Step "1/3" "Environment Detection"

    $osInfo = [Environment]::OSVersion
    $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    $psVersion = $PSVersionTable.PSVersion

    Write-Info "OS:          Windows $($osInfo.Version) ($arch)"
    Write-Info "PowerShell:  $psVersion"
    Write-Info "Storage:     User-level environment variables (Registry)"
    Write-Info "BASE_URL:    $DEFAULT_BASE_URL (built-in)"

    if (Test-Installed) {
        Write-Host ""
        $config = Get-CurrentConfig
        Write-Warn "Existing LiteLLM Proxy configuration detected. Continuing will overwrite it."
        if ($config.BaseUrl) {
            Write-Info "  Current ANTHROPIC_BASE_URL:  $($config.BaseUrl)"
        }
        if ($config.AuthToken) {
            Write-Info "  Current ANTHROPIC_AUTH_TOKEN: $(Get-MaskedToken -Token $config.AuthToken)"
        }
        $overwrite = Read-Host "Continue? [y/N]"
        if ($overwrite -notmatch "^[yY]") {
            Write-Warn "Install cancelled."
            Write-Host ""
            return
        }
    }

    # ── Step 2: Input AUTH_TOKEN ──
    Write-Step "2/3" "Configure ANTHROPIC_AUTH_TOKEN"

    Write-Host ""
    Write-Host "  LiteLLM Virtual Key (starts with sk-)" -ForegroundColor DarkGray
    Write-Host ""

    $secureToken = Read-Host "  Enter ANTHROPIC_AUTH_TOKEN" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    $inputAuthToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

    if ([string]::IsNullOrWhiteSpace($inputAuthToken)) {
        Write-Err "AUTH_TOKEN cannot be empty. Install aborted."
        Write-Host ""
        return
    }

    if ($inputAuthToken -notmatch "^sk-") {
        Write-Warn "The entered Token does not start with sk-. Please verify it is correct."
        $continueToken = Read-Host "  Continue with this Token? [y/N]"
        if ($continueToken -notmatch "^[yY]") {
            Write-Err "Install aborted."
            Write-Host ""
            return
        }
    }

    $maskedToken = Get-MaskedToken -Token $inputAuthToken
    Write-Success "ANTHROPIC_AUTH_TOKEN set"

    # ── Step 3: Confirm & Write ──
    Write-Step "3/3" "Confirm and write configuration"

    Write-Host ""
    Write-Host "  Please confirm the following configuration:" -ForegroundColor White
    Write-Host ""
    Write-Host "  +──────────────────────────────────────────────────────────────+"
    Write-Host "  |  ANTHROPIC_BASE_URL                  = $DEFAULT_BASE_URL"
    Write-Host "  |  ANTHROPIC_AUTH_TOKEN                 = $maskedToken"
    Write-Host "  |  CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS = 1"
    Write-Host "  |                                                              "
    Write-Host "  |  Target: User-level environment variables (Registry)         "
    Write-Host "  +──────────────────────────────────────────────────────────────+"
    Write-Host ""

    Write-Color "  Confirm write? [y/N]: " -ForegroundColor Yellow -NoNewline
    $finalConfirm = Read-Host

    if ($finalConfirm -notmatch "^[yY]") {
        Write-Warn "Install cancelled. No changes were made."
        Write-Host ""
        return
    }

    Write-Config -AuthToken $inputAuthToken

    Write-Host ""
    Write-Color "  +==========================================================" -ForegroundColor Green
    Write-Color "  |                                                          " -ForegroundColor Green
    Write-Color "  |        Install successful! Configuration complete.       " -ForegroundColor Green
    Write-Color "  |                                                          " -ForegroundColor Green
    Write-Color "  +==========================================================" -ForegroundColor Green
    Write-Host ""
    Write-Info "Environment variables are set for the current session."
    Write-Info "New terminal windows will also inherit these variables."
    Write-Host ""
    Write-Info "To uninstall:"
    Write-Host ""
    Write-Host "    irm https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.ps1 -OutFile install.ps1; .\install.ps1 -Uninstall" -ForegroundColor White
    Write-Host ""
    Write-Success "All done!"
    Write-Host ""
}

# ─── Help ────────────────────────────────────────────────────────────────────

function Show-Help {
    Print-Banner
    Write-Host "  Usage:" -ForegroundColor White
    Write-Host ""
    Write-Host "    Install (interactive):" -ForegroundColor White
    Write-Host "      irm https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.ps1 | iex"
    Write-Host ""
    Write-Host "    Uninstall:" -ForegroundColor White
    Write-Host "      irm https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.ps1 -OutFile install.ps1; .\install.ps1 -Uninstall"
    Write-Host ""
    Write-Host "    Help:" -ForegroundColor White
    Write-Host "      irm https://raw.githubusercontent.com/siaslfs/ai-xxx/main/LiteLLM/install.ps1 -OutFile install.ps1; .\install.ps1 -Help"
    Write-Host ""
    Write-Host "  What this script does:" -ForegroundColor White
    Write-Host ""
    Write-Host "    Sets the following User-level environment variables:"
    Write-Host "      - ANTHROPIC_BASE_URL                  : $DEFAULT_BASE_URL (built-in)"
    Write-Host "      - ANTHROPIC_AUTH_TOKEN                 : LiteLLM Virtual Key"
    Write-Host "      - CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS : 1"
    Write-Host ""
    Write-Host "    These are stored in the Windows Registry (HKCU\Environment)"
    Write-Host "    and persist across terminal sessions and reboots."
    Write-Host ""
}

# ─── Main Entry Point ───────────────────────────────────────────────────────

if ($Help) {
    Show-Help
} elseif ($Uninstall) {
    Invoke-Uninstall
} else {
    Invoke-Install
}
