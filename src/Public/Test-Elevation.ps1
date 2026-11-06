function Test-Elevation {
    <#
        .SYNOPSIS
        Determines whether the current session runs with elevated (administrator) privileges.

        .DESCRIPTION
        Tests whether the current process runs with elevated privileges. On Windows this checks
        whether the process token is elevated; on Linux and macOS it checks for an effective user
        ID of 0 (root).

        .INPUTS
        None. You can't pipe objects to Test-Elevation.

        .OUTPUTS
        System.Boolean. True if the session is elevated, otherwise false.

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
        Write-Output ([Environment]::IsPrivilegedProcess)
    }
}
