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
