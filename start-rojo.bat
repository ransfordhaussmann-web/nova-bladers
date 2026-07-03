@echo off
title Nova Bladers — Rojo Sync
cd /d "%~dp0"

:: PATH neu laden
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USERPATH=%%b"
for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYSPATH=%%b"
set "PATH=%SYSPATH%;%USERPATH%"

where rojo >nul 2>&1
if errorlevel 1 (
  echo.
  echo  Rojo nicht gefunden — installiere automatisch …
  echo.
  where winget >nul 2>&1
  if not errorlevel 1 (
    winget install -e --id Rojo.Rojo --accept-package-agreements --accept-source-agreements
    for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USERPATH=%%b"
    for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYSPATH=%%b"
    set "PATH=%SYSPATH%;%USERPATH%"
  )
)

where rojo >nul 2>&1
if errorlevel 1 (
  echo.
  echo  Rojo ist noch nicht installiert.
  echo.
  echo  Terminal oeffnen und eingeben:
  echo    winget install -e --id Rojo.Rojo
  echo.
  echo  Dann PC neu starten und start-rojo.bat nochmal.
  echo  Nicht nur ZIP entpacken — rojo muss installiert sein!
  echo.
  pause
  exit /b 1
)

echo.
echo  Nova Bladers — Rojo laeuft auf Port 34872
echo  In Roblox Studio: Plugins ^> Rojo ^> Connect
echo  Druecke Ctrl+C zum Beenden.
echo.

rojo serve default.project.json
pause
