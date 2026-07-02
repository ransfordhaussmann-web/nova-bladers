@echo off
chcp 65001 >nul
title Nova Bladers — Projektordner
cd /d "%~dp0"
echo.
echo  Nova Bladers Projektordner:
echo  %CD%
echo.
explorer "%CD%"
pause
