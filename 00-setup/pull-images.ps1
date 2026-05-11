$ErrorActionPreference = 'Stop'

$images = @(
    'prom/prometheus:v2.55.0'
    'prom/alertmanager:v0.27.0'
    'grafana/grafana:11.3.0'
    'grafana/loki:3.3.0'
    'jaegertracing/all-in-one:1.62.0'
    'otel/opentelemetry-collector-contrib:0.114.0'
)

function Test-DockerReady {
    try {
        docker version --format '{{.Server.Version}}' 2>$null | Out-Null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

for ($attempt = 1; $attempt -le 20; $attempt++) {
    if (Test-DockerReady) {
        break
    }

    if ($attempt -eq 20) {
        Write-Host 'ERROR: Docker daemon is not reachable.' -ForegroundColor Red
        Write-Host '  Open Docker Desktop and wait until the engine reports that it is running.' -ForegroundColor Red
        Write-Host '  Then rerun: powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\lab.ps1 setup' -ForegroundColor Yellow
        exit 1
    }

    Start-Sleep -Seconds 3
}

if (-not (Test-DockerReady)) {
    Write-Host 'ERROR: Docker daemon is not reachable.' -ForegroundColor Red
    Write-Host '  Open Docker Desktop and wait until the engine reports that it is running.' -ForegroundColor Red
    Write-Host '  Then rerun: powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\lab.ps1 setup' -ForegroundColor Yellow
    exit 1
}

Write-Host "Pre-pulling $($images.Count) images (the FastAPI app builds locally)..."
foreach ($image in $images) {
    Write-Host "  pulling: $image"
    docker pull --quiet $image | Out-Null
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

Write-Host 'All images cached.'