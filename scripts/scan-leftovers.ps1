<#
.SYNOPSIS
    Scan or clean software leftover files after uninstallation.
.DESCRIPTION
    Compares folders in Program Files, Program Files (x86), AppData, and
    LocalAppData against the registry uninstall list to find orphaned folders.
.PARAMETER Action
    Scan: list orphaned folders (read-only).
    Clean: delete orphaned folders (requires explicit user path confirmation).
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
