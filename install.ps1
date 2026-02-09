#Requires -Version 5.1
<#
.SYNOPSIS
    LiteLLM Proxy Environment Setup Script for Windows.

.DESCRIPTION
    Configures ANTHROPIC_BASE_URL and ANTHROPIC_AUTH_TOKEN environment variables
    on Windows systems. Supports both User-level and System-level (admin) persistence.

.PARAMETER BaseUrl
    LiteLLM proxy address (e.g. http://34.81.219.7:4000)

.PARAMETER AuthToken
    LiteLLM virtual key (sk-...)

.PARAMETER Scope
    Environment variable scope: 'User' (default) or 'Machine' (requires admin)

.PARAMETER DryRun
    Show what would be done without making changes

.PARAMETER Uninstall
    Remove the environment variables

.PARAMETER Force
    Overwrite existing values without prompting

.PARAMETER Quiet
    Minimal output

.EXAMPLE
    # Interactive mode:
    irm https://raw.githubusercontent.com/siaslfs/ai-xxx/main/litellm-setup/install.ps1 | iex

.EXAMPLE
    # Non-interactive mode:
    .\install.ps1 -BaseUrl "http://34.81.219.7:4000" -AuthToken "sk-your-key"

.EXAMPLE
    # Uninstall:
    .\install.ps1 -Uninstall
#>

[CmdletBinding()]
param(
    [string]$BaseUrl = "",
    [string]$AuthToken = "",
    [ValidateSet("User", "Machine")]
    [string]$Scope = "User",
    [switch]$DryRun,
    [switch]$Uninstall,
    [switch]$Force,
    [switch]$Quiet,
    [switch]$Help
)

# ── Strict Mode ──────────────────────────────────────────────────────────────
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Colors & Formatting ─────────────────────────────────────────────────────
function Write-Color {
    param(
        [string]$Text,
        [string]$Color = "White",
        [switch]$NoNewline
    )
    $params = @{ Object = $Text; ForegroundColor = $Color }
    if ($NoNewline) { $params["NoNewline"] = $true }
    Write-Host @params
}

function Write-Info    { param([string]$Msg) if (-not $Quiet) { Write-Host "  i " -ForegroundColor Cyan -NoNewline; Write-Host $Msg } }
function Write-Success { param([string]$Msg) Write-Host "  ✓ " -ForegroundColor Green -NoNewline; Write-Host $Msg }
function Write-Warn    { param([string]$Msg) Write-Host "  ! " -ForegroundColor Yellow -NoNewline; Write-Host $Msg }
function Write-Err     { param([string]$Msg) Write-Host "  ✗ " -ForegroundColor Red -NoNewline; Write-Host $Msg }
function Write-Step    { param([string]$Msg) if (-not $Quiet) { Write-Host "  → " -ForegroundColor DarkCyan -NoNewline; Write-Host $Msg } }

# ── Banner ───────────────────────────────────────────────────────────────────
function Show-Banner {
    Write-Host ""
    Write-Host "    ╔══════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
    Write-Host "    ║                                                      ║" -ForegroundColor DarkCyan
    Write-Host "    ║     ██╗     ██╗████████╗███████╗██╗     ██╗     ███╗ ║" -ForegroundColor DarkCyan
    Write-Host "    ║     ██║     ██║╚══██╔══╝██╔════╝██║     ██║     ████╗║" -ForegroundColor DarkCyan
    Write-Host "    ║     ██║     ██║   ██║   █████╗  ██║     ██║     ██╔██║" -ForegroundColor DarkCyan
    Write-Host "    ║     ██║     ██║   ██║   ██╔══╝  ██║     ██║     ██║╚█║" -ForegroundColor DarkCyan
    Write-Host "    ║     ███████╗██║   ██║   ███████╗███████╗███████╗██║ █║" -ForegroundColor DarkCyan
    Write-Host "    ║     ╚══════╝╚═╝   ╚═╝   ╚══════╝╚══════╝╚══════╝╚═╝ ║" -ForegroundColor DarkCyan
    Write-Host "    ║                                                      ║" -ForegroundColor DarkCyan
    Write-Host "    ║          LiteLLM Proxy Environment Setup             ║" -ForegroundColor DarkCyan
    Write-Host "    ║                 (Windows Edition)                     ║" -ForegroundColor DarkCyan
    Write-Host "    ║                                                      ║" -ForegroundColor DarkCyan
    Write-Host "    ╚══════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "    Configure ANTHROPIC_BASE_URL & ANTHROPIC_AUTH_TOKEN" -ForegroundColor DarkGray
    Write-Host ""
}

# ── Help ─────────────────────────────────────────────────────────────────────
function Show-Help {
    Show-Banner
    Write-Host "USAGE:" -ForegroundColor White
    Write-Host "  irm https://raw.githubusercontent.com/siaslfs/ai-xxx/main/litellm-setup/install.ps1 | iex" -ForegroundColor Cyan
    Write-Host "  .\install.ps1 -BaseUrl 'http://...' -AuthToken 'sk-...'" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor White
    Write-Host "  -BaseUrl <url>       LiteLLM proxy address (e.g. http://34.81.219.7:4000)" -ForegroundColor Gray
    Write-Host "  -AuthToken <token>   LiteLLM virtual key (sk-...)" -ForegroundColor Gray
    Write-Host "  -Scope <scope>       'User' (default) or 'Machine' (requires admin)" -ForegroundColor Gray
    Write-Host "  -DryRun              Show what would be done without making changes" -ForegroundColor Gray
    Write-Host "  -Uninstall           Remove the environment variables" -ForegroundColor Gray
    Write-Host "  -Force               Overwrite existing values without prompting" -ForegroundColor Gray
    Write-Host "  -Quiet               Minimal output" -ForegroundColor Gray
    Write-Host "  -Help                Show this help message" -ForegroundColor Gray
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor White
    Write-Host "  # Interactive mode:" -ForegroundColor DarkGray
    Write-Host "  .\install.ps1" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  # Non-interactive:" -ForegroundColor DarkGray
    Write-Host '  .\install.ps1 -BaseUrl "http://34.81.219.7:4000" -AuthToken "sk-your-key"' -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  # System-wide (requires admin):" -ForegroundColor DarkGray
    Write-Host '  .\install.ps1 -Scope Machine -BaseUrl "http://..." -AuthToken "sk-..."' -ForegroundColor Cyan
    Write-Host ""
}

# ── Validation ───────────────────────────────────────────────────────────────
function Test-BaseUrl {
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) {
        Write-Err "Base URL cannot be empty."
        return $null
    }
    if ($Url -notmatch '^https?://') {
        Write-Err "Base URL must start with http:// or https://"
        Write-Info "Example: http://34.81.219.7:4000"
        return $null
    }
    return $Url.TrimEnd('/')
}

