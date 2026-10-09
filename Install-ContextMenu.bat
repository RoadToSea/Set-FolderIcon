@echo off
chcp 65001 >nul
setlocal
title °²×°ÓÒ¼ü²Ëµ¥ - Set-FolderIcon

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-ContextMenu.ps1"
echo.
pause
