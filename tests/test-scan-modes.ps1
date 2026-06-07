<#
.SYNOPSIS
    Validates that every scan script produces valid JSON output in Scan mode.
    NOTE: These tests scan the actual system, so they may be slow.
#>

$scriptsDir = "$PSScriptRoot\..\scripts"

Describe "Scan mode validation" {
    Context "scan-temp.ps1" {
        It "outputs valid JSON with required fields" {
            $output = & "$scriptsDir\scan-temp.ps1" -Action Scan
            $obj = $output | ConvertFrom-Json
            ($obj.PSObject.Properties.Name -contains 'category') | Should Be $true
            ($obj.PSObject.Properties.Name -contains 'risk') | Should Be $true
            ($obj.PSObject.Properties.Name -contains 'totalSize') | Should Be $true
            ($obj.PSObject.Properties.Name -contains 'fileCount') | Should Be $true
            ($obj.PSObject.Properties.Name -contains 'items') | Should Be $true
        }
    }

    Context "scan-recycle.ps1" {
        It "outputs valid JSON with required fields" {
            $output = & "$scriptsDir\scan-recycle.ps1" -Action Scan
            $obj = $output | ConvertFrom-Json
            ($obj.PSObject.Properties.Name -contains 'category') | Should Be $true
            ($obj.PSObject.Properties.Name -contains 'risk') | Should Be $true
        }
    }

    Context "scan-browser.ps1" {
        It "outputs valid JSON with required fields" {
            $output = & "$scriptsDir\scan-browser.ps1" -Action Scan
            $obj = $output | ConvertFrom-Json
            ($obj.PSObject.Properties.Name -contains 'category') | Should Be $true
            ($obj.PSObject.Properties.Name -contains 'risk') | Should Be $true
        }
    }

    Context "scan-userjunk.ps1" {
        It "outputs valid JSON with required fields" {
            $output = & "$scriptsDir\scan-userjunk.ps1" -Action Scan
            $obj = $output | ConvertFrom-Json
            ($obj.PSObject.Properties.Name -contains 'category') | Should Be $true
            ($obj.PSObject.Properties.Name -contains 'risk') | Should Be $true
        }
    }

    Context "scan-leftovers.ps1" {
        It "outputs valid JSON with required fields" {
            $output = & "$scriptsDir\scan-leftovers.ps1" -Action Scan
            $obj = $output | ConvertFrom-Json
            ($obj.PSObject.Properties.Name -contains 'category') | Should Be $true
            ($obj.PSObject.Properties.Name -contains 'risk') | Should Be $true
        }
    }

    Context "scan-large.ps1" {
        It "outputs valid JSON with required fields" {
            $output = & "$scriptsDir\scan-large.ps1" -Action Scan
            $obj = $output | ConvertFrom-Json
            ($obj.PSObject.Properties.Name -contains 'category') | Should Be $true
            ($obj.PSObject.Properties.Name -contains 'risk') | Should Be $true
        }
    }
}
