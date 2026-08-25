using namespace System

function Get-EnvironmentVariable {
    <#
        .SYNOPSIS
        Reads an environment variable from the specified scope.

        .DESCRIPTION
        Reads an environment variable from the specified scope. If no key is provided,
        it defaults to the PATH variable. The default scope is 'Process'.

        .PARAMETER Key
        The name of the environment variable to read. Defaults to PATH.

        .PARAMETER Scope
        Specifies the scope of the environment variable to read.
        The default is Process. On Linux and macOS, only the Process scope is supported.

        .INPUTS
        System.String. You can pipe a variable name to Get-EnvironmentVariable.

        .OUTPUTS
        System.String[]. A collection of strings representing the values of the retrieved environment variable(s).

        .EXAMPLE
        PS> Get-EnvironmentVariable -Scope Machine

        Returns all values from the PATH environment variable defined in Machine scope.

        .EXAMPLE
        PS> Get-EnvironmentVariable -Key JAVA_HOME -Scope User

        Returns all values from the JAVA_HOME environment variable defined in User scope.

        .NOTES
        On Linux and macOS, .NET only supports the Process scope for environment variables.
        The User and Machine scopes are ignored by the runtime, so on those platforms this
        Cmdlet emits a warning and performs no action when a non-Process scope is requested.

        .LINK
        https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_environment_variables
    #>
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [string] $Key = "PATH",

        [Parameter(Position = 1)]
        [EnvironmentVariableTarget] $Scope = [EnvironmentVariableTarget]::Process
    )

    begin {
        $Token = $IsWindows ? ";" : ":"
    }
    process {
        if (!$IsWindows -and $Scope -ne [EnvironmentVariableTarget]::Process) {
            Write-Warning "On Linux and macOS, only the Process scope is supported; the '$Scope' scope has no effect."
            return
        }

        $EnvironmentVariables = [Environment]::GetEnvironmentVariable($Key, $Scope)

        if ([string]::IsNullOrEmpty($EnvironmentVariables)) {
            Write-Error "Environment variable `"$Key`" is empty or not defined." -Category InvalidData
            return
        }

        $EnvironmentVariableArray = $EnvironmentVariables -Split $Token
        Write-Output $EnvironmentVariableArray
    }
}
