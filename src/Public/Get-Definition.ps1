using namespace System.Management.Automation

function Get-Definition {
    <#
        .SYNOPSIS
        Prints the definition of a specified PowerShell function or Cmdlet.

        .DESCRIPTION
        Prints the definition of a specified PowerShell function or Cmdlet.
        If the command is a PowerShell script or function, the source code of the script or function is returned.
        Otherwise, for commands from binary modules, the syntax of the command is displayed.
        If the command is an alias, it is resolved to its underlying command before the definition is retrieved.

        .PARAMETER Command
        The name of the PowerShell command. Aliases are supported and resolved to their underlying command.

        .INPUTS
        None. You can't pipe objects to Get-Definition.

        .EXAMPLE
        PS> Get-Definition Get-Battery

        Returns the implementation of the Get-Battery Cmdlet.

        .EXAMPLE
        PS> Get-Definition battery

        Resolves the "battery" alias to Get-Battery and returns its implementation.

        .OUTPUTS
        The definition of the specified command is returned as a string.

        .NOTES
        If the bat syntax highlighter is installed and accessible, it formats the output.
    #>
    [OutputType([string])]
    param(
        [string] $Command
    )

    process {
        $ResolvedCommand = Get-Command $Command -ErrorAction SilentlyContinue

        while ($ResolvedCommand -and $ResolvedCommand.CommandType -eq [CommandTypes]::Alias) {
            $ResolvedCommand = $ResolvedCommand.ResolvedCommand
        }

        if (-not $ResolvedCommand) {
            Write-Error "The command `"$Command`" is not recognized as a name of a cmdlet, function, or alias." `
                -Category InvalidArgument `
                -ErrorAction Stop
        }

        $Definition = $ResolvedCommand.Definition

        if (Test-Command bat) {
            Write-Output $Definition | bat --language powershell
        } else {
            Write-Output $Definition
        }
    }
}
