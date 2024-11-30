using namespace System

function Get-EnvironmentVariable {
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
