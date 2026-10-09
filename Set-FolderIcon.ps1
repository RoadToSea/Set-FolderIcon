#requires -Version 5.1
<#
.SYNOPSIS
    根据文件夹内部存放的应用程序，自动将该文件夹的图标修改为对应的应用图标。

.DESCRIPTION
    分析指定文件夹内的可执行文件 (.exe)、图标文件 (.ico) 或快捷方式 (.lnk)，
    智能挑选最匹配的主应用程序图标，自动生成/更新 desktop.ini 并设置属性，
    同时通知 Windows Explorer 刷新图标缓存。

.PARAMETER Path
    目标文件夹路径（支持多个路径、管道输入、拖拽传入）。

.PARAMETER AllSubFolders
    批量处理指定文件夹下的所有一级子文件夹。

.PARAMETER Restore
    将指定文件夹恢复为 Windows 系统默认文件夹图标。

.PARAMETER Force
    强制更新已自定义过的文件夹图标。

.PARAMETER Quiet
    静默运行，不输出交互提示。
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromRemainingArguments = $true)]
    [string[]]$Path,

    [Alias("Batch")]
    [switch]$AllSubFolders,

    [switch]$Restore,

    [switch]$Force,

    [switch]$Quiet
)

# 确保 Win32 API 辅助类型已加载
if (-not ([System.Management.Automation.PSTypeName]'Win32IconHelper').Type) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class Win32IconHelper {
    // 检查 PE 文件中包含的图标资源数量
    [DllImport("shell32.dll", CharSet = CharSet.Auto)]
    public static extern uint ExtractIconEx(string szFileName, int nIconIndex, IntPtr[] phiconLarge, IntPtr[] phiconSmall, uint nIcons);

    // 通知 Windows Shell 刷新文件/文件夹状态
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    public static extern void SHChangeNotify(int wEventId, uint uFlags, string dwItem1, string dwItem2);
}
"@ -ErrorAction SilentlyContinue
}

# Win32 常量
$SHCNE_UPDATEDIR   = 0x00001000
$SHCNE_UPDATEITEM  = 0x00002000
$SHCNE_ASSOCCHANGED = 0x08000000
$SHCNF_PATHW       = 0x0005
$SHCNF_IDLIST      = 0x0000

# 计算相对路径（兼容 Windows PowerShell 5.1 与 PowerShell 7+）
function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)] [string]$BasePath,
        [Parameter(Mandatory = $true)] [string]$TargetPath
    )
    try {
        $baseFull = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
        $targetFull = [System.IO.Path]::GetFullPath($TargetPath)
        
        $baseUri = [System.Uri]$baseFull
        $targetUri = [System.Uri]$targetFull
        
        # 若在不同盘符，无法相对化，直接返回绝对路径
        if ($baseUri.Scheme -ne $targetUri.Scheme -or $baseUri.Host -ne $targetUri.Host) {
            return $targetFull
        }
        
        $relUri = $baseUri.MakeRelativeUri($targetUri)
        $relPath = [System.Uri]::UnescapeDataString($relUri.ToString()).Replace('/', '\')
        return $relPath
    } catch {
        return $TargetPath
    }
}

