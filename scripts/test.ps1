using namespace System.IO

param(
    [string] $Version = "0.0.0",

    [switch] $Build
)

begin {
    $ProjectRoot = Split-Path -Path $PSScriptRoot -Parent
    Push-Location $ProjectRoot

    $MinimumVersion = "6.0.0"
    $MaximumVersion = "6.99.99"
}
process {
    $Pester = Get-Module Pester -ListAvailable
        | Where-Object { $_.Version -ge $MinimumVersion -and $_.Version -le $MaximumVersion }

    if (!$Pester) {
        Install-Module Pester -MinimumVersion $MinimumVersion -MaximumVersion $MaximumVersion -Scope CurrentUser -Force
    }

    Import-Module Pester -MinimumVersion $MinimumVersion -MaximumVersion $MaximumVersion -Force

    $Container = New-PesterContainer `
        -Path $([Path]::Join($ProjectRoot, "tests", "module.tests.ps1")) `
        -Data @{
            Version = $Version
            Build = $Build.IsPresent
        }

    Invoke-Pester -Container $Container -Output Detailed
}
clean {
    Pop-Location
}
