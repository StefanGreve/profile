#Requires -Version 7.4

<#
    .SYNOPSIS
    Installs the PowerShell profile from this repository.

    .DESCRIPTION
    Bootstraps the environment by installing the PowerTools module, cloning this
    repository, and creating a symbolic link from the selected $PROFILE location
    to the profile.ps1 file in the clone.

    On Windows, creating the symbolic link requires administrator rights unless
    Developer Mode is enabled.

    .PARAMETER RepositoryPath
    Parent directory into which the repository is cloned. The clone is placed in a
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

    Clones the repository into ./profile and links it to the CurrentUserAllHosts profile.

    .EXAMPLE
    PS> ./install.ps1 -RepositoryPath ~/repos -ProfileKind CurrentUserCurrentHost

    Clones the repository into ~/repos/profile and links profile.ps1 to the
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
        $Description = "The file `"${ProfileTargetPath}`" will be permanently deleted and replaced with a symbolic link to the cloned repository. Continue?"

        if ($PSCmdlet.ShouldProcess($ProfileTargetPath, "Remove the existing PowerShell profile")) {
            if ($Force.IsPresent -or $PSCmdlet.ShouldContinue($Description, $Title)) {
                [File]::Delete($ProfileTargetPath)
            } else {
                Write-Error "Aborted installation because the existing profile was not removed." `
                    -Category OperationStopped
            }
        }
    }
}
process {
    if (-not $PSCmdlet.ShouldProcess($ProfileTargetPath, "Install PowerShell profile")) { return }

    Write-Host "[1/3] " -ForegroundColor DarkGray -NoNewline
    Write-Host "Download PowerShell Profile . . . " -NoNewline
    git clone https://github.com/StefanGreve/profile.git $TargetDirectory --quiet

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to clone the profile repository from GitHub (git exited with code ${LASTEXITCODE})." `
            -Category ConnectionError
    }

    # Since the clone operation succeeded, this path is guaranteed to exist
    $ProfileSource = [Path]::GetFullPath([Path]::Join($TargetDirectory, "profile.ps1"))
    Write-Host "✓" -ForegroundColor Green

    Write-Host "[2/3] " -ForegroundColor DarkGray -NoNewline
    Write-Host "Create Symbolic Link . . . " -NoNewline
    $ProfileParentDirectory = [Directory]::GetParent($ProfileTargetPath).FullName
    $null = [Directory]::CreateDirectory($ProfileParentDirectory)
    $null = [File]::CreateSymbolicLink($ProfileTargetPath, $ProfileSource)
    Write-Host "✓" -ForegroundColor Green

    Write-Host "[3/3] " -ForegroundColor DarkGray -NoNewline
    Write-Host "Install Dependencies . . . " -NoNewline
    $InstallScope = $ProfileKind.StartsWith("All") ? "AllUsers" : "CurrentUser"
    Install-Module PowerTools -Scope $InstallScope -Force -ErrorAction Stop
    Write-Host "✓" -ForegroundColor Green

    Write-Host ""
    Write-Host "PowerShell profile installed successfully." -ForegroundColor Green
    Write-Host "Linked `"${ProfileTargetPath}`" -> `"${ProfileSource}`"." -ForegroundColor DarkGray
    Write-Host "Restart PowerShell or run '. `$PROFILE' to load it now." -ForegroundColor DarkGray
}