# 智能查找文件夹内最匹配的应用图标
function Find-FolderAppIcon {
    param([Parameter(Mandatory = $true)] [string]$FolderPath)

    if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) {
        return $null
    }

    $folderItem = Get-Item -LiteralPath $FolderPath
    $folderName = $folderItem.Name
    $normFolderName = ($folderName -replace '[^a-zA-Z0-9\u4e00-\u9fa5]', '').ToLower()

    $candidates = @()

    # 1. 扫描根目录的 .ico 图标文件
    $icoFiles = Get-ChildItem -LiteralPath $FolderPath -Filter "*.ico" -File -ErrorAction SilentlyContinue
    foreach ($ico in $icoFiles) {
        $normName = ($ico.BaseName -replace '[^a-zA-Z0-9\u4e00-\u9fa5]', '').ToLower()
        $score = 500
        if ($normName -eq $normFolderName) {
            $score += 500
        } elseif ($normName -match "^$normFolderName" -or $normFolderName -match "^$normName") {
            $score += 300
        }
        $rel = Get-RelativePath -BasePath $FolderPath -TargetPath $ico.FullName
        $candidates += [PSCustomObject]@{
            File      = $ico
            Type      = 'ico'
            RelPath   = $rel
            Score     = $score
            IconIndex = 0
            IconCount = 1
            Reason    = "ICO文件"
        }
    }

    # 2. 扫描 .exe 可执行文件（优先在根目录下查找）
    $rootExes = Get-ChildItem -LiteralPath $FolderPath -Filter "*.exe" -File -ErrorAction SilentlyContinue
    $searchExes = @($rootExes)

    # 如果根目录下没有任何 exe，或者根目录下只有卸载/升级程序，则递归扫描前2层子目录
    $needSubScan = ($rootExes.Count -eq 0)
    if (-not $needSubScan) {
        $validRootExes = $rootExes | Where-Object {
            $_.Name -notmatch '(?i)unins|uninstall|setup|installer|update|updater|crashpad|feedback|helper|daemon|elevate'
        }
        if ($validRootExes.Count -eq 0) {
            $needSubScan = $true
        }
    }

    if ($needSubScan) {
        # 排除无关的重度子目录以加快速度
        $subDirs = Get-ChildItem -LiteralPath $FolderPath -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '(?i)^(\.git|node_modules|logs|cache|tmp|temp|doc|docs|include|lib|share|man)$' }
        foreach ($sd in $subDirs) {
            $subExes = Get-ChildItem -LiteralPath $sd.FullName -Filter "*.exe" -File -Recurse -Depth 1 -ErrorAction SilentlyContinue
            $searchExes += $subExes
        }
    }

    # 过滤与评分 exe
    foreach ($exe in $searchExes) {
        $name = $exe.Name
        $baseName = $exe.BaseName
        $normName = ($baseName -replace '[^a-zA-Z0-9\u4e00-\u9fa5]', '').ToLower()

        # 排除非主程序（卸载、安装包、升级、崩溃收集、服务守护等）
        if ($name -match '(?i)unins|uninstall|setup|installer|update|updater|crashpad|crashreporter|feedback|helper|daemon|elevate|vcredist|dotnet|dxwebsetup') {
            continue
        }

        # 检测 PE 文件是否包含有效图标资源
        $iconCount = [Win32IconHelper]::ExtractIconEx($exe.FullName, -1, $null, $null, 0)
        if ($iconCount -eq 0) {
            continue
        }

        $score = 100
        $isRoot = ($exe.DirectoryName -eq $folderItem.FullName)
        if ($isRoot) { $score += 150 } else { $score += 50 }

        # 名称匹配评分
        if ($normName -eq $normFolderName) {
            $score += 600
        } elseif ($normName -match "^$normFolderName" -or $normFolderName -match "^$normName") {
            $score += 400
        } elseif ($normName -match $normFolderName -or $normFolderName -match $normName) {
            $score += 250
        }

        # 倾向于主 GUI 程序标识
        if ($name -match '(?i)64|gui|client|desktop|main|app') { $score += 50 }

        # 文件体积加分（主 GUI 程序通常在数 MB 以上，避免小 stub 启动器）
        $sizeMB = [math]::Min(50, [math]::Round($exe.Length / 1MB))
        $score += ($sizeMB * 2)

        $rel = Get-RelativePath -BasePath $FolderPath -TargetPath $exe.FullName

        $candidates += [PSCustomObject]@{
            File      = $exe
            Type      = 'exe'
            RelPath   = $rel
            Score     = $score
            IconIndex = 0
            IconCount = $iconCount
            Reason    = "EXE主程序 ($($name))"
        }
    }

    # 3. 若仍未找到，检查根目录下的快捷方式 (.lnk)
    if ($candidates.Count -eq 0) {
        $lnkFiles = Get-ChildItem -LiteralPath $FolderPath -Filter "*.lnk" -File -ErrorAction SilentlyContinue
        if ($lnkFiles.Count -gt 0) {
            try {
                $wsh = New-Object -ComObject WScript.Shell
                foreach ($lnk in $lnkFiles) {
                    $sc = $wsh.CreateShortcut($lnk.FullName)
                    $target = $sc.TargetPath
                    if ($target -and (Test-Path -LiteralPath $target) -and $target.EndsWith(".exe", [System.StringComparison]::OrdinalIgnoreCase)) {
                        $iconCount = [Win32IconHelper]::ExtractIconEx($target, -1, $null, $null, 0)
                        if ($iconCount -gt 0) {
                            $rel = Get-RelativePath -BasePath $FolderPath -TargetPath $target
                            $candidates += [PSCustomObject]@{
                                File      = (Get-Item -LiteralPath $target)
                                Type      = 'lnk'
                                RelPath   = $rel
                                Score     = 300
                                IconIndex = 0
                                IconCount = $iconCount
                                Reason    = "快捷方式指向 ($($lnk.Name))"
                            }
                            break
                        }
                    }
                }
            } catch {}
        }
    }

    if ($candidates.Count -eq 0) {
        return $null
    }

    return ($candidates | Sort-Object -Property Score -Descending | Select-Object -First 1)
}

