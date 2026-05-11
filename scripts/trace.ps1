$ErrorActionPreference = 'Stop'

$body = @{ prompt = 'hello' } | ConvertTo-Json -Compress
$response = Invoke-RestMethod -Method Post -Uri 'http://localhost:8000/predict' -ContentType 'application/json' -Body $body
$traceId = if ($null -ne $response.trace_id -and $response.trace_id -ne '') { $response.trace_id } else { '?' }

Write-Host ("trace_id: {0}" -f $traceId)