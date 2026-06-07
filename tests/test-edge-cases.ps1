<#
.SYNOPSIS
    Edge case tests: empty directories, inaccessible paths, special characters.
#>
Import-Module "$PSScriptRoot\..\scripts\pc-cleaner.psm1" -Force

Describe "Edge cases" {
    Context "Safe-RemoveItem" {
        It "returns false for non-existent path" {
            Safe-RemoveItem "C:\definitely-not-exists-abc123\file.txt" | Should Be $false
        }
        It "returns false for system root" {
            Safe-RemoveItem "C:\Windows" | Should Be $false
        }
    }

    Context "Get-SafeFolderSize" {
        It "returns 0 for non-existent path" {
            Get-SafeFolderSize "C:\definitely-not-exists-abc123" | Should Be 0
        }
    }

    Context "Get-SizeDisplay" {
        It "handles negative values without throwing" {
            try {
                Get-SizeDisplay -1024
                $true | Should Be $true
            } catch {
                $false | Should Be $true
            }
        }
    }
}