# 为文件夹设置自定义图标
function Set-FolderIcon {
    param(
        [Parameter(Mandatory = $true)] [string]$FolderPath,
        [Parameter(Mandatory = $true)] [string]$IconRelOrAbsPath,
        [int]$IconIndex = 0
    )

    try {
        $folderItem = Get-Item -LiteralPath $FolderPath
        $iniPath = Join-Path $folderItem.FullName "desktop.ini"

        # 1. 解除已有 desktop.ini 的只读/隐藏/系统属性以便写入
        if (Test-Path -LiteralPath $iniPath) {
            try {
                $existingIni = Get-Item -LiteralPath $iniPath -Force
                $existingIni.Attributes = [System.IO.FileAttributes]::Normal
            } catch {}
        }

        # 2. 构造 desktop.ini 内容
        $iniContent = @"
[.ShellClassInfo]
IconResource=$IconRelOrAbsPath,$IconIndex
[ViewState]
Mode=
Vid=
FolderType=Generic
"@

        # 使用 Unicode (UTF-16 LE with BOM) 写入，原生支持中文路径
        [System.IO.File]::WriteAllText($iniPath, $iniContent, [System.Text.Encoding]::Unicode)

        # 3. 必须设置 desktop.ini 为 Hidden + System
        $iniFile = Get-Item -LiteralPath $iniPath -Force
        $iniFile.Attributes = [System.IO.FileAttributes]::Hidden -bor [System.IO.FileAttributes]::System

        # 4. 关键：文件夹必须具有 ReadOnly 属性，Explorer 才会读取 desktop.ini
        # (注：Windows 中文件夹的只读属性不影响内部文件修改，仅用于指示自定义视图)
        $folderItem = Get-Item -LiteralPath $FolderPath
        $folderItem.Attributes = $folderItem.Attributes -bor [System.IO.FileAttributes]::ReadOnly
        $folderItem.LastWriteTime = Get-Date

        # 5. 触发 Windows Shell 刷新通知
        [Win32IconHelper]::SHChangeNotify($SHCNE_UPDATEITEM, $SHCNF_PATHW, $folderItem.FullName, $null)
        [Win32IconHelper]::SHChangeNotify($SHCNE_UPDATEDIR,  $SHCNF_PATHW, $folderItem.FullName, $null)
        [Win32IconHelper]::SHChangeNotify($SHCNE_ASSOCCHANGED, $SHCNF_IDLIST, $null, $null)

        return $true
    } catch {
        Write-Warning "写入图标配置失败 [$FolderPath]: $($_.Exception.Message)"
        return $false
    }
}

