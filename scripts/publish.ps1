using namespace System.IO

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param(
    [string] $ModuleName = "PowerTools",

    [Parameter(Mandatory)]
    [string] $ApiKey,

    [Parameter(Mandatory)]
    [string] $Version
)

begin {
    $ManifestPath = "${ModuleName}.psd1"
    $ProjectRoot = Split-Path -Path $PSScriptRoot -Parent
    Push-Location $ProjectRoot
}
process {
    if ($Version -eq "0.0.0") {
        Write-Error "Version is not configured correctly." -Category InvalidArgument -ErrorAction Stop
    }

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


