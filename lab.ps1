param(
    [Parameter(Position = 0)]
    [ValidateSet('help', 'setup', 'up', 'down', 'restart', 'logs', 'smoke', 'load', 'alert', 'trace', 'drift', 'demo', 'verify', 'clean', 'lint-dashboards')]
    [string]$Command = 'help'
)

$ErrorActionPreference = 'Stop'
$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:Compose = @('docker', 'compose')

function Invoke-CommandLine {
    param([string[]]$Arguments)

    & $Arguments[0] @($Arguments[1..($Arguments.Count - 1)])
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

function Ensure-EnvFile {
    if (-not (Test-Path (Join-Path $script:Root '.env'))) {
        Copy-Item (Join-Path $script:Root '.env.example') (Join-Path $script:Root '.env')
    }
}

function Show-Help {
    Write-Host 'Day 23 Track 2 - Observability Lab'
    Write-Host ''
    Write-Host 'Usage:'
    Write-Host '  powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\lab.ps1 <command>'
    Write-Host ''
    Write-Host 'Commands:'
    Write-Host '  help             Show this help'
    Write-Host '  setup            One-time install + .env scaffold'
    Write-Host '  up               Start the stack'
    Write-Host '  down             Stop the stack'
    Write-Host '  restart          Stop + start'
    Write-Host '  logs             Tail logs from all services'
    Write-Host '  smoke            Health-check all 7 services'
    Write-Host '  load             Run baseline locust load'
    Write-Host '  alert            Trigger an alert by killing the app'
    Write-Host '  trace            Generate one traced request and print its trace_id'
    Write-Host '  drift            Run drift detection script'
    Write-Host '  demo             End-to-end demo (load -> alert -> trace -> drift)'
    Write-Host '  verify           Rubric gate'
    Write-Host '  clean            Stop stack + remove volumes'
    Write-Host '  lint-dashboards  Validate Grafana dashboard JSONs'
}

function Invoke-Setup {
    Ensure-EnvFile
    & (Join-Path $script:Root '00-setup/pull-images.ps1')
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    python (Join-Path $script:Root '00-setup/verify-docker.py')
}

function Invoke-Up {
    Invoke-CommandLine (@($script:Compose) + @('up', '-d'))
    Write-Host "Stack starting. Run 'powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\lab.ps1 smoke' to verify (allow ~30s for first start)."
}

function Invoke-Down {
    Invoke-CommandLine (@($script:Compose) + @('down'))
}

function Invoke-Logs {
    & $script:Compose logs -f --tail=50
}

function Invoke-Smoke {
    & (Join-Path $script:Root 'scripts/smoke.ps1')
}

function Invoke-Load {
    & (Join-Path $script:Root '02-prometheus-grafana/load-test/run-load.ps1')
}

function Invoke-Alert {
    & (Join-Path $script:Root 'scripts/trigger-alert.ps1')
}

function Invoke-Trace {
    & (Join-Path $script:Root 'scripts/trace.ps1')
}

function Invoke-Drift {
    python (Join-Path $script:Root '04-drift-detection/scripts/drift_detect.py')
}

function Invoke-Demo {
    Invoke-Load
    Invoke-Alert
    Invoke-Trace
    Invoke-Drift
}

function Invoke-Verify {
    python (Join-Path $script:Root 'scripts/verify.py')
}

function Invoke-LintDashboards {
    python (Join-Path $script:Root 'scripts/lint-dashboards.py') (Join-Path $script:Root '02-prometheus-grafana/grafana/dashboards/*.json')
}

function Invoke-Clean {
    Invoke-CommandLine (@($script:Compose) + @('down', '-v'))
}

switch ($Command) {
    'help' { Show-Help }
    'setup' { Invoke-Setup }
    'up' { Invoke-Up }
    'down' { Invoke-Down }
    'restart' { Invoke-Down; Invoke-Up }
    'logs' { Invoke-Logs }
    'smoke' { Invoke-Smoke }
    'load' { Invoke-Load }
    'alert' { Invoke-Alert }
    'trace' { Invoke-Trace }
    'drift' { Invoke-Drift }
    'demo' { Invoke-Demo }
    'verify' { Invoke-Verify }
    'clean' { Invoke-Clean }
    'lint-dashboards' { Invoke-LintDashboards }
}