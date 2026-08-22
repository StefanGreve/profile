using namespace System

function Set-EnvironmentVariable {
    <#
        .SYNOPSIS
        Sets an environment variable in the specified scope.

        .DESCRIPTION
        Defines or modifies an environment variable in the specified scope.
        The scope determines where the variable will be available. If the scope
        is User or Machine, changes may require restarting the terminal or system
        to take effect.

        .PARAMETER Key
        The name of the environment variable to set.

        .PARAMETER Value
         The value to assign to the environment variable.

        .PARAMETER Scope
        Specifies the scope of the environment variable to set.
        The default is Process. The terminal session requires a restart if the
        scope is not set to Process for the changes to take effect.
        On Linux and macOS, only the Process scope is supported.

        .PARAMETER Override
        If specified, the function overwrites the existing value of the environment
        variable if it already exists.

        .INPUTS
        None. You can't pipe objects to Set-EnvironmentVariable.

        .OUTPUTS
        None. This function does not produce any output.

        .EXAMPLE
        PS> Set-EnvironmentVariable -Key PROFILE_ENABLE_BRANCH_USERNAME -Value 1

        Sets the value of the PROFILE_ENABLE_BRANCH_USERNAME environment variable to 1 in Process scope.

        .EXAMPLE
        PS> Set-EnvironmentVariable -Key API_KEY -Value "REDACTED" -Scope User -Override

        Sets the value of the API_KEY environment variable to "REDACTED" in the User scope, overwriting any existing value.

        .NOTES
        On Linux and macOS, .NET only supports the Process scope for environment variables.
        The User and Machine scopes are ignored by the runtime, so on those platforms this
        Cmdlet emits a warning and performs no action when a non-Process scope is requested.

        .LINK
        https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_environment_variables
    #>
    [OutputType([void])]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Low")]
    param(
        [Parameter(Position = 0)]
        [string] $Key = "PATH",

        [Parameter(Position = 1, Mandatory)]
        [string] $Value,

        [Parameter(Position = 2)]
        [EnvironmentVariableTarget] $Scope = [EnvironmentVariableTarget]::Process,

        [switch] $Override
    )

    begin {
        $Token = $IsWindows ? ";" : ":"
        $OldValue = ($Override.IsPresent ? [string]::Empty : [Environment]::GetEnvironmentVariable($Key, $Scope)) ?? [string]::Empty
        $NewValue = $OldValue.Length ? [string]::Join($Token, $OldValue, $Value) : $Value
    }
    process {
        if (!$IsWindows -and $Scope -ne [EnvironmentVariableTarget]::Process) {
            Write-Warning "On Linux and macOS, only the Process scope is supported; the '$Scope' scope has no effect."
            return
        }

        if ($PSCmdlet.ShouldProcess($null, "Are you sure that you want to add `"${Value}`" to the environment variable `"${Key}`"?", "Add `"${Value}`" to `"${Key}`"")) {
            $IsDuplicatedValue = $($OldValue -Split $Token).Contains($Value)

            if ($IsDuplicatedValue) {
                Write-Warning "The value `"${Value}`" already exists for the key `"${Key}`"; skipping."
                return
            }

            [Environment]::SetEnvironmentVariable($Key, $NewValue, $Scope)
        }
    }
}
