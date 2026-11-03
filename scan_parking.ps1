# Reads ikwilhuren.nu and posts the Central Park spots that are "Te huur" to sijpesteijn.pages.dev.
# Runs on GitHub Actions (.github/workflows/parkeerscan.yml): on schedule at 12:00 and 19:00 Dutch time, and with
# -Force whenever the scan button on the site starts the job. The key comes from the PARKING_KEY secret.
param([string]$Site = 'https://sijpesteijn.pages.dev', [switch]$Force)

$ErrorActionPreference = 'Stop'

# the schedule fires in UTC for both summer and winter time; only the run that lands on 12 or 19 o'clock scans
if (-not $Force) {
  $zone = try { [TimeZoneInfo]::FindSystemTimeZoneById('Europe/Amsterdam') } catch { [TimeZoneInfo]::FindSystemTimeZoneById('W. Europe Standard Time') }
  $local = [TimeZoneInfo]::ConvertTimeFromUtc([datetime]::UtcNow, $zone)
  if ($local.Hour -ne 12 -and $local.Hour -ne 19) { Write-Host "Het is $($local.ToString('HH:mm')) in Nederland, geen scan."; exit 0 }
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
