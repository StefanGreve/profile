#Requires -Version 7.4

using namespace System.IO
using namespace System.Management.Automation.Host

function Install-Profile {
    <#
        .SYNOPSIS
        Installs the PowerShell profile from this repository.

        .DESCRIPTION
        Bootstraps the environment by downloading profile.ps1 from this repository,
        creating a symbolic link from the selected $PROFILE location to the downloaded
        file, and installing the PowerTools module (which provides the remaining scripts).

        When -ProfileKind is not supplied and the session is interactive, the command
        prompts for the profile location to link. This lets the `irm ... | iex` one-liner,
        which cannot forward arguments, still offer a choice.

        On Windows, this command must be run from an elevated (administrator) session,
        since creating the symbolic link requires administrator rights.

        Re-running the command overwrites a previous installation: the downloaded files
        under -InstallDirectory and the linked profile are replaced. An existing profile.config.json
        is preserved, since it is user-owned configuration. If an earlier run linked to a
        different -InstallDirectory, that stale download directory is removed once the new
        installation succeeds. A pre-existing profile that is not one of these managed symbolic
        links is backed up and confirmed before being replaced, unless -Force is specified.

        .PARAMETER InstallDirectory
        Parent directory into which profile.ps1 is downloaded. The file is placed in a
        "profile" subdirectory of this path. Defaults to the current working directory.

        .PARAMETER ProfileKind
        The member of the $PROFILE automatic variable to link. Accepted values are
        AllUsersAllHosts, AllUsersCurrentHost, CurrentUserAllHosts, and
        CurrentUserCurrentHost. The default is CurrentUserAllHosts.

        .PARAMETER Force
        Replace an existing profile without prompting for confirmation.

        .INPUTS
        None. You can't pipe objects to Install-Profile.

        .OUTPUTS
        None. This command writes progress to the host but does not return any objects.

        .EXAMPLE
        PS> Install-Profile

        Downloads profile.ps1 into ./profile and links it to the CurrentUserAllHosts profile.

        .EXAMPLE
        PS> Install-Profile -InstallDirectory ~/repos -ProfileKind CurrentUserCurrentHost

        Downloads profile.ps1 into ~/repos/profile and links it to the
        CurrentUserCurrentHost profile.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param(
        [Alias("RepositoryPath")]
        [Parameter(HelpMessage = "Parent directory into which profile.ps1 is downloaded (placed in a 'profile' subdirectory).")]
        [string] $InstallDirectory = $PWD.Path,

        [ValidateSet(
            "AllUsersAllHosts",
            "AllUsersCurrentHost",
            "CurrentUserAllHosts",
            "CurrentUserCurrentHost"
        )]
        [Parameter(HelpMessage = "The member of the `$PROFILE automatic variable to link.")]
        [string] $ProfileKind = "CurrentUserAllHosts",

        [Parameter(HelpMessage = "Replace an existing profile without prompting for confirmation.")]
        [switch] $Force
    )

    begin {
        Set-StrictMode -Version Latest
        $ErrorActionPreference = "Stop"

        if (!(Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Error "git is required (for the profile), but could not be found in PATH." `
                -Category NotInstalled
        }

        $CanPrompt = [Environment]::UserInteractive -and !([Console]::IsInputRedirected)

        if (!$PSBoundParameters.ContainsKey("ProfileKind") -and $CanPrompt) {
            $ProfileKinds = $PROFILE | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

            $Choices = [ChoiceDescription[]]@(
                for ($Index = 0; $Index -lt $ProfileKinds.Count; $Index++) {
                    $Kind = $ProfileKinds[$Index]
                    [ChoiceDescription]::new("&$($Index + 1) ${Kind}", [string] $PROFILE.$Kind)
                }
            )

            $Default = [array]::IndexOf($ProfileKinds, $ProfileKind)

            try {
                $Selection = $Host.UI.PromptForChoice("PowerShell profile", "Which `$PROFILE do you want to link?", $Choices, $Default)
                $ProfileKind = $ProfileKinds[$Selection]
            } catch {
                # A non-interactive host refuses prompts (the throw is wrapped in a
                # MethodInvocationException, not a HostException); keep the default value.
            }
        }

        $ProfileTargetPath = $PROFILE.$ProfileKind
        $ProfileBackupPath = "${ProfileTargetPath}.bak"
        $TargetDirectory = [Path]::GetFullPath([Path]::Join($InstallDirectory, "profile"))
        $ConfigPath = [Path]::GetFullPath([Path]::Join([Path]::GetDirectoryName($ProfileTargetPath), "profile.config.json"))
        $LinkProbePath = [Path]::Join([Path]::GetTempPath(), [Path]::GetRandomFileName())

        $PreviousTargetDirectory = $null

        if ([File]::Exists($ProfileTargetPath)) {
            $ExistingProfile = Get-Item -LiteralPath $ProfileTargetPath -Force

            if ($ExistingProfile.LinkType -eq "SymbolicLink") {
                $LinkTarget = $ExistingProfile.LinkTarget
                $CandidateDirectory = [Path]::GetDirectoryName($LinkTarget)
                $IsProfileDirectory = [Path]::GetFileName($LinkTarget) -eq "profile.ps1" -and [Path]::GetFileName($CandidateDirectory) -eq "profile"

                if ($IsProfileDirectory -and $CandidateDirectory -ne $TargetDirectory) {
                    $PreviousTargetDirectory = $CandidateDirectory
                }
            } else {
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
    }
    process {
        if (!$PSCmdlet.ShouldProcess($ProfileTargetPath, "Install PowerShell profile")) { return }

        Write-Host "[1/3] " -ForegroundColor DarkGray -NoNewline
        Write-Host "Download PowerShell Profile . . . " -NoNewline
        $ProfileSource = [Path]::GetFullPath([Path]::Join($TargetDirectory, "profile.ps1"))
        $null = [Directory]::CreateDirectory($TargetDirectory)
        Invoke-RestMethod -Uri "https://raw.githubusercontent.com/StefanGreve/profile/master/profile.ps1" -OutFile $ProfileSource
        Write-Host "done" -ForegroundColor Green

        Write-Host "[2/3] " -ForegroundColor DarkGray -NoNewline
        Write-Host "Create PowerShell Profile . . . " -NoNewline
        $ProfileParentDirectory = [Path]::GetDirectoryName($ProfileTargetPath)
        $null = [Directory]::CreateDirectory($ProfileParentDirectory)

        # Probe link creation first so a permission failure aborts before the profile is displaced
        try {
            $null = [File]::CreateSymbolicLink($LinkProbePath, $ProfileSource)
        } finally {
            [File]::Delete($LinkProbePath)
        }

        # Back up a pre-existing profile instead of deleting it outright.
        if ([File]::Exists($ProfileTargetPath)) {
            [File]::Move($ProfileTargetPath, $ProfileBackupPath, $true)
        }

        $null = [File]::CreateSymbolicLink($ProfileTargetPath, $ProfileSource)

        # Initialize profile with default configuration only on a fresh install
        if (![File]::Exists($ConfigPath)) {
            Invoke-RestMethod -Uri "https://raw.githubusercontent.com/StefanGreve/profile/master/profile.config.json" -OutFile $ConfigPath
        }

        Write-Host "done" -ForegroundColor Green

        Write-Host "[3/3] " -ForegroundColor DarkGray -NoNewline
        Write-Host "Install Dependencies . . . " -NoNewline
        $InstallScope = $ProfileKind.StartsWith("All") ? "AllUsers" : "CurrentUser"
        Install-Module PowerTools -Scope $InstallScope -Force
        Write-Host "done" -ForegroundColor Green

        Write-Host ""
        Write-Host "PowerShell profile installed successfully." -ForegroundColor Green
        Write-Host "Linked `"${ProfileTargetPath}`" -> `"${ProfileSource}`"." -ForegroundColor DarkGray
        Write-Host "Restart PowerShell or run '. `$PROFILE' to load it now." -ForegroundColor DarkGray

        # After a successful install, delete the installation directory from a previous run if present
        if ($null -ne $PreviousTargetDirectory -and [Directory]::Exists($PreviousTargetDirectory)) {
            if ($PSCmdlet.ShouldProcess($PreviousTargetDirectory, "Remove previous installation directory")) {
                try {
                    [Directory]::Delete($PreviousTargetDirectory, $true)
                    Write-Host "Removed previous installation directory `"${PreviousTargetDirectory}`"." -ForegroundColor DarkGray
                } catch {
                    Write-Warning "Could not remove the previous installation directory `"${PreviousTargetDirectory}`": $($_.Exception.Message)"
                }
            }
        }
    }
    end {
        # Installation succeeded; discard the backup of the previous profile.
        if ([File]::Exists($ProfileBackupPath)) {
            [File]::Delete($ProfileBackupPath)
        }
    }
}

Install-Profile @args
