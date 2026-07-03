# Nova Bladers — PC Setup (Windows)
# Fuehrt Pruefungen aus und gibt klare naechste Schritte.
# Starten: Doppelklick auf setup-pc.bat  ODER  .\scripts\setup-pc.ps1

$ErrorActionPreference = "Continue"
$RepoRoot = Split-Path $PSScriptRoot -Parent

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Nova Bladers — PC Setup (Windows)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Projektordner: $RepoRoot" -ForegroundColor DarkGray
Write-Host ""

function Test-Command($name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

function Step-Ok($msg)   { Write-Host "  [OK]   $msg" -ForegroundColor Green }
function Step-Warn($msg) { Write-Host "  [FEHL] $msg" -ForegroundColor Yellow }
function Step-Info($msg) { Write-Host "         $msg" -ForegroundColor DarkGray }

# --- 1. Git ---
Write-Host "1. Git" -ForegroundColor White
if (Test-Command "git") {
    $gitVer = git --version
    Step-Ok $gitVer
} else {
    Step-Warn "Git nicht gefunden"
    Step-Info "Installieren: https://git-scm.com/download/win"
    Step-Info "Danach PC neu starten und dieses Skript erneut ausfuehren."
}

# --- 2. Node.js (fuer Mobile + Preview) ---
Write-Host ""
Write-Host "2. Node.js (Video-Vorschau, optional)" -ForegroundColor White
if (Test-Command "node") {
    Step-Ok "Node $(node --version)"
} else {
    Step-Warn "Node.js nicht gefunden"
    Step-Info "Installieren: https://nodejs.org/ (LTS Version)"
}

# --- 3. Aftman + Rojo ---
Write-Host ""
Write-Host "3. Rojo (Cursor ↔ Roblox Studio Sync)" -ForegroundColor White
$rojoOk = Test-Command "rojo"
$aftmanOk = Test-Command "aftman"

if ($rojoOk) {
    Step-Ok "Rojo $(rojo --version 2>&1 | Select-Object -First 1)"
} elseif ($aftmanOk) {
    Step-Info "Aftman gefunden — installiere Rojo aus aftman.toml …"
    Push-Location $RepoRoot
    aftman install
    Pop-Location
    if (Test-Command "rojo") {
        Step-Ok "Rojo installiert"
        $rojoOk = $true
    } else {
        Step-Warn "Rojo nach aftman install noch nicht im PATH"
        Step-Info "Terminal schliessen, neu oeffnen, Skript erneut starten."
    }
} else {
    Step-Warn "Weder Rojo noch Aftman gefunden"
    Step-Info "Option A (empfohlen): Aftman installieren"
    Step-Info "  1. https://github.com/LPGhatGuy/aftman/releases"
    Step-Info "  2. aftman-x86_64-pc-windows-msvc.zip entpacken"
    Step-Info "  3. aftman.exe nach C:\Users\$env:USERNAME\.aftman\bin\"
    Step-Info "  4. Diesen Ordner zu PATH hinzufuegen (Windows-Suche: Umgebungsvariablen)"
    Step-Info "  5. setup-pc.bat erneut ausfuehren"
    Step-Info ""
    Step-Info "Option B: Rojo direkt von https://github.com/rojo-rbx/rojo/releases"
}

# --- 4. Repo Status ---
Write-Host ""
Write-Host "4. Git Repository" -ForegroundColor White
if (Test-Command "git") {
    Push-Location $RepoRoot
    if (Test-Path ".git") {
        Step-Ok "Git-Repo vorhanden"
        $branch = git branch --show-current 2>$null
        if ($branch) { Step-Info "Branch: $branch" }
        $remote = git remote get-url origin 2>$null
        if ($remote) {
            Step-Info "Remote: $remote"
            Write-Host ""
            Write-Host "  Neueste Aenderungen holen …" -ForegroundColor DarkGray
            git fetch origin 2>&1 | Out-Null
            git pull origin $branch 2>&1
        } else {
            Step-Warn "Kein GitHub-Remote konfiguriert"
            Step-Info 'git remote add origin https://github.com/ransfordhaussmann-web/nova-bladers.git'
            Step-Info "git pull origin main"
        }
    } else {
        Step-Warn "Kein Git-Repo in diesem Ordner"
        Step-Info "In Cursor: Clone repo → https://github.com/ransfordhaussmann-web/nova-bladers"
    }
    Pop-Location
}

# --- 5. Projekt-Dateien ---
Write-Host ""
Write-Host "5. Projekt-Dateien" -ForegroundColor White
$checks = @(
    @("Spiel-Code",        "src\ReplicatedStorage\NovaBladers\BeyConfig.lua"),
    @("Rojo-Config",       "default.project.json"),
    @("Video-Vorschau",    "preview\index.html")
)
foreach ($c in $checks) {
    $path = Join-Path $RepoRoot $c[1]
    if (Test-Path $path) { Step-Ok $c[0] } else { Step-Warn "$($c[0]) fehlt ($($c[1]))" }
}

# --- Zusammenfassung ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Naechste Schritte auf deinem PC" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  A) Cursor oeffnen" -ForegroundColor White
Write-Host "     File → Open Folder → $RepoRoot"
Write-Host ""
Write-Host "  B) Roblox Studio oeffnen" -ForegroundColor White
Write-Host "     → Nova-Bladers-Place oeffnen"
Write-Host "     → Plugin installieren: Roblox Creator Store → 'Rojo' suchen"
Write-Host ""
if ($rojoOk) {
    Write-Host "  C) Sync starten" -ForegroundColor White
    Write-Host "     Doppelklick: start-rojo.bat"
    Write-Host "     In Studio: Plugins → Rojo → Connect"
    Write-Host ""
    Write-Host "  D) Testen" -ForegroundColor White
    Write-Host "     Play druecken → E = Special Move"
} else {
    Write-Host "  C) Rojo installieren (siehe Schritt 3 oben)" -ForegroundColor Yellow
    Write-Host "     Dann: start-rojo.bat ausfuehren"
}
Write-Host ""
Write-Host "  E) Special-Move-Videos ansehen" -ForegroundColor White
Write-Host "     Doppelklick: preview\index.html"
Write-Host ""
Write-Host "  Ausfuehrliche Anleitung: docs\SETUP-WINDOWS.md" -ForegroundColor DarkGray
Write-Host ""
