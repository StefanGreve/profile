using namespace System.IO

[CmdletBinding()]
param()

begin {
    $ModuleName = "PowerTools"
    $ManifestPath = "${ModuleName}.psd1"
    $ProjectRoot = Split-Path -Path $PSScriptRoot -Parent

    Push-Location $ProjectRoot
}
process {
    # 1 - Unload the currently installed module
    Remove-Module -Name $ModuleName -Force -ErrorAction SilentlyContinue

    # 2 - Build a local development version
    & "./scripts/build.ps1" -ModuleName $ModuleName -Version 0.0.0

    # 3 - Import the freshly built module
    Import-Module -Name "./src/${ManifestPath}" -Force -ErrorAction Stop
}
clean {
    Pop-Location
}