function Test-AuthToken {
    param([string]$Token)
    if ([string]::IsNullOrWhiteSpace($Token)) {
        Write-Err "Auth token cannot be empty."
        return $null
    }
    if ($Token -notmatch '^sk-') {
        Write-Warn "Token does not start with 'sk-'. Are you sure this is correct?"
        $reply = Read-Host "  Continue anyway? [Y/n]"
        if ($reply -match '^[Nn]') {
            return $null
        }
    }
    return $Token
}

# ── Admin Check ──────────────────────────────────────────────────────────────
function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ── Connectivity Test ────────────────────────────────────────────────────────
function Test-LiteLLMConnection {
    param([string]$Url)

    Write-Step "Testing connection to $Url ..."

    try {
        $response = Invoke-WebRequest -Uri "$Url/health" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Success "LiteLLM proxy is reachable and healthy."
        }
        else {
            Write-Warn "LiteLLM proxy responded with HTTP $($response.StatusCode)."
        }
    }
    catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }

        if ($statusCode -eq 401 -or $statusCode -eq 403) {
            Write-Warn "LiteLLM proxy responded with $statusCode (auth required). This may be normal."
        }
        else {
            Write-Warn "Could not connect to $Url. The server may be down or unreachable."
            Write-Info "The environment variables will still be set. You can verify later."
        }
    }
}

# ── Set Environment Variable ─────────────────────────────────────────────────
function Set-EnvVariable {
    param(
        [string]$Name,
        [string]$Value,
        [string]$EnvScope
    )

    # Set for current process
    [System.Environment]::SetEnvironmentVariable($Name, $Value, "Process")

    # Persist
    [System.Environment]::SetEnvironmentVariable($Name, $Value, $EnvScope)

    Write-Success "Set $Name ($EnvScope scope)"
}

# ── Remove Environment Variable ──────────────────────────────────────────────
function Remove-EnvVariable {
    param(
        [string]$Name,
        [string]$EnvScope
    )

    $existing = [System.Environment]::GetEnvironmentVariable($Name, $EnvScope)
    if ($null -ne $existing) {
        [System.Environment]::SetEnvironmentVariable($Name, $null, $EnvScope)
        [System.Environment]::SetEnvironmentVariable($Name, $null, "Process")
        Write-Success "Removed $Name from $EnvScope scope"
        return $true
    }
    else {
        Write-Info "$Name not found in $EnvScope scope"
        return $false
    }
}

