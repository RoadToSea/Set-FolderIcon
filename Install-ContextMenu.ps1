#requires -Version 5.1
<#
.SYNOPSIS
    为 Windows 资源管理器安装 Set-FolderIcon 右键菜单。

.DESCRIPTION
    将以下右键菜单项注册到系统：
    1. 选中单个文件夹右键 -> 应用此文件夹内程序图标 (仅处理该文件夹)
    2. 选中单个文件夹右键 -> 还原为默认文件夹图标 (仅还原该文件夹)
    3. 文件夹内部空白处右键 -> 批量应用所有子文件夹图标 (批量处理当前目录下所有子文件夹)
    4. 文件夹内部空白处右键 -> 批量还原所有子文件夹图标 (批量还原当前目录下所有子文件夹)

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

# 辅助函数：安全删除已废弃或冲突的注册表项
function Remove-LegacyKey {
    param([string]$SubKey)
    $fullPath = Join-Path $rootKey $SubKey
    if (Test-Path -LiteralPath $fullPath) {
        try {
            Remove-Item -LiteralPath $fullPath -Recurse -Force -ErrorAction SilentlyContinue
        } catch {}
    }
}

try {
    # 0. 清理旧版在文件夹内部空白处产生歧义的旧项
    Remove-LegacyKey -SubKey "Directory\Background\shell\SetAppIcon"
    Remove-LegacyKey -SubKey "Directory\Background\shell\RestoreAppIcon"

    # 1. 选中单个文件夹右键：设置该文件夹应用图标
    Set-RegKeyAndValues -SubKey "Directory\shell\SetAppIcon" `
        -DefaultText "应用此文件夹内程序图标" `
        -IconPath "imageres.dll,114" `
        -CommandString "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"& '$scriptTarget' -Path '%1'`""

    # 2. 选中单个文件夹右键：还原该文件夹为默认图标
    Set-RegKeyAndValues -SubKey "Directory\shell\RestoreAppIcon" `
        -DefaultText "还原为默认文件夹图标" `
        -IconPath "shell32.dll,3" `
        -CommandString "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"& '$scriptTarget' -Path '%1' -Restore`""

    # 3. 文件夹内部空白处右键：批量应用所有子文件夹图标
    Set-RegKeyAndValues -SubKey "Directory\Background\shell\SetSubFolderIcons" `
        -DefaultText "批量应用所有子文件夹图标" `
        -IconPath "imageres.dll,114" `
        -CommandString "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"& '$scriptTarget' -Path '%V' -AllSubFolders`""

    # 4. 文件夹内部空白处右键：批量还原所有子文件夹图标
    Set-RegKeyAndValues -SubKey "Directory\Background\shell\RestoreSubFolderIcons" `
        -DefaultText "批量还原所有子文件夹图标" `
        -IconPath "shell32.dll,3" `
        -CommandString "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"& '$scriptTarget' -Path '%V' -AllSubFolders -Restore`""

    Write-Host "[成功] 右键菜单已成功注册！" -ForegroundColor Green
    Write-Host "已配置以下操作逻辑：" -ForegroundColor White
    Write-Host "  [选中文件夹]   右键 -> [应用此文件夹内程序图标] (仅设置当前单个文件夹)" -ForegroundColor DarkGreen
    Write-Host "  [选中文件夹]   右键 -> [还原为默认文件夹图标]   (仅还原当前单个文件夹)" -ForegroundColor DarkGreen
    Write-Host "  [文件夹空白处] 右键 -> [批量应用所有子文件夹图标] (批量处理其下所有子文件夹)" -ForegroundColor DarkGreen
    Write-Host "  [文件夹空白处] 右键 -> [批量还原所有子文件夹图标] (批量还原其下所有子文件夹)" -ForegroundColor DarkGreen
    Write-Host "`n现在可以打开资源管理器体验了！" -ForegroundColor Cyan
} catch {
    Write-Error "注册失败: $_"
    exit 1
}