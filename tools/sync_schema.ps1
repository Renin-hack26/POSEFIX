# Applies supabase/schema_account_sync.sql via the Supabase Management API.
# Idempotent — safe to re-run. Reads secrets/local.env (never echoed).
param(
  [string]$SqlFile = "$PSScriptRoot\..\supabase\schema_account_sync.sql"
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path "$PSScriptRoot\.."
$envPath = Join-Path $repoRoot 'secrets\local.env'
if (-not (Test-Path $envPath)) { Write-Error 'secrets/local.env missing'; exit 1 }

# Parse KEY=VALUE lines (no output of values).
$vars = @{}
foreach ($line in [System.IO.File]::ReadAllLines($envPath)) {
  if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
    $vars[$Matches[1]] = $Matches[2].Trim().Trim('"').Trim("'")
  }
}
$token = $vars['SUPABASE_ACCESS_TOKEN']
$url = $vars['SUPABASE_URL']
if (-not $token -or -not $url) { Write-Error 'SUPABASE_ACCESS_TOKEN or SUPABASE_URL missing'; exit 1 }
$projectRef = ([Uri]$url).Host.Split('.')[0]

$sql = [System.IO.File]::ReadAllText((Resolve-Path $SqlFile))
$body = @{ query = $sql } | ConvertTo-Json -Compress

try {
  $resp = Invoke-RestMethod -Method Post `
    -Uri "https://api.supabase.com/v1/projects/$projectRef/database/query" `
    -Headers @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' } `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 60
  Write-Output "SCHEMA_EXIT=0 (applied to $projectRef)"
  exit 0
} catch {
  $status = $_.Exception.Response.StatusCode.value__
  $detail = $_.ErrorDetails.Message
  Write-Output "SCHEMA_HTTP=$status $detail"
  exit 1
}
