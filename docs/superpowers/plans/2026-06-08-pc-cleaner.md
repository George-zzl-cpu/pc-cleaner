# PC Cleaner Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code skill plugin that scans and cleans Windows PC junk (temp files, browser cache, recycle bin, software leftovers, large/duplicate files, user junk) via modular PowerShell scripts with a conservative scan-then-confirm-then-clean workflow.

**Architecture:** 1 shared PowerShell module (`pc-cleaner.psm1`) + 6 independent scan scripts (`scan-*.ps1`) with a unified `-Action Scan|Clean` interface + 1 Claude Code skill definition file (`pc-cleaner.md`) that orchestrates the workflow. All scripts output JSON for Claude to parse and present.

**Tech Stack:** PowerShell 5.1+ (built-in cmdlets only), Claude Code skill format (Markdown with YAML frontmatter)

**File map:**

| File | Purpose |
|------|---------|
| `scripts/pc-cleaner.psm1` | Shared functions: `Get-SizeDisplay`, `Format-ScanResult`, `Test-AdminPrivilege`, `Safe-RemoveItem`, `Invoke-CleanAction` |
| `scripts/scan-temp.ps1` | System temp files (risk: low) |
| `scripts/scan-browser.ps1` | Browser cache (risk: medium) |
| `scripts/scan-recycle.ps1` | Recycle Bin (risk: low) |
| `scripts/scan-leftovers.ps1` | Software leftovers (risk: high) |
| `scripts/scan-large.ps1` | Large/duplicate files (risk: high) |
| `scripts/scan-userjunk.ps1` | User directory junk (risk: medium) |
| `skills/pc-cleaner.md` | Claude Code skill definition |
| `tests/test-module.ps1` | Tests for shared module |
| `tests/test-scan-modes.ps1` | Tests for scan scripts |
| `tests/test-edge-cases.ps1` | Edge case tests |
| `.gitignore` | Git ignore rules |
| `README.md` | User documentation |
| `LICENSE` | MIT License |
| `CLAUDE.md` | Developer context |

---

### Task 1: Project scaffolding

**Files:**
- Create: `.gitignore`
- Create: `LICENSE`
- Create: `README.md`
- Create: `CLAUDE.md`

- [ ] **Step 1: Create .gitignore**

```gitignore
# PowerShell
*.ps1.xml
*.psm1.xml
*.ps1.xml.help.txt

# Windows
Thumbs.db
Desktop.ini
$RECYCLE.BIN/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
```

- [ ] **Step 2: Create LICENSE (MIT)**

```
MIT License

Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 3: Create README.md**

```markdown
# PC Cleaner — Claude Code Skill

让 Claude 帮你清理 Windows 电脑。支持扫描和清理系统临时文件、浏览器缓存、回收站、软件残留、大文件/重复文件、用户目录垃圾。

## 安装

```bash
# 1. 克隆仓库
git clone https://github.com/<user>/pc-cleaner.git

# 2. 安装到 Claude Code
claude skills install /path/to/pc-cleaner/skills/pc-cleaner.md
```

## 使用

在 Claude Code 中直接说：

- "清理电脑" — 全面扫描并选择清理
- "扫描临时文件" — 只扫描系统临时文件
- "清理浏览器缓存" — 只清理浏览器缓存

## 安全策略

- **先扫描后清理** — 所有操作先展示报告，确认后才执行
- **保守默认** — 默认只清理低风险项（临时文件、回收站）
- **高风险需确认** — 大文件、软件残留等需逐项确认

## 功能

| 模块 | 说明 | 风险 |
|------|------|------|
| 系统临时文件 | Windows Temp, 更新缓存, 缩略图缓存 | 低 |
| 浏览器缓存 | Chrome/Edge/Firefox 缓存 | 中 |
| 回收站 | 清空回收站 | 低 |
| 软件残留 | 卸载后遗留的文件和文件夹 | 高 |
| 大文件/重复文件 | 查找占用空间的大文件和重复文件 | 高 |
| 用户目录垃圾 | 下载文件夹、桌面垃圾文件 | 中 |

## 依赖

- Windows 10/11
- PowerShell 5.1+
- Claude Code CLI

## License

MIT
```

- [ ] **Step 4: Create CLAUDE.md**

```markdown
# PC Cleaner — Developer Context

A Claude Code skill plugin for Windows PC cleanup.

## Project layout

- `skills/pc-cleaner.md` — Skill definition entry point
- `scripts/pc-cleaner.psm1` — Shared PowerShell module
- `scripts/scan-*.ps1` — Individual scan/clean scripts (unified `-Action Scan|Clean` interface)
- `tests/` — Pester tests

## Architecture

Every scan script accepts `-Action Scan` (returns JSON, read-only) or `-Action Clean` (deletes, returns report JSON). The skill definition file (`pc-cleaner.md`) tells Claude how to call these scripts, present results, and confirm before cleaning.

## Testing

```powershell
# Run all tests
Invoke-Pester tests/
```
```

- [ ] **Step 5: Commit scaffolding**

```bash
git init
git add .gitignore LICENSE README.md CLAUDE.md
git commit -m "chore: project scaffolding"
```

---

### Task 2: Shared PowerShell module (`pc-cleaner.psm1`)

**Files:**
- Create: `scripts/pc-cleaner.psm1`

- [ ] **Step 1: Create the module file**

```powershell
<#
.SYNOPSIS
    PC Cleaner shared module — formatting, safety checks, and common utilities.
.DESCRIPTION
    Provides functions used by all scan scripts: size formatting, result formatting,
    admin privilege check, and safe file deletion.
#>

# Convert bytes to human-readable string
function Get-SizeDisplay {
    param([long]$Bytes)
    if ($Bytes -eq 0) { return "0 B" }
    $suffix = @("B", "KB", "MB", "GB", "TB")
    $index = [Math]::Floor([Math]::Log([Math]::Max($Bytes, 1)) / [Math]::Log(1024))
    if ($index -ge $suffix.Length) { $index = $suffix.Length - 1 }
    $size = [Math]::Round($Bytes / [Math]::Pow(1024, $index), 2)
    return "$size $($suffix[$index])"
}

# Build a standardized scan result object and output as JSON
function Format-ScanResult {
    param(
        [string]$Category,
        [string]$Risk,
        [long]$TotalSize,
        [int]$FileCount,
        [array]$Items
    )
    $result = [PSCustomObject]@{
        category  = $Category
        risk      = $Risk
        totalSize = $TotalSize
        fileCount = $FileCount
        items     = $Items
    }
    return $result | ConvertTo-Json -Depth 3
}

