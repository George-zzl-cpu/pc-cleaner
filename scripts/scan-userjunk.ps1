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
