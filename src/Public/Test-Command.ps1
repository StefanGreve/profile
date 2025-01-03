function Test-Command {
    <#
        .SYNOPSIS
        Tests whether a command, alias, function, or script exists in the current PowerShell session.

        .DESCRIPTION
        The Test-Command function verifies if a specified command is available in the current
        PowerShell environment. This includes cmdlets, aliases, functions, or external executables.

        .PARAMETER Name
        The name of the command to check for existence. This can be a cmdlet, alias, function, or
        external executable.

        .INPUTS
        None. You can't pipe objects to Test-Command.

        .EXAMPLE
        PS> Test-Command -Name wget

        Tests if the wget command exists in the current session.

        .OUTPUTS
        [bool] Returns $true if the command exists, otherwise $false.
    #>
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    process {
        $PrevPreference = $ErrorActionPreference

        try {
            $ErrorActionPreference = "Stop"
            Get-Command $Name | Out-Null
            return $true
        }
        catch {
            return $false
        }
        finally {
            $ErrorActionPreference = $PrevPreference
        }
    }
}
