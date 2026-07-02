@echo off
title Nova Bladers — PC Setup
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup-pc.ps1"
pause
