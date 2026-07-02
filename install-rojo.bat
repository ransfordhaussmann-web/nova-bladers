@echo off
chcp 65001 >nul
title Nova Bladers — Rojo installieren
color 0B
cd /d "%~dp0"

echo.
echo  ========================================
echo   Rojo wird installiert …
echo  ========================================
echo.

where rojo >nul 2>&1
if not errorlevel 1 (
  echo  Rojo ist schon installiert:
  rojo --version
  echo.
  goto :done
)

:: 1) winget (einfachste Methode auf Windows)
where winget >nul 2>&1
if not errorlevel 1 (
  echo  [1/3] Installiere mit winget …
  winget install -e --id Rojo.Rojo --accept-package-agreements --accept-source-agreements
  if not errorlevel 1 goto :check
  echo  winget fehlgeschlagen — versuche Aftman …
)

:: 2) aftman aus aftman.toml
where aftman >nul 2>&1
if not errorlevel 1 (
  echo  [2/3] Installiere mit aftman …
  aftman install
  if not errorlevel 1 goto :check
)

:: 3) Hinweis manuell
echo.
echo  Automatische Installation fehlgeschlagen.
echo.
echo  Bitte in PowerShell ausfuehren:
echo    winget install -e --id Rojo.Rojo
echo.
echo  Oder: https://github.com/rojo-rbx/rojo/releases
echo.
pause
exit /b 1

:check
where rojo >nul 2>&1
if errorlevel 1 (
  echo.
  echo  Rojo installiert, aber noch nicht im PATH.
  echo  Terminal / PC neu starten, dann start-rojo.bat erneut.
  echo.
  pause
  exit /b 1
)

:done
echo.
echo  ========================================
echo   Fertig!
echo  ========================================
echo.
rojo --version
echo.
echo  Naechste Schritte:
echo    1. start-rojo.bat
echo    2. Roblox Studio ^> Plugins ^> Rojo ^> Connect
echo.
echo  Rojo-Plugin in Studio (falls noch nicht):
echo    Creator Store ^> "Rojo" suchen ^> installieren
echo.
pause