# 还原文件夹为默认系统图标
function Reset-FolderIcon {
    param([Parameter(Mandatory = $true)] [string]$FolderPath)

    try {
        $folderItem = Get-Item -LiteralPath $FolderPath
        $iniPath = Join-Path $folderItem.FullName "desktop.ini"

        if (Test-Path -LiteralPath $iniPath) {
            $iniFile = Get-Item -LiteralPath $iniPath -Force
            $iniFile.Attributes = [System.IO.FileAttributes]::Normal
            Remove-Item -LiteralPath $iniPath -Force
        }

        # 取消文件夹的 ReadOnly 属性
        $folderItem = Get-Item -LiteralPath $FolderPath
        $folderItem.Attributes = $folderItem.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
        $folderItem.LastWriteTime = Get-Date

        # 刷新通知
        [Win32IconHelper]::SHChangeNotify($SHCNE_UPDATEITEM, $SHCNF_PATHW, $folderItem.FullName, $null)
        [Win32IconHelper]::SHChangeNotify($SHCNE_UPDATEDIR,  $SHCNF_PATHW, $folderItem.FullName, $null)
        [Win32IconHelper]::SHChangeNotify($SHCNE_ASSOCCHANGED, $SHCNF_IDLIST, $null, $null)

        return $true
    } catch {
        Write-Warning "还原图标失败 [$FolderPath]: $($_.Exception.Message)"
        return $false
    }
}

# 处理单个文件夹逻辑
function Process-SingleFolder {
    param(
        [Parameter(Mandatory = $true)] [string]$TargetFolder,
        [switch]$IsRestore
    )

    if (-not (Test-Path -LiteralPath $TargetFolder -PathType Container)) {
        Write-Warning "路径不存在或不是文件夹: $TargetFolder"
        return $false
    }

    $folderItem = Get-Item -LiteralPath $TargetFolder
    $folderName = $folderItem.Name

    if ($IsRestore) {
        $ok = Reset-FolderIcon -FolderPath $folderItem.FullName
        if ($ok) {
            Write-Host "[已还原] $folderName -> 恢复系统默认图标" -ForegroundColor Yellow
            return $true
        }
        return $false
    }

    $best = Find-FolderAppIcon -FolderPath $folderItem.FullName
    if ($null -eq $best) {
        Write-Host "[跳过] $folderName -> 未找到包含图标的应用程序 (.exe / .ico)" -ForegroundColor DarkGray
        return $false
    }

    $ok = Set-FolderIcon -FolderPath $folderItem.FullName -IconRelOrAbsPath $best.RelPath -IconIndex $best.IconIndex
    if ($ok) {
        Write-Host "[成功] $folderName -> 匹配到: $($best.RelPath) [$($best.Reason)]" -ForegroundColor Green
        return $true
    }
    return $false
}

# 弹出文件夹选择对话框
function Show-FolderBrowserDialog {
    param([string]$Description = "请选择要设置应用图标的目标文件夹")
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = $Description
    $dialog.ShowNewFolderButton = $false
    if ($PSScriptRoot -and (Test-Path -LiteralPath $PSScriptRoot)) {
        $parent = Split-Path -Parent $PSScriptRoot
        if ($parent -and (Test-Path -LiteralPath $parent)) {
            $dialog.SelectedPath = $parent
        } else {
            $dialog.SelectedPath = $PSScriptRoot
        }
    }
    $result = $dialog.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.SelectedPath
    }
    return $null
}

# ----------------- 主程序入口 -----------------