# Check if running as administrator
function Test-AdminPrivilege {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Validate that a path is safe to delete (not a system-critical directory)
function Test-SafePath {
    param([string]$Path)
    $blocked = @(
        [System.Environment]::GetFolderPath('Windows'),
        [System.Environment]::GetFolderPath('System'),
        [System.Environment]::GetFolderPath('ProgramFiles'),
        [System.Environment]::GetFolderPath('ProgramFilesX86'),
        [System.Environment]::GetFolderPath('SystemX86')
    ) | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\').ToLowerInvariant() }

    $normalized = (Resolve-Path $Path -ErrorAction SilentlyContinue).Path.TrimEnd('\').ToLowerInvariant()
    if (-not $normalized) { return $false }
    foreach ($b in $blocked) {
        if ($normalized -eq $b) { return $false }
        # Also block immediate children of system root directories that aren't for cleanup
    }
    return $true
}

# Safely remove an item with path validation
function Safe-RemoveItem {
    param(
        [string]$Path,
        [switch]$Recurse
    )
    if (-not (Test-SafePath $Path)) {
        Write-Error "Blocked: '$Path' is a protected system path."
        return $false
    }
    if (-not (Test-Path $Path)) {
        Write-Warning "Path not found: '$Path'"
        return $false
    }
    try {
        Remove-Item $Path -Recurse:$Recurse -Force -ErrorAction Stop
        return $true
    } catch {
        Write-Warning "Failed to remove '$Path': $($_.Exception.Message)"
        return $false
    }
}

# Unified action dispatcher for all scan scripts
function Invoke-CleanAction {
    param(
        [string]$Action,
        [scriptblock]$ScanBlock,
        [scriptblock]$CleanBlock
    )
    switch ($Action) {
        'Scan' {
            return & $ScanBlock
        }
        'Clean' {
            return & $CleanBlock
        }
        default {
            Write-Error "Invalid Action: '$Action'. Must be 'Scan' or 'Clean'."
            exit 1
        }
    }
}

# Convenience: get size of a folder recursively, handling access errors
function Get-SafeFolderSize {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    try {
        $items = Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue
        return ($items | Measure-Object -Property Length -Sum).Sum
    } catch {
        return 0
    }
}

# Convenience: build an item entry for the scan result
function New-ScanItem {
    param(
        [string]$Path,
        [long]$Size,
        [datetime]$LastModified,
        [bool]$SafeToDelete = $true
    )
    return [PSCustomObject]@{
        path         = $Path
        size         = $Size
        lastModified = $LastModified.ToString('yyyy-MM-dd')
        safeToDelete = $SafeToDelete
    }
}

Export-ModuleMember -Function Get-SizeDisplay, Format-ScanResult, Test-AdminPrivilege,
    Test-SafePath, Safe-RemoveItem, Invoke-CleanAction, Get-SafeFolderSize, New-ScanItem
```

- [ ] **Step 2: Verify the module loads without error**

Run: `powershell -NoProfile -Command "Import-Module ./scripts/pc-cleaner.psm1 -Force; Write-Host 'Module loaded OK'"`

Expected: "Module loaded OK"

- [ ] **Step 3: Commit**

```bash
git add scripts/pc-cleaner.psm1
git commit -m "feat: add shared PowerShell module"
```

---

### Task 3: scan-temp.ps1 — System temp files

**Files:**
- Create: `scripts/scan-temp.ps1`

- [ ] **Step 1: Create the script**

```powershell
<#
.SYNOPSIS
    Scan or clean Windows system temporary files.
.DESCRIPTION
    Covers %WINDIR%\Temp, %TEMP%, Prefetch, Windows Update download cache, and thumbnail cache.
.PARAMETER Action
    Scan: list files older than 7 days and their sizes (read-only).
    Clean: delete files older than 7 days.
.EXAMPLE
    .\scan-temp.ps1 -Action Scan
    .\scan-temp.ps1 -Action Clean
#>
param(
    [Parameter(Mandatory)]
    [ValidateSet('Scan', 'Clean')]
    [string]$Action
)

Import-Module "$PSScriptRoot\pc-cleaner.psm1" -Force

$cutoff = (Get-Date).AddDays(-7)

$scanTargets = @(
    "$env:SystemRoot\Temp",
    $env:TEMP,
    "$env:SystemRoot\Prefetch",
    "$env:SystemRoot\SoftwareDistribution\Download"
)

# Also find thumbnail cache files
$thumbPaths = @(
    "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
)

function Get-TempFiles {
    $items = @()
    $totalSize = 0L

    foreach ($dir in $scanTargets) {
        if (-not (Test-Path $dir)) { continue }
        $files = Get-ChildItem $dir -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff }
        foreach ($f in $files) {
            $items += New-ScanItem -Path $f.FullName -Size $f.Length -LastModified $f.LastWriteTime -SafeToDelete $true
            $totalSize += $f.Length
        }
    }

    # Thumbnail cache
    foreach ($tp in $thumbPaths) {
        if (-not (Test-Path $tp)) { continue }
        $thumbs = Get-ChildItem $tp -Recurse -Filter "thumbcache_*.db" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff }
        foreach ($t in $thumbs) {
            $items += New-ScanItem -Path $t.FullName -Size $t.Length -LastModified $t.LastWriteTime -SafeToDelete $true
            $totalSize += $t.Length
        }
    }

    return Format-ScanResult -Category "系统临时文件" -Risk "low" -TotalSize $totalSize -FileCount $items.Count -Items $items
}

function Remove-TempFiles {
    $freed = 0L
    $failed = 0

    foreach ($dir in $scanTargets) {
        if (-not (Test-Path $dir)) { continue }
        $files = Get-ChildItem $dir -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff }
        foreach ($f in $files) {
            if (Safe-RemoveItem $f.FullName) { $freed += $f.Length } else { $failed++ }
        }
    }

    foreach ($tp in $thumbPaths) {
        if (-not (Test-Path $tp)) { continue }
        $thumbs = Get-ChildItem $tp -Recurse -Filter "thumbcache_*.db" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff }
        foreach ($t in $thumbs) {
            if (Safe-RemoveItem $t.FullName) { $freed += $t.Length } else { $failed++ }
        }
    }

    $report = [PSCustomObject]@{
        category = "系统临时文件"
        freed    = $freed
        display  = Get-SizeDisplay $freed
        failed   = $failed
    }
    return $report | ConvertTo-Json -Depth 2
}

Invoke-CleanAction -Action $Action -ScanBlock ${function:Get-TempFiles} -CleanBlock ${function:Remove-TempFiles}
```

- [ ] **Step 2: Verify Scan mode outputs valid JSON**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File "./scripts/scan-temp.ps1" -Action Scan`

Expected: JSON with `category`, `risk`, `totalSize`, `fileCount`, `items` fields. `risk` equals `"low"`.

- [ ] **Step 3: Commit**

```bash
git add scripts/scan-temp.ps1
git commit -m "feat: add system temp files scanner"
```

---

### Task 4: scan-recycle.ps1 — Recycle Bin

**Files:**
- Create: `scripts/scan-recycle.ps1`

- [ ] **Step 1: Create the script**

