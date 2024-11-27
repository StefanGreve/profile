using namespace System

function Set-EnvironmentVariable {
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
