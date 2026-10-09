# Set-FolderIcon

<p align="center">
  <strong>Windows 文件夹应用图标自动定制工具</strong><br>
  Auto Folder Icon Customizer for Windows
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT">
  <img src="https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6.svg" alt="Windows">
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE.svg" alt="PowerShell">
  <img src="https://img.shields.io/badge/Pure%20Script-No%20Third--party%20Deps-brightgreen.svg" alt="Pure Script">
</p>

---

## 📖 简介

在 Windows 电脑上存放各类便携软件、绿色工具箱、开发环境或游戏目录时，默认所有文件夹都是千篇一律的黄色图标，查找极其低效且不美观。

**Set-FolderIcon** 是一款轻量、开源、免安装的 Windows 文件夹图标智能定制脚本：
- 自动扫描目标文件夹内的程序资源，通过启发式评分算法智能挑选最合适的主程序（`.exe`）、图标文件（`.ico`）或快捷方式（`.lnk`）；
- 自动提取并写入标准 Windows `desktop.ini`，并将图标路径设为**相对路径**（移动硬盘、U盘换机拔插不失效）；
- 结合 Win32 原生 API 自动刷新 Windows 资源管理器图标缓存，实现修改后即时生效。

---

## ✨ 核心特性

- 🎯 **智能识别主程序**：
  - 基于 Win32 `ExtractIconEx` 深度探测 PE 文件是否包含有效图标资源。
  - 智能名称相似度匹配、文件体积加权、主程序关键词倾向（`gui` / `client` / `64` / `main` 等）。
  - 自动过滤 `unins000.exe`、`uninstall.exe`、`updater.exe`、`setup.exe`、`crashpad.exe`、守护服务等非主程序干扰。
  - 找不到根目录程序时，自动向下递归检索 2 层子目录，或识别根目录下的 `.lnk` 快捷方式。
- 💾 **绿色便携（相对路径）**：
  - 优先在 `desktop.ini` 中写入目标程序的相对路径（例如 `IconResource=App.exe,0` 或 `IconResource=bin\App.exe,0`）。
  - 拷贝至移动硬盘、重命名上级目录或跨电脑使用，自定义图标依然长期有效！
- ⚡ **无缝右键菜单集成**：
  - 支持一键安装 Windows 资源管理器右键菜单。
  - 选中文件夹右键或在文件夹内部空白处右键，一键应用或还原。
  - 采用当前用户注册机制（HKCU），无需管理员权限即可秒装。
- 🔄 **即时无感刷新**：
  - 调用 Windows Shell `SHChangeNotify` API 广播系统变更，通常无需重启 `explorer.exe`。
- 🛡️ **安全可逆**：
  - 提供一键恢复默认图标功能，自动删除 `desktop.ini` 并解除文件夹系统属性。
- 📦 **零第三方依赖**：
  - 纯原生 PowerShell 5.1+ 与 Windows 批处理实现，开箱即用。

---

## 📁 目录结构

```text
Set-FolderIcon/
├── Set-FolderIcon.ps1          # 核心处理脚本 (PowerShell 5.1+)
├── Set-FolderIcon.bat          # 交互式控制台菜单 / 拖拽处理入口
├── Install-ContextMenu.bat     # 一键安装右键菜单 (双击运行)
├── Install-ContextMenu.ps1     # 右键菜单智能注册逻辑 (自动识别路径)
├── Uninstall-ContextMenu.bat   # 一键卸载右键菜单 (双击运行)
├── Uninstall-ContextMenu.ps1   # 卸载并清理注册表右键菜单
├── Register-ContextMenu.reg    # 注册表模板 (供手动导入参考)
├── Unregister-ContextMenu.reg  # 注册表清理模板 (供手动导入参考)
├── LICENSE                     # MIT 开源许可证
├── .gitignore
└── README.md                   # 项目说明文档
```

---

## 🚀 使用方法

### 方式 1：Windows 资源管理器右键菜单（强烈推荐）

1. 双击运行 `Install-ContextMenu.bat`（无需管理员权限）。
2. 在任意需要美化的文件夹上：
   - **鼠标右键**点击该文件夹 -> 点击 **「应用此文件夹内程序图标」**。
   - 或者进入该文件夹内部，在**空白处右键** -> 点击 **「应用当前文件夹内程序图标」**。