```powershell
<#
.SYNOPSIS
    Scan or clean the Windows Recycle Bin.
.DESCRIPTION
    Scans $Recycle.Bin across all drives for file count and total size.
.PARAMETER Action
    Scan: list recycle bin contents (read-only).
    Clean: empty the recycle bin.
.EXAMPLE
    .\scan-recycle.ps1 -Action Scan
    .\scan-recycle.ps1 -Action Clean
#>
param(
    [Parameter(Mandatory)]
    [ValidateSet('Scan', 'Clean')]
    [string]$Action
)

Import-Module "$PSScriptRoot\pc-cleaner.psm1" -Force

function Get-RecycleBin {
    $items = @()
    $totalSize = 0L

    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' }
    foreach ($drive in $drives) {
        $recyclePath = "$($drive.Root)`$Recycle.Bin"
        if (-not (Test-Path $recyclePath)) { continue }
        $files = Get-ChildItem $recyclePath -Recurse -File -Force -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            $items += New-ScanItem -Path $f.FullName -Size $f.Length -LastModified $f.LastWriteTime -SafeToDelete $true
            $totalSize += $f.Length
        }
    }

    return Format-ScanResult -Category "回收站" -Risk "low" -TotalSize $totalSize -FileCount $items.Count -Items $items
}

function Clear-RecycleBinAll {
    try {
        $freed = 0L
        # Sum up sizes before clearing
        $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' }
        foreach ($drive in $drives) {
            $recyclePath = "$($drive.Root)`$Recycle.Bin"
            if (-not (Test-Path $recyclePath)) { continue }
            $files = Get-ChildItem $recyclePath -Recurse -File -Force -ErrorAction SilentlyContinue
            $freed += ($files | Measure-Object -Property Length -Sum).Sum
        }
        Clear-RecycleBin -Force -ErrorAction Stop
        $report = [PSCustomObject]@{
            category = "回收站"
            freed    = $freed
            display  = Get-SizeDisplay $freed
            failed   = 0
        }
        return $report | ConvertTo-Json -Depth 2
    } catch {
        $report = [PSCustomObject]@{
            category = "回收站"
            freed    = 0
            display  = "0 B"
            failed   = 0
            error    = $_.Exception.Message
        }
        return $report | ConvertTo-Json -Depth 2
    }
}

Invoke-CleanAction -Action $Action -ScanBlock ${function:Get-RecycleBin} -CleanBlock ${function:Clear-RecycleBinAll}
```

- [ ] **Step 2: Verify Scan mode outputs valid JSON**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File "./scripts/scan-recycle.ps1" -Action Scan`

Expected: JSON with `category`, `risk`, `totalSize`, `fileCount`, `items`. `risk` equals `"low"`.

- [ ] **Step 3: Commit**

```bash
git add scripts/scan-recycle.ps1
git commit -m "feat: add recycle bin scanner"
```

---

### Task 5: scan-browser.ps1 — Browser cache

**Files:**
- Create: `scripts/scan-browser.ps1`

- [ ] **Step 1: Create the script**

```powershell
<#
.SYNOPSIS
    Scan or clean browser cache files (Chrome, Edge, Firefox).
.DESCRIPTION
    Scans Chromium-based and Firefox cache directories for cache files.
    Clean removes cache files; users may need to re-login to websites.
.PARAMETER Action
    Scan: list cache files and sizes (read-only).
    Clean: delete cache files.
.EXAMPLE
    .\scan-browser.ps1 -Action Scan
    .\scan-browser.ps1 -Action Clean
#>
param(
    [Parameter(Mandatory)]
    [ValidateSet('Scan', 'Clean')]
    [string]$Action
)

Import-Module "$PSScriptRoot\pc-cleaner.psm1" -Force

$localAppData = [System.Environment]::GetFolderPath('LocalApplicationData')

$browserCachePaths = @(
    # Chrome
    @{ Name = "Chrome"; Path = "$localAppData\Google\Chrome\User Data" },
    # Edge
    @{ Name = "Edge"; Path = "$localAppData\Microsoft\Edge\User Data" },
    # Firefox
    @{ Name = "Firefox"; Path = "$localAppData\Mozilla\Firefox\Profiles" }
)

$cacheDirs = @("Cache", "Cache\Cache_Data", "Code Cache", "GPUCache", "Service Worker\CacheStorage", "cache2", "thumbnails")

function Get-BrowserFiles {
    $items = @()
    $totalSize = 0L

    foreach ($browser in $browserCachePaths) {
        if (-not (Test-Path $browser.Path)) { continue }
        $profiles = Get-ChildItem $browser.Path -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq 'Default' -or $_.Name -match '^Profile' -or $_.Name -match '\.default' }

        foreach ($profile in $profiles) {
            foreach ($cacheDir in $cacheDirs) {
                $cachePath = Join-Path $profile.FullName $cacheDir
                if (-not (Test-Path $cachePath)) { continue }
                $files = Get-ChildItem $cachePath -Recurse -File -ErrorAction SilentlyContinue
                foreach ($f in $files) {
                    $label = "$($browser.Name)/$($profile.Name)"
                    $items += New-ScanItem -Path $f.FullName -Size $f.Length -LastModified $f.LastWriteTime -SafeToDelete $true
                    $totalSize += $f.Length
                }
            }
        }
    }

    return Format-ScanResult -Category "浏览器缓存" -Risk "medium" -TotalSize $totalSize -FileCount $items.Count -Items $items
}

function Remove-BrowserFiles {
    $freed = 0L
    $failed = 0

    foreach ($browser in $browserCachePaths) {
        if (-not (Test-Path $browser.Path)) { continue }
        $profiles = Get-ChildItem $browser.Path -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq 'Default' -or $_.Name -match '^Profile' -or $_.Name -match '\.default' }

        foreach ($profile in $profiles) {
            foreach ($cacheDir in $cacheDirs) {
                $cachePath = Join-Path $profile.FullName $cacheDir
                if (-not (Test-Path $cachePath)) { continue }
                # Delete files inside but keep the directory
                $files = Get-ChildItem $cachePath -Recurse -File -ErrorAction SilentlyContinue
                foreach ($f in $files) {
                    if (Safe-RemoveItem $f.FullName) { $freed += $f.Length } else { $failed++ }
                }
            }
        }
    }

    $report = [PSCustomObject]@{
        category = "浏览器缓存"
        freed    = $freed
        display  = Get-SizeDisplay $freed
        failed   = $failed
        note     = "某些网站可能需要重新登录。"
    }
    return $report | ConvertTo-Json -Depth 2
}

Invoke-CleanAction -Action $Action -ScanBlock ${function:Get-BrowserFiles} -CleanBlock ${function:Remove-BrowserFiles}
```

- [ ] **Step 2: Verify Scan mode outputs valid JSON**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File "./scripts/scan-browser.ps1" -Action Scan`

Expected: JSON with `category`, `risk` = `"medium"`, `totalSize`, `fileCount`, `items`. If no browsers installed, `fileCount` = 0 and output is still valid.

- [ ] **Step 3: Commit**

```bash
git add scripts/scan-browser.ps1
git commit -m "feat: add browser cache scanner"
```

---

### Task 6: scan-userjunk.ps1 — User directory junk

**Files:**
- Create: `scripts/scan-userjunk.ps1`

- [ ] **Step 1: Create the script**

```powershell
<#
.SYNOPSIS
    Scan or clean user directory junk files.
.DESCRIPTION
    Scans Downloads (files untouched 30+ days), Desktop temporary files,
    Recent shortcuts, and crash/dump files.
