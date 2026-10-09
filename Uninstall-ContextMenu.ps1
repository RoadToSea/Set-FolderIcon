#requires -Version 5.1
<#
.SYNOPSIS
    卸载并清理 Set-FolderIcon 在 Windows 资源管理器中的右键菜单。

.DESCRIPTION
    清理 HKCU 和 HKLM 下注册的 Set-FolderIcon 相关右键菜单。
#>

[CmdletBinding()]
param()

$keysToRemove = @(
    "Directory\shell\SetAppIcon",
    "Directory\shell\RestoreAppIcon",
    "Directory\Background\shell\SetAppIcon",
    "Directory\Background\shell\RestoreAppIcon",
    "Directory\Background\shell\SetSubFolderIcons",
    "Directory\Background\shell\RestoreSubFolderIcons"
)

$roots = @(
    "Registry::HKEY_CURRENT_USER\Software\Classes",
    "Registry::HKEY_LOCAL_MACHINE\Software\Classes"
)

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "         Set-FolderIcon 右键菜单卸载程序                    " -ForegroundColor White
Write-Host "============================================================" -ForegroundColor Cyan

$removedCount = 0

foreach ($root in $roots) {
    foreach ($k in $keysToRemove) {
        $fullPath = Join-Path $root $k
        if (Test-Path -LiteralPath $fullPath) {
            try {
                Remove-Item -LiteralPath $fullPath -Recurse -Force -ErrorAction Stop
                Write-Host "[已移除] $fullPath" -ForegroundColor Yellow
                $removedCount++
            } catch {
                Write-Warning "无法删除项: $fullPath ($($_.Exception.Message))"
            }
        }
    }
}

if ($removedCount -gt 0) {
    Write-Host "`n[成功] 右键菜单已成功卸载并清理！" -ForegroundColor Green
} else {
    Write-Host "`n[提示] 系统中未检测到相关右键菜单项，无需清理。" -ForegroundColor Gray
}