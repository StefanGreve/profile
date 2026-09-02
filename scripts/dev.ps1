using namespace System.IO

[CmdletBinding()]
param(
    [string] $Version = "0.0.0"
)

begin {
    $ModuleName = "PowerTools"
    $Author = "Stefan Greve"
    $CompanyName = "Advanced Systems"
    $Description = "General purpose Cmdlets for all platforms."
    $FoundingYear = 2024

    $ManifestPath = "${ModuleName}.psd1"
    $ProjectRoot = Split-Path -Path $PSScriptRoot -Parent

    Push-Location $ProjectRoot
}
process {
    # 1 - Unload the currently installed module
    Remove-Module -Name $ModuleName -Force -ErrorAction SilentlyContinue

    # 2 - Build a local development version
    & "./scripts/build.ps1" `
        -ModuleName $ModuleName `
        -Author $Author `
        -CompanyName $CompanyName `
        -Description $Description `
        -FoundingYear $FoundingYear `
        -Version $Version

    # 3 - Import the freshly built module
    Import-Module -Name "./src/${ManifestPath}" -Force -ErrorAction Stop
}
clean {
    Pop-Location
}