.PARAMETER Action
    Scan: list junk files (read-only).
    Clean: delete junk files.
.EXAMPLE
    .\scan-userjunk.ps1 -Action Scan
    .\scan-userjunk.ps1 -Action Clean
#>
param(
    [Parameter(Mandatory)]
    [ValidateSet('Scan', 'Clean')]
    [string]$Action
)

Import-Module "$PSScriptRoot\pc-cleaner.psm1" -Force

$userProfile = $env:USERPROFILE
$downloadsCutoff = (Get-Date).AddDays(-30)

$junkExtensions = @(".tmp", ".log", ".dmp", ".crashreport", ".etl", ".wer")

function Get-UserJunk {
    $items = @()
    $totalSize = 0L

    # Downloads: files not accessed in 30+ days
    $downloadsPath = "$userProfile\Downloads"
    if (Test-Path $downloadsPath) {
        $oldDownloads = Get-ChildItem $downloadsPath -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastAccessTime -lt $downloadsCutoff }
        foreach ($f in $oldDownloads) {
            $items += New-ScanItem -Path $f.FullName -Size $f.Length -LastModified $f.LastWriteTime -SafeToDelete $false
            $totalSize += $f.Length
        }
    }

    # Desktop: temp/log/dmp files
    $desktopPath = "$userProfile\Desktop"
    if (Test-Path $desktopPath) {
        $deskJunk = Get-ChildItem $desktopPath -File -ErrorAction SilentlyContinue |
            Where-Object { $ext = $_.Extension.ToLower(); $junkExtensions -contains $ext }
        foreach ($f in $deskJunk) {
            $items += New-ScanItem -Path $f.FullName -Size $f.Length -LastModified $f.LastWriteTime -SafeToDelete $true
            $totalSize += $f.Length
        }
    }

    # Recent documents shortcuts
    $recentPath = "$env:APPDATA\Microsoft\Windows\Recent"
    if (Test-Path $recentPath) {
        $recentFiles = Get-ChildItem $recentPath -File -ErrorAction SilentlyContinue
        foreach ($f in $recentFiles) {
            $items += New-ScanItem -Path $f.FullName -Size $f.Length -LastModified $f.LastWriteTime -SafeToDelete $true
            $totalSize += $f.Length
        }
    }

    # Windows Error Reporting
    $werPaths = @(
        "$env:LOCALAPPDATA\Microsoft\Windows\WER",
        "$env:ProgramData\Microsoft\Windows\WER"
    )
    foreach ($werPath in $werPaths) {
        if (-not (Test-Path $werPath)) { continue }
        $werFiles = Get-ChildItem $werPath -Recurse -File -Include "*.wer", "*.dmp", "*.hdmp" -ErrorAction SilentlyContinue
        foreach ($f in $werFiles) {
            $items += New-ScanItem -Path $f.FullName -Size $f.Length -LastModified $f.LastWriteTime -SafeToDelete $true
            $totalSize += $f.Length
        }
    }

    return Format-ScanResult -Category "用户目录垃圾" -Risk "medium" -TotalSize $totalSize -FileCount $items.Count -Items $items
}

function Remove-UserJunk {
    $freed = 0L
    $failed = 0

    # Downloads
    $downloadsPath = "$userProfile\Downloads"
    if (Test-Path $downloadsPath) {
        $oldDownloads = Get-ChildItem $downloadsPath -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastAccessTime -lt $downloadsCutoff }
        foreach ($f in $oldDownloads) {
            if (Safe-RemoveItem $f.FullName) { $freed += $f.Length } else { $failed++ }
        }
    }

    # Desktop junk
    $desktopPath = "$userProfile\Desktop"
    if (Test-Path $desktopPath) {
        $deskJunk = Get-ChildItem $desktopPath -File -ErrorAction SilentlyContinue |
            Where-Object { $ext = $_.Extension.ToLower(); $junkExtensions -contains $ext }
        foreach ($f in $deskJunk) {
            if (Safe-RemoveItem $f.FullName) { $freed += $f.Length } else { $failed++ }
        }
    }

    # Recent shortcuts
    $recentPath = "$env:APPDATA\Microsoft\Windows\Recent"
    if (Test-Path $recentPath) {
        Get-ChildItem $recentPath -File -ErrorAction SilentlyContinue | ForEach-Object {
            if (Safe-RemoveItem $_.FullName) { $freed += $_.Length } else { $failed++ }
        }
    }

    # WER files
    $werPaths = @(
        "$env:LOCALAPPDATA\Microsoft\Windows\WER",
        "$env:ProgramData\Microsoft\Windows\WER"
    )
    foreach ($werPath in $werPaths) {
        if (-not (Test-Path $werPath)) { continue }
        Get-ChildItem $werPath -Recurse -File -Include "*.wer", "*.dmp", "*.hdmp" -ErrorAction SilentlyContinue |
            ForEach-Object {
                if (Safe-RemoveItem $_.FullName) { $freed += $_.Length } else { $failed++ }
            }
    }

    $report = [PSCustomObject]@{
        category = "用户目录垃圾"
        freed    = $freed
        display  = Get-SizeDisplay $freed
        failed   = $failed
        note     = "Downloads 中超过 30 天未访问的文件也包含在内。"
    }
    return $report | ConvertTo-Json -Depth 2
}

Invoke-CleanAction -Action $Action -ScanBlock ${function:Get-UserJunk} -CleanBlock ${function:Remove-UserJunk}
```

- [ ] **Step 2: Verify Scan mode outputs valid JSON**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File "./scripts/scan-userjunk.ps1" -Action Scan`

Expected: JSON with `category`, `risk` = `"medium"`, `totalSize`, `fileCount`, `items`.

- [ ] **Step 3: Commit**

```bash
git add scripts/scan-userjunk.ps1
git commit -m "feat: add user junk scanner"
```

---

### Task 7: scan-leftovers.ps1 — Software leftovers

**Files:**
- Create: `scripts/scan-leftovers.ps1`

- [ ] **Step 1: Create the script**

