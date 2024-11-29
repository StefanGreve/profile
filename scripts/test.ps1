using namespace System.IO

param(
    [string] $Version = "0.0.0",

    [switch] $Build
)

begin {
    $ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
    $ProjectRoot = $(Get-Item $([Path]::Combine($ScriptPath, ".."))).FullName
}
process {
    if (!$(Get-Module Pester -ListAvailable)) {
        Install-Module Pester -Scope CurrentUser -Force
    }

    $Container = New-PesterContainer `
        -Path $([Path]::Combine($ProjectRoot, "tests", "module.tests.ps1")) `
        -Data @{
            Version = $Version
            Build = $Build.IsPresent
        }

    Invoke-Pester -Container $Container -Output Detailed
}
clean {
}
