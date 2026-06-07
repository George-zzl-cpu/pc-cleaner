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

    $resolved = Resolve-Path $Path -ErrorAction SilentlyContinue
    if (-not $resolved) { return $false }
    $normalized = $resolved.Path.TrimEnd('\').ToLowerInvariant()
    foreach ($b in $blocked) {
        if ($normalized -eq $b) { return $false }
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
