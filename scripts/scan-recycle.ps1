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
