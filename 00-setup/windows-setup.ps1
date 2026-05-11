## Windows pre-flight check (PowerShell).
## Run via: powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File windows-setup.ps1
## Or:      powershell if you prefer the built-in Windows shell

$ErrorActionPreference = "Stop"

Write-Host "Checking Windows lab prerequisites..."

# Docker daemon reachable?
docker version --format '{{.Server.Version}}' | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Docker daemon not reachable." -ForegroundColor Red
    Write-Host "  Start Docker Desktop and wait until it reports that the engine is running." -ForegroundColor Red
    exit 1
}

# Compose v2?
docker compose version --short | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Compose v2 missing. Reinstall Docker Desktop (latest version)." -ForegroundColor Red
    exit 1
}

Write-Host "Windows setup OK." -ForegroundColor Green
Write-Host "TIP: run 'powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\lab.ps1 <command>' from PowerShell or Windows Terminal." -ForegroundColor Yellow
