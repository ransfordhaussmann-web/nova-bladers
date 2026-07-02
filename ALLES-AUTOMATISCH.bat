@echo off
chcp 65001 >nul
title Nova Bladers — Alles automatisch
color 0B

set "ZIEL=C:\Users\%USERNAME%\NovaBladers"
set "ZIP="

echo.
echo  ========================================
echo   Nova Bladers — Setup automatisch
echo  ========================================
echo.

:: Bereits entpacktes Projekt?
if exist "%~dp0import-nova-striker.bat" (
  set "ZIEL=%~dp0"
  set "ZIEL=%ZIEL:~0,-1%"
  goto :setup
)

:: ZIP suchen
for %%Z in (
  "%USERPROFILE%\Downloads\nova-bladers*.zip"
  "%USERPROFILE%\Downloads\NovaBladers*.zip"
  "%USERPROFILE%\Desktop\nova-bladers*.zip"
  "%USERPROFILE%\Desktop\NovaBladers*.zip"
  "%~dp0*.zip"
) do (
  if exist %%Z (
    set "ZIP=%%~fZ"
    goto :extract
  )
)

echo  Keine ZIP gefunden.
echo  Lege nova-bladers.zip in Downloads ab
echo  ODER entpacke ZIP und starte diese Datei im Ordner.
echo.
pause
exit /b 1

:extract
echo  [1/4] ZIP gefunden:
echo        %ZIP%
echo  [1/4] Entpacke nach %ZIEL% …

if exist "%ZIEL%" (
  echo        Ordner existiert — ueberschreibe nur Inhalt …
) else (
  mkdir "%ZIEL%"
)

powershell -NoProfile -Command "Expand-Archive -Path '%ZIP%' -DestinationPath '%ZIEL%\_tmp' -Force"
if errorlevel 1 (
  echo  Fehler beim Entpacken.
  pause
  exit /b 1
)

:: ZIP hat oft Unterordner nova-bladers-main
if exist "%ZIEL%\_tmp\nova-bladers-main\import-nova-striker.bat" (
  xcopy "%ZIEL%\_tmp\nova-bladers-main\*" "%ZIEL%\" /E /Y /Q >nul
) else if exist "%ZIEL%\_tmp\import-nova-striker.bat" (
  xcopy "%ZIEL%\_tmp\*" "%ZIEL%\" /E /Y /Q >nul
) else (
  xcopy "%ZIEL%\_tmp\*" "%ZIEL%\" /E /Y /Q >nul
)
rmdir /S /Q "%ZIEL%\_tmp" 2>nul
echo        OK
echo.

:setup
cd /d "%ZIEL%"
echo  Projektordner: %ZIEL%
echo.

if not exist "%ZIEL%\beyblade model" mkdir "%ZIEL%\beyblade model"

echo  [2/4] Suche GLB in beyblade model …
if exist "%ZIEL%\beyblade model\*.glb" (
  echo        GLB gefunden — Import startet …
) else (
  echo        Keine GLB — Sketchfab-Seite oeffnen …
  echo        Download 3D Model ^> GLB ^> speichern in:
  echo        %ZIEL%\beyblade model\storm-pegasus.glb
  start https://sketchfab.com/3d-models/storm-pegasus-105-rf-versao-exclusiva-2093ae37cc624534902d7b92fee88f4e
  echo.
  echo  Nach dem Speichern Enter druecken …
  pause >nul
)

echo  [3/4] Import-Skript …
if exist "%ZIEL%\import-nova-striker.bat" (
  call "%ZIEL%\import-nova-striker.bat"
) else (
  echo  import-nova-striker.bat fehlt — alte ZIP?
  echo  Hole neueste Version von GitHub …
  where git >nul 2>&1
  if not errorlevel 1 (
    git clone https://github.com/ransfordhaussmann-web/nova-bladers.git "%ZIEL%_neu"
    if exist "%ZIEL%_neu\import-nova-striker.bat" (
      xcopy "%ZIEL%_neu\*" "%ZIEL%\" /E /Y /Q >nul
      rmdir /S /Q "%ZIEL%_neu"
      call "%ZIEL%\import-nova-striker.bat"
    )
  )
)

echo.
echo  [4/4] Fertig!
echo  Ordner: %ZIEL%
echo.
echo  Cursor: File ^> Open Folder ^> obigen Pfad
echo.
explorer "%ZIEL%"
explorer "%ZIEL%\beyblade model"
pause
