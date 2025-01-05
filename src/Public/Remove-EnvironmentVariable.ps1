using namespace System

function Remove-EnvironmentVariable {
    <#
        .SYNOPSIS
        Removes an environment variable from the specified scope.

        .DESCRIPTION
        Deletes an environment variable based on its key and optional value
        from the specified scope. If the value is not provided, the function removes
        the variable based solely on the key.

        .PARAMETER Key
        The name of the environment variable to remove.

        .PARAMETER Value
        The value of the environment variable to remove. This parameter is optional
        and can be used to remove a specific value from an environment variable.

        .PARAMETER Scope
        Specifies the scope of the environment variable to remove.
        The default is Process. The terminal session requires a restart if the
        scope is not set to Process for the changes to take effect.

        .INPUTS
        None. You can't pipe objects to Remove-EnvironmentVariable.

        .EXAMPLE
        PS> Remove-EnvironmentVariable -Key PROFILE_ENABLE_BRANCH_USERNAME

        Removes the PROFILE_ENABLE_BRANCH_USERNAME environment variable from the
        Process scope.

        .EXAMPLE
        PS> Remove-EnvironmentVariable -Key PATH -Value "C:\Program Files\bin" -Scope User

        Removes "C:\Program Files\bin" from PATH.

        .OUTPUTS
        None. This function does not produce any output.

        .LINK
        https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_environment_variables
    #>
    [OutputType([void])]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param(
        [Parameter(Position = 0, Mandatory)]
        [string] $Key,

        [Parameter(Position = 1)]
        [string] $Value,

        [EnvironmentVariableTarget] $Scope = [EnvironmentVariableTarget]::Process
    )

    begin {
        $Token = [OperatingSystem]::IsWindows() ? ";" : ":"
    }
    process {
        $Title = "Remove `"${Value}`" from `"${Key}`""
        $Description = "Are you sure that you want to remove `"${Value}`" from the environment variable `"${Key}`"?"
        $RemoveValue = $([Environment]::GetEnvironmentVariable($Key, $Scope) -Split $Token | Where-Object { $_ -ne $Value }) -Join $Token

        if (!$PSBoundParameters.ContainsKey("Value")) {
            $Title = "Remove all values in `"${Key}`""
            $Description = "Are you sure that you want to remove the environment variable `"${Key}`"?"
            $RemoveValue = $null
        }

        if ($PSCmdlet.ShouldProcess($null, $Description, $Title)) {
            [Environment]::SetEnvironmentVariable($Key, $RemoveValue, $Scope)
        }
    }
}
