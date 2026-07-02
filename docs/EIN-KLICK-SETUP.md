# PowerShell — alles in einem (kopieren & einfügen)

Führe in **PowerShell** aus (Rechtsklick → Terminal):

```powershell
$ziel = "$env:USERPROFILE\NovaBladers"
$zip = Get-ChildItem "$env:USERPROFILE\Downloads\nova-bladers*.zip","$env:USERPROFILE\Downloads\NovaBladers*.zip" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $zip) { Write-Host "ZIP nicht in Downloads gefunden. Pfad anpassen:" ; $zip = Read-Host "Voller Pfad zur ZIP" ; $zip = Get-Item $zip }
New-Item -ItemType Directory -Force -Path $ziel | Out-Null
Expand-Archive -Path $zip.FullName -DestinationPath "$ziel\_tmp" -Force
$inner = Get-ChildItem "$ziel\_tmp" -Directory | Where-Object { Test-Path "$($_.FullName)\import-nova-striker.bat" } | Select-Object -First 1
if ($inner) { Copy-Item "$($inner.FullName)\*" $ziel -Recurse -Force } else { Copy-Item "$ziel\_tmp\*" $ziel -Recurse -Force }
Remove-Item "$ziel\_tmp" -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path "$ziel\beyblade model" | Out-Null
Start-Process explorer $ziel
Write-Host "Fertig! Ordner: $ziel"
Write-Host "GLB ablegen in: $ziel\beyblade model\storm-pegasus.glb"
Write-Host "Dann Doppelklick: $ziel\import-nova-striker.bat"
```
