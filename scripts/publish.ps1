using namespace System.IO

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param(
    [string] $ModuleName = "Toolbox",

    [Parameter(Mandatory)]
    [string] $ApiKey,

    [Parameter(Mandatory)]
    [string] $Version
)

begin {
    $ManifestPath = "${ModuleName}.psd1"

    $ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
    $ProjectRoot = $(Get-Item $([Path]::Combine($ScriptPath, ".."))).FullName
    Push-Location $ProjectRoot
}
process {
    # 1 - Build
    & "./scripts/build.ps1" -Version $Version

    # 2 - Test
    & "./scripts/test.ps1" -Version $Version

    # 3 - Deploy
    if ($PSCmdlet.ShouldProcess($ManifestPath, "Publish `"${ModuleName}`" (Version ${Version}) to PSGallery")) {
        Publish-Module -Name "./src/${ManifestPath}" `
            -NuGetApiKey $ApiKey `
            -RequiredVersion $Version
    }
}
clean {
    Pop-Location
}


