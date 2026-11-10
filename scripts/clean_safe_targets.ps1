$ErrorActionPreference = "SilentlyContinue"
$beforeFree = (Get-PSDrive C).Free
Write-Output ("清理前 C 盘可用空间: {0:N2} GB" -f ($beforeFree / 1GB))

function Remove-SafeTarget {
    param([string]$Path, [string]$Label)
    if (Test-Path -LiteralPath $Path) {
        $size = (Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        if (-not $size) {
            $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
            if ($item -and -not $item.PSIsContainer) { $size = $item.Length }
        }
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path -LiteralPath $Path)) {
            Write-Output ("[已清理] {0:N2} MB | {1} ({2})" -f ($size / 1MB), $Label, $Path)
        } else {
            $remSize = (Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            $freed = [math]::Max(0, ($size - $remSize))
            Write-Output ("[部分清理] 释放 {0:N2} MB (占用/需提权: {1:N2} MB) | {2}" -f ($freed / 1MB), ($remSize / 1MB), $Label)
        }
    }
}

function Remove-OldVersions {
    param([array]$Folders, [string]$GroupLabel)
    $sorted = $Folders | Sort-Object LastWriteTime -Descending
    if ($sorted.Count -gt 1) {
        for ($i = 1; $i -lt $sorted.Count; $i++) {
            $old = $sorted[$i]
            $size = (Get-ChildItem -LiteralPath $old.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            Remove-Item -LiteralPath $old.FullName -Recurse -Force -ErrorAction SilentlyContinue
            if (-not (Test-Path -LiteralPath $old.FullName)) {
                Write-Output ("[已删旧版本] {0:N2} MB | {1} -> {2}" -f ($size / 1MB), $GroupLabel, $old.Name)
            }
        }
    }
}

# 1. VS Code & Cursor C/C++ IntelliSense 数据库缓存 (.BROWSE.VC.DB)
Remove-SafeTarget "$env:LOCALAPPDATA\Microsoft\vscode-cpptools" "VS Code C/C++ 全局符号缓存"
Get-ChildItem -Path "$env:APPDATA\Code\User\workspaceStorage", "$env:APPDATA\Cursor\User\workspaceStorage" -Filter "ms-vscode.cpptools" -Recurse -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-SafeTarget $_.FullName "工作区 C/C++ 符号缓存"
}

# 2. 各类 *-updater 自动更新安装包残留
Get-ChildItem -Path $env:LOCALAPPDATA -Filter "*-updater" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-SafeTarget $_.FullName ("更新包缓存: " + $_.Name)
}

# 3. 常见软件安装包与缓存目录
$safeTargets = @(
    @{ Label = "QQ 安装包缓存"; Path = "$env:APPDATA\QQ\packages" },
    @{ Label = "新版微信更新补丁"; Path = "$env:APPDATA\Tencent\xwechat\update\patch" },
    @{ Label = "腾讯视频应用商店缓存"; Path = "$env:APPDATA\Tencent\QQLiveAppStore" },
    @{ Label = "腾讯视频小游戏缓存 (TCGamer)"; Path = "$env:APPDATA\Tencent\QQLive\TCGamer" },
    @{ Label = "腾讯视频小游戏缓存 (WxMiniGame)"; Path = "$env:APPDATA\Tencent\QQLive\WxMiniGame" },
    @{ Label = "腾讯视频小游戏缓存 (wx_minigame_root_dir)"; Path = "$env:APPDATA\Tencent\QQLive\wx_minigame_root_dir" },
    @{ Label = "VS Code VSIX 缓存"; Path = "$env:APPDATA\Code\CachedExtensionVSIXs" },
    @{ Label = "VS Code Cache"; Path = "$env:APPDATA\Code\Cache" },
    @{ Label = "VS Code CachedData"; Path = "$env:APPDATA\Code\CachedData" },
    @{ Label = "Cursor VSIX 缓存"; Path = "$env:APPDATA\Cursor\CachedExtensionVSIXs" },
    @{ Label = "Cursor Cache"; Path = "$env:APPDATA\Cursor\Cache" },
    @{ Label = "Cursor CachedData"; Path = "$env:APPDATA\Cursor\CachedData" },
    @{ Label = "Chrome 缓存"; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache" },
    @{ Label = "Chrome Code Cache"; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache" },
    @{ Label = "崩溃转储 CrashDumps"; Path = "$env:LOCALAPPDATA\CrashDumps" },
    @{ Label = "用户临时文件 Temp"; Path = "$env:LOCALAPPDATA\Temp" }
)
foreach ($t in $safeTargets) {
    Remove-SafeTarget -Path $t.Path -Label $t.Label
}

# 4. WPS 插件池多版本去重 (保留最新版)
$wpsPool = "$env:APPDATA\kingsoft\wps\addons\pool\win-i386"
if (Test-Path $wpsPool) {
    Get-ChildItem -Path $wpsPool -Directory | Group-Object { ($_.Name -split '_')[0] } | Where-Object { $_.Count -gt 1 } | ForEach-Object {
        Remove-OldVersions -Folders $_.Group -GroupLabel ("WPS 插件: " + $_.Name)
    }
}

# 5. VS Code & Cursor 扩展多版本去重 (保留最新版)
foreach ($extRoot in @("$env:USERPROFILE\.vscode\extensions", "$env:USERPROFILE\.cursor\extensions")) {
    if (Test-Path $extRoot) {
        Get-ChildItem -Path $extRoot -Directory | Group-Object {
            if ($_.Name -match '^([a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+)-\d+\.') { $matches[1].ToLower() } else { $_.Name }
        } | Where-Object { $_.Count -gt 1 } | ForEach-Object {
            Remove-OldVersions -Folders $_.Group -GroupLabel ("编辑器扩展: " + $_.Name)
        }
    }
}

# 6. WebView2 component_crx_cache 清理
Get-ChildItem -Path "$env:USERPROFILE\AppData" -Filter "component_crx_cache" -Recurse -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-SafeTarget -Path $_.FullName -Label "WebView2 component_crx_cache"
}

$afterFree = (Get-PSDrive C).Free
Write-Output ("`n清理后 C 盘可用空间: {0:N2} GB (本次共释放: {1:N2} GB)" -f ($afterFree / 1GB), (($afterFree - $beforeFree) / 1GB))