# 处理通过参数传入的路径列表
if ($Path -and $Path.Count -gt 0) {
    $totalSuccess = 0
    $totalProcessed = 0

    foreach ($p in $Path) {
        if (-not (Test-Path -LiteralPath $p)) {
            Write-Warning "路径无效: $p"
            continue
        }

        if ($AllSubFolders) {
            # 批量处理该路径下的所有一级子目录
            $subFolders = Get-ChildItem -LiteralPath $p -Directory
            Write-Host "============================================================" -ForegroundColor Cyan
            Write-Host "  正在批量处理目录下的所有子文件夹..." -ForegroundColor White
            Write-Host "  目标目录: $p" -ForegroundColor Gray
            Write-Host "  子文件夹总数: $($subFolders.Count)" -ForegroundColor Gray
            Write-Host "============================================================" -ForegroundColor Cyan
            
            foreach ($sub in $subFolders) {
                # 跳过本工具自身所在目录
                if ($PSScriptRoot -and ($sub.FullName -eq $PSScriptRoot)) {
                    continue
                }
                $totalProcessed++
                $res = Process-SingleFolder -TargetFolder $sub.FullName -IsRestore:$Restore
                if ($res) { $totalSuccess++ }
            }
            Write-Host "============================================================" -ForegroundColor Cyan
            Write-Host ">>> 批量处理完成！成功: $totalSuccess / 总计: $totalProcessed`n" -ForegroundColor Cyan
        } else {
            $totalProcessed++
            $res = Process-SingleFolder -TargetFolder $p -IsRestore:$Restore
            if ($res) { $totalSuccess++ }
        }
    }

    # 如果不是静默模式，显示完成状态并在倒计时后自动关闭（也可按任意键立即关闭）
    if (-not $Quiet) {
        $actionDesc = if ($Restore) { "还原" } else { "设置" }
        Write-Host "操作完成 (成功 $actionDesc $totalSuccess 个文件夹)。" -ForegroundColor Green
        Write-Host "窗口将在 2 秒后自动关闭 (或按任意键立即退出)..." -ForegroundColor Gray

        $timeout = 20
        while ($timeout -gt 0) {
            try {
                if ([System.Console]::KeyAvailable) {
                    [System.Console]::ReadKey($true) | Out-Null
                    break
                }
            } catch {
                Start-Sleep -Seconds 2
                break
            }
            Start-Sleep -Milliseconds 100
            $timeout--
        }
    }
    exit 0
}

# 无参数运行：启动交互式菜单
Clear-Host
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "     Windows 文件夹应用图标自动定制工具 (Folder Icon Tool)  " -ForegroundColor White
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " [1] 选择单个文件夹应用图标 (弹窗选择)"
Write-Host " [2] 批量扫描并应用指定目录下的所有子文件夹 (弹窗选择)"
Write-Host " [3] 手动输入文件夹路径处理"
Write-Host " [4] 还原某个文件夹为系统默认图标 (弹窗选择)"
Write-Host " [0] 退出"
Write-Host "------------------------------------------------------------" -ForegroundColor Gray

$choice = Read-Host "请输入操作选项 [0-4]"

switch ($choice) {
    "1" {
        $selected = Show-FolderBrowserDialog -Description "请选择要设置应用图标的目标文件夹"
        if ($selected) {
            Write-Host "`n正在处理: $selected" -ForegroundColor Cyan
            Process-SingleFolder -TargetFolder $selected
        } else {
            Write-Host "已取消选择。" -ForegroundColor Yellow
        }
    }
    "2" {
        $batchTarget = Show-FolderBrowserDialog -Description "请选择要批量处理其子文件夹的父目录"
        if ($batchTarget) {
            $subFolders = Get-ChildItem -LiteralPath $batchTarget -Directory
            Write-Host "`n>>> 正在批量扫描并设置 [$batchTarget] 下的 $($subFolders.Count) 个子文件夹..." -ForegroundColor Cyan
            foreach ($sub in $subFolders) {
                if ($PSScriptRoot -and ($sub.FullName -eq $PSScriptRoot)) {
                    continue
                }
                Process-SingleFolder -TargetFolder $sub.FullName
            }
            Write-Host ">>> 批量处理完成！`n" -ForegroundColor Cyan
        } else {
            Write-Host "已取消选择。" -ForegroundColor Yellow
        }
    }
    "3" {
        $inputPath = Read-Host "`n请输入目标文件夹完整路径"
        if ($inputPath -and (Test-Path -LiteralPath $inputPath -PathType Container)) {
            Process-SingleFolder -TargetFolder $inputPath
        } else {
            Write-Warning "输入的路径无效或不存在！"
        }
    }
    "4" {
        $restorePath = Show-FolderBrowserDialog -Description "请选择要恢复为默认图标的目标文件夹"
        if ($restorePath) {
            Process-SingleFolder -TargetFolder $restorePath -IsRestore
        } else {
            Write-Host "已取消选择。" -ForegroundColor Yellow
        }
    }
    Default {
        Write-Host "已退出。" -ForegroundColor Gray
    }
}
