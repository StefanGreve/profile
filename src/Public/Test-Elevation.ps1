using namespace System.Security

function Test-Elevation {
    <#
        .SYNOPSIS
        Determines whether the current session runs with elevated (administrator) privileges.

        .DESCRIPTION
        Tests whether the current user runs with elevated privileges. On Windows this checks
        membership in the built-in Administrators role; on Linux it checks for a root user ID
        (UID 0); on MacOS it probes for passwordless sudo access. Returns $null on operating
        systems that cannot be determined.

        .INPUTS
        None. You can't pipe objects to Test-Elevation.

        .OUTPUTS
        System.Boolean. True if the session is elevated, otherwise false. Returns $null when
        the operating system cannot be determined.

        .EXAMPLE
        PS> Test-Elevation

        Returns True if the current session is elevated.

        .EXAMPLE
        PS> if (Test-Elevation) { "Elevated" } else { "Not elevated" }

        Branches on the elevation status of the current session.
    #>
    [OutputType([bool])]
    [CmdletBinding()]
    [Alias("Test-Administrator")]
    param()

    process {
        $IsElevated = if ($IsWindows) {
            $CurrentUser = [Principal.WindowsPrincipal][Principal.WindowsIdentity]::GetCurrent()
            $Administrator = [Principal.WindowsBuiltInRole]::Administrator
            $CurrentUser.IsInRole($Administrator)
        } elseif ($IsLinux) {
            $(id -u) -eq 0
        } elseif ($IsMacOS) {
            $(sudo -n true 2>$null) -eq $true
        } else {
            $null
        }

        Write-Output $IsElevated
    }
}