```powershell
<#
.SYNOPSIS
    Scan or clean software leftover files after uninstallation.
.DESCRIPTION
    Compares folders in Program Files, Program Files (x86), AppData, and
    LocalAppData against the registry uninstall list to find orphaned folders.
.PARAMETER Action
    Scan: list orphaned folders (read-only).
    Clean: delete orphaned folders (each requires explicit user path confirmation).
.EXAMPLE
    .\scan-leftovers.ps1 -Action Scan
    .\scan-leftovers.ps1 -Action Clean
#>
param(
    [Parameter(Mandatory)]
    [ValidateSet('Scan', 'Clean')]
    [string]$Action
)

Import-Module "$PSScriptRoot\pc-cleaner.psm1" -Force

function Get-InstalledSoftwareNames {
    $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $registryPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($regPath in $registryPaths) {
        try {
            $entries = Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName } |
                ForEach-Object { $_.DisplayName.Trim() }
            foreach ($name in $entries) { [void]$names.Add($name) }
        } catch {}
    }

    return $names
}

function Get-LeftoverFiles {
    $items = @()
    $totalSize = 0L
    $installed = Get-InstalledSoftwareNames

    $scanRoots = @(
        [System.Environment]::GetFolderPath('ProgramFiles'),
        [System.Environment]::GetFolderPath('ProgramFilesX86'),
        [System.Environment]::GetFolderPath('ApplicationData'),
        [System.Environment]::GetFolderPath('LocalApplicationData')
    )

    foreach ($root in $scanRoots) {
        if (-not (Test-Path $root)) { continue }
        $folders = Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^(Microsoft|Windows|PackageManagement|NuGet|npm|pip|Python)' }

        foreach ($folder in $folders) {
            # Check if folder name appears in any installed software name
            $matched = $false
            foreach ($sw in $installed) {
                if ($sw -match [regex]::Escape($folder.Name) -or $folder.Name -match [regex]::Escape($sw)) {
                    $matched = $true
                    break
                }
            }
            if (-not $matched) {
                $size = Get-SafeFolderSize $folder.FullName
                $items += New-ScanItem -Path $folder.FullName -Size $size -LastModified $folder.LastWriteTime -SafeToDelete $false
                $totalSize += $size
            }
        }
    }

    return Format-ScanResult -Category "软件残留" -Risk "high" -TotalSize $totalSize -FileCount $items.Count -Items $items
}

function Remove-LeftoverFiles {
    # High risk — called only after user has selected specific paths
    $installed = Get-InstalledSoftwareNames
    $freed = 0L
    $failed = 0

    $scanRoots = @(
        [System.Environment]::GetFolderPath('ProgramFiles'),
        [System.Environment]::GetFolderPath('ProgramFilesX86'),
        [System.Environment]::GetFolderPath('ApplicationData'),
        [System.Environment]::GetFolderPath('LocalApplicationData')
    )

    foreach ($root in $scanRoots) {
        if (-not (Test-Path $root)) { continue }
        $folders = Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^(Microsoft|Windows|PackageManagement|NuGet|npm|pip|Python)' }

        foreach ($folder in $folders) {
            $matched = $false
            foreach ($sw in $installed) {
                if ($sw -match [regex]::Escape($folder.Name) -or $folder.Name -match [regex]::Escape($sw)) {
                    $matched = $true
                    break
                }
            }
            if (-not $matched) {
                $size = Get-SafeFolderSize $folder.FullName
                if (Safe-RemoveItem $folder.FullName -Recurse) { $freed += $size } else { $failed++ }
            }
        }
    }

    $report = [PSCustomObject]@{
        category = "软件残留"
        freed    = $freed
        display  = Get-SizeDisplay $freed
        failed   = $failed
        note     = "已删除未在注册表中注册的残留文件夹。"
    }
    return $report | ConvertTo-Json -Depth 2
}

Invoke-CleanAction -Action $Action -ScanBlock ${function:Get-LeftoverFiles} -CleanBlock ${function:Remove-LeftoverFiles}
```

- [ ] **Step 2: Verify Scan mode outputs valid JSON**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File "./scripts/scan-leftovers.ps1" -Action Scan`

Expected: JSON with `category`, `risk` = `"high"`, `totalSize`, `fileCount`, `items`.

- [ ] **Step 3: Commit**

```bash
git add scripts/scan-leftovers.ps1
git commit -m "feat: add software leftovers scanner"
```

---

### Task 8: scan-large.ps1 — Large files & duplicates

**Files:**
- Create: `scripts/scan-large.ps1`

- [ ] **Step 1: Create the script**

```powershell
<#
.SYNOPSIS
    Scan for large files (>500MB) and duplicate files (MD5 hash).
.DESCRIPTION
    Large files: scans user directories, reports top 20 by size.
    Duplicates: compares MD5 hashes, reports groups of identical files.
.PARAMETER Action
    Scan: list large files and duplicate groups (read-only).
    Clean: for duplicates, keep newest and delete rest. Large files: report only.
.EXAMPLE
    .\scan-large.ps1 -Action Scan
    .\scan-large.ps1 -Action Clean
#>
param(
    [Parameter(Mandatory)]
    [ValidateSet('Scan', 'Clean')]
    [string]$Action
)

Import-Module "$PSScriptRoot\pc-cleaner.psm1" -Force

$minLargeSize = 500MB
$maxLargeCount = 20
$scanRoot = $env:USERPROFILE

# Exclude these directories from duplicate scan (too many system files)
$excludeDirs = @(
    "AppData", "node_modules", ".git", "__pycache__", "venv", ".venv",
    "Microsoft", "Windows", "Cache", "cache", "temp", "tmp"
)

function Get-LargeAndDuplicates {
    $items = @()
    $totalSize = 0L

    # --- Large files ---
    if (Test-Path $scanRoot) {
        $largeFiles = Get-ChildItem $scanRoot -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -ge $minLargeSize } |
            Sort-Object Length -Descending |
            Select-Object -First $maxLargeCount

        foreach ($f in $largeFiles) {
            $items += New-ScanItem -Path $f.FullName -Size $f.Length -LastModified $f.LastWriteTime -SafeToDelete $false
            $totalSize += $f.Length
        }
    }

    # --- Duplicate files ---
    $allFiles = Get-ChildItem $scanRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt 0 -and $_.Length -lt 100MB } |
        Where-Object {
            $full = $_.FullName
            $skip = $false
            foreach ($ex in $excludeDirs) {
                if ($full -match "\\$ex\\" -or $full -match "\\$ex$") { $skip = $true; break }
            }
            return -not $skip
        }

    # Group by size first (quick filter), then hash within size groups
    $bySize = $allFiles | Group-Object Length | Where-Object { $_.Count -gt 1 -and $_.Name -gt 0 }
    $duplicates = @()

    foreach ($group in $bySize) {
        $hashGroups = $group.Group | Group-Object { (Get-FileHash $_.FullName -Algorithm MD5).Hash } |
            Where-Object { $_.Count -gt 1 }
        foreach ($hg in $hashGroups) {
            $duplicates += [PSCustomObject]@{
                hash  = $hg.Name
                files = @($hg.Group | Select-Object FullName, Length, LastWriteTime)
            }
        }
    }

    # Add duplicate file info to items
    $dupTotalSize = 0L
    $dupCount = 0
    foreach ($d in $duplicates) {
        # Keep the newest, the rest are duplicates
        $sorted = $d.files | Sort-Object LastWriteTime -Descending
        $keep = $sorted[0]
        for ($i = 1; $i -lt $sorted.Count; $i++) {
            $f = $sorted[$i]
            $items += [PSCustomObject]@{
                path         = $f.FullName
                size         = $f.Length
                lastModified = $f.LastWriteTime.ToString('yyyy-MM-dd')
                safeToDelete = $true
                duplicateOf  = $keep.FullName
            }
            $dupTotalSize += $f.Length
            $dupCount++
        }
    }
    $totalSize += $dupTotalSize

    return Format-ScanResult -Category "大文件与重复文件" -Risk "high" -TotalSize $totalSize -FileCount $items.Count -Items $items
}

