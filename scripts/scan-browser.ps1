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
    @{ Name = "Chrome"; Path = "$localAppData\Google\Chrome\User Data" },
    @{ Name = "Edge"; Path = "$localAppData\Microsoft\Edge\User Data" },
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
