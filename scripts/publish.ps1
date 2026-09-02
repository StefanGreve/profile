using namespace System.IO

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param(
    [Parameter(Mandatory)]
    [string] $ApiKey,

    [Parameter(Mandatory)]
    [string] $Version
)

begin {
    $ModuleName = "PowerTools"
    $Author = "Stefan Greve"
    $CompanyName = "Advanced Systems"
    $Description = "General purpose Cmdlets for all platforms."
    $FoundingYear = 2024

    $PrivateData = @{
        PSData = @{
            Tags = @("PSEdition_Core", "Windows", "MacOS", "Linux")
            IconUri = "https://raw.githubusercontent.com/Advanced-Systems/assets/refs/heads/master/logos/png/adv-logo_85x85.png"
            LicenseUri = "https://github.com/StefanGreve/profile/blob/master/LICENSE.md"
            ProjectUri = "https://github.com/StefanGreve/profile"
            ReleaseNotes = "https://github.com/StefanGreve/profile/blob/master/CHANGELOG.md"
        }
    }

    $ManifestPath = "${ModuleName}.psd1"
    $ProjectRoot = Split-Path -Path $PSScriptRoot -Parent
    Push-Location $ProjectRoot
}
process {
    if ($Version -eq "0.0.0") {
        Write-Error "Version is not configured correctly." -Category InvalidArgument -ErrorAction Stop
    }

    # 1 - Build
    & "./scripts/build.ps1" `
        -ModuleName $ModuleName `
        -Author $Author `
        -CompanyName $CompanyName `
        -Description $Description `
        -FoundingYear $FoundingYear `
        -PrivateData $PrivateData `
        -Version $Version

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


