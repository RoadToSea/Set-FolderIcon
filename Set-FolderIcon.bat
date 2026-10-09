@echo off
chcp 65001 >nul
setlocal
title Set-FolderIcon

if "%~1"=="" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Set-FolderIcon.ps1"
    goto :done
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Set-FolderIcon.ps1" -Path %*

:done
echo.
pause
