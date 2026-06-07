<#
.SYNOPSIS
    Tests for the shared PowerShell module (pc-cleaner.psm1).
#>

Import-Module "$PSScriptRoot\..\scripts\pc-cleaner.psm1" -Force

Describe "Get-SizeDisplay" {
    It "returns '0 B' for 0 bytes" {
        Get-SizeDisplay 0 | Should Be "0 B"
    }
    It "returns '1 KB' for 1024 bytes" {
        Get-SizeDisplay 1024 | Should Be "1 KB"
    }
    It "returns '1 MB' for 1048576 bytes" {
        Get-SizeDisplay 1048576 | Should Be "1 MB"
    }
    It "returns '1 GB' for 1073741824 bytes" {
        Get-SizeDisplay 1073741824 | Should Be "1 GB"
    }
    It "handles large values without error" {
        $result = Get-SizeDisplay 5368709120
        $result | Should Match "GB$"
    }
}

Describe "Test-SafePath" {
    It "rejects System32" {
        Test-SafePath "$env:SystemRoot\System32" | Should Be $false
    }
    It "rejects Windows directory" {
        Test-SafePath "$env:SystemRoot" | Should Be $false
    }
    It "rejects Program Files" {
        Test-SafePath ${env:ProgramFiles} | Should Be $false
    }
}

Describe "Test-AdminPrivilege" {
    It "returns a boolean" {
        $result = Test-AdminPrivilege
        ($result -eq $true -or $result -eq $false) | Should Be $true
    }
}

Describe "Format-ScanResult" {
    It "outputs valid JSON with required fields" {
        $items = @(
            (New-ScanItem -Path "C:\Temp\test.tmp" -Size 100 -LastModified (Get-Date) -SafeToDelete $true)
        )
        $json = Format-ScanResult -Category "Test" -Risk "low" -TotalSize 100 -FileCount 1 -Items $items
        $obj = $json | ConvertFrom-Json
        $obj.category | Should Be "Test"
        $obj.risk | Should Be "low"
        $obj.totalSize | Should Be 100
        $obj.fileCount | Should Be 1
        $obj.items.Count | Should Be 1
    }

    It "outputs empty items array for zero files" {
        $json = Format-ScanResult -Category "Empty" -Risk "low" -TotalSize 0 -FileCount 0 -Items @()
        $obj = $json | ConvertFrom-Json
        $obj.fileCount | Should Be 0
        (@($obj.items).Count -eq 0) | Should Be $true
    }
}

Describe "New-ScanItem" {
    It "creates an item with correct properties" {
        $item = New-ScanItem -Path "C:\test.txt" -Size 500 -LastModified (Get-Date) -SafeToDelete $true
        $item.path | Should Be "C:\test.txt"
        $item.size | Should Be 500
        $item.safeToDelete | Should Be $true
    }
}

Describe "Invoke-CleanAction" {
    It "executes Scan block when Action is Scan" {
        $result = Invoke-CleanAction -Action "Scan" `
            -ScanBlock { return '{"scanned": true}' } `
            -CleanBlock { return '{"cleaned": true}' }
        $result | Should Be '{"scanned": true}'
    }

    It "executes Clean block when Action is Clean" {
        $result = Invoke-CleanAction -Action "Clean" `
            -ScanBlock { return '{"scanned": true}' } `
            -CleanBlock { return '{"cleaned": true}' }
        $result | Should Be '{"cleaned": true}'
    }
}