3. 如果需要恢复默认黄色文件夹：
   - 右键点击文件夹 -> **「还原为默认文件夹图标」** 即可。

> **卸载右键菜单**：双击运行 `Uninstall-ContextMenu.bat` 即可完整清除所有右键菜单项。

---

### 方式 2：文件拖拽快捷处理

将任意一个或多个应用程序文件夹直接**鼠标拖拽**到 `Set-FolderIcon.bat` 图标上释放，脚本将自动批量识别并设置图标。

---

### 方式 3：交互式控制台菜单

直接双击运行 `Set-FolderIcon.bat`（或在终端运行 `Set-FolderIcon.ps1`），将出现交互式操作菜单：

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

- 选择 `[2]` 可以弹窗选择一个软件汇总目录（例如 `D:\Tools`），脚本将自动批量处理该目录下所有一级子文件夹。

---

### 方式 4：PowerShell 命令行调用

在终端或自动化脚本中直接调用：

```powershell
# 1. 为指定文件夹设置图标
.\Set-FolderIcon.ps1 -Path "D:\Tools\7-Zip"

# 2. 批量处理指定目录下的所有一级子目录 (-Batch 或 -AllSubFolders)
.\Set-FolderIcon.ps1 -Path "D:\Tools" -AllSubFolders

# 3. 还原指定文件夹为默认系统图标
.\Set-FolderIcon.ps1 -Path "D:\Tools\7-Zip" -Restore

# 4. 支持管道输入批量处理
Get-Item "D:\Tools\*" | .\Set-FolderIcon.ps1
```

**参数说明**：

| 参数 | 说明 |
| :--- | :--- |
| `-Path` | 目标文件夹路径（支持多个路径、管道输入） |
| `-AllSubFolders` (别名 `-Batch`) | 批量扫描并处理该路径下的一级子文件夹 |
| `-Restore` | 还原指定文件夹为 Windows 默认图标 |
| `-Force` | 强制重新生成已存在的图标配置 |
| `-Quiet` | 静默模式运行 |

---

## 🛠️ 技术原理

Windows 资源管理器通过 `desktop.ini` 文件来支持自定义文件夹外观，核心实现分为三步：

1. **识别与生成配置文件**：
   在文件夹根目录下创建 `desktop.ini`：
   ```ini
   [.ShellClassInfo]
   IconResource=App.exe,0
   [ViewState]
   Mode=
   Vid=
   FolderType=Generic
   ```
   > 编码统一采用带有 BOM 的 UTF-16LE，保证包含中文路径时 Windows Shell 也能正常识别。

2. **设置 Windows 特殊文件属性**：
   - 将 `desktop.ini` 设置为 `Hidden`（隐藏）+ `System`（系统）属性。
   - **最关键的一步**：将文件夹自身赋予 `ReadOnly`（只读）属性。根据 Windows Shell 设计规范，文件夹的只读属性并不限制内部文件读写，而是作为“通知资源管理器解析该文件夹内 desktop.ini”的标记位。

3. **Win32 Shell 缓存刷新通知**：
   - 通过 P/Invoke 调用 `shell32.dll` 的 `SHChangeNotify` 函数，发送 `SHCNE_UPDATEITEM`、`SHCNE_UPDATEDIR` 与 `SHCNE_ASSOCCHANGED` 消息，促使 Windows 资源管理器即时刷新该文件夹的显示状态。

---

## ❓ 常见问题 (FAQ)

### Q1：为什么某些文件夹设置后没有立刻变图标？
- Windows 资源管理器存在自身的图标缓存（IconCache）。大部分情况下脚本触发的 `SHChangeNotify` 会即时生效；
- 如果系统缓存特别顽固，可以在资源管理器中按 `F5` 刷新，或者通过任务管理器重启一次 `Windows 资源管理器` 进程即可显示。

### Q2：右键菜单提示权限不足？
- `Install-ContextMenu.bat` 默认写入当前用户的注册表分支（`HKCU`），**普通用户权限即可直接运行**，无需管理员身份。
- 如果需要为本机所有用户全局安装，可以在以管理员身份运行的 PowerShell 窗口中执行：`.\Install-ContextMenu.ps1 -AllUsers`。

---

## 📄 开源许可证

本项目基于 [MIT 许可证](LICENSE) 开源。欢迎 Star、Fork 与提 Issue！