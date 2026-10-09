# Set-FolderIcon

<p align="center">
  <strong>Auto Folder Icon Customizer for Windows</strong><br>
  Windows 文件夹应用图标自动定制工具
</p>

<p align="center">
  <strong>English | <a href="README.md">简体中文</a></strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT">
  <img src="https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6.svg" alt="Windows">
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE.svg" alt="PowerShell">
  <img src="https://img.shields.io/badge/Pure%20Script-No%20Third--party%20Deps-brightgreen.svg" alt="Pure Script">
</p>

---

## 📖 Introduction

When storing portable tools, standalone software, development toolchains, or game directories on Windows, all folders look like identical, plain yellow icons by default—making visual searching tedious and cluttered.

**Set-FolderIcon** is a lightweight, portable, and open-source script tool for Windows:
- Automatically scans target directories and uses a heuristic scoring algorithm to intelligently identify the primary application (`.exe`), icon file (`.ico`), or shortcut (`.lnk`);
- Extracts icon metadata and writes a standard Windows `desktop.ini` using **relative paths** (so icons remain intact when moving directories or using portable USB drives/external SSDs);
- Calls native Win32 `SHChangeNotify` APIs to trigger instant icon refreshes in Windows Explorer without restarting the `explorer.exe` process.

---

## ✨ Features

- 🎯 **Smart Main Executable Detection**:
  - Leverages Win32 `ExtractIconEx` to inspect PE file structures for valid embedded icon resources.
  - Heuristic scoring based on name similarity, file size weighting, and keywords (`gui`, `client`, `64`, `main`, `app`).
  - Automatically filters out setup/installer/updater/uninstaller stubs (`unins000.exe`, `uninstall.exe`, `updater.exe`, `crashpad.exe`, background daemons, etc.).
  - Recursively inspects up to 2 sub-levels if no candidate is found at the root, or falls back to root `.lnk` shortcuts.
- 💾 **Portable & Green (Relative Paths)**:
  - Generates relative paths in `desktop.ini` whenever possible (e.g., `IconResource=App.exe,0` or `IconResource=bin\App.exe,0`).
  - Icons remain valid across drive letter changes, external drives, or renamed parent directories.
- ⚡ **Seamless Context Menu Integration**:
  - One-click installer and uninstaller scripts included.
  - **Single folder**: Right-click any folder to customize or restore only that folder.
  - **Batch subfolders**: Right-click on the blank background of a container folder to batch process all subfolders.
  - Registered under the current user (`HKCU`), requiring **no administrator privileges**.
- 🔄 **Instant Live Refresh**:
  - Broadcasts shell notifications via `SHChangeNotify` (`SHCNE_UPDATEITEM`, `SHCNE_UPDATEDIR`, `SHCNE_ASSOCCHANGED`), updating icons live.
- 🛡️ **Fully Reversible**:
  - Cleanly removes `desktop.ini` and clears the directory's read-only flag to restore the default Windows folder icon.
- 📦 **Zero Third-Party Dependencies**:
  - Pure native PowerShell 5.1+ and Windows Batch scripts. Works out of the box on Windows 10 & 11.

---

## 📁 Directory Structure

```text
Set-FolderIcon/
├── Set-FolderIcon.ps1          # Core logic script (PowerShell 5.1+)
├── Set-FolderIcon.bat          # Console interactive menu & drag-and-drop launcher
├── Install-ContextMenu.bat     # One-click context menu installer (Double-click)
├── Install-ContextMenu.ps1     # Smart context menu registration (HKCU, no admin required)
├── Uninstall-ContextMenu.bat   # One-click context menu uninstaller (Double-click)
├── Uninstall-ContextMenu.ps1   # Uninstaller script to clean up registry entries
├── Register-ContextMenu.reg    # Registry template for manual import reference
├── Unregister-ContextMenu.reg  # Registry cleanup template for manual reference
├── LICENSE                     # MIT Open Source License
├── .gitignore                  # Git ignore rules
├── README.md                   # Chinese documentation (简体中文)
└── README_EN.md                # English documentation (This file)
```

---

## 🚀 Usage

### Method 1: Windows Explorer Context Menu (Recommended)

