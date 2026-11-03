# Reads ikwilhuren.nu and posts the Central Park spots that are "Te huur" to sijpesteijn.pages.dev.
# Runs on GitHub Actions (.github/workflows/parkeerscan.yml) every 15 minutes, but only reads ikwilhuren.nu
# when a visitor pressed the scan button or the last scan is a day old. The key comes from the PARKING_KEY secret.
param([string]$Site = 'https://sijpesteijn.pages.dev', [switch]$Force)

$ErrorActionPreference = 'Stop'

if (-not $Force) {
  $current = $null
  try { $current = Invoke-RestMethod "$Site/api/parking-status" } catch { }  # 404: no scan stored yet
  $fresh = $current -and $current.scanned -and ((Get-Date).ToUniversalTime() - ([datetime]$current.scanned).ToUniversalTime()).TotalHours -lt 23.5
  if ($fresh -and -not $current.requested) { Write-Host "Stand van $($current.scanned) is actueel, geen verzoek."; exit 0 }
}

if (-not $env:PARKING_KEY) { throw 'secret PARKING_KEY ontbreekt' }
$page = (Invoke-WebRequest -UseBasicParsing 'https://ikwilhuren.nu/parkeerplaatsen/' -Headers @{ 'Accept-Language' = 'nl' }).Content

# every listing is a table row: name ("Parkeerplaats central park 4022"), city, type, status, price, link
$rows = 0
$available = New-Object System.Collections.Generic.SortedSet[string]
foreach ($row in [regex]::Matches($page, '(?is)<tr.*?</tr>')) {
  $cells = @([regex]::Matches($row.Value, '(?is)<td[^>]*>(.*?)</td>') | ForEach-Object {
    ($_.Groups[1].Value -replace '<[^>]*>', ' ' -replace '&nbsp;', ' ' -replace '\s+', ' ').Trim()
  })
  if ($cells.Count -lt 3) { continue }
  $spot = [regex]::Match($cells[0], '(?i)central park\s+(\d{4})\b')
  if (-not $spot.Success) { continue }
  $rows++
  if ($cells[2] -match '^(?i)te huur$') { [void]$available.Add($spot.Groups[1].Value) }
}
# no Central Park rows at all means the page changed or was unreachable, not that everything is rented
if ($rows -eq 0) { throw 'geen Central Park-plekken gevonden op ikwilhuren.nu' }

$body = @{ available = @($available) } | ConvertTo-Json -Compress
$res = Invoke-RestMethod -Method Post -Uri "$Site/api/parking-status" -Headers @{ 'X-Parking-Key' = $env:PARKING_KEY } `
  -ContentType 'application/json' -Body ([Text.Encoding]::UTF8.GetBytes($body))
Write-Host ("Gescand: {0} van {1} plekken te huur." -f $res.available.Count, $rows)
