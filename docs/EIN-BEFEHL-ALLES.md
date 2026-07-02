# Alles auf einmal — 1 Befehl für deinen Laptop

Kopiere **alles** in PowerShell (**Win + X → Terminal**) und drücke **Enter**:

```powershell
$ziel = "$env:USERPROFILE\NovaBladers"
if (-not (Test-Path "$ziel\SPIEL-START.bat")) {
  Write-Host "Lade Projekt von GitHub …"
  if (Get-Command git -ErrorAction SilentlyContinue) {
    git clone https://github.com/ransfordhaussmann-web/nova-bladers.git $ziel
  } else {
    winget install -e --id Git.Git --accept-package-agreements --accept-source-agreements
    git clone https://github.com/ransfordhaussmann-web/nova-bladers.git $ziel
  }
}
Set-Location $ziel
git pull origin main 2>$null
Write-Host "Starte Setup …"
& "$ziel\SPIEL-START.bat"
```

Danach nur noch in **Roblox Studio**: **Plugins → Rojo → Connect → Play**

---

## Oder manuell (wenn du schon den Ordner hast)

Doppelklick auf **`SPIEL-START.bat`** im Projektordner.

Ordner bei dir vermutlich:
`C:\Users\hp\Downloads\nova-bladers-main`

Dort fehlen evtl. neue Dateien — dann lieber GitHub-Version nach `C:\Users\hp\NovaBladers` klonen (Befehl oben).
