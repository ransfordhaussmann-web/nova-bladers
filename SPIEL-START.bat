@echo off
chcp 65001 >nul
title Nova Bladers — SPIEL STARTEN
color 0A
cd /d "%~dp0"

echo.
echo  ========================================
echo   Nova Bladers — Alles laden und starten
echo  ========================================
echo.

:: --- Schritt 1: Tools installieren ---
echo  [1/3] Installiere und pruefe Tools …
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup-alles.ps1"
echo.

:: PATH neu laden (nach winget-Installation)
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USERPATH=%%b"
for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYSPATH=%%b"
set "PATH=%SYSPATH%;%USERPATH%"

:: --- Schritt 2: Rojo pruefen ---
where rojo >nul 2>&1
if errorlevel 1 (
  echo  [!!] Rojo noch nicht gefunden.
  echo.
  echo  Bitte PC NEU STARTEN, dann SPIEL-START.bat nochmal.
  echo  Oder Terminal oeffnen und eingeben:
  echo    winget install -e --id Rojo.Rojo
  echo.
  notepad STATUS.txt 2>nul
  pause
  exit /b 1
)

:: --- Schritt 3: Rojo starten ---
echo  [2/3] Rojo Sync starten …
echo.
echo  [3/3] In Roblox Studio:
echo        Plugins ^> Rojo ^> Connect  ^>  Play
echo.
echo  Dieses Fenster OFFEN lassen!
echo  ========================================
echo.

start "Nova Bladers Rojo" cmd /k "cd /d "%~dp0" && title Rojo Sync && echo Rojo laeuft — Fenster offen lassen! && echo Studio: Plugins ^> Rojo ^> Connect && echo. && rojo serve default.project.json"

timeout /t 2 >nul
echo  Rojo-Fenster wurde geoeffnet.
echo.
notepad STATUS.txt 2>nul
pause
