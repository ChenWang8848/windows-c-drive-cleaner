param(
    [string]$CzkawkaDir = "d:\Desktop\新建文件夹\Czkawka_GUI",
    [string]$OutputDir = "$env:TEMP\c_drive_scan"
)

$ErrorActionPreference = "SilentlyContinue"
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

Write-Output "=========================================================="
Write-Output "  Step 1: C 盘空间基线检查与 Czkawka 工具准备"
Write-Output "=========================================================="
$drive = Get-PSDrive C
Write-Output ("当前 C 盘状态 -> 已用: {0:N2} GB | 可用: {1:N2} GB" -f ($drive.Used / 1GB), ($drive.Free / 1GB))

$cliPath = Join-Path $CzkawkaDir "czkawka_cli.exe"
if (-not (Test-Path -LiteralPath $cliPath)) {
    Write-Output "未在 $CzkawkaDir 找到 czkawka_cli.exe，正在从 GitHub (https://github.com/qarmin/czkawka) 下载最新版..."
    New-Item -ItemType Directory -Path $CzkawkaDir -Force | Out-Null
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/qarmin/czkawka/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -match "windows_czkawka_gui_gtk.*\.zip" } | Select-Object -First 1
    $zipPath = Join-Path $OutputDir $asset.name
    curl.exe -L -o $zipPath $asset.browser_download_url
    Expand-Archive -Path $zipPath -DestinationPath $CzkawkaDir -Force
}

if (Test-Path -LiteralPath $cliPath) {
    Write-Output "`n=========================================================="
    Write-Output "  Step 2: 运行 Czkawka 重复文件 (>=1MB) 与 Top 40 大文件扫描"
    Write-Output "=========================================================="
    & $cliPath dup -d "C:\" -e "C:\Windows" -m 1048576 -s HASH -t BLAKE3 -p "$OutputDir\dup_1mb.json" -f "$OutputDir\dup_1mb.txt" -N -W
    & $cliPath big -d "C:\" -e "C:\Windows" -n 40 -f "$OutputDir\big_files.txt" -N -W
    Write-Output "扫描结果已保存至: $OutputDir"
}

Write-Output "`n=========================================================="
Write-Output "  Step 3: 常见应用缓存、更新包与冗余目录体积统计"
Write-Output "=========================================================="
function Get-DirSizeMB($p) {
    if (Test-Path -LiteralPath $p) {
        $s = (Get-ChildItem -LiteralPath $p -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        return [math]::Round($s / 1MB, 2)
    }
    return 0
}

$targets = @(
    @{ Name = "VS Code C/C++ 全局符号缓存 (vscode-cpptools)"; Path = "$env:LOCALAPPDATA\Microsoft\vscode-cpptools" },
    @{ Name = "WPS 插件多版本池 (addons\pool\win-i386)"; Path = "$env:APPDATA\kingsoft\wps\addons\pool\win-i386" },
    @{ Name = "新版微信插件池 (xwechat\XPlugin\Plugins)"; Path = "$env:APPDATA\Tencent\xwechat\XPlugin\Plugins" },
    @{ Name = "新版微信更新补丁 (xwechat\update\patch)"; Path = "$env:APPDATA\Tencent\xwechat\update\patch" },
    @{ Name = "旧版微信插件池 (WeChat\XPlugin)"; Path = "$env:APPDATA\Tencent\WeChat\XPlugin" },
    @{ Name = "QQ 安装包缓存 (Roaming\QQ\packages)"; Path = "$env:APPDATA\QQ\packages" },
    @{ Name = "腾讯视频缓存 (Roaming\Tencent\QQLive)"; Path = "$env:APPDATA\Tencent\QQLive" },
    @{ Name = "腾讯视频应用中心缓存 (QQLiveAppStore)"; Path = "$env:APPDATA\Tencent\QQLiveAppStore" },
    @{ Name = "豆包/飞书 沙盒与组件缓存 (Roaming\LarkShell)"; Path = "$env:APPDATA\LarkShell" },
    @{ Name = "Cursor 扩展包缓存 (CachedExtensionVSIXs)"; Path = "$env:APPDATA\Cursor\CachedExtensionVSIXs" },
    @{ Name = "VS Code 扩展包缓存 (CachedExtensionVSIXs)"; Path = "$env:APPDATA\Code\CachedExtensionVSIXs" },
    @{ Name = "Chrome 浏览器缓存 (Default\Cache)"; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache" },
    @{ Name = "Edge 浏览器缓存 (Default\Cache)"; Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache" },
    @{ Name = "用户临时目录 (AppData\Local\Temp)"; Path = "$env:LOCALAPPDATA\Temp" },
    @{ Name = "崩溃转储目录 (AppData\Local\CrashDumps)"; Path = "$env:LOCALAPPDATA\CrashDumps" },
    @{ Name = "pip 缓存"; Path = "$env:LOCALAPPDATA\pip\cache" },
    @{ Name = "uv 缓存"; Path = "$env:LOCALAPPDATA\uv\cache" },
    @{ Name = "npm 缓存 (Local)"; Path = "$env:LOCALAPPDATA\npm-cache" },
    @{ Name = "npm 缓存 (Roaming)"; Path = "$env:APPDATA\npm-cache" },
    @{ Name = "荣耀电脑管家驱动更新下载缓存"; Path = "C:\ProgramData\Comms\PCManager\DriverUpgrade\Update\Downloaded" },
    @{ Name = "荣耀 YOYO 助理更新下载缓存"; Path = "C:\ProgramData\Comms\Upgrade\Update\Downloaded" }
)

$report = foreach ($t in $targets) {
    $mb = Get-DirSizeMB $t.Path
    if ($mb -gt 5) {
        [PSCustomObject]@{
            Category = $t.Name
            SizeMB   = $mb
            SizeGB   = [math]::Round($mb / 1024, 2)
            Path     = $t.Path
        }
    }
}
$report | Sort-Object SizeMB -Descending | Format-Table -AutoSize

# 扫描所有 *-updater 目录
Write-Output "=== 软件自动更新器残留 (*-updater) ==="
Get-ChildItem -Path $env:LOCALAPPDATA -Filter "*-updater" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $mb = Get-DirSizeMB $_.FullName
    if ($mb -gt 5) {
        [PSCustomObject]@{ Updater = $_.Name; SizeMB = $mb; Path = $_.FullName }
    }
} | Sort-Object SizeMB -Descending | Format-Table -AutoSize