# ── Uninstall ────────────────────────────────────────────────────────────────
function Invoke-Uninstall {
    Write-Host ""
    Write-Host "  Removing LiteLLM Proxy environment variables..." -ForegroundColor White
    Write-Host ""

    $removed = 0
    foreach ($varName in @("ANTHROPIC_BASE_URL", "ANTHROPIC_AUTH_TOKEN")) {
        # Try User scope
        if (Remove-EnvVariable -Name $varName -EnvScope "User") {
            $removed++
        }
        # Also try Machine scope if admin
        if (Test-IsAdmin) {
            if (Remove-EnvVariable -Name $varName -EnvScope "Machine") {
                $removed++
            }
        }
    }

    Write-Host ""
    if ($removed -gt 0) {
        Write-Success "Cleanup complete. Please restart your terminal for changes to take effect."
    }
    else {
        Write-Info "Nothing to remove."
    }
}

# ── Print Summary ────────────────────────────────────────────────────────────
function Show-Summary {
    param(
        [string]$EnvScope,
        [string]$Url,
        [string]$Token
    )

    # Mask token
    $maskedToken = if ($Token.Length -gt 11) {
        "$($Token.Substring(0, 7))...$($Token.Substring($Token.Length - 4))"
    }
    else {
        "$($Token.Substring(0, 3))***"
    }

    Write-Host ""
    Write-Host "    ╔══════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
    Write-Host "    ║              Setup Complete!                         ║" -ForegroundColor DarkCyan
    Write-Host "    ╚══════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "    ANTHROPIC_BASE_URL   = " -NoNewline; Write-Host $Url -ForegroundColor Cyan
    Write-Host "    ANTHROPIC_AUTH_TOKEN  = " -NoNewline; Write-Host $maskedToken -ForegroundColor DarkGray
    Write-Host "    Scope                = " -NoNewline; Write-Host $EnvScope -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    The variables are available immediately in this session." -ForegroundColor Yellow
    Write-Host "    For other terminals, please restart them to pick up the changes." -ForegroundColor DarkGray
    Write-Host ""

    # Also set in PowerShell profile for convenience
    $profilePath = $PROFILE.CurrentUserCurrentHost
    if (-not (Test-Path $profilePath)) {
        Write-Info "Tip: You can also add these to your PowerShell profile:"
        Write-Host '    $env:ANTHROPIC_BASE_URL = "' -NoNewline -ForegroundColor DarkGray
        Write-Host $Url -NoNewline -ForegroundColor Cyan
        Write-Host '"' -ForegroundColor DarkGray
        Write-Host '    $env:ANTHROPIC_AUTH_TOKEN = "' -NoNewline -ForegroundColor DarkGray
        Write-Host "sk-..." -NoNewline -ForegroundColor DarkGray
        Write-Host '"' -ForegroundColor DarkGray
        Write-Host ""
    }
}