1. Double-click `Install-ContextMenu.bat` to register the context menu (no admin rights needed).
2. Use the menu depending on your needs:
   - **Right-click a single folder**:
     - Click **"应用此文件夹内程序图标" (Set app icon)**: Applies icon only to the selected folder.
     - Click **"还原为默认文件夹图标" (Restore default icon)**: Reverts only the selected folder to default.
   - **Right-click on blank background inside a folder** (e.g. inside `D:\Software` or `D:\Tools`):
     - Click **"批量应用所有子文件夹图标" (Batch set all subfolders)**: Scans and sets icons for all immediate subfolders.
     - Click **"批量还原所有子文件夹图标" (Batch restore all subfolders)**: Reverts all immediate subfolders to default.

> **To uninstall**: Simply double-click `Uninstall-ContextMenu.bat` to completely clean up registry entries.

---

### Method 2: Drag and Drop

Drag and drop one or multiple application folders directly onto `Set-FolderIcon.bat`. The script will process each dropped folder automatically.

---

### Method 3: Interactive Console Menu

Double-click `Set-FolderIcon.bat` (or run `Set-FolderIcon.ps1` in a terminal without parameters) to open the interactive menu:

```text
============================================================
     Windows 文件夹应用图标自动定制工具 (Folder Icon Tool)  
============================================================
 [1] 选择单个文件夹应用图标 (弹窗选择)
 [2] 批量扫描并应用指定目录下的所有子文件夹 (弹窗选择)
 [3] 手动输入文件夹路径处理
 [4] 还原某个文件夹为系统默认图标 (弹窗选择)
 [0] 退出
------------------------------------------------------------
请输入操作选项 [0-4]:
```

---

### Method 4: PowerShell Command Line (CLI)

Run directly from PowerShell terminal or automation workflows:

```powershell
# 1. Customize a single folder
.\Set-FolderIcon.ps1 -Path "D:\Tools\7-Zip"

# 2. Batch process all immediate subfolders under a directory
.\Set-FolderIcon.ps1 -Path "D:\Tools" -AllSubFolders

# 3. Restore a folder to default system icon
.\Set-FolderIcon.ps1 -Path "D:\Tools\7-Zip" -Restore

# 4. Pipeline support
Get-Item "D:\Tools\*" | .\Set-FolderIcon.ps1
```

**Parameters**:

| Parameter | Description |
| :--- | :--- |
| `-Path` | Target folder path(s) (supports multiple paths and pipeline input) |
| `-AllSubFolders` (Alias `-Batch`) | Batch process all first-level subdirectories under `-Path` |
| `-Restore` | Revert target folder(s) to Windows default folder icon |
| `-Force` | Force re-creation of icon configuration |
| `-Quiet` | Silent execution without interactive prompts or pauses |

---

## 🛠️ How It Works

Windows Explorer relies on `desktop.ini` to customize directory appearances. The implementation consists of three key steps:

1. **Config File Generation**:
   Generates a `desktop.ini` inside the target directory:
   ```ini
   [.ShellClassInfo]
   IconResource=App.exe,0
   [ViewState]
   Mode=
   Vid=
   FolderType=Generic
   ```
   > The file is saved in **UTF-16 LE with BOM** to guarantee native support for non-ASCII/Unicode folder names.

2. **Special Windows File Attributes**:
   - Sets `desktop.ini` attributes to `Hidden` + `System`.
   - **Crucial Step**: Sets the folder itself to have the `ReadOnly` attribute. Per Windows Shell design specifications, a directory's `ReadOnly` flag does not prevent modifying files inside; rather, it instructs Windows Explorer to parse `desktop.ini`.

3. **Win32 Shell Cache Notification**:
   - Calls `SHChangeNotify` from `shell32.dll` to send `SHCNE_UPDATEITEM`, `SHCNE_UPDATEDIR`, and `SHCNE_ASSOCCHANGED` notifications, forcing Windows Explorer to redraw without requiring an Explorer restart.

---

## ❓ FAQ & Troubleshooting

### Q1: Why do some folder icons not update immediately?
- Windows Explorer maintains an internal icon cache (`IconCache.db`). While `SHChangeNotify` triggers instant live updates in most cases, occasionally aggressive Explorer caching may delay the visual update.
- Press `F5` inside Explorer, or restart `Windows Explorer` via Task Manager if necessary.

### Q2: Do I need administrator permissions?
- No. `Install-ContextMenu.bat` registers to the current user's registry branch (`HKCU`), so it runs immediately under regular user privileges without UAC prompts.
- To install machine-wide for all users, execute `.\Install-ContextMenu.ps1 -AllUsers` in an elevated administrator PowerShell prompt.

---

## 📄 License

This project is open-source under the [MIT License](LICENSE). Contributions, stars, and pull requests are welcome!