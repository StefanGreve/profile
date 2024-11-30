using namespace System

function Remove-EnvironmentVariable {
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
