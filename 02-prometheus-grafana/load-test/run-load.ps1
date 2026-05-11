$ErrorActionPreference = 'Stop'

Push-Location $PSScriptRoot
try {
    $locustCmd = Get-Command locust -ErrorAction SilentlyContinue
    if ($locustCmd) {
        & locust -f locustfile.py --headless -u 10 -r 2 -t 60s --host http://localhost:8000
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } else {
        Write-Host '`locust` not found on PATH — falling back to `python -m locust`'
        python -m locust -f locustfile.py --headless -u 10 -r 2 -t 60s --host http://localhost:8000
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
} finally {
    Pop-Location
}