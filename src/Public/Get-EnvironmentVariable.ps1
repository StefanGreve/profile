using namespace System

function Get-EnvironmentVariable {
    <#
        .SYNOPSIS
        Reads an environment variable from the specified scope.

        .DESCRIPTION
        Reads an environment variable from the specified scope. If no key is provided,
        it returns all environment variables available in the scope.
        The default scope is 'Process'.

        .PARAMETER Key
        The name of the environment variable to read.

        .PARAMETER Scope
        Specifies the scope of the environment variable to read.
        The default is Process.

        .INPUTS
        None. You can't pipe objects to Get-EnvironmentVariable.

        .EXAMPLE
        PS> Get-EnvironmentVariable -Scope Machine

        Returns all values from the PATH environment variable defined in Machine scope.

        .EXAMPLE
        PS> Get-EnvironmentVariable -Key PROFILE_ENABLE_BRANCH_USERNAME -Scope User

        Returns all values from the PROFILE_ENABLE_BRANCH_USERNAME environment variable defined in User scope.

        .OUTPUTS
        System.String[]. A collection of strings representing the values of the retrieved environment variable(s).

        .LINK
        https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_environment_variables
    #>
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string] $Key = "PATH",

        [Parameter(Position = 1)]
        [EnvironmentVariableTarget] $Scope = [EnvironmentVariableTarget]::Process
    )

    begin {
        $Token = [OperatingSystem]::IsWindows() ? ";" : ":"
    }
    process {
        $EnvironmentVariables = [Environment]::GetEnvironmentVariable($Key, $Scope)

        if ($EnvironmentVariables.Length -eq 0) {
            Write-Warning "Environment variable `"{$Key}`" is empty or not defined."
            return
        }

        $EnvironmentVariableArray = $EnvironmentVariables -Split $Token
        Write-Output $EnvironmentVariableArray
    }
}
