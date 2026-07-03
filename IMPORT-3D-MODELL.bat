@echo off
chcp 65001 >nul
title Nova Bladers — 3D Modell importieren
color 0E
cd /d "%~dp0"

echo.
echo  ========================================
echo   3D Modell — Nova Striker importieren
echo  ========================================
echo.

:: GLB erzeugen falls noetig
if not exist "%~dp0assets\models\NovaStriker.glb" (
  if not exist "%~dp0tools\nova-striker-import\output\NovaStriker.glb" (
    echo  [1/4] Erzeuge NovaStriker.glb …
    if exist "%~dp0import-nova-striker.bat" (
      call "%~dp0import-nova-striker.bat"
    ) else (
      echo  import-nova-striker.bat fehlt — neueste ZIP von GitHub holen!
      pause
      exit /b 1
    )
  )
)

set "GLB="
if exist "%~dp0assets\models\NovaStriker.glb" set "GLB=%~dp0assets\models\NovaStriker.glb"
if not defined GLB if exist "%~dp0tools\nova-striker-import\output\NovaStriker.glb" set "GLB=%~dp0tools\nova-striker-import\output\NovaStriker.glb"

echo  [2/4] GLB bereit:
echo        %GLB%
echo.
echo  [3/4] ROBLOX STUDIO (Rojo Connected):
echo.
echo    1. File -^> Import 3D -^> NovaStriker.glb
echo    2. Play druecken (1x) — Modell wird automatisch eingefuegt!
echo    3. Place speichern (File -^> Save to File)
echo    4. Play -^> Nova Striker waehlen
echo.
echo  Manuell: setup-in-studio.lua in Command Bar (falls Play nicht reicht)
echo.
echo  [4/4] Sketchfab Original (optional, besser):
echo    GLB nach beyblade model\ legen, dann import-nova-striker.bat
echo    https://sketchfab.com/3d-models/storm-pegasus-105-rf-versao-exclusiva-2093ae37cc624534902d7b92fee88f4e
echo.

explorer /select,"%GLB%"
notepad "%~dp0tools\nova-striker-import\setup-in-studio.lua"
pause
