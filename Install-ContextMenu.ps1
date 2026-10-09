#requires -Version 5.1
<#
.SYNOPSIS
    为 Windows 资源管理器安装 Set-FolderIcon 右键菜单。

.DESCRIPTION
    将以下右键菜单项注册到系统：
    1. 选中文件夹右键 -> 应用此文件夹内程序图标
    2. 文件夹空白处右键 -> 应用当前文件夹内程序图标
    3. 选中文件夹右键 -> 还原为默认文件夹图标
    4. 文件夹空白处右键 -> 还原当前文件夹图标

.PARAMETER AllUsers
    为本机所有用户注册（需要管理员权限）。默认仅为当前用户注册（无需管理员权限）。
#>

[CmdletBinding()]
param(
    [switch]$AllUsers
)

$ErrorActionPreference = "Stop"

$scriptTarget = Join-Path $PSScriptRoot "Set-FolderIcon.ps1"
if (-not (Test-Path -LiteralPath $scriptTarget)) {
    Write-Error "未找到核心脚本文件: $scriptTarget"
    exit 1
}

$rootKey = if ($AllUsers) { "Registry::HKEY_LOCAL_MACHINE\Software\Classes" } else { "Registry::HKEY_CURRENT_USER\Software\Classes" }

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "         Set-FolderIcon 右键菜单安装程序                    " -ForegroundColor White
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "目标脚本: $scriptTarget" -ForegroundColor Gray
Write-Host "注册范围: $(if ($AllUsers) { '所有用户 (HKLM)' } else { '当前用户 (HKCU - 无需管理员权限)' })`n" -ForegroundColor Gray

# 辅助函数：创建或更新注册表项
function Set-RegKeyAndValues {
    param(
        [string]$SubKey,
        [string]$DefaultText,
        [string]$IconPath,
        [string]$CommandString
    )

    $fullPath = Join-Path $rootKey $SubKey
    if (-not (Test-Path -LiteralPath $fullPath)) {
        New-Item -Path $fullPath -Force | Out-Null
    }
    
    Set-ItemProperty -LiteralPath $fullPath -Name "(default)" -Value $DefaultText -Force
    if ($IconPath) {
        Set-ItemProperty -LiteralPath $fullPath -Name "Icon" -Value $IconPath -Force
    }

    $cmdPath = Join-Path $fullPath "command"
    if (-not (Test-Path -LiteralPath $cmdPath)) {
        New-Item -Path $cmdPath -Force | Out-Null
    }
    Set-ItemProperty -LiteralPath $cmdPath -Name "(default)" -Value $CommandString -Force
}

try {
    # 1. 选中文件夹右键：设置应用图标
    Set-RegKeyAndValues -SubKey "Directory\shell\SetAppIcon" `
        -DefaultText "应用此文件夹内程序图标" `
        -IconPath "imageres.dll,114" `
        -CommandString "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptTarget`" -Path `"%1`""

    # 2. 文件夹内部空白处右键：设置应用图标
    Set-RegKeyAndValues -SubKey "Directory\Background\shell\SetAppIcon" `
        -DefaultText "应用当前文件夹内程序图标" `
        -IconPath "imageres.dll,114" `
        -CommandString "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptTarget`" -Path `"%V`""

    # 3. 选中文件夹右键：还原默认图标
    Set-RegKeyAndValues -SubKey "Directory\shell\RestoreAppIcon" `
        -DefaultText "还原为默认文件夹图标" `
        -IconPath "shell32.dll,3" `
        -CommandString "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptTarget`" -Path `"%1`" -Restore"

    # 4. 文件夹内部空白处右键：还原默认图标
    Set-RegKeyAndValues -SubKey "Directory\Background\shell\RestoreAppIcon" `
        -DefaultText "还原当前文件夹图标" `
        -IconPath "shell32.dll,3" `
        -CommandString "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptTarget`" -Path `"%V`" -Restore"

    Write-Host "[成功] 右键菜单已成功注册！" -ForegroundColor Green
    Write-Host "已添加以下项：" -ForegroundColor White
    Write-Host "  1. 文件夹右键 -> [应用此文件夹内程序图标]" -ForegroundColor DarkGreen
    Write-Host "  2. 文件夹空白处右键 -> [应用当前文件夹内程序图标]" -ForegroundColor DarkGreen
    Write-Host "  3. 文件夹右键 -> [还原为默认文件夹图标]" -ForegroundColor DarkGreen
    Write-Host "  4. 文件夹空白处右键 -> [还原当前文件夹图标]" -ForegroundColor DarkGreen
    Write-Host "`n现在可以在任意文件夹上右键直接使用了！" -ForegroundColor Cyan
} catch {
    Write-Error "注册失败: $_"
    exit 1
}