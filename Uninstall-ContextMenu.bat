@echo off
chcp 65001 >nul
setlocal
title п╤тьср╪Э╡к╣╔ - Set-FolderIcon

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-ContextMenu.ps1"
echo.
pause
