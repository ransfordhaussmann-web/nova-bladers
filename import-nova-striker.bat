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

echo  [1/5] Suche GLB/GLTF im Projekt…

set "FOUND="
for /r "%~dp0" %%F in (*.glb *.gltf) do (
  if not defined FOUND (
    echo %%F | findstr /i "node_modules" >nul
    if errorlevel 1 (
      set "FOUND=%%F"
    )
  )
)

if defined FOUND (
  echo        Gefunden: %FOUND%
  copy /Y "%FOUND%" "%SOURCE%\storm-pegasus.glb" >nul
  echo        Kopiert nach source\storm-pegasus.glb
  goto :simplify
)

if exist "%~dp0beyblade model\*.glb" (
  for %%F in ("%~dp0beyblade model\*.glb") do set "FOUND=%%F" & goto :copyfound
)
if exist "%~dp0beyblade model\*.gltf" (
  for %%F in ("%~dp0beyblade model\*.gltf") do set "FOUND=%%F" & goto :copyfound
)
if exist "%~dp0beyblade-model\*.glb" (
  for %%F in ("%~dp0beyblade-model\*.glb") do set "FOUND=%%F" & goto :copyfound
)
if exist "%SOURCE%\*.glb" (
  for %%F in ("%SOURCE%\*.glb") do set "FOUND=%%F" & goto :simplify
)
if exist "%SOURCE%\*.gltf" (
  for %%F in ("%SOURCE%\*.gltf") do set "FOUND=%%F" & goto :simplify
)

echo.
echo  Keine GLB gefunden. Bitte Datei hierhin legen:
echo    %SOURCE%\storm-pegasus.glb
echo  ODER Ordner: %~dp0beyblade model\
echo.
echo  Sketchfab Download oeffnen? (J/N)
choice /C JN /N /M " "
if errorlevel 2 goto :end
start https://sketchfab.com/models/6bd1a9f1864a46dba4632307ce6c2660#download
echo  Nach dem Speichern Enter druecken…
pause >nul
goto :checkagain

:copyfound
echo        Gefunden: %FOUND%
copy /Y "%FOUND%" "%SOURCE%\storm-pegasus.glb" >nul
echo        Kopiert nach source\storm-pegasus.glb

:simplify
echo.
echo  [2/5] npm install…
cd /d "%TOOL%"
call npm install >nul 2>&1

echo  [3/5] Mesh vereinfachen fuer Roblox…
call npm run simplify
if errorlevel 1 (
  echo  Fehler bei simplify. Siehe Meldung oben.
  pause
  exit /b 1
)

echo.
echo  [4/5] Fertig! Datei:
echo        %OUTPUT%
echo.
echo  [5/5] Roblox Studio:
echo    1. start-rojo.bat
echo    2. File -^> Import 3D -^> NovaStriker.glb (aus output Ordner)
echo    3. Command Bar: setup-in-studio.lua einfuegen
echo    4. Play -^> Nova Striker
echo.
explorer "%TOOL%\output"
notepad "%TOOL%\setup-in-studio.lua"
goto :end

:checkagain
if exist "%SOURCE%\storm-pegasus.glb" goto :simplify
if exist "%SOURCE%\*.glb" goto :simplify
echo  Immer noch keine Datei in source\
pause
exit /b 1

:end
pause