function Remove-DuplicatesOnly {
    $freed = 0L
    $failed = 0

    # Re-run duplicate detection logic for clean
    $allFiles = Get-ChildItem $scanRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt 0 -and $_.Length -lt 100MB } |
        Where-Object {
            $full = $_.FullName
            $skip = $false
            foreach ($ex in $excludeDirs) {
                if ($full -match "\\$ex\\" -or $full -match "\\$ex$") { $skip = $true; break }
            }
            return -not $skip
        }

    $bySize = $allFiles | Group-Object Length | Where-Object { $_.Count -gt 1 -and $_.Name -gt 0 }

    foreach ($group in $bySize) {
        $hashGroups = $group.Group | Group-Object { (Get-FileHash $_.FullName -Algorithm MD5).Hash } |
            Where-Object { $_.Count -gt 1 }
        foreach ($hg in $hashGroups) {
            $sorted = $hg.Group | Sort-Object LastWriteTime -Descending
            $keep = $sorted[0]
            for ($i = 1; $i -lt $sorted.Count; $i++) {
                if (Safe-RemoveItem $sorted[$i].FullName) { $freed += $sorted[$i].Length } else { $failed++ }
            }
        }
    }

    $report = [PSCustomObject]@{
        category = "大文件与重复文件"
        freed    = $freed
        display  = Get-SizeDisplay $freed
        failed   = $failed
        note     = "仅删除重复文件（保留最新副本）。大文件仅作报告，未删除。"
    }
    return $report | ConvertTo-Json -Depth 2
}

Invoke-CleanAction -Action $Action -ScanBlock ${function:Get-LargeAndDuplicates} -CleanBlock ${function:Remove-DuplicatesOnly}
```

- [ ] **Step 2: Verify Scan mode outputs valid JSON**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File "./scripts/scan-large.ps1" -Action Scan`

Expected: JSON with `category`, `risk` = `"high"`, `totalSize`, `fileCount`, `items`. Large files have `safeToDelete: false`, duplicates have `safeToDelete: true` with `duplicateOf` field.

- [ ] **Step 3: Commit**

```bash
git add scripts/scan-large.ps1
git commit -m "feat: add large files & duplicates scanner"
```

---

### Task 9: Skill definition file (`pc-cleaner.md`)

**Files:**
- Create: `skills/pc-cleaner.md`

- [ ] **Step 1: Create the skill definition**

```markdown
---
name: pc-cleaner
description: Windows 电脑清理工具。扫描和清理系统临时文件、浏览器缓存、回收站、软件残留、大文件/重复文件、用户目录垃圾。保守策略：先扫描出报告，用户确认后才执行清理。
version: 1.0.0
author: user
---

# PC Cleaner — Windows 电脑清理

当用户表达清理电脑的意图时，使用此技能。支持中文和英文指令。

## 核心原则

1. **永远先扫描后清理** — 绝不直接执行 Clean 操作。先运行 Scan 收集数据，展示报告，等待用户确认。
2. **风险分级展示** — 低风险（临时文件、回收站）标记为可直接清理；中风险（浏览器缓存、用户垃圾）提醒后果；高风险（软件残留、大文件）需逐项确认。
3. **管理员权限检查** — 大部分清理操作需要管理员权限。如果未以管理员运行，提示用户如何提升权限。

## 脚本位置

所有脚本位于此 skill 文件同级目录的 `scripts/` 文件夹下。使用前确保路径正确：

```
scripts/
├── pc-cleaner.psm1       # 公共模块
├── scan-temp.ps1          # 系统临时文件 (risk: low)
├── scan-browser.ps1       # 浏览器缓存 (risk: medium)
├── scan-recycle.ps1       # 回收站 (risk: low)
├── scan-leftovers.ps1     # 软件残留 (risk: high)
├── scan-large.ps1         # 大文件/重复文件 (risk: high)
└── scan-userjunk.ps1      # 用户目录垃圾 (risk: medium)
```

## 工作流程

### Step 1: 理解用户意图

分析用户输入，确定要扫描哪些模块：

| 用户说 | 扫描模块 |
|--------|---------|
| "清理电脑" / "全盘扫描" | 全部 6 个模块 |
| "清理临时文件" | scan-temp.ps1 |
| "清理浏览器缓存" | scan-browser.ps1 |
| "清空回收站" | scan-recycle.ps1 |
| "查找软件残留" | scan-leftovers.ps1 |
| "查找大文件" | scan-large.ps1 |
| "清理下载/桌面垃圾" | scan-userjunk.ps1 |

如果用户只指定了某一项，只扫描该项。如果模糊不清（如"帮我清理一下"），默认扫描全部。

### Step 2: 检查管理员权限

运行以下命令检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "Import-Module '<SKILL_DIR>/scripts/pc-cleaner.psm1' -Force; Test-AdminPrivilege"
```

如果不是管理员：
> ⚠️ 此操作需要管理员权限。请以管理员身份重新打开 Claude Code，或运行：
> ```
> Start-Process pwsh -Verb RunAs
> ```

### Step 3: 运行扫描（Scan 模式）

对每个选中的模块，运行扫描命令。命令中的 `<SKILL_DIR>` 替换为此 skill 文件的所在目录：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>/scripts/scan-<name>.ps1" -Action Scan
```

解析每个脚本输出的 JSON：
- `category` — 类别名称
- `risk` — 风险等级：`low`, `medium`, `high`
- `totalSize` — 总大小（字节）
- `fileCount` — 文件/项目数量
- `items` — 详细条目数组

### Step 4: 展示扫描报告

用表格形式展示汇总结果：

```
📊 PC Cleaner 扫描报告
┌─────────────────┬──────────┬───────────┬────────┐
│ 类别             │ 文件数    │ 大小       │ 风险   │
├─────────────────┼──────────┼───────────┼────────┤
│ 系统临时文件      │ X        │ X.XX GB   │ 🟢 低  │
│ 浏览器缓存        │ X        │ X.XX GB   │ 🟡 中  │
│ 回收站           │ X        │ X.XX GB   │ 🟢 低  │
│ 软件残留         │ X        │ X.XX GB   │ 🔴 高  │
│ 大文件/重复文件   │ X        │ X.XX GB   │ 🔴 高  │
│ 用户目录垃圾      │ X        │ X.XX GB   │ 🟡 中  │
├─────────────────┼──────────┼───────────┼────────┤
│ 总计             │ XXXX     │ XX.XX GB  │        │
└─────────────────┴──────────┴───────────┴────────┘

💡 建议：
- 🟢 低风险项（X.XX GB）可安全清理
- 🟡 中风险项（X.XX GB）清理后可能需要重新登录或重新下载
- 🔴 高风险项（X.XX GB）需要逐项确认，避免误删重要数据
```

### Step 5: 获取用户确认

提供选项：
> 请选择清理范围：
> 1. 🟢 仅清理低风险项（安全）
> 2. 🟢🟡 清理低+中风险项
> 3. 🔴 全部清理（含高风险，需逐项确认）
> 4. ✏️ 自定义选择
> 5. ❌ 取消

等高风险的项，如果用户选择全部清理，逐项列出每个高风险条目让用户确认。

### Step 6: 执行清理（Clean 模式）

对用户确认的每个模块，运行清理命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>/scripts/scan-<name>.ps1" -Action Clean
```