# ── Main ─────────────────────────────────────────────────────────────────────
function Invoke-Main {
    # Help
    if ($Help) {
        Show-Help
        return
    }

    Show-Banner

    # System info
    $osVersion = [System.Environment]::OSVersion
    $psVersion = $PSVersionTable.PSVersion
    Write-Info "OS: Windows $($osVersion.Version) | PowerShell $psVersion"
    Write-Info "Scope: $Scope"

    # Admin check for Machine scope
    if ($Scope -eq "Machine" -and -not (Test-IsAdmin)) {
        Write-Err "Machine-level scope requires Administrator privileges."
        Write-Info "Please run PowerShell as Administrator, or use -Scope User."
        return
    }

    Write-Host ""

    # Uninstall
    if ($Uninstall) {
        Invoke-Uninstall
        return
    }

    # ── Collect Base URL ──
    if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
        $existingUrl = [System.Environment]::GetEnvironmentVariable("ANTHROPIC_BASE_URL", $Scope)
        $defaultUrl = if ($existingUrl) { $existingUrl } else { "http://34.81.219.7:4000" }

        Write-Host "  Step 1/2: LiteLLM Proxy Address" -ForegroundColor White
        Write-Host "    The HTTP address of your LiteLLM proxy server." -ForegroundColor DarkGray
        Write-Host "    Example: http://34.81.219.7:4000" -ForegroundColor DarkGray
        Write-Host ""

        $inputUrl = Read-Host "    Enter ANTHROPIC_BASE_URL [$defaultUrl]"
        if ([string]::IsNullOrWhiteSpace($inputUrl)) {
            $inputUrl = $defaultUrl
        }
        $BaseUrl = $inputUrl
    }

    # Validate
    $validatedUrl = Test-BaseUrl -Url $BaseUrl
    if ($null -eq $validatedUrl) { return }
    $BaseUrl = $validatedUrl
    Write-Host ""

    # ── Collect Auth Token ──
    if ([string]::IsNullOrWhiteSpace($AuthToken)) {
        $existingToken = [System.Environment]::GetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN", $Scope)
        $defaultToken = if ($existingToken) { $existingToken } else { "" }

        Write-Host "  Step 2/2: LiteLLM Virtual Key" -ForegroundColor White
        Write-Host "    Your LiteLLM API key, usually starts with sk-" -ForegroundColor DarkGray
        Write-Host ""

        if ($defaultToken) {
            $inputToken = Read-Host "    Enter ANTHROPIC_AUTH_TOKEN [$($defaultToken.Substring(0, [Math]::Min(7, $defaultToken.Length)))...]"
        }
        else {
            $inputToken = Read-Host "    Enter ANTHROPIC_AUTH_TOKEN"
        }
        if ([string]::IsNullOrWhiteSpace($inputToken) -and $defaultToken) {
            $inputToken = $defaultToken
        }
        $AuthToken = $inputToken
    }

    # Validate
    $validatedToken = Test-AuthToken -Token $AuthToken
    if ($null -eq $validatedToken) { return }
    $AuthToken = $validatedToken
    Write-Host ""

    # ── Check Existing ──
    if (-not $Force) {
        $existingBaseUrl = [System.Environment]::GetEnvironmentVariable("ANTHROPIC_BASE_URL", $Scope)
        $existingAuthToken = [System.Environment]::GetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN", $Scope)

        if ($existingBaseUrl -or $existingAuthToken) {
            if ($existingBaseUrl) {
                Write-Warn "ANTHROPIC_BASE_URL already set: $existingBaseUrl"
            }
            if ($existingAuthToken) {
                Write-Warn "ANTHROPIC_AUTH_TOKEN already set in $Scope scope."
            }
            $reply = Read-Host "    Overwrite existing values? [Y/n]"
            if ($reply -match '^[Nn]') {
                Write-Info "Aborted. No changes made."
                return
            }
            Write-Host ""
        }
    }

    # ── Dry Run ──
    if ($DryRun) {
        Write-Host "  Dry Run — No changes will be made:" -ForegroundColor White
        Write-Host ""
        Write-Host "    Would set ANTHROPIC_BASE_URL   = $BaseUrl" -ForegroundColor Cyan
        Write-Host "    Would set ANTHROPIC_AUTH_TOKEN  = $($AuthToken.Substring(0, [Math]::Min(7, $AuthToken.Length)))..." -ForegroundColor Cyan
        Write-Host "    Scope: $Scope" -ForegroundColor Cyan
        Write-Host ""
        Write-Success "Dry run complete."
        return
    }

    # ── Test Connectivity ──
    Test-LiteLLMConnection -Url $BaseUrl
    Write-Host ""

    # ── Set Variables ──
    Write-Step "Setting environment variables ($Scope scope)..."
    Write-Host ""

    Set-EnvVariable -Name "ANTHROPIC_BASE_URL" -Value $BaseUrl -EnvScope $Scope
    Set-EnvVariable -Name "ANTHROPIC_AUTH_TOKEN" -Value $AuthToken -EnvScope $Scope

    # Also update current process environment
    $env:ANTHROPIC_BASE_URL = $BaseUrl
    $env:ANTHROPIC_AUTH_TOKEN = $AuthToken

    # ── Also write to PowerShell profile (optional) ──
    $profilePath = $PROFILE.CurrentUserCurrentHost
    $writeProfile = $false

    if (Test-Path $profilePath) {
        $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if ($profileContent -notmatch 'ANTHROPIC_BASE_URL') {
            $writeProfile = $true
        }
    }
    else {
        $writeProfile = $true
    }

    if ($writeProfile) {
        Write-Step "Adding to PowerShell profile: $profilePath"

        $profileDir = Split-Path $profilePath -Parent
        if (-not (Test-Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }

        $profileLines = @(
            "",
            "# [LiteLLM Proxy] Added by install script on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
            "`$env:ANTHROPIC_BASE_URL = `"$BaseUrl`"",
            "`$env:ANTHROPIC_AUTH_TOKEN = `"$AuthToken`""
        )

        Add-Content -Path $profilePath -Value ($profileLines -join "`n") -Encoding UTF8
        Write-Success "Written to PowerShell profile."
    }

    # ── Also write to CMD environment via registry (for cmd.exe users) ──
    # This is already handled by [System.Environment]::SetEnvironmentVariable with User/Machine scope

    # ── Summary ──
    Show-Summary -EnvScope $Scope -Url $BaseUrl -Token $AuthToken
}

# ── Entry Point ──────────────────────────────────────────────────────────────
Invoke-Main
