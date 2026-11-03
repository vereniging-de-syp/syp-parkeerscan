# SYP parkeerscan

Houdt de parkeerplattegrond op https://sijpesteijn.pages.dev/parkeren/ actueel.

- Elke dag om 12:00 en 19:00 leest `scan_parking.ps1` https://ikwilhuren.nu/parkeerplaatsen/ uit en stuurt de
  Central Park-plekken die te huur staan naar de site. De site houdt bij welke nummers sinds de vorige scan
  zijn veranderd.
- De knop "Scan beschikbare plekken" op de site start deze taak meteen, hooguit één keer per uur.
- Zelf meteen scannen: tabblad **Actions** → **Parkeerscan** → **Run workflow**.
- Secrets: `PARKING_KEY` (hier, in Settings → Secrets and variables → Actions). De site gebruikt een apart
  token, `GITHUB_SCAN_TOKEN` (in Cloudflare), dat alleen deze taak mag starten.
