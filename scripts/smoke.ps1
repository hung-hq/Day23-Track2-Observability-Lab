$ErrorActionPreference = 'Stop'

function Test-WebRequestOk {
    param([string]$Uri)

    try {
        return (Invoke-WebRequest -UseBasicParsing -Uri $Uri -TimeoutSec 5).StatusCode -eq 200
    } catch {
        return $false
    }
}

function Test-JsonEndpoint {
    param(
        [string]$Uri,
        [scriptblock]$Predicate
    )

    try {
        $payload = Invoke-RestMethod -Uri $Uri -TimeoutSec 5
        return & $Predicate $payload
    } catch {
        return $false
    }
}

Write-Host 'Checking services...'

$checks = @(
    @{ Label = 'app'; Check = { Test-WebRequestOk 'http://localhost:8000/healthz' } }
    @{ Label = 'prometheus'; Check = { Test-WebRequestOk 'http://localhost:9090/-/healthy' } }
    @{ Label = 'alertmanager'; Check = { Test-WebRequestOk 'http://localhost:9093/-/healthy' } }
    @{ Label = 'grafana'; Check = { Test-JsonEndpoint 'http://localhost:3000/api/health' { param($payload) $payload.database -eq 'ok' } } }
    @{ Label = 'loki'; Check = { Test-WebRequestOk 'http://localhost:3100/ready' } }
    @{ Label = 'jaeger'; Check = { Test-WebRequestOk 'http://localhost:16686/' } }
    @{ Label = 'otel-collector'; Check = { Test-WebRequestOk 'http://localhost:8888/metrics' } }
)

foreach ($check in $checks) {
    if (-not (& $check.Check)) {
        throw "$($check.Label) check failed"
    }

    Write-Host ("  {0,-14} OK" -f $check.Label)
}

Write-Host 'Stack healthy.'