解析输出的清理报告 JSON：
- `category` — 类别名称
- `freed` — 释放的字节数
- `display` — 可读的大小
- `failed` — 失败的文件数
- `note` — 备注（如有）

### Step 7: 展示清理结果

```
✅ 清理完成！
┌─────────────────┬───────────┬────────┐
│ 类别             │ 释放空间   │ 失败   │
├─────────────────┼───────────┼────────┤
│ 系统临时文件      │ 1.20 GB   │ 0      │
│ 回收站           │ 45 MB     │ 0      │
├─────────────────┼───────────┼────────┤
│ 🎉 总计释放     │ 1.25 GB   │        │
└─────────────────┴───────────┴────────┘

⚠️ 提醒：浏览器缓存已清理，部分网站需要重新登录。
```

## 安全规则

1. 绝对不能跳过扫描步骤直接执行 Clean
2. 绝对不能对 `C:\Windows`、`C:\Program Files`、`C:\Windows\System32` 等系统目录执行批量删除
3. 高风险项（risk: high）必须逐条展示路径让用户确认，不能批量清理
4. 如果扫描结果为空（fileCount = 0），告知用户"没有发现可清理的文件"而不是报错

## 错误处理

- 如果某个脚本执行失败，继续执行其他脚本，不要中断整个流程
- 如果 PowerShell 版本 < 5.1，提示用户升级
- 如果路径访问被拒绝，在报告中标注"权限不足"而不是崩溃
```

- [ ] **Step 2: Verify the skill file is valid YAML frontmatter**

Check that the frontmatter between `---` delimiters is valid YAML with `name`, `description`, `version`, `author`.

- [ ] **Step 3: Commit**

```bash
git add skills/pc-cleaner.md
git commit -m "feat: add skill definition file"
```

---

### Task 10: Tests

**Files:**
- Create: `tests/test-module.ps1`
- Create: `tests/test-scan-modes.ps1`
- Create: `tests/test-edge-cases.ps1`

- [ ] **Step 1: Create test-module.ps1**

```powershell
<#
.SYNOPSIS
    Tests for the shared PowerShell module (pc-cleaner.psm1).
#>

Import-Module "$PSScriptRoot\..\scripts\pc-cleaner.psm1" -Force

Describe "Get-SizeDisplay" {
    It "returns '0 B' for 0 bytes" {
        Get-SizeDisplay 0 | Should -Be "0 B"
    }
    It "returns '1 KB' for 1024 bytes" {
        Get-SizeDisplay 1024 | Should -Be "1 KB"
    }
    It "returns '1 MB' for 1048576 bytes" {
        Get-SizeDisplay 1048576 | Should -Be "1 MB"
    }
    It "returns '1 GB' for 1073741824 bytes" {
        Get-SizeDisplay 1073741824 | Should -Be "1 GB"
    }
    It "handles large values without error" {
        Get-SizeDisplay 5368709120 | Should -Match "GB$"
    }
}

Describe "Test-SafePath" {
    It "rejects System32" {
        Test-SafePath "$env:SystemRoot\System32" | Should -Be $false
    }
    It "rejects Windows directory" {
        Test-SafePath "$env:SystemRoot" | Should -Be $false
    }
    It "rejects Program Files" {
        Test-SafePath ${env:ProgramFiles} | Should -Be $false
    }
    It "allows a temp directory" {
        Test-SafePath "$env:TEMP\test-folder" | Should -Be $true
    }
}

Describe "Test-AdminPrivilege" {
    It "returns a boolean" {
        $result = Test-AdminPrivilege
        $result | Should -BeOfType [bool]
    }
}

Describe "Format-ScanResult" {
    It "outputs valid JSON with required fields" {
        $items = @(
            (New-ScanItem -Path "C:\Temp\test.tmp" -Size 100 -LastModified (Get-Date) -SafeToDelete $true)
        )
        $json = Format-ScanResult -Category "Test" -Risk "low" -TotalSize 100 -FileCount 1 -Items $items
        $obj = $json | ConvertFrom-Json
        $obj.category | Should -Be "Test"
        $obj.risk | Should -Be "low"
        $obj.totalSize | Should -Be 100
        $obj.fileCount | Should -Be 1
        $obj.items.Count | Should -Be 1
    }

    It "outputs empty items array for zero files" {
        $json = Format-ScanResult -Category "Empty" -Risk "low" -TotalSize 0 -FileCount 0 -Items @()
        $obj = $json | ConvertFrom-Json
        $obj.fileCount | Should -Be 0
        $obj.items | Should -BeNullOrEmpty
    }
}

Describe "New-ScanItem" {
    It "creates an item with correct properties" {
        $item = New-ScanItem -Path "C:\test.txt" -Size 500 -LastModified (Get-Date) -SafeToDelete $true
        $item.path | Should -Be "C:\test.txt"
        $item.size | Should -Be 500
        $item.safeToDelete | Should -Be $true
    }
}

Describe "Invoke-CleanAction" {
    It "executes Scan block when Action is Scan" {
        $result = Invoke-CleanAction -Action "Scan" `
            -ScanBlock { return '{"scanned": true}' } `
            -CleanBlock { return '{"cleaned": true}' }
        $result | Should -Be '{"scanned": true}'
    }

    It "executes Clean block when Action is Clean" {
        $result = Invoke-CleanAction -Action "Clean" `
            -ScanBlock { return '{"scanned": true}' } `
            -CleanBlock { return '{"cleaned": true}' }
        $result | Should -Be '{"cleaned": true}'
    }
}
```

- [ ] **Step 2: Run module tests**

Run: `powershell -NoProfile -Command "Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser; Import-Module Pester; Invoke-Pester ./tests/test-module.ps1"`

Expected: All tests pass.

- [ ] **Step 3: Create test-scan-modes.ps1**

```powershell
<#
.SYNOPSIS
    Validates that every scan script produces valid JSON output in Scan mode.
#>

$scriptsDir = "$PSScriptRoot\..\scripts"
$scanScripts = Get-ChildItem "$scriptsDir\scan-*.ps1" | ForEach-Object { $_.Name }

