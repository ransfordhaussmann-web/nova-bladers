@echo off
chcp 65001 >nul
title Nova Striker — Auto Import
color 0B
cd /d "%~dp0"

set "TOOL=%~dp0tools\nova-striker-import"
set "OUTPUT=%TOOL%\output\NovaStriker.glb"
set "ASSETS=%~dp0assets\models\NovaStriker.glb"

echo.
echo  ========================================
echo   Nova Striker — Auto Import
echo  ========================================
echo.

echo  [1/3] GLB laden / vereinfachen…
cd /d "%TOOL%"
call npm install >nul 2>&1

if exist "%TOOL%\.env" (
  call npm run fetch
) else (
  call npm run download
)
call npm run simplify
if errorlevel 1 (
  echo  Fehler bei npm run all.
  pause
  exit /b 1
)

if exist "%OUTPUT%" (
  if not exist "%~dp0assets\models" mkdir "%~dp0assets\models"
  copy /Y "%OUTPUT%" "%ASSETS%" >nul
)

echo.
echo  [2/3] Fertig! Dateien:
echo        %OUTPUT%
if exist "%ASSETS%" echo        %ASSETS%
echo.
echo  [3/3] Roblox Studio (einmalig):
echo    1. start-rojo.bat
echo    2. File -^> Import 3D -^> NovaStriker.glb
echo    3. Command Bar: setup-in-studio.lua einfuegen
echo    4. Play -^> Nova Striker waehlen
echo.
echo  Ohne Studio-Import: verbessertes Pegasus-Modell laeuft direkt im Spiel.
echo.
explorer "%TOOL%\output"
goto :end

:end
pause
