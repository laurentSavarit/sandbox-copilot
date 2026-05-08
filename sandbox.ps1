# sandbox.ps1 — Windows equivalent of sandbox.sh
# Run the GitHub Copilot CLI sandbox with your current directory mounted as workspace.
#
# Requires: Docker Desktop for Windows with WSL2 backend
#
# Usage (from any directory):
#   .\sandbox.ps1                         → copilot --allow-all-tools (yolo mode)
#   .\sandbox.ps1 bash                    → debug shell
#
# Build the image first:
#   docker compose build      (from this repo's root)

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Command
)

$ErrorActionPreference = 'Stop'

$Image      = "sandbox-copilot:latest"
$ScriptDir  = $PSScriptRoot
$LogsDir    = Join-Path $ScriptDir "logs"
$AuthVolume = "copilot-auth"

# ── Ensure logs directory exists ──────────────────────────────────────────────
New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null

# ── Default command ───────────────────────────────────────────────────────────
if ($Command.Count -eq 0) {
    $Command = @("copilot", "--allow-all-tools")
}

# ── Volume args ───────────────────────────────────────────────────────────────
$VolArgs = @(
    "-v", "${AuthVolume}:/root/.copilot",
    "-v", "$(Get-Location):/workspace",
    "-v", "${LogsDir}:/sandbox-logs"
)

$AwsDir   = Join-Path $env:USERPROFILE ".aws"
$AzureDir = Join-Path $env:USERPROFILE ".azure"

if (Test-Path $AwsDir)   { $VolArgs += @("-v", "${AwsDir}:/root/.aws:ro") }
if (Test-Path $AzureDir) { $VolArgs += @("-v", "${AzureDir}:/root/.azure:ro") }

# ── Run ───────────────────────────────────────────────────────────────────────
$DockerArgs = @("run", "--rm", "-it") + $VolArgs + @("-w", "/workspace", $Image) + $Command

& docker @DockerArgs
exit $LASTEXITCODE
