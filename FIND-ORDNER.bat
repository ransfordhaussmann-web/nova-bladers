@echo off
chcp 65001 >nul
title Nova Bladers — Ordner finden
color 0E

set "FOUND="
set "USER_DIR=C:\Users\%USERNAME%"

echo.
echo  ========================================
echo   Nova Bladers — Ordner suchen
echo  ========================================
echo.

:: Typische Orte pruefen
for %%P in (
  "%USER_DIR%\NovaBladers"
  "%USER_DIR%\Documents\NovaBladers"
  "%USER_DIR%\Desktop\NovaBladers"
  "%USER_DIR%\Desktop\nova-bladers-main"
  "%USER_DIR%\Downloads\nova-bladers-main"
  "%USER_DIR%\Downloads\nova-bladers"
) do (
  if exist "%%~P\import-nova-striker.bat" (
    set "FOUND=%%~P"
    goto :found
  )
)

:: Breitere Suche in Downloads/Desktop (nur 1 Ebene)
for /d %%D in ("%USER_DIR%\Downloads\*" "%USER_DIR%\Desktop\*") do (
  if exist "%%~D\import-nova-striker.bat" (
    set "FOUND=%%~D"
    goto :found
  )
)

:notfound
echo  Kein NovaBladers-Ordner gefunden.
echo.
echo  ========================================
echo   NEU ANLEGEN (3 Schritte):
echo  ========================================
echo.
echo  1. Cursor oeffnen
echo  2. Strg+Shift+P → "Git: Clone"
echo  3. URL einfuegen:
echo     https://github.com/ransfordhaussmann-web/nova-bladers
echo  4. Speichern unter:
echo     %USER_DIR%\NovaBladers
echo.
echo  ODER ZIP von GitHub:
echo  https://github.com/ransfordhaussmann-web/nova-bladers
echo  → Code → Download ZIP → entpacken nach NovaBladers
echo.
start https://github.com/ransfordhaussmann-web/nova-bladers
pause
exit /b 1

:found
echo  GEFUNDEN:
echo  %FOUND%
echo.
echo  Oeffne Ordner …
explorer "%FOUND%"
echo.
echo  In Cursor: File → Open Folder → obigen Pfad waehlen
echo.
pause
