@echo off
title Nova Bladers — Rojo Sync
cd /d "%~dp0"

where rojo >nul 2>&1
if errorlevel 1 (
  echo.
  echo  Rojo ist nicht installiert.
  echo  Bitte zuerst setup-pc.bat ausfuehren.
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
