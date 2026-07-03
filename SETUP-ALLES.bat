@echo off
chcp 65001 >nul
title Nova Bladers — SETUP ALLES
color 0B
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup-alles.ps1"
echo.
notepad STATUS.txt 2>nul
pause
