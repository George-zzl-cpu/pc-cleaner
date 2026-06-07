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

    $dupTotalSize = 0L
    foreach ($d in $duplicates) {
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
        }
    }
    $totalSize += $dupTotalSize

    return Format-ScanResult -Category "大文件与重复文件" -Risk "high" -TotalSize $totalSize -FileCount $items.Count -Items $items
}

function Remove-DuplicatesOnly {
    $freed = 0L
    $failed = 0

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