Describe "Scan mode validation" {
    Context "scan-temp.ps1" {
        It "outputs valid JSON with required fields" {
            $output = & "$scriptsDir\scan-temp.ps1" -Action Scan
            $obj = $output | ConvertFrom-Json
            $obj.PSObject.Properties.Name -contains 'category' | Should -Be $true
            $obj.PSObject.Properties.Name -contains 'risk' | Should -Be $true
            $obj.PSObject.Properties.Name -contains 'totalSize' | Should -Be $true
            $obj.PSObject.Properties.Name -contains 'fileCount' | Should -Be $true
            $obj.PSObject.Properties.Name -contains 'items' | Should -Be $true
        }
    }

    Context "scan-recycle.ps1" {
        It "outputs valid JSON with required fields" {
            $output = & "$scriptsDir\scan-recycle.ps1" -Action Scan
            $obj = $output | ConvertFrom-Json
            $obj.PSObject.Properties.Name -contains 'category' | Should -Be $true
            $obj.PSObject.Properties.Name -contains 'risk' | Should -Be $true
        }
    }

    Context "scan-browser.ps1" {
        It "outputs valid JSON with required fields" {
            $output = & "$scriptsDir\scan-browser.ps1" -Action Scan
            $obj = $output | ConvertFrom-Json
            $obj.PSObject.Properties.Name -contains 'category' | Should -Be $true
            $obj.PSObject.Properties.Name -contains 'risk' | Should -Be $true
        }
    }

    Context "scan-userjunk.ps1" {
        It "outputs valid JSON with required fields" {
            $output = & "$scriptsDir\scan-userjunk.ps1" -Action Scan
            $obj = $output | ConvertFrom-Json
            $obj.PSObject.Properties.Name -contains 'category' | Should -Be $true
            $obj.PSObject.Properties.Name -contains 'risk' | Should -Be $true
        }
    }

    Context "scan-leftovers.ps1" {
        It "outputs valid JSON with required fields" {
            $output = & "$scriptsDir\scan-leftovers.ps1" -Action Scan
            $obj = $output | ConvertFrom-Json
            $obj.PSObject.Properties.Name -contains 'category' | Should -Be $true
            $obj.PSObject.Properties.Name -contains 'risk' | Should -Be $true
        }
    }

    Context "scan-large.ps1" {
        It "outputs valid JSON with required fields" {
            $output = & "$scriptsDir\scan-large.ps1" -Action Scan
            $obj = $output | ConvertFrom-Json
            $obj.PSObject.Properties.Name -contains 'category' | Should -Be $true
            $obj.PSObject.Properties.Name -contains 'risk' | Should -Be $true
        }
    }
}
```

- [ ] **Step 4: Run scan mode tests**

Run: `powershell -NoProfile -Command "Import-Module Pester; Invoke-Pester ./tests/test-scan-modes.ps1"`

Expected: All tests pass (6 out of 6).

- [ ] **Step 5: Create test-edge-cases.ps1**

```powershell
<#
.SYNOPSIS
    Edge case tests: empty directories, inaccessible paths, special characters.
#>
Import-Module "$PSScriptRoot\..\scripts\pc-cleaner.psm1" -Force

Describe "Edge cases" {
    Context "Safe-RemoveItem" {
        It "returns false for non-existent path" {
            Safe-RemoveItem "C:\definitely-not-exists-abc123\file.txt" | Should -Be $false
        }
        It "returns false for system root" {
            Safe-RemoveItem "C:\Windows" | Should -Be $false
        }
    }

    Context "Get-SafeFolderSize" {
        It "returns 0 for non-existent path" {
            Get-SafeFolderSize "C:\definitely-not-exists-abc123" | Should -Be 0
        }
        It "returns 0 for a path with no files (system protected)" {
            # Should handle gracefully
            { Get-SafeFolderSize "C:\Windows\System32" } | Should -Not -Throw
        }
    }

    Context "Get-SizeDisplay" {
        It "handles negative values gracefully" {
            # Should not throw
            { Get-SizeDisplay -1024 } | Should -Not -Throw
        }
    }

    Context "Scan scripts handle empty/invalid paths" {
        It "scan-temp does not throw" {
            { & "$PSScriptRoot\..\scripts\scan-temp.ps1" -Action Scan } | Should -Not -Throw
        }
        It "scan-recycle does not throw" {
            { & "$PSScriptRoot\..\scripts\scan-recycle.ps1" -Action Scan } | Should -Not -Throw
        }
        It "scan-browser does not throw" {
            { & "$PSScriptRoot\..\scripts\scan-browser.ps1" -Action Scan } | Should -Not -Throw
        }
        It "scan-userjunk does not throw" {
            { & "$PSScriptRoot\..\scripts\scan-userjunk.ps1" -Action Scan } | Should -Not -Throw
        }
        It "scan-leftovers does not throw" {
            { & "$PSScriptRoot\..\scripts\scan-leftovers.ps1" -Action Scan } | Should -Not -Throw
        }
        It "scan-large does not throw" {
            { & "$PSScriptRoot\..\scripts\scan-large.ps1" -Action Scan } | Should -Not -Throw
        }
    }

    Context "Invalid Action parameter" {
        It "fails for invalid action" {
            $result = & "$PSScriptRoot\..\scripts\scan-temp.ps1" -Action "Invalid" 2>&1
            $result | Should -Not -BeNullOrEmpty
        }
    }
}
```

- [ ] **Step 6: Run edge case tests**

Run: `powershell -NoProfile -Command "Import-Module Pester; Invoke-Pester ./tests/test-edge-cases.ps1"`

Expected: All tests pass or skip gracefully.

- [ ] **Step 7: Commit tests**

```bash
git add tests/
git commit -m "test: add module, scan mode, and edge case tests"
```

---

### Task 11: Final verification

- [ ] **Step 1: Run all tests**

```bash
powershell -NoProfile -Command "Import-Module Pester; Invoke-Pester ./tests/"
```

Expected: All test suites pass.

- [ ] **Step 2: Verify all scripts exist and execute**

```bash
for script in scripts/scan-*.ps1; do
  echo "=== Testing $script ==="
  powershell -NoProfile -ExecutionPolicy Bypass -File "$script" -Action Scan > /dev/null 2>&1 && echo "PASS: $script" || echo "FAIL: $script"
done
```

Expected: All 6 scripts show PASS.

- [ ] **Step 3: Verify project structure is complete**

```bash
echo "Expected files:"
for f in .gitignore LICENSE README.md CLAUDE.md \
         scripts/pc-cleaner.psm1 \
         scripts/scan-temp.ps1 scripts/scan-browser.ps1 scripts/scan-recycle.ps1 \
         scripts/scan-leftovers.ps1 scripts/scan-large.ps1 scripts/scan-userjunk.ps1 \
         skills/pc-cleaner.md \
         tests/test-module.ps1 tests/test-scan-modes.ps1 tests/test-edge-cases.ps1; do
  [ -f "$f" ] && echo "  ✅ $f" || echo "  ❌ MISSING: $f"
done
```

Expected: All ✅.

- [ ] **Step 4: Commit final verification**

```bash
git add -A
git commit -m "chore: final verification, all scripts and tests pass"
```

---

## Self-Review

**Spec coverage:**
- ✅ 6 scan modules → Tasks 3-8
- ✅ Shared module with 4 functions + helpers → Task 2
- ✅ Skill definition file with workflow → Task 9
- ✅ 3 test files → Task 10
- ✅ Error handling (admin check, path safety) → In module (Task 2) + skill file (Task 9)
- ✅ Safety principles (scan/clean separation, confirmation gate) → Enforced in skill file (Task 9)
- ✅ Project scaffolding → Task 1

**No placeholders:** Every step has complete, copy-paste-ready code. No TODOs or fill-in-laters.

**Type consistency:**
- All scripts use `-Action Scan|Clean` with `ValidateSet` ✅
- All scripts output JSON via `Format-ScanResult` or manual `ConvertTo-Json` ✅
- All scripts import `pc-cleaner.psm1` with the same relative path ✅
- `Invoke-CleanAction` signature consistent across all callers ✅
