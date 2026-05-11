$ErrorActionPreference = 'Stop'

function Get-ActiveAlertCount {
    try {
        $alerts = Invoke-RestMethod -Uri 'http://localhost:9093/api/v2/alerts' -TimeoutSec 5
        return @($alerts | Where-Object { $_.state -eq 'active' }).Count
    } catch {
        return 0
    }
}

Write-Host 'Step 1: kill app container'
docker stop day23-app | Out-Null
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host 'Step 2: wait 90s for ServiceDown alert to fire'
for ($i = 1; $i -le 18; $i++) {
    Start-Sleep -Seconds 5
    $alerts = Get-ActiveAlertCount
    if ($alerts -gt 0) {
        Write-Host "  alert fired (after $($i * 5)s)"
        break
    }

    Write-Host "  no alert yet ($($i * 5)s)"
}

Write-Host 'Step 3: restart app'
docker start day23-app | Out-Null
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host 'Step 4: wait 60s for alert to resolve'
for ($i = 1; $i -le 12; $i++) {
    Start-Sleep -Seconds 5
    $alerts = Get-ActiveAlertCount
    if ($alerts -eq 0) {
        Write-Host '  alert resolved'
        exit 0
    }
}

Write-Error 'alert did not resolve within 60s'
exit 1