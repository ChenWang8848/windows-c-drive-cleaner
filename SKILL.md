---
name: windows-c-drive-cleaner
description: >-
  Use this skill when the user asks to scan, analyze, or clean up the Windows C: drive,
  free up disk space, find duplicate files or large files, or run Czkawka disk cleanup.
---

# Windows C盘深度分析与安全清理 (Windows C-Drive Cleaner Skill)

本 Skill 结合 GitHub 顶级开源磁盘清理工具 **[qarmin/czkawka](https://github.com/qarmin/czkawka)** 与定制化 PowerShell 诊断清理脚本，通过标准化的 **“四步安全清理法”** 为 Windows C 盘释放空间，杜绝盲目删除系统文件或软件核心运行库。

---

## 🔗 核心开源工具参考 (GitHub)

1. **[qarmin/czkawka](https://github.com/qarmin/czkawka)** (~35k+ Stars)
   * **用途**：基于 Rust 的极速重复文件 (`dup`)、最大文件 (`big`)、临时文件与空文件夹扫描引擎（含命令行 `czkawka_cli.exe`、新一代 GUI `krokiet.exe` 和经典 GUI `czkawka_gui.exe`）。
   * **Releases 下载地址**：`https://github.com/qarmin/czkawka/releases/latest`
2. **[Chuyu-Team/Dism-Multi-language](https://github.com/Chuyu-Team/Dism-Multi-language)** (Dism++, ~20.7k+ Stars)
   * **用途**：清理 Windows 更新备份 (`WinSxS`)、过期驱动与系统底层组件。
3. **[Klocman/Bulk-Crap-Uninstaller](https://github.com/Klocman/Bulk-Crap-Uninstaller)** (~20k+ Stars)
   * **用途**：批量卸载不用软件并深度清除注册表与 `AppData` 孤立残留。
4. **[ChenAI-TGF/windows-c-drive-cleaner](https://github.com/ChenAI-TGF/windows-c-drive-cleaner)** & **[hello-qingshan/skill-c-cleaner](https://github.com/hello-qingshan/skill-c-cleaner)**
   * **用途**：开源社区 AI Agent C 盘安全清理白名单与分级决策参考。

---

## 🚀 标准执行流程（四步法）

当用户要求清理 C 盘、查找重复文件或释放磁盘空间时，**严格按以下四个步骤执行**：

### 第一步：检查并准备 Czkawka 工具（Download & Setup）

1. 检查本地是否已存在 `czkawka_cli.exe`（例如在工作区 `Czkawka_GUI\czkawka_cli.exe` 或工具缓存目录）。
2. 如果尚未下载，通过 GitHub API 获取 **[qarmin/czkawka](https://github.com/qarmin/czkawka)** 最新 Release 并自动下载解压：
   ```powershell
   $release = Invoke-RestMethod -Uri "https://api.github.com/repos/qarmin/czkawka/releases/latest"
   $asset = $release.assets | Where-Object { $_.name -match "windows_czkawka_gui_gtk.*\.zip" } | Select-Object -First 1
   curl.exe -L -o "czkawka_windows.zip" $asset.browser_download_url
   Expand-Archive -Path "czkawka_windows.zip" -DestinationPath ".\Czkawka_GUI" -Force
   ```
   *(注：GUI 交互推荐使用解压目录下的 `krokiet.exe`；在 GUI 中勾选重复文件时，应点击底部 **“选择 (Select)” -> “选择除最旧/最新之外的所有项 (Select all except oldest/newest)”**，切勿直接点击“全选”。)*

---

### 第二步：执行全盘只读扫描（Read-Only Scan）

运行本 Skill 内置的扫描脚本 [scan_c_drive.ps1](./scripts/scan_c_drive.ps1)，或者分步调用以下命令（**此阶段严禁删除任何文件**）：

1. **查看当前 C 盘容量基线**：记录清理前的可用空间 (`Free GB`)。
2. **调用 `czkawka_cli.exe dup` 扫描重复文件（≥1MB，排除 `C:\Windows`）**：
   ```powershell
   & ".\Czkawka_GUI\czkawka_cli.exe" dup -d "C:\" -e "C:\Windows" -m 1048576 -s HASH -t BLAKE3 -p "dup_1mb.json" -f "dup_1mb.txt" -N -W
   ```
3. **调用 `czkawka_cli.exe big` 扫描前 40 个最大单文件（排除 `C:\Windows`）**：
   ```powershell
   & ".\Czkawka_GUI\czkawka_cli.exe" big -d "C:\" -e "C:\Windows" -n 40 -f "big_files.txt" -N -W
   ```
4. **扫描常见高优缓存目录大小**：统计 `AppData` 下的开发缓存（`vscode-cpptools`、`npm`、`pip`、`uv`）、更新器缓存（`*-updater`）、办公/社交软件多版本冗余（WPS `addons\pool`、微信 `XPlugin`、QQ `libcef`、豆包/飞书 `LarkShell`）等。

---

### 第三步：三级风险分类与汇报确认（Analyze & Confirm）

将扫描结果按以下 **三级安全标准** 分类展示给用户，**必须等待用户明确同意后才能进入第四步**：

* 🟢 **第一梯队（极安全 - 纯缓存与更新安装包，强烈推荐清理）**
  * **VS Code / Cursor C/C++ 符号数据库缓存**：`AppData\Local\Microsoft\vscode-cpptools` 及 `workspaceStorage\*\ms-vscode.cpptools` 下的 `.BROWSE.VC.DB`（动辄数 GB，删后按需自动重建）。
  * **各类软件残留更新包 (`*-updater` / `Downloaded Installations`)**：如 `unityhub-updater`、`obsidian-updater`、`pcsuite-updater`、`qoder-updater`、`antigravity-updater`、QQNT 历史 `.zip` 更新包、微信 `update\patch`、C 盘根目录的 `C:\National Instruments Downloads` 等。
  * **软件与扩展多版本冗余（保留最新版，清理历史旧版）**：
    * WPS 插件池：`AppData\Roaming\kingsoft\wps\addons\pool\win-i386` 下同名前缀的旧版本目录（如 `billfish`、`openvino`）。
    * 微信/QQ 插件与内核：`WeChat\XPlugin\Plugins`、`xwechat\XPlugin\Plugins`、QQ `libcef` 下的旧版本号目录。
    * VS Code / Cursor 扩展：`.vscode\extensions` 与 `.cursor\extensions` 下同一插件的旧版本目录，以及 `CachedExtensionVSIXs`。
  * **浏览器与 WebView2 缓存**：各应用下的 `component_crx_cache`、Chrome/Edge/Cursor `Cache` & `Code Cache`、腾讯视频内置小游戏缓存 (`QQLiveAppStore` / `TCGamer` / `WxMiniGame`)、系统 `Temp` 与 `CrashDumps`。

* 🟡 **第二梯队（需确认 - 旧版软件遗留或沙盒/休眠文件）**
  * 旧版微信 3.x (`Roaming\Tencent\WeChat`) / 旧版 QQ 9.x (`Local\Tencent\QQGuild`、`qq-play`)（当用户已升级至新版微信 4.x `xwechat` 和 `QQNT` 时可清）。
  * 豆包 / 飞书本地沙盒缓存 (`AppData\Roaming\LarkShell\aha`)。
  * Windows 休眠文件 `C:\hiberfil.sys`（可通过管理员命令 `powercfg /h /type reduced` 缩减一半或 `powercfg -h off` 关闭）。

* 🔴 **第三梯队（高危禁区 - 严禁作为重复文件删除）**
  * ❌ `C:\Windows`（含 `WinSxS`、`System32`、`Installer`）
  * ❌ `C:\ProgramData\Microsoft\Windows Defender\Platform\...`（Defender 引擎文件）
  * ❌ `C:\Program Files` 与 `C:\Program Files (x86)` 下不同软件各自携带的同名运行库（如 `icudtl.dat`、`msedge.dll`、`openvino_intel_cpu_plugin.dll`、`libFFmpeg32.dll`）。虽然哈希值相同，但删掉会导致对应软件崩溃无法启动！

---

### 第四步：精准执行清理与复盘报告（Execute & Verify）

1. 用户确认后，运行内置清理脚本 [clean_safe_targets.ps1](./scripts/clean_safe_targets.ps1) 或针对用户勾选的梯队执行清理。
2. **多版本目录清理铁律**：按版本号或修改时间降序排列，**始终保留最新的一份 (`$sorted[0]`)**，仅删除其余旧版本。
3. **管理员权限目录处理**：对于 `C:\ProgramData\Comms\...\Downloaded`（荣耀电脑管家/YOYO 助理驱动更新包）、`GoogleUpdater\crx_cache`、`EdgeUpdate\Download` 等受 UAC 保护的缓存目录，若普通权限无法删除，生成一行标准的管理员 PowerShell 命令供用户复制执行。
4. **输出复盘报告**：对比清理前后的 C 盘可用空间 (`Free GB`)，以表格形式汇报各分类实际释放的 MB/GB 数。
