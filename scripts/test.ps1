using namespace System.IO

param()

begin {
    $ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
    $ProjectRoot = $(Get-Item $([Path]::Combine($ScriptPath, ".."))).FullName
    Push-Location $([Path]::Combine($ProjectRoot, "tests"))
}
process {
    Invoke-Pester -Script ("./module.tests.ps1")
}
clean {
    Pop-Location
}
