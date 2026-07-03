# Nova Bladers — installiert & prüft alles automatisch (Windows)
# Start: Doppelklick SETUP-ALLES.bat

$ErrorActionPreference = "Continue"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$StatusFile = Join-Path $RepoRoot "STATUS.txt"

function Test-Command($name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}
function Step-Ok($msg)   { Write-Host "  [OK]   $msg" -ForegroundColor Green; return $true }
function Step-Warn($msg) { Write-Host "  [!!]   $msg" -ForegroundColor Yellow; return $false }
function Step-Info($msg) { Write-Host "         $msg" -ForegroundColor DarkGray }

function Install-Winget($id, $label) {
    if (-not (Test-Command "winget")) {
        Step-Warn "winget fehlt — $label manuell installieren"
        return $false
    }
    Write-Host "         Installiere $label …" -ForegroundColor DarkGray
    winget install -e --id $id --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    Refresh-Path
    return $true
}

function Refresh-Path {
    $machine = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Nova Bladers — SETUP ALLES" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Ordner: $RepoRoot" -ForegroundColor DarkGray
Write-Host ""

$status = [ordered]@{
    Projektordner = $RepoRoot
    Git = "?"
    Node = "?"
    Rojo = "?"
    SpielCode = "?"
    RojoConfig = "?"
    Bereit = "NEIN"
}

# --- Git ---
Write-Host "1/4 Git" -ForegroundColor White
if (-not (Test-Command "git")) {
    Install-Winget "Git.Git" "Git"
}
if (Test-Command "git") {
    Step-Ok (git --version)
    $status.Git = "OK"
} else {
    Step-Warn "Git fehlt — https://git-scm.com/download/win"
    $status.Git = "FEHLT"
}

# --- Node ---
Write-Host ""
Write-Host "2/4 Node.js" -ForegroundColor White
if (-not (Test-Command "node")) {
    Install-Winget "OpenJS.NodeJS.LTS" "Node.js LTS"
}
if (Test-Command "node") {
    Step-Ok "Node $(node --version)"
    $status.Node = "OK"
} else {
    Step-Warn "Node fehlt — https://nodejs.org/"
    $status.Node = "FEHLT (optional)"
}

# --- Rojo ---
Write-Host ""
Write-Host "3/4 Rojo" -ForegroundColor White
if (-not (Test-Command "rojo")) {
    if (Test-Command "aftman") {
        Push-Location $RepoRoot
        aftman install 2>&1 | Out-Null
        Pop-Location
    }
    if (-not (Test-Command "rojo")) {
        Install-Winget "Rojo.Rojo" "Rojo"
    }
}
if (Test-Command "rojo") {
    Step-Ok ("Rojo " + (rojo --version 2>&1 | Select-Object -First 1))
    $status.Rojo = "OK"
} else {
    Step-Warn "Rojo fehlt — Terminal neu starten, dann SETUP-ALLES.bat nochmal"
    Step-Info "Oder: winget install -e --id Rojo.Rojo"
    $status.Rojo = "FEHLT"
}

# --- Projekt ---
Write-Host ""
Write-Host "4/4 Projekt-Dateien" -ForegroundColor White
$codeOk = Test-Path (Join-Path $RepoRoot "src\ReplicatedStorage\NovaBladers\BeyConfig.lua")
$rojoCfg = Test-Path (Join-Path $RepoRoot "default.project.json")
if ($codeOk) { Step-Ok "Spiel-Code (src/)"; $status.SpielCode = "OK" }
else { Step-Warn "Spiel-Code fehlt"; $status.SpielCode = "FEHLT" }
if ($rojoCfg) { Step-Ok "Rojo-Config"; $status.RojoConfig = "OK" }
else { Step-Warn "default.project.json fehlt"; $status.RojoConfig = "FEHLT" }

if ($status.Rojo -eq "OK" -and $status.SpielCode -eq "OK") {
    $status.Bereit = "JA — start-rojo.bat starten!"
}

# --- Status-Datei ---
$lines = @(
    "NOVA BLADERS — STATUS",
    "Erstellt: $(Get-Date -Format 'dd.MM.yyyy HH:mm')",
    "",
    "Projektordner: $($status.Projektordner)",
    "Git:           $($status.Git)",
    "Node.js:       $($status.Node)",
    "Rojo:          $($status.Rojo)",
    "Spiel-Code:    $($status.SpielCode)",
    "Rojo-Config:   $($status.RojoConfig)",
    "",
    "BEREIT ZUM SPIELEN: $($status.Bereit)",
    "",
    "Naechste Schritte:",
    "  1. SPIEL-START.bat  (alles in einem)",
    "  2. start-rojo.bat",
    "  2. Roblox Studio > Plugins > Rojo > Connect",
    "  3. Play druecken",
    "",
    "Optional (3D-Modell): import-nova-striker.bat",
    "Hilfe: docs/STATUS-DE.md"
)
$lines | Set-Content -Path $StatusFile -Encoding UTF8

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  STATUS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Git:        $($status.Git)" -ForegroundColor $(if ($status.Git -eq "OK") { "Green" } else { "Yellow" })
Write-Host "  Node.js:    $($status.Node)" -ForegroundColor $(if ($status.Node -like "OK*") { "Green" } else { "Yellow" })
Write-Host "  Rojo:       $($status.Rojo)" -ForegroundColor $(if ($status.Rojo -eq "OK") { "Green" } else { "Yellow" })
Write-Host "  Spiel-Code: $($status.SpielCode)" -ForegroundColor $(if ($status.SpielCode -eq "OK") { "Green" } else { "Yellow" })
Write-Host ""
if ($status.Bereit -like "JA*") {
    Write-Host "  >>> BEREIT! start-rojo.bat doppelklicken <<<" -ForegroundColor Green
} else {
    Write-Host "  >>> Noch nicht fertig — siehe [!!] oben <<<" -ForegroundColor Yellow
    if ($status.Rojo -eq "FEHLT") {
        Write-Host "  Terminal schliessen, neu oeffnen, SETUP-ALLES.bat nochmal." -ForegroundColor DarkGray
    }
}
Write-Host ""
Write-Host "  Status gespeichert: STATUS.txt" -ForegroundColor DarkGray
Write-Host ""
