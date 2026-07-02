@echo off
chcp 65001 >nul
title Nova Bladers — START HERE
color 0B

:: ============================================================
::  Nova Bladers — Ein-Klick-Start fuer deinen PC
::  Holt den neuesten Stand von GitHub und oeffnet alles.
:: ============================================================

set "DEFAULT_DIR=C:\Users\%USERNAME%\NovaBladers"
set "REPO_URL=https://github.com/ransfordhaussmann-web/nova-bladers.git"

echo.
echo  ========================================
echo   Nova Bladers — START HERE
echo  ========================================
echo.

:: --- Git vorhanden? ---
where git >nul 2>&1
if errorlevel 1 (
    echo  [1/4] Git fehlt — bitte zuerst installieren:
    echo        https://git-scm.com/download/win
    echo        Danach PC neu starten und diese Datei erneut oeffnen.
    echo.
    start https://git-scm.com/download/win
    pause
    exit /b 1
)

:: --- Sind wir schon im Repo? ---
if exist "%~dp0.git" (
    set "PROJECT_DIR=%~dp0"
    goto :pull
)

:: --- Repo woanders? ---
if exist "%DEFAULT_DIR%\.git" (
    set "PROJECT_DIR=%DEFAULT_DIR%\"
    cd /d "%PROJECT_DIR%"
    goto :pull
)

:: --- Noch kein Repo — klonen ---
echo  [1/4] Projekt wird zum ersten Mal heruntergeladen …
echo        Ziel: %DEFAULT_DIR%
echo.
if not exist "%DEFAULT_DIR%" mkdir "%DEFAULT_DIR%"
git clone %REPO_URL% "%DEFAULT_DIR%"
if errorlevel 1 (
    echo.
    echo  Fehler beim Klonen. Internetverbindung pruefen.
    pause
    exit /b 1
)
set "PROJECT_DIR=%DEFAULT_DIR%\"
cd /d "%PROJECT_DIR%"

:pull
cd /d "%PROJECT_DIR%"
echo  [2/4] Neueste Aenderungen von GitHub holen …
git fetch origin
git checkout main 2>nul
git pull origin main
if errorlevel 1 (
    echo  Warnung: pull fehlgeschlagen — du arbeitest evtl. mit altem Stand.
)
echo        OK — Projekt ist aktuell.
echo.

:: --- Setup pruefen ---
echo  [3/4] PC-Setup pruefen …
if exist "%PROJECT_DIR%scripts\setup-pc.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_DIR%scripts\setup-pc.ps1"
) else (
    echo        setup-pc.ps1 nicht gefunden — uebersprungen.
)
echo.

:: --- Alles oeffnen ---
echo  [4/4] Projekt oeffnen …
echo.
echo  ========================================
echo   FERTIG — So geht es weiter:
echo  ========================================
echo.
echo   1. Cursor oeffnen ^> File ^> Open Folder
echo      ^> %PROJECT_DIR%
echo.
echo   2. Roblox Studio oeffnen ^> Rojo Plugin ^> Connect
echo      ^> Vorher: start-rojo.bat starten
echo.
echo   3. Special-Move-Videos: preview\index.html
echo      ^> oeffnet sich gleich im Browser
echo.
echo   Projektordner:
echo   %PROJECT_DIR%
echo.

start "" "%PROJECT_DIR%preview\index.html"
explorer "%PROJECT_DIR%"

echo  Browser und Ordner wurden geoeffnet.
echo  Lies START-HERE.md fuer Details.
echo.
pause
