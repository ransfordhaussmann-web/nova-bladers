@echo off
chcp 65001 >nul
title Nova Striker — Sketchfab Import
color 0B
cd /d "%~dp0"

set "TOOL=%~dp0tools\nova-striker-import"
set "SOURCE=%TOOL%\source"
set "OUTPUT=%TOOL%\output\NovaStriker.glb"

echo.
echo  ========================================
echo   Nova Striker — Import Storm Pegasus
echo  ========================================
echo.

if not exist "%SOURCE%" mkdir "%SOURCE%"

echo  [1/4] Sketchfab download page opening…
echo        Download as GLB and save to:
echo        %SOURCE%\storm-pegasus.glb
echo.
start https://sketchfab.com/models/6bd1a9f1864a46dba4632307ce6c2660#download
echo  Press Enter AFTER you saved the GLB file…
pause >nul

if not exist "%SOURCE%\*.glb" (
  if not exist "%SOURCE%\*.gltf" (
    echo.
    echo  ERROR: No .glb or .gltf found in source folder.
    echo  Save the download as: storm-pegasus.glb
    pause
    exit /b 1
  )
)

echo.
echo  [2/4] Installing simplify tool…
cd /d "%TOOL%"
call npm install >nul 2>&1

echo  [3/4] Simplifying mesh for Roblox (~763k -^> ~15k tris)…
call npm run simplify
if errorlevel 1 (
  echo  Simplify failed.
  pause
  exit /b 1
)

echo.
echo  [4/4] Roblox Studio steps:
echo.
echo    1. Open Roblox Studio + your Nova Bladers place
echo    2. start-rojo.bat (if not running)
echo    3. File -^> Import 3D -^> select:
echo       %OUTPUT%
echo    4. View -^> Command Bar
echo    5. Open tools\nova-striker-import\setup-in-studio.lua
echo       Copy ALL text -^> paste in Command Bar -^> Enter
echo    6. Play -^> pick Nova Striker
echo.
explorer "%TOOL%\output"
notepad "%TOOL%\setup-in-studio.lua"

echo  Done! Output folder and setup script opened.
pause
