using namespace System.IO

param(
    [switch] $Build
)

begin {
    $ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
    $ProjectRoot = $(Get-Item $([Path]::Combine($ScriptPath, ".."))).FullName
}
process {
    $Container = New-PesterContainer `
        -Path $([Path]::Combine($ProjectRoot, "tests", "module.tests.ps1")) `
        -Data @{
            Build = $Build.IsPresent
        }

    Invoke-Pester -Container $Container -Output Detailed
}
clean {
}
