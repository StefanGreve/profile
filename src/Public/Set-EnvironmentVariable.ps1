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
        scope is not set to Process for the changes to take effect

        .PARAMETER Override
        If specified, the function overwrites the existing value of the environment
        variable if it already exists.

        .PARAMETER Force
        Enable this option to add a value to an existing key multiple times.

        .INPUTS
        None. You can't pipe objects to Set-EnvironmentVariable.

        .EXAMPLE
        PS> Set-EnvironmentVariable -Key PROFILE_ENABLE_BRANCH_USERNAME -Value 1

        Sets the value of the PROFILE_ENABLE_BRANCH_USERNAME environment variable to 1 in Process scope.

        .EXAMPLE
        PS> Set-EnvironmentVariable -Key API_KEY -Value "REDACTED" -Scope Process -Override

        Sets the value of the API_KEY environment variable to "REDACTED" in the User scope, overwriting any existing value.

        .EXAMPLE
        PS> Set-EnvironmentVariable -Key PATH -Value "C:\NewPath" -Scope Machine -Force

        Adds "C:\NewPath" to the PATH environment variable in the Machine scope, even if the PATH variable already exists.

        .OUTPUTS
        None. This function does not produce any output.

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

        [switch] $Override,

        [switch] $Force
    )

    begin {
        $Token = [OperatingSystem]::IsWindows() ? ";" : ":"
        $OldValue = $Override.IsPresent ? [string]::Empty : [Environment]::GetEnvironmentVariable($Key, $Scope)
        $NewValue = $OldValue.Length ? [string]::Join($Token, $OldValue, $Value) : $Value
    }
    process {
        if ($PSCmdlet.ShouldProcess($null, "Are you sure that you want to add `"${Value}`" to the environment variable `"${Key}`"?", "Add `"${Value}`" to `"${Key}`"")) {
            $IsDuplicatedValue = $($OldValue -Split $Token).Contains($Value)

            if ($IsDuplicatedValue) {
                Write-Warning "The value `"${Value}`" already exists for the key `"${Key}`"."

                if (!$Force) {
                    $Message = "To add a value to an existing key multiple times, use the -Force flag."
                    Write-Information -MessageData $Message -Tags "Instructions" -InformationAction Continue
                    return
                }

                Write-Warning "Forcing addition due to the -Force flag."
            }

            [Environment]::SetEnvironmentVariable($Key, $NewValue, $Scope)
        }
    }
}
