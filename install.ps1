#Requires -Version 7.4

<#
    .SYNOPSIS
    Installs the PowerShell profile from this repository.

    .DESCRIPTION
    Bootstraps the environment by downloading profile.ps1 from this repository,
    creating a symbolic link from the selected $PROFILE location to the downloaded
    file, and installing the PowerTools module (which provides the remaining scripts).

    On Windows, this script must be run from an elevated (administrator) session,
    since creating the symbolic link requires administrator rights.

    .PARAMETER RepositoryPath
    Parent directory into which profile.ps1 is downloaded. The file is placed in a
    "profile" subdirectory of this path. Defaults to the current working directory.

    .PARAMETER ProfileKind
    The member of the $PROFILE automatic variable to link. Accepted values are
    AllUsersAllHosts, AllUsersCurrentHost, CurrentUserAllHosts, and
    CurrentUserCurrentHost. The default is CurrentUserAllHosts.

    .INPUTS
    None. You can't pipe objects to install.ps1.

    .OUTPUTS
    None. This script writes progress to the host but does not return any objects.

    .EXAMPLE
    PS> ./install.ps1

    Downloads profile.ps1 into ./profile and links it to the CurrentUserAllHosts profile.

    .EXAMPLE
    PS> ./install.ps1 -RepositoryPath ~/repos -ProfileKind CurrentUserCurrentHost

    Downloads profile.ps1 into ~/repos/profile and links it to the
    CurrentUserCurrentHost profile.
#>

using namespace System.IO

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
param(
    [string] $RepositoryPath = $PWD.Path,

    [ValidateSet(
        "AllUsersAllHosts",
        "AllUsersCurrentHost",
        "CurrentUserAllHosts",
        "CurrentUserCurrentHost"
    )]
    [string] $ProfileKind = "CurrentUserAllHosts",

    [switch] $Force
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"

    $ProfileTargetPath = $PROFILE.$ProfileKind
    $TargetDirectory = [Path]::Join($RepositoryPath, "profile")

    if ([Directory]::Exists($TargetDirectory)) {
        Write-Error "The target directory `"${TargetDirectory}`" already exists; remove it or choose a different -RepositoryPath." `
            -Category ResourceExists
    }

    if ([File]::Exists($ProfileTargetPath)) {
        Write-Warning "A PowerShell profile already exists in the selected target location."

        $Title = "Overwrite existing PowerShell profile"
        $Description = "The file `"${ProfileTargetPath}`" will be backed up and replaced with a symbolic link to the downloaded profile. Continue?"

        if ($PSCmdlet.ShouldProcess($ProfileTargetPath, "Replace the existing PowerShell profile")) {
            if (!($Force.IsPresent -or $PSCmdlet.ShouldContinue($Description, $Title))) {
                Write-Error "Aborted installation because the existing profile may not be replaced." `
                    -Category OperationStopped
            }
        }
    }
}
process {
    if (-not $PSCmdlet.ShouldProcess($ProfileTargetPath, "Install PowerShell profile")) { return }

    Write-Host "[1/3] " -ForegroundColor DarkGray -NoNewline
    Write-Host "Download PowerShell Profile . . . " -NoNewline
    $ProfileSource = [Path]::GetFullPath([Path]::Join($TargetDirectory, "profile.ps1"))
    $null = [Directory]::CreateDirectory($TargetDirectory)

    try {
        Invoke-RestMethod -Uri "https://raw.githubusercontent.com/StefanGreve/profile/master/profile.ps1" -OutFile $ProfileSource
        Write-Host "✓" -ForegroundColor Green
    } catch {
        Write-Error "Failed to download the profile from GitHub: $($_.Exception.Message)" `
            -Category ConnectionError
    }

    Write-Host "[2/3] " -ForegroundColor DarkGray -NoNewline
    Write-Host "Create Symbolic Link . . . " -NoNewline

    # Back up a pre-existing profile instead of deleting it outright.
    $ProfileBackupPath = "${ProfileTargetPath}.bak"
    if ([File]::Exists($ProfileTargetPath)) {
        [File]::Move($ProfileTargetPath, $ProfileBackupPath, $true)
    }

    $ProfileParentDirectory = [Directory]::GetParent($ProfileTargetPath).FullName
    $null = [Directory]::CreateDirectory($ProfileParentDirectory)
    $null = [File]::CreateSymbolicLink($ProfileTargetPath, $ProfileSource)
    Write-Host "✓" -ForegroundColor Green

    Write-Host "[3/3] " -ForegroundColor DarkGray -NoNewline
    Write-Host "Install Dependencies . . . " -NoNewline
    $InstallScope = $ProfileKind.StartsWith("All") ? "AllUsers" : "CurrentUser"
    Install-Module PowerTools -Scope $InstallScope -Force
    Write-Host "✓" -ForegroundColor Green

    Write-Host ""
    Write-Host "PowerShell profile installed successfully." -ForegroundColor Green
    Write-Host "Linked `"${ProfileTargetPath}`" -> `"${ProfileSource}`"." -ForegroundColor DarkGray
    Write-Host "Restart PowerShell or run '. `$PROFILE' to load it now." -ForegroundColor DarkGray
}
clean {
    if ([File]::Exists($ProfileBackupPath)) {
        [File]::Delete($ProfileBackupPath)
    }
}
